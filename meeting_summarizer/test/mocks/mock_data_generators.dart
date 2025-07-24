import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meeting_summarizer/core/models/audio_configuration.dart';
import 'package:meeting_summarizer/core/models/recording_session.dart';
import 'package:meeting_summarizer/core/models/transcription_request.dart';
import 'package:meeting_summarizer/core/models/transcription_result.dart';
import 'package:meeting_summarizer/core/enums/transcription_language.dart';
import 'package:meeting_summarizer/core/enums/recording_state.dart';
import 'package:meeting_summarizer/core/enums/audio_format.dart';
import 'package:meeting_summarizer/core/models/cloud_sync/cloud_provider.dart';
import 'package:meeting_summarizer/core/models/cloud_sync/sync_operation.dart';
import 'package:meeting_summarizer/core/models/cloud_sync/sync_conflict.dart'
    as conflict_models;

/// Comprehensive mock data generators for testing
///
/// Provides realistic test data generation for all major models and scenarios
/// used throughout the meeting summarizer application.
class MockDataGenerators {
  static final math.Random _random = math.Random();

  // Sample data collections for realistic generation
  static const List<String> _meetingTitles = [
    'Weekly Team Standup',
    'Product Roadmap Review',
    'Q3 Planning Session',
    'Client Feedback Discussion',
    'Budget Review Meeting',
    'Sprint Retrospective',
    'Architecture Planning',
    'Customer Interview',
    'Sales Pipeline Review',
    'Marketing Strategy Session',
    'Performance Review Meeting',
    'Project Kickoff',
    'Risk Assessment Workshop',
    'Training Session',
    'Board Meeting',
  ];

  static const List<String> _transcriptionTexts = [
    "Good morning everyone, let's start by reviewing our progress from last week. The development team has made significant headway on the user authentication module.",
    "I think we should prioritize the mobile app features for the next sprint. Our analytics show that 70% of our users are accessing the platform via mobile devices.",
    "The client feedback has been overwhelmingly positive about the new dashboard design. However, they've requested some modifications to the reporting functionality.",
    "Let's discuss the budget allocation for Q4. We need to consider the additional resources required for the international expansion project.",
    "The security audit revealed a few vulnerabilities that need immediate attention. I'll share the detailed report after this meeting.",
    "Our user acquisition costs have decreased by 25% this quarter thanks to the improved onboarding flow and targeted marketing campaigns.",
    "The integration with the third-party payment system is complete. We should see improved transaction processing times starting next week.",
    "I'd like to propose a new feature that allows users to collaborate in real-time on their projects. This could significantly increase user engagement.",
    "The performance optimization work has resulted in a 40% reduction in page load times. Users should notice the improvement immediately.",
    "Let's schedule follow-up meetings with the key stakeholders to address their concerns about the project timeline and deliverables.",
  ];

  static const List<String> _actionItems = [
    'Update project documentation',
    'Schedule client demo',
    'Review security protocols',
    'Implement user feedback',
    'Prepare budget proposal',
    'Conduct code review',
    'Test mobile functionality',
    'Deploy to staging environment',
    'Create user training materials',
    'Analyze performance metrics',
  ];

  static const List<String> _keyPoints = [
    'Budget increase approved for Q4',
    'New feature development on track',
    'Security vulnerability identified and patched',
    'User engagement metrics improved significantly',
    'Client feedback predominantly positive',
    'Performance optimization successful',
    'Team productivity increased by 15%',
    'Mobile traffic represents 70% of usage',
    'Integration with payment system complete',
    'International expansion planning initiated',
  ];

  static const List<String> _filePaths = [
    '/recordings/meeting_001.m4a',
    '/recordings/team_standup.wav',
    '/recordings/client_call.mp3',
    '/recordings/quarterly_review.aac',
    '/recordings/project_planning.m4a',
    '/recordings/budget_discussion.wav',
    '/recordings/retrospective.mp3',
    '/recordings/training_session.aac',
    '/recordings/interview.m4a',
    '/recordings/strategy_meeting.wav',
  ];

  /// Generate realistic audio configuration for testing
  static AudioConfiguration generateAudioConfiguration({
    AudioFormat? format,
    int? bitRate,
    int? sampleRate,
    bool? enableNoiseReduction,
    bool? enableAutoGainControl,
  }) {
    return AudioConfiguration(
      format:
          format ??
          AudioFormat.values[_random.nextInt(AudioFormat.values.length)],
      bitRate: bitRate ?? [128000, 192000, 256000, 320000][_random.nextInt(4)],
      sampleRate: sampleRate ?? [44100, 48000][_random.nextInt(2)],
      channels: _random.nextBool() ? 1 : 2, // mono or stereo
      enableNoiseReduction: enableNoiseReduction ?? _random.nextBool(),
      enableAutoGainControl: enableAutoGainControl ?? _random.nextBool(),
      recordingLimit: _random.nextBool()
          ? Duration(minutes: 30 + _random.nextInt(60))
          : null,
      outputDirectory: _random.nextBool() ? '/custom/output/path' : null,
    );
  }

