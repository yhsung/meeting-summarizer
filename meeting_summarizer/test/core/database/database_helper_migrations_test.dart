import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:meeting_summarizer/core/database/database_helper.dart';
import 'package:meeting_summarizer/core/database/database_schema.dart';
import 'package:meeting_summarizer/core/models/database/recording.dart';
import 'package:meeting_summarizer/core/models/database/transcription.dart';
import 'package:meeting_summarizer/core/models/database/summary.dart';

void main() {
  group('DatabaseHelper Migration Integration Tests', () {
    late DatabaseHelper dbHelper;

    setUpAll(() {
      // Initialize sqflite for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Create a unique database for each test to enable parallel execution
      final testId = DateTime.now().microsecondsSinceEpoch;
      dbHelper = DatabaseHelper(
        customDatabaseName: 'test_migrations_$testId.db',
      );
      // Ensure we start with a clean database for each test
      await dbHelper.recreateDatabase();
    });

    tearDown(() async {
      await dbHelper.close();
    });

    group('Migration Management', () {
      test('should get current database version', () async {
        final version = await dbHelper.getDatabaseVersion();
        expect(version, equals(DatabaseSchema.databaseVersion));
      });

      test('should check if migration is needed', () async {
        final needsMigration = await dbHelper.needsMigration();
        // For a new database, no migration should be needed
        expect(needsMigration, isFalse);
      });

      test('should get migration information', () async {
        final migrationInfo = await dbHelper.getMigrationInfo();

        expect(migrationInfo, isA<Map<String, dynamic>>());
        expect(migrationInfo['currentVersion'], isA<int>());
        expect(migrationInfo['targetVersion'], isA<int>());
        expect(migrationInfo['needsMigration'], isA<bool>());
        expect(migrationInfo['isVersionSupported'], isA<bool>());

        // For a new database
        expect(
          migrationInfo['currentVersion'],
          equals(DatabaseSchema.databaseVersion),
        );
        expect(
          migrationInfo['targetVersion'],
          equals(DatabaseSchema.databaseVersion),
        );
        expect(migrationInfo['needsMigration'], isFalse);
        expect(migrationInfo['isVersionSupported'], isTrue);
      });

      test('should handle database recreation', () async {
        // Insert some test data
        final recordingId = DatabaseHelper.generateId();
        final recording = _createTestRecording(recordingId);
        await dbHelper.insertRecording(recording);

        // Verify data exists
        final retrievedRecording = await dbHelper.getRecording(recordingId);
        expect(retrievedRecording, isNotNull);

        // Recreate database
        await dbHelper.recreateDatabase();

        // Verify data is gone (new clean database)
        final retrievedAfterRecreation = await dbHelper.getRecording(
          recordingId,
        );
        expect(retrievedAfterRecreation, isNull);

        // Verify database is functional
        final stats = await dbHelper.getDatabaseStats();
        expect(stats['recordings'], equals(0));
      });
    });

    group('Migration Error Handling', () {
      test('should handle version compatibility checks', () async {
        // This test simulates checking version compatibility
        // In a real scenario, we would need to modify the database version
        final migrationInfo = await dbHelper.getMigrationInfo();

        expect(
          migrationInfo['minSupportedVersion'],
          equals(DatabaseSchema.minSupportedVersion),
        );
        expect(
          migrationInfo['maxSupportedVersion'],
          equals(DatabaseSchema.maxSupportedVersion),
        );
        expect(migrationInfo['isVersionSupported'], isTrue);
      });

      test('should maintain data integrity after operations', () async {
        // Insert test data
        final recordingId = DatabaseHelper.generateId();
        final transcriptionId = DatabaseHelper.generateId();
        final summaryId = DatabaseHelper.generateId();

        final recording = _createTestRecording(recordingId);
        await dbHelper.insertRecording(recording);

        final transcription = _createTestTranscription(
          transcriptionId,
          recordingId,
        );
        await dbHelper.insertTranscription(transcription);

        final summary = _createTestSummary(summaryId, transcriptionId);
        await dbHelper.insertSummary(summary);

        // Verify all data exists and relationships are intact
        final retrievedRecording = await dbHelper.getRecording(recordingId);
        final retrievedTranscriptions = await dbHelper
            .getTranscriptionsByRecording(recordingId);
        final retrievedSummaries = await dbHelper.getSummariesByTranscription(
          transcriptionId,
        );

        expect(retrievedRecording, isNotNull);
        expect(retrievedTranscriptions.length, equals(1));
        expect(retrievedSummaries.length, equals(1));

        // Test foreign key constraints
        expect(retrievedTranscriptions.first.recordingId, equals(recordingId));
        expect(
          retrievedSummaries.first.transcriptionId,
          equals(transcriptionId),
        );
      });

      test('should handle vacuum operation', () async {
        // Insert and delete some data to create fragmentation
        for (int i = 0; i < 10; i++) {
          final recordingId = DatabaseHelper.generateId();
          final recording = _createTestRecording(recordingId);
          await dbHelper.insertRecording(recording);

          if (i % 2 == 0) {
            await dbHelper.deleteRecording(recordingId);
          }
        }

        // Vacuum should complete without errors
        await dbHelper.vacuum();

        // Verify database is still functional
        final stats = await dbHelper.getDatabaseStats();
        expect(stats['recordings'], equals(5)); // 5 records should remain
      });
    });

    group('Database Statistics and Health', () {
      test('should provide accurate database statistics', () async {
        final initialStats = await dbHelper.getDatabaseStats();
        expect(initialStats['recordings'], equals(0));
        expect(initialStats['transcriptions'], equals(0));
        expect(initialStats['summaries'], equals(0));
        expect(
          initialStats['settings'],
          greaterThan(0),
        ); // Default settings should exist

        // Add some test data
        final recordingId = DatabaseHelper.generateId();
        final recording = _createTestRecording(recordingId);
        await dbHelper.insertRecording(recording);

        final transcriptionId = DatabaseHelper.generateId();
        final transcription = _createTestTranscription(
          transcriptionId,
          recordingId,
        );
        await dbHelper.insertTranscription(transcription);

        final updatedStats = await dbHelper.getDatabaseStats();
        expect(updatedStats['recordings'], equals(1));
        expect(updatedStats['transcriptions'], equals(1));
        expect(updatedStats['summaries'], equals(0));
      });

      test('should handle concurrent operations safely', () async {
        // Simulate concurrent inserts
        final futures = <Future>[];

        for (int i = 0; i < 5; i++) {
          futures.add(() async {
            final recordingId = DatabaseHelper.generateId();
            final recording = _createTestRecording(recordingId);
            await dbHelper.insertRecording(recording);
          }());
        }

        await Future.wait(futures);

        final stats = await dbHelper.getDatabaseStats();
        expect(stats['recordings'], equals(5));
      });
    });
  });
}

