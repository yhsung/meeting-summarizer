import 'dart:async';
import 'dart:math';

import '../models/storage/file_category.dart';
import '../models/storage/file_metadata.dart';
import 'storage_organization_service.dart';
import 'enhanced_storage_organization_service.dart';
import 'file_categorization_service.dart';

/// Advanced search service with ranking, filters, and suggestions
class AdvancedSearchService {
  final StorageOrganizationService? _basicService;
  final EnhancedStorageOrganizationService? _enhancedService;
  final List<SearchQuery> _searchHistory = [];
  final Map<String, List<String>> _savedSearches = {};

  AdvancedSearchService.basic(StorageOrganizationService service)
    : _basicService = service,
      _enhancedService = null;

  AdvancedSearchService.enhanced(EnhancedStorageOrganizationService service)
    : _basicService = null,
      _enhancedService = service;

  /// Perform comprehensive search with ranking and advanced filtering
  Future<SearchResult> search(SearchQuery query) async {
    final startTime = DateTime.now();

    // Add to search history
    _addToHistory(query);

    // Get results from storage service
    final List<FileMetadata> rawResults;
    if (_enhancedService != null) {
      rawResults = await _enhancedService.searchFiles(
        query: query.text,
        categories: query.categories,
        tags: query.tags,
        createdAfter: query.dateRange?.start,
        createdBefore: query.dateRange?.end,
        minSize: query.sizeRange?.min,
        maxSize: query.sizeRange?.max,
        includeArchived: query.includeArchived,
      );
    } else {
      rawResults = await _basicService!.searchFiles(
        query: query.text,
        categories: query.categories,
        tags: query.tags,
        createdAfter: query.dateRange?.start,
        createdBefore: query.dateRange?.end,
        minSize: query.sizeRange?.min,
        maxSize: query.sizeRange?.max,
        includeArchived: query.includeArchived,
      );
    }

    // Apply relevance scoring and ranking
    final rankedResults = _rankResults(rawResults, query);

    // Apply pagination
    final paginatedResults = _paginateResults(rankedResults, query);

    final endTime = DateTime.now();
    final searchTime = endTime.difference(startTime);

    return SearchResult(
      query: query,
      results: paginatedResults,
      totalResults: rankedResults.length,
      searchTime: searchTime,
      facets: _generateFacets(rawResults),
      suggestions: _generateSuggestions(query, rawResults),
    );
  }

  /// Get search suggestions based on query and history
  Future<List<String>> getSearchSuggestions({
    String? currentQuery,
    int limit = 10,
  }) async {
    final suggestions = <String>{};

    // Get all files for context
    final List<FileMetadata> allFiles;
    if (_enhancedService != null) {
      allFiles = await _enhancedService.searchFiles();
    } else {
      allFiles = await _basicService!.searchFiles();
    }

    // Add suggestions from file categorization service
    final categoryBasedSuggestions =
        FileCategorizationService.getSearchSuggestions(
          allFiles,
          currentQuery: currentQuery,
        );
    suggestions.addAll(categoryBasedSuggestions);

    // Add suggestions from search history
    if (currentQuery != null && currentQuery.isNotEmpty) {
      final historySuggestions = _getHistoryBasedSuggestions(currentQuery);
      suggestions.addAll(historySuggestions);
    }

    // Add autocomplete suggestions
    final autocompleteSuggestions = _getAutocompleteSuggestions(
      currentQuery,
      allFiles,
    );
    suggestions.addAll(autocompleteSuggestions);

    return suggestions.take(limit).toList();
  }

  /// Get search facets for filtering
  Future<SearchFacets> getSearchFacets([String? query]) async {
    final List<FileMetadata> allFiles;
    if (_enhancedService != null) {
      allFiles = await _enhancedService!.searchFiles(query: query);
    } else {
      // _basicService is guaranteed to be non-null if _enhancedService is null
      allFiles = await _basicService!.searchFiles(query: query);
    }

    return _generateFacets(allFiles);
  }

