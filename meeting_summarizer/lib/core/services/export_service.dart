import 'dart:async';
import 'dart:io';
import 'dart:convert';

import '../interfaces/export_service_interface.dart';
import '../models/export/export_options.dart';
import '../models/export/export_result.dart';
import '../models/storage/file_category.dart';
import '../models/storage/file_metadata.dart';
import '../enums/export_format.dart';
import '../enums/compression_level.dart';
import '../services/advanced_search_service.dart' show SearchQuery;
import 'enhanced_storage_organization_service.dart';

/// Core export service implementing multiple format support with factory pattern
class ExportService implements ExportServiceInterface {
  final EnhancedStorageOrganizationService _storageService;
  final Map<ExportFormat, FormatExporter> _formatExporters;
  final Map<String, StreamController<ExportProgress>> _activeExports;

  ExportService._({
    required EnhancedStorageOrganizationService storageService,
    required Map<ExportFormat, FormatExporter> formatExporters,
  }) : _storageService = storageService,
       _formatExporters = formatExporters,
       _activeExports = {};

  /// Create export service with all format exporters
  static Future<ExportService> create({
    required EnhancedStorageOrganizationService storageService,
  }) async {
    final formatExporters = <ExportFormat, FormatExporter>{
      ExportFormat.json: JsonExporter(),
      ExportFormat.csv: CsvExporter(),
      ExportFormat.xml: XmlExporter(),
      ExportFormat.pdf: PdfExporter(),
      ExportFormat.html: HtmlExporter(),
      ExportFormat.zip: ZipExporter(),
      ExportFormat.tar: TarExporter(),
    };

    return ExportService._(
      storageService: storageService,
      formatExporters: formatExporters,
    );
  }

  @override
  Future<ExportResult> exportSingleFile(
    String fileId,
    ExportOptions options,
  ) async {
    return exportMultipleFiles([fileId], options);
  }

  @override
  Future<ExportResult> exportMultipleFiles(
    List<String> fileIds,
    ExportOptions options,
  ) async {
    final exportId = _generateExportId();
    final progressController = StreamController<ExportProgress>.broadcast();
    _activeExports[exportId] = progressController;

    try {
      // Validate options
      final validation = validateExportOptions(options);
      if (!validation.isValid) {
        return ExportResult.failure(
          format: options.format,
          options: options,
          errorMessage: validation.errors.join(', '),
        );
      }

      // Get file metadata
      final files = <FileMetadata>[];
      for (final fileId in fileIds) {
        final metadata = await _storageService.getFileMetadata(fileId);
        if (metadata != null) {
          files.add(metadata);
        }
      }

      if (files.isEmpty) {
        return ExportResult.failure(
          format: options.format,
          options: options,
          errorMessage: 'No valid files found for export',
        );
      }

      // Apply filters
      final filteredFiles = _applyFilters(files, options);

      // Get the appropriate exporter
      final exporter = _formatExporters[options.format];
      if (exporter == null) {
        return ExportResult.failure(
          format: options.format,
          options: options,
          errorMessage:
              'Unsupported export format: ${options.format.displayName}',
        );
      }

      // Perform export with progress tracking
      final startTime = DateTime.now();
      final result = await _performExport(
        exporter,
        filteredFiles,
        options,
        exportId,
        progressController,
      );

      final endTime = DateTime.now();
      final processingTime = endTime.difference(startTime);

      // Create export metadata
      final metadata = ExportMetadata.forFiles(
        files: filteredFiles.map((f) => f.toJson()).toList(),
        source: ExportSource.manual,
      );

      return ExportResult.success(
        outputPaths: result.outputPaths,
        format: options.format,
        options: options,
        fileCount: filteredFiles.length,
        totalSizeBytes: result.totalSizeBytes,
        processingTime: processingTime,
        metadata: metadata,
      );
    } catch (e, stackTrace) {
      return ExportResult.failure(
        format: options.format,
        options: options,
        errorMessage: 'Export failed: $e',
        stackTrace: stackTrace.toString(),
      );
    } finally {
      // Clean up progress tracking
      _activeExports.remove(exportId);
      await progressController.close();
    }
  }

