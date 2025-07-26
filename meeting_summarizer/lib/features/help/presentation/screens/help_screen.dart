import 'package:flutter/material.dart';
import 'dart:developer' as dev;

import '../../../../core/models/help/help_article.dart';
import '../../../../core/models/help/faq_item.dart';
import '../../../../core/services/help_service.dart';
import '../widgets/help_search_bar.dart';
import '../widgets/help_category_grid.dart';
import '../widgets/help_article_list.dart';
import '../widgets/help_faq_list.dart';
import '../widgets/help_quick_actions.dart';

/// Main help screen with search, categories, and content
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen>
    with SingleTickerProviderStateMixin {
  final HelpService _helpService = HelpService.instance;
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;

  List<HelpCategory> _categories = [];
  List<HelpArticle> _articles = [];
  List<HelpArticle> _featuredArticles = [];
  List<FaqItem> _faqs = [];
  List<FaqItem> _popularFaqs = [];

  // Search state
  bool _isSearching = false;
  String _searchQuery = '';
  List<HelpArticle> _searchArticles = [];
  List<FaqItem> _searchFaqs = [];

  // Loading state
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHelpContent();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHelpContent() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final results = await Future.wait([
        _helpService.getAllCategories(),
        _helpService.getAllArticles(),
        _helpService.getFeaturedArticles(),
        _helpService.getAllFaqs(),
        _helpService.getPopularFaqs(),
      ]);

      if (mounted) {
        setState(() {
          _categories = results[0] as List<HelpCategory>;
          _articles = results[1] as List<HelpArticle>;
          _featuredArticles = results[2] as List<HelpArticle>;
          _faqs = results[3] as List<FaqItem>;
          _popularFaqs = results[4] as List<FaqItem>;
          _isLoading = false;
        });
      }

      dev.log('Help content loaded successfully', name: 'HelpScreen');
    } catch (e) {
      dev.log('Error loading help content: $e', name: 'HelpScreen', level: 900);
      if (mounted) {
        setState(() {
          _error = 'Failed to load help content. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
        _isSearching = query.isNotEmpty;
      });

      if (query.isNotEmpty) {
        _performSearch(query);
      }
    }
  }

  Future<void> _performSearch(String query) async {
    try {
      final results = await Future.wait([
        _helpService.searchArticles(query),
        _helpService.searchFaqs(query),
      ]);

      if (mounted && query == _searchQuery) {
        setState(() {
          _searchArticles = results[0] as List<HelpArticle>;
          _searchFaqs = results[1] as List<FaqItem>;
        });
      }
    } catch (e) {
      dev.log('Error performing search: $e', name: 'HelpScreen', level: 900);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchArticles.clear();
      _searchFaqs.clear();
    });
  }

  Future<void> _refresh() async {
    await _helpService.refreshCache();
    await _loadHelpContent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh help content',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 60),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: HelpSearchBar(
                  controller: _searchController,
                  onClear: _clearSearch,
                  helpService: _helpService,
                ),
              ),
              if (!_isSearching)
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Overview', icon: Icon(Icons.home)),
                    Tab(text: 'Articles', icon: Icon(Icons.article)),
                    Tab(text: 'FAQ', icon: Icon(Icons.help)),
                  ],
                ),
            ],
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading help content...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadHelpContent,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_isSearching) {
      return _buildSearchResults();
    }

    return TabBarView(
      controller: _tabController,
      children: [_buildOverviewTab(), _buildArticlesTab(), _buildFaqTab()],
    );
  }

  Widget _buildSearchResults() {
    final hasResults = _searchArticles.isNotEmpty || _searchFaqs.isNotEmpty;

    if (!hasResults && _searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found for "$_searchQuery"',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or browse categories',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search Results for "$_searchQuery"',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          if (_searchArticles.isNotEmpty) ...[
            Text(
              'Articles (${_searchArticles.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            HelpArticleList(
              articles: _searchArticles,
              onArticleTap: _navigateToArticle,
            ),
            const SizedBox(height: 24),
          ],

          if (_searchFaqs.isNotEmpty) ...[
            Text(
              'FAQ (${_searchFaqs.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            HelpFaqList(faqs: _searchFaqs, onFaqTap: _navigateToFaq),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick actions
          HelpQuickActions(
            onContactSupport: _contactSupport,
            onVideoTutorials: _openVideoTutorials,
            onUserGuide: _openUserGuide,
          ),
          const SizedBox(height: 24),

          // Categories
          Text(
            'Browse by Category',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          HelpCategoryGrid(
            categories: _categories,
            onCategoryTap: _navigateToCategory,
          ),
          const SizedBox(height: 24),

          // Featured articles
          if (_featuredArticles.isNotEmpty) ...[
            Text(
              'Featured Articles',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            HelpArticleList(
              articles: _featuredArticles.take(3).toList(),
              onArticleTap: _navigateToArticle,
              showExcerpt: true,
            ),
            const SizedBox(height: 24),
          ],

          // Popular FAQs
          if (_popularFaqs.isNotEmpty) ...[
            Text(
              'Popular Questions',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            HelpFaqList(
              faqs: _popularFaqs.take(3).toList(),
              onFaqTap: _navigateToFaq,
              isExpanded: false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArticlesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All Articles (${_articles.length})',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          HelpArticleList(
            articles: _articles,
            onArticleTap: _navigateToArticle,
            showExcerpt: true,
            showCategory: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFaqTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Frequently Asked Questions (${_faqs.length})',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          HelpFaqList(
            faqs: _faqs,
            onFaqTap: _navigateToFaq,
            isExpanded: false,
            showHelpfulness: true,
          ),
        ],
      ),
    );
  }

  void _navigateToArticle(HelpArticle article) {
    _helpService.incrementArticleViews(article.id);
    Navigator.pushNamed(context, '/help/article', arguments: article);
  }

  void _navigateToFaq(FaqItem faq) {
    _helpService.incrementFaqViews(faq.id);
    Navigator.pushNamed(context, '/help/faq', arguments: faq);
  }

  void _navigateToCategory(HelpCategory category) {
    Navigator.pushNamed(context, '/help/category', arguments: category);
  }

  void _contactSupport() {
    // TODO: Implement contact support functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contact support feature coming soon')),
    );
  }

  void _openVideoTutorials() {
    // TODO: Implement video tutorials functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Video tutorials feature coming soon')),
    );
  }

  void _openUserGuide() {
    // Navigate to user guide article
    final userGuideArticle = _articles.firstWhere(
      (article) => article.id == 'welcome',
      orElse: () => _articles.first,
    );
    _navigateToArticle(userGuideArticle);
  }
}
