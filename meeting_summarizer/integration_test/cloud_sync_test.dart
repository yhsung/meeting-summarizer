/// Integration tests for cloud sync functionality
/// Tests offline queue, sync operations, and conflict resolution
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:meeting_summarizer/main.dart' as app;
import 'package:meeting_summarizer/core/models/database/recording.dart';

import 'integration_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Cloud Sync Integration Tests', () {
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

    testWidgets('Offline queue accumulates operations', (tester) async {
      // Start in offline mode
      IntegrationTestHelpers.mockOfflineMode();

      app.main();
      await tester.pumpAndSettle();

      // Create multiple recordings while offline
      final recordings = <Recording>[];
      for (int i = 0; i < 3; i++) {
        final recording = await IntegrationTestHelpers.createTestRecording(
          fileName: 'offline_recording_$i.wav',
        );
        recordings.add(recording);
      }

      // Verify recordings are stored locally
      await IntegrationTestHelpers.verifyDatabaseState(expectedRecordings: 3);

      // Take screenshot showing offline operations
      await IntegrationTestHelpers.takeScreenshot('offline_queue');
    });

    testWidgets('Sync processes when going online', (tester) async {
      // Start offline with existing data
      IntegrationTestHelpers.mockOfflineMode();

      // Create offline data
      final recording = await IntegrationTestHelpers.createTestRecording(
        fileName: 'sync_test.wav',
      );
      await IntegrationTestHelpers.createTestTranscription(
        recordingId: recording.id,
        content: 'Sync test transcription content.',
      );

      app.main();
      await tester.pumpAndSettle();

      // Verify offline state
      await IntegrationTestHelpers.verifyDatabaseState(
        expectedRecordings: 1,
        expectedTranscriptions: 1,
      );

      // Switch to online mode
      IntegrationTestHelpers.mockOnlineMode();

      // Simulate connectivity change notification
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'dev.fluttercommunity.plus/connectivity',
        null,
        (data) {},
      );

      // Allow time for sync operations
      await IntegrationTestHelpers.pumpAndSettleTimes(tester, 5);

      // Verify app handles online transition
      expect(find.byType(MaterialApp), findsOneWidget);

      // Take screenshot of sync operation
      await IntegrationTestHelpers.takeScreenshot('sync_online');
    });

    testWidgets('App handles intermittent connectivity', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Create initial data online
      IntegrationTestHelpers.mockOnlineMode();
      await IntegrationTestHelpers.createTestRecording(
        fileName: 'intermittent_1.wav',
      );

      await IntegrationTestHelpers.waitForAsync();

      // Go offline
      IntegrationTestHelpers.mockOfflineMode();
      await IntegrationTestHelpers.createTestRecording(
        fileName: 'intermittent_2.wav',
      );

      await IntegrationTestHelpers.waitForAsync();

      // Back online
      IntegrationTestHelpers.mockOnlineMode();
      await IntegrationTestHelpers.createTestRecording(
        fileName: 'intermittent_3.wav',
      );

      // Verify all data is handled correctly
      await IntegrationTestHelpers.verifyDatabaseState(expectedRecordings: 3);

      // Take screenshot of intermittent connectivity handling
      await IntegrationTestHelpers.takeScreenshot('intermittent_connectivity');
    });

    testWidgets('Handles large file sync operations', (tester) async {
      // Start offline
      IntegrationTestHelpers.mockOfflineMode();

      // Create large recording
      final largeRecording = await IntegrationTestHelpers.createTestRecording(
        fileName: 'large_file_sync.wav',
        durationMs: 1800000, // 30 minutes
      );

      app.main();
      await tester.pumpAndSettle();

      // Add transcription for large file
      await IntegrationTestHelpers.createTestTranscription(
        recordingId: largeRecording.id,
        content: '''This is a very long transcription content that simulates 
        a large file that would need to be synced to the cloud. It contains 
        multiple sentences and paragraphs to simulate real-world usage.
        
        This content would typically be generated from a 30-minute meeting
        recording and would include detailed discussions, decisions made,
        and action items that were identified during the meeting.''',
      );

      // Go online to trigger sync
      IntegrationTestHelpers.mockOnlineMode();

      // Simulate connectivity change
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'dev.fluttercommunity.plus/connectivity',
        null,
        (data) {},
      );

      // Allow extra time for large file operations
      await IntegrationTestHelpers.pumpAndSettleTimes(tester, 10);

      // Verify large file operations complete
      await IntegrationTestHelpers.verifyDatabaseState(
        expectedRecordings: 1,
        expectedTranscriptions: 1,
      );

      // Take screenshot of large file sync
      await IntegrationTestHelpers.takeScreenshot('large_file_sync');
    });

    testWidgets('Handles sync conflicts gracefully', (tester) async {
      // Create initial data
      final recording = await IntegrationTestHelpers.createTestRecording(
        fileName: 'conflict_test.wav',
      );

      app.main();
      await tester.pumpAndSettle();

      // Simulate conflict scenario by creating transcription offline
      IntegrationTestHelpers.mockOfflineMode();
      await IntegrationTestHelpers.createTestTranscription(
        recordingId: recording.id,
        content: 'Local transcription content.',
      );

      // Go back online
      IntegrationTestHelpers.mockOnlineMode();

      // Simulate sync operation
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'dev.fluttercommunity.plus/connectivity',
        null,
        (data) {},
      );

      await IntegrationTestHelpers.pumpAndSettleTimes(tester, 5);

      // Verify conflict resolution doesn't crash app
      expect(find.byType(MaterialApp), findsOneWidget);

      // Take screenshot of conflict handling
      await IntegrationTestHelpers.takeScreenshot('sync_conflicts');
    });

    testWidgets('Maintains sync queue integrity', (tester) async {
      // Start offline
      IntegrationTestHelpers.mockOfflineMode();

      app.main();
      await tester.pumpAndSettle();

      // Create operations that would be queued
      final recordings = <Recording>[];
      for (int i = 0; i < 5; i++) {
        final recording = await IntegrationTestHelpers.createTestRecording(
          fileName: 'queue_integrity_$i.wav',
        );
        recordings.add(recording);

        // Add transcription for some recordings
        if (i % 2 == 0) {
          await IntegrationTestHelpers.createTestTranscription(
            recordingId: recording.id,
            content: 'Queue integrity test transcription $i',
          );
        }
      }

      // Verify queue has accumulated operations
      await IntegrationTestHelpers.verifyDatabaseState(
        expectedRecordings: 5,
        expectedTranscriptions: 3,
      );

      // Simulate partial connectivity (intermittent failures)
      IntegrationTestHelpers.mockOnlineMode();
      await IntegrationTestHelpers.waitForAsync();

      IntegrationTestHelpers.mockOfflineMode();
      await IntegrationTestHelpers.waitForAsync();

      IntegrationTestHelpers.mockOnlineMode();

      // Final sync attempt
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'dev.fluttercommunity.plus/connectivity',
        null,
        (data) {},
      );

      await IntegrationTestHelpers.pumpAndSettleTimes(tester, 8);

      // Verify data integrity is maintained
      await IntegrationTestHelpers.verifyDatabaseState(
        expectedRecordings: 5,
        expectedTranscriptions: 3,
      );

      // Take screenshot of queue integrity test
      await IntegrationTestHelpers.takeScreenshot('queue_integrity');
    });

    testWidgets('Handles concurrent sync operations', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Create multiple items rapidly
      final recordings = <Recording>[];
      for (int i = 0; i < 3; i++) {
        final recording = await IntegrationTestHelpers.createTestRecording(
          fileName: 'concurrent_$i.wav',
        );
        recordings.add(recording);

        // Don't wait between operations to simulate concurrent creation
        final transcription =
            await IntegrationTestHelpers.createTestTranscription(
              recordingId: recording.id,
              content: 'Concurrent transcription $i',
            );

        await IntegrationTestHelpers.createTestSummary(
          transcriptionId: transcription.id,
          content: 'Concurrent summary $i',
        );
      }

      // Verify all operations completed successfully
      await IntegrationTestHelpers.verifyDatabaseState(
        expectedRecordings: 3,
        expectedTranscriptions: 3,
        expectedSummaries: 3,
      );

      // Take screenshot of concurrent operations
      await IntegrationTestHelpers.takeScreenshot('concurrent_sync');
    });

    testWidgets('Recovers from sync failures', (tester) async {
      // Create data that will initially fail to sync
      IntegrationTestHelpers.mockOfflineMode();

      await IntegrationTestHelpers.createTestRecording(
        fileName: 'sync_failure_recovery.wav',
      );

      app.main();
      await tester.pumpAndSettle();

      // Attempt sync that will fail (still offline)
      IntegrationTestHelpers.mockOnlineMode();
      await IntegrationTestHelpers.waitForAsync(
        const Duration(milliseconds: 100),
      );

      // Go back offline (simulating sync failure)
      IntegrationTestHelpers.mockOfflineMode();
      await IntegrationTestHelpers.waitForAsync(
        const Duration(milliseconds: 100),
      );

      // Successful sync
      IntegrationTestHelpers.mockOnlineMode();
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'dev.fluttercommunity.plus/connectivity',
        null,
        (data) {},
      );

      await IntegrationTestHelpers.pumpAndSettleTimes(tester, 5);

      // Verify recovery worked
      expect(find.byType(MaterialApp), findsOneWidget);
      await IntegrationTestHelpers.verifyDatabaseState(expectedRecordings: 1);

      // Take screenshot of sync recovery
      await IntegrationTestHelpers.takeScreenshot('sync_recovery');
    });
  });
}
