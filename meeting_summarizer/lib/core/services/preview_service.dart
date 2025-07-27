import 'dart:async';
import 'dart:io';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

import '../interfaces/preview_service_interface.dart';
import '../models/preview/preview_config.dart';
import '../models/preview/preview_result.dart';
import '../models/storage/file_metadata.dart';
import '../enums/preview_type.dart';
import '../enums/thumbnail_size.dart';

/// Implementation of preview service with multi-format thumbnail generation
class PreviewService implements PreviewServiceInterface {
  final String _cacheDirectory;
  final Map<String, StreamController<PreviewGenerationProgress>>
      _activeGenerations;
  final Map<String, PreviewResult> _memoryCache;
  final int _memoryCacheLimit;

  PreviewService._({required String cacheDirectory, int memoryCacheLimit = 50})
      : _cacheDirectory = cacheDirectory,
        _activeGenerations = {},
        _memoryCache = {},
        _memoryCacheLimit = memoryCacheLimit;

  /// Create preview service instance
  static Future<PreviewService> create({
    String? cacheDirectory,
    int memoryCacheLimit = 50,
  }) async {
    final cacheDir = cacheDirectory ?? await _getDefaultCacheDirectory();
    await Directory(cacheDir).create(recursive: true);

    return PreviewService._(
      cacheDirectory: cacheDir,
      memoryCacheLimit: memoryCacheLimit,
    );
  }

  @override
  Future<PreviewResult> generatePreview(
    FileMetadata fileMetadata,
    PreviewConfig config,
  ) async {
    final startTime = DateTime.now();
    final type = config.type;

    try {
      // Check if already generating
      if (isGenerating(fileMetadata.id)) {
        return PreviewResult.failure(
          type: type,
          errorMessage: 'Preview generation already in progress',
          size: config.thumbnailSize,
          processingTime: DateTime.now().difference(startTime),
        );
      }

      // Check cache first if enabled
      if (config.enableCache) {
        final cached = await getCachedPreview(
          fileMetadata.id,
          config.thumbnailSize,
        );
        if (cached != null && cached.success) {
          return cached;
        }
      }

      // Start generation tracking
      final progressController =
          StreamController<PreviewGenerationProgress>.broadcast();
      _activeGenerations[fileMetadata.id] = progressController;

      try {
        // Generate thumbnail based on type
        final result = await _generateThumbnailByType(
          fileMetadata,
          config,
          progressController,
        );

        // Cache result if successful and caching is enabled
        if (result.success && config.enableCache) {
          await _cacheResult(fileMetadata.id, config.thumbnailSize, result);
        }

        return result;
      } finally {
        // Clean up generation tracking
        _activeGenerations.remove(fileMetadata.id);
        await progressController.close();
      }
    } catch (e, stackTrace) {
      return PreviewResult.failure(
        type: type,
        errorMessage: 'Preview generation failed: $e',
        size: config.thumbnailSize,
        processingTime: DateTime.now().difference(startTime),
        metadata: {'error': e.toString(), 'stackTrace': stackTrace.toString()},
      );
    }
  }

  @override
  Future<List<PreviewResult>> generatePreviews(
    List<FileMetadata> fileMetadataList,
    PreviewConfig config,
  ) async {
    final results = <PreviewResult>[];

    for (int i = 0; i < fileMetadataList.length; i++) {
      final fileMetadata = fileMetadataList[i];
      final result = await generatePreview(fileMetadata, config);
      results.add(result);

      // Report batch progress if there are active listeners
      if (_activeGenerations.containsKey('batch_operation')) {
        final progress = PreviewGenerationProgress(
          fileId: 'batch_operation',
          fileName: 'Batch Operation',
          type: config.type,
          size: config.thumbnailSize,
          progressPercentage: ((i + 1) / fileMetadataList.length) * 100,
          currentOperation: 'Processing ${fileMetadata.fileName}',
          startTime: DateTime.now(),
        );

        _activeGenerations['batch_operation']?.add(progress);
      }
    }

    return results;
  }

