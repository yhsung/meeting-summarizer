import '../../enums/export_format.dart';
import 'export_options.dart';

/// Result of an export operation
class ExportResult {
  /// Whether the export was successful
  final bool success;

  /// Path to the exported file(s)
  final List<String> outputPaths;

  /// Export format used
  final ExportFormat format;

  /// Export options that were applied
  final ExportOptions options;

  /// Number of files processed
  final int fileCount;

  /// Total size of exported data in bytes
  final int totalSizeBytes;

  /// Time taken for the export operation
  final Duration processingTime;

  /// Error message if export failed
  final String? errorMessage;

  /// Detailed error stack trace for debugging
  final String? stackTrace;

  /// Export metadata and statistics
  final ExportMetadata metadata;

  /// Warnings encountered during export
  final List<String> warnings;

  const ExportResult({
    required this.success,
    required this.outputPaths,
    required this.format,
    required this.options,
    required this.fileCount,
    required this.totalSizeBytes,
    required this.processingTime,
    this.errorMessage,
    this.stackTrace,
    required this.metadata,
    this.warnings = const [],
  });

  /// Create a successful export result
  factory ExportResult.success({
    required List<String> outputPaths,
    required ExportFormat format,
    required ExportOptions options,
    required int fileCount,
    required int totalSizeBytes,
    required Duration processingTime,
    required ExportMetadata metadata,
    List<String> warnings = const [],
  }) {
    return ExportResult(
      success: true,
      outputPaths: outputPaths,
      format: format,
      options: options,
      fileCount: fileCount,
      totalSizeBytes: totalSizeBytes,
      processingTime: processingTime,
      metadata: metadata,
      warnings: warnings,
    );
  }

  /// Create a failed export result
  factory ExportResult.failure({
    required ExportFormat format,
    required ExportOptions options,
    required String errorMessage,
    String? stackTrace,
    Duration? processingTime,
  }) {
    return ExportResult(
      success: false,
      outputPaths: [],
      format: format,
      options: options,
      fileCount: 0,
      totalSizeBytes: 0,
      processingTime: processingTime ?? Duration.zero,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
      metadata: ExportMetadata.empty(),
      warnings: [],
    );
  }

  /// Check if export has warnings
  bool get hasWarnings => warnings.isNotEmpty;

  /// Check if export was partial (some files failed)
  bool get isPartialSuccess => success && hasWarnings;

  /// Get compression ratio achieved (if applicable)
  double? get compressionRatio {
    if (metadata.originalSizeBytes > 0) {
      return totalSizeBytes / metadata.originalSizeBytes;
    }
    return null;
  }

  /// Get processing speed in MB/s
  double get processingSpeedMBps {
    if (processingTime.inMilliseconds > 0) {
      final mbProcessed = totalSizeBytes / (1024 * 1024);
      final secondsTaken = processingTime.inMilliseconds / 1000;
      return mbProcessed / secondsTaken;
    }
    return 0.0;
  }

  /// Create JSON representation
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'outputPaths': outputPaths,
      'format': format.value,
      'options': options.toJson(),
      'fileCount': fileCount,
      'totalSizeBytes': totalSizeBytes,
      'processingTimeMs': processingTime.inMilliseconds,
      'errorMessage': errorMessage,
      'metadata': metadata.toJson(),
      'warnings': warnings,
      'compressionRatio': compressionRatio,
      'processingSpeedMBps': processingSpeedMBps,
    };
  }

  /// Create from JSON representation
  factory ExportResult.fromJson(Map<String, dynamic> json) {
    return ExportResult(
      success: json['success'],
      outputPaths: (json['outputPaths'] as List).cast<String>(),
      format: ExportFormat.fromString(json['format']),
      options: ExportOptions.fromJson(json['options']),
      fileCount: json['fileCount'],
      totalSizeBytes: json['totalSizeBytes'],
      processingTime: Duration(milliseconds: json['processingTimeMs']),
      errorMessage: json['errorMessage'],
      metadata: ExportMetadata.fromJson(json['metadata']),
      warnings: (json['warnings'] as List).cast<String>(),
    );
  }

  @override
  String toString() {
    if (success) {
      return 'ExportResult(success: $fileCount files, ${(totalSizeBytes / 1024 / 1024).toStringAsFixed(2)} MB, ${processingTime.inMilliseconds}ms)';
    } else {
      return 'ExportResult(failed: $errorMessage)';
    }
  }
}

