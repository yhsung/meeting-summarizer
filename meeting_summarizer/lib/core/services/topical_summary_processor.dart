/// Specialized processor for topical summaries with advanced topic analysis
library;

import 'dart:async';
import 'dart:developer';

import 'package:uuid/uuid.dart';

import '../enums/summary_type.dart';
import '../models/summarization_configuration.dart';
import '../models/summarization_result.dart';
import '../exceptions/summarization_exceptions.dart';
import 'summary_type_processors.dart';
import 'topic_extraction_service.dart';

/// Processor specialized for topical summaries with advanced topic analysis
class TopicalSummaryProcessor extends SummaryTypeProcessor {
  static const Uuid _uuid = Uuid();

  @override
  bool canProcess(SummarizationConfiguration configuration) {
    return configuration.summaryType == SummaryType.topical;
  }

  @override
  int get priority => 15;

  @override
  Future<SummarizationResult> process({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
    required Future<String> Function(String prompt, String systemPrompt) aiCall,
    String? sessionId,
  }) async {
    final startTime = DateTime.now();

    try {
      // Extract topics using advanced analysis
      final topics = await TopicExtractionService.extractTopics(
        transcriptionText: transcriptionText,
        aiCall: aiCall,
        maxTopics: 12,
        relevanceThreshold: 0.4,
        contextHint: _buildContextHint(configuration),
      );

      // Generate topical summary with topic structure
      final summaryContent = await _generateTopicalSummary(
        transcriptionText,
        topics,
        configuration,
        aiCall,
      );

      // Analyze topic relationships
      final topicRelationships =
          TopicExtractionService.analyzeTopicRelationships(topics);
      final topicHierarchy = TopicExtractionService.buildTopicHierarchy(topics);

      final processingTime = DateTime.now().difference(startTime);

      return SummarizationResult(
        id: _uuid.v4(),
        content: summaryContent,
        summaryType: configuration.summaryType,
        actionItems: configuration.extractActionItems
            ? await _extractTopicActionItems(topics, transcriptionText, aiCall)
            : [],
        keyDecisions: configuration.identifyDecisions
            ? await _extractTopicDecisions(topics, transcriptionText, aiCall)
            : [],
        topics: topics,
        keyHighlights: _extractTopicalHighlights(summaryContent, topics),
        confidenceScore: _calculateTopicalConfidence(
          summaryContent,
          topics,
          transcriptionText,
        ),
        wordCount: summaryContent.split(' ').length,
        characterCount: summaryContent.length,
        processingTimeMs: processingTime.inMilliseconds,
        aiModel: 'processor-topical-v1.0',
        language: configuration.language,
        createdAt: DateTime.now(),
        sourceTranscriptionId: sessionId ?? _uuid.v4(),
        metadata: SummarizationMetadata(
          totalTokens:
              (transcriptionText.length / 4).ceil() +
              (summaryContent.length / 4).ceil(),
          promptTokens: (transcriptionText.length / 4).ceil(),
          completionTokens: (summaryContent.length / 4).ceil(),
          streamingUsed: false,
          additionalData: {
            'topic_count': topics.length,
            'topic_relationships': topicRelationships,
            'topic_hierarchy': topicHierarchy,
            'avg_topic_relevance': topics.isNotEmpty
                ? topics.map((t) => t.relevance).reduce((a, b) => a + b) /
                      topics.length
                : 0.0,
          },
        ),
      );
    } catch (e) {
      throw SummarizationExceptions.processingFailed(
        'Topical summary processing failed: $e',
      );
    }
  }

  /// Generate structured topical summary
  Future<String> _generateTopicalSummary(
    String transcriptionText,
    List<TopicExtract> topics,
    SummarizationConfiguration configuration,
    Future<String> Function(String, String) aiCall,
  ) async {
    // Create topic-organized prompt
    final topicsContext = topics
        .map((topic) => '- ${topic.topic} (${topic.keywords.join(", ")})')
        .join('\n');

    final systemPrompt =
        '''You are an expert at organizing meeting content by topics and themes. Create a structured summary that groups related discussion points under clear topic headings.''';

    final prompt =
        '''Create a topical summary of the following meeting transcription. Organize the content under these identified topic areas:

IDENTIFIED TOPICS:
$topicsContext

STRUCTURE REQUIREMENTS:
1. Group content logically under topic headings
2. Show how topics relate to each other
3. Include cross-references between related topics
4. Highlight topic transitions and connections
5. Maintain chronological flow within each topic when relevant

FORMAT: Use clear topic headings with relevant content grouped underneath. Show topic relationships and transitions.

MEETING TRANSCRIPTION:
${transcriptionText.trim()}

Create a well-organized topical summary:''';

    final response = await aiCall(prompt, systemPrompt);
    return _enhanceTopicalStructure(response, topics);
  }

