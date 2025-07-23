/// Integration test utilities and helpers for end-to-end testing
library;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:meeting_summarizer/core/database/database_helper.dart';
import 'package:meeting_summarizer/core/models/database/recording.dart';
import 'package:meeting_summarizer/core/models/database/transcription.dart';
import 'package:meeting_summarizer/core/models/database/summary.dart' as models;
import 'package:meeting_summarizer/core/enums/audio_format.dart';
import 'package:meeting_summarizer/core/enums/audio_quality.dart';

/// Integration test helper class providing utilities for end-to-end testing
class IntegrationTestHelpers {
  static IntegrationTestWidgetsFlutterBinding? _binding;
  static DatabaseHelper? _testDatabaseHelper;
  static Directory? _testDirectory;

  /// Initialize integration test environment
  static Future<void> initialize() async {
    _binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

    // Setup test directory
    _testDirectory = await getTemporaryDirectory();
    final testDbPath = '${_testDirectory!.path}/test_meeting_summarizer.db';

    // Initialize test database with custom database name
    _testDatabaseHelper = DatabaseHelper(customDatabaseName: testDbPath);
    await _testDatabaseHelper!.database;

    // Configure test-specific settings
    await _configureTestEnvironment();
  }

  /// Clean up test environment
  static Future<void> cleanup() async {
    if (_testDatabaseHelper != null) {
      await _testDatabaseHelper!.close();
      _testDatabaseHelper = null;
    }

    if (_testDirectory != null && await _testDirectory!.exists()) {
      await _testDirectory!.delete(recursive: true);
    }

    _testDirectory = null;
  }

