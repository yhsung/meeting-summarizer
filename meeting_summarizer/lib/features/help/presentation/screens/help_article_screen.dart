import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as dev;

import '../../../../core/models/help/help_article.dart';
import '../../../../core/services/help_service.dart';

/// Screen displaying a single help article
class HelpArticleScreen extends StatefulWidget {
  final HelpArticle article;

  const HelpArticleScreen({super.key, required this.article});

  @override
  State<HelpArticleScreen> createState() => _HelpArticleScreenState();
}

class _HelpArticleScreenState extends State<HelpArticleScreen> {
  final HelpService _helpService = HelpService.instance;
  final ScrollController _scrollController = ScrollController();

  List<HelpArticle> _relatedArticles = [];
  bool _isLoadingRelated = false;

  @override
  void initState() {
    super.initState();
    _loadRelatedArticles();
    _trackArticleView();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRelatedArticles() async {
    setState(() {
      _isLoadingRelated = true;
    });

    try {
      final allArticles = await _helpService.getAllArticles();
      final related = allArticles
          .where(
            (article) =>
                article.id != widget.article.id &&
                (article.category.id == widget.article.category.id ||
                    article.tags.any(
                      (tag) => widget.article.tags.contains(tag),
                    )),
          )
          .take(3)
          .toList();

      if (mounted) {
        setState(() {
          _relatedArticles = related;
          _isLoadingRelated = false;
        });
      }
    } catch (e) {
      dev.log(
        'Error loading related articles: $e',
        name: 'HelpArticleScreen',
        level: 900,
      );
      if (mounted) {
        setState(() {
          _isLoadingRelated = false;
        });
      }
    }
  }

  Future<void> _trackArticleView() async {
    try {
      await _helpService.incrementArticleViews(widget.article.id);
    } catch (e) {
      dev.log(
        'Error tracking article view: $e',
        name: 'HelpArticleScreen',
        level: 900,
      );
    }
  }

  void _shareArticle() {
    // TODO: Implement article sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Article sharing feature coming soon')),
    );
  }

  void _copyArticleLink() {
    Clipboard.setData(
      ClipboardData(text: 'help://article/${widget.article.id}'),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Article link copied to clipboard')),
    );
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.article.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareArticle,
            tooltip: 'Share article',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'copy_link':
                  _copyArticleLink();
                  break;
                case 'scroll_top':
                  _scrollToTop();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'copy_link',
                child: Row(
                  children: [
                    Icon(Icons.link),
                    SizedBox(width: 8),
                    Text('Copy Link'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'scroll_top',
                child: Row(
                  children: [
                    Icon(Icons.keyboard_arrow_up),
                    SizedBox(width: 8),
                    Text('Scroll to Top'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildArticleHeader(),
            const SizedBox(height: 24),
            _buildArticleContent(),
            const SizedBox(height: 32),
            if (widget.article.tags.isNotEmpty) ...[
              _buildTagsSection(),
              const SizedBox(height: 32),
            ],
            if (widget.article.videoUrl != null) ...[
              _buildVideoSection(),
              const SizedBox(height: 32),
            ],
            _buildRelatedArticles(),
            const SizedBox(height: 32),
            _buildHelpfulnessSection(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scrollToTop,
        mini: true,
        child: const Icon(Icons.keyboard_arrow_up),
      ),
    );
  }

  Widget _buildArticleHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category and featured badge
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: widget.article.category.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.article.category.color.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.article.category.icon,
                    size: 16,
                    color: widget.article.category.color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.article.category.name,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: widget.article.category.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.article.isFeatured) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Featured',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // Article title
        Text(
          widget.article.title,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Article excerpt
        Text(
          widget.article.excerpt,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),

        // Article metadata
        Row(
          children: [
            Icon(
              Icons.access_time,
              size: 16,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 4),
            Text(
              'Updated ${_formatDate(widget.article.updatedAt)}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            if (widget.article.viewCount > 0) ...[
              const SizedBox(width: 16),
              Icon(
                Icons.visibility,
                size: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                '${widget.article.viewCount} views',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildArticleContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        widget.article.content,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.article.tags.map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                tag,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVideoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Video Tutorial',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_circle_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Video Tutorial Available',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement video player
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Video player feature coming soon'),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Watch Video'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedArticles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Related Articles',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_isLoadingRelated)
          const Center(child: CircularProgressIndicator())
        else if (_relatedArticles.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 8),
                Text(
                  'No related articles found',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: _relatedArticles.map((article) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: article.category.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      article.category.icon,
                      color: article.category.color,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    article.excerpt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            HelpArticleScreen(article: article),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildHelpfulnessSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Was this article helpful?',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _voteHelpfulness(true),
                icon: const Icon(Icons.thumb_up, size: 18),
                label: const Text('Yes, helpful'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _voteHelpfulness(false),
                icon: const Icon(Icons.thumb_down, size: 18),
                label: const Text('Not helpful'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _voteHelpfulness(bool isHelpful) {
    // TODO: Implement helpfulness voting
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isHelpful ? 'Thanks for your feedback!' : 'Feedback recorded',
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
