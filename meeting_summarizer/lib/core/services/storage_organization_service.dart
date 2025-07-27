import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../interfaces/storage_organization_interface.dart';
import '../models/storage/file_category.dart';
import '../models/storage/file_metadata.dart';
import '../models/storage/storage_stats.dart';

/// Implementation of storage organization system
class StorageOrganizationService implements StorageOrganizationInterface {
  static const String _metadataFileName = '.file_metadata.json';
  static const String _backupPrefix = 'metadata_backup_';

  final Uuid _uuid = const Uuid();

  Directory? _storageDirectory;
  final Map<String, FileMetadata> _metadataCache = {};
  bool _isInitialized = false;

  StorageOrganizationService();

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    _storageDirectory = await getStorageDirectory();
    await createDirectoryStructure();
    await _loadMetadataCache();
    _isInitialized = true;
  }

  @override
  Future<Directory> getStorageDirectory() async {
    if (_storageDirectory != null) return _storageDirectory!;

    final appDir = await getApplicationDocumentsDirectory();
    _storageDirectory = Directory(path.join(appDir.path, 'meeting_summarizer'));

    if (!await _storageDirectory!.exists()) {
      await _storageDirectory!.create(recursive: true);
    }

    return _storageDirectory!;
  }

  @override
  Future<Directory> getCategoryDirectory(FileCategory category) async {
    final baseDir = await getStorageDirectory();
    final categoryDir = Directory(
      path.join(baseDir.path, category.directoryName),
    );

    if (!await categoryDir.exists()) {
      await categoryDir.create(recursive: true);
    }

    return categoryDir;
  }

  @override
  Future<void> createDirectoryStructure() async {
    final baseDir = await getStorageDirectory();

    // Create category directories
    for (final category in FileCategory.values) {
      final categoryDir = Directory(
        path.join(baseDir.path, category.directoryName),
      );
      if (!await categoryDir.exists()) {
        await categoryDir.create(recursive: true);
      }
    }

    // Create year/month subdirectories for time-based organization
    final now = DateTime.now();
    final recordingsDir = await getCategoryDirectory(FileCategory.recordings);
    final yearDir = Directory(
      path.join(recordingsDir.path, now.year.toString()),
    );
    final monthDir = Directory(
      path.join(yearDir.path, now.month.toString().padLeft(2, '0')),
    );

    if (!await monthDir.exists()) {
      await monthDir.create(recursive: true);
    }
  }

  @override
  Future<FileMetadata> registerFile({
    required String filePath,
    required FileCategory category,
    String? description,
    List<String> tags = const [],
    Map<String, dynamic> customMetadata = const {},
    String? parentFileId,
  }) async {
    await initialize();

    final file = File(filePath);
    if (!await file.exists()) {
      throw ArgumentError('File does not exist: $filePath');
    }

    final fileStats = await file.stat();
    final fileSize = await file.length();
    final fileId = _uuid.v4();

    // Calculate relative path from storage directory
    final storageDir = await getStorageDirectory();
    final relativePath = path.relative(filePath, from: storageDir.path);

    // Calculate checksum for integrity verification
    final checksum = await _calculateFileChecksum(file);

    final metadata = FileMetadata(
      id: fileId,
      fileName: path.basename(filePath),
      filePath: filePath,
      relativePath: relativePath,
      category: category,
      fileSize: fileSize,
      createdAt: fileStats.changed,
      modifiedAt: fileStats.modified,
      accessedAt: fileStats.accessed,
      customMetadata: Map<String, dynamic>.from(customMetadata),
      tags: List<String>.from(tags),
      parentFileId: parentFileId,
      description: description,
      isArchived: false,
      checksum: checksum,
    );

    // Store in cache and database
    _metadataCache[fileId] = metadata;
    await _saveMetadataToDatabase(metadata);
    await _saveMetadataCache();

    return metadata;
  }

  @override
  Future<FileMetadata> organizeFile({
    required String sourceFilePath,
    required FileCategory category,
    String? targetFileName,
    String? description,
    List<String> tags = const [],
    Map<String, dynamic> customMetadata = const {},
    String? parentFileId,
  }) async {
    await initialize();

    final sourceFile = File(sourceFilePath);
    if (!await sourceFile.exists()) {
      throw ArgumentError('Source file does not exist: $sourceFilePath');
    }

    // Generate target path
    final fileName = targetFileName ?? path.basename(sourceFilePath);
    final targetPath = await _generateOrganizedPath(category, fileName);

    // Ensure target directory exists
    final targetDir = Directory(path.dirname(targetPath));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // Move file to organized location
    await sourceFile.copy(targetPath);
    await sourceFile.delete();

    // Register the organized file
    return await registerFile(
      filePath: targetPath,
      category: category,
      description: description,
      tags: tags,
      customMetadata: customMetadata,
      parentFileId: parentFileId,
    );
  }

  @override
  Future<FileMetadata?> getFileMetadata(String fileId) async {
    await initialize();

    // Check cache first
    if (_metadataCache.containsKey(fileId)) {
      return _metadataCache[fileId];
    }

    // Load from database
    final metadata = await _loadMetadataFromDatabase(fileId);
    if (metadata != null) {
      _metadataCache[fileId] = metadata;
    }

    return metadata;
  }

  @override
  Future<List<FileMetadata>> getFilesByCategory(
    FileCategory category, {
    bool includeArchived = false,
  }) async {
    await initialize();

    final results = <FileMetadata>[];

    for (final metadata in _metadataCache.values) {
      if (metadata.category == category) {
        if (includeArchived || !metadata.isArchived) {
          results.add(metadata);
        }
      }
    }

    // Sort by creation date (newest first)
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return results;
  }

  @override
  Future<List<FileMetadata>> getFilesByTags(
    List<String> tags, {
    bool matchAll = false,
    bool includeArchived = false,
  }) async {
    await initialize();

    final results = <FileMetadata>[];

    for (final metadata in _metadataCache.values) {
      if (includeArchived || !metadata.isArchived) {
        final hasMatchingTags = matchAll
            ? tags.every((tag) => metadata.tags.contains(tag))
            : tags.any((tag) => metadata.tags.contains(tag));

        if (hasMatchingTags) {
          results.add(metadata);
        }
      }
    }

    return results;
  }

  @override
  Future<List<FileMetadata>> searchFiles({
    String? query,
    List<FileCategory>? categories,
    List<String>? tags,
    DateTime? createdAfter,
    DateTime? createdBefore,
    int? minSize,
    int? maxSize,
    bool includeArchived = false,
  }) async {
    await initialize();

    final results = <FileMetadata>[];

    for (final metadata in _metadataCache.values) {
      if (!includeArchived && metadata.isArchived) {
        continue;
      }

      // Category filter
      if (categories != null && !categories.contains(metadata.category)) {
        continue;
      }

      // Tag filter
      if (tags != null && tags.isNotEmpty) {
        final hasMatchingTags = tags.any((tag) => metadata.tags.contains(tag));
        if (!hasMatchingTags) {
          continue;
        }
      }

      // Date filters
      if (createdAfter != null && metadata.createdAt.isBefore(createdAfter)) {
        continue;
      }
      if (createdBefore != null && metadata.createdAt.isAfter(createdBefore)) {
        continue;
      }

      // Size filters
      if (minSize != null && metadata.fileSize < minSize) {
        continue;
      }
      if (maxSize != null && metadata.fileSize > maxSize) {
        continue;
      }

      // Query filter (search in filename and description)
      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        final matchesFileName = metadata.fileName.toLowerCase().contains(
              queryLower,
            );
        final matchesDescription =
            metadata.description?.toLowerCase().contains(queryLower) ?? false;

        if (!matchesFileName && !matchesDescription) {
          continue;
        }
      }

      results.add(metadata);
    }

    // Sort by relevance (exact matches first, then by date)
    if (query != null && query.isNotEmpty) {
      results.sort((a, b) {
        final aExact = a.fileName.toLowerCase() == query.toLowerCase();
        final bExact = b.fileName.toLowerCase() == query.toLowerCase();

        if (aExact && !bExact) return -1;
        if (!aExact && bExact) return 1;

        return b.createdAt.compareTo(a.createdAt);
      });
    } else {
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return results;
  }

  @override
  Future<FileMetadata> updateFileMetadata(
    String fileId, {
    String? description,
    List<String>? tags,
    Map<String, dynamic>? customMetadata,
    bool? isArchived,
  }) async {
    await initialize();

    final existing = await getFileMetadata(fileId);
    if (existing == null) {
      throw ArgumentError('File metadata not found: $fileId');
    }

    final updated = existing.copyWith(
      description: description,
      tags: tags,
      customMetadata: customMetadata,
      isArchived: isArchived,
      modifiedAt: DateTime.now(),
    );

    _metadataCache[fileId] = updated;
    await _saveMetadataToDatabase(updated);
    await _saveMetadataCache();

    return updated;
  }

  @override
  Future<void> archiveFile(String fileId) async {
    await updateFileMetadata(fileId, isArchived: true);
  }

  @override
  Future<void> restoreFile(String fileId) async {
    await updateFileMetadata(fileId, isArchived: false);
  }

  @override
  Future<void> deleteFile(String fileId, {bool deleteFromDisk = true}) async {
    await initialize();

    final metadata = await getFileMetadata(fileId);
    if (metadata == null) return;

    if (deleteFromDisk) {
      final file = File(metadata.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    _metadataCache.remove(fileId);
    await _deleteMetadataFromDatabase(fileId);
    await _saveMetadataCache();
  }

  @override
  Future<StorageStats> getStorageStats() async {
    await initialize();

    final categoryStats = <FileCategory, CategoryStats>{};
    int totalFiles = 0;
    int totalSize = 0;
    int archivedFiles = 0;
    int archivedSize = 0;

    // Initialize category stats
    for (final category in FileCategory.values) {
      categoryStats[category] = const CategoryStats(
        fileCount: 0,
        totalSize: 0,
        archivedCount: 0,
        archivedSize: 0,
      );
    }

    // Process all files
    for (final metadata in _metadataCache.values) {
      totalFiles++;
      totalSize += metadata.fileSize;

      if (metadata.isArchived) {
        archivedFiles++;
        archivedSize += metadata.fileSize;
      }

      // Update category stats
      final currentStats = categoryStats[metadata.category]!;
      categoryStats[metadata.category] = CategoryStats(
        fileCount: currentStats.fileCount + 1,
        totalSize: currentStats.totalSize + metadata.fileSize,
        archivedCount:
            currentStats.archivedCount + (metadata.isArchived ? 1 : 0),
        archivedSize: currentStats.archivedSize +
            (metadata.isArchived ? metadata.fileSize : 0),
        oldestFile: currentStats.oldestFile == null
            ? metadata.createdAt
            : (metadata.createdAt.isBefore(currentStats.oldestFile!)
                ? metadata.createdAt
                : currentStats.oldestFile),
        newestFile: currentStats.newestFile == null
            ? metadata.createdAt
            : (metadata.createdAt.isAfter(currentStats.newestFile!)
                ? metadata.createdAt
                : currentStats.newestFile),
        commonExtensions: _updateCommonExtensions(
          currentStats.commonExtensions,
          metadata.extension,
        ),
      );
    }

    return StorageStats(
      categoryStats: categoryStats,
      totalFiles: totalFiles,
      totalSize: totalSize,
      archivedFiles: archivedFiles,
      archivedSize: archivedSize,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<void> cleanupCache({Duration? olderThan}) async {
    await initialize();

    final cutoffDate = DateTime.now().subtract(
      olderThan ?? const Duration(days: 7),
    );
    final cacheFiles = await getFilesByCategory(FileCategory.cache);

    for (final metadata in cacheFiles) {
      if (metadata.createdAt.isBefore(cutoffDate)) {
        await deleteFile(metadata.id);
      }
    }
  }

  @override
  Future<List<String>> verifyIntegrity() async {
    await initialize();

    final issues = <String>[];

    for (final metadata in _metadataCache.values) {
      final file = File(metadata.filePath);

      // Check if file exists
      if (!await file.exists()) {
        issues.add('File missing: ${metadata.fileName} (${metadata.id})');
        continue;
      }

      // Check file size
      final currentSize = await file.length();
      if (currentSize != metadata.fileSize) {
        issues.add(
          'Size mismatch: ${metadata.fileName} (expected: ${metadata.fileSize}, actual: $currentSize)',
        );
      }

      // Check checksum if available
      if (metadata.checksum != null) {
        final currentChecksum = await _calculateFileChecksum(file);
        if (currentChecksum != metadata.checksum) {
          issues.add(
            'Checksum mismatch: ${metadata.fileName} (file may be corrupted)',
          );
        }
      }
    }

    return issues;
  }

  @override
  Future<String> createMetadataBackup() async {
    await initialize();

    final storageDir = await getStorageDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupPath = path.join(
      storageDir.path,
      '$_backupPrefix$timestamp.json',
    );

    final backupData = {
      'version': '1.0',
      'created': DateTime.now().toIso8601String(),
      'metadata': _metadataCache.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    };

    final backupFile = File(backupPath);
    await backupFile.writeAsString(jsonEncode(backupData));

    return backupPath;
  }

  @override
  Future<void> restoreMetadataBackup(String backupPath) async {
    final backupFile = File(backupPath);
    if (!await backupFile.exists()) {
      throw ArgumentError('Backup file does not exist: $backupPath');
    }

    final backupContent = await backupFile.readAsString();
    final backupData = jsonDecode(backupContent) as Map<String, dynamic>;

    final metadataMap = backupData['metadata'] as Map<String, dynamic>;
    _metadataCache.clear();

    for (final entry in metadataMap.entries) {
      final metadata = FileMetadata.fromJson(
        entry.value as Map<String, dynamic>,
      );
      _metadataCache[entry.key] = metadata;
      await _saveMetadataToDatabase(metadata);
    }

    await _saveMetadataCache();
  }

  @override
  Future<List<CleanupRecommendation>> getCleanupRecommendations() async {
    await initialize();

    final recommendations = <CleanupRecommendation>[];
    final now = DateTime.now();

    // Old cache files
    final oldCacheFiles = _metadataCache.values
        .where(
          (m) =>
              m.category == FileCategory.cache &&
              m.createdAt.isBefore(now.subtract(const Duration(days: 7))),
        )
        .toList();

    if (oldCacheFiles.isNotEmpty) {
      final totalSize = oldCacheFiles.fold<int>(
        0,
        (sum, m) => sum + m.fileSize,
      );
      recommendations.add(
        CleanupRecommendation(
          id: 'old_cache',
          title: 'Remove old cache files',
          description:
              'Delete cache files older than 7 days (${oldCacheFiles.length} files)',
          type: CleanupType.deleteOldCache,
          affectedFileIds: oldCacheFiles.map((m) => m.id).toList(),
          estimatedSavings: totalSize,
          priority: CleanupPriority.medium,
        ),
      );
    }

    // Old export files
    final oldExportFiles = _metadataCache.values
        .where(
          (m) =>
              m.category == FileCategory.exports &&
              m.createdAt.isBefore(now.subtract(const Duration(days: 30))),
        )
        .toList();

    if (oldExportFiles.isNotEmpty) {
      final totalSize = oldExportFiles.fold<int>(
        0,
        (sum, m) => sum + m.fileSize,
      );
      recommendations.add(
        CleanupRecommendation(
          id: 'old_exports',
          title: 'Remove old export files',
          description:
              'Delete export files older than 30 days (${oldExportFiles.length} files)',
          type: CleanupType.deleteOldExports,
          affectedFileIds: oldExportFiles.map((m) => m.id).toList(),
          estimatedSavings: totalSize,
          priority: CleanupPriority.low,
        ),
      );
    }

    return recommendations;
  }

  @override
  Future<void> executeCleanup(List<String> recommendationIds) async {
    final recommendations = await getCleanupRecommendations();

    for (final recommendation in recommendations) {
      if (recommendationIds.contains(recommendation.id)) {
        for (final fileId in recommendation.affectedFileIds) {
          await deleteFile(fileId);
        }
      }
    }
  }

  // Private helper methods

  Future<String> _generateOrganizedPath(
    FileCategory category,
    String fileName,
  ) async {
    final categoryDir = await getCategoryDirectory(category);

    // For recordings, use year/month subdirectory structure
    if (category == FileCategory.recordings) {
      final now = DateTime.now();
      final yearDir = Directory(
        path.join(categoryDir.path, now.year.toString()),
      );
      final monthDir = Directory(
        path.join(yearDir.path, now.month.toString().padLeft(2, '0')),
      );

      if (!await monthDir.exists()) {
        await monthDir.create(recursive: true);
      }

      return path.join(monthDir.path, fileName);
    }

    return path.join(categoryDir.path, fileName);
  }

  Future<String> _calculateFileChecksum(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  Future<void> _loadMetadataCache() async {
    final storageDir = await getStorageDirectory();
    final metadataFile = File(path.join(storageDir.path, _metadataFileName));

    if (await metadataFile.exists()) {
      try {
        final content = await metadataFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;

        _metadataCache.clear();
        for (final entry in data.entries) {
          final metadata = FileMetadata.fromJson(
            entry.value as Map<String, dynamic>,
          );
          _metadataCache[entry.key] = metadata;
        }
      } catch (e) {
        // If cache is corrupted, start fresh
        _metadataCache.clear();
      }
    }
  }

  Future<void> _saveMetadataCache() async {
    final storageDir = await getStorageDirectory();
    final metadataFile = File(path.join(storageDir.path, _metadataFileName));

    final data = _metadataCache.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    await metadataFile.writeAsString(jsonEncode(data));
  }

  Future<void> _saveMetadataToDatabase(FileMetadata metadata) async {
    // Store metadata in JSON format for future database integration
    // For now, metadata is persisted via the JSON cache file
  }

  Future<FileMetadata?> _loadMetadataFromDatabase(String fileId) async {
    // Load metadata from JSON cache for now
    // Future enhancement: integrate with DatabaseHelper for persistent storage
    return _metadataCache[fileId];
  }

  Future<void> _deleteMetadataFromDatabase(String fileId) async {
    // Remove from cache for now
    // Future enhancement: integrate with DatabaseHelper for persistent deletion
    _metadataCache.remove(fileId);
  }

  List<String> _updateCommonExtensions(
    List<String> current,
    String newExtension,
  ) {
    final extensions = List<String>.from(current);
    if (!extensions.contains(newExtension)) {
      extensions.add(newExtension);
    }
    return extensions;
  }
}
