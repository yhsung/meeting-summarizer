/// Tests for quality scoring and feedback integration service
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/services/quality_scoring_service.dart';
import 'package:meeting_summarizer/core/models/summarization_result.dart';
import 'package:meeting_summarizer/core/models/summarization_configuration.dart';
import 'package:meeting_summarizer/core/enums/summary_type.dart';

void main() {
  group('QualityScoringService Tests', () {
    late SummarizationResult testResult;
    late SummarizationConfiguration testConfiguration;
    late String testTranscription;

    setUp(() {
      testTranscription = '''
      Meeting discussion about project planning and budget allocation.
      We need to finalize the requirements by Friday.
      The budget has been approved for Q1 initiatives.
      Action items include hiring new developers and scheduling training.
      Risk assessment identified potential delays in Phase 2.
      ''';

      testResult = SummarizationResult(
        id: 'test-summary-id',
        content: '''
        ## Project Planning Discussion

        The team discussed project requirements and budget allocation for Q1.
        Key decisions include hiring developers and scheduling training sessions.
        Risk assessment identified Phase 2 delays as main concern.

        **Action Items:**
        - Finalize requirements by Friday
        - Hire new developers
        - Schedule training sessions

        **Decisions:**
        - Budget approved for Q1 initiatives
        - Risk mitigation plan needed for Phase 2
        ''',
        summaryType: SummaryType.meetingNotes,
        actionItems: [
          ActionItem(
            id: 'action-1',
            description: 'Finalize requirements by Friday',
            priority: 'high',
            confidence: 0.9,
          ),
          ActionItem(
            id: 'action-2',
            description: 'Hire new developers',
            priority: 'medium',
            confidence: 0.8,
          ),
        ],
        keyDecisions: [
          KeyDecision(
            id: 'decision-1',
            description: 'Budget approved for Q1 initiatives',
            confidence: 0.9,
          ),
        ],
        topics: [
          TopicExtract(
            topic: 'Project Planning',
            relevance: 0.9,
            keywords: ['project', 'planning', 'requirements'],
            description: 'Discussion about project requirements',
            discussionDuration: Duration(minutes: 15),
          ),
        ],
        keyHighlights: ['Budget approved for Q1', 'Risk assessment completed'],
        confidenceScore: 0.85,
        wordCount: 95,
        characterCount: 450,
        processingTimeMs: 1500,
        aiModel: 'test-model',
        language: 'en',
        createdAt: DateTime.now(),
        sourceTranscriptionId: 'test-transcription-id',
        metadata: SummarizationMetadata(
          totalTokens: 200,
          promptTokens: 100,
          completionTokens: 100,
          streamingUsed: false,
          additionalData: {},
        ),
      );

      testConfiguration = SummarizationConfiguration.meetingDefault();
    });

    group('Quality Assessment', () {
      test('should calculate comprehensive quality scores', () async {
        final assessment = await QualityScoringService.assessQuality(
          result: testResult,
          originalTranscription: testTranscription,
          configuration: testConfiguration,
        );

        expect(assessment.summaryId, equals(testResult.id));
        expect(assessment.overallScore, greaterThan(0.0));
        expect(assessment.overallScore, lessThanOrEqualTo(1.0));
        expect(assessment.accuracyScore, greaterThan(0.0));
        expect(assessment.completenessScore, greaterThan(0.0));
        expect(assessment.clarityScore, greaterThan(0.0));
        expect(assessment.relevanceScore, greaterThan(0.0));
        expect(assessment.structureScore, greaterThan(0.0));
        expect(assessment.recommendations, isNotEmpty);
      });

      test('should handle AI-powered assessment', () async {
        Future<String> mockAiCall(String prompt, String systemPrompt) async {
          return '''
          ACCURACY: 0.85
          COMPLETENESS: 0.80
          CLARITY: 0.90
          RELEVANCE: 0.88
          STRUCTURE: 0.82
          OVERALL: 0.85
          FEEDBACK: High-quality summary with clear structure and comprehensive coverage.
          ''';
        }

        final assessment = await QualityScoringService.assessQuality(
          result: testResult,
          originalTranscription: testTranscription,
          configuration: testConfiguration,
          aiCall: mockAiCall,
        );

        expect(assessment.aiAssessment, isNotNull);
        expect(assessment.aiAssessment!.overall, closeTo(0.85, 0.01));
        expect(assessment.aiAssessment!.accuracy, closeTo(0.85, 0.01));
        expect(assessment.aiAssessment!.feedback, contains('High-quality'));
      });

      test('should incorporate user feedback', () async {
        final userFeedback = [
          UserFeedback(
            id: 'feedback-1',
            summaryId: testResult.id,
            rating: 4,
            comments: 'Good summary but missing some details',
            timestamp: DateTime.now(),
          ),
          UserFeedback(
            id: 'feedback-2',
            summaryId: testResult.id,
            rating: 5,
            comments: 'Excellent structure and clarity',
            timestamp: DateTime.now(),
          ),
        ];

        final assessment = await QualityScoringService.assessQuality(
          result: testResult,
          originalTranscription: testTranscription,
          configuration: testConfiguration,
          userFeedback: userFeedback,
        );

        expect(assessment.feedbackScore, isNotNull);
        expect(assessment.feedbackScore!, greaterThan(0.0));
        expect(assessment.userFeedback, hasLength(2));
        expect(assessment.recommendations, isNotEmpty);
      });

      test('should compare with reference summary', () async {
        final referenceSummary = SummarizationResult(
          id: 'reference-id',
          content: 'Reference summary content for comparison',
          summaryType: SummaryType.brief,
          actionItems: [],
          keyDecisions: [],
          topics: [],
          keyHighlights: [],
          confidenceScore: 0.9,
          wordCount: 50,
          characterCount: 200,
          processingTimeMs: 1000,
          aiModel: 'reference-model',
          language: 'en',
          createdAt: DateTime.now(),
          sourceTranscriptionId: 'reference-transcription',
          metadata: SummarizationMetadata(
            totalTokens: 100,
            promptTokens: 50,
            completionTokens: 50,
            streamingUsed: false,
            additionalData: {},
          ),
        );

        final assessment = await QualityScoringService.assessQuality(
          result: testResult,
          originalTranscription: testTranscription,
          configuration: testConfiguration,
          referenceSummary: referenceSummary,
        );

        expect(assessment.comparisonScore, isNotNull);
        expect(assessment.comparisonScore!, greaterThanOrEqualTo(0.0));
        expect(assessment.comparisonScore!, lessThanOrEqualTo(1.0));
      });

      test('should handle assessment errors gracefully', () async {
        Future<String> failingAiCall(String prompt, String systemPrompt) async {
          throw Exception('AI service unavailable');
        }

        final assessment = await QualityScoringService.assessQuality(
          result: testResult,
          originalTranscription: testTranscription,
          configuration: testConfiguration,
          aiCall: failingAiCall,
        );

        // Should still return valid assessment with fallback scores
        expect(assessment.overallScore, greaterThan(0.0));
        expect(assessment.recommendations, isNotEmpty);
      });
    });

    group('User Feedback Processing', () {
      test('should process and analyze user feedback', () {
        final feedbackList = [
          UserFeedback(
            id: 'feedback-1',
            summaryId: 'summary-1',
            rating: 4,
            comments: 'Good summary but could be more detailed',
            timestamp: DateTime.now(),
          ),
          UserFeedback(
            id: 'feedback-2',
            summaryId: 'summary-1',
            rating: 5,
            comments: 'Excellent clarity and structure',
            timestamp: DateTime.now(),
          ),
          UserFeedback(
            id: 'feedback-3',
            summaryId: 'summary-1',
            rating: 3,
            comments: 'Missing important action items',
            timestamp: DateTime.now(),
          ),
        ];

        final insights = QualityScoringService.processUserFeedback(
          feedbackList,
        );

        expect(insights.averageRating, closeTo(4.0, 0.1));
        expect(insights.feedbackCount, equals(3));
        expect(insights.commonIssues, isA<List<String>>());
        expect(insights.improvementSuggestions, isA<List<String>>());
        expect(insights.positiveAspects, isA<List<String>>());
      });

      test('should handle empty feedback list', () {
        final insights = QualityScoringService.processUserFeedback([]);

        expect(insights.averageRating, isNull);
        expect(insights.feedbackCount, equals(0));
        expect(insights.commonIssues, isEmpty);
        expect(insights.improvementSuggestions, isEmpty);
        expect(insights.positiveAspects, isEmpty);
      });

      test('should identify feedback patterns', () {
        final feedbackList = [
          UserFeedback(
            id: 'feedback-1',
            summaryId: 'summary-1',
            rating: 2,
            comments: 'Too brief and lacks detail',
            timestamp: DateTime.now(),
          ),
          UserFeedback(
            id: 'feedback-2',
            summaryId: 'summary-1',
            rating: 2,
            comments: 'Not detailed enough for executive review',
            timestamp: DateTime.now(),
          ),
          UserFeedback(
            id: 'feedback-3',
            summaryId: 'summary-1',
            rating: 3,
            comments: 'Could use more detail in action items',
            timestamp: DateTime.now(),
          ),
        ];

        final insights = QualityScoringService.processUserFeedback(
          feedbackList,
        );

        expect(insights.commonIssues, isA<List<String>>());
        expect(insights.improvementSuggestions, isA<List<String>>());
      });
    });

    group('Data Classes', () {
      test('QualityAssessment should serialize correctly', () {
        final assessment = QualityAssessment(
          id: 'test-id',
          summaryId: 'summary-id',
          overallScore: 0.85,
          accuracyScore: 0.9,
          completenessScore: 0.8,
          clarityScore: 0.85,
          relevanceScore: 0.9,
          structureScore: 0.8,
          recommendations: ['Improve clarity', 'Add more details'],
          userFeedback: [],
          assessmentDate: DateTime.now(),
          configurationUsed: testConfiguration,
        );

        final json = assessment.toJson();
        expect(json['id'], equals('test-id'));
        expect(json['overallScore'], equals(0.85));
        expect(json['recommendations'], hasLength(2));
      });

      test('QualityDimensions should serialize correctly', () {
        final dimensions = QualityDimensions(
          accuracy: 0.9,
          completeness: 0.8,
          clarity: 0.85,
          relevance: 0.9,
          structure: 0.8,
          overall: 0.85,
          feedback: 'High quality summary',
        );

        final json = dimensions.toJson();
        expect(json['accuracy'], equals(0.9));
        expect(json['overall'], equals(0.85));
        expect(json['feedback'], equals('High quality summary'));
      });

      test('UserFeedback should serialize correctly', () {
        final feedback = UserFeedback(
          id: 'feedback-id',
          summaryId: 'summary-id',
          rating: 4,
          comments: 'Good summary',
          timestamp: DateTime.now(),
          userId: 'user-123',
        );

        final json = feedback.toJson();
        expect(json['id'], equals('feedback-id'));
        expect(json['rating'], equals(4));
        expect(json['comments'], equals('Good summary'));
        expect(json['userId'], equals('user-123'));
      });

      test('QualityInsights should serialize correctly', () {
        final insights = QualityInsights(
          averageRating: 4.2,
          commonIssues: ['Clarity', 'Detail'],
          improvementSuggestions: ['Add examples', 'Improve structure'],
          positiveAspects: ['Good format', 'Clear language'],
          feedbackCount: 5,
        );

        final json = insights.toJson();
        expect(json['averageRating'], equals(4.2));
        expect(json['feedbackCount'], equals(5));
        expect(json['commonIssues'], hasLength(2));
        expect(json['improvementSuggestions'], hasLength(2));
        expect(json['positiveAspects'], hasLength(2));
      });
    });

    group('Edge Cases', () {
      test('should handle empty transcription', () async {
        final assessment = await QualityScoringService.assessQuality(
          result: testResult,
          originalTranscription: '',
          configuration: testConfiguration,
        );

        expect(assessment.overallScore, greaterThan(0.0));
        expect(assessment.recommendations, isNotEmpty);
      });

      test('should handle empty summary content', () async {
        final emptyResult = SummarizationResult(
          id: 'empty-id',
          content: '',
          summaryType: SummaryType.brief,
          actionItems: [],
          keyDecisions: [],
          topics: [],
          keyHighlights: [],
          confidenceScore: 0.1,
          wordCount: 0,
          characterCount: 0,
          processingTimeMs: 100,
          aiModel: 'test-model',
          language: 'en',
          createdAt: DateTime.now(),
          sourceTranscriptionId: 'test-id',
          metadata: SummarizationMetadata(
            totalTokens: 0,
            promptTokens: 0,
            completionTokens: 0,
            streamingUsed: false,
            additionalData: {},
          ),
        );

        final assessment = await QualityScoringService.assessQuality(
          result: emptyResult,
          originalTranscription: testTranscription,
          configuration: testConfiguration,
        );

        expect(assessment.overallScore, greaterThan(0.0));
        expect(assessment.recommendations, isNotEmpty);
      });

      test('should handle malformed AI responses', () async {
        Future<String> malformedAiCall(
          String prompt,
          String systemPrompt,
        ) async {
          return 'Invalid response format without proper structure';
        }

        final assessment = await QualityScoringService.assessQuality(
          result: testResult,
          originalTranscription: testTranscription,
          configuration: testConfiguration,
          aiCall: malformedAiCall,
        );

        // Should still provide assessment even with malformed AI response
        expect(assessment.overallScore, greaterThan(0.0));
      });
    });
  });
}
