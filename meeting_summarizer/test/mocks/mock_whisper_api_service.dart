import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:developer';

import 'package:meeting_summarizer/core/models/transcription_result.dart';
import 'package:meeting_summarizer/core/models/transcription_request.dart';
import 'package:meeting_summarizer/core/models/transcription_usage_stats.dart';
import 'package:meeting_summarizer/core/services/transcription_service_interface.dart';
import 'package:meeting_summarizer/core/enums/transcription_language.dart';

/// Comprehensive mock Whisper API service for testing
class MockWhisperApiService implements TranscriptionServiceInterface {
  // Mock behavior configuration
  bool _shouldFailTranscription = false;
  bool _shouldFailInitialization = false;
  Duration _mockTranscriptionDelay = const Duration(milliseconds: 500);
  double _mockConfidenceScore = 0.95;
  bool _isInitialized = false;
  int _transcriptionCounter = 0;
  int _totalCharactersTranscribed = 0;
  int _totalRequestsProcessed = 0;

  // Mock response templates
  static const List<String> _mockTranscriptions = [
    "Hello everyone, welcome to today's meeting. Let's start by reviewing the agenda.",
    "The quarterly results show a significant improvement in our key metrics.",
    "I think we should prioritize the customer feedback we received last week.",
    "The development team has completed the initial phase of the project.",
    "Let's schedule a follow-up meeting to discuss the next steps.",
    "Thank you all for your valuable input during this discussion.",
    "The market research indicates a growing demand for our services.",
    "We need to allocate additional resources to meet the upcoming deadline.",
    "The new features have been well-received by our beta users.",
    "Let's take a short break and reconvene in ten minutes.",
  ];

  static const List<String> _mockSpeakers = [
    "Speaker A",
    "Speaker B",
    "Speaker C",
    "Speaker D",
    "Unknown Speaker",
  ];

  // Mock configuration methods

  /// Configure mock to simulate transcription failures
  void setMockTranscriptionFailure(bool shouldFail) {
    _shouldFailTranscription = shouldFail;
  }

  /// Configure mock to simulate initialization failures
  void setMockInitializationFailure(bool shouldFail) {
    _shouldFailInitialization = shouldFail;
  }

  /// Set mock transcription delay for testing timing scenarios
  void setMockTranscriptionDelay(Duration delay) {
    _mockTranscriptionDelay = delay;
  }

  /// Set mock confidence score for transcriptions
  void setMockConfidenceScore(double confidence) {
    _mockConfidenceScore = math.max(0.0, math.min(1.0, confidence));
  }

  /// Reset all mock state to defaults
  void resetMockState() {
    _shouldFailTranscription = false;
    _shouldFailInitialization = false;
    _mockTranscriptionDelay = const Duration(milliseconds: 500);
    _mockConfidenceScore = 0.95;
    _transcriptionCounter = 0;
    _totalCharactersTranscribed = 0;
    _totalRequestsProcessed = 0;
  }

  @override
  Future<void> initialize() async {
    if (_shouldFailInitialization) {
      throw Exception('Mock Whisper API initialization failure');
    }

    await Future.delayed(const Duration(milliseconds: 100));
    _isInitialized = true;
    log('MockWhisperApiService: Initialized successfully');
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    log('MockWhisperApiService: Disposed');
  }

  @override
  Future<bool> isServiceAvailable() async {
    return _isInitialized && !_shouldFailTranscription;
  }

  @override
  Future<TranscriptionResult> transcribeAudioFile(
    File audioFile,
    TranscriptionRequest request,
  ) async {
    if (!_isInitialized) {
      throw StateError('Service not initialized');
    }

    if (_shouldFailTranscription) {
      throw Exception('Mock transcription failure');
    }

    // Simulate processing time
    await Future.delayed(_mockTranscriptionDelay);

    _transcriptionCounter++;
    _totalRequestsProcessed++;

    final audioLength = await _getAudioFileLength(audioFile);
    final mockResult = _generateMockTranscriptionResult(request, audioLength);
    _totalCharactersTranscribed += mockResult.text.length;

    log(
      'MockWhisperApiService: File transcription completed - ${mockResult.text.length} characters',
    );
    return mockResult;
  }

