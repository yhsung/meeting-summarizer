import 'package:flutter/material.dart';
import '../../../../core/models/feedback/feedback_item.dart';
import '../../../feedback/data/services/feedback_service_provider.dart';
import '../screens/feedback_screen.dart';
import '../widgets/rating_dialog.dart';

/// Widget that integrates feedback functionality into the main app
class FeedbackIntegrationWidget extends StatefulWidget {
  final Widget child;

  const FeedbackIntegrationWidget({super.key, required this.child});

  @override
  State<FeedbackIntegrationWidget> createState() =>
      _FeedbackIntegrationWidgetState();
}

class _FeedbackIntegrationWidgetState extends State<FeedbackIntegrationWidget>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeFeedbackService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeFeedbackService() async {
    try {
      await FeedbackServiceProvider.instance.initialize();
    } catch (e) {
      // Log error, but don't crash the app if feedback service fails
      debugPrint('Failed to initialize feedback service: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Check for rating prompt when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _checkForRatingPrompt();
    }
  }

  Future<void> _checkForRatingPrompt() async {
    // Wait a bit to let the app settle
    await Future.delayed(const Duration(seconds: 2));

    final provider = FeedbackServiceProvider.instance;
    if (provider.isInitialized && provider.feedbackService != null && mounted) {
      // Check if we should show the rating prompt
      final shouldShow =
          await provider.feedbackService!.shouldShowRatingPrompt();

      if (shouldShow && mounted) {
        await RatingDialog.showIfAppropriate(
          context: context,
          feedbackService: provider.feedbackService!,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Floating action button for quick feedback access
class FeedbackFloatingActionButton extends StatefulWidget {
  const FeedbackFloatingActionButton({super.key});

  @override
  State<FeedbackFloatingActionButton> createState() =>
      _FeedbackFloatingActionButtonState();
}

class _FeedbackFloatingActionButtonState
    extends State<FeedbackFloatingActionButton> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isExpanded) ...[
          _buildFeedbackOption(
            'Bug Report',
            Icons.bug_report,
            Colors.red,
            () => _showFeedbackForm(FeedbackType.bugReport),
          ),
          const SizedBox(height: 8),
          _buildFeedbackOption(
            'Feature Request',
            Icons.lightbulb,
            Colors.blue,
            () => _showFeedbackForm(FeedbackType.featureRequest),
          ),
          const SizedBox(height: 8),
          _buildFeedbackOption(
            'General',
            Icons.feedback,
            Colors.green,
            () => _showFeedbackForm(FeedbackType.general),
          ),
          const SizedBox(height: 8),
        ],
        FloatingActionButton(
          onPressed: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          backgroundColor: Theme.of(context).primaryColor,
          child: AnimatedRotation(
            turns: _isExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.feedback),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackOption(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          onPressed: onPressed,
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
      ],
    );
  }

  Future<void> _showFeedbackForm(FeedbackType type) async {
    setState(() {
      _isExpanded = false;
    });

    final provider = FeedbackServiceProvider.instance;
    if (!provider.isInitialized) {
      await provider.initialize();
    }

    if (provider.feedbackService != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              FeedbackScreen(feedbackService: provider.feedbackService!),
        ),
      );
    }
  }
}

/// App bar action for feedback
class FeedbackAppBarAction extends StatelessWidget {
  const FeedbackAppBarAction({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) => _handleMenuSelection(context, value),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'feedback',
          child: ListTile(
            leading: Icon(Icons.feedback),
            title: Text('Send Feedback'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'rate',
          child: ListTile(
            leading: Icon(Icons.star),
            title: Text('Rate App'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Future<void> _handleMenuSelection(BuildContext context, String value) async {
    final provider = FeedbackServiceProvider.instance;
    if (!provider.isInitialized) {
      await provider.initialize();
    }

    if (provider.feedbackService == null) return;

    switch (value) {
      case 'feedback':
        if (context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  FeedbackScreen(feedbackService: provider.feedbackService!),
            ),
          );
        }
        break;
      case 'rate':
        await provider.feedbackService!.showRatingPrompt();
        break;
    }
  }
}