  @override
  Future<PreviewResult?> getCachedPreview(
    String fileId,
    ThumbnailSize size,
  ) async {
    // Check memory cache first
    final memoryKey = _getMemoryCacheKey(fileId, size);
    if (_memoryCache.containsKey(memoryKey)) {
      final cached = _memoryCache[memoryKey]!;
      // Check if cache is still valid
      if (_isCacheValid(cached)) {
        return cached;
      } else {
        _memoryCache.remove(memoryKey);
      }
    }

    // Check disk cache
    final cacheFile = File(_getCacheFilePath(fileId, size));
    if (await cacheFile.exists()) {
      try {
        final thumbnailData = await cacheFile.readAsBytes();
        final result = PreviewResult.success(
          type: PreviewType.image, // Cached thumbnails are always images
          thumbnailData: thumbnailData,
          size: size,
          processingTime: Duration.zero,
          metadata: {'cached': true, 'cacheFile': cacheFile.path},
        );

        // Add to memory cache
        _addToMemoryCache(memoryKey, result);
        return result;
      } catch (e) {
        // Cache file corrupted, delete it
        await cacheFile.delete();
        return null;
      }
    }

    return null;
  }

  @override
  bool canPreview(FileMetadata fileMetadata) {
    final type = getPreviewType(fileMetadata);
    return type != PreviewType.unsupported;
  }

  @override
  PreviewType getPreviewType(FileMetadata fileMetadata) {
    return PreviewType.fromExtension(path.extension(fileMetadata.fileName));
  }

  @override
  List<PreviewType> getSupportedTypes() {
    return [
      PreviewType.image,
      PreviewType.video,
      PreviewType.pdf,
      PreviewType.audio,
      PreviewType.text,
    ];
  }

  @override
  Future<void> clearCache(String fileId) async {
    // Remove from memory cache
    _memoryCache.removeWhere((key, value) => key.startsWith(fileId));

    // Remove from disk cache
    for (final size in ThumbnailSize.values) {
      final cacheFile = File(_getCacheFilePath(fileId, size));
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
    }
  }

  @override
  Future<void> clearAllCaches() async {
    // Clear memory cache
    _memoryCache.clear();

    // Clear disk cache
    final cacheDir = Directory(_cacheDirectory);
    if (await cacheDir.exists()) {
      await for (final entity in cacheDir.list()) {
        if (entity is File && entity.path.endsWith('.thumbnail')) {
          await entity.delete();
        }
      }
    }
  }

  @override
  Future<PreviewCacheStats> getCacheStats() async {
    final cacheDir = Directory(_cacheDirectory);
    if (!await cacheDir.exists()) {
      return PreviewCacheStats(
        totalFiles: 0,
        cachedThumbnails: 0,
        totalSizeBytes: 0,
        averageSizeBytes: 0,
        lastCleanup: DateTime(2024, 1, 1),
      );
    }

    int totalFiles = 0;
    int totalSizeBytes = 0;
    final sizeDistribution = <ThumbnailSize, int>{};
    final typeDistribution = <PreviewType, int>{};

    await for (final entity in cacheDir.list()) {
      if (entity is File && entity.path.endsWith('.thumbnail')) {
        totalFiles++;
        final stat = await entity.stat();
        totalSizeBytes += stat.size;

        // Parse filename to get size and type information
        final filename = path.basename(entity.path);
        final parts = filename.split('_');
        if (parts.length >= 3) {
          final sizeStr = parts[1];
          final size = ThumbnailSize.values.cast<ThumbnailSize?>().firstWhere(
                (s) => s?.size.toString() == sizeStr,
                orElse: () => null,
              );
          if (size != null) {
            sizeDistribution[size] = (sizeDistribution[size] ?? 0) + 1;
          }
        }
      }
    }

    final averageSize = totalFiles > 0 ? totalSizeBytes ~/ totalFiles : 0;

    return PreviewCacheStats(
      totalFiles: _memoryCache.length, // Using known file count
      cachedThumbnails: totalFiles,
      totalSizeBytes: totalSizeBytes,
      averageSizeBytes: averageSize,
      lastCleanup: DateTime.now(), // Would track this properly in production
      sizeDistribution: sizeDistribution,
      typeDistribution: typeDistribution,
    );
  }