  @override
  Future<TranscriptionResult> transcribeAudioBytes(
    List<int> audioBytes,
    TranscriptionRequest request,
  ) async {
    if (!_isInitialized) {
      throw StateError('Service not initialized');
    }

    if (_shouldFailTranscription) {
      throw Exception('Mock transcription failure');
    }

    // Simulate processing time
    await Future.delayed(_mockTranscriptionDelay);

    _transcriptionCounter++;
    _totalRequestsProcessed++;

    final audioLength = _estimateAudioLengthFromBytes(audioBytes.length);
    final mockResult = _generateMockTranscriptionResult(request, audioLength);
    _totalCharactersTranscribed += mockResult.text.length;

    log(
      'MockWhisperApiService: Bytes transcription completed - ${mockResult.text.length} characters',
    );
    return mockResult;
  }

  @override
  Future<List<TranscriptionLanguage>> getSupportedLanguages() async {
    return [
      TranscriptionLanguage.english,
      TranscriptionLanguage.spanish,
      TranscriptionLanguage.french,
      TranscriptionLanguage.german,
      TranscriptionLanguage.italian,
      TranscriptionLanguage.portuguese,
      TranscriptionLanguage.russian,
      TranscriptionLanguage.japanese,
      TranscriptionLanguage.korean,
      TranscriptionLanguage.chineseSimplified,
      TranscriptionLanguage.arabic,
      TranscriptionLanguage.hindi,
      TranscriptionLanguage.turkish,
      TranscriptionLanguage.polish,
      TranscriptionLanguage.dutch,
      TranscriptionLanguage.swedish,
      TranscriptionLanguage.danish,
      TranscriptionLanguage.norwegian,
      TranscriptionLanguage.finnish,
    ];
  }

  @override
  Future<TranscriptionLanguage?> detectLanguage(File audioFile) async {
    if (!_isInitialized) {
      throw StateError('Service not initialized');
    }

    // Simulate language detection delay
    await Future.delayed(Duration(milliseconds: 200));

    // Mock language detection - randomly pick from common languages
    final commonLanguages = [
      TranscriptionLanguage.english,
      TranscriptionLanguage.spanish,
      TranscriptionLanguage.french,
      TranscriptionLanguage.german,
    ];

    final random = math.Random();
    return commonLanguages[random.nextInt(commonLanguages.length)];
  }

  @override
  Future<TranscriptionUsageStats> getUsageStats() async {
    final failedRequests =
        _shouldFailTranscription ? _totalRequestsProcessed : 0;
    final successfulRequests = _totalRequestsProcessed - failedRequests;

    return TranscriptionUsageStats(
      totalRequests: _totalRequestsProcessed,
      successfulRequests: successfulRequests,
      failedRequests: failedRequests,
      totalProcessingTime: Duration(
        milliseconds:
            _mockTranscriptionDelay.inMilliseconds * _totalRequestsProcessed,
      ),
      averageProcessingTime: _mockTranscriptionDelay.inMilliseconds.toDouble(),
      totalAudioMinutes:
          (_totalRequestsProcessed * 2.5).round(), // ~2.5 minutes per request
      lastRequestTime: DateTime.now(),
      peakMetrics: PeakUsageMetrics(),
    );
  }

  // Private helper methods

