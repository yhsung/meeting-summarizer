/// Result models for AI summarization responses
library;

import '../enums/summary_type.dart';

/// Result of an AI summarization request
class SummarizationResult {
  /// Unique identifier for this summarization
  final String id;

  /// The generated summary content
  final String content;

  /// Type of summary that was generated
  final SummaryType summaryType;

  /// Extracted action items (if requested)
  final List<ActionItem> actionItems;

  /// Identified key decisions (if requested)
  final List<KeyDecision> keyDecisions;

  /// Extracted topics and themes (if requested)
  final List<TopicExtract> topics;

  /// Key highlights from the content
  final List<String> keyHighlights;

  /// Confidence score for the summary quality (0.0-1.0)
  final double confidenceScore;

  /// Word count of the generated summary
  final int wordCount;

  /// Character count of the generated summary
  final int characterCount;

  /// Processing time in milliseconds
  final int processingTimeMs;

  /// AI model used for generation
  final String aiModel;

  /// Language of the summary
  final String language;

  /// Timestamp when the summary was generated
  final DateTime createdAt;

  /// Source transcription ID this summary was generated from
  final String sourceTranscriptionId;

  /// Metadata about the summarization process
  final SummarizationMetadata metadata;

  const SummarizationResult({
    required this.id,
    required this.content,
    required this.summaryType,
    required this.actionItems,
    required this.keyDecisions,
    required this.topics,
    required this.keyHighlights,
    required this.confidenceScore,
    required this.wordCount,
    required this.characterCount,
    required this.processingTimeMs,
    required this.aiModel,
    required this.language,
    required this.createdAt,
    required this.sourceTranscriptionId,
    required this.metadata,
  });

