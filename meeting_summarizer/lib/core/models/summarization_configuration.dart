/// Configuration models for AI summarization service
library;

import '../enums/summary_type.dart';

/// Configuration for AI summarization requests
class SummarizationConfiguration {
  /// Type of summary to generate
  final SummaryType summaryType;

  /// Length category for the summary
  final SummaryLength summaryLength;

  /// Focus area for targeted summarization
  final SummaryFocus summaryFocus;

  /// Custom word count (if using custom length)
  final int? customWordCount;

  /// Custom focus description (if using custom focus)
  final String? customFocusDescription;

  /// Whether to include timestamps in the summary
  final bool includeTimestamps;

  /// Whether to include speaker identification
  final bool includeSpeakerInfo;

  /// Whether to extract action items
  final bool extractActionItems;

  /// Whether to identify key decisions
  final bool identifyDecisions;

  /// Whether to extract topics and themes
  final bool extractTopics;

  /// Whether to include confidence scores
  final bool includeConfidenceScores;

  /// Language for the summary (ISO 639-1 code)
  final String language;

  /// Tone for the summary (formal, casual, technical)
  final String tone;

  /// Additional context or instructions for the AI
  final String? additionalContext;

  /// Custom prompt template (if using custom format)
  final String? customPrompt;

  /// AI model temperature for creativity (0.0-1.0)
  final double temperature;

  /// Maximum tokens for the AI response
  final int maxTokens;

  /// Whether to enable streaming responses
  final bool enableStreaming;

  const SummarizationConfiguration({
    required this.summaryType,
    this.summaryLength = SummaryLength.medium,
    this.summaryFocus = SummaryFocus.general,
    this.customWordCount,
    this.customFocusDescription,
    this.includeTimestamps = false,
    this.includeSpeakerInfo = false,
    this.extractActionItems = true,
    this.identifyDecisions = true,
    this.extractTopics = true,
    this.includeConfidenceScores = false,
    this.language = 'en',
    this.tone = 'professional',
    this.additionalContext,
    this.customPrompt,
    this.temperature = 0.3,
    this.maxTokens = 2000,
    this.enableStreaming = false,
  });

  /// Create a copy with modified parameters
  SummarizationConfiguration copyWith({
    SummaryType? summaryType,
    SummaryLength? summaryLength,
    SummaryFocus? summaryFocus,
    int? customWordCount,
    String? customFocusDescription,
    bool? includeTimestamps,
    bool? includeSpeakerInfo,
    bool? extractActionItems,
    bool? identifyDecisions,
    bool? extractTopics,
    bool? includeConfidenceScores,
    String? language,
    String? tone,
    String? additionalContext,
    String? customPrompt,
    double? temperature,
    int? maxTokens,
    bool? enableStreaming,
  }) {
    return SummarizationConfiguration(
      summaryType: summaryType ?? this.summaryType,
      summaryLength: summaryLength ?? this.summaryLength,
      summaryFocus: summaryFocus ?? this.summaryFocus,
      customWordCount: customWordCount ?? this.customWordCount,
      customFocusDescription:
          customFocusDescription ?? this.customFocusDescription,
      includeTimestamps: includeTimestamps ?? this.includeTimestamps,
      includeSpeakerInfo: includeSpeakerInfo ?? this.includeSpeakerInfo,
      extractActionItems: extractActionItems ?? this.extractActionItems,
      identifyDecisions: identifyDecisions ?? this.identifyDecisions,
      extractTopics: extractTopics ?? this.extractTopics,
      includeConfidenceScores:
          includeConfidenceScores ?? this.includeConfidenceScores,
      language: language ?? this.language,
      tone: tone ?? this.tone,
      additionalContext: additionalContext ?? this.additionalContext,
      customPrompt: customPrompt ?? this.customPrompt,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      enableStreaming: enableStreaming ?? this.enableStreaming,
    );
  }

