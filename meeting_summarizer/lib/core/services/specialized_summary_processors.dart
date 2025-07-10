/// Specialized processors for action items, executive summaries, and other summary types
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../enums/summary_type.dart';
import '../models/summarization_configuration.dart';
import '../models/summarization_result.dart';
import '../exceptions/summarization_exceptions.dart';
import 'summary_type_processors.dart';

/// Processor specialized for action items
class ActionItemsProcessor extends SummaryTypeProcessor {
  static const Uuid _uuid = Uuid();

  @override
  bool canProcess(SummarizationConfiguration configuration) {
    return configuration.summaryType == SummaryType.actionItems;
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

    // Specialized system prompt for action items
    const systemPrompt =
        '''You are an expert at extracting actionable tasks and commitments from meeting transcriptions. Focus on:
- Clear, specific action items
- Assignments and ownership
- Deadlines and timelines
- Dependencies and prerequisites
- Priority levels based on context''';

    // Generate action-focused prompt
    final prompt =
        '''Extract ALL action items from the following transcription. For each action item, provide:

1. TASK DESCRIPTION: Clear, specific description of what needs to be done
2. ASSIGNEE: Who is responsible (if mentioned)
3. DUE DATE: When it's due (if mentioned)
4. PRIORITY: High/Medium/Low based on urgency and importance
5. CONTEXT: Background or reasoning
6. DEPENDENCIES: What needs to happen first

Format as a structured list with clear headings.

TRANSCRIPTION:
${transcriptionText.trim()}

Provide a comprehensive list of all actionable items:''';

    try {
      final summaryContent = await aiCall(prompt, systemPrompt);

      // Extract detailed action items
      final actionItems = await _extractAdvancedActionItems(summaryContent);

      final processingTime = DateTime.now().difference(startTime);

      return SummarizationResult(
        id: _uuid.v4(),
        content: summaryContent,
        summaryType: configuration.summaryType,
        actionItems: actionItems,
        keyDecisions: [], // Focus on actions, not decisions
        topics: [], // Focus on actions, not topics
        keyHighlights: _extractActionHighlights(summaryContent),
        confidenceScore: _calculateActionItemConfidence(
          actionItems,
          transcriptionText,
        ),
        wordCount: summaryContent.split(' ').length,
        characterCount: summaryContent.length,
        processingTimeMs: processingTime.inMilliseconds,
        aiModel: 'processor-action-items-v1.0',
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
        ),
      );
    } catch (e) {
      throw SummarizationExceptions.processingFailed(
        'Action items processing failed: $e',
      );
    }
  }

  Future<List<ActionItem>> _extractAdvancedActionItems(String content) async {
    final items = <ActionItem>[];
    final sections = content.split('\n\n');

    for (final section in sections) {
      if (section.trim().isEmpty) continue;

      final lines = section.split('\n');
      ActionItem? currentItem;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        // Detect new action item
        if (_isActionItemStart(trimmed)) {
          // Save previous item
          if (currentItem != null) {
            items.add(currentItem);
          }

          // Start new item
          currentItem = ActionItem(
            id: _uuid.v4(),
            description: _cleanActionDescription(trimmed),
            priority: 'medium',
            confidence: 0.9,
          );
        } else if (currentItem != null) {
          // Parse additional details
          currentItem = _parseActionItemDetails(currentItem, trimmed);
        }
      }

      // Save last item
      if (currentItem != null) {
        items.add(currentItem);
      }
    }

    return items;
  }

  bool _isActionItemStart(String line) {
    final actionIndicators = [
      r'^\d+\.',
      r'^[-•*]',
      r'^TASK:',
      r'^ACTION:',
      r'^TODO:',
    ];

    return actionIndicators.any(
      (pattern) => RegExp(pattern, caseSensitive: false).hasMatch(line),
    );
  }

  String _cleanActionDescription(String line) {
    return line
        .replaceAll(RegExp(r'^\d+\.'), '')
        .replaceAll(RegExp(r'^[-•*]'), '')
        .replaceAll(RegExp(r'^(TASK|ACTION|TODO):', caseSensitive: false), '')
        .trim();
  }

  ActionItem _parseActionItemDetails(ActionItem item, String line) {
    final lower = line.toLowerCase();

    // Parse assignee
    String? assignee = item.assignee;
    if (lower.contains('assignee:') ||
        lower.contains('responsible:') ||
        lower.contains('owner:')) {
      assignee = _extractValue(line, ['assignee:', 'responsible:', 'owner:']);
    }

    // Parse due date
    DateTime? dueDate = item.dueDate;
    if (lower.contains('due:') ||
        lower.contains('deadline:') ||
        lower.contains('by:')) {
      final dateStr = _extractValue(line, ['due:', 'deadline:', 'by:']);
      dueDate = _parseDate(dateStr);
    }

    // Parse priority
    String priority = item.priority;
    if (lower.contains('priority:')) {
      final priorityStr = _extractValue(line, ['priority:'])?.toLowerCase();
      if (priorityStr != null) {
        if (priorityStr.contains('high') || priorityStr.contains('urgent')) {
          priority = 'high';
        } else if (priorityStr.contains('low')) {
          priority = 'low';
        } else {
          priority = 'medium';
        }
      }
    }

    // Parse context
    String? context = item.context;
    if (lower.contains('context:') || lower.contains('background:')) {
      context = _extractValue(line, ['context:', 'background:']);
    }

    return ActionItem(
      id: item.id,
      description: item.description,
      assignee: assignee,
      dueDate: dueDate,
      priority: priority,
      context: context,
      timestamp: item.timestamp,
      confidence: item.confidence,
    );
  }

  String? _extractValue(String line, List<String> prefixes) {
    for (final prefix in prefixes) {
      final index = line.toLowerCase().indexOf(prefix);
      if (index >= 0) {
        return line.substring(index + prefix.length).trim();
      }
    }
    return null;
  }

  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;

    try {
      // Try common date formats
      final patterns = [
        RegExp(r'(\d{4}-\d{2}-\d{2})'),
        RegExp(r'(\d{1,2}/\d{1,2}/\d{4})'),
        RegExp(r'(\d{1,2}-\d{1,2}-\d{4})'),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(dateStr);
        if (match != null) {
          return DateTime.tryParse(match.group(1)!);
        }
      }

      // Try relative dates
      if (dateStr.toLowerCase().contains('tomorrow')) {
        return DateTime.now().add(const Duration(days: 1));
      } else if (dateStr.toLowerCase().contains('next week')) {
        return DateTime.now().add(const Duration(days: 7));
      } else if (dateStr.toLowerCase().contains('end of week')) {
        final now = DateTime.now();
        final daysUntilFriday = 5 - now.weekday;
        return now.add(Duration(days: daysUntilFriday));
      }
    } catch (e) {
      debugPrint(
        'ActionItemsProcessor: Date parsing failed for "$dateStr": $e',
      );
    }

    return null;
  }

  List<String> _extractActionHighlights(String content) {
    final highlights = <String>[];
    final lines = content.split('\n');

    for (final line in lines) {
      if (line.trim().isNotEmpty &&
          (line.toLowerCase().contains('urgent') ||
              line.toLowerCase().contains('critical') ||
              line.toLowerCase().contains('high priority'))) {
        highlights.add(line.trim());
      }
    }

    return highlights.take(5).toList();
  }

  double _calculateActionItemConfidence(
    List<ActionItem> items,
    String originalText,
  ) {
    if (items.isEmpty) return 0.0;

    double score = 0.7;

    // Higher confidence for more detailed items
    final itemsWithAssignees = items
        .where((item) => item.assignee != null)
        .length;
    final itemsWithDueDates = items
        .where((item) => item.dueDate != null)
        .length;

    score += (itemsWithAssignees / items.length) * 0.15;
    score += (itemsWithDueDates / items.length) * 0.15;

    return score.clamp(0.0, 1.0);
  }
}

