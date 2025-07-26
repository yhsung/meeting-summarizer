import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/models/feedback/feedback_item.dart';
import '../../presentation/widgets/feedback_form.dart';

/// Provider for feedback service initialization and management
class FeedbackServiceProvider extends ChangeNotifier {
  static FeedbackServiceProvider? _instance;
  FeedbackService? _feedbackService;
  bool _isInitialized = false;

  FeedbackServiceProvider._internal();

  static FeedbackServiceProvider get instance {
    _instance ??= FeedbackServiceProvider._internal();
    return _instance!;
  }

  /// Get the feedback service instance
  FeedbackService? get feedbackService => _feedbackService;

  /// Check if feedback service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the feedback service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final databaseHelper = DatabaseHelper();

      _feedbackService = FeedbackService(
        databaseHelper: databaseHelper,
        prefs: prefs,
      );

      await _feedbackService!.initialize();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to initialize FeedbackService: $e');
    }
  }

  /// Show rating dialog if appropriate
  Future<void> checkAndShowRatingPrompt(BuildContext context) async {
    if (!_isInitialized || _feedbackService == null) {
      await initialize();
    }

    if (_feedbackService != null) {
      await _feedbackService!.showRatingPrompt();
    }
  }

  /// Get feedback statistics for debugging
  Future<Map<String, dynamic>> getFeedbackStats() async {
    if (!_isInitialized || _feedbackService == null) {
      await initialize();
    }

    return _feedbackService?.getFeedbackStats() ?? {};
  }

  /// Reset all feedback preferences (for testing or reset functionality)
  Future<void> resetFeedbackData() async {
    if (!_isInitialized || _feedbackService == null) {
      await initialize();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_rating_prompt');
    await prefs.remove('app_launch_count');
    await prefs.remove('feedback_submitted');
    await prefs.remove('never_show_rating');
    await prefs.remove('has_rated_app');

    notifyListeners();
  }

  @override
  void dispose() {
    _feedbackService?.dispose();
    super.dispose();
  }
}

/// Helper class for creating feedback-related UI components
class FeedbackUIHelper {
  /// Build a feedback section widget for settings or other screens
  static Widget buildFeedbackSection(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Feedback & Support',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('Rate This App'),
              subtitle: const Text('Share your experience on the app store'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final provider = FeedbackServiceProvider.instance;
                await provider.checkAndShowRatingPrompt(context);
              },
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Report a Bug'),
              subtitle: const Text('Help us fix issues you encounter'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _navigateToFeedbackForm(context, FeedbackType.bugReport);
              },
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('Request a Feature'),
              subtitle: const Text('Suggest improvements and new features'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _navigateToFeedbackForm(context, FeedbackType.featureRequest);
              },
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.feedback_outlined),
              title: const Text('General Feedback'),
              subtitle: const Text('Share your thoughts and suggestions'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _navigateToFeedbackForm(context, FeedbackType.general);
              },
            ),
          ],
        ),
      ),
    );
  }

  static void _navigateToFeedbackForm(
    BuildContext context,
    FeedbackType type,
  ) async {
    final provider = FeedbackServiceProvider.instance;
    if (!provider.isInitialized) {
      await provider.initialize();
    }

    if (provider.feedbackService != null && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FeedbackForm(
            feedbackService: provider.feedbackService!,
            initialType: type,
          ),
        ),
      );
    }
  }
}