  /// Save a search query for future use
  void saveSearch(String name, SearchQuery query) {
    _savedSearches[name] = [
      query.text ?? '',
      query.categories?.map((c) => c.name).join(',') ?? '',
      query.tags?.join(',') ?? '',
      query.dateRange?.start.toIso8601String() ?? '',
      query.dateRange?.end.toIso8601String() ?? '',
      query.sizeRange?.min.toString() ?? '',
      query.sizeRange?.max.toString() ?? '',
      query.includeArchived.toString(),
    ];
  }

  /// Load a saved search
  SearchQuery? loadSavedSearch(String name) {
    final data = _savedSearches[name];
    if (data == null || data.length != 8) return null;

    return SearchQuery(
      text: data[0].isNotEmpty ? data[0] : null,
      categories: data[1].isNotEmpty
          ? data[1]
                .split(',')
                .map((c) => FileCategory.values.byName(c))
                .toList()
          : null,
      tags: data[2].isNotEmpty ? data[2].split(',') : null,
      dateRange: data[3].isNotEmpty && data[4].isNotEmpty
          ? DateRange(
              start: DateTime.parse(data[3]),
              end: DateTime.parse(data[4]),
            )
          : null,
      sizeRange: data[5].isNotEmpty && data[6].isNotEmpty
          ? SizeRange(min: int.parse(data[5]), max: int.parse(data[6]))
          : null,
      includeArchived: bool.parse(data[7]),
    );
  }

  /// Get list of saved searches
  List<String> getSavedSearchNames() => _savedSearches.keys.toList();

  /// Delete a saved search
  void deleteSavedSearch(String name) {
    _savedSearches.remove(name);
  }

  /// Get search history
  List<SearchQuery> getSearchHistory({int limit = 20}) {
    return _searchHistory.take(limit).toList();
  }

  /// Clear search history
  void clearSearchHistory() {
    _searchHistory.clear();
  }

  // Private helper methods

  void _addToHistory(SearchQuery query) {
    // Remove duplicate queries
    _searchHistory.removeWhere((q) => q.toString() == query.toString());

    // Add to front of history
    _searchHistory.insert(0, query.copyWith(timestamp: DateTime.now()));

    // Limit history size
    if (_searchHistory.length > 100) {
      _searchHistory.removeRange(100, _searchHistory.length);
    }
  }

  List<RankedFileMetadata> _rankResults(
    List<FileMetadata> results,
    SearchQuery query,
  ) {
    final rankedResults = <RankedFileMetadata>[];

    for (final result in results) {
      final score = _calculateRelevanceScore(result, query);
      rankedResults.add(RankedFileMetadata(metadata: result, score: score));
    }

    // Sort by relevance score (highest first)
    rankedResults.sort((a, b) => b.score.compareTo(a.score));

    return rankedResults;
  }

  double _calculateRelevanceScore(FileMetadata metadata, SearchQuery query) {
    double score = 0.0;

    if (query.text != null && query.text!.isNotEmpty) {
      final queryText = query.text!.toLowerCase();

      // Exact filename match gets highest score
      if (metadata.fileName.toLowerCase() == queryText) {
        score += 100.0;
      }
      // Filename contains query
      else if (metadata.fileName.toLowerCase().contains(queryText)) {
        score += 50.0;
      }

      // Description match
      if (metadata.description?.toLowerCase().contains(queryText) == true) {
        score += 30.0;
      }

      // Tag match
      for (final tag in metadata.tags) {
        if (tag.toLowerCase().contains(queryText)) {
          score += 20.0;
        }
      }

      // File extension match
      if (metadata.extension.toLowerCase().contains(queryText)) {
        score += 15.0;
      }
    }

    // Boost score for newer files
    final daysSinceCreation = DateTime.now()
        .difference(metadata.createdAt)
        .inDays;
    if (daysSinceCreation < 7) {
      score += 10.0;
    } else if (daysSinceCreation < 30) {
      score += 5.0;
    }

    // Boost score for files with more tags (indication of better organization)
    score += metadata.tags.length * 2.0;

    // Boost score for non-archived files
    if (!metadata.isArchived) {
      score += 5.0;
    }

    return score;
  }