  /// Generate realistic recording session for testing
  static RecordingSession generateRecordingSession({
    String? id,
    RecordingState? state,
    Duration? duration,
    AudioConfiguration? configuration,
    String? filePath,
    String? errorMessage,
  }) {
    final now = DateTime.now();
    final sessionDuration =
        duration ??
        Duration(
          minutes: _random.nextInt(120) + 5, // 5-125 minutes
          seconds: _random.nextInt(60),
        );

    return RecordingSession(
      id:
          id ??
          'session_${now.millisecondsSinceEpoch}_${_random.nextInt(1000)}',
      startTime: now.subtract(sessionDuration),
      state:
          state ??
          RecordingState.values[_random.nextInt(RecordingState.values.length)],
      duration: sessionDuration,
      configuration: configuration ?? generateAudioConfiguration(),
      filePath: filePath ?? _filePaths[_random.nextInt(_filePaths.length)],
      fileSize:
          sessionDuration.inMinutes * 1024 * 1024 * 0.5, // ~0.5MB per minute
      currentAmplitude: _random.nextDouble(),
      waveformData: generateWaveformData(points: 50),
      endTime: state?.isCompleted == true ? now : null,
      errorMessage: errorMessage,
    );
  }

  /// Generate realistic waveform data for testing
  static List<double> generateWaveformData({int points = 100}) {
    final waveform = <double>[];

    for (int i = 0; i < points; i++) {
      // Generate realistic audio amplitude pattern
      final time = i / points * 2 * math.pi;
      final baseAmplitude = math.sin(time) * 0.5 + 0.5; // 0-1 range
      final noise = (_random.nextDouble() - 0.5) * 0.2; // Add some noise
      final amplitude = math.max(0.0, math.min(1.0, baseAmplitude + noise));
      waveform.add(amplitude);
    }

    return waveform;
  }

  /// Generate realistic transcription request for testing
  static TranscriptionRequest generateTranscriptionRequest({
    TranscriptionLanguage? language,
    String? prompt,
    bool? enableTimestamps,
    bool? enableSpeakerDiarization,
    String? audioFormat,
  }) {
    final languages = [
      TranscriptionLanguage.english,
      TranscriptionLanguage.spanish,
      TranscriptionLanguage.french,
      TranscriptionLanguage.german,
      TranscriptionLanguage.chinese,
    ];

    return TranscriptionRequest(
      language: language ?? languages[_random.nextInt(languages.length)],
      prompt:
          prompt ??
          (_random.nextBool()
              ? 'Please transcribe this meeting recording'
              : null),
      temperature: _random.nextDouble() * 0.5, // 0.0-0.5 range
      audioFormat:
          audioFormat ?? ['mp3', 'wav', 'm4a', 'aac'][_random.nextInt(4)],
      enableTimestamps: enableTimestamps ?? _random.nextBool(),
      enableWordTimestamps: _random.nextBool(),
      enableSpeakerDiarization: enableSpeakerDiarization ?? _random.nextBool(),
      maxAlternatives: _random.nextInt(3) + 1, // 1-3 alternatives
      maxSpeakers: _random.nextBool()
          ? _random.nextInt(5) + 2
          : null, // 2-6 speakers
      customVocabulary: _random.nextBool()
          ? ['API', 'deployment', 'user story']
          : null,
    );
  }

  /// Generate realistic transcription result for testing
  static TranscriptionResult generateTranscriptionResult({
    String? text,
    TranscriptionLanguage? language,
    double? confidence,
    String? provider,
    Duration? processingTime,
    Duration? audioDuration,
  }) {
    final resultText =
        text ??
        _transcriptionTexts[_random.nextInt(_transcriptionTexts.length)];
    final wordCount = resultText.split(' ').length;
    final effectiveAudioDuration =
        audioDuration ?? Duration(minutes: _random.nextInt(60) + 5);
    final segments = generateTranscriptionSegments(
      resultText,
      wordCount: wordCount,
    );
    final words = generateTranscriptionWords(resultText);

    return TranscriptionResult(
      text: resultText,
      confidence: confidence ?? (0.8 + _random.nextDouble() * 0.2), // 0.8-1.0
      language: language ?? TranscriptionLanguage.english,
      processingTimeMs:
          (processingTime ?? Duration(seconds: _random.nextInt(30) + 5))
              .inMilliseconds,
      audioDurationMs: effectiveAudioDuration.inMilliseconds,
      segments: segments,
      words: words,
      provider:
          provider ??
          ['openai_whisper', 'google_speech', 'local_whisper'][_random.nextInt(
            3,
          )],
      model: 'whisper-1',
      metadata: {
        'processing_timestamp': DateTime.now().toIso8601String(),
        'quality_score': _random.nextDouble(),
        'noise_level': _random.nextDouble() * 0.3,
      },
      createdAt: DateTime.now(),
    );
  }

