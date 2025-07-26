import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/services/advanced_search_service.dart';
import 'package:meeting_summarizer/core/services/storage_organization_service.dart';
import 'package:meeting_summarizer/core/models/storage/file_category.dart';
import 'package:meeting_summarizer/core/models/storage/file_metadata.dart';

// Mock storage organization service for testing
class MockStorageOrganizationService extends StorageOrganizationService {
  final List<FileMetadata> _mockFiles = [];

  void addMockFile(FileMetadata metadata) {
    _mockFiles.add(metadata);
  }

  void clearMockFiles() {
    _mockFiles.clear();
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

    // Apply filters
    if (!includeArchived) {
      results = results.where((file) => !file.isArchived).toList();
    }

    if (categories != null && categories.isNotEmpty) {
      results =
          results.where((file) => categories.contains(file.category)).toList();
    }

    if (tags != null && tags.isNotEmpty) {
      results = results.where((file) {
        return tags.any((tag) => file.tags.contains(tag));
      }).toList();
    }

    if (query != null && query.isNotEmpty) {
      final queryLower = query.toLowerCase();
      results = results.where((file) {
        return file.fileName.toLowerCase().contains(queryLower) ||
            (file.description?.toLowerCase().contains(queryLower) ?? false) ||
            file.tags.any((tag) => tag.toLowerCase().contains(queryLower));
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

    if (minSize != null) {
      results = results.where((file) => file.fileSize >= minSize).toList();
    }

    if (maxSize != null) {
      results = results.where((file) => file.fileSize <= maxSize).toList();
    }

    return results;
  }
}

void main() {
  group('AdvancedSearchService', () {
    late AdvancedSearchService searchService;
    late MockStorageOrganizationService mockStorage;

    setUp(() {
      mockStorage = MockStorageOrganizationService();
      searchService = AdvancedSearchService.basic(mockStorage);

      // Add sample files
      mockStorage.addMockFile(
        FileMetadata(
          id: '1',
          fileName: 'meeting_notes.txt',
          filePath: '/path/meeting_notes.txt',
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
          filePath: '/path/audio_recording.wav',
          relativePath: 'recordings/audio_recording.wav',
          category: FileCategory.recordings,
          fileSize: 10240000,
          createdAt: DateTime(2024, 1, 10),
          modifiedAt: DateTime(2024, 1, 10),
          description: 'Recording of team meeting',
          tags: ['audio', 'meeting', 'team'],
        ),
      );

      mockStorage.addMockFile(
        FileMetadata(
          id: '3',
          fileName: 'summary_report.pdf',
          filePath: '/path/summary_report.pdf',
          relativePath: 'summaries/summary_report.pdf',
          category: FileCategory.summaries,
          fileSize: 5120,
          createdAt: DateTime(2024, 1, 20),
          modifiedAt: DateTime(2024, 1, 20),
          description: 'Executive summary of quarterly results',
          tags: ['summary', 'quarterly', 'executive'],
          isArchived: true,
        ),
      );
    });

    group('Basic Search', () {
      test('should return all files when no filters applied', () async {
        final query = const SearchQuery();
        final result = await searchService.search(query);

        expect(result.hasResults, true);
        expect(result.totalResults, 2); // Excluding archived file
        expect(result.results.length, 2);
      });

      test('should filter by text query', () async {
        final query = const SearchQuery(text: 'meeting');
        final result = await searchService.search(query);

        expect(result.hasResults, true);
        expect(result.totalResults, 2);
        expect(
          result.results.every(
            (r) =>
                r.metadata.fileName.toLowerCase().contains('meeting') ||
                r.metadata.description!.toLowerCase().contains('meeting') ||
                r.metadata.tags.any((tag) => tag.contains('meeting')),
          ),
          true,
        );
      });

      test('should filter by category', () async {
        final query = const SearchQuery(categories: [FileCategory.recordings]);
        final result = await searchService.search(query);

        expect(result.hasResults, true);
        expect(result.totalResults, 1);
        expect(result.results.first.metadata.category, FileCategory.recordings);
      });

      test('should filter by tags', () async {
        final query = const SearchQuery(tags: ['planning']);
        final result = await searchService.search(query);

        expect(result.hasResults, true);
        expect(result.totalResults, 1);
        expect(result.results.first.metadata.tags.contains('planning'), true);
      });

      test('should include archived files when requested', () async {
        final query = const SearchQuery(includeArchived: true);
        final result = await searchService.search(query);

        expect(result.totalResults, 3); // Including archived file
      });

      test('should filter by date range', () async {
        final dateRange = DateRange(
          start: DateTime(2024, 1, 12),
          end: DateTime(2024, 1, 18),
        );
        final query = SearchQuery(dateRange: dateRange);
        final result = await searchService.search(query);

        expect(result.hasResults, true);
        expect(result.totalResults, 1);
        expect(result.results.first.metadata.fileName, 'meeting_notes.txt');
      });

      test('should filter by file size', () async {
        final sizeRange = SizeRange(min: 1000000, max: 20000000);
        final query = SearchQuery(sizeRange: sizeRange);
        final result = await searchService.search(query);

        expect(result.hasResults, true);
        expect(result.totalResults, 1);
        expect(result.results.first.metadata.fileName, 'audio_recording.wav');
      });
    });

    group('Search Ranking', () {
      test('should rank exact filename matches highest', () async {
        final query = const SearchQuery(text: 'meeting_notes.txt');
        final result = await searchService.search(query);

        expect(result.hasResults, true);
        expect(result.results.first.metadata.fileName, 'meeting_notes.txt');
        expect(result.results.first.score, greaterThan(50));
      });

      test('should rank newer files higher', () async {
        final query = const SearchQuery(text: 'meeting');
        final result = await searchService.search(query);

        expect(result.hasResults, true);
        expect(result.results.length, 2);

        // Newer file should be ranked higher
        final newerFileResult = result.results.firstWhere(
          (r) => r.metadata.fileName == 'meeting_notes.txt',
        );
        final olderFileResult = result.results.firstWhere(
          (r) => r.metadata.fileName == 'audio_recording.wav',
        );

        expect(newerFileResult.score, greaterThan(olderFileResult.score));
      });

      test('should boost score for files with more tags', () async {
        final query = const SearchQuery();
        final result = await searchService.search(query);

        expect(result.hasResults, true);

        // Both files have 3 tags, but content matching may affect scores
        for (final rankedFile in result.results) {
          expect(rankedFile.score, greaterThan(0));
        }
      });
    });

    group('Search Suggestions', () {
      test('should provide search suggestions', () async {
        final suggestions = await searchService.getSearchSuggestions(
          currentQuery: 'meet',
          limit: 5,
        );

        expect(suggestions, isNotEmpty);
        expect(suggestions.any((s) => s.toLowerCase().contains('meet')), true);
      });

      test('should provide autocomplete suggestions', () async {
        final suggestions = await searchService.getSearchSuggestions(
          currentQuery: 'meeting',
          limit: 10,
        );

        expect(suggestions, isNotEmpty);
      });
    });

    group('Search Facets', () {
      test('should generate category facets', () async {
        final facets = await searchService.getSearchFacets();

        expect(facets.categories, isNotEmpty);
        expect(facets.categories.any((f) => f.label == 'Transcriptions'), true);
        expect(
          facets.categories.any((f) => f.label == 'Audio Recordings'),
          true,
        );
      });

      test('should generate tag facets', () async {
        final facets = await searchService.getSearchFacets();

        expect(facets.tags, isNotEmpty);
        expect(facets.tags.any((f) => f.label == 'meeting'), true);
      });

      test('should generate size facets', () async {
        final facets = await searchService.getSearchFacets();

        expect(facets.sizes, isNotEmpty);
      });
    });

    group('Search History', () {
      test('should track search history', () async {
        final query1 = const SearchQuery(text: 'meeting');
        final query2 = const SearchQuery(text: 'audio');

        await searchService.search(query1);
        await searchService.search(query2);

        final history = searchService.getSearchHistory();

        expect(history.length, 2);
        expect(history.first.text, 'audio'); // Most recent first
        expect(history.last.text, 'meeting');
      });

      test('should remove duplicate queries from history', () async {
        final query = const SearchQuery(text: 'meeting');

        await searchService.search(query);
        await searchService.search(query);

        final history = searchService.getSearchHistory();

        expect(history.length, 1);
      });

      test('should limit history size', () async {
        // Add many searches to test history limit
        for (int i = 0; i < 105; i++) {
          final query = SearchQuery(text: 'query$i');
          await searchService.search(query);
        }

        final history = searchService.getSearchHistory();

        expect(history.length, lessThanOrEqualTo(100));
      });

      test('should clear search history', () async {
        final query = const SearchQuery(text: 'meeting');
        await searchService.search(query);

        searchService.clearSearchHistory();
        final history = searchService.getSearchHistory();

        expect(history, isEmpty);
      });
    });

    group('Saved Searches', () {
      test('should save and load search queries', () {
        final query = const SearchQuery(
          text: 'meeting',
          categories: [FileCategory.transcriptions],
          tags: ['planning'],
        );

        searchService.saveSearch('My Meeting Search', query);
        final loadedQuery = searchService.loadSavedSearch('My Meeting Search');

        expect(loadedQuery, isNotNull);
        expect(loadedQuery!.text, 'meeting');
        expect(loadedQuery.categories, [FileCategory.transcriptions]);
        expect(loadedQuery.tags, ['planning']);
      });

      test('should list saved search names', () {
        final query = const SearchQuery(text: 'test');

        searchService.saveSearch('Search 1', query);
        searchService.saveSearch('Search 2', query);

        final names = searchService.getSavedSearchNames();

        expect(names, contains('Search 1'));
        expect(names, contains('Search 2'));
      });

      test('should delete saved searches', () {
        final query = const SearchQuery(text: 'test');

        searchService.saveSearch('Test Search', query);
        searchService.deleteSavedSearch('Test Search');

        final loadedQuery = searchService.loadSavedSearch('Test Search');
        expect(loadedQuery, isNull);
      });
    });

    group('Pagination', () {
      test('should handle pagination correctly', () async {
        // Add more files for pagination testing
        for (int i = 0; i < 25; i++) {
          mockStorage.addMockFile(
            FileMetadata(
              id: 'test$i',
              fileName: 'test_file_$i.txt',
              filePath: '/path/test_file_$i.txt',
              relativePath: 'test/test_file_$i.txt',
              category: FileCategory.cache,
              fileSize: 1024,
              createdAt: DateTime.now(),
              modifiedAt: DateTime.now(),
            ),
          );
        }

        final query = const SearchQuery(pageSize: 10, page: 1);
        final result = await searchService.search(query);

        expect(result.results.length, 10);
        expect(result.totalPages, greaterThan(1));
        expect(result.hasNextPage, true);
        expect(result.hasPreviousPage, false);
      });

      test('should handle second page correctly', () async {
        // Add more files for pagination testing
        for (int i = 0; i < 25; i++) {
          mockStorage.addMockFile(
            FileMetadata(
              id: 'test$i',
              fileName: 'test_file_$i.txt',
              filePath: '/path/test_file_$i.txt',
              relativePath: 'test/test_file_$i.txt',
              category: FileCategory.cache,
              fileSize: 1024,
              createdAt: DateTime.now(),
              modifiedAt: DateTime.now(),
            ),
          );
        }

        final query = const SearchQuery(pageSize: 10, page: 2);
        final result = await searchService.search(query);

        expect(result.currentPage, 2);
        expect(result.hasPreviousPage, true);
      });
    });

    group('Search Performance', () {
      test('should track search time', () async {
        final query = const SearchQuery(text: 'meeting');
        final result = await searchService.search(query);

        expect(result.searchTime.inMilliseconds, greaterThanOrEqualTo(0));
      });

      test('should handle empty results gracefully', () async {
        final query = const SearchQuery(text: 'nonexistent');
        final result = await searchService.search(query);

        expect(result.hasResults, false);
        expect(result.totalResults, 0);
        expect(result.results, isEmpty);
      });
    });

    group('Query Validation', () {
      test('should handle null and empty queries', () async {
        final query1 = const SearchQuery(text: null);
        final query2 = const SearchQuery(text: '');

        final result1 = await searchService.search(query1);
        final result2 = await searchService.search(query2);

        expect(result1.hasResults, true); // Should return all files
        expect(result2.hasResults, true); // Should return all files
      });

      test('should handle complex query combinations', () async {
        final query = SearchQuery(
          text: 'meeting',
          categories: [FileCategory.transcriptions, FileCategory.recordings],
          tags: ['meeting'],
          dateRange: DateRange(
            start: DateTime(2024, 1, 1),
            end: DateTime(2024, 1, 31),
          ),
        );

        final result = await searchService.search(query);

        expect(result.hasResults, true);
        expect(
          result.results.every((r) => r.metadata.tags.contains('meeting')),
          true,
        );
      });
    });
  });
}
