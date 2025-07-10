/// Specialized processors for different summary types
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../enums/summary_type.dart';
import '../models/summarization_configuration.dart';
import '../models/summarization_result.dart';
import '../exceptions/summarization_exceptions.dart';
import 'prompt_template_service.dart';

/// Abstract base processor for summary types
abstract class SummaryTypeProcessor {
  /// Process a summarization request for this specific type
  Future<SummarizationResult> process({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
    required Future<String> Function(String prompt, String systemPrompt) aiCall,
    String? sessionId,
  });

  /// Validate that this processor can handle the configuration
  bool canProcess(SummarizationConfiguration configuration);

  /// Get processing priority (higher = more specialized)
  int get priority => 0;
}

/// Processor for brief summaries
class BriefSummaryProcessor extends SummaryTypeProcessor {
  static const Uuid _uuid = Uuid();

  @override
  bool canProcess(SummarizationConfiguration configuration) {
    return configuration.summaryType == SummaryType.brief;
  }

  @override
  int get priority => 10;

  @override
  Future<SummarizationResult> process({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
    required Future<String> Function(String prompt, String systemPrompt) aiCall,
    String? sessionId,
  }) async {
    final startTime = DateTime.now();

    // Generate optimized prompt for brief summaries
    final systemPrompt = PromptTemplateService.generateSystemPrompt(
      configuration,
    );
    final prompt = PromptTemplateService.generatePrompt(
      transcriptionText: transcriptionText,
      configuration: configuration,
    );

    try {
      final summaryContent = await aiCall(prompt, systemPrompt);

      // Post-process for brief summaries
      final processedContent = _postProcessBriefSummary(
        summaryContent,
        configuration,
      );

      final processingTime = DateTime.now().difference(startTime);

      return SummarizationResult(
        id: _uuid.v4(),
        content: processedContent,
        summaryType: configuration.summaryType,
        actionItems: configuration.extractActionItems
            ? await _extractSimpleActionItems(transcriptionText, aiCall)
            : [],
        keyDecisions: configuration.identifyDecisions
            ? await _extractKeyDecisions(transcriptionText, aiCall)
            : [],
        topics: configuration.extractTopics
            ? await _extractTopics(transcriptionText, aiCall)
            : [],
        keyHighlights: _extractHighlights(processedContent),
        confidenceScore: _calculateConfidenceScore(
          processedContent,
          transcriptionText,
        ),
        wordCount: processedContent.split(' ').length,
        characterCount: processedContent.length,
        processingTimeMs: processingTime.inMilliseconds,
        aiModel: 'processor-brief-v1.0',
        language: configuration.language,
        createdAt: DateTime.now(),
        sourceTranscriptionId: sessionId ?? _uuid.v4(),
        metadata: SummarizationMetadata(
          totalTokens:
              (transcriptionText.length / 4).ceil() +
              (processedContent.length / 4).ceil(),
          promptTokens: (transcriptionText.length / 4).ceil(),
          completionTokens: (processedContent.length / 4).ceil(),
          streamingUsed: false,
        ),
      );
    } catch (e) {
      throw SummarizationExceptions.processingFailed(
        'Brief summary processing failed: $e',
      );
    }
  }

  String _postProcessBriefSummary(
    String content,
    SummarizationConfiguration config,
  ) {
    // Ensure brief summaries are concise and well-structured
    final sentences = content
        .split('. ')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    // Limit to key sentences for brief format
    final maxSentences = config.summaryLength == SummaryLength.short ? 3 : 5;
    final keyContent = sentences.take(maxSentences).join('. ');

    return keyContent.endsWith('.') ? keyContent : '$keyContent.';
  }

