/// Export format definitions for file export system
enum ExportFormat {
  /// JSON format - structured data with metadata
  json('json', 'JSON', 'application/json', '.json'),

  /// CSV format - tabular data for spreadsheet analysis
  csv('csv', 'CSV', 'text/csv', '.csv'),

  /// XML format - structured markup for interoperability
  xml('xml', 'XML', 'application/xml', '.xml'),

  /// PDF format - document format for reports
  pdf('pdf', 'PDF', 'application/pdf', '.pdf'),

  /// HTML format - web-viewable reports
  html('html', 'HTML', 'text/html', '.html'),

  /// ZIP format - compressed archive
  zip('zip', 'ZIP Archive', 'application/zip', '.zip'),

  /// TAR format - archive with compression
  tar('tar', 'TAR Archive', 'application/x-tar', '.tar.gz');

  const ExportFormat(
    this.value,
    this.displayName,
    this.mimeType,
    this.extension,
  );

  /// Internal format identifier
  final String value;

  /// User-friendly display name
  final String displayName;

  /// MIME type for the format
  final String mimeType;

  /// File extension including dot
  final String extension;

  /// Get export format from string value
  static ExportFormat fromString(String value) {
    return ExportFormat.values.firstWhere(
      (format) => format.value == value,
      orElse: () => throw ArgumentError('Unknown export format: $value'),
    );
  }

  /// Check if format supports file bundling
  bool get supportsFileBundling {
    switch (this) {
      case ExportFormat.zip:
      case ExportFormat.tar:
        return true;
      default:
        return false;
    }
  }

  /// Check if format supports rich text/formatting
  bool get supportsRichContent {
    switch (this) {
      case ExportFormat.pdf:
      case ExportFormat.html:
        return true;
      default:
        return false;
    }
  }

  /// Check if format is purely metadata-based
  bool get isMetadataOnly {
    switch (this) {
      case ExportFormat.json:
      case ExportFormat.csv:
      case ExportFormat.xml:
        return true;
      default:
        return false;
    }
  }

  /// Get recommended file size for this format
  int get recommendedMaxSizeMB {
    switch (this) {
      case ExportFormat.json:
      case ExportFormat.xml:
        return 50; // Large structured data files
      case ExportFormat.csv:
        return 100; // Spreadsheet compatibility
      case ExportFormat.pdf:
        return 200; // Document with embedded content
      case ExportFormat.html:
        return 25; // Web browser limitations
      case ExportFormat.zip:
      case ExportFormat.tar:
        return 2048; // Archive formats can be large
    }
  }
}
