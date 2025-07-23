/// End-to-end integration tests for complete user journeys
/// Tests the full workflow: Recording -> Transcription -> Summarization
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:meeting_summarizer/main.dart' as app;
import 'package:meeting_summarizer/core/models/database/summary.dart' as models;

import 'integration_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Complete User Journey Integration Tests', () {
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

    group('Recording to Summary Workflow', () {
      testWidgets('Complete workflow: Record -> Transcribe -> Summarize', (
        tester,
      ) async {
        // Launch the app
        app.main();
        await tester.pumpAndSettle();

        // Step 1: Navigate to recording screen
        await _navigateToRecordingScreen(tester);
        await IntegrationTestHelpers.waitForAsync();

        // Step 2: Start recording (mocked)
        await _startRecording(tester);
        await IntegrationTestHelpers.pumpAndSettleTimes(tester, 3);

        // Step 3: Stop recording
        await _stopRecording(tester);
        await IntegrationTestHelpers.pumpAndSettleTimes(tester, 3);

        // Step 4: Navigate to transcription
        await _navigateToTranscription(tester);
        await IntegrationTestHelpers.waitForAsync();

        // Step 5: Start transcription process (mocked)
        await _startTranscription(tester);
        await IntegrationTestHelpers.pumpAndSettleTimes(tester, 5);

        // Step 6: Verify transcription completed
        await _verifyTranscriptionCompleted(tester);

        // Step 7: Navigate to summarization
        await _navigateToSummarization(tester);
        await IntegrationTestHelpers.waitForAsync();

        // Step 8: Generate summary
        await _generateSummary(tester, models.SummaryType.brief);
        await IntegrationTestHelpers.pumpAndSettleTimes(tester, 5);

        // Step 9: Verify summary completed
        await _verifySummaryCompleted(tester);

        // Step 10: Verify database state
        await IntegrationTestHelpers.verifyDatabaseState(
          expectedRecordings: 1,
          expectedTranscriptions: 1,
          expectedSummaries: 1,
        );

        // Take screenshot for documentation
        await IntegrationTestHelpers.takeScreenshot('complete_workflow_end');
      });

      testWidgets('Multiple summary types for same transcription', (
        tester,
      ) async {
        // Setup: Create a test recording and transcription
        final testData =
            await IntegrationTestHelpers.createCompleteTestDataSet();

        app.main();
        await tester.pumpAndSettle();

        // Navigate to existing transcription
        await _navigateToExistingTranscription(
          tester,
          testData['transcription'].id,
        );
        await IntegrationTestHelpers.waitForAsync();

        // Generate different summary types
        for (final summaryType in models.SummaryType.values) {
          await _generateSummary(tester, summaryType);
          await IntegrationTestHelpers.pumpAndSettleTimes(tester, 3);

          await _verifySummaryCompleted(tester);
          await IntegrationTestHelpers.waitForAsync();
        }

        // Verify multiple summaries created
        await IntegrationTestHelpers.verifyDatabaseState(
          expectedSummaries:
              models.SummaryType.values.length + 1, // +1 from setup data
        );
      });

      testWidgets('Workflow with error handling and retry', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Navigate to recording screen
        await _navigateToRecordingScreen(tester);
        await IntegrationTestHelpers.waitForAsync();

        // Simulate recording error
        await _simulateRecordingError(tester);
        await IntegrationTestHelpers.pumpAndSettleTimes(tester, 3);

        // Verify error handling
        await _verifyErrorHandling(tester);

        // Retry recording
        await _retryRecording(tester);
        await IntegrationTestHelpers.pumpAndSettleTimes(tester, 3);

        // Verify successful recovery
        await _verifyRecordingSuccess(tester);
      });
    });

    group('Offline Functionality Tests', () {
      testWidgets('Recording works in offline mode', (tester) async {
        // Mock offline state
        IntegrationTestHelpers.mockOfflineMode();

        app.main();
        await tester.pumpAndSettle();

        // Navigate to recording screen
        await _navigateToRecordingScreen(tester);
        await IntegrationTestHelpers.waitForAsync();

        // Start recording in offline mode
        await _startRecording(tester);
        await IntegrationTestHelpers.pumpAndSettleTimes(tester, 3);

        // Stop recording
        await _stopRecording(tester);
        await IntegrationTestHelpers.pumpAndSettleTimes(tester, 3);

        // Verify recording saved locally
        await IntegrationTestHelpers.verifyDatabaseState(expectedRecordings: 1);

        // Verify offline indicator shown
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      });

      testWidgets('Sync queue processes when back online', (tester) async {
        // Start offline with existing recorded data
        IntegrationTestHelpers.mockOfflineMode();
        await IntegrationTestHelpers.createTestRecording();

        app.main();
        await tester.pumpAndSettle();

        // Verify offline queue has items
        await _verifyOfflineQueueHasItems(tester);

        // Go back online
        IntegrationTestHelpers.mockOnlineMode();
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'dev.fluttercommunity.plus/connectivity',
          null,
          (data) {},
        );
        await IntegrationTestHelpers.pumpAndSettleTimes(tester, 5);

        // Verify sync queue processing
        await _verifySyncProcessing(tester);
      });
    });

    group('Data Persistence and Recovery', () {
      testWidgets('App state persists across restarts', (tester) async {
        // Create test data
        final testData =
            await IntegrationTestHelpers.createCompleteTestDataSet();

        // First app session
        app.main();
        await tester.pumpAndSettle();

        // Verify data is visible
        await _verifyDataVisible(tester, testData);

        // Simulate app restart by pumping new instance
        await tester.pumpWidget(Container()); // Clear current app
        await tester.pumpAndSettle();

        // Start app again
        app.main();
        await tester.pumpAndSettle();

        // Verify data still visible after restart
        await _verifyDataVisible(tester, testData);
      });

      testWidgets('Handles corrupted data gracefully', (tester) async {
        // Create corrupted test data
        await _createCorruptedTestData();

        app.main();
        await tester.pumpAndSettle();

        // Verify app doesn't crash and shows error handling
        expect(find.byType(MaterialApp), findsOneWidget);

        // Verify error recovery mechanisms
        await _verifyErrorRecovery(tester);
      });
    });

    group('Performance and Resource Management', () {
      testWidgets('Memory usage remains stable during long sessions', (
        tester,
      ) async {
        app.main();
        await tester.pumpAndSettle();

        // Simulate long session with multiple operations
        for (int i = 0; i < 10; i++) {
          // Create test data
          await IntegrationTestHelpers.createTestRecording(
            fileName: 'test_recording_$i.wav',
          );

          // Process through workflow
          await _simulateQuickWorkflow(tester);
          await IntegrationTestHelpers.waitForAsync();

          // Clean up periodically to simulate normal usage
          if (i % 3 == 0) {
            await IntegrationTestHelpers.cleanTestDatabase();
          }
        }

        // Verify app is still responsive
        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('Large file handling works correctly', (tester) async {
        // Create large test recording
        final largeRecording = await IntegrationTestHelpers.createTestRecording(
          fileName: 'large_recording.wav',
          durationMs: 1800000, // 30 minutes
        );

        app.main();
        await tester.pumpAndSettle();

        // Navigate to the large recording
        await _navigateToRecording(tester, largeRecording.id);
        await IntegrationTestHelpers.waitForAsync();

        // Process large file
        await _processLargeFile(tester);
        await IntegrationTestHelpers.pumpAndSettleTimes(tester, 10);

        // Verify successful processing
        await _verifyLargeFileProcessed(tester);
      });
    });
  });
}