  @override
  Future<void> cleanupCache() async {
    final cacheDir = Directory(_cacheDirectory);
    if (!await cacheDir.exists()) return;

    final cutoffDate = DateTime.now().subtract(const Duration(days: 7));

    await for (final entity in cacheDir.list()) {
      if (entity is File && entity.path.endsWith('.thumbnail')) {
        final stat = await entity.stat();
        if (stat.accessed.isBefore(cutoffDate)) {
          await entity.delete();
        }
      }
    }

    // Clean up memory cache
    _memoryCache.removeWhere((key, value) => !_isCacheValid(value));
  }

  @override
  Future<void> preGenerateThumbnails(
    List<FileMetadata> fileMetadataList, {
    ThumbnailSize size = ThumbnailSize.medium,
    Function(int processed, int total)? onProgress,
  }) async {
    final config = PreviewConfig(type: PreviewType.image, thumbnailSize: size);

    for (int i = 0; i < fileMetadataList.length; i++) {
      final fileMetadata = fileMetadataList[i];

      // Skip if already cached
      final cached = await getCachedPreview(fileMetadata.id, size);
      if (cached != null) {
        onProgress?.call(i + 1, fileMetadataList.length);
        continue;
      }

      // Generate thumbnail
      try {
        await generatePreview(fileMetadata, config);
      } catch (e) {
        // Continue with next file on error
        if (kDebugMode) {
          log('Failed to generate thumbnail for ${fileMetadata.fileName}: $e');
        }
      }

      onProgress?.call(i + 1, fileMetadataList.length);
    }
  }

  @override
  bool isGenerating(String fileId) {
    return _activeGenerations.containsKey(fileId);
  }

  @override
  Future<bool> cancelGeneration(String fileId) async {
    final controller = _activeGenerations[fileId];
    if (controller != null) {
      await controller.close();
      _activeGenerations.remove(fileId);
      return true;
    }
    return false;
  }

  @override
  Stream<PreviewGenerationProgress> getGenerationProgress() {
    return Stream.fromIterable(
      _activeGenerations.values,
    ).asyncExpand((controller) => controller.stream);
  }

  // Private helper methods

  Future<PreviewResult> _generateThumbnailByType(
    FileMetadata fileMetadata,
    PreviewConfig config,
    StreamController<PreviewGenerationProgress> progressController,
  ) async {
    final startTime = DateTime.now();

    switch (config.type) {
      case PreviewType.image:
        return await _generateImageThumbnail(
          fileMetadata,
          config,
          progressController,
        );
      case PreviewType.video:
        return await _generateVideoThumbnail(
          fileMetadata,
          config,
          progressController,
        );
      case PreviewType.pdf:
        return await _generatePdfThumbnail(
          fileMetadata,
          config,
          progressController,
        );
      case PreviewType.audio:
        return await _generateAudioThumbnail(
          fileMetadata,
          config,
          progressController,
        );
      case PreviewType.text:
        return await _generateTextThumbnail(
          fileMetadata,
          config,
          progressController,
        );
      case PreviewType.archive:
        return await _generateArchiveThumbnail(
          fileMetadata,
          config,
          progressController,
        );
      case PreviewType.unsupported:
        return PreviewResult.failure(
          type: config.type,
          errorMessage: 'Unsupported file type for preview',
          size: config.thumbnailSize,
          processingTime: DateTime.now().difference(startTime),
        );
    }
  }

