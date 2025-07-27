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
import '../database/database_helper.dart';
import '../database/file_metadata_dao.dart';
import 'file_categorization_service.dart';

/// Enhanced storage organization service with database integration
class EnhancedStorageOrganizationService
    implements StorageOrganizationInterface {
  static const String _backupPrefix = 'metadata_backup_';

  final FileMetadataDao _metadataDao;
  final Uuid _uuid = const Uuid();

  Directory? _storageDirectory;
  bool _isInitialized = false;

  EnhancedStorageOrganizationService(DatabaseHelper databaseHelper)
      : _metadataDao = FileMetadataDao(databaseHelper);

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    _storageDirectory = await getStorageDirectory();
    await createDirectoryStructure();
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

    // Auto-generate tags using categorization service
    final autoTags = FileCategorizationService.generateAutoTags(
      filePath,
      category,
      customMetadata: customMetadata,
    );

    // Combine manual and auto tags, then validate
    final allTags = FileCategorizationService.validateTags([
      ...tags,
      ...autoTags,
    ]);

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
      tags: allTags,
      parentFileId: parentFileId,
      description: description,
      isArchived: false,
      checksum: checksum,
    );

    // Store in database
    await _metadataDao.insertOrUpdate(metadata);

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

    // Auto-categorize if not specified or use smart categorization
    final smartCategory = category == FileCategory.cache
        ? FileCategorizationService.categorizeFile(sourceFilePath)
        : category;

    // Generate target path
    final fileName = targetFileName ?? path.basename(sourceFilePath);
    final targetPath = await _generateOrganizedPath(smartCategory, fileName);

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
      category: smartCategory,
      description: description,
      tags: tags,
      customMetadata: customMetadata,
      parentFileId: parentFileId,
    );
  }

  @override
  Future<FileMetadata?> getFileMetadata(String fileId) async {
    await initialize();
    return await _metadataDao.getById(fileId);
  }

  @override
  Future<List<FileMetadata>> getFilesByCategory(
    FileCategory category, {
    bool includeArchived = false,
  }) async {
    await initialize();
    return await _metadataDao.getByCategory(
      category,
      includeArchived: includeArchived,
    );
  }

  @override
  Future<List<FileMetadata>> getFilesByTags(
    List<String> tags, {
    bool matchAll = false,
    bool includeArchived = false,
  }) async {
    await initialize();
    return await _metadataDao.getByTags(
      tags,
      matchAll: matchAll,
      includeArchived: includeArchived,
    );
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
    return await _metadataDao.search(
      query: query,
      categories: categories,
      tags: tags,
      createdAfter: createdAfter,
      createdBefore: createdBefore,
      minSize: minSize,
      maxSize: maxSize,
      includeArchived: includeArchived,
    );
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

    // Validate tags if provided
    final validatedTags = tags != null
        ? FileCategorizationService.validateTags(tags)
        : existing.tags;

    final updated = existing.copyWith(
      description: description,
      tags: validatedTags,
      customMetadata: customMetadata,
      isArchived: isArchived,
      modifiedAt: DateTime.now(),
    );

    await _metadataDao.update(updated);
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

    await _metadataDao.delete(fileId);
  }

  @override
  Future<StorageStats> getStorageStats() async {
    await initialize();

    final dbStats = await _metadataDao.getStorageStats();
    final overall = dbStats['overall'] as Map<String, dynamic>;
    final categories = dbStats['categories'] as List<Map<String, dynamic>>;

    // Build category stats map
    final categoryStatsMap = <FileCategory, CategoryStats>{};

    // Initialize all categories with zero stats
    for (final category in FileCategory.values) {
      categoryStatsMap[category] = const CategoryStats(
        fileCount: 0,
        totalSize: 0,
        archivedCount: 0,
        archivedSize: 0,
      );
    }

    // Update with actual stats from database
    for (final categoryData in categories) {
      try {
        final category = FileCategory.values.byName(
          categoryData['category'] as String,
        );
        categoryStatsMap[category] = CategoryStats(
          fileCount: categoryData['file_count'] as int,
          totalSize: categoryData['total_size'] as int,
          archivedCount: categoryData['archived_count'] as int,
          archivedSize: categoryData['archived_size'] as int,
          oldestFile: categoryData['oldest_file'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  categoryData['oldest_file'] as int,
                )
              : null,
          newestFile: categoryData['newest_file'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  categoryData['newest_file'] as int,
                )
              : null,
        );
      } catch (e) {
        // Skip unknown categories
      }
    }

    return StorageStats(
      categoryStats: categoryStatsMap,
      totalFiles: overall['total_files'] as int,
      totalSize: overall['total_size'] as int,
      archivedFiles: overall['archived_files'] as int,
      archivedSize: overall['archived_size'] as int,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<void> cleanupCache({Duration? olderThan}) async {
    await initialize();

    final cutoffDate = DateTime.now().subtract(
      olderThan ?? const Duration(days: 7),
    );
    final cacheFiles = await _metadataDao.getByCategory(FileCategory.cache);

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
    final allFiles = await searchFiles(); // Get all files

    for (final metadata in allFiles) {
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

    // Check for orphaned files
    final orphanedFiles = await _metadataDao.getOrphanedFiles();
    for (final orphan in orphanedFiles) {
      issues.add(
        'Orphaned file: ${orphan.fileName} (parent ${orphan.parentFileId} not found)',
      );
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

    // Get all metadata from database
    final allFiles = await searchFiles();
    final metadataMap = <String, Map<String, dynamic>>{};

    for (final metadata in allFiles) {
      metadataMap[metadata.id] = metadata.toJson();
    }

    final backupData = {
      'version': '2.0',
      'created': DateTime.now().toIso8601String(),
      'metadata': metadataMap,
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

    for (final entry in metadataMap.entries) {
      final metadata = FileMetadata.fromJson(
        entry.value as Map<String, dynamic>,
      );
      await _metadataDao.insertOrUpdate(metadata);
    }
  }

  @override
  Future<List<CleanupRecommendation>> getCleanupRecommendations() async {
    await initialize();

    final recommendations = <CleanupRecommendation>[];
    final now = DateTime.now();

    // Old cache files
    final oldCacheFiles = await _metadataDao.search(
      categories: [FileCategory.cache],
      createdBefore: now.subtract(const Duration(days: 7)),
    );

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
    final oldExportFiles = await _metadataDao.search(
      categories: [FileCategory.exports],
      createdBefore: now.subtract(const Duration(days: 30)),
    );

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

    // Orphaned files
    final orphanedFiles = await _metadataDao.getOrphanedFiles();
    if (orphanedFiles.isNotEmpty) {
      recommendations.add(
        CleanupRecommendation(
          id: 'orphaned_files',
          title: 'Fix orphaned file references',
          description:
              'Clean up ${orphanedFiles.length} files with missing parent references',
          type: CleanupType.removeDuplicates,
          affectedFileIds: orphanedFiles.map((m) => m.id).toList(),
          estimatedSavings:
              0, // No storage savings, but improves data integrity
          priority: CleanupPriority.high,
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
        switch (recommendation.type) {
          case CleanupType.deleteOldCache:
          case CleanupType.deleteOldExports:
            for (final fileId in recommendation.affectedFileIds) {
              await deleteFile(fileId);
            }
            break;
          case CleanupType.removeDuplicates:
            // Clean up orphaned file references
            await _metadataDao.cleanupOrphanedFiles();
            break;
          case CleanupType.archiveOldFiles:
            for (final fileId in recommendation.affectedFileIds) {
              await archiveFile(fileId);
            }
            break;
          case CleanupType.compressLargeFiles:
            // File compression not yet implemented
            break;
        }
      }
    }
  }

  /// Get smart tag suggestions for a file
  Future<List<String>> getTagSuggestions(String filePath) async {
    await initialize();

    final allFiles = await searchFiles();
    return FileCategorizationService.suggestTags(filePath, allFiles);
  }

  /// Get search suggestions based on existing data
  Future<List<String>> getSearchSuggestions({String? currentQuery}) async {
    await initialize();

    final allFiles = await searchFiles();
    return FileCategorizationService.getSearchSuggestions(
      allFiles,
      currentQuery: currentQuery,
    );
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
}