  /// Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'summaryType': summaryType.value,
      'summaryLength': summaryLength.value,
      'summaryFocus': summaryFocus.value,
      'customWordCount': customWordCount,
      'customFocusDescription': customFocusDescription,
      'includeTimestamps': includeTimestamps,
      'includeSpeakerInfo': includeSpeakerInfo,
      'extractActionItems': extractActionItems,
      'identifyDecisions': identifyDecisions,
      'extractTopics': extractTopics,
      'includeConfidenceScores': includeConfidenceScores,
      'language': language,
      'tone': tone,
      'additionalContext': additionalContext,
      'customPrompt': customPrompt,
      'temperature': temperature,
      'maxTokens': maxTokens,
      'enableStreaming': enableStreaming,
    };
  }

  /// Create from JSON
  factory SummarizationConfiguration.fromJson(Map<String, dynamic> json) {
    return SummarizationConfiguration(
      summaryType: SummaryType.fromString(json['summaryType'] ?? 'brief'),
      summaryLength: SummaryLength.fromString(
        json['summaryLength'] ?? 'medium',
      ),
      summaryFocus: SummaryFocus.fromString(json['summaryFocus'] ?? 'general'),
      customWordCount: json['customWordCount'],
      customFocusDescription: json['customFocusDescription'],
      includeTimestamps: json['includeTimestamps'] ?? false,
      includeSpeakerInfo: json['includeSpeakerInfo'] ?? false,
      extractActionItems: json['extractActionItems'] ?? true,
      identifyDecisions: json['identifyDecisions'] ?? true,
      extractTopics: json['extractTopics'] ?? true,
      includeConfidenceScores: json['includeConfidenceScores'] ?? false,
      language: json['language'] ?? 'en',
      tone: json['tone'] ?? 'professional',
      additionalContext: json['additionalContext'],
      customPrompt: json['customPrompt'],
      temperature: (json['temperature'] ?? 0.3).toDouble(),
      maxTokens: json['maxTokens'] ?? 2000,
      enableStreaming: json['enableStreaming'] ?? false,
    );
  }

  /// Get effective word count based on length setting
  int get effectiveWordCount {
    if (summaryLength == SummaryLength.custom && customWordCount != null) {
      return customWordCount!;
    }
    return summaryLength.maxWords;
  }

  /// Get effective focus description
  String get effectiveFocusDescription {
    if (summaryFocus == SummaryFocus.custom && customFocusDescription != null) {
      return customFocusDescription!;
    }
    return summaryFocus.description;
  }

  /// Get tone options
  static List<String> get toneOptions => [
        'professional',
        'casual',
        'formal',
        'technical',
        'conversational',
        'academic',
      ];

  /// Get language options
  static List<String> get languageOptions => [
        'en', // English
        'es', // Spanish
        'fr', // French
        'de', // German
        'it', // Italian
        'pt', // Portuguese
        'ja', // Japanese
        'ko', // Korean
        'zh', // Chinese
      ];

  /// Create default configuration for meeting summaries
  factory SummarizationConfiguration.meetingDefault() {
    return const SummarizationConfiguration(
      summaryType: SummaryType.brief,
      summaryLength: SummaryLength.medium,
      summaryFocus: SummaryFocus.general,
      includeTimestamps: true,
      includeSpeakerInfo: true,
      extractActionItems: true,
      identifyDecisions: true,
      extractTopics: true,
      tone: 'professional',
      temperature: 0.3,
    );
  }

  /// Create default configuration for executive summaries
  factory SummarizationConfiguration.executiveDefault() {
    return const SummarizationConfiguration(
      summaryType: SummaryType.executive,
      summaryLength: SummaryLength.short,
      summaryFocus: SummaryFocus.decisions,
      includeTimestamps: false,
      includeSpeakerInfo: false,
      extractActionItems: true,
      identifyDecisions: true,
      extractTopics: false,
      tone: 'formal',
      temperature: 0.2,
    );
  }

  /// Create default configuration for action items
  factory SummarizationConfiguration.actionItemsDefault() {
    return const SummarizationConfiguration(
      summaryType: SummaryType.actionItems,
      summaryLength: SummaryLength.short,
      summaryFocus: SummaryFocus.actions,
      includeTimestamps: true,
      includeSpeakerInfo: true,
      extractActionItems: true,
      identifyDecisions: false,
      extractTopics: false,
      tone: 'professional',
      temperature: 0.1,
    );
  }

  @override
  String toString() {
    return 'SummarizationConfiguration(type: $summaryType, length: $summaryLength, focus: $summaryFocus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SummarizationConfiguration &&
        other.summaryType == summaryType &&
        other.summaryLength == summaryLength &&
        other.summaryFocus == summaryFocus &&
        other.customWordCount == customWordCount &&
        other.customFocusDescription == customFocusDescription &&
        other.includeTimestamps == includeTimestamps &&
        other.includeSpeakerInfo == includeSpeakerInfo &&
        other.extractActionItems == extractActionItems &&
        other.identifyDecisions == identifyDecisions &&
        other.extractTopics == extractTopics &&
        other.includeConfidenceScores == includeConfidenceScores &&
        other.language == language &&
        other.tone == tone &&
        other.additionalContext == additionalContext &&
        other.customPrompt == customPrompt &&
        other.temperature == temperature &&
        other.maxTokens == maxTokens &&
        other.enableStreaming == enableStreaming;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      summaryType,
      summaryLength,
      summaryFocus,
      customWordCount,
      customFocusDescription,
      includeTimestamps,
      includeSpeakerInfo,
      extractActionItems,
      identifyDecisions,
      extractTopics,
      includeConfidenceScores,
      language,
      tone,
      additionalContext,
      customPrompt,
      temperature,
      maxTokens,
      enableStreaming,
    ]);
  }
}
