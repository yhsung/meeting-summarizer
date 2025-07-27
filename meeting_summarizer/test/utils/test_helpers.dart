/// Test utilities and helpers for unit testing
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:faker/faker.dart';

import 'package:meeting_summarizer/core/models/database/recording.dart';
import 'package:meeting_summarizer/core/models/database/transcription.dart';
import 'package:meeting_summarizer/core/models/database/summary.dart';

/// Test utilities for setting up test environment
class TestHelpers {
  static final Faker _faker = Faker();
  static final Random _random = Random();

  /// Initialize test environment
  static void setupTestEnvironment() {
    // Initialize FFI for sqflite testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Set up test binding
    TestWidgetsFlutterBinding.ensureInitialized();
  }

  /// Create a test database path
  static String getTestDatabasePath() {
    return ':memory:'; // Use in-memory database for tests
  }

  /// Generate test audio data
  static List<int> generateTestAudioData({int lengthInSeconds = 5}) {
    // Generate simple sine wave audio data for testing
    const sampleRate = 44100;
    const amplitude = 0.3;
    const frequency = 440.0; // A4 note

    final samples = lengthInSeconds * sampleRate;
    final data = List<int>.filled(samples * 2, 0); // 16-bit samples

    for (int i = 0; i < samples; i++) {
      final time = i / sampleRate;
      final sample =
          (amplitude * sin(2 * pi * frequency * time) * 32767).round();

      // Convert to 16-bit little-endian
      data[i * 2] = sample & 0xFF;
      data[i * 2 + 1] = (sample >> 8) & 0xFF;
    }

    return data;
  }

  /// Create a temporary test file
  static Future<File> createTestFile({
    String? fileName,
    String? content,
    List<int>? bytes,
  }) async {
    final tempDir = Directory.systemTemp;
    final file = File(
      '${tempDir.path}/${fileName ?? 'test_${_random.nextInt(10000)}.txt'}',
    );

    if (content != null) {
      await file.writeAsString(content);
    } else if (bytes != null) {
      await file.writeAsBytes(bytes);
    }

    return file;
  }

