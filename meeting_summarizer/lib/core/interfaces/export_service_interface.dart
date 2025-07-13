import '../models/export/export_options.dart';
import '../models/export/export_result.dart';
import '../models/storage/file_category.dart';
import '../enums/export_format.dart';
import '../services/advanced_search_service.dart' show SearchQuery;

/// Interface for export services supporting multiple file formats
abstract class ExportServiceInterface {
  /// Export a single file by ID
  Future<ExportResult> exportSingleFile(String fileId, ExportOptions options);

  /// Export multiple files by their IDs
  Future<ExportResult> exportMultipleFiles(
    List<String> fileIds,
    ExportOptions options,
  );

  /// Export all files in a specific category
  Future<ExportResult> exportCategory(
    FileCategory category,
    ExportOptions options,
  );

  /// Export search results from a search query
  Future<ExportResult> exportSearchResults(
    SearchQuery query,
    ExportOptions options,
  );

  /// Export files within a date range
  Future<ExportResult> exportDateRange(
    DateRange dateRange,
    ExportOptions options,
  );

  /// Export files matching specific tags
  Future<ExportResult> exportByTags(List<String> tags, ExportOptions options);

  /// Export storage statistics and analytics
  Future<ExportResult> exportStorageStats(
    ExportOptions options, {
    DateRange? dateRange,
  });

  /// Create a complete system backup
  Future<ExportResult> createSystemBackup(ExportOptions options);

  /// Get estimated export size before performing export
  Future<ExportEstimate> estimateExportSize(
    List<String> fileIds,
    ExportOptions options,
  );

  /// Cancel an ongoing export operation
  Future<bool> cancelExport(String exportId);

  /// Get progress of an ongoing export operation
  Stream<ExportProgress> getExportProgress(String exportId);

  /// Get list of supported export formats
  List<ExportFormat> getSupportedFormats();

  /// Validate export options for compatibility
  ValidationResult validateExportOptions(ExportOptions options);

  /// Clean up temporary files from failed exports
  Future<void> cleanupTemporaryFiles();
}

/// Progress information for ongoing exports
class ExportProgress {
  /// Unique identifier for the export operation
  final String exportId;

  /// Current progress percentage (0-100)
  final double progressPercentage;

  /// Number of files processed so far
  final int filesProcessed;

  /// Total number of files to process
  final int totalFiles;

  /// Current operation being performed
  final String currentOperation;

  /// Estimated time remaining
  final Duration? estimatedTimeRemaining;

  /// Total bytes processed
  final int bytesProcessed;

  /// Total bytes to process
  final int totalBytes;

  const ExportProgress({
    required this.exportId,
    required this.progressPercentage,
    required this.filesProcessed,
    required this.totalFiles,
    required this.currentOperation,
    this.estimatedTimeRemaining,
    required this.bytesProcessed,
    required this.totalBytes,
  });

  /// Check if export is complete
  bool get isComplete => progressPercentage >= 100.0;

  /// Get processing speed in files per second
  double get filesPerSecond {
    // Implementation would track timing
    return 0.0;
  }

  /// Create JSON representation
  Map<String, dynamic> toJson() {
    return {
      'exportId': exportId,
      'progressPercentage': progressPercentage,
      'filesProcessed': filesProcessed,
      'totalFiles': totalFiles,
      'currentOperation': currentOperation,
      'estimatedTimeRemainingMs': estimatedTimeRemaining?.inMilliseconds,
      'bytesProcessed': bytesProcessed,
      'totalBytes': totalBytes,
    };
  }
}

/// Estimation of export operation requirements
class ExportEstimate {
  /// Estimated output file size in bytes
  final int estimatedSizeBytes;

  /// Estimated processing time
  final Duration estimatedDuration;

  /// Number of files to be processed
  final int fileCount;

  /// Estimated compression ratio (if applicable)
  final double? compressionRatio;

  /// Memory requirements for the operation
  final int estimatedMemoryUsageBytes;

  /// Whether the export might exceed system limits
  final bool exceedsRecommendedLimits;

  /// Warnings about the export operation
  final List<String> warnings;

  const ExportEstimate({
    required this.estimatedSizeBytes,
    required this.estimatedDuration,
    required this.fileCount,
    this.compressionRatio,
    required this.estimatedMemoryUsageBytes,
    required this.exceedsRecommendedLimits,
    this.warnings = const [],
  });

  /// Get estimated size in human-readable format
  String get humanReadableSize {
    if (estimatedSizeBytes < 1024) return '$estimatedSizeBytes B';
    if (estimatedSizeBytes < 1024 * 1024) {
      return '${(estimatedSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (estimatedSizeBytes < 1024 * 1024 * 1024) {
      return '${(estimatedSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(estimatedSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Create JSON representation
  Map<String, dynamic> toJson() {
    return {
      'estimatedSizeBytes': estimatedSizeBytes,
      'estimatedDurationMs': estimatedDuration.inMilliseconds,
      'fileCount': fileCount,
      'compressionRatio': compressionRatio,
      'estimatedMemoryUsageBytes': estimatedMemoryUsageBytes,
      'exceedsRecommendedLimits': exceedsRecommendedLimits,
      'warnings': warnings,
      'humanReadableSize': humanReadableSize,
    };
  }
}

/// Validation result for export options
class ValidationResult {
  /// Whether the options are valid
  final bool isValid;

  /// Error messages for invalid options
  final List<String> errors;

  /// Warning messages for potentially problematic options
  final List<String> warnings;

  /// Suggested corrections or improvements
  final List<String> suggestions;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.suggestions = const [],
  });

  /// Create a successful validation result
  factory ValidationResult.valid({
    List<String> warnings = const [],
    List<String> suggestions = const [],
  }) {
    return ValidationResult(
      isValid: true,
      warnings: warnings,
      suggestions: suggestions,
    );
  }

  /// Create a failed validation result
  factory ValidationResult.invalid({
    required List<String> errors,
    List<String> warnings = const [],
    List<String> suggestions = const [],
  }) {
    return ValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings,
      suggestions: suggestions,
    );
  }

  /// Check if there are any issues (errors or warnings)
  bool get hasIssues => errors.isNotEmpty || warnings.isNotEmpty;

  /// Create JSON representation
  Map<String, dynamic> toJson() {
    return {
      'isValid': isValid,
      'errors': errors,
      'warnings': warnings,
      'suggestions': suggestions,
    };
  }
}