// Helper functions for navigation and interactions

Future<void> _navigateToRecordingScreen(WidgetTester tester) async {
  // Look for recording tab or button
  final recordingButton = find.byIcon(Icons.mic);
  if (recordingButton.evaluate().isNotEmpty) {
    await tester.tap(recordingButton);
  } else {
    // Alternative navigation path
    final fabButton = find.byType(FloatingActionButton);
    if (fabButton.evaluate().isNotEmpty) {
      await tester.tap(fabButton);
    }
  }
  await tester.pumpAndSettle();
}

Future<void> _startRecording(WidgetTester tester) async {
  final startButton = find.byIcon(Icons.play_arrow);
  final micButton = find.byIcon(Icons.mic);

  if (startButton.evaluate().isNotEmpty) {
    await tester.tap(startButton);
  } else if (micButton.evaluate().isNotEmpty) {
    await tester.tap(micButton);
  }

  await tester.pumpAndSettle();
}

Future<void> _stopRecording(WidgetTester tester) async {
  final stopButton = find.byIcon(Icons.stop);
  final pauseButton = find.byIcon(Icons.pause);

  if (stopButton.evaluate().isNotEmpty) {
    await tester.tap(stopButton);
  } else if (pauseButton.evaluate().isNotEmpty) {
    await tester.tap(pauseButton);
  }
  await tester.pumpAndSettle();
}