  Future<List<ActionItem>> _extractSimpleActionItems(
    String text,
    Future<String> Function(String, String) aiCall,
  ) async {
    // Simplified action item extraction for brief summaries
    try {
      final prompt = PromptTemplateService.generateActionItemPrompt(text);
      final response = await aiCall(prompt, 'Extract action items concisely.');

      // Parse response and create action items
      return _parseActionItems(response);
    } catch (e) {
      debugPrint('BriefSummaryProcessor: Action item extraction failed: $e');
      return [];
    }
  }

  Future<List<KeyDecision>> _extractKeyDecisions(
    String text,
    Future<String> Function(String, String) aiCall,
  ) async {
    try {
      final prompt = PromptTemplateService.generateDecisionPrompt(text);
      final response = await aiCall(prompt, 'Extract key decisions clearly.');

      return _parseKeyDecisions(response);
    } catch (e) {
      debugPrint('BriefSummaryProcessor: Decision extraction failed: $e');
      return [];
    }
  }

  Future<List<TopicExtract>> _extractTopics(
    String text,
    Future<String> Function(String, String) aiCall,
  ) async {
    try {
      final prompt = PromptTemplateService.generateTopicPrompt(
        text,
        maxTopics: 5,
      );
      final response = await aiCall(prompt, 'Extract main topics.');

      return _parseTopics(response);
    } catch (e) {
      debugPrint('BriefSummaryProcessor: Topic extraction failed: $e');
      return [];
    }
  }

  List<String> _extractHighlights(String content) {
    // Extract key phrases and important statements
    final sentences = content.split('. ');
    return sentences
        .where((s) => s.trim().isNotEmpty && s.length > 20)
        .take(3)
        .map((s) => s.trim())
        .toList();
  }

  double _calculateConfidenceScore(String summary, String originalText) {
    // Calculate confidence based on content quality
    if (summary.isEmpty || originalText.isEmpty) return 0.0;

    final summaryLength = summary.split(' ').length;
    final originalLength = originalText.split(' ').length;

    // Higher confidence for appropriate compression ratio
    final compressionRatio = summaryLength / originalLength;

    if (compressionRatio > 0.1 && compressionRatio < 0.3) {
      return 0.85;
    } else if (compressionRatio < 0.5) {
      return 0.75;
    } else {
      return 0.65;
    }
  }

  List<ActionItem> _parseActionItems(String response) {
    // Simple parsing for action items from AI response
    final items = <ActionItem>[];
    final lines = response.split('\n');

    for (final line in lines) {
      if (line.trim().isNotEmpty &&
          (line.contains('TODO') ||
              line.contains('Action') ||
              line.contains('-'))) {
        items.add(
          ActionItem(
            id: _uuid.v4(),
            description: line.trim().replaceAll(RegExp(r'^[-•]\s*'), ''),
            priority: 'medium',
            confidence: 0.8,
          ),
        );
      }
    }

    return items.take(5).toList();
  }

  List<KeyDecision> _parseKeyDecisions(String response) {
    final decisions = <KeyDecision>[];
    final lines = response.split('\n');

    for (final line in lines) {
      if (line.trim().isNotEmpty &&
          (line.contains('Decided') ||
              line.contains('Decision') ||
              line.contains('-'))) {
        decisions.add(
          KeyDecision(
            id: _uuid.v4(),
            description: line.trim().replaceAll(RegExp(r'^[-•]\s*'), ''),
            confidence: 0.8,
          ),
        );
      }
    }

    return decisions.take(3).toList();
  }

  List<TopicExtract> _parseTopics(String response) {
    final topics = <TopicExtract>[];
    final lines = response.split('\n');

    for (final line in lines) {
      if (line.trim().isNotEmpty && line.contains('-')) {
        final topicName = line.trim().replaceAll(RegExp(r'^[-•]\s*'), '');
        topics.add(
          TopicExtract(
            topic: topicName,
            relevance: 0.8,
            keywords: topicName.split(' ').take(3).toList(),
          ),
        );
      }
    }

    return topics.take(5).toList();
  }
}