/// Processor specialized for executive summaries
class ExecutiveSummaryProcessor extends SummaryTypeProcessor {
  static const Uuid _uuid = Uuid();

  @override
  bool canProcess(SummarizationConfiguration configuration) {
    return configuration.summaryType == SummaryType.executive;
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

    // Executive-focused system prompt
    const systemPrompt =
        '''You are an executive assistant specializing in creating high-level strategic summaries for senior leadership. Focus on:
- Business impact and strategic implications
- Key decisions and their rationale
- Resource requirements and recommendations
- Risk assessment and opportunities
- Clear action items for leadership''';

    // Generate executive-focused prompt
    final prompt =
        '''Create an executive summary of the following meeting transcription. Structure it for senior leadership with these sections:

1. EXECUTIVE OVERVIEW: High-level summary in 2-3 sentences
2. KEY DECISIONS: Strategic decisions made and their implications
3. BUSINESS IMPACT: Resource, financial, and operational implications
4. RECOMMENDATIONS: Specific recommendations for leadership action
5. NEXT STEPS: Critical actions requiring executive attention

Focus on strategic value, business impact, and leadership decisions. Avoid technical details unless strategically relevant.

MEETING TRANSCRIPTION:
${transcriptionText.trim()}

Provide a concise, strategic executive summary:''';

    try {
      final summaryContent = await aiCall(prompt, systemPrompt);

      // Process for executive format
      final processedContent = _formatExecutiveSummary(summaryContent);

      final processingTime = DateTime.now().difference(startTime);

      return SummarizationResult(
        id: _uuid.v4(),
        content: processedContent,
        summaryType: configuration.summaryType,
        actionItems: configuration.extractActionItems
            ? await _extractExecutiveActions(summaryContent, aiCall)
            : [],
        keyDecisions: configuration.identifyDecisions
            ? await _extractStrategicDecisions(summaryContent, aiCall)
            : [],
        topics:
            [], // Executive summaries focus on strategic points, not detailed topics
        keyHighlights: _extractExecutiveHighlights(processedContent),
        confidenceScore: _calculateExecutiveConfidence(
          processedContent,
          transcriptionText,
        ),
        wordCount: processedContent.split(' ').length,
        characterCount: processedContent.length,
        processingTimeMs: processingTime.inMilliseconds,
        aiModel: 'processor-executive-v1.0',
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
        'Executive summary processing failed: $e',
      );
    }
  }