/// Helper function to create a test recording
Recording _createTestRecording(String id) {
  final now = DateTime.now();
  return Recording(
    id: id,
    filename: 'test_$id.wav',
    filePath: '/test/test_$id.wav',
    duration: 60000,
    fileSize: 1024000,
    format: 'wav',
    quality: 'high',
    sampleRate: 44100,
    bitDepth: 16,
    channels: 1,
    title: 'Test Recording $id',
    description: 'Test description for recording $id',
    tags: null,
    location: null,
    waveformData: null,
    createdAt: now,
    updatedAt: now,
    isDeleted: false,
    metadata: null,
  );
}

/// Helper function to create a test transcription
Transcription _createTestTranscription(String id, String recordingId) {
  final now = DateTime.now();
  return Transcription(
    id: id,
    recordingId: recordingId,
    text: 'Test transcription text for $id',
    confidence: 0.95,
    language: 'en',
    provider: 'test_provider',
    segments: null,
    status: TranscriptionStatus.completed,
    errorMessage: null,
    processingTime: 5000,
    wordCount: 6,
    createdAt: now,
    updatedAt: now,
  );
}

/// Helper function to create a test summary
Summary _createTestSummary(String id, String transcriptionId) {
  final now = DateTime.now();
  return Summary(
    id: id,
    transcriptionId: transcriptionId,
    content: 'Test summary content for $id',
    type: SummaryType.brief,
    provider: 'test_provider',
    model: 'test_model',
    prompt: null,
    confidence: 0.90,
    wordCount: 5,
    characterCount: 30,
    keyPoints: null,
    actionItems: null,
    sentiment: SentimentType.neutral,
    createdAt: now,
    updatedAt: now,
  );
}