  /// Enhance the topical structure with additional formatting
  String _enhanceTopicalStructure(String content, List<TopicExtract> topics) {
    final sections = <String>[];

    // Add summary header
    sections.add('# Topical Discussion Summary\n');

    // Add topic overview
    if (topics.isNotEmpty) {
      sections.add('## Topics Covered (${topics.length} topics)\n');

      final topicOverview = topics
          .map(
            (topic) =>
                '- **${topic.topic}** (${(topic.relevance * 100).round()}% relevance)',
          )
          .join('\n');

      sections.add('$topicOverview\n');
    }

    // Add the main content
    sections.add('## Discussion Details\n');
    sections.add(content);

    // Add topic relationships if available
    final relationships = TopicExtractionService.analyzeTopicRelationships(
      topics,
    );
    if (relationships.isNotEmpty) {
      sections.add('\n## Topic Relationships\n');

      for (final entry in relationships.entries) {
        final relatedTopics = entry.value.join(', ');
        sections.add('- **${entry.key}** relates to: $relatedTopics');
      }
    }

    return sections.join('\n');
  }

  /// Extract action items related to specific topics
  Future<List<ActionItem>> _extractTopicActionItems(
    List<TopicExtract> topics,
    String transcriptionText,
    Future<String> Function(String, String) aiCall,
  ) async {
    try {
      final topicNames = topics.map((t) => t.topic).join(', ');

      final prompt =
          '''Extract action items from the transcription, organizing them by topic area.

TOPIC AREAS: $topicNames

For each action item, identify:
- Which topic area it relates to
- Specific task description
- Who is responsible (if mentioned)
- Timeline or deadline (if mentioned)
- Priority based on topic relevance

TRANSCRIPTION:
$transcriptionText

Return action items organized by topic with clear assignments.''';

      const systemPrompt =
          'Extract topic-organized action items with clear categorization.';

      final response = await aiCall(prompt, systemPrompt);
      return _parseTopicActionItems(response, topics);
    } catch (e) {
      log('TopicalSummaryProcessor: Action item extraction failed: $e');
      return [];
    }
  }

  /// Extract decisions related to specific topics
  Future<List<KeyDecision>> _extractTopicDecisions(
    List<TopicExtract> topics,
    String transcriptionText,
    Future<String> Function(String, String) aiCall,
  ) async {
    try {
      final topicNames = topics.map((t) => t.topic).join(', ');

      final prompt =
          '''Extract key decisions from the transcription, organizing them by topic area.

TOPIC AREAS: $topicNames

For each decision, identify:
- Which topic area it relates to
- What was decided
- Who made the decision (if mentioned)
- Business impact or reasoning
- Implementation implications

TRANSCRIPTION:
$transcriptionText

Return decisions organized by topic with clear context.''';

      const systemPrompt =
          'Extract topic-organized decisions with clear categorization.';

      final response = await aiCall(prompt, systemPrompt);
      return _parseTopicDecisions(response, topics);
    } catch (e) {
      log('TopicalSummaryProcessor: Decision extraction failed: $e');
      return [];
    }
  }

  /// Extract highlights that represent key topical insights
  List<String> _extractTopicalHighlights(
    String content,
    List<TopicExtract> topics,
  ) {
    final highlights = <String>[];
    final lines = content.split('\n');

    // Extract topic-specific highlights
    for (final topic in topics.take(5)) {
      for (final line in lines) {
        if (line.trim().isNotEmpty &&
            (line.toLowerCase().contains(topic.topic.toLowerCase()) ||
                topic.keywords.any(
                  (keyword) =>
                      line.toLowerCase().contains(keyword.toLowerCase()),
                ))) {
          // Clean and add highlight
          final cleaned = line
              .trim()
              .replaceAll(RegExp(r'^[#*-]+\s*'), '')
              .replaceAll(RegExp(r'\*+'), '');

          if (cleaned.length > 20 && !highlights.contains(cleaned)) {
            highlights.add('${topic.topic}: $cleaned');
          }
        }
      }
    }

    return highlights.take(6).toList();
  }

