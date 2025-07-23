/// Golden file tests for SearchResultsWidget
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:meeting_summarizer/features/search/presentation/widgets/search_results_widget.dart';
import 'package:meeting_summarizer/core/services/advanced_search_service.dart';
import 'package:meeting_summarizer/core/models/storage/file_metadata.dart';
import 'package:meeting_summarizer/core/models/storage/file_category.dart';
import '../../../utils/golden_test_helpers.dart';

void main() {
  group('SearchResultsWidget Golden Tests', () {
    setUpAll(() async {
      await GoldenTestHelpers.initialize();
    });

    // Helper to create mock file metadata
    FileMetadata createMockFileMetadata({
      required String id,
      required String fileName,
      required String filePath,
      int? fileSize,
      List<String>? tags,
    }) {
      return FileMetadata(
        id: id,
        fileName: fileName,
        filePath: filePath,
        relativePath: filePath,
        category: FileCategory.recordings,
        fileSize: fileSize ?? 1024000,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        modifiedAt: DateTime.now().subtract(const Duration(days: 1)),
        customMetadata: {},
        tags: tags ?? [],
        isArchived: false,
      );
    }

    // Helper to create mock ranked file metadata
    RankedFileMetadata createMockRankedResult({
      required FileMetadata metadata,
      double? score,
    }) {
      return RankedFileMetadata(metadata: metadata, score: score ?? 0.85);
    }

    // Helper to create mock search result
    SearchResult createMockSearchResult({
      required List<RankedFileMetadata> results,
      SearchFacets? facets,
    }) {
      return SearchResult(
        query: SearchQuery(
          text: 'test query',
          categories: [],
          tags: [],
          page: 1,
          pageSize: 10,
          includeArchived: false,
        ),
        results: results,
        totalResults: results.length,
        searchTime: const Duration(milliseconds: 150),
        facets:
            facets ?? const SearchFacets(categories: [], tags: [], sizes: []),
        suggestions: [],
      );
    }

    testGoldens('SearchResultsWidget - Empty State', (tester) async {
      final emptyResult = createMockSearchResult(results: []);

      final widget = SearchResultsWidget(
        searchResult: emptyResult,
        onFileSelected: (file) {},
        onSearchChanged: (query) {},
      );

      await GoldenTestHelpers.testWidgetOnMultipleDevices(
        tester: tester,
        widget: widget,
        goldenFileName: 'search_results_empty',
        devices: GoldenTestHelpers.testDevices,
      );
    });

    testGoldens('SearchResultsWidget - Single Result', (tester) async {
      final singleResult = createMockSearchResult(
        results: [
          createMockRankedResult(
            metadata: createMockFileMetadata(
              id: '1',
              fileName: 'team_meeting.wav',
              filePath: '/recordings/team_meeting.wav',
              fileSize: 2048000,
              tags: ['meeting', 'team', 'weekly'],
            ),
            score: 0.92,
          ),
        ],
      );

      final widget = SearchResultsWidget(
        searchResult: singleResult,
        onFileSelected: (file) {},
        onSearchChanged: (query) {},
      );

      await GoldenTestHelpers.testWidgetOnMultipleDevices(
        tester: tester,
        widget: widget,
        goldenFileName: 'search_results_single',
        devices: GoldenTestHelpers.testDevices,
      );
    });

    testGoldens('SearchResultsWidget - Multiple Results', (tester) async {
      final multipleResults = createMockSearchResult(
        results: [
          createMockRankedResult(
            metadata: createMockFileMetadata(
              id: '1',
              fileName: 'team_meeting.wav',
              filePath: '/recordings/team_meeting.wav',
              tags: ['meeting', 'team'],
            ),
            score: 0.95,
          ),
          createMockRankedResult(
            metadata: createMockFileMetadata(
              id: '2',
              fileName: 'client_call.wav',
              filePath: '/recordings/client_call.wav',
              tags: ['client', 'call'],
            ),
            score: 0.78,
          ),
          createMockRankedResult(
            metadata: createMockFileMetadata(
              id: '3',
              fileName: 'standup.wav',
              filePath: '/recordings/standup.wav',
              tags: ['standup', 'daily'],
            ),
            score: 0.65,
          ),
        ],
      );

      final widget = SearchResultsWidget(
        searchResult: multipleResults,
        onFileSelected: (file) {},
        onSearchChanged: (query) {},
      );

      await GoldenTestHelpers.testWidgetOnMultipleDevices(
        tester: tester,
        widget: widget,
        goldenFileName: 'search_results_multiple',
        devices: GoldenTestHelpers.testDevices,
      );
    });

    testGoldens('SearchResultsWidget - With Facets', (tester) async {
      final facets = SearchFacets(
        categories: [
          FacetItem(label: 'Meetings', value: 'meetings', count: 15),
          FacetItem(label: 'Interviews', value: 'interviews', count: 8),
          FacetItem(label: 'Calls', value: 'calls', count: 12),
        ],
        tags: [
          FacetItem(label: 'urgent', value: 'urgent', count: 5),
          FacetItem(label: 'follow-up', value: 'follow-up', count: 7),
          FacetItem(label: 'project-alpha', value: 'project-alpha', count: 10),
        ],
        sizes: [
          FacetItem(label: 'Small', value: 'small', count: 8),
          FacetItem(label: 'Medium', value: 'medium', count: 20),
          FacetItem(label: 'Large', value: 'large', count: 5),
        ],
      );

      final resultsWithFacets = createMockSearchResult(
        results: [
          createMockRankedResult(
            metadata: createMockFileMetadata(
              id: '1',
              fileName: 'important_meeting.wav',
              filePath: '/recordings/important_meeting.wav',
              tags: ['urgent', 'project-alpha'],
            ),
            score: 0.88,
          ),
        ],
        facets: facets,
      );

      final widget = SearchResultsWidget(
        searchResult: resultsWithFacets,
        onFileSelected: (file) {},
        onSearchChanged: (query) {},
      );

      await GoldenTestHelpers.testWidgetOnMultipleDevices(
        tester: tester,
        widget: widget,
        goldenFileName: 'search_results_with_facets',
        devices: GoldenTestHelpers.testDevices,
      );
    });

    testGoldens('SearchResultsWidget - Light and Dark Themes', (tester) async {
      final results = createMockSearchResult(
        results: [
          createMockRankedResult(
            metadata: createMockFileMetadata(
              id: '1',
              fileName: 'meeting.wav',
              filePath: '/recordings/meeting.wav',
              tags: ['important'],
            ),
            score: 0.85,
          ),
          createMockRankedResult(
            metadata: createMockFileMetadata(
              id: '2',
              fileName: 'review.wav',
              filePath: '/recordings/review.wav',
              tags: ['review'],
            ),
            score: 0.72,
          ),
        ],
      );

      final widget = SearchResultsWidget(
        searchResult: results,
        onFileSelected: (file) {},
        onSearchChanged: (query) {},
      );

      await GoldenTestHelpers.testWidgetOnMultipleDevices(
        tester: tester,
        widget: widget,
        goldenFileName: 'search_results_themes',
        testBothThemes: true,
      );
    });

    testGoldens('SearchResultsWidget - Long File Names', (tester) async {
      final longNameResults = createMockSearchResult(
        results: [
          createMockRankedResult(
            metadata: createMockFileMetadata(
              id: '1',
              fileName:
                  'very_long_meeting_name_that_might_wrap_to_multiple_lines.wav',
              filePath:
                  '/recordings/very_long_meeting_name_that_might_wrap_to_multiple_lines.wav',
              tags: ['long-name', 'test'],
            ),
            score: 0.90,
          ),
        ],
      );

      final widget = SearchResultsWidget(
        searchResult: longNameResults,
        onFileSelected: (file) {},
        onSearchChanged: (query) {},
      );

      await GoldenTestHelpers.testWidgetOnMultipleDevices(
        tester: tester,
        widget: widget,
        goldenFileName: 'search_results_long_names',
        devices: [GoldenTestHelpers.smallPhone, Device.phone],
      );
    });

    testGoldens('SearchResultsWidget - Accessibility Testing', (tester) async {
      final results = createMockSearchResult(
        results: [
          createMockRankedResult(
            metadata: createMockFileMetadata(
              id: '1',
              fileName: 'meeting.wav',
              filePath: '/recordings/meeting.wav',
            ),
            score: 0.85,
          ),
        ],
      );

      final widget = SearchResultsWidget(
        searchResult: results,
        onFileSelected: (file) {},
        onSearchChanged: (query) {},
      );

      await GoldenTestHelpers.testWidgetAccessibility(
        tester: tester,
        widget: widget,
        goldenFileName: 'search_results_accessibility',
        textScales: [0.8, 1.0, 1.2, 1.5],
      );
    });
  });
}
