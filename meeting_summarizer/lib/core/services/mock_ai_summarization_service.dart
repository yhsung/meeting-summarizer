/// Mock implementation of AI summarization service for testing and development
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'base_ai_summarization_service.dart';
import 'ai_summarization_service_interface.dart';
import '../models/summarization_configuration.dart';
import '../models/summarization_result.dart';
import '../enums/summary_type.dart';

/// Mock implementation for testing and development
class MockAISummarizationService extends BaseAISummarizationService {
  static const Uuid _uuid = Uuid();
  final math.Random _random = math.Random();

  MockAISummarizationService(super.config);

  @override
  Future<void> initializeProvider() async {
    // Simulate initialization delay
    await Future.delayed(const Duration(milliseconds: 100));
    debugPrint('MockAISummarizationService: Initialized');
  }

  @override
  Future<void> disposeProvider() async {
    debugPrint('MockAISummarizationService: Disposed');
  }

  @override
  ServiceCapabilities get capabilities => const ServiceCapabilities(
    supportedLanguages: ['en', 'es', 'fr', 'de'],
    supportedSummaryTypes: [
      'brief',
      'detailed',
      'bullet_points',
      'action_items',
      'executive',
      'meeting_notes',
      'key_highlights',
      'topical',
    ],
    maxInputTokens: 10000,
    maxOutputTokens: 2000,
    supportsStreaming: true,
    supportsActionItems: true,
    supportsDecisionExtraction: true,
    supportsTopicExtraction: true,
    supportsBatchProcessing: false,
  );

  @override
  Future<SummarizationResult> generateSummaryInternal({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
    String? sessionId,
  }) async {
    // Simulate processing delay
    final processingTime = 500 + _random.nextInt(1000);
    await Future.delayed(Duration(milliseconds: processingTime));

    // Generate mock summary based on configuration
    final summary = _generateMockSummary(transcriptionText, configuration);
    final actionItems = configuration.extractActionItems
        ? _generateMockActionItems(transcriptionText)
        : <ActionItem>[];
    final keyDecisions = configuration.identifyDecisions
        ? _generateMockKeyDecisions(transcriptionText)
        : <KeyDecision>[];
    final topics = configuration.extractTopics
        ? _generateMockTopics(transcriptionText)
        : <TopicExtract>[];

    return SummarizationResult(
      id: _uuid.v4(),
      content: summary,
      summaryType: configuration.summaryType,
      actionItems: actionItems,
      keyDecisions: keyDecisions,
      topics: topics,
      keyHighlights: _generateMockHighlights(transcriptionText),
      confidenceScore: 0.8 + _random.nextDouble() * 0.2,
      wordCount: summary.split(' ').length,
      characterCount: summary.length,
      processingTimeMs: processingTime,
      aiModel: 'mock-model-v1.0',
      language: configuration.language,
      createdAt: DateTime.now(),
      sourceTranscriptionId: sessionId ?? _uuid.v4(),
      metadata: SummarizationMetadata(
        totalTokens: 1000 + _random.nextInt(500),
        promptTokens: 500 + _random.nextInt(200),
        completionTokens: 300 + _random.nextInt(200),
        cost: 0.001 + _random.nextDouble() * 0.01,
        costCurrency: 'USD',
        modelVersion: 'mock-v1.0',
        temperature: configuration.temperature,
        maxTokens: configuration.maxTokens,
        streamingUsed: configuration.enableStreaming,
      ),
    );
  }