/// Processor for detailed summaries
class DetailedSummaryProcessor extends SummaryTypeProcessor {
  static const Uuid _uuid = Uuid();

  @override
  bool canProcess(SummarizationConfiguration configuration) {
    return configuration.summaryType == SummaryType.detailed;
  }

  @override
  int get priority => 10;

  @override
  Future<SummarizationResult> process({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
    required Future<String> Function(String prompt, String systemPrompt) aiCall,
    String? sessionId,
  }) async {
    final startTime = DateTime.now();

    // Generate comprehensive prompt for detailed analysis
    final systemPrompt = PromptTemplateService.generateSystemPrompt(
      configuration,
    );
    final prompt = PromptTemplateService.generatePrompt(
      transcriptionText: transcriptionText,
      configuration: configuration,
    );

    try {
      final summaryContent = await aiCall(prompt, systemPrompt);

      // Enhanced processing for detailed summaries
      final processedContent = _postProcessDetailedSummary(
        summaryContent,
        configuration,
      );

      final processingTime = DateTime.now().difference(startTime);

      return SummarizationResult(
        id: _uuid.v4(),
        content: processedContent,
        summaryType: configuration.summaryType,
        actionItems: configuration.extractActionItems
            ? await _extractDetailedActionItems(transcriptionText, aiCall)
            : [],
        keyDecisions: configuration.identifyDecisions
            ? await _extractDetailedDecisions(transcriptionText, aiCall)
            : [],
        topics: configuration.extractTopics
            ? await _extractDetailedTopics(transcriptionText, aiCall)
            : [],
        keyHighlights: _extractDetailedHighlights(processedContent),
        confidenceScore: _calculateDetailedConfidenceScore(
          processedContent,
          transcriptionText,
        ),
        wordCount: processedContent.split(' ').length,
        characterCount: processedContent.length,
        processingTimeMs: processingTime.inMilliseconds,
        aiModel: 'processor-detailed-v1.0',
        language: configuration.language,
        createdAt: DateTime.now(),
        sourceTranscriptionId: sessionId ?? _uuid.v4(),
        metadata: SummarizationMetadata(
          totalTokens:
              (transcriptionText.length / 4).ceil() +
              (processedContent.length / 4).ceil(),
          promptTokens: (transcriptionText.length / 4).ceil(),
          completionTokens: (processedContent.length / 4).ceil(),
          streamingUsed: false,
        ),
      );
    } catch (e) {
      throw SummarizationExceptions.processingFailed(
        'Detailed summary processing failed: $e',
      );
    }
  }

  String _postProcessDetailedSummary(
    String content,
    SummarizationConfiguration config,
  ) {
    // Structure detailed summaries with sections
    if (!content.contains('\n\n')) {
      // Add structure if not present
      final sentences = content.split('. ');
      final sections = <String>[];

      if (sentences.length > 3) {
        sections.add('Overview:\n${sentences.take(2).join('. ')}.');

        if (sentences.length > 5) {
          sections.add(
            '\nKey Discussion Points:\n${sentences.skip(2).take(3).join('. ')}.',
          );
        }

        if (sentences.length > 6) {
          sections.add(
            '\nConclusions and Next Steps:\n${sentences.skip(5).join('. ')}.',
          );
        }
      }

      return sections.isNotEmpty ? sections.join('\n') : content;
    }

    return content;
  }

  Future<List<ActionItem>> _extractDetailedActionItems(
    String text,
    Future<String> Function(String, String) aiCall,
  ) async {
    try {
      final prompt = '''${PromptTemplateService.generateActionItemPrompt(text)}

Provide detailed action items with:
- Specific descriptions
- Clear assignments
- Realistic deadlines
- Priority levels
- Dependencies''';

      final response = await aiCall(
        prompt,
        'Extract comprehensive action items.',
      );
      return _parseDetailedActionItems(response);
    } catch (e) {
      debugPrint('DetailedSummaryProcessor: Action item extraction failed: $e');
      return [];
    }
  }

