import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:meeting_summarizer/core/services/encrypted_database_service.dart';
import 'package:meeting_summarizer/core/models/database/recording.dart';
import 'package:meeting_summarizer/core/models/database/transcription.dart';
import 'package:meeting_summarizer/core/models/database/summary.dart' as models;
import 'package:meeting_summarizer/core/database/database_helper.dart';

void main() {
  group('EncryptedDatabaseService Tests', () {
    late EncryptedDatabaseService encryptedDbService;
    // Mock storage for testing
    final Map<String, String> mockStorage = {};

    setUpAll(() {
      // Initialize Flutter test framework
      TestWidgetsFlutterBinding.ensureInitialized();

      // Mock the secure storage since it won't work in tests
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
            (MethodCall methodCall) async {
              switch (methodCall.method) {
                case 'read':
                  final key = methodCall.arguments['key'] as String;
                  return mockStorage[key];
                case 'write':
                  final key = methodCall.arguments['key'] as String;
                  final value = methodCall.arguments['value'] as String;
                  mockStorage[key] = value;
                  return null;
                case 'delete':
                  final key = methodCall.arguments['key'] as String;
                  mockStorage.remove(key);
                  return null;
                case 'readAll':
                  return Map<String, String>.from(mockStorage);
                case 'deleteAll':
                  mockStorage.clear();
                  return null;
                default:
                  return null;
              }
            },
          );

      // Initialize sqflite for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Clear mock storage before each test
      mockStorage.clear();

      // Create a unique database for each test to enable parallel execution
      final testId = DateTime.now().microsecondsSinceEpoch;
      
      // Initialize the encrypted database service for each test
      await EncryptedDatabaseService.initialize(
        customDatabaseName: 'test_encrypted_$testId.db',
      );
      encryptedDbService = EncryptedDatabaseService();

      // Ensure we have a clean database for this test
      await encryptedDbService.databaseHelper.recreateDatabase();
    });

    tearDown(() async {
      await encryptedDbService.close();
    });

    group('Service Initialization', () {
      test('should initialize successfully', () async {
        expect(() => EncryptedDatabaseService.initialize(), returnsNormally);
        expect(EncryptedDatabaseService.isEncryptionEnabled, isA<bool>());
      });

      test('should get database helper instance', () {
        final dbHelper = encryptedDbService.databaseHelper;
        expect(dbHelper, isA<DatabaseHelper>());
      });
    });

    group('Encryption Settings', () {
      test('should enable and disable encryption', () async {
        // Test enabling encryption
        await EncryptedDatabaseService.setEncryptionEnabled(true);
        expect(EncryptedDatabaseService.isEncryptionEnabled, isTrue);

        // Test disabling encryption
        await EncryptedDatabaseService.setEncryptionEnabled(false);
        expect(EncryptedDatabaseService.isEncryptionEnabled, isFalse);
      });

      test('should persist encryption setting', () async {
        // Enable encryption - this writes to the database
        await EncryptedDatabaseService.setEncryptionEnabled(true);

        // Check if setting is stored in database
        // Use the same database helper instance that EncryptedDatabaseService uses
        final dbHelper = encryptedDbService.databaseHelper;
        final setting = await dbHelper.getSetting('encryption_enabled');
        expect(setting, equals('true'));

        // Disable encryption
        await EncryptedDatabaseService.setEncryptionEnabled(false);

        final disabledSetting = await dbHelper.getSetting('encryption_enabled');
        expect(disabledSetting, equals('false'));
      });
    });

    group('Recording Operations with Encryption', () {
      test('should insert and retrieve recording without encryption', () async {
        // Ensure encryption is disabled
        await EncryptedDatabaseService.setEncryptionEnabled(false);

        final recording = _createTestRecording('test-recording-1');

        // Insert recording
        final insertedId = await encryptedDbService.insertRecording(recording);
        expect(insertedId, equals(recording.id));

        // Retrieve recording
        final retrievedRecording = await encryptedDbService.getRecording(
          recording.id,
        );
        expect(retrievedRecording, isNotNull);
        expect(retrievedRecording!.id, equals(recording.id));
        expect(retrievedRecording.description, equals(recording.description));
        expect(retrievedRecording.tags, equals(recording.tags));
      });

      test(
        'should insert and retrieve recording with encryption enabled',
        () async {
          // Enable encryption
          await EncryptedDatabaseService.setEncryptionEnabled(true);

          final recording = _createTestRecording('test-recording-2');

          // Insert recording
          final insertedId = await encryptedDbService.insertRecording(
            recording,
          );
          expect(insertedId, equals(recording.id));

          // Retrieve recording (should be automatically decrypted)
          final retrievedRecording = await encryptedDbService.getRecording(
            recording.id,
          );
          expect(retrievedRecording, isNotNull);
          expect(retrievedRecording!.id, equals(recording.id));
          expect(retrievedRecording.description, equals(recording.description));
          expect(retrievedRecording.tags, equals(recording.tags));
          expect(retrievedRecording.location, equals(recording.location));
        },
      );

      test('should update recording with encryption', () async {
        await EncryptedDatabaseService.setEncryptionEnabled(true);

        final recording = _createTestRecording('test-recording-3');
        await encryptedDbService.insertRecording(recording);

        // Update recording with new sensitive data
        final updatedRecording = recording.copyWith(
          description: 'Updated sensitive description',
          tags: ['updated', 'sensitive', 'tags'],
          location: 'Updated secret location',
        );

        final updateResult = await encryptedDbService.updateRecording(
          updatedRecording,
        );
        expect(updateResult, isTrue);

        // Retrieve and verify update
        final retrievedRecording = await encryptedDbService.getRecording(
          recording.id,
        );
        expect(retrievedRecording, isNotNull);
        expect(
          retrievedRecording!.description,
          equals('Updated sensitive description'),
        );
        expect(
          retrievedRecording.tags,
          equals(['updated', 'sensitive', 'tags']),
        );
        expect(retrievedRecording.location, equals('Updated secret location'));
      });

      test('should get recordings list with encryption', () async {
        await EncryptedDatabaseService.setEncryptionEnabled(true);

        // Insert multiple recordings
        final recordings = [
          _createTestRecording('test-recording-4'),
          _createTestRecording('test-recording-5'),
          _createTestRecording('test-recording-6'),
        ];

        for (final recording in recordings) {
          await encryptedDbService.insertRecording(recording);
        }

        // Get all recordings
        final retrievedRecordings = await encryptedDbService.getRecordings();
        expect(retrievedRecordings.length, greaterThanOrEqualTo(3));

        // Verify recordings are properly decrypted
        for (final recording in recordings) {
          final found = retrievedRecordings.firstWhere(
            (r) => r.id == recording.id,
          );
          expect(found.description, equals(recording.description));
          expect(found.tags, equals(recording.tags));
        }
      });

      test('should delete recording', () async {
        final recording = _createTestRecording('test-recording-delete');
        await encryptedDbService.insertRecording(recording);

        // Verify recording exists
        final beforeDelete = await encryptedDbService.getRecording(
          recording.id,
        );
        expect(beforeDelete, isNotNull);

        // Delete recording
        final deleteResult = await encryptedDbService.deleteRecording(
          recording.id,
        );
        expect(deleteResult, isTrue);

        // Verify recording is soft deleted
        final afterDelete = await encryptedDbService.getRecording(recording.id);
        expect(afterDelete, isNull);
      });
    });

    group('Transcription Operations with Encryption', () {
      test(
        'should insert and retrieve transcription with encryption',
        () async {
          await EncryptedDatabaseService.setEncryptionEnabled(true);

          // First create a recording
          final recording = _createTestRecording(
            'test-recording-transcription',
          );
          await encryptedDbService.insertRecording(recording);

          final transcription = _createTestTranscription(
            'test-transcription-1',
            recording.id,
          );

          // Insert transcription
          final insertedId = await encryptedDbService.insertTranscription(
            transcription,
          );
          expect(insertedId, equals(transcription.id));

          // Retrieve transcription (should be automatically decrypted)
          final retrievedTranscription = await encryptedDbService
              .getTranscription(transcription.id);
          expect(retrievedTranscription, isNotNull);
          expect(retrievedTranscription!.id, equals(transcription.id));
          expect(retrievedTranscription.text, equals(transcription.text));
        },
      );

      test(
        'should get transcriptions by recording ID with encryption',
        () async {
          await EncryptedDatabaseService.setEncryptionEnabled(true);

          // Create recording
          final recording = _createTestRecording(
            'test-recording-transcriptions',
          );
          await encryptedDbService.insertRecording(recording);

          // Create multiple transcriptions
          final transcriptions = [
            _createTestTranscription('test-transcription-2', recording.id),
            _createTestTranscription('test-transcription-3', recording.id),
          ];

          for (final transcription in transcriptions) {
            await encryptedDbService.insertTranscription(transcription);
          }

          // Get transcriptions by recording ID
          final retrievedTranscriptions = await encryptedDbService
              .getTranscriptionsByRecording(recording.id);

          expect(retrievedTranscriptions.length, equals(2));

          // Verify transcriptions are properly decrypted
          for (final transcription in transcriptions) {
            final found = retrievedTranscriptions.firstWhere(
              (t) => t.id == transcription.id,
            );
            expect(found.text, equals(transcription.text));
          }
        },
      );

      test('should update transcription with encryption', () async {
        await EncryptedDatabaseService.setEncryptionEnabled(true);

        final recording = _createTestRecording(
          'test-recording-update-transcription',
        );
        await encryptedDbService.insertRecording(recording);

        final transcription = _createTestTranscription(
          'test-transcription-update',
          recording.id,
        );
        await encryptedDbService.insertTranscription(transcription);

        // Update transcription with new text
        final updatedTranscription = transcription.copyWith(
          text: 'This is the updated and encrypted transcription text',
        );

        final updateResult = await encryptedDbService.updateTranscription(
          updatedTranscription,
        );
        expect(updateResult, isTrue);

        // Retrieve and verify update
        final retrievedTranscription = await encryptedDbService
            .getTranscription(transcription.id);
        expect(retrievedTranscription, isNotNull);
        expect(
          retrievedTranscription!.text,
          equals('This is the updated and encrypted transcription text'),
        );
      });
    });

    group('Data Migration', () {
      test('should migrate existing data to encrypted format', () async {
        // Start with encryption disabled
        await EncryptedDatabaseService.setEncryptionEnabled(false);

        // Insert data without encryption
        final recording = _createTestRecording('test-migration-recording');
        await encryptedDbService.insertRecording(recording);

        final transcription = _createTestTranscription(
          'test-migration-transcription',
          recording.id,
        );
        await encryptedDbService.insertTranscription(transcription);

        // Enable encryption
        await EncryptedDatabaseService.setEncryptionEnabled(true);

        // Migrate existing data
        await encryptedDbService.migrateToEncryption();

        // Verify data is still accessible (should be encrypted in storage but decrypted when retrieved)
        final retrievedRecording = await encryptedDbService.getRecording(
          recording.id,
        );
        expect(retrievedRecording, isNotNull);
        expect(retrievedRecording!.description, equals(recording.description));

        final retrievedTranscription = await encryptedDbService
            .getTranscription(transcription.id);
        expect(retrievedTranscription, isNotNull);
        expect(retrievedTranscription!.text, equals(transcription.text));
      });
    });

    group('Pass-through Operations', () {
      test('should handle summary operations', () async {
        final recording = _createTestRecording('test-summary-recording');
        await encryptedDbService.insertRecording(recording);

        final transcription = _createTestTranscription(
          'test-summary-transcription',
          recording.id,
        );
        await encryptedDbService.insertTranscription(transcription);

        final summary = _createTestSummary('test-summary-1', transcription.id);

        // Test summary operations (pass-through)
        final insertedId = await encryptedDbService.insertSummary(summary);
        expect(insertedId, equals(summary.id));

        final retrievedSummary = await encryptedDbService.getSummary(
          summary.id,
        );
        expect(retrievedSummary, isNotNull);
        expect(retrievedSummary!.id, equals(summary.id));
      });

      test('should handle settings operations', () async {
        const testKey = 'test_setting_key';
        const testValue = 'test_setting_value';

        // Test setting value
        final setResult = await encryptedDbService.setSetting(
          testKey,
          testValue,
        );
        expect(setResult, isTrue);

        // Test getting value
        final retrievedValue = await encryptedDbService.getSetting(testKey);
        expect(retrievedValue, equals(testValue));
      });

      test('should handle database statistics', () async {
        final stats = await encryptedDbService.getDatabaseStats();
        expect(stats, isA<Map<String, int>>());
        expect(stats.containsKey('recordings'), isTrue);
        expect(stats.containsKey('transcriptions'), isTrue);
        expect(stats.containsKey('summaries'), isTrue);
        expect(stats.containsKey('settings'), isTrue);
      });
    });

    group('Error Handling', () {
      test('should handle encryption failures gracefully', () async {
        await EncryptedDatabaseService.setEncryptionEnabled(true);

        // Test with recording that might cause encryption issues
        final recording = _createTestRecording('test-error-recording');

        // Should handle the insertion even if encryption fails
        // The method should return a result (success or failure) without throwing
        final result = await encryptedDbService.insertRecording(recording);
        expect(result, isA<String>());
      });

      test('should handle decryption failures gracefully', () async {
        await EncryptedDatabaseService.setEncryptionEnabled(true);

        final recording = _createTestRecording('test-decryption-error');
        await encryptedDbService.insertRecording(recording);

        // Even if decryption fails, should return some data
        final retrievedRecording = await encryptedDbService.getRecording(
          recording.id,
        );
        expect(retrievedRecording, isNotNull);
      });
    });
  });
}

