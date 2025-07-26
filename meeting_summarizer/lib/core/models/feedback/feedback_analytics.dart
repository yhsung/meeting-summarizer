import 'package:json_annotation/json_annotation.dart';
import 'feedback_item.dart';

part 'feedback_analytics.g.dart';

/// Analytics data for feedback collection
@JsonSerializable()
class FeedbackAnalytics {
  /// Total number of feedback items collected
  final int totalFeedback;

  /// Number of ratings collected
  final int totalRatings;

  /// Average rating (1-5 stars)
  final double averageRating;

  /// Number of bug reports
  final int bugReports;

  /// Number of feature requests
  final int featureRequests;

  /// Number of general feedback items
  final int generalFeedback;

  /// Most recent feedback date
  final DateTime? lastFeedbackDate;

  /// Distribution of ratings (1-5 stars)
  final Map<int, int> ratingDistribution;

  /// Common feedback tags and their frequency
  final Map<String, int> tagFrequency;

  /// Average time between app launch and rating prompt
  final Duration? averageRatingPromptDelay;

  const FeedbackAnalytics({
    required this.totalFeedback,
    required this.totalRatings,
    required this.averageRating,
    required this.bugReports,
    required this.featureRequests,
    required this.generalFeedback,
    this.lastFeedbackDate,
    required this.ratingDistribution,
    required this.tagFrequency,
    this.averageRatingPromptDelay,
  });

  factory FeedbackAnalytics.empty() {
    return const FeedbackAnalytics(
      totalFeedback: 0,
      totalRatings: 0,
      averageRating: 0.0,
      bugReports: 0,
      featureRequests: 0,
      generalFeedback: 0,
      ratingDistribution: {},
      tagFrequency: {},
    );
  }

  factory FeedbackAnalytics.fromFeedbackList(List<FeedbackItem> feedback) {
    if (feedback.isEmpty) {
      return FeedbackAnalytics.empty();
    }

    final ratings = feedback
        .where((f) => f.type == FeedbackType.rating && f.rating != null)
        .map((f) => f.rating!)
        .toList();

    final ratingDistribution = <int, int>{};
    for (final rating in ratings) {
      ratingDistribution[rating] = (ratingDistribution[rating] ?? 0) + 1;
    }

    final tagFrequency = <String, int>{};
    for (final item in feedback) {
      for (final tag in item.tags) {
        tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
      }
    }

    return FeedbackAnalytics(
      totalFeedback: feedback.length,
      totalRatings: ratings.length,
      averageRating: ratings.isEmpty
          ? 0.0
          : ratings.reduce((a, b) => a + b) / ratings.length,
      bugReports:
          feedback.where((f) => f.type == FeedbackType.bugReport).length,
      featureRequests:
          feedback.where((f) => f.type == FeedbackType.featureRequest).length,
      generalFeedback:
          feedback.where((f) => f.type == FeedbackType.general).length,
      lastFeedbackDate: feedback
          .map((f) => f.createdAt)
          .reduce((a, b) => a.isAfter(b) ? a : b),
      ratingDistribution: ratingDistribution,
      tagFrequency: tagFrequency,
    );
  }

  factory FeedbackAnalytics.fromJson(Map<String, dynamic> json) =>
      _$FeedbackAnalyticsFromJson(json);

  Map<String, dynamic> toJson() => _$FeedbackAnalyticsToJson(this);

  /// Returns true if we have enough positive ratings to show app store prompt
  bool get shouldPromptAppStoreReview {
    if (totalRatings < 5) return false;
    return averageRating >= 4.0;
  }

  /// Returns true if we should collect more feedback before prompting
  bool get needsMoreFeedback {
    return totalFeedback < 10 || averageRating < 3.5;
  }

  @override
  String toString() {
    return 'FeedbackAnalytics{totalFeedback: $totalFeedback, averageRating: $averageRating}';
  }
}
