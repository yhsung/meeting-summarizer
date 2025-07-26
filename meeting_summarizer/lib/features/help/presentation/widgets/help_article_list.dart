import 'package:flutter/material.dart';

import '../../../../core/models/help/help_article.dart';

/// List widget displaying help articles
class HelpArticleList extends StatelessWidget {
  final List<HelpArticle> articles;
  final ValueChanged<HelpArticle>? onArticleTap;
  final bool showExcerpt;
  final bool showCategory;
  final bool showMetadata;

  const HelpArticleList({
    super.key,
    required this.articles,
    this.onArticleTap,
    this.showExcerpt = false,
    this.showCategory = false,
    this.showMetadata = false,
  });

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No articles available'),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: articles.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final article = articles[index];
        return _ArticleListItem(
          article: article,
          onTap: () => onArticleTap?.call(article),
          showExcerpt: showExcerpt,
          showCategory: showCategory,
          showMetadata: showMetadata,
        );
      },
    );
  }
}

class _ArticleListItem extends StatelessWidget {
  final HelpArticle article;
  final VoidCallback? onTap;
  final bool showExcerpt;
  final bool showCategory;
  final bool showMetadata;

  const _ArticleListItem({
    required this.article,
    this.onTap,
    this.showExcerpt = false,
    this.showCategory = false,
    this.showMetadata = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: onTap,
      leading: _buildLeading(context),
      title: _buildTitle(context),
      subtitle: _buildSubtitle(context),
      trailing: _buildTrailing(context),
    );
  }

  Widget _buildLeading(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: article.category.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              article.category.icon,
              color: article.category.color,
              size: 24,
            ),
          ),
          if (article.isFeatured)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.star, size: 8, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          article.title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (showCategory) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                article.category.icon,
                size: 14,
                color: article.category.color,
              ),
              const SizedBox(width: 4),
              Text(
                article.category.name,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: article.category.color,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget? _buildSubtitle(BuildContext context) {
    if (!showExcerpt && !showMetadata) return null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showExcerpt) ...[
          const SizedBox(height: 4),
          Text(
            article.excerpt,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (showMetadata) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (article.viewCount > 0) ...[
                Icon(
                  Icons.visibility,
                  size: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  '${article.viewCount} views',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                ),
                const SizedBox(width: 12),
              ],
              Icon(
                Icons.access_time,
                size: 14,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(article.updatedAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
              ),
            ],
          ),
        ],
        if (article.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: article.tags.take(3).map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tag,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    return Icon(
      Icons.chevron_right,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
