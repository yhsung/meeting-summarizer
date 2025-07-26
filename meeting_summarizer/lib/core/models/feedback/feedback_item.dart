import 'package:json_annotation/json_annotation.dart';

part 'feedback_item.g.dart';

/// Represents a feedback item submitted by the user
@JsonSerializable()
class FeedbackItem {
  /// Unique identifier for the feedback
  final String id;

  /// Type of feedback (rating, bug_report, feature_request, general)
  final FeedbackType type;

  /// User rating (1-5 stars, only for rating feedback)
  final int? rating;

  /// Feedback subject/title
  final String subject;

  /// Detailed feedback message
  final String message;

  /// User's email for follow-up (optional)
  final String? email;

  /// Device/app version information
  final String appVersion;

  /// Platform information (iOS, Android, Web, etc.)
  final String platform;

  /// Timestamp when feedback was created
  final DateTime createdAt;

  /// Whether the feedback has been submitted successfully
  final bool isSubmitted;

  /// Optional screenshot or attachment reference
  final String? attachmentPath;

  /// Tags associated with the feedback
  final List<String> tags;

  const FeedbackItem({
    required this.id,
    required this.type,
    this.rating,
    required this.subject,
    required this.message,
    this.email,
    required this.appVersion,
    required this.platform,
    required this.createdAt,
    required this.isSubmitted,
    this.attachmentPath,
    required this.tags,
  });

  factory FeedbackItem.fromJson(Map<String, dynamic> json) =>
      _$FeedbackItemFromJson(json);

  Map<String, dynamic> toJson() => _$FeedbackItemToJson(this);

  FeedbackItem copyWith({
    String? id,
    FeedbackType? type,
    int? rating,
    String? subject,
    String? message,
    String? email,
    String? appVersion,
    String? platform,
    DateTime? createdAt,
    bool? isSubmitted,
    String? attachmentPath,
    List<String>? tags,
  }) {
    return FeedbackItem(
      id: id ?? this.id,
      type: type ?? this.type,
      rating: rating ?? this.rating,
      subject: subject ?? this.subject,
      message: message ?? this.message,
      email: email ?? this.email,
      appVersion: appVersion ?? this.appVersion,
      platform: platform ?? this.platform,
      createdAt: createdAt ?? this.createdAt,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      tags: tags ?? this.tags,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedbackItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'FeedbackItem{id: $id, type: $type, subject: $subject, isSubmitted: $isSubmitted}';
  }
}

/// Types of feedback that can be collected
enum FeedbackType {
  /// User rating with stars
  @JsonValue('rating')
  rating,

  /// Bug report
  @JsonValue('bug_report')
  bugReport,

  /// Feature request
  @JsonValue('feature_request')
  featureRequest,

  /// General feedback
  @JsonValue('general')
  general,
}

extension FeedbackTypeExtension on FeedbackType {
  String get displayName {
    switch (this) {
      case FeedbackType.rating:
        return 'Rating';
      case FeedbackType.bugReport:
        return 'Bug Report';
      case FeedbackType.featureRequest:
        return 'Feature Request';
      case FeedbackType.general:
        return 'General Feedback';
    }
  }

  String get icon {
    switch (this) {
      case FeedbackType.rating:
        return '⭐';
      case FeedbackType.bugReport:
        return '🐛';
      case FeedbackType.featureRequest:
        return '💡';
      case FeedbackType.general:
        return '💬';
    }
  }
}
