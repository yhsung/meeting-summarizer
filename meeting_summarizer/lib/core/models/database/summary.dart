import 'package:json_annotation/json_annotation.dart';

part 'summary.g.dart';

@JsonSerializable()
class Summary {
  final String id;
  final String transcriptionId;
  final String content;
  final SummaryType type;
  final String provider; // AI service provider
  final String? model; // AI model used for generation
  final String? prompt; // Prompt used for generation
  final double confidence;
  final int wordCount;
  final int characterCount;
  final List<String>? keyPoints; // Key points extracted
  final List<ActionItem>? actionItems; // Action items identified
  final SentimentType sentiment;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Summary({
    required this.id,
    required this.transcriptionId,
    required this.content,
    required this.type,
    required this.provider,
    this.model,
    this.prompt,
    required this.confidence,
    required this.wordCount,
    required this.characterCount,
    this.keyPoints,
    this.actionItems,
    required this.sentiment,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a Summary from JSON
  factory Summary.fromJson(Map<String, dynamic> json) =>
      _$SummaryFromJson(json);

  /// Convert Summary to JSON
  Map<String, dynamic> toJson() => _$SummaryToJson(this);

  /// Create a Summary from database row
  factory Summary.fromDatabase(Map<String, dynamic> row) {
    return Summary(
      id: row['id'] as String,
      transcriptionId: row['transcription_id'] as String,
      content: row['content'] as String,
      type: SummaryType.fromString(row['type'] as String),
      provider: row['provider'] as String,
      model: row['model'] as String?,
      prompt: row['prompt'] as String?,
      confidence: (row['confidence'] as num).toDouble(),
      wordCount: row['word_count'] as int,
      characterCount: row['character_count'] as int,
      keyPoints: row['key_points'] != null
          ? _parseKeyPoints(row['key_points'] as String)
          : null,
      actionItems: row['action_items'] != null
          ? _parseActionItems(row['action_items'] as String)
          : null,
      sentiment: SentimentType.fromString(row['sentiment'] as String),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  /// Convert Summary to database row
  Map<String, dynamic> toDatabase() {
    return {
      'id': id,
      'transcription_id': transcriptionId,
      'content': content,
      'type': type.value,
      'provider': provider,
      'model': model,
      'prompt': prompt,
      'confidence': confidence,
      'word_count': wordCount,
      'character_count': characterCount,
      'key_points': keyPoints != null ? _encodeKeyPoints(keyPoints!) : null,
      'action_items': actionItems != null
          ? _encodeActionItems(actionItems!)
          : null,
      'sentiment': sentiment.value,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Create a copy with updated fields
  Summary copyWith({
    String? id,
    String? transcriptionId,
    String? content,
    SummaryType? type,
    String? provider,
    String? model,
    String? prompt,
    double? confidence,
    int? wordCount,
    int? characterCount,
    List<String>? keyPoints,
    List<ActionItem>? actionItems,
    SentimentType? sentiment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Summary(
      id: id ?? this.id,
      transcriptionId: transcriptionId ?? this.transcriptionId,
      content: content ?? this.content,
      type: type ?? this.type,
      provider: provider ?? this.provider,
      model: model ?? this.model,
      prompt: prompt ?? this.prompt,
      confidence: confidence ?? this.confidence,
      wordCount: wordCount ?? this.wordCount,
      characterCount: characterCount ?? this.characterCount,
      keyPoints: keyPoints ?? this.keyPoints,
      actionItems: actionItems ?? this.actionItems,
      sentiment: sentiment ?? this.sentiment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get formatted confidence percentage
  String get formattedConfidence => '${(confidence * 100).toStringAsFixed(1)}%';

  /// Get summary length category
  String get lengthCategory {
    if (wordCount < 50) return 'Brief';
    if (wordCount < 200) return 'Medium';
    return 'Detailed';
  }

  /// Get reading time estimate in minutes
  int get estimatedReadingTime {
    // Average reading speed: 200 words per minute
    return (wordCount / 200).ceil();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Summary && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Summary(id: $id, type: ${type.value}, wordCount: $wordCount)';

  // Helper methods for key points and action items encoding/decoding
  static List<String>? _parseKeyPoints(String keyPointsJson) {
    try {
      // Simplified parsing - in production you'd use dart:convert
      return [];
    } catch (e) {
      return null;
    }
  }

  static List<ActionItem>? _parseActionItems(String actionItemsJson) {
    try {
      // Simplified parsing - in production you'd use dart:convert
      return [];
    } catch (e) {
      return null;
    }
  }

  static String _encodeKeyPoints(List<String> keyPoints) {
    // Simplified encoding - in production you'd use dart:convert
    return '[]';
  }

  static String _encodeActionItems(List<ActionItem> actionItems) {
    // Simplified encoding - in production you'd use dart:convert
    return '[]';
  }
}

@JsonSerializable()
class ActionItem {
  final String id;
  final String text;
  final String? assignee;
  final DateTime? dueDate;
  final ActionItemPriority priority;
  final ActionItemStatus status;

  const ActionItem({
    required this.id,
    required this.text,
    this.assignee,
    this.dueDate,
    required this.priority,
    required this.status,
  });

  /// Create an ActionItem from JSON
  factory ActionItem.fromJson(Map<String, dynamic> json) =>
      _$ActionItemFromJson(json);

  /// Convert ActionItem to JSON
  Map<String, dynamic> toJson() => _$ActionItemToJson(this);

  /// Create a copy with updated fields
  ActionItem copyWith({
    String? id,
    String? text,
    String? assignee,
    DateTime? dueDate,
    ActionItemPriority? priority,
    ActionItemStatus? status,
  }) {
    return ActionItem(
      id: id ?? this.id,
      text: text ?? this.text,
      assignee: assignee ?? this.assignee,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
    );
  }

  /// Check if action item is overdue
  bool get isOverdue {
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!) &&
        status != ActionItemStatus.completed;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActionItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ActionItem(id: $id, text: $text, status: ${status.value})';
}

enum SummaryType {
  brief('brief'),
  detailed('detailed'),
  bulletPoints('bullet_points'),
  actionItems('action_items');

  const SummaryType(this.value);

  final String value;

  static SummaryType fromString(String value) {
    return SummaryType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => SummaryType.brief,
    );
  }

  String get displayName {
    switch (this) {
      case SummaryType.brief:
        return 'Brief Summary';
      case SummaryType.detailed:
        return 'Detailed Summary';
      case SummaryType.bulletPoints:
        return 'Bullet Points';
      case SummaryType.actionItems:
        return 'Action Items';
    }
  }

  @override
  String toString() => value;
}

enum SentimentType {
  positive('positive'),
  negative('negative'),
  neutral('neutral');

  const SentimentType(this.value);

  final String value;

  static SentimentType fromString(String value) {
    return SentimentType.values.firstWhere(
      (sentiment) => sentiment.value == value,
      orElse: () => SentimentType.neutral,
    );
  }

  @override
  String toString() => value;
}

enum ActionItemPriority {
  low('low'),
  medium('medium'),
  high('high'),
  urgent('urgent');

  const ActionItemPriority(this.value);

  final String value;

  static ActionItemPriority fromString(String value) {
    return ActionItemPriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => ActionItemPriority.medium,
    );
  }

  @override
  String toString() => value;
}

enum ActionItemStatus {
  pending('pending'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  const ActionItemStatus(this.value);

  final String value;

  static ActionItemStatus fromString(String value) {
    return ActionItemStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ActionItemStatus.pending,
    );
  }

  @override
  String toString() => value;
}