  @override
  Future<ExportResult> exportCategory(
    FileCategory category,
    ExportOptions options,
  ) async {
    final files = await _storageService.getFilesByCategory(category);
    final fileIds = files.map((f) => f.id).toList();

    return exportMultipleFiles(
      fileIds,
      options.copyWith(categories: [category]),
    );
  }

  @override
  Future<ExportResult> exportSearchResults(
    SearchQuery query,
    ExportOptions options,
  ) async {
    // This would require integration with AdvancedSearchService
    // For now, return a placeholder implementation
    return ExportResult.failure(
      format: options.format,
      options: options,
      errorMessage: 'Search results export not yet implemented',
    );
  }

  @override
  Future<ExportResult> exportDateRange(
    DateRange dateRange,
    ExportOptions options,
  ) async {
    final files = await _storageService.searchFiles(
      createdAfter: dateRange.start,
      createdBefore: dateRange.end,
    );
    final fileIds = files.map((f) => f.id).toList();

    return exportMultipleFiles(fileIds, options.copyWith(dateRange: dateRange));
  }

  @override
  Future<ExportResult> exportByTags(
    List<String> tags,
    ExportOptions options,
  ) async {
    final files = await _storageService.searchFiles(tags: tags);
    final fileIds = files.map((f) => f.id).toList();

    return exportMultipleFiles(fileIds, options.copyWith(tags: tags));
  }

  @override
  Future<ExportResult> exportStorageStats(
    ExportOptions options, {
    DateRange? dateRange,
  }) async {
    // Get storage statistics
    final stats = await _storageService.getStorageStats();

    // Create synthetic file metadata for stats
    final statsData = {
      'id': 'storage_stats_${DateTime.now().millisecondsSinceEpoch}',
      'fileName': 'storage_statistics.${options.format.extension}',
      'data': stats.toJson(),
      'category': 'analytics',
      'createdAt': DateTime.now().toIso8601String(),
    };

    final exporter = _formatExporters[options.format];
    if (exporter == null) {
      return ExportResult.failure(
        format: options.format,
        options: options,
        errorMessage: 'Unsupported export format for statistics',
      );
    }

    try {
      final result = await exporter.exportData([statsData], options);

      return ExportResult.success(
        outputPaths: result.outputPaths,
        format: options.format,
        options: options,
        fileCount: 1,
        totalSizeBytes: result.totalSizeBytes,
        processingTime: result.processingTime,
        metadata: ExportMetadata.empty(),
      );
    } catch (e) {
      return ExportResult.failure(
        format: options.format,
        options: options,
        errorMessage: 'Failed to export storage statistics: $e',
      );
    }
  }