  Future<PreviewResult> _generateImageThumbnail(
    FileMetadata fileMetadata,
    PreviewConfig config,
    StreamController<PreviewGenerationProgress> progressController,
  ) async {
    final startTime = DateTime.now();

    try {
      progressController.add(
        PreviewGenerationProgress(
          fileId: fileMetadata.id,
          fileName: fileMetadata.fileName,
          type: config.type,
          size: config.thumbnailSize,
          progressPercentage: 25.0,
          currentOperation: 'Reading image file',
          startTime: startTime,
        ),
      );

      // Read original image
      final imageFile = File(fileMetadata.filePath);
      if (!await imageFile.exists()) {
        return PreviewResult.failure(
          type: config.type,
          errorMessage: 'Image file not found',
          size: config.thumbnailSize,
          processingTime: DateTime.now().difference(startTime),
        );
      }

      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        return PreviewResult.failure(
          type: config.type,
          errorMessage: 'Invalid image format',
          size: config.thumbnailSize,
          processingTime: DateTime.now().difference(startTime),
        );
      }

      progressController.add(
        PreviewGenerationProgress(
          fileId: fileMetadata.id,
          fileName: fileMetadata.fileName,
          type: config.type,
          size: config.thumbnailSize,
          progressPercentage: 50.0,
          currentOperation: 'Resizing image',
          startTime: startTime,
        ),
      );

      // Resize image to thumbnail size
      final thumbnailSize = config.thumbnailSize.size;
      final thumbnail = img.copyResize(
        image,
        width: thumbnailSize,
        height: thumbnailSize,
        interpolation: img.Interpolation.cubic,
      );

      progressController.add(
        PreviewGenerationProgress(
          fileId: fileMetadata.id,
          fileName: fileMetadata.fileName,
          type: config.type,
          size: config.thumbnailSize,
          progressPercentage: 75.0,
          currentOperation: 'Encoding thumbnail',
          startTime: startTime,
        ),
      );

      // Encode as JPEG with specified quality
      final thumbnailBytes = img.encodeJpg(
        thumbnail,
        quality: config.defaultQuality,
      );

      progressController.add(
        PreviewGenerationProgress(
          fileId: fileMetadata.id,
          fileName: fileMetadata.fileName,
          type: config.type,
          size: config.thumbnailSize,
          progressPercentage: 100.0,
          currentOperation: 'Thumbnail complete',
          startTime: startTime,
        ),
      );

      return PreviewResult.success(
        type: config.type,
        thumbnailData: Uint8List.fromList(thumbnailBytes),
        size: config.thumbnailSize,
        processingTime: DateTime.now().difference(startTime),
        metadata: {
          'originalWidth': image.width,
          'originalHeight': image.height,
          'thumbnailWidth': thumbnail.width,
          'thumbnailHeight': thumbnail.height,
          'compressionRatio': thumbnailBytes.length / imageBytes.length,
          'format': 'JPEG',
          'quality': config.defaultQuality,
        },
      );
    } catch (e) {
      return PreviewResult.failure(
        type: config.type,
        errorMessage: 'Image thumbnail generation failed: $e',
        size: config.thumbnailSize,
        processingTime: DateTime.now().difference(startTime),
      );
    }
  }

  Future<PreviewResult> _generateVideoThumbnail(
    FileMetadata fileMetadata,
    PreviewConfig config,
    StreamController<PreviewGenerationProgress> progressController,
  ) async {
    final startTime = DateTime.now();

    try {
      progressController.add(
        PreviewGenerationProgress(
          fileId: fileMetadata.id,
          fileName: fileMetadata.fileName,
          type: config.type,
          size: config.thumbnailSize,
          progressPercentage: 25.0,
          currentOperation: 'Extracting video frame',
          startTime: startTime,
        ),
      );

      final timeMs = config.typeSpecificOptions['timeMs'] ?? 1000;
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: fileMetadata.filePath,
        thumbnailPath: _cacheDirectory,
        imageFormat: ImageFormat.JPEG,
        maxWidth: config.thumbnailSize.size,
        maxHeight: config.thumbnailSize.size,
        timeMs: timeMs,
        quality: config.defaultQuality,
      );

      if (thumbnailPath == null) {
        return PreviewResult.failure(
          type: config.type,
          errorMessage: 'Failed to extract video thumbnail',
          size: config.thumbnailSize,
          processingTime: DateTime.now().difference(startTime),
        );
      }

      progressController.add(
        PreviewGenerationProgress(
          fileId: fileMetadata.id,
          fileName: fileMetadata.fileName,
          type: config.type,
          size: config.thumbnailSize,
          progressPercentage: 100.0,
          currentOperation: 'Video thumbnail complete',
          startTime: startTime,
        ),
      );

      final thumbnailFile = File(thumbnailPath);
      final thumbnailBytes = await thumbnailFile.readAsBytes();

      return PreviewResult.success(
        type: config.type,
        thumbnailPath: thumbnailPath,
        thumbnailData: thumbnailBytes,
        size: config.thumbnailSize,
        processingTime: DateTime.now().difference(startTime),
        metadata: {
          'extractionTimeMs': timeMs,
          'format': 'JPEG',
          'quality': config.defaultQuality,
        },
      );
    } catch (e) {
      return PreviewResult.failure(
        type: config.type,
        errorMessage: 'Video thumbnail generation failed: $e',
        size: config.thumbnailSize,
        processingTime: DateTime.now().difference(startTime),
      );
    }
  }

  Future<PreviewResult> _generatePdfThumbnail(
    FileMetadata fileMetadata,
    PreviewConfig config,
    StreamController<PreviewGenerationProgress> progressController,
  ) async {
    final startTime = DateTime.now();

    // PDF thumbnail generation would require additional native dependencies
    // For now, return a placeholder implementation
    return PreviewResult.failure(
      type: config.type,
      errorMessage: 'PDF thumbnail generation not yet implemented',
      size: config.thumbnailSize,
      processingTime: DateTime.now().difference(startTime),
    );
  }

  Future<PreviewResult> _generateAudioThumbnail(
    FileMetadata fileMetadata,
    PreviewConfig config,
    StreamController<PreviewGenerationProgress> progressController,
  ) async {
    final startTime = DateTime.now();

    // Audio thumbnail (waveform) generation would require audio processing
    // For now, return a placeholder implementation
    return PreviewResult.failure(
      type: config.type,
      errorMessage: 'Audio waveform thumbnail generation not yet implemented',
      size: config.thumbnailSize,
      processingTime: DateTime.now().difference(startTime),
    );
  }

  Future<PreviewResult> _generateTextThumbnail(
    FileMetadata fileMetadata,
    PreviewConfig config,
    StreamController<PreviewGenerationProgress> progressController,
  ) async {
    final startTime = DateTime.now();

    // Text thumbnail generation would create an image of the text content
    // For now, return a placeholder implementation
    return PreviewResult.failure(
      type: config.type,
      errorMessage: 'Text thumbnail generation not yet implemented',
      size: config.thumbnailSize,
      processingTime: DateTime.now().difference(startTime),
    );
  }

  Future<PreviewResult> _generateArchiveThumbnail(
    FileMetadata fileMetadata,
    PreviewConfig config,
    StreamController<PreviewGenerationProgress> progressController,
  ) async {
    final startTime = DateTime.now();

    // Archive thumbnail generation would show contents listing
    // For now, return a placeholder implementation
    return PreviewResult.failure(
      type: config.type,
      errorMessage: 'Archive thumbnail generation not yet implemented',
      size: config.thumbnailSize,
      processingTime: DateTime.now().difference(startTime),
    );
  }

  String _getCacheFilePath(String fileId, ThumbnailSize size) {
    final hash = sha256.convert(fileId.codeUnits).toString().substring(0, 16);
    return path.join(_cacheDirectory, '${hash}_${size.size}.thumbnail');
  }

  String _getMemoryCacheKey(String fileId, ThumbnailSize size) {
    return '${fileId}_${size.size}';
  }

  Future<void> _cacheResult(
    String fileId,
    ThumbnailSize size,
    PreviewResult result,
  ) async {
    if (result.thumbnailData != null) {
      // Save to disk cache
      final cacheFile = File(_getCacheFilePath(fileId, size));
      await cacheFile.writeAsBytes(result.thumbnailData!);

      // Add to memory cache
      final memoryKey = _getMemoryCacheKey(fileId, size);
      _addToMemoryCache(memoryKey, result);
    }
  }

  void _addToMemoryCache(String key, PreviewResult result) {
    // Remove oldest entries if cache is full
    if (_memoryCache.length >= _memoryCacheLimit) {
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
    }

    _memoryCache[key] = result;
  }

  bool _isCacheValid(PreviewResult result) {
    final age = DateTime.now().difference(result.createdAt);
    return age < const Duration(days: 7); // Default cache validity
  }

  static Future<String> _getDefaultCacheDirectory() async {
    // This would use path_provider to get the appropriate cache directory
    // For now, return a placeholder path
    return path.join(
      Directory.systemTemp.path,
      'meeting_summarizer_thumbnails',
    );
  }
}
