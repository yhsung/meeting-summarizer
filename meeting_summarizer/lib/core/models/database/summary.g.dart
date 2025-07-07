// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Summary _$SummaryFromJson(Map<String, dynamic> json) => Summary(
  id: json['id'] as String,
  transcriptionId: json['transcriptionId'] as String,
  content: json['content'] as String,
  type: $enumDecode(_$SummaryTypeEnumMap, json['type']),
  provider: json['provider'] as String,
  model: json['model'] as String?,
  prompt: json['prompt'] as String?,
  confidence: (json['confidence'] as num).toDouble(),
  wordCount: (json['wordCount'] as num).toInt(),
  characterCount: (json['characterCount'] as num).toInt(),
  keyPoints: (json['keyPoints'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  actionItems: (json['actionItems'] as List<dynamic>?)
      ?.map((e) => ActionItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  sentiment: $enumDecode(_$SentimentTypeEnumMap, json['sentiment']),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$SummaryToJson(Summary instance) => <String, dynamic>{
  'id': instance.id,
  'transcriptionId': instance.transcriptionId,
  'content': instance.content,
  'type': _$SummaryTypeEnumMap[instance.type]!,
  'provider': instance.provider,
  'model': instance.model,
  'prompt': instance.prompt,
  'confidence': instance.confidence,
  'wordCount': instance.wordCount,
  'characterCount': instance.characterCount,
  'keyPoints': instance.keyPoints,
  'actionItems': instance.actionItems,
  'sentiment': _$SentimentTypeEnumMap[instance.sentiment]!,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

const _$SummaryTypeEnumMap = {
  SummaryType.brief: 'brief',
  SummaryType.detailed: 'detailed',
  SummaryType.bulletPoints: 'bulletPoints',
  SummaryType.actionItems: 'actionItems',
};

const _$SentimentTypeEnumMap = {
  SentimentType.positive: 'positive',
  SentimentType.negative: 'negative',
  SentimentType.neutral: 'neutral',
};

ActionItem _$ActionItemFromJson(Map<String, dynamic> json) => ActionItem(
  id: json['id'] as String,
  text: json['text'] as String,
  assignee: json['assignee'] as String?,
  dueDate: json['dueDate'] == null
      ? null
      : DateTime.parse(json['dueDate'] as String),
  priority: $enumDecode(_$ActionItemPriorityEnumMap, json['priority']),
  status: $enumDecode(_$ActionItemStatusEnumMap, json['status']),
);

Map<String, dynamic> _$ActionItemToJson(ActionItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'assignee': instance.assignee,
      'dueDate': instance.dueDate?.toIso8601String(),
      'priority': _$ActionItemPriorityEnumMap[instance.priority]!,
      'status': _$ActionItemStatusEnumMap[instance.status]!,
    };

const _$ActionItemPriorityEnumMap = {
  ActionItemPriority.low: 'low',
  ActionItemPriority.medium: 'medium',
  ActionItemPriority.high: 'high',
  ActionItemPriority.urgent: 'urgent',
};

const _$ActionItemStatusEnumMap = {
  ActionItemStatus.pending: 'pending',
  ActionItemStatus.inProgress: 'inProgress',
  ActionItemStatus.completed: 'completed',
  ActionItemStatus.cancelled: 'cancelled',
};