  String _formatExecutiveSummary(String content) {
    // Ensure proper executive format with clear sections
    if (!content.contains('EXECUTIVE OVERVIEW') &&
        !content.contains('Executive Overview')) {
      // Add structure if missing
      final paragraphs = content.split('\n\n');

      final sections = <String>[];

      if (paragraphs.isNotEmpty) {
        sections.add('## Executive Overview\n${paragraphs.first}');

        if (paragraphs.length > 1) {
          sections.add(
            '\n## Key Points\n${paragraphs.skip(1).take(2).join('\n\n')}',
          );
        }

        if (paragraphs.length > 3) {
          sections.add(
            '\n## Recommendations\n${paragraphs.skip(3).join('\n\n')}',
          );
        }
      }

      return sections.join('\n');
    }

    return content;
  }

  Future<List<ActionItem>> _extractExecutiveActions(
    String content,
    Future<String> Function(String, String) aiCall,
  ) async {
    try {
      final prompt =
          '''Extract executive-level action items from this summary. Focus on:
- Strategic initiatives requiring leadership approval
- Resource allocation decisions
- High-level assignments to departments/teams
- Board or stakeholder communications needed

SUMMARY:
$content

Return only strategic actions requiring executive attention.''';

      final response = await aiCall(prompt, 'Extract strategic action items.');
      return _parseExecutiveActions(response);
    } catch (e) {
      debugPrint('ExecutiveSummaryProcessor: Action extraction failed: $e');
      return [];
    }
  }