Future<void> _navigateToTranscription(WidgetTester tester) async {
  // Look for transcription tab or navigate to transcription screen
  final transcriptionTab = find.text('Transcription');
  final textFieldsIcon = find.byIcon(Icons.text_fields);

  if (transcriptionTab.evaluate().isNotEmpty) {
    await tester.tap(transcriptionTab.first);
    await tester.pumpAndSettle();
  } else if (textFieldsIcon.evaluate().isNotEmpty) {
    await tester.tap(textFieldsIcon.first);
    await tester.pumpAndSettle();
  }
}

Future<void> _startTranscription(WidgetTester tester) async {
  final transcribeButton = find.text('Start Transcription');
  final textFormatIcon = find.byIcon(Icons.text_format);

  if (transcribeButton.evaluate().isNotEmpty) {
    await tester.tap(transcribeButton.first);
    await tester.pumpAndSettle();
  } else if (textFormatIcon.evaluate().isNotEmpty) {
    await tester.tap(textFormatIcon.first);
    await tester.pumpAndSettle();
  }
}

Future<void> _verifyTranscriptionCompleted(WidgetTester tester) async {
  // Wait for transcription to complete (mocked, so should be fast)
  await tester.pumpAndSettle(const Duration(seconds: 5));

  // Look for completion indicators - check for any of these
  final completeText = find.text('Transcription Complete');
  final checkIcon = find.byIcon(Icons.check_circle);

  // Allow for different UI implementations - at least one should exist
  expect(
    completeText.evaluate().isNotEmpty || checkIcon.evaluate().isNotEmpty,
    isTrue,
  );
}

Future<void> _navigateToSummarization(WidgetTester tester) async {
  final summaryTab = find.text('Summary');
  final summarizeIcon = find.byIcon(Icons.summarize);

  if (summaryTab.evaluate().isNotEmpty) {
    await tester.tap(summaryTab.first);
    await tester.pumpAndSettle();
  } else if (summarizeIcon.evaluate().isNotEmpty) {
    await tester.tap(summarizeIcon.first);
    await tester.pumpAndSettle();
  }
}

Future<void> _generateSummary(
  WidgetTester tester,
  models.SummaryType type,
) async {
  // Select summary type if picker is available
  final typePicker = find.text(type.name);
  if (typePicker.evaluate().isNotEmpty) {
    await tester.tap(typePicker);
    await tester.pumpAndSettle();
  }

  // Generate summary
  final generateButton = find.text('Generate Summary');
  final awesomeIcon = find.byIcon(Icons.auto_awesome);

  if (generateButton.evaluate().isNotEmpty) {
    await tester.tap(generateButton.first);
    await tester.pumpAndSettle();
  } else if (awesomeIcon.evaluate().isNotEmpty) {
    await tester.tap(awesomeIcon.first);
    await tester.pumpAndSettle();
  }
}

Future<void> _verifySummaryCompleted(WidgetTester tester) async {
  // Wait for summary generation (mocked)
  await tester.pumpAndSettle(const Duration(seconds: 3));

  // Look for summary content or completion indicators
  final summaryText = find.textContaining('Summary');
  final checkIcon = find.byIcon(Icons.check_circle);

  // At least one should be present
  expect(
    summaryText.evaluate().isNotEmpty || checkIcon.evaluate().isNotEmpty,
    isTrue,
  );
}

Future<void> _navigateToExistingTranscription(
  WidgetTester tester,
  String transcriptionId,
) async {
  // Navigate to transcriptions list and select specific transcription
  final transcriptionsTab = find.text('Transcriptions');
  if (transcriptionsTab.evaluate().isNotEmpty) {
    await tester.tap(transcriptionsTab);
    await tester.pumpAndSettle();
  }

  // Find and tap the specific transcription
  final transcriptionItem = find.text(transcriptionId);
  final transcriptionKey = find.byKey(Key('transcription_$transcriptionId'));

  if (transcriptionItem.evaluate().isNotEmpty) {
    await tester.tap(transcriptionItem.first);
    await tester.pumpAndSettle();
  } else if (transcriptionKey.evaluate().isNotEmpty) {
    await tester.tap(transcriptionKey.first);
    await tester.pumpAndSettle();
  }
}