  /// Generate realistic transcription segments for testing
  static List<TranscriptionSegment> generateTranscriptionSegments(
    String text, {
    int? wordCount,
  }) {
    final sentences = text.split('. ').where((s) => s.isNotEmpty).toList();
    final segments = <TranscriptionSegment>[];
    double currentTime = 0.0;

    for (int i = 0; i < sentences.length; i++) {
      final sentence = sentences[i];
      final words = sentence.split(' ').length;
      final duration =
          words * 0.5 + _random.nextDouble() * 2; // ~0.5s per word + variance

      segments.add(
        TranscriptionSegment(
          text: sentence + (i < sentences.length - 1 ? '.' : ''),
          start: currentTime,
          end: currentTime + duration,
          confidence: 0.8 + _random.nextDouble() * 0.2,
          speakerId: _random.nextBool()
              ? 'Speaker ${_random.nextInt(3) + 1}'
              : null,
        ),
      );

      currentTime += duration + 0.5; // Small pause between segments
    }

    return segments;
  }

  /// Generate realistic transcription words for testing
  static List<TranscriptionWord> generateTranscriptionWords(String text) {
    final words = text.split(' ');
    final wordObjects = <TranscriptionWord>[];
    double currentTime = 0.0;

    for (final word in words) {
      final duration = 0.3 + _random.nextDouble() * 0.4; // 0.3-0.7 seconds

      wordObjects.add(
        TranscriptionWord(
          word: word,
          start: currentTime,
          end: currentTime + duration,
          confidence: 0.8 + _random.nextDouble() * 0.2,
        ),
      );

      currentTime += duration + 0.05; // Small pause between words
    }

    return wordObjects;
  }

  /// Generate realistic sync operation for testing
  static SyncOperation generateSyncOperation({
    String? id,
    SyncOperationType? type,
    String? localPath,
    String? remotePath,
    CloudProvider? provider,
    SyncOperationStatus? status,
    double? progress,
  }) {
    final operationType =
        type ??
        SyncOperationType.values[_random.nextInt(
          SyncOperationType.values.length,
        )];
    final operationStatus =
        status ??
        SyncOperationStatus.values[_random.nextInt(
          SyncOperationStatus.values.length,
        )];
    final now = DateTime.now();
    final startTime = now.subtract(Duration(minutes: _random.nextInt(60)));

    return SyncOperation(
      id: id ?? 'sync_${now.millisecondsSinceEpoch}_${_random.nextInt(1000)}',
      type: operationType,
      localPath: localPath ?? _filePaths[_random.nextInt(_filePaths.length)],
      remotePath:
          remotePath ??
          '/cloud${_filePaths[_random.nextInt(_filePaths.length)]}',
      provider:
          provider ??
          CloudProvider.values[_random.nextInt(CloudProvider.values.length)],
      status: operationStatus,
      progress:
          progress ??
          (operationStatus == SyncOperationStatus.completed
              ? 1.0
              : _random.nextDouble()),
      startTime: startTime,
      endTime: operationStatus.isCompleted
          ? startTime.add(Duration(minutes: _random.nextInt(10) + 1))
          : null,
      bytesTransferred: (_random.nextInt(1000000) + 100000)
          .toDouble(), // 100KB-1MB
      totalBytes: (_random.nextInt(2000000) + 1000000).toDouble(), // 1-2MB
      errorMessage: operationStatus == SyncOperationStatus.failed
          ? 'Mock sync error'
          : null,
    );
  }