/// Metadata about the export operation
class ExportMetadata {
  /// Timestamp when export was created
  final DateTime timestamp;

  /// Version of the export system
  final String exportVersion;

  /// Original total size before compression
  final int originalSizeBytes;

  /// Categories included in export
  final Map<String, int> categoryCounts;

  /// File type distribution
  final Map<String, int> extensionCounts;

  /// Export source information
  final ExportSource source;

  /// Checksum of exported content (if available)
  final String? contentChecksum;

  /// Additional custom metadata
  final Map<String, dynamic> customData;

  const ExportMetadata({
    required this.timestamp,
    required this.exportVersion,
    required this.originalSizeBytes,
    required this.categoryCounts,
    required this.extensionCounts,
    required this.source,
    this.contentChecksum,
    this.customData = const {},
  });

  /// Create empty metadata
  factory ExportMetadata.empty() {
    return ExportMetadata(
      timestamp: DateTime.now(),
      exportVersion: '1.0.0',
      originalSizeBytes: 0,
      categoryCounts: {},
      extensionCounts: {},
      source: ExportSource.manual,
    );
  }

  /// Create metadata for file export
  factory ExportMetadata.forFiles({
    required List<Map<String, dynamic>> files,
    required ExportSource source,
    String? checksum,
  }) {
    final categoryCounts = <String, int>{};
    final extensionCounts = <String, int>{};
    int totalSize = 0;

    for (final file in files) {
      // Count categories
      final category = file['category'] ?? 'unknown';
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;

      // Count extensions
      final extension = file['extension'] ?? '.unknown';
      extensionCounts[extension] = (extensionCounts[extension] ?? 0) + 1;

      // Sum file sizes
      totalSize += (file['fileSize'] ?? 0) as int;
    }

    return ExportMetadata(
      timestamp: DateTime.now(),
      exportVersion: '1.0.0',
      originalSizeBytes: totalSize,
      categoryCounts: categoryCounts,
      extensionCounts: extensionCounts,
      source: source,
      contentChecksum: checksum,
    );
  }

  /// Create JSON representation
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'exportVersion': exportVersion,
      'originalSizeBytes': originalSizeBytes,
      'categoryCounts': categoryCounts,
      'extensionCounts': extensionCounts,
      'source': source.value,
      'contentChecksum': contentChecksum,
      'customData': customData,
    };
  }

  /// Create from JSON representation
  factory ExportMetadata.fromJson(Map<String, dynamic> json) {
    return ExportMetadata(
      timestamp: DateTime.parse(json['timestamp']),
      exportVersion: json['exportVersion'],
      originalSizeBytes: json['originalSizeBytes'],
      categoryCounts: Map<String, int>.from(json['categoryCounts']),
      extensionCounts: Map<String, int>.from(json['extensionCounts']),
      source: ExportSource.fromString(json['source']),
      contentChecksum: json['contentChecksum'],
      customData: Map<String, dynamic>.from(json['customData'] ?? {}),
    );
  }
}

/// Source of the export operation
enum ExportSource {
  /// Manual export initiated by user
  manual('manual', 'Manual Export'),

  /// Scheduled/automated export
  scheduled('scheduled', 'Scheduled Export'),

  /// Export from search results
  search('search', 'Search Results Export'),

  /// Backup operation export
  backup('backup', 'Backup Export'),

  /// Bulk operation export
  bulk('bulk', 'Bulk Export'),

  /// API-triggered export
  api('api', 'API Export');

  const ExportSource(this.value, this.displayName);

  /// Internal source identifier
  final String value;

  /// User-friendly display name
  final String displayName;

  /// Get export source from string value
  static ExportSource fromString(String value) {
    return ExportSource.values.firstWhere(
      (source) => source.value == value,
      orElse: () => ExportSource.manual,
    );
  }
}
