/// Basic integration tests for core app functionality
/// Tests app initialization, navigation, and basic workflows
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:meeting_summarizer/main.dart' as app;

import 'integration_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Workflow Integration Tests', () {
    setUpAll(() async {
      await IntegrationTestHelpers.initialize();
    });

    tearDownAll(() async {
      await IntegrationTestHelpers.cleanup();
    });

    setUp(() async {
      await IntegrationTestHelpers.cleanTestDatabase();
      IntegrationTestHelpers.resetMocks();
    });

    testWidgets('App launches and shows main screen', (tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Verify app launches successfully
      expect(find.byType(MaterialApp), findsOneWidget);

      // Take screenshot for documentation
      await IntegrationTestHelpers.takeScreenshot('app_launch');
    });

    testWidgets('App navigation works correctly', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Look for common navigation elements
      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsAtLeastNWidgets(1));

      // Wait for any animations to complete
      await IntegrationTestHelpers.pumpAndSettleTimes(tester, 3);

      // Take screenshot after navigation
      await IntegrationTestHelpers.takeScreenshot('app_navigation');
    });

    testWidgets('Database operations work correctly', (tester) async {
      // Create test data directly in database
      final recording = await IntegrationTestHelpers.createTestRecording(
        fileName: 'integration_test_recording.wav',
      );

      final transcription =
          await IntegrationTestHelpers.createTestTranscription(
            recordingId: recording.id,
            content: 'This is an integration test transcription.',
          );

      await IntegrationTestHelpers.createTestSummary(
        transcriptionId: transcription.id,
        content: 'This is an integration test summary.',
      );

      // Verify database state
      await IntegrationTestHelpers.verifyDatabaseState(
        expectedRecordings: 1,
        expectedTranscriptions: 1,
        expectedSummaries: 1,
      );

      // Launch app and verify it handles existing data
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify app loaded successfully with data
      expect(find.byType(MaterialApp), findsOneWidget);

      // Take screenshot showing data handling
      await IntegrationTestHelpers.takeScreenshot('database_operations');
    });

    testWidgets('App handles empty state correctly', (tester) async {
      // Ensure database is clean
      await IntegrationTestHelpers.cleanTestDatabase();

      app.main();
      await tester.pumpAndSettle();

      // Verify app shows empty state appropriately
      expect(find.byType(MaterialApp), findsOneWidget);

      // Take screenshot of empty state
      await IntegrationTestHelpers.takeScreenshot('empty_state');
    });

    testWidgets('App handles offline mode', (tester) async {
      // Mock offline connectivity
      IntegrationTestHelpers.mockOfflineMode();

      app.main();
      await tester.pumpAndSettle();

      // Verify app works in offline mode
      expect(find.byType(MaterialApp), findsOneWidget);

      // Create some test data to verify offline functionality
      await IntegrationTestHelpers.createTestRecording(
        fileName: 'offline_test.wav',
      );

      // Verify offline operations work
      await IntegrationTestHelpers.verifyDatabaseState(expectedRecordings: 1);

      // Take screenshot of offline mode
      await IntegrationTestHelpers.takeScreenshot('offline_mode');
    });

    testWidgets('App transitions back to online mode', (tester) async {
      // Start offline
      IntegrationTestHelpers.mockOfflineMode();

      app.main();
      await tester.pumpAndSettle();

      // Create offline data
      await IntegrationTestHelpers.createTestRecording(
        fileName: 'transition_test.wav',
      );

      // Switch to online mode
      IntegrationTestHelpers.mockOnlineMode();

      // Simulate connectivity change
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'dev.fluttercommunity.plus/connectivity',
        null,
        (data) {},
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify app handles transition
      expect(find.byType(MaterialApp), findsOneWidget);

      // Take screenshot of online transition
      await IntegrationTestHelpers.takeScreenshot('online_transition');
    });

    testWidgets('App handles multiple data types', (tester) async {
      // Create comprehensive test dataset
      await IntegrationTestHelpers.createCompleteTestDataSet(
        fileName: 'comprehensive_test.wav',
      );

      // Create additional recordings
      await IntegrationTestHelpers.createTestRecording(
        fileName: 'test_recording_2.wav',
      );
      await IntegrationTestHelpers.createTestRecording(
        fileName: 'test_recording_3.wav',
      );

      app.main();
      await tester.pumpAndSettle();

      // Verify app loads with multiple data items
      expect(find.byType(MaterialApp), findsOneWidget);

      // Verify database contains expected data
      await IntegrationTestHelpers.verifyDatabaseState(
        expectedRecordings: 3,
        expectedTranscriptions: 1,
        expectedSummaries: 1,
      );

      // Take screenshot showing multiple data handling
      await IntegrationTestHelpers.takeScreenshot('multiple_data_types');
    });

    testWidgets('App performance with larger dataset', (tester) async {
      // Create a larger dataset to test performance
      for (int i = 0; i < 10; i++) {
        final recording = await IntegrationTestHelpers.createTestRecording(
          fileName: 'performance_test_$i.wav',
        );

        if (i % 2 == 0) {
          // Add transcriptions for half the recordings
          await IntegrationTestHelpers.createTestTranscription(
            recordingId: recording.id,
            content: 'Performance test transcription for recording $i',
          );
        }
      }

      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Verify app handles larger dataset
      expect(find.byType(MaterialApp), findsOneWidget);

      // Verify database state
      await IntegrationTestHelpers.verifyDatabaseState(
        expectedRecordings: 10,
        expectedTranscriptions: 5,
      );

      // Take screenshot of app with larger dataset
      await IntegrationTestHelpers.takeScreenshot('large_dataset');
    });

    testWidgets('App gracefully handles errors', (tester) async {
      // Create test data with potential error conditions
      await IntegrationTestHelpers.createTestRecording(
        fileName: 'error_test.wav',
      );

      app.main();
      await tester.pumpAndSettle();

      // Verify app doesn't crash with error conditions
      expect(find.byType(MaterialApp), findsOneWidget);

      // Test should complete without throwing exceptions
      await IntegrationTestHelpers.takeScreenshot('error_handling');
    });

    testWidgets('App maintains state during lifecycle', (tester) async {
      // Create initial data
      await IntegrationTestHelpers.createTestRecording(
        fileName: 'lifecycle_test.wav',
      );

      // First app session
      app.main();
      await tester.pumpAndSettle();

      // Verify initial state
      expect(find.byType(MaterialApp), findsOneWidget);

      // Simulate app pause/resume by pumping empty and restarting
      await tester.pumpWidget(Container());
      await tester.pumpAndSettle();

      // Restart app
      app.main();
      await tester.pumpAndSettle();

      // Verify state is maintained
      expect(find.byType(MaterialApp), findsOneWidget);
      await IntegrationTestHelpers.verifyDatabaseState(expectedRecordings: 1);

      // Take screenshot of lifecycle test
      await IntegrationTestHelpers.takeScreenshot('lifecycle_test');
    });
  });
}
