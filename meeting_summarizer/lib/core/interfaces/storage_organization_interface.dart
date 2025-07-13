import 'dart:io';
import '../models/storage/file_category.dart';
import '../models/storage/file_metadata.dart';
import '../models/storage/storage_stats.dart';

/// Interface for storage organization operations
abstract class StorageOrganizationInterface {
  /// Initialize the storage organization system
  Future<void> initialize();

  /// Get the base storage directory
  Future<Directory> getStorageDirectory();

  /// Get directory for a specific category
  Future<Directory> getCategoryDirectory(FileCategory category);

  /// Create organized directory structure
  Future<void> createDirectoryStructure();

  /// Register a file in the organization system
  Future<FileMetadata> registerFile({
    required String filePath,
    required FileCategory category,
    String? description,
    List<String> tags = const [],
    Map<String, dynamic> customMetadata = const {},
    String? parentFileId,
  });

  /// Move a file to the appropriate organized location
  Future<FileMetadata> organizeFile({
    required String sourceFilePath,
    required FileCategory category,
    String? targetFileName,
    String? description,
    List<String> tags = const [],
    Map<String, dynamic> customMetadata = const {},
    String? parentFileId,
  });

  /// Get file metadata by ID
  Future<FileMetadata?> getFileMetadata(String fileId);

  /// Get all files in a category
  Future<List<FileMetadata>> getFilesByCategory(
    FileCategory category, {
    bool includeArchived = false,
  });

  /// Get files by tags
  Future<List<FileMetadata>> getFilesByTags(
    List<String> tags, {
    bool matchAll = false,
    bool includeArchived = false,
  });

  /// Search files by various criteria
  Future<List<FileMetadata>> searchFiles({
    String? query,
    List<FileCategory>? categories,
    List<String>? tags,
    DateTime? createdAfter,
    DateTime? createdBefore,
    int? minSize,
    int? maxSize,
    bool includeArchived = false,
  });

  /// Update file metadata
  Future<FileMetadata> updateFileMetadata(
    String fileId, {
    String? description,
    List<String>? tags,
    Map<String, dynamic>? customMetadata,
    bool? isArchived,
  });

  /// Archive a file (soft delete)
  Future<void> archiveFile(String fileId);

  /// Restore an archived file
  Future<void> restoreFile(String fileId);

  /// Permanently delete a file
  Future<void> deleteFile(String fileId, {bool deleteFromDisk = true});

  /// Get storage statistics
  Future<StorageStats> getStorageStats();

  /// Clean up temporary and cache files
  Future<void> cleanupCache({Duration? olderThan});

  /// Verify file integrity (check if files exist and match metadata)
  Future<List<String>> verifyIntegrity();

  /// Create a backup of file metadata
  Future<String> createMetadataBackup();

  /// Restore file metadata from backup
  Future<void> restoreMetadataBackup(String backupPath);

  /// Get recommended cleanup actions
  Future<List<CleanupRecommendation>> getCleanupRecommendations();

  /// Execute cleanup recommendations
  Future<void> executeCleanup(List<String> recommendationIds);
}

/// Cleanup recommendation for storage optimization
class CleanupRecommendation {
  final String id;
  final String title;
  final String description;
  final CleanupType type;
  final List<String> affectedFileIds;
  final int estimatedSavings;
  final CleanupPriority priority;

  const CleanupRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.affectedFileIds,
    required this.estimatedSavings,
    required this.priority,
  });

  /// Get formatted estimated savings
  String get formattedSavings {
    if (estimatedSavings < 1024) return '$estimatedSavings B';
    if (estimatedSavings < 1024 * 1024) {
      return '${(estimatedSavings / 1024).toStringAsFixed(1)} KB';
    }
    if (estimatedSavings < 1024 * 1024 * 1024) {
      return '${(estimatedSavings / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(estimatedSavings / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Types of cleanup operations
enum CleanupType {
  deleteOldCache,
  deleteOldExports,
  archiveOldFiles,
  removeDuplicates,
  compressLargeFiles,
}

/// Priority levels for cleanup recommendations
enum CleanupPriority { low, medium, high, critical }