  Future<List<KeyDecision>> _extractDetailedDecisions(
    String text,
    Future<String> Function(String, String) aiCall,
  ) async {
    try {
      final prompt = '''${PromptTemplateService.generateDecisionPrompt(text)}

Include context, rationale, and implications for each decision.''';

      final response = await aiCall(
        prompt,
        'Extract decisions with full context.',
      );
      return _parseDetailedDecisions(response);
    } catch (e) {
      debugPrint('DetailedSummaryProcessor: Decision extraction failed: $e');
      return [];
    }
  }

  Future<List<TopicExtract>> _extractDetailedTopics(
    String text,
    Future<String> Function(String, String) aiCall,
  ) async {
    try {
      final prompt = PromptTemplateService.generateTopicPrompt(
        text,
        maxTopics: 10,
      );
      final response = await aiCall(
        prompt,
        'Extract comprehensive topics with context.',
      );

      return _parseDetailedTopics(response);
    } catch (e) {
      debugPrint('DetailedSummaryProcessor: Topic extraction failed: $e');
      return [];
    }
  }

  List<String> _extractDetailedHighlights(String content) {
    // Extract key insights and important statements
    final sections = content.split('\n\n');
    final highlights = <String>[];

    for (final section in sections) {
      if (section.trim().isNotEmpty) {
        final sentences = section.split('. ');
        final keyStatement = sentences.firstWhere(
          (s) =>
              s.length > 30 &&
              (s.contains('important') ||
                  s.contains('significant') ||
                  s.contains('key') ||
                  s.contains('decided')),
          orElse: () => sentences.isNotEmpty ? sentences.first : '',
        );

        if (keyStatement.isNotEmpty) {
          highlights.add(keyStatement.trim());
        }
      }
    }

    return highlights.take(6).toList();
  }

  double _calculateDetailedConfidenceScore(
    String summary,
    String originalText,
  ) {
    if (summary.isEmpty || originalText.isEmpty) return 0.0;

    final summaryWords = summary.split(' ').length;
    final originalWords = originalText.split(' ').length;
    final hasStructure = summary.contains('\n\n') || summary.contains(':');

    // Higher confidence for well-structured detailed summaries
    double score = 0.7;

    if (hasStructure) score += 0.1;
    if (summaryWords > 200) score += 0.1;
    if (summaryWords / originalWords > 0.2) score += 0.1;

    return score.clamp(0.0, 1.0);
  }