  @override
  Stream<SummarizationResult> generateSummaryStreamInternal({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
    String? sessionId,
  }) async* {
    // Simulate streaming by yielding partial results
    final words = transcriptionText.split(' ');
    final chunks = <String>[];

    // Process in chunks
    for (int i = 0; i < words.length; i += 50) {
      final chunk = words.skip(i).take(50).join(' ');
      chunks.add(chunk);

      // Simulate processing delay
      await Future.delayed(const Duration(milliseconds: 200));

      // Generate partial summary
      final partialSummary = _generateMockSummary(
        chunks.join(' '),
        configuration,
      );

      yield SummarizationResult(
        id: _uuid.v4(),
        content: partialSummary,
        summaryType: configuration.summaryType,
        actionItems: i > words.length * 0.7
            ? _generateMockActionItems(transcriptionText)
            : [],
        keyDecisions: i > words.length * 0.8
            ? _generateMockKeyDecisions(transcriptionText)
            : [],
        topics: i > words.length * 0.9
            ? _generateMockTopics(transcriptionText)
            : [],
        keyHighlights: _generateMockHighlights(chunks.join(' ')),
        confidenceScore: math.min(0.9, 0.5 + (i / words.length) * 0.4),
        wordCount: partialSummary.split(' ').length,
        characterCount: partialSummary.length,
        processingTimeMs: 200,
        aiModel: 'mock-model-v1.0',
        language: configuration.language,
        createdAt: DateTime.now(),
        sourceTranscriptionId: sessionId ?? _uuid.v4(),
        metadata: SummarizationMetadata(
          totalTokens: chunks.join(' ').length ~/ 4,
          promptTokens: transcriptionText.length ~/ 4,
          completionTokens: partialSummary.length ~/ 4,
          cost: 0.001,
          costCurrency: 'USD',
          modelVersion: 'mock-v1.0',
          temperature: configuration.temperature,
          maxTokens: configuration.maxTokens,
          streamingUsed: true,
        ),
      );
    }
  }

  String _generateMockSummary(
    String transcriptionText,
    SummarizationConfiguration configuration,
  ) {
    final words = transcriptionText.split(' ');

    switch (configuration.summaryType) {
      case SummaryType.brief:
        return _generateBriefSummary(words, configuration);
      case SummaryType.detailed:
        return _generateDetailedSummary(words, configuration);
      case SummaryType.bulletPoints:
        return _generateBulletPointsSummary(words, configuration);
      case SummaryType.actionItems:
        return _generateActionItemsSummary(words, configuration);
      case SummaryType.executive:
        return _generateExecutiveSummary(words, configuration);
      case SummaryType.meetingNotes:
        return _generateMeetingNotesSummary(words, configuration);
      case SummaryType.keyHighlights:
        return _generateKeyHighlightsSummary(words, configuration);
      case SummaryType.topical:
        return _generateTopicalSummary(words, configuration);
      case SummaryType.speakerFocused:
        return _generateSpeakerFocusedSummary(words, configuration);
      case SummaryType.custom:
        return _generateCustomSummary(words, configuration);
    }
  }

  String _generateBriefSummary(
    List<String> words,
    SummarizationConfiguration config,
  ) {
    final topics = [
      'project planning',
      'budget allocation',
      'timeline review',
      'team coordination',
    ];
    final selectedTopic = topics[_random.nextInt(topics.length)];

    return 'This ${words.length > 200 ? "meeting" : "discussion"} focused on $selectedTopic. '
        'Key points covered include initial planning phases, resource allocation strategies, '
        'and next steps for implementation. The team agreed on moving forward with the '
        'proposed approach and established clear deliverables for the upcoming milestones.';
  }

  String _generateDetailedSummary(
    List<String> words,
    SummarizationConfiguration config,
  ) {
    return 'Comprehensive Discussion Summary\n\n'
        'The session began with an overview of current project status and identified several '
        'key areas requiring attention. Participants engaged in detailed discussions about '
        'resource allocation, timeline constraints, and strategic priorities.\n\n'
        'Major topics addressed:\n'
        '- Project scope and requirements analysis\n'
        '- Budget considerations and funding sources\n'
        '- Team responsibilities and role assignments\n'
        '- Risk assessment and mitigation strategies\n\n'
        'The group reached consensus on the proposed approach and outlined specific action '
        'items with assigned owners and target completion dates. Follow-up meetings were '
        'scheduled to monitor progress and address any emerging challenges.';
  }