  /// Clean up test files
  static Future<void> cleanupTestFiles(List<File> files) async {
    for (final file in files) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Ignore cleanup errors in tests
      }
    }
  }

  /// Generate mock recording data
  static Recording generateMockRecording({
    String? id,
    String? filename,
    String? title,
    DateTime? createdAt,
    int? duration,
    String? filePath,
    String? quality,
  }) {
    final now = DateTime.now();
    return Recording(
      id: id ?? _faker.guid.guid(),
      filename:
          filename ?? '${_faker.conference.name().replaceAll(' ', '_')}.wav',
      filePath: filePath ?? '/test/recordings/${_faker.guid.guid()}.wav',
      duration: duration ??
          (_random.nextInt(7200) + 60) * 1000, // 1-120 minutes in milliseconds
      fileSize: _random.nextInt(50000000) + 1000000, // 1-50MB
      format: 'wav',
      quality: quality ?? ['high', 'medium', 'low'][_random.nextInt(3)],
      sampleRate: 44100,
      bitDepth: 16,
      channels: 2,
      title: title ?? _faker.conference.name(),
      description: _faker.lorem.sentence(),
      tags: [_faker.company.name(), _faker.job.title()],
      location: _faker.address.city(),
      waveformData: List.generate(100, (index) => _random.nextDouble()),
      createdAt:
          createdAt ?? _faker.date.dateTime(minYear: 2023, maxYear: 2024),
      updatedAt: now,
      isDeleted: false,
      metadata: {
        'device': _faker.internet.userAgent(),
        'sampleRate': 44100,
        'bitRate': 128000,
      },
    );
  }

  /// Generate mock transcription data
  static Transcription generateMockTranscription({
    String? id,
    String? recordingId,
    String? text,
    DateTime? createdAt,
    TranscriptionStatus? status,
    double? confidence,
  }) {
    final now = DateTime.now();
    final transcriptionText = text ?? _generateMockTranscriptionText();
    return Transcription(
      id: id ?? _faker.guid.guid(),
      recordingId: recordingId ?? _faker.guid.guid(),
      text: transcriptionText,
      confidence: confidence ?? (_random.nextDouble() * 0.3 + 0.7), // 0.7-1.0
      language: 'en-US',
      provider: ['openai', 'google', 'local'][_random.nextInt(3)],
      segments: _generateMockSegments(),
      status: status ?? TranscriptionStatus.completed,
      errorMessage: null,
      processingTime:
          _random.nextInt(300000) + 10000, // 10-300 seconds in milliseconds
      wordCount: transcriptionText.split(' ').length,
      createdAt:
          createdAt ?? _faker.date.dateTime(minYear: 2023, maxYear: 2024),
      updatedAt: now,
    );
  }

  /// Generate mock summary data
  static Summary generateMockSummary({
    String? id,
    String? transcriptionId,
    String? content,
    DateTime? createdAt,
    SummaryType? type,
  }) {
    final now = DateTime.now();
    final summaryContent = content ?? _generateMockSummaryContent();
    return Summary(
      id: id ?? _faker.guid.guid(),
      transcriptionId: transcriptionId ?? _faker.guid.guid(),
      content: summaryContent,
      type: type ??
          SummaryType.values[_random.nextInt(SummaryType.values.length)],
      provider: ['openai', 'anthropic'][_random.nextInt(2)],
      model: 'gpt-4',
      prompt: 'Please summarize the following meeting transcript...',
      confidence: _random.nextDouble() * 0.3 + 0.7,
      wordCount: summaryContent.split(' ').length,
      characterCount: summaryContent.length,
      keyPoints: [
        _faker.lorem.sentence(),
        _faker.lorem.sentence(),
        _faker.lorem.sentence(),
      ],
      actionItems: [
        ActionItem(
          id: _faker.guid.guid(),
          text: _faker.lorem.sentence(),
          assignee: _faker.person.name(),
          dueDate: _faker.date.dateTime(minYear: 2024, maxYear: 2025),
          priority: ActionItemPriority
              .values[_random.nextInt(ActionItemPriority.values.length)],
          status: ActionItemStatus
              .values[_random.nextInt(ActionItemStatus.values.length)],
        ),
      ],
      sentiment:
          SentimentType.values[_random.nextInt(SentimentType.values.length)],
      createdAt:
          createdAt ?? _faker.date.dateTime(minYear: 2023, maxYear: 2024),
      updatedAt: now,
    );
  }

  /// Generate mock transcription text
  static String _generateMockTranscriptionText() {
    final sentences = <String>[];
    final sentenceCount = _random.nextInt(10) + 5;

    for (int i = 0; i < sentenceCount; i++) {
      sentences.add(_faker.lorem.sentence());
    }

    return sentences.join(' ');
  }

  /// Generate mock transcription segments
  static List<TranscriptionSegment> _generateMockSegments() {
    final segments = <TranscriptionSegment>[];
    final segmentCount = _random.nextInt(5) + 3;
    int currentTime = 0;

    for (int i = 0; i < segmentCount; i++) {
      final duration =
          _random.nextInt(10000) + 2000; // 2-12 seconds in milliseconds
      segments.add(
        TranscriptionSegment(
          startTime: currentTime,
          endTime: currentTime + duration,
          text: _faker.lorem.sentence(),
          confidence: _random.nextDouble() * 0.3 + 0.7,
          words: _faker.lorem.sentence().split(' '),
        ),
      );
      currentTime += duration;
    }

    return segments;
  }

  /// Generate mock summary content
  static String _generateMockSummaryContent() {
    final paragraphs = <String>[];
    final paragraphCount = _random.nextInt(3) + 2;

    for (int i = 0; i < paragraphCount; i++) {
      final sentences = <String>[];
      final sentenceCount = _random.nextInt(4) + 2;

      for (int j = 0; j < sentenceCount; j++) {
        sentences.add(_faker.lorem.sentence());
      }

      paragraphs.add(sentences.join(' '));
    }

    return paragraphs.join('\n\n');
  }

  /// Create a list of mock recordings
  static List<Recording> generateMockRecordingList({int count = 5}) {
    return List.generate(count, (index) => generateMockRecording());
  }

  /// Create a list of mock transcriptions
  static List<Transcription> generateMockTranscriptionList({int count = 5}) {
    return List.generate(count, (index) => generateMockTranscription());
  }

  /// Create a list of mock summaries
  static List<Summary> generateMockSummaryList({int count = 5}) {
    return List.generate(count, (index) => generateMockSummary());
  }

  /// Setup mock method channel responses
  static void setupMockMethodChannel(
    String channelName,
    Map<String, dynamic> responses,
  ) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channelName), (
      MethodCall methodCall,
    ) async {
      return responses[methodCall.method];
    });
  }

  /// Verify that a future completes within a timeout
  static Future<T> expectCompletes<T>(
    Future<T> future, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    return future.timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'Future did not complete within $timeout',
        timeout,
      ),
    );
  }

  /// Create test matchers for custom objects
  static Matcher isRecordingWithId(String id) {
    return predicate<Recording>((recording) => recording.id == id);
  }

  static Matcher isTranscriptionWithText(String text) {
    return predicate<Transcription>(
      (transcription) => transcription.text.contains(text),
    );
  }

  static Matcher isSummaryWithType(SummaryType type) {
    return predicate<Summary>((summary) => summary.type == type);
  }

  /// Wait for a condition to be true
  static Future<void> waitForCondition(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (!condition() && stopwatch.elapsed < timeout) {
      await Future.delayed(interval);
    }

    if (!condition()) {
      throw TimeoutException('Condition was not met within $timeout', timeout);
    }
  }

  /// Dispose test resources
  static void dispose() {
    // Clean up any global test resources if needed
  }
}

/// Extension methods for test assertions
extension TestAssertions on Object? {
  /// Assert that this object is not null and return it
  T assertNotNull<T>() {
    expect(this, isNotNull);
    return this as T;
  }
}

/// Custom timeout exception for tests
class TimeoutException implements Exception {
  final String message;
  final Duration timeout;

  const TimeoutException(this.message, this.timeout);

  @override
  String toString() => 'TimeoutException: $message';
}