  @override
  Future<ExportResult> createSystemBackup(ExportOptions options) async {
    // Get all files from all categories
    final allFiles = <FileMetadata>[];
    for (final category in FileCategory.userContentCategories) {
      final categoryFiles = await _storageService.getFilesByCategory(category);
      allFiles.addAll(categoryFiles);
    }

    final fileIds = allFiles.map((f) => f.id).toList();

    return exportMultipleFiles(
      fileIds,
      options.copyWith(
        includeFiles: true,
        maintainStructure: true,
        includeExportMetadata: true,
        filenamePrefix:
            'system_backup_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
  }

  @override
  Future<ExportEstimate> estimateExportSize(
    List<String> fileIds,
    ExportOptions options,
  ) async {
    int totalSize = 0;
    int fileCount = 0;
    final warnings = <String>[];

    for (final fileId in fileIds) {
      final metadata = await _storageService.getFileMetadata(fileId);
      if (metadata != null) {
        totalSize += metadata.fileSize;
        fileCount++;
      }
    }

    // Apply compression estimation
    double compressionRatio = 1.0;
    if (options.format.supportsFileBundling) {
      compressionRatio = options.compression.estimatedRatio;
    }

    final estimatedSize = (totalSize * compressionRatio).round();
    final estimatedDuration = Duration(
      milliseconds: (totalSize / (10 * 1024 * 1024) * 1000).round(), // ~10MB/s
    );

    // Check limits
    final maxSize = options.format.recommendedMaxSizeMB * 1024 * 1024;
    final exceedsLimits = estimatedSize > maxSize;

    if (exceedsLimits) {
      warnings.add(
        'Export size exceeds recommended limit of ${options.format.recommendedMaxSizeMB}MB',
      );
    }

    return ExportEstimate(
      estimatedSizeBytes: estimatedSize,
      estimatedDuration: estimatedDuration,
      fileCount: fileCount,
      compressionRatio: compressionRatio,
      estimatedMemoryUsageBytes: (estimatedSize * 1.5).round(), // 50% overhead
      exceedsRecommendedLimits: exceedsLimits,
      warnings: warnings,
    );
  }

  @override
  Future<bool> cancelExport(String exportId) async {
    final controller = _activeExports[exportId];
    if (controller != null) {
      await controller.close();
      _activeExports.remove(exportId);
      return true;
    }
    return false;
  }

  @override
  Stream<ExportProgress> getExportProgress(String exportId) {
    final controller = _activeExports[exportId];
    if (controller != null) {
      return controller.stream;
    }
    return const Stream.empty();
  }

  @override
  List<ExportFormat> getSupportedFormats() {
    return _formatExporters.keys.toList();
  }

  @override
  ValidationResult validateExportOptions(ExportOptions options) {
    final errors = <String>[];
    final warnings = <String>[];
    final suggestions = <String>[];

    // Check if format is supported
    if (!_formatExporters.containsKey(options.format)) {
      errors.add('Unsupported export format: ${options.format.displayName}');
    }

    // Validate file bundling options
    if (options.includeFiles &&
        !options.format.supportsFileBundling &&
        options.format.isMetadataOnly) {
      warnings.add(
        'Selected format only supports metadata export, files will be excluded',
      );
    }

    // Validate compression settings
    if (options.compression != CompressionLevel.none &&
        !options.format.supportsFileBundling) {
      warnings.add(
        'Compression not applicable for ${options.format.displayName} format',
      );
    }

    // Validate size limits
    if (options.maxSizeBytes != null &&
        options.maxSizeBytes! >
            options.format.recommendedMaxSizeMB * 1024 * 1024) {
      warnings.add(
        'Size limit exceeds recommended maximum for ${options.format.displayName}',
      );
    }

    // Suggest optimizations
    if (options.format == ExportFormat.json && options.includeFiles) {
      suggestions.add(
        'Consider using ZIP format for exports that include files',
      );
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      suggestions: suggestions,
    );
  }

  @override
  Future<void> cleanupTemporaryFiles() async {
    // Implementation would clean up any temporary files
    // created during export operations
  }

  // Private helper methods

  List<FileMetadata> _applyFilters(
    List<FileMetadata> files,
    ExportOptions options,
  ) {
    var filtered = files;

    // Apply category filter
    if (options.categories != null && options.categories!.isNotEmpty) {
      filtered = filtered
          .where((f) => options.categories!.contains(f.category))
          .toList();
    }

    // Apply tag filter
    if (options.tags != null && options.tags!.isNotEmpty) {
      filtered = filtered.where((f) {
        return options.tags!.any((tag) => f.tags.contains(tag));
      }).toList();
    }

    // Apply date range filter
    if (options.dateRange != null) {
      filtered = filtered
          .where((f) => options.dateRange!.contains(f.createdAt))
          .toList();
    }

    return filtered;
  }

  Future<ExportInternalResult> _performExport(
    FormatExporter exporter,
    List<FileMetadata> files,
    ExportOptions options,
    String exportId,
    StreamController<ExportProgress> progressController,
  ) async {
    final totalFiles = files.length;
    int processedFiles = 0;
    int totalBytes = 0;

    // Convert files to export data
    final exportData = <Map<String, dynamic>>[];
    for (final file in files) {
      var fileData = file.toJson();

      // Include file content if requested
      if (options.includeFiles && options.format.supportsFileBundling) {
        fileData['_fileContent'] = await _getFileContent(file);
      }

      exportData.add(fileData);

      // Update progress
      processedFiles++;
      final progress = ExportProgress(
        exportId: exportId,
        progressPercentage: (processedFiles / totalFiles) * 100,
        filesProcessed: processedFiles,
        totalFiles: totalFiles,
        currentOperation: 'Processing ${file.fileName}',
        bytesProcessed: totalBytes,
        totalBytes: files.fold(0, (sum, f) => sum + f.fileSize),
      );

      progressController.add(progress);
    }

    // Perform the actual export
    return await exporter.exportData(exportData, options);
  }

  Future<String?> _getFileContent(FileMetadata file) async {
    try {
      final fileContent = await File(file.filePath).readAsBytes();
      return base64Encode(fileContent);
    } catch (e) {
      return null; // File not accessible
    }
  }

  String _generateExportId() {
    return 'export_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Abstract base class for format-specific exporters
abstract class FormatExporter {
  Future<ExportInternalResult> exportData(
    List<Map<String, dynamic>> data,
    ExportOptions options,
  );
}

/// Internal result structure for exporters
class ExportInternalResult {
  final List<String> outputPaths;
  final int totalSizeBytes;
  final Duration processingTime;

  const ExportInternalResult({
    required this.outputPaths,
    required this.totalSizeBytes,
    required this.processingTime,
  });
}

// Placeholder implementations for format exporters
// These will be implemented in the next phase

class JsonExporter extends FormatExporter {
  @override
  Future<ExportInternalResult> exportData(
    List<Map<String, dynamic>> data,
    ExportOptions options,
  ) async {
    final startTime = DateTime.now();

    // Create JSON export
    final jsonData = {
      'metadata': {
        'exportedAt': DateTime.now().toIso8601String(),
        'format': 'json',
        'version': '1.0.0',
        'fileCount': data.length,
      },
      'files': data,
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

    // Generate output path
    final fileName = options.filenamePrefix != null
        ? '${options.filenamePrefix}_${DateTime.now().millisecondsSinceEpoch}.json'
        : 'export_${DateTime.now().millisecondsSinceEpoch}.json';

    final outputPath = options.outputPath ?? '/tmp/$fileName';

    // Write file
    final file = File(outputPath);
    await file.writeAsString(jsonString);

    return ExportInternalResult(
      outputPaths: [outputPath],
      totalSizeBytes: jsonString.length,
      processingTime: DateTime.now().difference(startTime),
    );
  }
}

class CsvExporter extends FormatExporter {
  @override
  Future<ExportInternalResult> exportData(
    List<Map<String, dynamic>> data,
    ExportOptions options,
  ) async {
    final startTime = DateTime.now();

    if (data.isEmpty) {
      return ExportInternalResult(
        outputPaths: [],
        totalSizeBytes: 0,
        processingTime: DateTime.now().difference(startTime),
      );
    }

    // Extract all unique keys for CSV headers
    final allKeys = <String>{};
    for (final item in data) {
      allKeys.addAll(item.keys);
    }

    // Remove complex objects that don't translate well to CSV
    final csvKeys = allKeys
        .where(
          (key) =>
              !key.startsWith('_') && // Skip internal fields
              key != 'customMetadata' && // Skip complex objects
              key != 'tags', // Handle tags separately
        )
        .toList();

    // Add tags as a separate column
    if (allKeys.contains('tags')) {
      csvKeys.add('tags');
    }

    // Create CSV content
    final csvLines = <String>[];

    // Add header
    csvLines.add(csvKeys.map(_escapeCsvValue).join(','));

    // Add data rows
    for (final item in data) {
      final row = csvKeys
          .map((key) {
            final value = item[key];
            if (key == 'tags' && value is List) {
              return _escapeCsvValue(value.join(';'));
            }
            return _escapeCsvValue(value?.toString() ?? '');
          })
          .join(',');
      csvLines.add(row);
    }

    final csvContent = csvLines.join('\n');

    // Generate output path
    final fileName = options.filenamePrefix != null
        ? '${options.filenamePrefix}_${DateTime.now().millisecondsSinceEpoch}.csv'
        : 'export_${DateTime.now().millisecondsSinceEpoch}.csv';

    final outputPath = options.outputPath ?? '/tmp/$fileName';

    // Write file
    final file = File(outputPath);
    await file.writeAsString(csvContent);

    return ExportInternalResult(
      outputPaths: [outputPath],
      totalSizeBytes: csvContent.length,
      processingTime: DateTime.now().difference(startTime),
    );
  }

  String _escapeCsvValue(String value) {
    // Escape quotes and wrap in quotes if necessary
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

class XmlExporter extends FormatExporter {
  @override
  Future<ExportInternalResult> exportData(
    List<Map<String, dynamic>> data,
    ExportOptions options,
  ) async {
    final startTime = DateTime.now();

    // Create XML document
    final xmlLines = <String>[];
    xmlLines.add('<?xml version="1.0" encoding="UTF-8"?>');
    xmlLines.add('<export>');
    xmlLines.add('  <metadata>');
    xmlLines.add(
      '    <exportedAt>${DateTime.now().toIso8601String()}</exportedAt>',
    );
    xmlLines.add('    <format>xml</format>');
    xmlLines.add('    <version>1.0.0</version>');
    xmlLines.add('    <fileCount>${data.length}</fileCount>');
    xmlLines.add('  </metadata>');
    xmlLines.add('  <files>');

    // Add each file
    for (final item in data) {
      xmlLines.add('    <file>');

      for (final entry in item.entries) {
        final key = entry.key;
        final value = entry.value;

        if (value is List) {
          xmlLines.add('      <$key>');
          for (final listItem in value) {
            xmlLines.add(
              '        <item>${_escapeXml(listItem.toString())}</item>',
            );
          }
          xmlLines.add('      </$key>');
        } else if (value is Map) {
          xmlLines.add('      <$key>');
          for (final subEntry in value.entries) {
            xmlLines.add(
              '        <${subEntry.key}>${_escapeXml(subEntry.value.toString())}</${subEntry.key}>',
            );
          }
          xmlLines.add('      </$key>');
        } else {
          xmlLines.add(
            '      <$key>${_escapeXml(value?.toString() ?? '')}</$key>',
          );
        }
      }

      xmlLines.add('    </file>');
    }

    xmlLines.add('  </files>');
    xmlLines.add('</export>');

    final xmlContent = xmlLines.join('\n');

    // Generate output path
    final fileName = options.filenamePrefix != null
        ? '${options.filenamePrefix}_${DateTime.now().millisecondsSinceEpoch}.xml'
        : 'export_${DateTime.now().millisecondsSinceEpoch}.xml';

    final outputPath = options.outputPath ?? '/tmp/$fileName';

    // Write file
    final file = File(outputPath);
    await file.writeAsString(xmlContent);

    return ExportInternalResult(
      outputPaths: [outputPath],
      totalSizeBytes: xmlContent.length,
      processingTime: DateTime.now().difference(startTime),
    );
  }

  String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

class PdfExporter extends FormatExporter {
  @override
  Future<ExportInternalResult> exportData(
    List<Map<String, dynamic>> data,
    ExportOptions options,
  ) async {
    // TODO: Implement PDF export
    throw UnimplementedError('PDF export not yet implemented');
  }
}

class HtmlExporter extends FormatExporter {
  @override
  Future<ExportInternalResult> exportData(
    List<Map<String, dynamic>> data,
    ExportOptions options,
  ) async {
    final startTime = DateTime.now();

    // Create HTML document
    final htmlLines = <String>[];

    // HTML header
    htmlLines.addAll([
      '<!DOCTYPE html>',
      '<html lang="en">',
      '<head>',
      '    <meta charset="UTF-8">',
      '    <meta name="viewport" content="width=device-width, initial-scale=1.0">',
      '    <title>File Export Report</title>',
      '    <style>',
      '        body { font-family: Arial, sans-serif; margin: 20px; }',
      '        .header { background-color: #f5f5f5; padding: 20px; border-radius: 5px; margin-bottom: 20px; }',
      '        .file-card { border: 1px solid #ddd; margin: 10px 0; padding: 15px; border-radius: 5px; }',
      '        .file-title { font-size: 18px; font-weight: bold; color: #333; margin-bottom: 10px; }',
      '        .file-meta { color: #666; font-size: 14px; margin: 5px 0; }',
      '        .tags { margin: 10px 0; }',
      '        .tag { background-color: #e3f2fd; padding: 2px 8px; border-radius: 12px; margin: 2px; display: inline-block; font-size: 12px; }',
      '        table { width: 100%; border-collapse: collapse; margin: 10px 0; }',
      '        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }',
      '        th { background-color: #f5f5f5; }',
      '    </style>',
      '</head>',
      '<body>',
    ]);

    // Header section
    htmlLines.addAll([
      '    <div class="header">',
      '        <h1>File Export Report</h1>',
      '        <p><strong>Generated:</strong> ${DateTime.now().toLocal()}</p>',
      '        <p><strong>Total Files:</strong> ${data.length}</p>',
      '        <p><strong>Export Format:</strong> HTML</p>',
      '    </div>',
    ]);

    // File cards
    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      htmlLines.add('    <div class="file-card">');
      htmlLines.add(
        '        <div class="file-title">${_escapeHtml(item['fileName']?.toString() ?? 'Unknown File')}</div>',
      );

      // Basic file information
      if (item['description'] != null) {
        htmlLines.add(
          '        <p>${_escapeHtml(item['description'].toString())}</p>',
        );
      }

      // File metadata
      htmlLines.add('        <div class="file-meta">');
      if (item['fileSize'] != null) {
        htmlLines.add(
          '            <strong>Size:</strong> ${_formatFileSize(item['fileSize'])} | ',
        );
      }
      if (item['category'] != null) {
        htmlLines.add(
          '            <strong>Category:</strong> ${_escapeHtml(item['category'].toString())} | ',
        );
      }
      if (item['createdAt'] != null) {
        htmlLines.add(
          '            <strong>Created:</strong> ${item['createdAt']}',
        );
      }
      htmlLines.add('        </div>');

      // Tags
      if (item['tags'] is List && (item['tags'] as List).isNotEmpty) {
        htmlLines.add('        <div class="tags">');
        htmlLines.add('            <strong>Tags:</strong>');
        for (final tag in item['tags'] as List) {
          htmlLines.add(
            '            <span class="tag">${_escapeHtml(tag.toString())}</span>',
          );
        }
        htmlLines.add('        </div>');
      }

      // Additional metadata table
      final metadataItems = item.entries
          .where(
            (e) =>
                ![
                  'fileName',
                  'description',
                  'fileSize',
                  'category',
                  'createdAt',
                  'tags',
                ].contains(e.key) &&
                !e.key.startsWith('_'),
          )
          .toList();

      if (metadataItems.isNotEmpty) {
        htmlLines.addAll([
          '        <table>',
          '            <thead>',
          '                <tr><th>Property</th><th>Value</th></tr>',
          '            </thead>',
          '            <tbody>',
        ]);

        for (final entry in metadataItems) {
          final value = entry.value?.toString() ?? '';
          if (value.isNotEmpty) {
            htmlLines.add(
              '                <tr><td>${_escapeHtml(entry.key)}</td><td>${_escapeHtml(value)}</td></tr>',
            );
          }
        }

        htmlLines.addAll(['            </tbody>', '        </table>']);
      }

      htmlLines.add('    </div>');
    }

    // HTML footer
    htmlLines.addAll(['</body>', '</html>']);

    final htmlContent = htmlLines.join('\n');

    // Generate output path
    final fileName = options.filenamePrefix != null
        ? '${options.filenamePrefix}_${DateTime.now().millisecondsSinceEpoch}.html'
        : 'export_${DateTime.now().millisecondsSinceEpoch}.html';

    final outputPath = options.outputPath ?? '/tmp/$fileName';

    // Write file
    final file = File(outputPath);
    await file.writeAsString(htmlContent);

    return ExportInternalResult(
      outputPaths: [outputPath],
      totalSizeBytes: htmlContent.length,
      processingTime: DateTime.now().difference(startTime),
    );
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _formatFileSize(dynamic size) {
    if (size is! int) return size.toString();

    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class ZipExporter extends FormatExporter {
  @override
  Future<ExportInternalResult> exportData(
    List<Map<String, dynamic>> data,
    ExportOptions options,
  ) async {
    // TODO: Implement ZIP export
    throw UnimplementedError('ZIP export not yet implemented');
  }
}

class TarExporter extends FormatExporter {
  @override
  Future<ExportInternalResult> exportData(
    List<Map<String, dynamic>> data,
    ExportOptions options,
  ) async {
    // TODO: Implement TAR export
    throw UnimplementedError('TAR export not yet implemented');
  }
}
