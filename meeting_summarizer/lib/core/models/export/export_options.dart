import '../../enums/export_format.dart';
import '../../enums/compression_level.dart';
import '../storage/file_category.dart';

/// Configuration options for export operations
class ExportOptions {
  /// Target export format
  final ExportFormat format;

  /// Include actual files in export (vs metadata only)
  final bool includeFiles;

  /// Maintain original directory structure
  final bool maintainStructure;

  /// Compression level for archive formats
  final CompressionLevel compression;

  /// Specific metadata fields to include (null = all fields)
  final List<ExportField>? fields;

  /// Custom output file path
  final String? outputPath;

  /// Custom filename prefix
  final String? filenamePrefix;

  /// Maximum file size limit in bytes
  final int? maxSizeBytes;

  /// Split large exports into multiple files
  final bool splitLargeFiles;

  /// Include file checksums for integrity verification
  final bool includeChecksums;

  /// Include export metadata (timestamp, options, etc.)
  final bool includeExportMetadata;

  /// Date range filter for exports
  final DateRange? dateRange;

  /// Categories to include in export
  final List<FileCategory>? categories;

  /// Tags to filter by
  final List<String>? tags;

  const ExportOptions({
    required this.format,
    this.includeFiles = true,
    this.maintainStructure = true,
    this.compression = CompressionLevel.balanced,
    this.fields,
    this.outputPath,
    this.filenamePrefix,
    this.maxSizeBytes,
    this.splitLargeFiles = false,
    this.includeChecksums = true,
    this.includeExportMetadata = true,
    this.dateRange,
    this.categories,
    this.tags,
  });

  /// Create a copy with modified options
  ExportOptions copyWith({
    ExportFormat? format,
    bool? includeFiles,
    bool? maintainStructure,
    CompressionLevel? compression,
    List<ExportField>? fields,
    String? outputPath,
    String? filenamePrefix,
    int? maxSizeBytes,
    bool? splitLargeFiles,
    bool? includeChecksums,
    bool? includeExportMetadata,
    DateRange? dateRange,
    List<FileCategory>? categories,
    List<String>? tags,
  }) {
    return ExportOptions(
      format: format ?? this.format,
      includeFiles: includeFiles ?? this.includeFiles,
      maintainStructure: maintainStructure ?? this.maintainStructure,
      compression: compression ?? this.compression,
      fields: fields ?? this.fields,
      outputPath: outputPath ?? this.outputPath,
      filenamePrefix: filenamePrefix ?? this.filenamePrefix,
      maxSizeBytes: maxSizeBytes ?? this.maxSizeBytes,
      splitLargeFiles: splitLargeFiles ?? this.splitLargeFiles,
      includeChecksums: includeChecksums ?? this.includeChecksums,
      includeExportMetadata:
          includeExportMetadata ?? this.includeExportMetadata,
      dateRange: dateRange ?? this.dateRange,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
    );
  }

  /// Create JSON representation
  Map<String, dynamic> toJson() {
    return {
      'format': format.value,
      'includeFiles': includeFiles,
      'maintainStructure': maintainStructure,
      'compression': compression.level,
      'fields': fields?.map((f) => f.value).toList(),
      'outputPath': outputPath,
      'filenamePrefix': filenamePrefix,
      'maxSizeBytes': maxSizeBytes,
      'splitLargeFiles': splitLargeFiles,
      'includeChecksums': includeChecksums,
      'includeExportMetadata': includeExportMetadata,
      'dateRange': dateRange?.toJson(),
      'categories': categories?.map((c) => c.directoryName).toList(),
      'tags': tags,
    };
  }