  TranscriptionResult _generateMockTranscriptionResult(
    TranscriptionRequest request,
    Duration audioLength,
  ) {
    final transcriptionText = _selectMockTranscription(audioLength);
    final segments = _generateMockSegments(transcriptionText, request);
    final words = _generateMockWords(transcriptionText, request);
    final speakers = _generateMockSpeakers(request);

    return TranscriptionResult(
      text: transcriptionText,
      confidence: _mockConfidenceScore,
      language: request.language ?? TranscriptionLanguage.english,
      processingTimeMs: _mockTranscriptionDelay.inMilliseconds,
      audioDurationMs: audioLength.inMilliseconds,
      segments: segments,
      words: words,
      speakers: speakers,
      provider: 'Mock Whisper API',
      model: 'mock-whisper-1',
      metadata: {
        'service': 'Mock Whisper API',
        'model': 'mock-whisper-1',
        'timestamp': DateTime.now().toIso8601String(),
        'audioFormat': request.audioFormat,
        'enableSpeakerDiarization': request.enableSpeakerDiarization,
        'enableTimestamps': request.enableTimestamps,
        'temperature': request.temperature,
        'mockGenerated': true,
        'transcriptionCounter': _transcriptionCounter,
      },
      createdAt: DateTime.now(),
    );
  }

  String _selectMockTranscription(Duration audioLength) {
    final random = math.Random();

    // Generate multiple sentences for longer audio
    final audioLengthSeconds = audioLength.inSeconds;
    final sentenceCount = math.max(1, (audioLengthSeconds / 10).round());

    final sentences = <String>[];
    for (int i = 0; i < sentenceCount; i++) {
      sentences.add(
        _mockTranscriptions[random.nextInt(_mockTranscriptions.length)],
      );
    }

    return sentences.join(' ');
  }

  List<TranscriptionSegment> _generateMockSegments(
    String fullText,
    TranscriptionRequest request,
  ) {
    final segments = <TranscriptionSegment>[];
    final words = fullText.split(' ');
    final random = math.Random();

    if (!request.enableTimestamps) {
      // Return single segment without timestamps
      return [
        TranscriptionSegment(
          text: fullText,
          start: 0.0,
          end: words.length * 0.5, // ~0.5 seconds per word
          confidence: _mockConfidenceScore,
          speakerId: request.enableSpeakerDiarization ? _mockSpeakers[0] : null,
        ),
      ];
    }

    // Generate segments with timestamps
    const maxSegmentLength = 10; // words per segment
    double currentTime = 0.0;

    for (int i = 0; i < words.length; i += maxSegmentLength) {
      final segmentWords = words.skip(i).take(maxSegmentLength).toList();
      final segmentText = segmentWords.join(' ');
      final segmentDuration =
          segmentWords.length * 0.5; // ~0.5 seconds per word

      segments.add(
        TranscriptionSegment(
          text: segmentText,
          start: currentTime,
          end: currentTime + segmentDuration,
          confidence: _mockConfidenceScore + (random.nextDouble() - 0.5) * 0.1,
          speakerId: request.enableSpeakerDiarization
              ? _mockSpeakers[random.nextInt(_mockSpeakers.length)]
              : null,
        ),
      );

      currentTime += segmentDuration + 0.1; // Small gap between segments
    }

    return segments;
  }

  List<TranscriptionWord> _generateMockWords(
    String fullText,
    TranscriptionRequest request,
  ) {
    if (!request.enableWordTimestamps) {
      return [];
    }

    final words = fullText.split(' ');
    final mockWords = <TranscriptionWord>[];
    double currentTime = 0.0;
    final random = math.Random();

    for (final word in words) {
      final wordDuration = 0.3 + random.nextDouble() * 0.4; // 0.3-0.7 seconds

      mockWords.add(
        TranscriptionWord(
          word: word,
          start: currentTime,
          end: currentTime + wordDuration,
          confidence: _mockConfidenceScore + (random.nextDouble() - 0.5) * 0.2,
        ),
      );

      currentTime += wordDuration + 0.05; // Small pause between words
    }

    return mockWords;
  }