  List<RankedFileMetadata> _paginateResults(
    List<RankedFileMetadata> results,
    SearchQuery query,
  ) {
    final start = (query.page - 1) * query.pageSize;
    final end = min(start + query.pageSize, results.length);

    if (start >= results.length) return [];

    return results.sublist(start, end);
  }

  SearchFacets _generateFacets(List<FileMetadata> results) {
    final categoryFacets = <FacetItem>[];
    final tagFacets = <FacetItem>[];
    final sizeFacets = <FacetItem>[];

    // Category facets
    final categoryGroups = <FileCategory, int>{};
    for (final result in results) {
      categoryGroups[result.category] =
          (categoryGroups[result.category] ?? 0) + 1;
    }

    for (final entry in categoryGroups.entries) {
      categoryFacets.add(
        FacetItem(
          label: entry.key.displayName,
          value: entry.key.name,
          count: entry.value,
        ),
      );
    }

    // Tag facets
    final tagGroups = <String, int>{};
    for (final result in results) {
      for (final tag in result.tags) {
        tagGroups[tag] = (tagGroups[tag] ?? 0) + 1;
      }
    }

    final sortedTags = tagGroups.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedTags.take(20)) {
      tagFacets.add(
        FacetItem(label: entry.key, value: entry.key, count: entry.value),
      );
    }

    // Size facets
    final sizeGroups = <String, int>{
      'Small (< 1MB)': 0,
      'Medium (1-10MB)': 0,
      'Large (10-100MB)': 0,
      'Very Large (> 100MB)': 0,
    };

    for (final result in results) {
      if (result.fileSize < 1024 * 1024) {
        sizeGroups['Small (< 1MB)'] = sizeGroups['Small (< 1MB)']! + 1;
      } else if (result.fileSize < 10 * 1024 * 1024) {
        sizeGroups['Medium (1-10MB)'] = sizeGroups['Medium (1-10MB)']! + 1;
      } else if (result.fileSize < 100 * 1024 * 1024) {
        sizeGroups['Large (10-100MB)'] = sizeGroups['Large (10-100MB)']! + 1;
      } else {
        sizeGroups['Very Large (> 100MB)'] =
            sizeGroups['Very Large (> 100MB)']! + 1;
      }
    }

    for (final entry in sizeGroups.entries) {
      if (entry.value > 0) {
        sizeFacets.add(
          FacetItem(label: entry.key, value: entry.key, count: entry.value),
        );
      }
    }

    return SearchFacets(
      categories: categoryFacets,
      tags: tagFacets,
      sizes: sizeFacets,
    );
  }

  List<String> _generateSuggestions(
    SearchQuery query,
    List<FileMetadata> results,
  ) {
    final suggestions = <String>{};

    // Add related tags from results
    final tagFrequency = <String, int>{};
    for (final result in results) {
      for (final tag in result.tags) {
        tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
      }
    }

    final popularTags = tagFrequency.entries
        .where((entry) => entry.value >= 2)
        .map((entry) => entry.key)
        .take(5);

    suggestions.addAll(popularTags);

    // Add category suggestions
    final categories = results
        .map((r) => r.category.displayName.toLowerCase())
        .toSet();
    suggestions.addAll(categories.take(3));

    return suggestions.toList();
  }

  List<String> _getHistoryBasedSuggestions(String currentQuery) {
    final suggestions = <String>[];
    final queryLower = currentQuery.toLowerCase();

    for (final historyItem in _searchHistory) {
      if (historyItem.text != null &&
          historyItem.text!.toLowerCase().startsWith(queryLower) &&
          historyItem.text!.toLowerCase() != queryLower) {
        suggestions.add(historyItem.text!);
      }
    }

    return suggestions.take(5).toList();
  }

  List<String> _getAutocompleteSuggestions(
    String? currentQuery,
    List<FileMetadata> allFiles,
  ) {
    if (currentQuery == null || currentQuery.isEmpty) return [];

    final suggestions = <String>{};
    final queryLower = currentQuery.toLowerCase();

    // Add filename completions
    for (final file in allFiles) {
      final fileName = file.baseName.toLowerCase();
      if (fileName.startsWith(queryLower) && fileName != queryLower) {
        suggestions.add(file.baseName);
      }
    }

    // Add tag completions
    for (final file in allFiles) {
      for (final tag in file.tags) {
        if (tag.toLowerCase().startsWith(queryLower) &&
            tag.toLowerCase() != queryLower) {
          suggestions.add(tag);
        }
      }
    }

    return suggestions.take(10).toList();
  }
}

