import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/models/storage/file_category.dart';
import 'package:meeting_summarizer/core/models/storage/storage_stats.dart';

void main() {
  group('StorageStats', () {
    late StorageStats sampleStats;
    late Map<FileCategory, CategoryStats> sampleCategoryStats;

    setUp(() {
      sampleCategoryStats = {
        FileCategory.recordings: const CategoryStats(
          fileCount: 10,
          totalSize: 1024 * 1024 * 100, // 100 MB
          archivedCount: 2,
          archivedSize: 1024 * 1024 * 20, // 20 MB
          oldestFile: null,
          newestFile: null,
          commonExtensions: ['.wav', '.mp3'],
        ),
        FileCategory.transcriptions: const CategoryStats(
          fileCount: 5,
          totalSize: 1024 * 50, // 50 KB
          archivedCount: 1,
          archivedSize: 1024 * 10, // 10 KB
        ),
      };

      sampleStats = StorageStats(
        categoryStats: sampleCategoryStats,
        totalFiles: 15,
        totalSize: 1024 * 1024 * 100 + 1024 * 50, // ~100.05 MB
        archivedFiles: 3,
        archivedSize: 1024 * 1024 * 20 + 1024 * 10, // ~20.01 MB
        lastUpdated: DateTime(2024, 1, 1, 12, 0, 0),
      );
    });

    group('basic properties', () {
      test('should return correct category stats', () {
        final recordingsStats = sampleStats.getCategoryStats(
          FileCategory.recordings,
        );
        expect(recordingsStats?.fileCount, 10);
        expect(recordingsStats?.totalSize, 1024 * 1024 * 100);

        final nonExistentStats = sampleStats.getCategoryStats(
          FileCategory.cache,
        );
        expect(nonExistentStats, null);
      });

      test('should calculate active size correctly', () {
        final expectedActiveSize =
            sampleStats.totalSize - sampleStats.archivedSize;
        expect(sampleStats.activeSize, expectedActiveSize);
      });

      test('should calculate active files correctly', () {
        final expectedActiveFiles =
            sampleStats.totalFiles - sampleStats.archivedFiles;
        expect(sampleStats.activeFiles, expectedActiveFiles);
      });
    });

    group('formatted sizes', () {
      test('should format total size correctly', () {
        expect(sampleStats.formattedTotalSize, contains('MB'));
      });

      test('should format archived size correctly', () {
        expect(sampleStats.formattedArchivedSize, contains('MB'));
      });

      test('should format active size correctly', () {
        expect(sampleStats.formattedActiveSize, contains('MB'));
      });
    });

    group('ranking methods', () {
      test('should return largest categories by size', () {
        final largest = sampleStats.getLargestCategories(limit: 2);

        expect(largest, hasLength(2));
        expect(largest.first.key, FileCategory.recordings);
        expect(largest.first.value.totalSize, 1024 * 1024 * 100);
        expect(largest.last.key, FileCategory.transcriptions);
      });

      test('should return categories with most files', () {
        final mostFiles = sampleStats.getCategoriesWithMostFiles(limit: 1);

        expect(mostFiles, hasLength(1));
        expect(mostFiles.first.key, FileCategory.recordings);
        expect(mostFiles.first.value.fileCount, 10);
      });

      test('should respect limit parameter', () {
        final largest = sampleStats.getLargestCategories(limit: 1);
        expect(largest, hasLength(1));

        final mostFiles = sampleStats.getCategoriesWithMostFiles(limit: 1);
        expect(mostFiles, hasLength(1));
      });
    });

    group('JSON serialization', () {
      test('should convert to JSON correctly', () {
        final json = sampleStats.toJson();

        expect(json['totalFiles'], 15);
        expect(json['totalSize'], sampleStats.totalSize);
        expect(json['archivedFiles'], 3);
        expect(json['archivedSize'], sampleStats.archivedSize);
        expect(json['lastUpdated'], '2024-01-01T12:00:00.000');

        final categoryStatsJson = json['categoryStats'] as Map<String, dynamic>;
        expect(categoryStatsJson['recordings'], isNotNull);
        expect(categoryStatsJson['transcriptions'], isNotNull);
      });

      test('should convert from JSON correctly', () {
        final json = sampleStats.toJson();
        final restored = StorageStats.fromJson(json);

        expect(restored.totalFiles, sampleStats.totalFiles);
        expect(restored.totalSize, sampleStats.totalSize);
        expect(restored.archivedFiles, sampleStats.archivedFiles);
        expect(restored.archivedSize, sampleStats.archivedSize);
        expect(restored.lastUpdated, sampleStats.lastUpdated);

        final recordingsStats = restored.getCategoryStats(
          FileCategory.recordings,
        );
        expect(recordingsStats?.fileCount, 10);
        expect(recordingsStats?.totalSize, 1024 * 1024 * 100);
      });

      test('should handle unknown categories gracefully', () {
        final jsonWithUnknown = {
          'categoryStats': {
            'recordings': {
              'fileCount': 5,
              'totalSize': 1000,
              'archivedCount': 1,
              'archivedSize': 200,
            },
            'unknown_category': {
              'fileCount': 3,
              'totalSize': 500,
              'archivedCount': 0,
              'archivedSize': 0,
            },
          },
          'totalFiles': 8,
          'totalSize': 1500,
          'archivedFiles': 1,
          'archivedSize': 200,
          'lastUpdated': '2024-01-01T12:00:00.000',
        };

        final stats = StorageStats.fromJson(jsonWithUnknown);

        expect(stats.totalFiles, 8);
        expect(stats.getCategoryStats(FileCategory.recordings), isNotNull);
        // Unknown category should be skipped
        expect(stats.categoryStats.keys, contains(FileCategory.recordings));
        expect(stats.categoryStats.keys.length, 1);
      });
    });
  });

  group('CategoryStats', () {
    late CategoryStats sampleCategoryStats;

    setUp(() {
      sampleCategoryStats = CategoryStats(
        fileCount: 10,
        totalSize: 1024 * 1024 * 50, // 50 MB
        archivedCount: 3,
        archivedSize: 1024 * 1024 * 15, // 15 MB
        oldestFile: DateTime(2023, 1, 1),
        newestFile: DateTime(2024, 1, 1),
        commonExtensions: ['.wav', '.mp3', '.aac'],
      );
    });

    group('calculated properties', () {
      test('should calculate active count correctly', () {
        expect(sampleCategoryStats.activeCount, 7); // 10 - 3
      });

      test('should calculate active size correctly', () {
        final expectedActiveSize =
            sampleCategoryStats.totalSize - sampleCategoryStats.archivedSize;
        expect(sampleCategoryStats.activeSize, expectedActiveSize);
      });

      test('should calculate average file size correctly', () {
        final expectedAverage =
            sampleCategoryStats.totalSize / sampleCategoryStats.fileCount;
        expect(sampleCategoryStats.averageFileSize, expectedAverage);
      });

      test('should handle zero file count for average', () {
        const emptyStats = CategoryStats(
          fileCount: 0,
          totalSize: 0,
          archivedCount: 0,
          archivedSize: 0,
        );

        expect(emptyStats.averageFileSize, 0);
      });
    });

    group('formatted sizes', () {
      test('should format total size correctly', () {
        expect(sampleCategoryStats.formattedTotalSize, contains('MB'));
      });

      test('should format active size correctly', () {
        expect(sampleCategoryStats.formattedActiveSize, contains('MB'));
      });

      test('should format archived size correctly', () {
        expect(sampleCategoryStats.formattedArchivedSize, contains('MB'));
      });

      test('should format average file size correctly', () {
        expect(sampleCategoryStats.formattedAverageFileSize, contains('MB'));
      });
    });

    group('JSON serialization', () {
      test('should convert to JSON correctly', () {
        final json = sampleCategoryStats.toJson();

        expect(json['fileCount'], 10);
        expect(json['totalSize'], sampleCategoryStats.totalSize);
        expect(json['archivedCount'], 3);
        expect(json['archivedSize'], sampleCategoryStats.archivedSize);
        expect(json['oldestFile'], '2023-01-01T00:00:00.000');
        expect(json['newestFile'], '2024-01-01T00:00:00.000');
        expect(json['commonExtensions'], ['.wav', '.mp3', '.aac']);
      });

      test('should convert from JSON correctly', () {
        final json = sampleCategoryStats.toJson();
        final restored = CategoryStats.fromJson(json);

        expect(restored.fileCount, sampleCategoryStats.fileCount);
        expect(restored.totalSize, sampleCategoryStats.totalSize);
        expect(restored.archivedCount, sampleCategoryStats.archivedCount);
        expect(restored.archivedSize, sampleCategoryStats.archivedSize);
        expect(restored.oldestFile, sampleCategoryStats.oldestFile);
        expect(restored.newestFile, sampleCategoryStats.newestFile);
        expect(restored.commonExtensions, sampleCategoryStats.commonExtensions);
      });

      test('should handle null dates in JSON', () {
        final jsonWithNullDates = {
          'fileCount': 5,
          'totalSize': 1000,
          'archivedCount': 1,
          'archivedSize': 200,
          'oldestFile': null,
          'newestFile': null,
          'commonExtensions': ['.txt'],
        };

        final stats = CategoryStats.fromJson(jsonWithNullDates);

        expect(stats.fileCount, 5);
        expect(stats.oldestFile, null);
        expect(stats.newestFile, null);
        expect(stats.commonExtensions, ['.txt']);
      });

      test('should handle missing optional fields', () {
        final minimalJson = {
          'fileCount': 3,
          'totalSize': 500,
          'archivedCount': 0,
          'archivedSize': 0,
        };

        final stats = CategoryStats.fromJson(minimalJson);

        expect(stats.fileCount, 3);
        expect(stats.totalSize, 500);
        expect(stats.oldestFile, null);
        expect(stats.newestFile, null);
        expect(stats.commonExtensions, isEmpty);
      });
    });
  });
}
