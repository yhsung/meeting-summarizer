import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/services/export_service.dart';
import 'package:meeting_summarizer/core/services/enhanced_storage_organization_service.dart';
import 'package:meeting_summarizer/core/models/export/export_options.dart';
import 'package:meeting_summarizer/core/models/storage/file_metadata.dart';
import 'package:meeting_summarizer/core/models/storage/file_category.dart';
import 'package:meeting_summarizer/core/models/storage/storage_stats.dart';
import 'package:meeting_summarizer/core/enums/export_format.dart';
import 'package:meeting_summarizer/core/enums/compression_level.dart';
import 'dart:io';

// Mock storage organization service for testing
class MockEnhancedStorageOrganizationService
    implements EnhancedStorageOrganizationService {
  final List<FileMetadata> _mockFiles = [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  void addMockFile(FileMetadata metadata) {
    _mockFiles.add(metadata);
  }

  void clearMockFiles() {
    _mockFiles.clear();
  }

  @override
  Future<FileMetadata?> getFileMetadata(String fileId) async {
    try {
      return _mockFiles.firstWhere((file) => file.id == fileId);
    } catch (e) {
      return null; // Return null for non-existent files
    }
  }

  @override
  Future<List<FileMetadata>> getFilesByCategory(
    FileCategory category, {
    bool includeArchived = false,
  }) async {
    var files = _mockFiles.where((file) => file.category == category);
    if (!includeArchived) {
      files = files.where((file) => !file.isArchived);
    }
    return files.toList();
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
    var results = List<FileMetadata>.from(_mockFiles);

    if (!includeArchived) {
      results = results.where((file) => !file.isArchived).toList();
    }

    if (categories != null && categories.isNotEmpty) {
      results = results
          .where((file) => categories.contains(file.category))
          .toList();
    }

    if (tags != null && tags.isNotEmpty) {
      results = results.where((file) {
        return tags.any((tag) => file.tags.contains(tag));
      }).toList();
    }

    if (createdAfter != null) {
      results = results
          .where((file) => file.createdAt.isAfter(createdAfter))
          .toList();
    }

    if (createdBefore != null) {
      results = results
          .where((file) => file.createdAt.isBefore(createdBefore))
          .toList();
    }

    return results;
  }

  @override
  Future<StorageStats> getStorageStats() async {
    return StorageStats(
      totalFiles: _mockFiles.length,
      totalSize: _mockFiles.fold(0, (sum, file) => sum + file.fileSize),
      archivedFiles: _mockFiles.where((f) => f.isArchived).length,
      archivedSize: _mockFiles
          .where((f) => f.isArchived)
          .fold(0, (sum, file) => sum + file.fileSize),
      categoryStats: {},
      lastUpdated: DateTime.now(),
    );
  }
}

void main() {
  group('ExportService', () {
    late ExportService exportService;
    late MockEnhancedStorageOrganizationService mockStorage;

    setUp(() async {
      mockStorage = MockEnhancedStorageOrganizationService();
      exportService = await ExportService.create(storageService: mockStorage);

      // Add sample files
      mockStorage.addMockFile(
        FileMetadata(
          id: '1',
          fileName: 'meeting_notes.txt',
          filePath: '/tmp/meeting_notes.txt',
          relativePath: 'transcriptions/meeting_notes.txt',
          category: FileCategory.transcriptions,
          fileSize: 2048,
          createdAt: DateTime(2024, 1, 15),
          modifiedAt: DateTime(2024, 1, 15),
          description: 'Meeting notes from Q1 planning',
          tags: ['meeting', 'planning', 'q1'],
        ),
      );

      mockStorage.addMockFile(
        FileMetadata(
          id: '2',
          fileName: 'audio_recording.wav',
          filePath: '/tmp/audio_recording.wav',
          relativePath: 'recordings/audio_recording.wav',
          category: FileCategory.recordings,
          fileSize: 10240000,
          createdAt: DateTime(2024, 1, 10),
          modifiedAt: DateTime(2024, 1, 10),
          description: 'Recording of team meeting',
          tags: ['audio', 'meeting', 'team'],
        ),
      );

      // Create temp files for testing
      await File(
        '/tmp/meeting_notes.txt',
      ).writeAsString('Sample meeting notes content');
      await File('/tmp/audio_recording.wav').writeAsBytes([1, 2, 3, 4, 5]);
    });

    tearDown(() async {
      // Clean up temp files
      try {
        await File('/tmp/meeting_notes.txt').delete();
        await File('/tmp/audio_recording.wav').delete();
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    group('Basic Export Operations', () {
      test('should export single file as JSON', () async {
        const options = ExportOptions(
          format: ExportFormat.json,
          includeFiles: false,
          outputPath: '/tmp/test_export.json',
        );

        final result = await exportService.exportSingleFile('1', options);

        expect(result.success, true);
        expect(result.format, ExportFormat.json);
        expect(result.fileCount, 1);
        expect(result.outputPaths.length, 1);
        expect(result.outputPaths.first, '/tmp/test_export.json');

        // Verify file was created
        final exportedFile = File(result.outputPaths.first);
        expect(await exportedFile.exists(), true);

        // Clean up
        await exportedFile.delete();
      });

      test('should export multiple files as CSV', () async {
        const options = ExportOptions(
          format: ExportFormat.csv,
          includeFiles: false,
          outputPath: '/tmp/test_export.csv',
        );

        final result = await exportService.exportMultipleFiles([
          '1',
          '2',
        ], options);

        expect(result.success, true);
        expect(result.format, ExportFormat.csv);
        expect(result.fileCount, 2);
        expect(result.outputPaths.length, 1);

        // Verify file was created
        final exportedFile = File(result.outputPaths.first);
        expect(await exportedFile.exists(), true);

        // Verify CSV content structure
        final content = await exportedFile.readAsString();
        expect(content.contains('fileName'), true);
        expect(content.contains('meeting_notes.txt'), true);
        expect(content.contains('audio_recording.wav'), true);

        // Clean up
        await exportedFile.delete();
      });

      test('should export files as XML', () async {
        const options = ExportOptions(
          format: ExportFormat.xml,
          includeFiles: false,
          outputPath: '/tmp/test_export.xml',
        );

        final result = await exportService.exportMultipleFiles(['1'], options);

        expect(result.success, true);
        expect(result.format, ExportFormat.xml);
        expect(result.fileCount, 1);

        // Verify file was created
        final exportedFile = File(result.outputPaths.first);
        expect(await exportedFile.exists(), true);

        // Verify XML content structure
        final content = await exportedFile.readAsString();
        expect(content.contains('<?xml version="1.0"'), true);
        expect(content.contains('<export>'), true);
        expect(content.contains('<files>'), true);
        expect(content.contains('meeting_notes.txt'), true);

        // Clean up
        await exportedFile.delete();
      });

      test('should export files as HTML', () async {
        const options = ExportOptions(
          format: ExportFormat.html,
          includeFiles: false,
          outputPath: '/tmp/test_export.html',
        );

        final result = await exportService.exportMultipleFiles(['1'], options);

        expect(result.success, true);
        expect(result.format, ExportFormat.html);
        expect(result.fileCount, 1);

        // Verify file was created
        final exportedFile = File(result.outputPaths.first);
        expect(await exportedFile.exists(), true);

        // Verify HTML content structure
        final content = await exportedFile.readAsString();
        expect(content.contains('<!DOCTYPE html>'), true);
        expect(content.contains('<title>File Export Report</title>'), true);
        expect(content.contains('meeting_notes.txt'), true);

        // Clean up
        await exportedFile.delete();
      });
    });

    group('Export by Category', () {
      test('should export files by category', () async {
        const options = ExportOptions(
          format: ExportFormat.json,
          includeFiles: false,
        );

        final result = await exportService.exportCategory(
          FileCategory.transcriptions,
          options,
        );

        expect(result.success, true);
        expect(result.fileCount, 1);
        expect(result.metadata.categoryCounts['transcriptions'], 1);

        // Clean up
        for (final path in result.outputPaths) {
          await File(path).delete();
        }
      });
    });

    group('Export by Tags', () {
      test('should export files by tags', () async {
        const options = ExportOptions(
          format: ExportFormat.json,
          includeFiles: false,
        );

        final result = await exportService.exportByTags(['meeting'], options);

        expect(result.success, true);
        expect(result.fileCount, 2); // Both files have 'meeting' tag

        // Clean up
        for (final path in result.outputPaths) {
          await File(path).delete();
        }
      });
    });

    group('Export by Date Range', () {
      test('should export files within date range', () async {
        final dateRange = DateRange(
          start: DateTime(2024, 1, 12),
          end: DateTime(2024, 1, 18),
        );

        const options = ExportOptions(
          format: ExportFormat.json,
          includeFiles: false,
        );

        final result = await exportService.exportDateRange(dateRange, options);

        expect(result.success, true);
        expect(result.fileCount, 1); // Only meeting_notes.txt is in range

        // Clean up
        for (final path in result.outputPaths) {
          await File(path).delete();
        }
      });
    });

    group('Storage Statistics Export', () {
      test('should export storage statistics', () async {
        const options = ExportOptions(
          format: ExportFormat.json,
          includeFiles: false,
          outputPath: '/tmp/storage_stats.json',
        );

        final result = await exportService.exportStorageStats(options);

        expect(result.success, true);
        expect(result.fileCount, 1);
        expect(result.outputPaths.length, 1);

        // Verify file was created
        final exportedFile = File(result.outputPaths.first);
        expect(await exportedFile.exists(), true);

        // Clean up
        await exportedFile.delete();
      });
    });

    group('System Backup', () {
      test('should create system backup', () async {
        const options = ExportOptions(
          format: ExportFormat.json,
          includeFiles: false,
        );

        final result = await exportService.createSystemBackup(options);

        expect(result.success, true);
        expect(result.fileCount, greaterThan(0));

        // Clean up
        for (final path in result.outputPaths) {
          await File(path).delete();
        }
      });
    });

    group('Export Estimation', () {
      test('should estimate export size correctly', () async {
        const options = ExportOptions(
          format: ExportFormat.json,
          compression: CompressionLevel.balanced,
        );

        final estimate = await exportService.estimateExportSize([
          '1',
          '2',
        ], options);

        expect(estimate.fileCount, 2);
        expect(estimate.estimatedSizeBytes, greaterThan(0));
        expect(estimate.estimatedDuration.inMilliseconds, greaterThan(0));
        expect(estimate.humanReadableSize, isNotEmpty);
      });

      test('should detect when export exceeds limits', () async {
        // Add a large mock file
        mockStorage.addMockFile(
          FileMetadata(
            id: 'large',
            fileName: 'large_file.wav',
            filePath: '/tmp/large_file.wav',
            relativePath: 'recordings/large_file.wav',
            category: FileCategory.recordings,
            fileSize: 200 * 1024 * 1024, // 200MB file
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
          ),
        );

        const options = ExportOptions(
          format: ExportFormat.csv, // Small limit for CSV (100MB)
        );

        final estimate = await exportService.estimateExportSize([
          'large',
        ], options);

        expect(estimate.exceedsRecommendedLimits, true);
        expect(estimate.warnings, isNotEmpty);
      });
    });

    group('Export Validation', () {
      test('should validate export options', () async {
        const validOptions = ExportOptions(
          format: ExportFormat.json,
          includeFiles: false,
        );

        final validation = exportService.validateExportOptions(validOptions);

        expect(validation.isValid, true);
        expect(validation.errors, isEmpty);
      });

      test('should detect invalid export options', () async {
        const invalidOptions = ExportOptions(
          format: ExportFormat.csv,
          includeFiles: true, // CSV doesn't support file bundling
        );

        final validation = exportService.validateExportOptions(invalidOptions);

        expect(validation.warnings, isNotEmpty);
      });
    });

    group('Error Handling', () {
      test('should handle non-existent file gracefully', () async {
        const options = ExportOptions(
          format: ExportFormat.json,
          includeFiles: false,
        );

        final result = await exportService.exportSingleFile(
          'nonexistent',
          options,
        );

        expect(result.success, false);
        expect(result.errorMessage, contains('No valid files found'));
      });

      test('should handle empty file list', () async {
        const options = ExportOptions(
          format: ExportFormat.json,
          includeFiles: false,
        );

        final result = await exportService.exportMultipleFiles([], options);

        expect(result.success, false);
        expect(result.errorMessage, contains('No valid files found'));
      });
    });

    group('Format Support', () {
      test('should return supported formats', () async {
        final formats = exportService.getSupportedFormats();

        expect(formats, contains(ExportFormat.json));
        expect(formats, contains(ExportFormat.csv));
        expect(formats, contains(ExportFormat.xml));
        expect(formats, contains(ExportFormat.html));
      });
    });

    group('Export Progress Tracking', () {
      test('should track export progress', () async {
        const options = ExportOptions(
          format: ExportFormat.json,
          includeFiles: false,
        );

        // Start export (this will complete quickly in tests)
        final resultFuture = exportService.exportMultipleFiles([
          '1',
          '2',
        ], options);

        // Note: In a real scenario, you'd need to capture the export ID
        // and track progress, but for unit tests, we just verify completion
        final result = await resultFuture;

        expect(result.success, true);
        expect(result.processingTime.inMicroseconds, greaterThan(0));

        // Clean up
        for (final path in result.outputPaths) {
          await File(path).delete();
        }
      });
    });

    group('Export Metadata', () {
      test('should include proper export metadata', () async {
        const options = ExportOptions(
          format: ExportFormat.json,
          includeFiles: false,
          includeExportMetadata: true,
        );

        final result = await exportService.exportMultipleFiles([
          '1',
          '2',
        ], options);

        expect(result.success, true);
        expect(result.metadata.timestamp, isNotNull);
        expect(result.metadata.exportVersion, isNotEmpty);
        expect(result.metadata.originalSizeBytes, greaterThan(0));
        expect(result.metadata.categoryCounts, isNotEmpty);

        // Clean up
        for (final path in result.outputPaths) {
          await File(path).delete();
        }
      });
    });

    group('Filter Application', () {
      test('should apply category filters', () async {
        const options = ExportOptions(
          format: ExportFormat.json,
          includeFiles: false,
          categories: [FileCategory.transcriptions],
        );

        final result = await exportService.exportMultipleFiles([
          '1',
          '2',
        ], options);

        expect(result.success, true);
        expect(result.fileCount, 1); // Only transcriptions category

        // Clean up
        for (final path in result.outputPaths) {
          await File(path).delete();
        }
      });

      test('should apply tag filters', () async {
        const options = ExportOptions(
          format: ExportFormat.json,
          includeFiles: false,
          tags: ['planning'],
        );

        final result = await exportService.exportMultipleFiles([
          '1',
          '2',
        ], options);

        expect(result.success, true);
        expect(result.fileCount, 1); // Only file with 'planning' tag

        // Clean up
        for (final path in result.outputPaths) {
          await File(path).delete();
        }
      });
    });
  });
}
