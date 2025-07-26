import 'package:flutter/material.dart';
import '../../../../core/models/feedback/feedback_item.dart';
import '../../../../core/services/feedback_service.dart';

/// Dialog for collecting user ratings with smart prompts
class RatingDialog extends StatefulWidget {
  final FeedbackService feedbackService;
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;

  const RatingDialog({
    super.key,
    required this.feedbackService,
    this.onComplete,
    this.onSkip,
  });

  /// Show the rating dialog if conditions are met
  static Future<void> showIfAppropriate({
    required BuildContext context,
    required FeedbackService feedbackService,
    VoidCallback? onComplete,
    VoidCallback? onSkip,
  }) async {
    if (await feedbackService.shouldShowRatingPrompt()) {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => RatingDialog(
            feedbackService: feedbackService,
            onComplete: onComplete,
            onSkip: onSkip,
          ),
        );
      }
    }
  }

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog>
    with SingleTickerProviderStateMixin {
  int _selectedRating = 0;
  bool _isSubmitting = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Submit rating feedback
      await widget.feedbackService.submitFeedback(
        type: FeedbackType.rating,
        rating: _selectedRating,
        subject: 'App Rating',
        message: 'User rated the app $_selectedRating stars',
        tags: ['rating', 'user_feedback'],
      );

      // If rating is 4-5 stars, prompt for app store review
      if (_selectedRating >= 4) {
        await widget.feedbackService.showRatingPrompt();
      }

      widget.onComplete?.call();

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _skipRating() async {
    widget.onSkip?.call();
    Navigator.of(context).pop();
  }

  Future<void> _neverAskAgain() async {
    await widget.feedbackService.neverShowRatingPrompt();
    widget.onSkip?.call();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App icon or emoji
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Icon(
                  Icons.favorite,
                  size: 32,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Enjoying the app?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Let us know what you think!',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Star rating
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRating = starIndex;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.star,
                          size: 40,
                          color: starIndex <= _selectedRating
                              ? Colors.amber
                              : Colors.grey[300],
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedRating > 0 && !_isSubmitting
                      ? _submitRating
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Rating'),
                ),
              ),
              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting ? null : _skipRating,
                      child: const Text('Maybe Later'),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting ? null : _neverAskAgain,
                      child: const Text('Don\'t Ask Again'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
