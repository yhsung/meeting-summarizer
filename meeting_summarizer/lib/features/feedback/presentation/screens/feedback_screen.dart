import 'package:flutter/material.dart';
import '../../../../core/models/feedback/feedback_item.dart';
import '../../../../core/models/feedback/feedback_analytics.dart';
import '../../../../core/services/feedback_service.dart';
import '../widgets/feedback_form.dart';
import '../widgets/rating_dialog.dart';

/// Main feedback screen for managing user feedback and viewing analytics
class FeedbackScreen extends StatefulWidget {
  final FeedbackService feedbackService;

  const FeedbackScreen({super.key, required this.feedbackService});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  List<FeedbackItem> _feedbackItems = [];
  FeedbackAnalytics _analytics = FeedbackAnalytics.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeedbackData();
  }

  Future<void> _loadFeedbackData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final feedback = await widget.feedbackService.getAllFeedback();
      final analytics = await widget.feedbackService.getFeedbackAnalytics();

      setState(() {
        _feedbackItems = feedback;
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showFeedbackForm(FeedbackType type) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FeedbackForm(
          feedbackService: widget.feedbackService,
          initialType: type,
          onSubmitted: _loadFeedbackData,
        ),
      ),
    );
  }

  Future<void> _showRatingDialog() async {
    await RatingDialog.showIfAppropriate(
      context: context,
      feedbackService: widget.feedbackService,
      onComplete: _loadFeedbackData,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback'),
        actions: [
          IconButton(
            onPressed: _loadFeedbackData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Analytics Overview
                _buildAnalyticsCard(),
                const SizedBox(height: 16),

                // Quick Actions
                _buildQuickActionsCard(),
                const SizedBox(height: 16),

                // Recent Feedback
                _buildRecentFeedbackCard(),
              ],
            ),
    );
  }

  Widget _buildAnalyticsCard() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Feedback Overview',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Feedback',
                    _analytics.totalFeedback.toString(),
                    '💬',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Average Rating',
                    _analytics.averageRating > 0
                        ? _analytics.averageRating.toStringAsFixed(1)
                        : 'N/A',
                    '⭐',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Bug Reports',
                    _analytics.bugReports.toString(),
                    '🐛',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Feature Requests',
                    _analytics.featureRequests.toString(),
                    '💡',
                  ),
                ),
              ],
            ),

            if (_analytics.ratingDistribution.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Rating Distribution',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildRatingDistribution(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String emoji) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRatingDistribution() {
    final theme = Theme.of(context);
    final maxCount = _analytics.ratingDistribution.values.isNotEmpty
        ? _analytics.ratingDistribution.values.reduce((a, b) => a > b ? a : b)
        : 1;

    return Column(
      children: List.generate(5, (index) {
        final rating = 5 - index;
        final count = _analytics.ratingDistribution[rating] ?? 0;
        final percentage = maxCount > 0 ? count / maxCount : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Text('$rating ⭐', style: theme.textTheme.bodySmall),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text(
                  count.toString(),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildQuickActionsCard() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Rate App',
                    '⭐',
                    Colors.amber,
                    () => _showRatingDialog(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Report Bug',
                    '🐛',
                    Colors.red,
                    () => _showFeedbackForm(FeedbackType.bugReport),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Feature Request',
                    '💡',
                    Colors.blue,
                    () => _showFeedbackForm(FeedbackType.featureRequest),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'General Feedback',
                    '💬',
                    Colors.green,
                    () => _showFeedbackForm(FeedbackType.general),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    String emoji,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentFeedbackCard() {
    final theme = Theme.of(context);
    final recentFeedback = _feedbackItems.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Feedback',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_feedbackItems.length > 5)
                  TextButton(
                    onPressed: () {
                      // Navigate to full feedback list
                    },
                    child: const Text('View All'),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (recentFeedback.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.feedback_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No feedback yet',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Share your thoughts to help us improve!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...recentFeedback.map((feedback) => _buildFeedbackTile(feedback)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackTile(FeedbackItem feedback) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(feedback.type.icon),
        ),
        title: Text(
          feedback.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              feedback.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (feedback.rating != null) ...[
                  ...List.generate(
                    feedback.rating!,
                    (index) =>
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _formatDate(feedback.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(
          feedback.isSubmitted ? Icons.check_circle : Icons.pending,
          color: feedback.isSubmitted ? Colors.green : Colors.orange,
          size: 20,
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.month}/${date.day}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }
}