  /// Create from JSON representation
  factory ExportOptions.fromJson(Map<String, dynamic> json) {
    return ExportOptions(
      format: ExportFormat.fromString(json['format']),
      includeFiles: json['includeFiles'] ?? true,
      maintainStructure: json['maintainStructure'] ?? true,
      compression: CompressionLevel.fromLevel(json['compression'] ?? 6),
      fields: (json['fields'] as List<dynamic>?)
          ?.map((f) => ExportField.fromString(f))
          .toList(),
      outputPath: json['outputPath'],
      filenamePrefix: json['filenamePrefix'],
      maxSizeBytes: json['maxSizeBytes'],
      splitLargeFiles: json['splitLargeFiles'] ?? false,
      includeChecksums: json['includeChecksums'] ?? true,
      includeExportMetadata: json['includeExportMetadata'] ?? true,
      dateRange: json['dateRange'] != null
          ? DateRange.fromJson(json['dateRange'])
          : null,
      categories: (json['categories'] as List<dynamic>?)
          ?.map((c) => FileCategory.fromString(c))
          .toList(),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
    );
  }

  /// Default options for different export scenarios
  static const ExportOptions defaultMetadataOnly = ExportOptions(
    format: ExportFormat.json,
    includeFiles: false,
    compression: CompressionLevel.none,
  );

  static const ExportOptions defaultFullExport = ExportOptions(
    format: ExportFormat.zip,
    includeFiles: true,
    compression: CompressionLevel.balanced,
    maintainStructure: true,
  );

  static const ExportOptions defaultAnalytics = ExportOptions(
    format: ExportFormat.csv,
    includeFiles: false,
    compression: CompressionLevel.none,
  );

  static const ExportOptions defaultReport = ExportOptions(
    format: ExportFormat.pdf,
    includeFiles: false,
    compression: CompressionLevel.none,
  );
}

/// Metadata fields that can be included in exports
enum ExportField {
  /// Basic file information
  basicInfo('basic', 'Basic Information'),

  /// File properties (size, dates, etc.)
  properties('properties', 'File Properties'),

  /// Content metadata (description, tags)
  content('content', 'Content Metadata'),

  /// Categorization information
  categories('categories', 'Categories and Tags'),

  /// File relationships (parent/child)
  relationships('relationships', 'File Relationships'),

  /// System metadata (checksum, paths)
  system('system', 'System Information'),

  /// Custom user-defined metadata
  custom('custom', 'Custom Metadata'),

  /// Audio-specific properties
  audio('audio', 'Audio Properties'),

  /// Transcription data
  transcription('transcription', 'Transcription Content'),

  /// Summary information
  summary('summary', 'Summary Data');

  const ExportField(this.value, this.displayName);

  /// Internal field identifier
  final String value;

  /// User-friendly display name
  final String displayName;

  /// Get export field from string value
  static ExportField fromString(String value) {
    return ExportField.values.firstWhere(
      (field) => field.value == value,
      orElse: () => throw ArgumentError('Unknown export field: $value'),
    );
  }

  /// Get all available fields
  static List<ExportField> get all => ExportField.values;

  /// Get essential fields for basic exports
  static List<ExportField> get essential => [
    ExportField.basicInfo,
    ExportField.properties,
    ExportField.categories,
  ];
}

/// Date range specification for filtered exports
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});

  /// Check if a date falls within this range
  bool contains(DateTime date) {
    return date.isAfter(start) && date.isBefore(end);
  }

  /// Duration of the date range
  Duration get duration => end.difference(start);

  /// Create JSON representation
  Map<String, dynamic> toJson() {
    return {'start': start.toIso8601String(), 'end': end.toIso8601String()};
  }

  /// Create from JSON representation
  factory DateRange.fromJson(Map<String, dynamic> json) {
    return DateRange(
      start: DateTime.parse(json['start']),
      end: DateTime.parse(json['end']),
    );
  }

  /// Common date range presets
  static DateRange get lastWeek {
    final now = DateTime.now();
    return DateRange(start: now.subtract(const Duration(days: 7)), end: now);
  }

  static DateRange get lastMonth {
    final now = DateTime.now();
    return DateRange(
      start: DateTime(now.year, now.month - 1, now.day),
      end: now,
    );
  }

  static DateRange get lastYear {
    final now = DateTime.now();
    return DateRange(
      start: DateTime(now.year - 1, now.month, now.day),
      end: now,
    );
  }
}