  /// Generate realistic sync conflict for testing
  static conflict_models.SyncConflict generateSyncConflict({
    String? id,
    String? localPath,
    String? remotePath,
    CloudProvider? provider,
    conflict_models.ConflictType? conflictType,
  }) {
    final now = DateTime.now();
    final localModified = now.subtract(
      Duration(hours: _random.nextInt(24) + 1),
    );
    final remoteModified = now.subtract(
      Duration(hours: _random.nextInt(24) + 1),
    );

    return conflict_models.SyncConflict(
      id:
          id ??
          'conflict_${now.millisecondsSinceEpoch}_${_random.nextInt(1000)}',
      localPath: localPath ?? _filePaths[_random.nextInt(_filePaths.length)],
      remotePath:
          remotePath ??
          '/cloud${_filePaths[_random.nextInt(_filePaths.length)]}',
      provider:
          provider ??
          CloudProvider.values[_random.nextInt(CloudProvider.values.length)],
      conflictType:
          conflictType ??
          conflict_models.ConflictType.values[_random.nextInt(
            conflict_models.ConflictType.values.length,
          )],
      description:
          'Mock conflict: File modified on both local and remote storage',
      localModified: localModified,
      remoteModified: remoteModified,
      localFileSize: _random.nextInt(2000000) + 500000, // 500KB-2MB
      remoteFileSize: _random.nextInt(2000000) + 500000,
      detectedAt: now,
    );
  }

  /// Generate realistic audio data for testing
  static Float32List generateAudioData({int samples = 1024}) {
    final audioData = Float32List(samples);

    for (int i = 0; i < samples; i++) {
      // Generate realistic audio signal with multiple frequencies
      final time = i / 44100.0; // Assume 44.1kHz sample rate
      final signal =
          0.1 *
          (math.sin(2 * math.pi * 440 * time) + // 440 Hz base tone
              0.5 * math.sin(2 * math.pi * 880 * time) + // 880 Hz harmonic
              0.25 * math.sin(2 * math.pi * 1320 * time) + // 1320 Hz harmonic
              0.1 *
                  (_random.nextDouble() - 0.5) // White noise
                  );
      audioData[i] = signal;
    }

    return audioData;
  }

  /// Generate test data collections for batch testing
  static List<T> generateBatch<T>(T Function() generator, {int count = 10}) {
    return List.generate(count, (_) => generator());
  }

  /// Generate realistic meeting titles
  static String generateMeetingTitle() {
    return _meetingTitles[_random.nextInt(_meetingTitles.length)];
  }

  /// Generate realistic action item
  static String generateActionItem() {
    return _actionItems[_random.nextInt(_actionItems.length)];
  }

  /// Generate realistic key point
  static String generateKeyPoint() {
    return _keyPoints[_random.nextInt(_keyPoints.length)];
  }

  /// Generate realistic file path
  static String generateFilePath({String? extension}) {
    final basePath = _filePaths[_random.nextInt(_filePaths.length)];
    if (extension != null) {
      final pathWithoutExt = basePath.substring(0, basePath.lastIndexOf('.'));
      return '$pathWithoutExt.$extension';
    }
    return basePath;
  }

  /// Generate realistic duration
  static Duration generateDuration({int minMinutes = 1, int maxMinutes = 120}) {
    final minutes = minMinutes + _random.nextInt(maxMinutes - minMinutes);
    final seconds = _random.nextInt(60);
    return Duration(minutes: minutes, seconds: seconds);
  }

  /// Generate realistic confidence score
  static double generateConfidenceScore({double min = 0.7, double max = 1.0}) {
    return min + _random.nextDouble() * (max - min);
  }

  /// Generate realistic file size in bytes
  static int generateFileSize({int minMB = 1, int maxMB = 100}) {
    final mb = minMB + _random.nextInt(maxMB - minMB);
    return mb * 1024 * 1024;
  }

  /// Generate mock error messages for testing error scenarios
  static String generateErrorMessage() {
    final errors = [
      'Network connection timeout',
      'Insufficient storage space',
      'File format not supported',
      'Permission denied',
      'Service temporarily unavailable',
      'Invalid authentication credentials',
      'Rate limit exceeded',
      'File not found',
      'Corrupt audio data',
      'Transcription service error',
    ];
    return errors[_random.nextInt(errors.length)];
  }

  /// Generate realistic metadata maps
  static Map<String, dynamic> generateMetadata() {
    return {
      'created_by': 'MockDataGenerator',
      'version': '1.0.${_random.nextInt(100)}',
      'quality_score': _random.nextDouble(),
      'processing_time_ms': _random.nextInt(10000) + 500,
      'source': 'test_data',
      'tags': ['test', 'mock', 'generated'],
      'checksum': 'mock_${_random.nextInt(100000)}',
      'compressed': _random.nextBool(),
      'encrypted': _random.nextBool(),
    };
  }

  /// Reset random seed for deterministic testing
  static void resetSeed([int? seed]) {
    _random = math.Random(seed);
  }
}