  /// Configure test environment with mock settings
  static Future<void> _configureTestEnvironment() async {
    // Disable actual recording for integration tests
    // Configure mock services to avoid real API calls

    // Set test-specific paths
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return _testDirectory!.path;
            }
            return null;
          },
        );
  }

  /// Create a test recording with mock data
  static Future<Recording> createTestRecording({
    String? fileName,
    int durationMs = 30000,
  }) async {
    final now = DateTime.now();
    final recording = Recording(
      id: now.millisecondsSinceEpoch.toString(),
      filename: fileName ?? 'test_recording_${now.millisecondsSinceEpoch}.wav',
      filePath: '${_testDirectory!.path}/recordings/${fileName ?? 'test.wav'}',
      duration: durationMs,
      fileSize: 1024000, // 1MB mock size
      format: AudioFormat.wav.name,
      quality: AudioQuality.medium.name,
      sampleRate: 44100,
      bitDepth: 16,
      channels: 2,
      createdAt: now,
      updatedAt: now,
    );

    // Create mock audio file
    await _createMockAudioFile(recording.filePath);

    // Insert into test database
    final db = await _testDatabaseHelper!.database;
    await db.insert('recordings', recording.toDatabase());

    return recording;
  }

  /// Create a test transcription for a recording
  static Future<Transcription> createTestTranscription({
    required String recordingId,
    String? content,
    double confidence = 0.95,
  }) async {
    final now = DateTime.now();
    final transcriptionText = content ?? _generateMockTranscriptionContent();
    final transcription = Transcription(
      id: now.millisecondsSinceEpoch.toString(),
      recordingId: recordingId,
      text: transcriptionText,
      confidence: confidence,
      language: 'en-US',
      provider: 'mock_provider',
      status: TranscriptionStatus.completed,
      wordCount: transcriptionText.split(' ').length,
      createdAt: now,
      updatedAt: now,
    );

    final db = await _testDatabaseHelper!.database;
    await db.insert('transcriptions', transcription.toDatabase());
    return transcription;
  }

  /// Create a test summary for a transcription
  static Future<models.Summary> createTestSummary({
    required String transcriptionId,
    models.SummaryType type = models.SummaryType.brief,
    String? content,
  }) async {
    final now = DateTime.now();
    final summaryContent = content ?? _generateMockSummaryContent(type);
    final summary = models.Summary(
      id: now.millisecondsSinceEpoch.toString(),
      transcriptionId: transcriptionId,
      content: summaryContent,
      type: type,
      provider: 'mock_provider',
      confidence: 0.9,
      wordCount: summaryContent.split(' ').length,
      characterCount: summaryContent.length,
      sentiment: models.SentimentType.neutral,
      createdAt: now,
      updatedAt: now,
    );

    final db = await _testDatabaseHelper!.database;
    await db.insert('summaries', summary.toDatabase());
    return summary;
  }

  /// Create a complete test data set (recording -> transcription -> summary)
  static Future<Map<String, dynamic>> createCompleteTestDataSet({
    String? fileName,
    models.SummaryType summaryType = models.SummaryType.brief,
  }) async {
    final recording = await createTestRecording(fileName: fileName);
    final transcription = await createTestTranscription(
      recordingId: recording.id,
    );
    final summary = await createTestSummary(
      transcriptionId: transcription.id,
      type: summaryType,
    );

    return {
      'recording': recording,
      'transcription': transcription,
      'summary': summary,
    };
  }

  /// Generate mock audio file for testing
  static Future<void> _createMockAudioFile(String filePath) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);

    // Create a minimal valid WAV file header with some mock data
    const wavHeader = [
      // RIFF header
      0x52, 0x49, 0x46, 0x46, // "RIFF"
      0x24, 0x08, 0x00, 0x00, // File size - 8
      0x57, 0x41, 0x56, 0x45, // "WAVE"
      // fmt subchunk
      0x66, 0x6D, 0x74, 0x20, // "fmt "
      0x10, 0x00, 0x00, 0x00, // Subchunk1Size (16 for PCM)
      0x01, 0x00, // AudioFormat (1 for PCM)
      0x02, 0x00, // NumChannels (2 for stereo)
      0x44, 0xAC, 0x00, 0x00, // SampleRate (44100)
      0x10, 0xB1, 0x02, 0x00, // ByteRate
      0x04, 0x00, // BlockAlign
      0x10, 0x00, // BitsPerSample (16)
      // data subchunk
      0x64, 0x61, 0x74, 0x61, // "data"
      0x00, 0x08, 0x00, 0x00, // Subchunk2Size
    ];

    // Add some mock audio data (2048 bytes of silence)
    final mockAudioData = List.filled(2048, 0);
    final completeData = [...wavHeader, ...mockAudioData];

    await file.writeAsBytes(completeData);
  }

  /// Generate mock transcription content
  static String _generateMockTranscriptionContent() {
    return '''Good morning everyone, thank you for joining today's meeting. 
We'll be discussing the quarterly review and upcoming project milestones. 
First, let's go over the progress we've made since our last meeting. 
The development team has successfully completed the authentication module 
and we're now moving forward with the user interface implementation. 
Are there any questions or concerns about the current timeline?''';
  }

  /// Generate mock summary content based on type
  static String _generateMockSummaryContent(models.SummaryType type) {
    switch (type) {
      case models.SummaryType.brief:
        return 'Meeting focused on quarterly review and project milestones. Authentication module completed, UI implementation in progress.';

      case models.SummaryType.detailed:
        return '''Meeting Summary:
1. Quarterly review discussion
2. Project milestone review
3. Authentication module - COMPLETED
4. UI implementation - IN PROGRESS
5. Timeline concerns addressed

Key Outcomes:
- Development team on track with current timeline
- Authentication module successfully delivered
- Next focus: User interface implementation''';

      case models.SummaryType.bulletPoints:
        return '''• Quarterly review conducted
• Authentication module completed successfully
• UI implementation currently in progress
• Team on track with project timeline
• No major concerns raised about current schedule''';

      case models.SummaryType.actionItems:
        return '''Action Items:
1. Continue UI implementation - Development Team
2. Prepare demo for authentication module - Lead Developer
3. Schedule next milestone review - Project Manager
4. Update project timeline documentation - Team Lead''';
    }
  }

  /// Wait for async operations to complete
  static Future<void> waitForAsync([Duration? timeout]) async {
    await Future.delayed(timeout ?? const Duration(milliseconds: 100));
  }

  /// Pump and settle multiple times for complex UI interactions
  static Future<void> pumpAndSettleTimes(
    WidgetTester tester,
    int times, [
    Duration timeout = const Duration(seconds: 10),
  ]) async {
    for (int i = 0; i < times; i++) {
      await tester.pumpAndSettle(timeout);
      await waitForAsync();
    }
  }

  /// Find widget by key with timeout
  static Future<Finder> findByKeyWithTimeout(
    String key, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final finder = find.byKey(Key(key));

    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      if (finder.evaluate().isNotEmpty) {
        return finder;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    throw Exception('Widget with key "$key" not found within timeout');
  }

  /// Take screenshot for debugging
  static Future<void> takeScreenshot(String name) async {
    if (_binding != null) {
      await _binding!.takeScreenshot(name);
    }
  }

  /// Get test database helper
  static DatabaseHelper get testDatabase {
    if (_testDatabaseHelper == null) {
      throw StateError(
        'Test database not initialized. Call initialize() first.',
      );
    }
    return _testDatabaseHelper!;
  }

  /// Get test directory
  static Directory get testDirectory {
    if (_testDirectory == null) {
      throw StateError(
        'Test directory not initialized. Call initialize() first.',
      );
    }
    return _testDirectory!;
  }

  /// Verify database state matches expectations
  static Future<void> verifyDatabaseState({
    int? expectedRecordings,
    int? expectedTranscriptions,
    int? expectedSummaries,
  }) async {
    final db = await _testDatabaseHelper!.database;

    if (expectedRecordings != null) {
      final recordingCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM recordings'),
          ) ??
          0;
      expect(recordingCount, equals(expectedRecordings));
    }

    if (expectedTranscriptions != null) {
      final transcriptionCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM transcriptions'),
          ) ??
          0;
      expect(transcriptionCount, equals(expectedTranscriptions));
    }

    if (expectedSummaries != null) {
      final summaryCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM summaries'),
          ) ??
          0;
      expect(summaryCount, equals(expectedSummaries));
    }
  }

  /// Clean test database
  static Future<void> cleanTestDatabase() async {
    final db = await _testDatabaseHelper!.database;
    await db.delete('recordings');
    await db.delete('transcriptions');
    await db.delete('summaries');
  }

  /// Mock network connectivity for offline tests
  static void mockOfflineMode() {
    // Mock network connectivity to simulate offline state
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'check') {
              return 'none';
            }
            return null;
          },
        );
  }

  /// Mock online connectivity
  static void mockOnlineMode() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'check') {
              return 'wifi';
            }
            return null;
          },
        );
  }

  /// Reset all mocks
  static void resetMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          null,
        );
  }

  /// Get current platform name for testing
  static String getPlatformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}