// Helper functions for creating test data

Recording _createTestRecording(String id) {
  final now = DateTime.now();
  return Recording(
    id: id,
    filename: '$id.wav',
    filePath: '/test/$id.wav',
    duration: 60000,
    fileSize: 1024000,
    format: 'wav',
    quality: 'high',
    sampleRate: 44100,
    bitDepth: 16,
    channels: 1,
    title: 'Test Recording $id',
    description: 'This is sensitive description for $id',
    tags: ['test', 'encrypted', 'sensitive'],
    location: 'Secret test location for $id',
    waveformData: [0.1, 0.2, 0.3, 0.4, 0.5],
    createdAt: now,
    updatedAt: now,
    isDeleted: false,
    metadata: {
      'test_key': 'test_value',
      'sensitive_info': 'secret metadata for $id',
    },
  );
}

Transcription _createTestTranscription(String id, String recordingId) {
  final now = DateTime.now();
  return Transcription(
    id: id,
    recordingId: recordingId,
    text:
        'This is a sensitive transcription text that should be encrypted: $id',
    confidence: 0.95,
    language: 'en',
    provider: 'test_provider',
    status: TranscriptionStatus.completed,
    wordCount: 10,
    createdAt: now,
    updatedAt: now,
  );
}

models.Summary _createTestSummary(String id, String transcriptionId) {
  final now = DateTime.now();
  return models.Summary(
    id: id,
    transcriptionId: transcriptionId,
    content: 'Test summary content for $id',
    type: models.SummaryType.brief,
    provider: 'test_provider',
    model: 'test_model',
    confidence: 0.90,
    wordCount: 5,
    characterCount: 30,
    sentiment: models.SentimentType.neutral,
    createdAt: now,
    updatedAt: now,
  );
}
