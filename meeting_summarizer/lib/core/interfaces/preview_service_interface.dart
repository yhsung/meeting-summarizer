import '../models/preview/preview_config.dart';
import '../models/preview/preview_result.dart';
import '../models/storage/file_metadata.dart';
import '../enums/preview_type.dart';
import '../enums/thumbnail_size.dart';

/// Abstract interface for file preview and thumbnail generation services
abstract class PreviewServiceInterface {
  /// Generate a preview/thumbnail for a single file
  Future<PreviewResult> generatePreview(
    FileMetadata fileMetadata,
    PreviewConfig config,
  );

  /// Generate previews for multiple files
  Future<List<PreviewResult>> generatePreviews(
    List<FileMetadata> fileMetadataList,
    PreviewConfig config,
  );

  /// Get cached preview if available
  Future<PreviewResult?> getCachedPreview(String fileId, ThumbnailSize size);

  /// Check if a file can be previewed
  bool canPreview(FileMetadata fileMetadata);

  /// Get the preview type for a file
  PreviewType getPreviewType(FileMetadata fileMetadata);

  /// Get supported preview types
  List<PreviewType> getSupportedTypes();

  /// Clear thumbnail cache for a specific file
  Future<void> clearCache(String fileId);

  /// Clear all thumbnail caches
  Future<void> clearAllCaches();

  /// Get cache statistics
  Future<PreviewCacheStats> getCacheStats();

  /// Clean up old cached thumbnails based on cache policies
  Future<void> cleanupCache();

  /// Pre-generate thumbnails for a list of files (background operation)
  Future<void> preGenerateThumbnails(
    List<FileMetadata> fileMetadataList, {
    ThumbnailSize size = ThumbnailSize.medium,
    Function(int processed, int total)? onProgress,
  });

  /// Check if preview generation is currently in progress for a file
  bool isGenerating(String fileId);

  /// Cancel preview generation for a file (if possible)
  Future<bool> cancelGeneration(String fileId);

  /// Get generation progress for files currently being processed
  Stream<PreviewGenerationProgress> getGenerationProgress();
}

/// Cache statistics for preview thumbnails
class PreviewCacheStats {
  final int totalFiles;
  final int cachedThumbnails;
  final int totalSizeBytes;
  final int averageSizeBytes;
  final DateTime lastCleanup;
  final Map<ThumbnailSize, int> sizeDistribution;
  final Map<PreviewType, int> typeDistribution;

  const PreviewCacheStats({
    required this.totalFiles,
    required this.cachedThumbnails,
    required this.totalSizeBytes,
    required this.averageSizeBytes,
    required this.lastCleanup,
    this.sizeDistribution = const {},
    this.typeDistribution = const {},
  });

  /// Calculate cache hit ratio
  double get hitRatio {
    if (totalFiles == 0) return 0.0;
    return cachedThumbnails / totalFiles;
  }

  /// Get human-readable total size
  String get formattedTotalSize {
    if (totalSizeBytes < 1024) return '${totalSizeBytes}B';
    if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Get human-readable average size
  String get formattedAverageSize {
    if (averageSizeBytes < 1024) return '${averageSizeBytes}B';
    if (averageSizeBytes < 1024 * 1024) {
      return '${(averageSizeBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(averageSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  String toString() {
    return 'PreviewCacheStats(totalFiles: $totalFiles, '
        'cachedThumbnails: $cachedThumbnails, '
        'totalSize: $formattedTotalSize, '
        'averageSize: $formattedAverageSize, '
        'hitRatio: ${(hitRatio * 100).toStringAsFixed(1)}%)';
  }
}

/// Progress information for preview generation operations
class PreviewGenerationProgress {
  final String fileId;
  final String fileName;
  final PreviewType type;
  final ThumbnailSize size;
  final double progressPercentage;
  final String currentOperation;
  final DateTime startTime;
  final Duration? estimatedTimeRemaining;

  const PreviewGenerationProgress({
    required this.fileId,
    required this.fileName,
    required this.type,
    required this.size,
    required this.progressPercentage,
    required this.currentOperation,
    required this.startTime,
    this.estimatedTimeRemaining,
  });

  /// Check if generation is complete
  bool get isComplete => progressPercentage >= 100.0;

  /// Get elapsed time since generation started
  Duration get elapsedTime => DateTime.now().difference(startTime);

  /// Get human-readable progress
  String get formattedProgress => '${progressPercentage.toStringAsFixed(1)}%';

  /// Get human-readable estimated time remaining
  String get formattedTimeRemaining {
    if (estimatedTimeRemaining == null) return 'Unknown';

    final seconds = estimatedTimeRemaining!.inSeconds;
    if (seconds < 60) return '${seconds}s';

    final minutes = estimatedTimeRemaining!.inMinutes;
    if (minutes < 60) return '${minutes}m ${seconds % 60}s';

    final hours = estimatedTimeRemaining!.inHours;
    return '${hours}h ${minutes % 60}m';
  }

  @override
  String toString() {
    return 'PreviewGenerationProgress(fileId: $fileId, '
        'type: $type, progress: $formattedProgress, '
        'operation: $currentOperation, '
        'timeRemaining: $formattedTimeRemaining)';
  }
}