  String _generateBulletPointsSummary(
    List<String> words,
    SummarizationConfiguration config,
  ) {
    return '• Project status review completed\n'
        '• Budget allocation approved for Q1\n'
        '• Timeline milestones established\n'
        '• Team assignments clarified\n'
        '• Risk mitigation plan developed\n'
        '• Next meeting scheduled for follow-up\n'
        '• Documentation requirements defined\n'
        '• Quality assurance protocols agreed upon';
  }

  String _generateActionItemsSummary(
    List<String> words,
    SummarizationConfiguration config,
  ) {
    return 'Action Items Summary:\n\n'
        '1. Finalize project requirements document (Due: End of week)\n'
        '2. Secure budget approval from stakeholders (Due: Next Tuesday)\n'
        '3. Assign team leads for each workstream (Due: Tomorrow)\n'
        '4. Schedule kick-off meeting with all participants (Due: Next week)\n'
        '5. Develop detailed project timeline (Due: End of month)\n'
        '6. Identify potential risks and mitigation strategies (Due: Next Friday)';
  }

  String _generateExecutiveSummary(
    List<String> words,
    SummarizationConfiguration config,
  ) {
    return 'Executive Summary\n\n'
        'Strategic Planning Session Results:\n\n'
        'The leadership team convened to address critical project initiatives and establish '
        'clear direction for the upcoming quarter. Key decisions were made regarding resource '
        'allocation, strategic priorities, and operational efficiency improvements.\n\n'
        'Outcomes: Approved budget increase of 15%, established three priority workstreams, '
        'and committed to accelerated delivery timeline. Risk assessment identified minimal '
        'exposure with appropriate mitigation strategies in place.\n\n'
        'Recommendation: Proceed with implementation as planned with regular progress reviews.';
  }

  String _generateMeetingNotesSummary(
    List<String> words,
    SummarizationConfiguration config,
  ) {
    final time = DateTime.now();
    return 'Meeting Notes - ${time.toLocal().toString().split(' ')[0]}\n\n'
        '10:00 AM - Meeting commenced with introductions\n'
        '10:15 AM - Project overview presentation\n'
        '10:30 AM - Budget discussion and approval\n'
        '10:45 AM - Timeline and milestone review\n'
        '11:00 AM - Team assignments and responsibilities\n'
        '11:15 AM - Risk assessment and mitigation planning\n'
        '11:30 AM - Action items review and assignment\n'
        '11:45 AM - Next steps and follow-up scheduling\n'
        '12:00 PM - Meeting concluded';
  }

  String _generateKeyHighlightsSummary(
    List<String> words,
    SummarizationConfiguration config,
  ) {
    return 'Key Highlights:\n\n'
        '🎯 Primary Objective: Successful project launch within budget and timeline\n'
        '💰 Budget Approved: Secured funding for all planned initiatives\n'
        '👥 Team Alignment: Clear roles and responsibilities established\n'
        '📅 Timeline Confirmed: All milestones achievable with current resources\n'
        '⚠️ Risk Management: Comprehensive mitigation strategies in place\n'
        '🚀 Next Steps: Implementation begins immediately with regular check-ins';
  }

  String _generateTopicalSummary(
    List<String> words,
    SummarizationConfiguration config,
  ) {
    return 'Topical Summary by Discussion Areas:\n\n'
        'PROJECT PLANNING:\n'
        'Comprehensive review of project scope, requirements, and deliverables. '
        'Team confirmed understanding of objectives and success criteria.\n\n'
        'RESOURCE ALLOCATION:\n'
        'Budget discussions focused on optimal distribution of funds across '
        'workstreams. Approved additional resources for critical path items.\n\n'
        'TIMELINE MANAGEMENT:\n'
        'Milestone review identified potential bottlenecks and established '
        'contingency plans. Realistic delivery dates confirmed.\n\n'
        'RISK ASSESSMENT:\n'
        'Identified key risks and developed mitigation strategies. Regular '
        'monitoring protocols established for early warning systems.';
  }