  List<ActionItem> _parseDetailedActionItems(String response) {
    final items = <ActionItem>[];
    final lines = response.split('\n');

    String? currentItem;
    String? assignee;
    String? dueDate;
    String priority = 'medium';

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('-') || trimmed.startsWith('•')) {
        // Save previous item
        if (currentItem != null) {
          items.add(
            ActionItem(
              id: _uuid.v4(),
              description: currentItem,
              assignee: assignee,
              dueDate: dueDate != null ? DateTime.tryParse(dueDate) : null,
              priority: priority,
              confidence: 0.85,
            ),
          );
        }

        // Start new item
        currentItem = trimmed.replaceAll(RegExp(r'^[-•]\s*'), '');
        assignee = null;
        dueDate = null;
        priority = 'medium';
      } else if (currentItem != null) {
        // Additional details for current item
        if (trimmed.toLowerCase().contains('assigned') ||
            trimmed.toLowerCase().contains('owner')) {
          assignee = _extractAssignee(trimmed);
        }
        if (trimmed.toLowerCase().contains('due') ||
            trimmed.toLowerCase().contains('deadline')) {
          dueDate = _extractDueDate(trimmed);
        }
        if (trimmed.toLowerCase().contains('priority')) {
          priority = _extractPriority(trimmed);
        }
      }
    }

    // Save last item
    if (currentItem != null) {
      items.add(
        ActionItem(
          id: _uuid.v4(),
          description: currentItem,
          assignee: assignee,
          dueDate: dueDate != null ? DateTime.tryParse(dueDate) : null,
          priority: priority,
          confidence: 0.85,
        ),
      );
    }

    return items;
  }

  List<KeyDecision> _parseDetailedDecisions(String response) {
    final decisions = <KeyDecision>[];
    final sections = response.split('\n\n');

    for (final section in sections) {
      if (section.trim().isNotEmpty &&
          (section.toLowerCase().contains('decision') ||
              section.toLowerCase().contains('decided'))) {
        final lines = section.split('\n');
        final description = lines.first.trim();

        String? decisionMaker;
        String? impact;

        for (final line in lines.skip(1)) {
          if (line.toLowerCase().contains('by') ||
              line.toLowerCase().contains('made')) {
            decisionMaker = _extractDecisionMaker(line);
          }
          if (line.toLowerCase().contains('impact') ||
              line.toLowerCase().contains('result')) {
            impact = line.trim();
          }
        }

        decisions.add(
          KeyDecision(
            id: _uuid.v4(),
            description: description,
            decisionMaker: decisionMaker,
            impact: impact,
            confidence: 0.85,
          ),
        );
      }
    }

    return decisions;
  }

  List<TopicExtract> _parseDetailedTopics(String response) {
    final topics = <TopicExtract>[];
    final sections = response.split('\n');

    for (final section in sections) {
      if (section.trim().isNotEmpty && section.contains('-')) {
        final parts = section.split('-');
        if (parts.length >= 2) {
          final topic = parts[1].trim();
          final keywords = topic.split(' ').take(5).toList();

          topics.add(
            TopicExtract(
              topic: topic,
              relevance: 0.8,
              keywords: keywords,
              description: section.length > 50
                  ? '${section.substring(0, 50)}...'
                  : section,
            ),
          );
        }
      }
    }

    return topics.take(8).toList();
  }

  String? _extractAssignee(String text) {
    final patterns = [
      RegExp(r'assigned to ([^,\n\.]+)', caseSensitive: false),
      RegExp(r'owner: ([^,\n\.]+)', caseSensitive: false),
      RegExp(r'responsible: ([^,\n\.]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }

    return null;
  }

  String? _extractDueDate(String text) {
    final patterns = [
      RegExp(r'due ([^,\n\.]+)', caseSensitive: false),
      RegExp(r'deadline: ([^,\n\.]+)', caseSensitive: false),
      RegExp(r'by ([^,\n\.]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }

    return null;
  }

  String _extractPriority(String text) {
    if (text.toLowerCase().contains('high') ||
        text.toLowerCase().contains('urgent')) {
      return 'high';
    } else if (text.toLowerCase().contains('low')) {
      return 'low';
    }
    return 'medium';
  }

  String? _extractDecisionMaker(String text) {
    final patterns = [
      RegExp(r'made by ([^,\n\.]+)', caseSensitive: false),
      RegExp(r'decided by ([^,\n\.]+)', caseSensitive: false),
      RegExp(r'([A-Z][a-z]+ [A-Z][a-z]+) decided', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }

    return null;
  }
}

/// Factory for getting appropriate processor for summary type
class SummaryTypeProcessorFactory {
  static final Map<SummaryType, SummaryTypeProcessor> _processors = {
    SummaryType.brief: BriefSummaryProcessor(),
    SummaryType.detailed: DetailedSummaryProcessor(),
    // Additional processors will be registered at runtime
  };

  /// Get processor for summary type
  static SummaryTypeProcessor? getProcessor(SummaryType type) {
    return _processors[type];
  }

  /// Register custom processor
  static void registerProcessor(
    SummaryType type,
    SummaryTypeProcessor processor,
  ) {
    _processors[type] = processor;
  }

  /// Get all available processors
  static Map<SummaryType, SummaryTypeProcessor> get availableProcessors =>
      Map.unmodifiable(_processors);
}
