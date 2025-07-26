// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feedback_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FeedbackItem _$FeedbackItemFromJson(Map<String, dynamic> json) => FeedbackItem(
  id: json['id'] as String,
  type: $enumDecode(_$FeedbackTypeEnumMap, json['type']),
  rating: (json['rating'] as num?)?.toInt(),
  subject: json['subject'] as String,
  message: json['message'] as String,
  email: json['email'] as String?,
  appVersion: json['appVersion'] as String,
  platform: json['platform'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  isSubmitted: json['isSubmitted'] as bool,
  attachmentPath: json['attachmentPath'] as String?,
  tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
);

Map<String, dynamic> _$FeedbackItemToJson(FeedbackItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$FeedbackTypeEnumMap[instance.type]!,
      'rating': instance.rating,
      'subject': instance.subject,
      'message': instance.message,
      'email': instance.email,
      'appVersion': instance.appVersion,
      'platform': instance.platform,
      'createdAt': instance.createdAt.toIso8601String(),
      'isSubmitted': instance.isSubmitted,
      'attachmentPath': instance.attachmentPath,
      'tags': instance.tags,
    };

const _$FeedbackTypeEnumMap = {
  FeedbackType.rating: 'rating',
  FeedbackType.bugReport: 'bug_report',
  FeedbackType.featureRequest: 'feature_request',
  FeedbackType.general: 'general',
};