  String _generateSpeakerFocusedSummary(
    List<String> words,
    SummarizationConfiguration config,
  ) {
    return 'Speaker-Focused Summary:\n\n'
        'PROJECT MANAGER:\n'
        'Presented comprehensive project overview, timeline, and resource requirements. '
        'Emphasized importance of staying on schedule and within budget.\n\n'
        'TEAM LEAD:\n'
        'Discussed technical implementation details and team capacity. Confirmed '
        'availability of required skills and expertise.\n\n'
        'STAKEHOLDER:\n'
        'Provided business context and strategic alignment. Approved funding '
        'and authorized project progression.\n\n'
        'PARTICIPANTS:\n'
        'Contributed domain expertise and identified potential challenges. '
        'Committed to supporting project success.';
  }

  String _generateCustomSummary(
    List<String> words,
    SummarizationConfiguration config,
  ) {
    return config.customPrompt ?? _generateBriefSummary(words, config);
  }

  List<ActionItem> _generateMockActionItems(String text) {
    final items = [
      'Complete project requirements documentation',
      'Schedule stakeholder review meeting',
      'Prepare budget allocation proposal',
      'Assign team leads for each workstream',
      'Develop risk mitigation strategies',
    ];

    return items.take(3 + _random.nextInt(3)).map((description) {
      return ActionItem(
        id: _uuid.v4(),
        description: description,
        assignee: _random.nextBool()
            ? 'Team Member ${_random.nextInt(5) + 1}'
            : null,
        dueDate: _random.nextBool()
            ? DateTime.now().add(Duration(days: 1 + _random.nextInt(14)))
            : null,
        priority: ['high', 'medium', 'low'][_random.nextInt(3)],
        confidence: 0.7 + _random.nextDouble() * 0.3,
        timestamp: Duration(minutes: _random.nextInt(60)),
      );
    }).toList();
  }

  List<KeyDecision> _generateMockKeyDecisions(String text) {
    final decisions = [
      'Approved budget increase for project expansion',
      'Selected technology stack for implementation',
      'Established project timeline and milestones',
      'Assigned project leadership roles',
      'Adopted agile development methodology',
    ];

    return decisions.take(2 + _random.nextInt(3)).map((description) {
      return KeyDecision(
        id: _uuid.v4(),
        description: description,
        decisionMaker: _random.nextBool() ? 'Project Manager' : null,
        impact: _random.nextBool()
            ? 'Significant impact on project timeline'
            : null,
        confidence: 0.8 + _random.nextDouble() * 0.2,
        timestamp: Duration(minutes: _random.nextInt(60)),
      );
    }).toList();
  }

  List<TopicExtract> _generateMockTopics(String text) {
    final topics = [
      ('Project Planning', ['planning', 'strategy', 'roadmap']),
      ('Budget Management', ['budget', 'cost', 'funding']),
      ('Team Coordination', ['team', 'roles', 'collaboration']),
      ('Timeline Management', ['schedule', 'deadline', 'milestone']),
      ('Risk Assessment', ['risk', 'mitigation', 'contingency']),
    ];

    return topics.take(3 + _random.nextInt(3)).map((topicData) {
      return TopicExtract(
        topic: topicData.$1,
        relevance: 0.6 + _random.nextDouble() * 0.4,
        keywords: topicData.$2,
        description: 'Discussion about ${topicData.$1.toLowerCase()}',
        discussionDuration: Duration(minutes: 5 + _random.nextInt(15)),
      );
    }).toList();
  }

  List<String> _generateMockHighlights(String text) {
    final highlights = [
      'Project approved with full funding',
      'Timeline confirmed as achievable',
      'Team assignments finalized',
      'Risk mitigation plan established',
      'Next steps clearly defined',
    ];

    return highlights.take(3 + _random.nextInt(3)).toList();
  }
}
