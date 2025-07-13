import 'file_category.dart';

/// Storage statistics and analytics
class StorageStats {
  final Map<FileCategory, CategoryStats> categoryStats;
  final int totalFiles;
  final int totalSize;
  final int archivedFiles;
  final int archivedSize;
  final DateTime lastUpdated;

  const StorageStats({
    required this.categoryStats,
    required this.totalFiles,
    required this.totalSize,
    required this.archivedFiles,
    required this.archivedSize,
    required this.lastUpdated,
  });

  /// Get statistics for a specific category
  CategoryStats? getCategoryStats(FileCategory category) {
    return categoryStats[category];
  }

  /// Get total size in a human-readable format
  String get formattedTotalSize => _formatBytes(totalSize);

  /// Get archived size in a human-readable format
  String get formattedArchivedSize => _formatBytes(archivedSize);

  /// Get active (non-archived) size
  int get activeSize => totalSize - archivedSize;

  /// Get active size in a human-readable format
  String get formattedActiveSize => _formatBytes(activeSize);

  /// Get active (non-archived) file count
  int get activeFiles => totalFiles - archivedFiles;

  /// Get largest categories by size
  List<MapEntry<FileCategory, CategoryStats>> getLargestCategories({
    int limit = 5,
  }) {
    final entries = categoryStats.entries.toList();
    entries.sort((a, b) => b.value.totalSize.compareTo(a.value.totalSize));
    return entries.take(limit).toList();
  }

  /// Get categories with most files
  List<MapEntry<FileCategory, CategoryStats>> getCategoriesWithMostFiles({
    int limit = 5,
  }) {
    final entries = categoryStats.entries.toList();
    entries.sort((a, b) => b.value.fileCount.compareTo(a.value.fileCount));
    return entries.take(limit).toList();
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'categoryStats': categoryStats.map(
        (key, value) => MapEntry(key.name, value.toJson()),
      ),
      'totalFiles': totalFiles,
      'totalSize': totalSize,
      'archivedFiles': archivedFiles,
      'archivedSize': archivedSize,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Create from JSON
  factory StorageStats.fromJson(Map<String, dynamic> json) {
    final categoryStatsMap = <FileCategory, CategoryStats>{};
    final categoryStatsJson = json['categoryStats'] as Map<String, dynamic>;

    for (final entry in categoryStatsJson.entries) {
      try {
        final category = FileCategory.values.byName(entry.key);
        final stats = CategoryStats.fromJson(
          entry.value as Map<String, dynamic>,
        );
        categoryStatsMap[category] = stats;
      } catch (e) {
        // Skip unknown categories
      }
    }

    return StorageStats(
      categoryStats: categoryStatsMap,
      totalFiles: json['totalFiles'] as int,
      totalSize: json['totalSize'] as int,
      archivedFiles: json['archivedFiles'] as int,
      archivedSize: json['archivedSize'] as int,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Statistics for a specific file category
class CategoryStats {
  final int fileCount;
  final int totalSize;
  final int archivedCount;
  final int archivedSize;
  final DateTime? oldestFile;
  final DateTime? newestFile;
  final List<String> commonExtensions;

  const CategoryStats({
    required this.fileCount,
    required this.totalSize,
    required this.archivedCount,
    required this.archivedSize,
    this.oldestFile,
    this.newestFile,
    this.commonExtensions = const [],
  });

  /// Get active (non-archived) file count
  int get activeCount => fileCount - archivedCount;

  /// Get active (non-archived) size
  int get activeSize => totalSize - archivedSize;

  /// Get formatted total size
  String get formattedTotalSize => StorageStats._formatBytes(totalSize);

  /// Get formatted active size
  String get formattedActiveSize => StorageStats._formatBytes(activeSize);

  /// Get formatted archived size
  String get formattedArchivedSize => StorageStats._formatBytes(archivedSize);

  /// Average file size
  double get averageFileSize => fileCount > 0 ? totalSize / fileCount : 0;

  /// Get formatted average file size
  String get formattedAverageFileSize =>
      StorageStats._formatBytes(averageFileSize.round());

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'fileCount': fileCount,
      'totalSize': totalSize,
      'archivedCount': archivedCount,
      'archivedSize': archivedSize,
      'oldestFile': oldestFile?.toIso8601String(),
      'newestFile': newestFile?.toIso8601String(),
      'commonExtensions': commonExtensions,
    };
  }

  /// Create from JSON
  factory CategoryStats.fromJson(Map<String, dynamic> json) {
    return CategoryStats(
      fileCount: json['fileCount'] as int,
      totalSize: json['totalSize'] as int,
      archivedCount: json['archivedCount'] as int,
      archivedSize: json['archivedSize'] as int,
      oldestFile: json['oldestFile'] != null
          ? DateTime.parse(json['oldestFile'] as String)
          : null,
      newestFile: json['newestFile'] != null
          ? DateTime.parse(json['newestFile'] as String)
          : null,
      commonExtensions: List<String>.from(
        json['commonExtensions'] as List? ?? [],
      ),
    );
  }
}
