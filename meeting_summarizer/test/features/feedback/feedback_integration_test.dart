import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:meeting_summarizer/core/database/database_helper.dart';
import 'package:meeting_summarizer/core/services/feedback_service.dart';
import 'package:meeting_summarizer/core/models/feedback/feedback_item.dart';
import 'package:meeting_summarizer/features/feedback/data/services/feedback_service_provider.dart';
import 'package:meeting_summarizer/features/feedback/presentation/widgets/feedback_integration_widget.dart';
import 'package:meeting_summarizer/features/feedback/presentation/widgets/rating_dialog.dart';
import 'package:meeting_summarizer/features/feedback/presentation/screens/feedback_screen.dart';

void main() {
  group('Feedback System Integration Tests', () {
    late FeedbackService feedbackService;
    late SharedPreferences prefs;

    setUpAll(() async {
      // Initialize database factory for testing
      databaseFactory = databaseFactoryFfi;

      // Initialize shared preferences for testing
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    setUp(() async {
      // Reset preferences for each test
      await prefs.clear();

      // Create feedback service instance
      feedbackService = FeedbackService(
        databaseHelper: DatabaseHelper(),
        prefs: prefs,
      );

      await feedbackService.initialize();
    });

    testWidgets('FeedbackIntegrationWidget initializes correctly', (
      tester,
    ) async {
      final testWidget = MaterialApp(
        home: FeedbackIntegrationWidget(child: Scaffold(body: Text('Test'))),
      );

      await tester.pumpWidget(testWidget);
      await tester.pump();

      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('Rating dialog shows when appropriate', (tester) async {
      // Set launch count to trigger rating prompt
      await prefs.setInt('app_launch_count', 15);

      final testWidget = MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => RatingDialog.showIfAppropriate(
                context: context,
                feedbackService: feedbackService,
              ),
              child: Text('Show Rating'),
            ),
          ),
        ),
      );

      await tester.pumpWidget(testWidget);
      await tester.tap(find.text('Show Rating'));
      await tester.pumpAndSettle();

      expect(find.text('Enjoying the app?'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsWidgets);
    });

    testWidgets('Feedback screen displays correctly', (tester) async {
      final widget = MaterialApp(
        home: FeedbackScreen(feedbackService: feedbackService),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      expect(find.text('Feedback'), findsOneWidget);
      expect(find.text('Feedback Overview'), findsOneWidget);
      expect(find.text('Quick Actions'), findsOneWidget);
    });

    test('Feedback service submits feedback correctly', () async {
      final feedbackId = await feedbackService.submitFeedback(
        type: FeedbackType.general,
        subject: 'Test Feedback',
        message: 'This is a test feedback message',
        tags: ['test', 'integration'],
      );

      expect(feedbackId, isNotNull);
      expect(feedbackId, isA<String>());

      final allFeedback = await feedbackService.getAllFeedback();
      expect(allFeedback, hasLength(1));
      expect(allFeedback.first.subject, equals('Test Feedback'));
      expect(allFeedback.first.type, equals(FeedbackType.general));
    });

    test('Rating prompt timing works correctly', () async {
      // Initially should not show (low launch count)
      bool shouldShow = await feedbackService.shouldShowRatingPrompt();
      expect(shouldShow, isFalse);

      // Set high launch count
      await prefs.setInt('app_launch_count', 15);
      shouldShow = await feedbackService.shouldShowRatingPrompt();
      expect(shouldShow, isTrue);

      // After rating, should not show again
      await prefs.setBool('has_rated_app', true);
      shouldShow = await feedbackService.shouldShowRatingPrompt();
      expect(shouldShow, isFalse);
    });

    test('Feedback analytics calculates correctly', () async {
      // Submit various types of feedback
      await feedbackService.submitFeedback(
        type: FeedbackType.rating,
        rating: 5,
        subject: 'Rating',
        message: 'Great app!',
      );

      await feedbackService.submitFeedback(
        type: FeedbackType.bugReport,
        subject: 'Bug Report',
        message: 'Found a bug',
        tags: ['bug', 'ui'],
      );

      await feedbackService.submitFeedback(
        type: FeedbackType.featureRequest,
        subject: 'Feature Request',
        message: 'Need this feature',
        tags: ['feature'],
      );

      final analytics = await feedbackService.getFeedbackAnalytics();

      expect(analytics.totalFeedback, equals(3));
      expect(analytics.totalRatings, equals(1));
      expect(analytics.averageRating, equals(5.0));
      expect(analytics.bugReports, equals(1));
      expect(analytics.featureRequests, equals(1));
      expect(analytics.tagFrequency['bug'], equals(1));
      expect(analytics.tagFrequency['ui'], equals(1));
      expect(analytics.tagFrequency['feature'], equals(1));
    });

    test('FeedbackServiceProvider singleton pattern works', () async {
      final provider1 = FeedbackServiceProvider.instance;
      final provider2 = FeedbackServiceProvider.instance;

      expect(provider1, same(provider2));

      await provider1.initialize();
      expect(provider1.isInitialized, isTrue);
      expect(provider1.feedbackService, isNotNull);
    });

    group('Feedback UI Components', () {
      testWidgets('Rating dialog handles user interaction', (tester) async {
        final testWidget = MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (context) =>
                      RatingDialog(feedbackService: feedbackService),
                ),
                child: Text('Show Dialog'),
              ),
            ),
          ),
        );

        await tester.pumpWidget(testWidget);
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Test star rating interaction
        final stars = find.byIcon(Icons.star);
        expect(stars, findsNWidgets(5));

        // Tap the 4th star (4-star rating)
        await tester.tap(stars.at(3));
        await tester.pump();

        // Submit rating button should be enabled
        final submitButton = find.text('Submit Rating');
        expect(submitButton, findsOneWidget);
      });

      testWidgets('Feedback screen quick actions work', (tester) async {
        final widget = MaterialApp(
          home: FeedbackScreen(feedbackService: feedbackService),
        );

        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        // Test quick action buttons
        expect(find.text('Rate App'), findsOneWidget);
        expect(find.text('Report Bug'), findsOneWidget);
        expect(find.text('Feature Request'), findsOneWidget);
        expect(find.text('General Feedback'), findsOneWidget);

        // Tap on bug report button
        await tester.tap(find.text('Report Bug'));
        await tester.pumpAndSettle();

        // Should navigate to feedback form
        expect(find.text('Send Feedback'), findsOneWidget);
      });
    });

    group('Error Handling', () {
      test('Feedback service handles invalid data gracefully', () async {
        expect(
          () => feedbackService.submitFeedback(
            type: FeedbackType.general,
            subject: '', // Empty subject should be handled gracefully
            message: '',
          ),
          throwsA(isA<Exception>()),
        );
      });

      testWidgets('UI handles service failures gracefully', (tester) async {
        // Create a feedback service that will fail
        final failingService = FeedbackService(
          databaseHelper: DatabaseHelper(),
          prefs: prefs,
        );

        final widget = MaterialApp(
          home: FeedbackScreen(feedbackService: failingService),
        );

        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        // Should still render the screen without crashing
        expect(find.text('Feedback'), findsOneWidget);
      });
    });
  });
}
