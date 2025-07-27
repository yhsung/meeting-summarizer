import 'package:flutter/material.dart';

import '../../../../core/models/help/faq_item.dart';
import '../../../../core/services/help_service.dart';

/// List widget displaying FAQ items
class HelpFaqList extends StatefulWidget {
  final List<FaqItem> faqs;
  final ValueChanged<FaqItem>? onFaqTap;
  final bool isExpanded;
  final bool showHelpfulness;

  const HelpFaqList({
    super.key,
    required this.faqs,
    this.onFaqTap,
    this.isExpanded = true,
    this.showHelpfulness = false,
  });

  @override
  State<HelpFaqList> createState() => _HelpFaqListState();
}

class _HelpFaqListState extends State<HelpFaqList> {
  final Set<String> _expandedItems = <String>{};
  final HelpService _helpService = HelpService.instance;

  @override
  void initState() {
    super.initState();
    if (widget.isExpanded) {
      _expandedItems.addAll(widget.faqs.map((faq) => faq.id));
    }
  }

  void _toggleExpansion(String faqId) {
    setState(() {
      if (_expandedItems.contains(faqId)) {
        _expandedItems.remove(faqId);
      } else {
        _expandedItems.add(faqId);
      }
    });
  }

  Future<void> _voteFaqHelpfulness(FaqItem faq, bool isHelpful) async {
    await _helpService.voteFaqHelpfulness(faq.id, isHelpful);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isHelpful ? 'Thanks for your feedback!' : 'Feedback recorded',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.faqs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.help_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No FAQ items available'),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.faqs.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final faq = widget.faqs[index];
        final isExpanded = _expandedItems.contains(faq.id);

        return _FaqListItem(
          faq: faq,
          isExpanded: isExpanded,
          onTap: () {
            widget.onFaqTap?.call(faq);
            _toggleExpansion(faq.id);
          },
          onVoteHelpfulness: widget.showHelpfulness
              ? (isHelpful) => _voteFaqHelpfulness(faq, isHelpful)
              : null,
          showHelpfulness: widget.showHelpfulness,
        );
      },
    );
  }
}

class _FaqListItem extends StatelessWidget {
  final FaqItem faq;
  final bool isExpanded;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onVoteHelpfulness;
  final bool showHelpfulness;

  const _FaqListItem({
    required this.faq,
    required this.isExpanded,
    this.onTap,
    this.onVoteHelpfulness,
    this.showHelpfulness = false,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: ValueKey(faq.id),
      initiallyExpanded: isExpanded,
      onExpansionChanged: (_) => onTap?.call(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.all(16),
      title: Row(
        children: [
          Expanded(
            child: Text(
              faq.question,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (faq.isPopular)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Popular',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
        ],
      ),
      subtitle: _buildSubtitle(context),
      children: [
        _buildAnswer(context),
        if (showHelpfulness) ...[
          const SizedBox(height: 16),
          _buildHelpfulnessSection(context),
        ],
        if (faq.relatedQuestions.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildRelatedQuestions(context),
        ],
      ],
    );
  }

  Widget? _buildSubtitle(BuildContext context) {
    if (faq.tags.isEmpty && faq.viewCount == 0) return null;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          if (faq.viewCount > 0) ...[
            Icon(
              Icons.visibility,
              size: 14,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 4),
            Text(
              '${faq.viewCount} views',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
            ),
            const SizedBox(width: 12),
          ],
          if (faq.tags.isNotEmpty)
            Expanded(
              child: Wrap(
                spacing: 4,
                runSpacing: 2,
                children: faq.tags.take(2).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tag,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                          ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnswer(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(faq.answer, style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  Widget _buildHelpfulnessSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Was this helpful?',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => onVoteHelpfulness?.call(true),
                icon: const Icon(Icons.thumb_up, size: 16),
                label: const Text('Yes'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => onVoteHelpfulness?.call(false),
                icon: const Icon(Icons.thumb_down, size: 16),
                label: const Text('No'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
              const Spacer(),
              if (faq.totalVotes > 0)
                Text(
                  '${faq.helpfulnessPercent.toStringAsFixed(0)}% helpful (${faq.totalVotes} votes)',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedQuestions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Related Questions',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...faq.relatedQuestions.take(3).map((questionId) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.arrow_right, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Related question #$questionId',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