  /// Calculate confidence score for topical summary
  double _calculateTopicalConfidence(
    String summary,
    List<TopicExtract> topics,
    String originalText,
  ) {
    if (summary.isEmpty || topics.isEmpty) return 0.0;

    double score = 0.7;

    // Topic coverage score
    final summaryLower = summary.toLowerCase();
    final coveredTopics = topics
        .where((topic) => summaryLower.contains(topic.topic.toLowerCase()))
        .length;

    final topicCoverage = coveredTopics / topics.length;
    score += topicCoverage * 0.2;

    // Structure quality score
    final hasStructure =
        summary.contains('##') ||
        summary.contains('#') ||
        summary.contains('**');
    if (hasStructure) score += 0.05;

    // Keyword coverage
    final allKeywords = topics.expand((t) => t.keywords).toSet();
    final coveredKeywords = allKeywords
        .where((keyword) => summaryLower.contains(keyword.toLowerCase()))
        .length;

    if (allKeywords.isNotEmpty) {
      final keywordCoverage = coveredKeywords / allKeywords.length;
      score += keywordCoverage * 0.05;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Build context hint for topic extraction
  String? _buildContextHint(SummarizationConfiguration configuration) {
    final hints = <String>[];

    if (configuration.additionalContext != null) {
      hints.add(configuration.additionalContext!);
    }

    switch (configuration.summaryFocus) {
      case SummaryFocus.technical:
        hints.add('Focus on technical topics and implementation details');
        break;
      case SummaryFocus.business:
        hints.add('Focus on business topics and strategic discussions');
        break;
      case SummaryFocus.decisions:
        hints.add('Focus on decision-making topics and alternatives');
        break;
      case SummaryFocus.actions:
        hints.add('Focus on action-oriented topics and implementation');
        break;
      default:
        break;
    }

    return hints.isNotEmpty ? hints.join('. ') : null;
  }

  /// Parse action items from topic-organized response
  List<ActionItem> _parseTopicActionItems(
    String response,
    List<TopicExtract> topics,
  ) {
    final items = <ActionItem>[];
    final sections = response.split('\n\n');

    for (final section in sections) {
      if (section.trim().isEmpty) continue;

      final lines = section.split('\n');
      String? currentTopic;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        // Check if this line identifies a topic
        final matchingTopic = topics.firstWhere(
          (topic) => trimmed.toLowerCase().contains(topic.topic.toLowerCase()),
          orElse: () => TopicExtract(topic: '', relevance: 0, keywords: []),
        );

        if (matchingTopic.topic.isNotEmpty) {
          currentTopic = matchingTopic.topic;
          continue;
        }

        // Check if this is an action item
        if (trimmed.startsWith('-') ||
            trimmed.startsWith('•') ||
            trimmed.toLowerCase().contains('action')) {
          final description = trimmed.replaceAll(RegExp(r'^[-•]\s*'), '');

          items.add(
            ActionItem(
              id: _uuid.v4(),
              description: description,
              context: currentTopic != null ? 'Topic: $currentTopic' : null,
              priority: 'medium',
              confidence: 0.8,
            ),
          );
        }
      }
    }

    return items.take(10).toList();
  }

  /// Parse decisions from topic-organized response
  List<KeyDecision> _parseTopicDecisions(
    String response,
    List<TopicExtract> topics,
  ) {
    final decisions = <KeyDecision>[];
    final sections = response.split('\n\n');

    for (final section in sections) {
      if (section.trim().isEmpty) continue;

      final lines = section.split('\n');
      String? currentTopic;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        // Check if this line identifies a topic
        final matchingTopic = topics.firstWhere(
          (topic) => trimmed.toLowerCase().contains(topic.topic.toLowerCase()),
          orElse: () => TopicExtract(topic: '', relevance: 0, keywords: []),
        );

        if (matchingTopic.topic.isNotEmpty) {
          currentTopic = matchingTopic.topic;
          continue;
        }

        // Check if this is a decision
        if (trimmed.startsWith('-') ||
            trimmed.startsWith('•') ||
            trimmed.toLowerCase().contains('decision') ||
            trimmed.toLowerCase().contains('decided')) {
          final description = trimmed.replaceAll(RegExp(r'^[-•]\s*'), '');

          decisions.add(
            KeyDecision(
              id: _uuid.v4(),
              description: description,
              impact: currentTopic != null ? 'Relates to: $currentTopic' : null,
              confidence: 0.8,
            ),
          );
        }
      }
    }

    return decisions.take(8).toList();
  }
}