  List<Speaker> _generateMockSpeakers(TranscriptionRequest request) {
    if (!request.enableSpeakerDiarization) {
      return [];
    }

    final speakers = <Speaker>[];
    final maxSpeakers = request.maxSpeakers ?? 3;
    final random = math.Random();

    for (int i = 0; i < maxSpeakers; i++) {
      speakers.add(
        Speaker(
          id: _mockSpeakers[i % _mockSpeakers.length],
          name: i < 2 ? 'Speaker ${String.fromCharCode(65 + i)}' : null,
          confidence: 0.8 + random.nextDouble() * 0.2,
          metadata: {'mockGenerated': true, 'speakerIndex': i},
        ),
      );
    }

    return speakers;
  }

  Future<Duration> _getAudioFileLength(File audioFile) async {
    // Mock file length estimation - use file size as rough approximation
    try {
      final fileSizeBytes = await audioFile.length();
      // Rough estimation: 1 minute of audio ≈ 1MB for compressed formats
      final estimatedMinutes = fileSizeBytes / (1024 * 1024);
      return Duration(milliseconds: (estimatedMinutes * 60 * 1000).round());
    } catch (e) {
      // Fallback to default length
      return const Duration(minutes: 2);
    }
  }

  Duration _estimateAudioLengthFromBytes(int audioSizeBytes) {
    // Rough estimation: 1 minute of audio ≈ 1MB for compressed formats
    final estimatedMinutes = audioSizeBytes / (1024 * 1024);
    return Duration(milliseconds: (estimatedMinutes * 60 * 1000).round());
  }

  /// Get current mock state for debugging
  Map<String, dynamic> getMockState() {
    return {
      'isInitialized': _isInitialized,
      'shouldFailTranscription': _shouldFailTranscription,
      'shouldFailInitialization': _shouldFailInitialization,
      'mockTranscriptionDelay': _mockTranscriptionDelay.inMilliseconds,
      'mockConfidenceScore': _mockConfidenceScore,
      'transcriptionCounter': _transcriptionCounter,
      'totalCharactersTranscribed': _totalCharactersTranscribed,
      'totalRequestsProcessed': _totalRequestsProcessed,
      'supportedLanguages': 19,
      'isServiceAvailable': _isInitialized && !_shouldFailTranscription,
    };
  }

  /// Generate mock transcription for specific content (useful for tests)
  TranscriptionResult generateMockTranscriptionForContent(
    String content,
    TranscriptionRequest request, {
    Duration? audioLength,
  }) {
    final effectiveAudioLength =
        audioLength ?? Duration(seconds: content.split(' ').length ~/ 2);
    final segments = _generateMockSegments(content, request);
    final words = _generateMockWords(content, request);
    final speakers = _generateMockSpeakers(request);

    return TranscriptionResult(
      text: content,
      confidence: _mockConfidenceScore,
      language: request.language ?? TranscriptionLanguage.english,
      processingTimeMs: _mockTranscriptionDelay.inMilliseconds,
      audioDurationMs: effectiveAudioLength.inMilliseconds,
      segments: segments,
      words: words,
      speakers: speakers,
      provider: 'Mock Whisper API',
      model: 'mock-whisper-custom',
      metadata: {
        'service': 'Mock Whisper API',
        'model': 'mock-whisper-custom',
        'timestamp': DateTime.now().toIso8601String(),
        'customContent': true,
        'mockGenerated': true,
      },
      createdAt: DateTime.now(),
    );
  }

  /// Validate audio format for testing
  bool validateAudioFormat(String format) {
    const supportedFormats = ['wav', 'mp3', 'aac', 'm4a', 'flac', 'ogg'];
    return supportedFormats.contains(format.toLowerCase());
  }

  /// Validate audio file size for testing
  bool validateFileSize(int fileSizeBytes) {
    const maxFileSize = 100 * 1024 * 1024; // 100MB
    return fileSizeBytes <= maxFileSize;
  }

  /// Validate audio duration for testing
  bool validateDuration(Duration duration) {
    const maxDuration = Duration(hours: 2);
    return duration <= maxDuration;
  }
}
