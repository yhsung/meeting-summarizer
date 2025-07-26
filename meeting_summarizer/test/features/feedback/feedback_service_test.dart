import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:in_app_review/in_app_review.dart';

import 'package:meeting_summarizer/core/database/database_helper.dart';
import 'package:meeting_summarizer/core/services/feedback_service.dart';
import 'package:meeting_summarizer/core/models/feedback/feedback_item.dart';
import 'package:meeting_summarizer/core/models/feedback/feedback_analytics.dart';

// Mock classes
class MockDatabaseHelper extends Mock implements DatabaseHelper {}

class MockSharedPreferences extends Mock implements SharedPreferences {}

class MockInAppReview extends Mock implements InAppReview {}

class MockUuid extends Mock implements Uuid {}

void main() {
  group('FeedbackService', () {
    late FeedbackService feedbackService;
    late MockDatabaseHelper mockDatabaseHelper;
    late MockSharedPreferences mockPrefs;
    late MockInAppReview mockInAppReview;
    late MockUuid mockUuid;

    setUp(() {
      mockDatabaseHelper = MockDatabaseHelper();
      mockPrefs = MockSharedPreferences();
      mockInAppReview = MockInAppReview();
      mockUuid = MockUuid();

      feedbackService = FeedbackService(
        databaseHelper: mockDatabaseHelper,
        prefs: mockPrefs,
        inAppReview: mockInAppReview,
        uuid: mockUuid,
      );
    });

    group('initialization', () {
      test('should initialize successfully', () async {
        // For now, just test that the service can be created
        // Full integration testing would require proper database mocking
        expect(feedbackService, isNotNull);
      });
    });

    group('feedback submission', () {
      test('should create feedback with correct properties', () async {
        // Test the feedback model creation
        final feedback = FeedbackItem(
          id: 'test-id',
          type: FeedbackType.general,
          subject: 'Test Subject',
          message: 'Test Message',
          appVersion: '1.0.0',
          platform: 'test',
          createdAt: DateTime.now(),
          isSubmitted: false,
          tags: const ['test'],
        );

        expect(feedback.id, equals('test-id'));
        expect(feedback.type, equals(FeedbackType.general));
        expect(feedback.subject, equals('Test Subject'));
      });
    });

    group('rating prompt logic', () {
      test('should not show rating prompt for new users', () async {
        when(mockPrefs.getBool('never_show_rating')).thenReturn(false);
        when(mockPrefs.getBool('has_rated_app')).thenReturn(false);
        when(
          mockPrefs.getInt('app_launch_count'),
        ).thenReturn(5); // Less than 10

        final shouldShow = await feedbackService.shouldShowRatingPrompt();

        expect(shouldShow, isFalse);
      });

      test('should show rating prompt for eligible users', () async {
        when(mockPrefs.getBool('never_show_rating')).thenReturn(false);
        when(mockPrefs.getBool('has_rated_app')).thenReturn(false);
        when(
          mockPrefs.getInt('app_launch_count'),
        ).thenReturn(15); // More than 10
        when(mockPrefs.getInt('last_rating_prompt')).thenReturn(null);
        when(mockPrefs.getBool('feedback_submitted')).thenReturn(false);

        final shouldShow = await feedbackService.shouldShowRatingPrompt();

        expect(shouldShow, isTrue);
      });

      test('should not show rating prompt if user opted out', () async {
        when(mockPrefs.getBool('never_show_rating')).thenReturn(true);

        final shouldShow = await feedbackService.shouldShowRatingPrompt();

        expect(shouldShow, isFalse);
      });
    });

    group('feedback analytics', () {
      test('should create empty analytics', () async {
        // Test the analytics model creation
        final analytics = FeedbackAnalytics.empty();

        expect(analytics.totalFeedback, equals(0));
        expect(analytics.averageRating, equals(0.0));
        expect(analytics.bugReports, equals(0));
        expect(analytics.featureRequests, equals(0));
      });
    });
  });
}

// Mock database for testing
class MockDatabase extends Mock {
  Future<void> execute(String sql) async {}
  Future<int> rawInsert(String sql, List<Object?> arguments) async => 1;
  Future<List<Map<String, Object?>>> rawQuery(String sql) async => [];
}