/// Test data factory for creating consistent test data
class TestDataFactory {
  /// Create test recording with specified parameters
  static Recording createRecording({
    String? id,
    String? fileName,
    String? filePath,
    int durationMs = 30000,
  }) {
    final now = DateTime.now();
    return Recording(
      id: id ?? now.millisecondsSinceEpoch.toString(),
      filename: fileName ?? 'test_recording.wav',
      filePath: filePath ?? '/test/recordings/test_recording.wav',
      duration: durationMs,
      fileSize: 1024000,
      format: AudioFormat.wav.name,
      quality: AudioQuality.medium.name,
      sampleRate: 44100,
      bitDepth: 16,
      channels: 2,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create test transcription
  static Transcription createTranscription({
    String? id,
    required String recordingId,
    String? content,
    double confidence = 0.95,
  }) {
    final now = DateTime.now();
    final transcriptionText =
        content ?? 'This is a test transcription content.';
    return Transcription(
      id: id ?? now.millisecondsSinceEpoch.toString(),
      recordingId: recordingId,
      text: transcriptionText,
      confidence: confidence,
      language: 'en-US',
      provider: 'test_provider',
      status: TranscriptionStatus.completed,
      wordCount: transcriptionText.split(' ').length,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create test summary
  static models.Summary createSummary({
    String? id,
    required String transcriptionId,
    models.SummaryType type = models.SummaryType.brief,
    String? content,
  }) {
    final now = DateTime.now();
    final summaryContent = content ?? 'This is a test summary content.';
    return models.Summary(
      id: id ?? now.millisecondsSinceEpoch.toString(),
      transcriptionId: transcriptionId,
      content: summaryContent,
      type: type,
      provider: 'test_provider',
      confidence: 0.9,
      wordCount: summaryContent.split(' ').length,
      characterCount: summaryContent.length,
      sentiment: models.SentimentType.neutral,
      createdAt: now,
      updatedAt: now,
    );
  }
}