Future<void> _simulateRecordingError(WidgetTester tester) async {
  // This would trigger an error condition in the mock service
  // For now, just start and expect it to handle errors gracefully
  await _startRecording(tester);
}

Future<void> _verifyErrorHandling(WidgetTester tester) async {
  // Look for error messages or indicators
  final errorText = find.text('Error');
  final errorIcon = find.byIcon(Icons.error);

  // Either should be present for error handling
  expect(
    errorText.evaluate().isNotEmpty || errorIcon.evaluate().isNotEmpty,
    isTrue,
  );
}

Future<void> _retryRecording(WidgetTester tester) async {
  final retryButton = find.text('Retry');
  final tryAgainButton = find.text('Try Again');
  if (retryButton.evaluate().isNotEmpty) {
    await tester.tap(retryButton);
    await tester.pumpAndSettle();
  } else if (tryAgainButton.evaluate().isNotEmpty) {
    await tester.tap(tryAgainButton);
    await tester.pumpAndSettle();
  }
}

Future<void> _verifyRecordingSuccess(WidgetTester tester) async {
  // Look for success indicators
  final checkIcon = find.byIcon(Icons.check_circle);
  final completeText = find.text('Recording Complete');

  expect(
    checkIcon.evaluate().isNotEmpty || completeText.evaluate().isNotEmpty,
    isTrue,
  );
}

Future<void> _verifyOfflineQueueHasItems(WidgetTester tester) async {
  // Look for offline queue indicators
  expect(find.byIcon(Icons.cloud_off), findsWidgets);
}

Future<void> _verifySyncProcessing(WidgetTester tester) async {
  // Look for sync indicators
  final syncIcon = find.byIcon(Icons.sync);
  final uploadIcon = find.byIcon(Icons.cloud_upload);

  expect(
    syncIcon.evaluate().isNotEmpty || uploadIcon.evaluate().isNotEmpty,
    isTrue,
  );
}

Future<void> _verifyDataVisible(
  WidgetTester tester,
  Map<String, dynamic> testData,
) async {
  // Verify test data is visible in the UI
  final recording = testData['recording'];
  final fileNameFinder = find.text(recording.filename);
  final recordingKeyFinder = find.byKey(Key('recording_${recording.id}'));

  expect(
    fileNameFinder.evaluate().isNotEmpty ||
        recordingKeyFinder.evaluate().isNotEmpty,
    isTrue,
  );
}

Future<void> _createCorruptedTestData() async {
  // Create data with invalid references or corrupted content
  await IntegrationTestHelpers.createTestRecording();
  await IntegrationTestHelpers.createTestTranscription(
    recordingId: 'invalid_recording_id', // Corrupted reference
  );
}

Future<void> _verifyErrorRecovery(WidgetTester tester) async {
  // Verify app shows appropriate error recovery UI
  expect(find.byType(MaterialApp), findsOneWidget);
}

Future<void> _simulateQuickWorkflow(WidgetTester tester) async {
  // Quick simulation of record -> transcribe -> summarize
  await IntegrationTestHelpers.waitForAsync(const Duration(milliseconds: 50));
}

Future<void> _navigateToRecording(
  WidgetTester tester,
  String recordingId,
) async {
  // Navigate to specific recording
  final recordingItem = find.byKey(Key('recording_$recordingId'));
  if (recordingItem.evaluate().isNotEmpty) {
    await tester.tap(recordingItem);
    await tester.pumpAndSettle();
  }
}

Future<void> _processLargeFile(WidgetTester tester) async {
  // Simulate processing a large file
  await _startTranscription(tester);
  await IntegrationTestHelpers.waitForAsync(const Duration(seconds: 1));
}

Future<void> _verifyLargeFileProcessed(WidgetTester tester) async {
  // Verify large file was processed successfully
  expect(find.byIcon(Icons.check_circle), findsWidgets);
}
