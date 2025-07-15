import 'package:flutter/material.dart';
import '../../../../core/services/advanced_search_service.dart';
import '../../../../core/services/enhanced_storage_organization_service.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/models/storage/file_metadata.dart';
import '../widgets/advanced_search_widget.dart';
import '../widgets/search_results_widget.dart';

/// Main search screen with advanced search capabilities
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late AdvancedSearchService _searchService;
  late TabController _tabController;

  SearchResult? _currentResult;
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeSearchService();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeSearchService() async {
    try {
      final databaseHelper = DatabaseHelper();
      final storageService = EnhancedStorageOrganizationService(databaseHelper);
      await storageService.initialize();

      _searchService = AdvancedSearchService.enhanced(storageService);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize search service: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Files'),
        bottom: _isInitialized
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.search), text: 'Search'),
                  Tab(icon: Icon(Icons.history), text: 'History'),
                  Tab(icon: Icon(Icons.bookmark), text: 'Saved'),
                ],
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildErrorState();
    }

    if (!_isInitialized) {
      return _buildLoadingState();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildSearchTab(),
        _buildHistoryTab(),
        _buildSavedSearchesTab(),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Search Unavailable',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeSearchService,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Initializing search...'),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        // Search widget
        Padding(
          padding: const EdgeInsets.all(16),
          child: AdvancedSearchWidget(
            searchService: _searchService,
            onSearchResult: _handleSearchResult,
            onClearSearch: _handleClearSearch,
          ),
        ),

        // Results
        Expanded(
          child: _currentResult != null
              ? SearchResultsWidget(
                  searchResult: _currentResult!,
                  onFileSelected: _handleFileSelected,
                  onSearchChanged: _handleSearchChanged,
                )
              : _buildEmptySearchState(),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return FutureBuilder<List<SearchQuery>>(
      future: Future.value(_searchService.getSearchHistory()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final history = snapshot.data!;
        if (history.isEmpty) {
          return _buildEmptyHistoryState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final query = history[index];
            return _buildHistoryItem(query);
          },
        );
      },
    );
  }

  Widget _buildSavedSearchesTab() {
    final savedSearches = _searchService.getSavedSearchNames();

    if (savedSearches.isEmpty) {
      return _buildEmptySavedSearchesState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: savedSearches.length,
      itemBuilder: (context, index) {
        final searchName = savedSearches[index];
        return _buildSavedSearchItem(searchName);
      },
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            'Start Searching',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Use the search bar above to find files by name, content, tags, or metadata',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistoryState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Search History',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your search history will appear here',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySavedSearchesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Saved Searches',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Save frequently used searches for quick access',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(SearchQuery query) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.history),
        title: Text(query.text ?? 'Advanced search'),
        subtitle: Text(_formatSearchQuery(query)),
        trailing: query.timestamp != null
            ? Text(
                _formatTimestamp(query.timestamp!),
                style: Theme.of(context).textTheme.bodySmall,
              )
            : null,
        onTap: () => _executeQuery(query),
      ),
    );
  }

  Widget _buildSavedSearchItem(String searchName) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.bookmark),
        title: Text(searchName),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'run') {
              final query = _searchService.loadSavedSearch(searchName);
              if (query != null) {
                _executeQuery(query);
              }
            } else if (action == 'delete') {
              _deleteSavedSearch(searchName);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'run',
              child: ListTile(
                leading: Icon(Icons.play_arrow),
                title: Text('Run Search'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete'),
                dense: true,
              ),
            ),
          ],
        ),
        onTap: () {
          final query = _searchService.loadSavedSearch(searchName);
          if (query != null) {
            _executeQuery(query);
          }
        },
      ),
    );
  }

  void _handleSearchResult(SearchResult result) {
    setState(() {
      _currentResult = result;
    });
  }

  void _handleClearSearch() {
    setState(() {
      _currentResult = null;
    });
  }

  void _handleFileSelected(FileMetadata metadata) {
    // TODO: Implement file selection/preview
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: ${metadata.fileName}'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () {
            // TODO: Open file
          },
        ),
      ),
    );
  }

  Future<void> _handleSearchChanged(SearchQuery query) async {
    try {
      final result = await _searchService.search(query);
      _handleSearchResult(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
      }
    }
  }

  Future<void> _executeQuery(SearchQuery query) async {
    // Switch to search tab
    _tabController.animateTo(0);

    // Execute the query
    await _handleSearchChanged(query);
  }

  void _deleteSavedSearch(String searchName) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Saved Search'),
        content: Text('Are you sure you want to delete "$searchName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        setState(() {
          _searchService.deleteSavedSearch(searchName);
        });
      }
    });
  }

  String _formatSearchQuery(SearchQuery query) {
    final parts = <String>[];

    if (query.categories?.isNotEmpty == true) {
      parts.add(
        'Categories: ${query.categories!.map((c) => c.displayName).join(', ')}',
      );
    }

    if (query.tags?.isNotEmpty == true) {
      parts.add('Tags: ${query.tags!.join(', ')}');
    }

    if (query.dateRange != null) {
      parts.add('Date range');
    }

    if (query.includeArchived) {
      parts.add('Including archived');
    }

    return parts.isEmpty ? 'No filters' : parts.join(' • ');
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
