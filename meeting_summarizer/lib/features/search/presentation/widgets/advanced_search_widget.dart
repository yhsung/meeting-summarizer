import 'package:flutter/material.dart';
import '../../../../core/models/storage/file_category.dart';
import '../../../../core/services/advanced_search_service.dart';

/// Advanced search widget with filters and suggestions
class AdvancedSearchWidget extends StatefulWidget {
  final AdvancedSearchService searchService;
  final Function(SearchResult) onSearchResult;
  final VoidCallback? onClearSearch;

  const AdvancedSearchWidget({
    super.key,
    required this.searchService,
    required this.onSearchResult,
    this.onClearSearch,
  });

  @override
  State<AdvancedSearchWidget> createState() => _AdvancedSearchWidgetState();
}

class _AdvancedSearchWidgetState extends State<AdvancedSearchWidget> {
  final _queryController = TextEditingController();
  final _focusNode = FocusNode();

  List<FileCategory>? _selectedCategories;
  List<String>? _selectedTags;
  DateRange? _dateRange;
  SizeRange? _sizeRange;
  bool _includeArchived = false;
  bool _showAdvancedFilters = false;

  List<String> _suggestions = [];
  bool _isSearching = false;
  SearchResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    if (_queryController.text.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    _loadSuggestions();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _queryController.text.isNotEmpty) {
      _loadSuggestions();
    }
  }

  Future<void> _loadSuggestions() async {
    try {
      final suggestions = await widget.searchService.getSearchSuggestions(
        currentQuery: _queryController.text,
        limit: 8,
      );

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
        });
      }
    } catch (e) {
      // Handle error silently for suggestions
    }
  }

  Future<void> _performSearch() async {
    if (_queryController.text.trim().isEmpty && !_hasAnyFilters()) {
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final query = SearchQuery(
        text: _queryController.text.trim().isNotEmpty
            ? _queryController.text.trim()
            : null,
        categories: _selectedCategories,
        tags: _selectedTags,
        dateRange: _dateRange,
        sizeRange: _sizeRange,
        includeArchived: _includeArchived,
      );

      final result = await widget.searchService.search(query);

      if (mounted) {
        setState(() {
          _lastResult = result;
          _suggestions = [];
        });

        widget.onSearchResult(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _clearSearch() {
    setState(() {
      _queryController.clear();
      _selectedCategories = null;
      _selectedTags = null;
      _dateRange = null;
      _sizeRange = null;
      _includeArchived = false;
      _suggestions = [];
      _lastResult = null;
    });

    widget.onClearSearch?.call();
  }

  bool _hasAnyFilters() {
    return _selectedCategories != null ||
        _selectedTags != null ||
        _dateRange != null ||
        _sizeRange != null ||
        _includeArchived;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        _buildSearchBar(),

        // Suggestions
        if (_suggestions.isNotEmpty && _focusNode.hasFocus) _buildSuggestions(),

        // Advanced filters toggle
        _buildAdvancedFiltersToggle(),

        // Advanced filters
        if (_showAdvancedFilters) _buildAdvancedFilters(),

        // Search results summary
        if (_lastResult != null) _buildResultsSummary(),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _queryController,
                focusNode: _focusNode,
                decoration: const InputDecoration(
                  hintText: 'Search files, tags, or content...',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (_) => _performSearch(),
              ),
            ),
            if (_isSearching)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: _performSearch,
              ),
            if (_queryController.text.isNotEmpty || _hasAnyFilters())
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _clearSearch,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Card(
      margin: const EdgeInsets.only(top: 4),
      child: Column(
        children: _suggestions.map((suggestion) {
          return ListTile(
            dense: true,
            leading: const Icon(Icons.history, size: 16),
            title: Text(suggestion),
            onTap: () {
              _queryController.text = suggestion;
              _focusNode.unfocus();
              _performSearch();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdvancedFiltersToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          TextButton.icon(
            icon: Icon(
              _showAdvancedFilters ? Icons.expand_less : Icons.expand_more,
            ),
            label: Text(
              _showAdvancedFilters ? 'Hide Filters' : 'Advanced Filters',
            ),
            onPressed: () {
              setState(() {
                _showAdvancedFilters = !_showAdvancedFilters;
              });
            },
          ),
          if (_hasAnyFilters())
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_getActiveFiltersCount()} filters active',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Categories filter
            _buildCategoriesFilter(),
            const SizedBox(height: 16),

            // Tags filter
            _buildTagsFilter(),
            const SizedBox(height: 16),

            // Date range filter
            _buildDateRangeFilter(),
            const SizedBox(height: 16),

            // Size range filter
            _buildSizeRangeFilter(),
            const SizedBox(height: 16),

            // Include archived checkbox
            CheckboxListTile(
              title: const Text('Include archived files'),
              value: _includeArchived,
              onChanged: (value) {
                setState(() {
                  _includeArchived = value ?? false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: FileCategory.values.map((category) {
            final isSelected = _selectedCategories?.contains(category) ?? false;
            return FilterChip(
              label: Text(category.displayName),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCategories = (_selectedCategories ?? [])
                      ..add(category);
                  } else {
                    _selectedCategories?.remove(category);
                    if (_selectedCategories?.isEmpty == true) {
                      _selectedCategories = null;
                    }
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTagsFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // TODO: Implement tag selection UI
        Text(
          'Tag selection coming soon...',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date Range', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _selectDateRange(context),
                child: Text(
                  _dateRange != null
                      ? '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}'
                      : 'Select date range',
                ),
              ),
            ),
            if (_dateRange != null)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _dateRange = null;
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSizeRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('File Size', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // TODO: Implement size range selector
        Text(
          'Size range selection coming soon...',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsSummary() {
    final result = _lastResult!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Found ${result.totalResults} files in ${result.searchTime.inMilliseconds}ms',
              ),
            ),
            if (result.totalPages > 1)
              Text(
                'Page ${result.currentPage} of ${result.totalPages}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange != null
          ? DateTimeRange(start: _dateRange!.start, end: _dateRange!.end)
          : null,
    );

    if (dateRange != null) {
      setState(() {
        _dateRange = DateRange(start: dateRange.start, end: dateRange.end);
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  int _getActiveFiltersCount() {
    int count = 0;
    if (_selectedCategories?.isNotEmpty == true) count++;
    if (_selectedTags?.isNotEmpty == true) count++;
    if (_dateRange != null) count++;
    if (_sizeRange != null) count++;
    if (_includeArchived) count++;
    return count;
  }
}