  Future<List<KeyDecision>> _extractStrategicDecisions(
    String content,
    Future<String> Function(String, String) aiCall,
  ) async {
    try {
      final prompt =
          '''Extract strategic decisions from this executive summary. Focus on:
- Business strategy decisions
- Resource allocation choices
- Policy or direction changes
- Investment or budget decisions

SUMMARY:
$content

Return decisions with business impact and strategic implications.''';

      final response = await aiCall(prompt, 'Extract strategic decisions.');
      return _parseStrategicDecisions(response);
    } catch (e) {
      debugPrint('ExecutiveSummaryProcessor: Decision extraction failed: $e');
      return [];
    }
  }

  List<String> _extractExecutiveHighlights(String content) {
    final highlights = <String>[];
    final lines = content.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty &&
          (trimmed.toLowerCase().contains('strategic') ||
              trimmed.toLowerCase().contains('critical') ||
              trimmed.toLowerCase().contains('recommend') ||
              trimmed.toLowerCase().contains('decision') ||
              trimmed.toLowerCase().contains('impact'))) {
        highlights.add(trimmed);
      }
    }

    return highlights.take(4).toList();
  }

  double _calculateExecutiveConfidence(String summary, String originalText) {
    if (summary.isEmpty || originalText.isEmpty) return 0.0;

    double score = 0.75;

    // Check for executive-level content
    final executiveKeywords = [
      'strategic',
      'business',
      'recommend',
      'decision',
      'impact',
      'resource',
      'budget',
      'leadership',
      'board',
    ];

    final summaryLower = summary.toLowerCase();
    final keywordCount = executiveKeywords
        .where((keyword) => summaryLower.contains(keyword))
        .length;

    score += (keywordCount / executiveKeywords.length) * 0.2;

    // Check for proper structure
    if (summary.contains('##') ||
        summary.contains('EXECUTIVE') ||
        summary.contains('RECOMMENDATION')) {
      score += 0.05;
    }

    return score.clamp(0.0, 1.0);
  }

  List<ActionItem> _parseExecutiveActions(String response) {
    final items = <ActionItem>[];
    final lines = response.split('\n');

    for (final line in lines) {
      if (line.trim().isNotEmpty &&
          (line.startsWith('-') ||
              line.startsWith('•') ||
              line.contains('Action'))) {
        final description = line.trim().replaceAll(RegExp(r'^[-•]\s*'), '');

        // Determine priority based on content
        String priority = 'medium';
        if (description.toLowerCase().contains('urgent') ||
            description.toLowerCase().contains('critical') ||
            description.toLowerCase().contains('board')) {
          priority = 'high';
        }

        items.add(
          ActionItem(
            id: _uuid.v4(),
            description: description,
            priority: priority,
            confidence: 0.9,
          ),
        );
      }
    }

    return items.take(6).toList();
  }

  List<KeyDecision> _parseStrategicDecisions(String response) {
    final decisions = <KeyDecision>[];
    final lines = response.split('\n');

    for (final line in lines) {
      if (line.trim().isNotEmpty &&
          (line.startsWith('-') ||
              line.startsWith('•') ||
              line.contains('Decision'))) {
        final description = line.trim().replaceAll(RegExp(r'^[-•]\s*'), '');

        // Extract impact if mentioned
        String? impact;
        if (description.toLowerCase().contains('impact') ||
            description.toLowerCase().contains('result')) {
          impact = 'Strategic business impact';
        }

        decisions.add(
          KeyDecision(
            id: _uuid.v4(),
            description: description,
            impact: impact,
            confidence: 0.9,
          ),
        );
      }
    }

    return decisions.take(5).toList();
  }
}
