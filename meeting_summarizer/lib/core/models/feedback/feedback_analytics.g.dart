// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feedback_analytics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FeedbackAnalytics _$FeedbackAnalyticsFromJson(Map<String, dynamic> json) =>
    FeedbackAnalytics(
      totalFeedback: (json['totalFeedback'] as num).toInt(),
      totalRatings: (json['totalRatings'] as num).toInt(),
      averageRating: (json['averageRating'] as num).toDouble(),
      bugReports: (json['bugReports'] as num).toInt(),
      featureRequests: (json['featureRequests'] as num).toInt(),
      generalFeedback: (json['generalFeedback'] as num).toInt(),
      lastFeedbackDate: json['lastFeedbackDate'] == null
          ? null
          : DateTime.parse(json['lastFeedbackDate'] as String),
      ratingDistribution: (json['ratingDistribution'] as Map<String, dynamic>)
          .map((k, e) => MapEntry(int.parse(k), (e as num).toInt())),
      tagFrequency: Map<String, int>.from(json['tagFrequency'] as Map),
      averageRatingPromptDelay: json['averageRatingPromptDelay'] == null
          ? null
          : Duration(
              microseconds: (json['averageRatingPromptDelay'] as num).toInt(),
            ),
    );

Map<String, dynamic> _$FeedbackAnalyticsToJson(
  FeedbackAnalytics instance,
) => <String, dynamic>{
  'totalFeedback': instance.totalFeedback,
  'totalRatings': instance.totalRatings,
  'averageRating': instance.averageRating,
  'bugReports': instance.bugReports,
  'featureRequests': instance.featureRequests,
  'generalFeedback': instance.generalFeedback,
  'lastFeedbackDate': instance.lastFeedbackDate?.toIso8601String(),
  'ratingDistribution': instance.ratingDistribution.map(
    (k, e) => MapEntry(k.toString(), e),
  ),
  'tagFrequency': instance.tagFrequency,
  'averageRatingPromptDelay': instance.averageRatingPromptDelay?.inMicroseconds,
};