  /// Create from JSON response
  factory SummarizationResult.fromJson(Map<String, dynamic> json) {
    return SummarizationResult(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      summaryType: SummaryType.fromString(json['summaryType'] ?? 'brief'),
      actionItems: (json['actionItems'] as List<dynamic>? ?? [])
          .map((item) => ActionItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      keyDecisions: (json['keyDecisions'] as List<dynamic>? ?? [])
          .map(
            (decision) =>
                KeyDecision.fromJson(decision as Map<String, dynamic>),
          )
          .toList(),
      topics: (json['topics'] as List<dynamic>? ?? [])
          .map((topic) => TopicExtract.fromJson(topic as Map<String, dynamic>))
          .toList(),
      keyHighlights: (json['keyHighlights'] as List<dynamic>? ?? [])
          .map((highlight) => highlight.toString())
          .toList(),
      confidenceScore: (json['confidenceScore'] ?? 0.0).toDouble(),
      wordCount: json['wordCount'] ?? 0,
      characterCount: json['characterCount'] ?? 0,
      processingTimeMs: json['processingTimeMs'] ?? 0,
      aiModel: json['aiModel'] ?? '',
      language: json['language'] ?? 'en',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      sourceTranscriptionId: json['sourceTranscriptionId'] ?? '',
      metadata: SummarizationMetadata.fromJson(
        json['metadata'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'summaryType': summaryType.value,
      'actionItems': actionItems.map((item) => item.toJson()).toList(),
      'keyDecisions':
          keyDecisions.map((decision) => decision.toJson()).toList(),
      'topics': topics.map((topic) => topic.toJson()).toList(),
      'keyHighlights': keyHighlights,
      'confidenceScore': confidenceScore,
      'wordCount': wordCount,
      'characterCount': characterCount,
      'processingTimeMs': processingTimeMs,
      'aiModel': aiModel,
      'language': language,
      'createdAt': createdAt.toIso8601String(),
      'sourceTranscriptionId': sourceTranscriptionId,
      'metadata': metadata.toJson(),
    };
  }

  /// Get quality rating based on confidence score
  String get qualityRating {
    if (confidenceScore >= 0.9) return 'Excellent';
    if (confidenceScore >= 0.8) return 'Good';
    if (confidenceScore >= 0.7) return 'Fair';
    if (confidenceScore >= 0.6) return 'Acceptable';
    return 'Poor';
  }

  /// Get reading time estimate in minutes
  int get estimatedReadingTimeMinutes {
    // Average reading speed: 200-250 words per minute
    return (wordCount / 225).ceil();
  }

  /// Check if summary has action items
  bool get hasActionItems => actionItems.isNotEmpty;

  /// Check if summary has key decisions
  bool get hasKeyDecisions => keyDecisions.isNotEmpty;

  /// Check if summary has topics
  bool get hasTopics => topics.isNotEmpty;

  /// Get all action items that are assigned to someone
  List<ActionItem> get assignedActionItems {
    return actionItems.where((item) => item.assignee != null).toList();
  }

  /// Get all action items with due dates
  List<ActionItem> get timeConstrainedActionItems {
    return actionItems.where((item) => item.dueDate != null).toList();
  }

  @override
  String toString() {
    return 'SummarizationResult(id: $id, type: $summaryType, words: $wordCount, confidence: $confidenceScore)';
  }
}

/// Extracted action item from the summarization
class ActionItem {
  /// Unique identifier for the action item
  final String id;

  /// Description of the task or action
  final String description;

  /// Person assigned to this action (if mentioned)
  final String? assignee;

  /// Due date for the action (if mentioned)
  final DateTime? dueDate;

  /// Priority level (high, medium, low)
  final String priority;

  /// Context or additional details
  final String? context;

  /// Timestamp when this action was mentioned
  final Duration? timestamp;

  /// Confidence score for this extraction (0.0-1.0)
  final double confidence;

  const ActionItem({
    required this.id,
    required this.description,
    this.assignee,
    this.dueDate,
    this.priority = 'medium',
    this.context,
    this.timestamp,
    this.confidence = 1.0,
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      id: json['id'] ?? '',
      description: json['description'] ?? '',
      assignee: json['assignee'],
      dueDate:
          json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : null,
      priority: json['priority'] ?? 'medium',
      context: json['context'],
      timestamp: json['timestamp'] != null
          ? Duration(milliseconds: json['timestamp'])
          : null,
      confidence: (json['confidence'] ?? 1.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'assignee': assignee,
      'dueDate': dueDate?.toIso8601String(),
      'priority': priority,
      'context': context,
      'timestamp': timestamp?.inMilliseconds,
      'confidence': confidence,
    };
  }

  @override
  String toString() => 'ActionItem: $description';
}

/// Identified key decision from the summarization
class KeyDecision {
  /// Unique identifier for the decision
  final String id;

  /// Description of the decision made
  final String description;

  /// Who made the decision (if mentioned)
  final String? decisionMaker;

  /// Impact or consequences of the decision
  final String? impact;

  /// Context surrounding the decision
  final String? context;

  /// Timestamp when this decision was made
  final Duration? timestamp;

  /// Confidence score for this extraction (0.0-1.0)
  final double confidence;

  const KeyDecision({
    required this.id,
    required this.description,
    this.decisionMaker,
    this.impact,
    this.context,
    this.timestamp,
    this.confidence = 1.0,
  });

  factory KeyDecision.fromJson(Map<String, dynamic> json) {
    return KeyDecision(
      id: json['id'] ?? '',
      description: json['description'] ?? '',
      decisionMaker: json['decisionMaker'],
      impact: json['impact'],
      context: json['context'],
      timestamp: json['timestamp'] != null
          ? Duration(milliseconds: json['timestamp'])
          : null,
      confidence: (json['confidence'] ?? 1.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'decisionMaker': decisionMaker,
      'impact': impact,
      'context': context,
      'timestamp': timestamp?.inMilliseconds,
      'confidence': confidence,
    };
  }

  @override
  String toString() => 'Decision: $description';
}

/// Extracted topic or theme from the content
class TopicExtract {
  /// Name of the topic or theme
  final String topic;

  /// Relevance score (0.0-1.0)
  final double relevance;

  /// Keywords associated with this topic
  final List<String> keywords;

  /// Brief description of the topic
  final String? description;

  /// Time spent discussing this topic
  final Duration? discussionDuration;

  const TopicExtract({
    required this.topic,
    required this.relevance,
    required this.keywords,
    this.description,
    this.discussionDuration,
  });

  factory TopicExtract.fromJson(Map<String, dynamic> json) {
    return TopicExtract(
      topic: json['topic'] ?? '',
      relevance: (json['relevance'] ?? 0.0).toDouble(),
      keywords: (json['keywords'] as List<dynamic>? ?? [])
          .map((keyword) => keyword.toString())
          .toList(),
      description: json['description'],
      discussionDuration: json['discussionDuration'] != null
          ? Duration(milliseconds: json['discussionDuration'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'topic': topic,
      'relevance': relevance,
      'keywords': keywords,
      'description': description,
      'discussionDuration': discussionDuration?.inMilliseconds,
    };
  }

  @override
  String toString() =>
      'Topic: $topic (${(relevance * 100).toStringAsFixed(1)}%)';
}

/// Metadata about the summarization process
class SummarizationMetadata {
  /// Total tokens used in the request
  final int totalTokens;

  /// Prompt tokens used
  final int promptTokens;

  /// Completion tokens generated
  final int completionTokens;

  /// Cost of the API request (if available)
  final double? cost;

  /// Currency for the cost
  final String? costCurrency;

  /// Model version used
  final String? modelVersion;

  /// Temperature setting used
  final double? temperature;

  /// Max tokens setting used
  final int? maxTokens;

  /// Whether streaming was used
  final bool streamingUsed;

  /// Additional provider-specific metadata
  final Map<String, dynamic> additionalData;

  const SummarizationMetadata({
    required this.totalTokens,
    required this.promptTokens,
    required this.completionTokens,
    this.cost,
    this.costCurrency,
    this.modelVersion,
    this.temperature,
    this.maxTokens,
    this.streamingUsed = false,
    this.additionalData = const {},
  });

  factory SummarizationMetadata.fromJson(Map<String, dynamic> json) {
    return SummarizationMetadata(
      totalTokens: json['totalTokens'] ?? 0,
      promptTokens: json['promptTokens'] ?? 0,
      completionTokens: json['completionTokens'] ?? 0,
      cost: json['cost']?.toDouble(),
      costCurrency: json['costCurrency'],
      modelVersion: json['modelVersion'],
      temperature: json['temperature']?.toDouble(),
      maxTokens: json['maxTokens'],
      streamingUsed: json['streamingUsed'] ?? false,
      additionalData: Map<String, dynamic>.from(json['additionalData'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalTokens': totalTokens,
      'promptTokens': promptTokens,
      'completionTokens': completionTokens,
      'cost': cost,
      'costCurrency': costCurrency,
      'modelVersion': modelVersion,
      'temperature': temperature,
      'maxTokens': maxTokens,
      'streamingUsed': streamingUsed,
      'additionalData': additionalData,
    };
  }

  /// Get cost formatted as currency string
  String? get formattedCost {
    if (cost == null) return null;
    final currency = costCurrency ?? 'USD';
    return '${cost!.toStringAsFixed(4)} $currency';
  }

  @override
  String toString() {
    return 'SummarizationMetadata(tokens: $totalTokens, cost: ${formattedCost ?? "N/A"})';
  }
}