/// Search query parameters
class SearchQuery {
  final String? text;
  final List<FileCategory>? categories;
  final List<String>? tags;
  final DateRange? dateRange;
  final SizeRange? sizeRange;
  final bool includeArchived;
  final int page;
  final int pageSize;
  final DateTime? timestamp;

  const SearchQuery({
    this.text,
    this.categories,
    this.tags,
    this.dateRange,
    this.sizeRange,
    this.includeArchived = false,
    this.page = 1,
    this.pageSize = 20,
    this.timestamp,
  });

  SearchQuery copyWith({
    String? text,
    List<FileCategory>? categories,
    List<String>? tags,
    DateRange? dateRange,
    SizeRange? sizeRange,
    bool? includeArchived,
    int? page,
    int? pageSize,
    DateTime? timestamp,
  }) {
    return SearchQuery(
      text: text ?? this.text,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      dateRange: dateRange ?? this.dateRange,
      sizeRange: sizeRange ?? this.sizeRange,
      includeArchived: includeArchived ?? this.includeArchived,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    final parts = <String>[];
    if (text != null) parts.add('text: $text');
    if (categories != null) {
      parts.add('categories: ${categories!.map((c) => c.name).join(',')}');
    }
    if (tags != null) parts.add('tags: ${tags!.join(',')}');
    if (dateRange != null) parts.add('dateRange: ${dateRange.toString()}');
    if (sizeRange != null) parts.add('sizeRange: ${sizeRange.toString()}');
    if (includeArchived) parts.add('includeArchived: true');
    return 'SearchQuery(${parts.join(', ')})';
  }
}

/// Date range filter
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});

  @override
  String toString() => 'DateRange($start to $end)';
}

/// File size range filter
class SizeRange {
  final int min;
  final int max;

  const SizeRange({required this.min, required this.max});

  @override
  String toString() => 'SizeRange($min to $max bytes)';
}

/// Search result with metadata
class SearchResult {
  final SearchQuery query;
  final List<RankedFileMetadata> results;
  final int totalResults;
  final Duration searchTime;
  final SearchFacets facets;
  final List<String> suggestions;

  const SearchResult({
    required this.query,
    required this.results,
    required this.totalResults,
    required this.searchTime,
    required this.facets,
    required this.suggestions,
  });

  bool get hasResults => results.isNotEmpty;
  int get currentPage => query.page;
  int get totalPages => (totalResults / query.pageSize).ceil();
  bool get hasNextPage => currentPage < totalPages;
  bool get hasPreviousPage => currentPage > 1;
}

/// File metadata with relevance score
class RankedFileMetadata {
  final FileMetadata metadata;
  final double score;

  const RankedFileMetadata({required this.metadata, required this.score});
}

/// Search facets for filtering
class SearchFacets {
  final List<FacetItem> categories;
  final List<FacetItem> tags;
  final List<FacetItem> sizes;

  const SearchFacets({
    required this.categories,
    required this.tags,
    required this.sizes,
  });
}

/// Individual facet item
class FacetItem {
  final String label;
  final String value;
  final int count;

  const FacetItem({
    required this.label,
    required this.value,
    required this.count,
  });
}
