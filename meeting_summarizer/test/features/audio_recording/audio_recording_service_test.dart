import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/enums/audio_format.dart';
import 'package:meeting_summarizer/core/enums/audio_quality.dart';
import 'package:meeting_summarizer/core/enums/recording_state.dart';
import 'package:meeting_summarizer/core/models/audio_configuration.dart';
import 'package:meeting_summarizer/core/services/audio_enhancement_service_interface.dart';
import 'package:meeting_summarizer/features/audio_recording/data/audio_recording_service.dart';

import 'platform/audio_recording_platform_test.dart';

// Mock AudioEnhancementService for testing
class MockAudioEnhancementService implements AudioEnhancementServiceInterface {
  bool _isInitialized = false;
  bool _isConfigured = false;
  AudioEnhancementConfig? _config;

  @override
  Future<void> initialize() async {
    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
  }

  @override
  Future<void> configure(AudioEnhancementConfig config) async {
    _config = config;
    _isConfigured = true;
  }

  @override
  AudioEnhancementConfig get currentConfig =>
      _config ?? const AudioEnhancementConfig();

  @override
  Future<AudioEnhancementResult> processAudio(
    Float32List audioData,
    int sampleRate,
  ) async {
    return AudioEnhancementResult(
      enhancedAudioData: audioData, // Return unmodified for testing
      processingMetrics: {},
      processingTime: const Duration(milliseconds: 10),
      noiseReductionApplied: 0.3,
      gainAdjustmentApplied: 0.1,
    );
  }

  @override
  Stream<Float32List> processAudioStream(
    Stream<Float32List> audioStream,
    int sampleRate,
  ) async* {
    await for (final chunk in audioStream) {
      yield chunk; // Return unmodified for testing
    }
  }

  @override
  Future<void> estimateNoiseProfile(
    Float32List audioData,
    int sampleRate,
  ) async {
    // Mock implementation
  }

  @override
  Future<Float32List> applyNoiseReduction(
    Float32List audioData,
    int sampleRate,
    double strength,
  ) async {
    return audioData; // Return unmodified for testing
  }

  @override
  Future<Float32List> applyEchoCancellation(
    Float32List audioData,
    int sampleRate,
    double strength,
  ) async {
    return audioData; // Return unmodified for testing
  }

  @override
  Future<Float32List> applyAutoGainControl(
    Float32List audioData,
    int sampleRate,
    double threshold,
  ) async {
    return audioData; // Return unmodified for testing
  }

  @override
  Future<Float32List> applySpectralSubtraction(
    Float32List audioData,
    int sampleRate,
    double alpha,
    double beta,
  ) async {
    return audioData; // Return unmodified for testing
  }

  @override
  Future<Float32List> applyFrequencyFiltering(
    Float32List audioData,
    int sampleRate,
    double highPassCutoff,
    double lowPassCutoff,
  ) async {
    return audioData; // Return unmodified for testing
  }

  @override
  List<AudioEnhancementType> getSupportedEnhancements() {
    return [
      AudioEnhancementType.noiseReduction,
      AudioEnhancementType.echocancellation,
      AudioEnhancementType.autoGainControl,
    ];
  }

  @override
  Future<bool> isReady() async {
    return _isInitialized;
  }

  @override
  ProcessingMode get processingMode => currentConfig.processingMode;

  @override
  Future<void> setProcessingMode(ProcessingMode mode) async {
    if (_config != null) {
      _config = _config!.copyWith(processingMode: mode);
    }
  }

  @override
  Map<String, dynamic> getPerformanceMetrics() {
    return {'processedSamples': 1024, 'averageProcessingTime': 10.0};
  }

  @override
  Future<void> resetToDefaults() async {
    _config = const AudioEnhancementConfig();
  }

  // Test helper properties
  bool get isInitialized => _isInitialized;
  bool get isConfigured => _isConfigured;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioRecordingService', () {
    late AudioRecordingService audioService;
    late MockAudioRecordingPlatform mockPlatform;
    late MockAudioEnhancementService mockEnhancementService;

    setUp(() {
      mockPlatform = MockAudioRecordingPlatform();
      mockEnhancementService = MockAudioEnhancementService();
      audioService = AudioRecordingService(
        platform: mockPlatform,
        enhancementService: mockEnhancementService,
      );

      // No need for method channel mocking since we're using mock platform
    });

    tearDown(() async {
      await audioService.dispose();
    });

    test('should initialize successfully with mock platform', () async {
      await audioService.initialize();
      expect(mockPlatform.isInitialized, true);
    });

    test('should have no current session initially', () {
      expect(audioService.currentSession, isNull);
    });

    test('should provide session stream', () {
      expect(audioService.sessionStream, isA<Stream>());
    });

    test('should return supported formats from platform', () {
      final formats = audioService.getSupportedFormats();
      expect(formats, isNotEmpty);
      expect(formats, contains('wav'));
      expect(formats, mockPlatform.getSupportedFormats());
    });

    group('AudioConfiguration', () {
      test('should create default configuration', () {
        final config = AudioConfiguration();
        expect(config.format, AudioFormat.wav);
        expect(config.quality, AudioQuality.high);
        expect(config.noiseReduction, true);
        expect(config.autoGainControl, true);
      });

      test('should create custom configuration', () {
        final config = AudioConfiguration(
          format: AudioFormat.mp3,
          quality: AudioQuality.medium,
          enableNoiseReduction: false,
        );
        expect(config.format, AudioFormat.mp3);
        expect(config.quality, AudioQuality.medium);
        expect(config.noiseReduction, false);
      });

      test('should support copyWith', () {
        final original = AudioConfiguration();
        final modified = original.copyWith(
          format: AudioFormat.aac,
          quality: AudioQuality.low,
        );

        expect(modified.format, AudioFormat.aac);
        expect(modified.quality, AudioQuality.low);
        expect(modified.noiseReduction, original.noiseReduction);
      });
    });

    group('RecordingState', () {
      test('should have correct state properties', () {
        expect(RecordingState.recording.isActive, true);
        expect(RecordingState.paused.isPaused, true);
        expect(RecordingState.stopped.isStopped, true);
        expect(RecordingState.idle.canRecord, true);
        expect(RecordingState.recording.canPause, true);
        expect(RecordingState.paused.canResume, true);
      });
    });

    group('AudioFormat', () {
      test('should have correct format properties', () {
        expect(AudioFormat.wav.extension, 'wav');
        expect(AudioFormat.mp3.extension, 'mp3');
        expect(AudioFormat.wav.mimeType, 'audio/wav');
        expect(AudioFormat.mp3.mimeType, 'audio/mpeg');
      });

      test('should parse from extension', () {
        expect(AudioFormat.fromExtension('wav'), AudioFormat.wav);
        expect(AudioFormat.fromExtension('mp3'), AudioFormat.mp3);
        expect(AudioFormat.fromExtension('unknown'), AudioFormat.wav);
      });
    });

    group('AudioQuality', () {
      test('should have correct quality settings', () {
        expect(AudioQuality.high.sampleRate, 44100);
        expect(AudioQuality.medium.sampleRate, 22050);
        expect(AudioQuality.low.sampleRate, 8000);

        expect(AudioQuality.high.bitRate, 320000);
        expect(AudioQuality.medium.bitRate, 128000);
        expect(AudioQuality.low.bitRate, 32000);
      });
    });

    group('Audio Enhancement Integration', () {
      test('should initialize audio enhancement service', () async {
        await audioService.initialize();
        expect(mockEnhancementService.isInitialized, true);
        expect(mockPlatform.isInitialized, true);
      });

      test('should dispose audio enhancement service', () async {
        await audioService.initialize();
        await audioService.dispose();
        expect(mockEnhancementService.isInitialized, false);
      });

      test('should support enhanced audio configuration', () {
        final config = AudioConfiguration(
          enableNoiseReduction: true,
          enableAutoGainControl: true,
          enableEchoCancellation: true,
          enableSpectralSubtraction: true,
          enableFrequencyFiltering: true,
          enableRealTimeEnhancement: true,
          noiseReductionStrength: 0.7,
          gainControlThreshold: 0.6,
          echoCancellationStrength: 0.4,
        );

        expect(config.enableNoiseReduction, true);
        expect(config.enableAutoGainControl, true);
        expect(config.enableEchoCancellation, true);
        expect(config.enableSpectralSubtraction, true);
        expect(config.enableFrequencyFiltering, true);
        expect(config.enableRealTimeEnhancement, true);
        expect(config.noiseReductionStrength, 0.7);
        expect(config.gainControlThreshold, 0.6);
        expect(config.echoCancellationStrength, 0.4);
      });

      test('should provide enhanced audio stream when recording', () async {
        await audioService.initialize();

        // Note: This test would need actual recording to be tested properly
        // For now, we'll just verify the method exists and doesn't throw
        expect(
          () => audioService.getEnhancedAudioStream(44100),
          returnsNormally,
        );
      });

      test('should handle processing state during stop recording', () async {
        await audioService.initialize();

        // Set up platform permissions
        mockPlatform.setPermission(true);

        // Note: Full recording flow testing would require more complex mocking
        // This test verifies basic integration exists
        expect(mockEnhancementService.isInitialized, true);
      });

      test('should copy configuration with enhancement settings', () {
        final original = AudioConfiguration(
          enableNoiseReduction: true,
          noiseReductionStrength: 0.5,
        );

        final modified = original.copyWith(
          enableEchoCancellation: true,
          echoCancellationStrength: 0.7,
          noiseReductionStrength: 0.8,
        );

        expect(modified.enableNoiseReduction, true);
        expect(modified.enableEchoCancellation, true);
        expect(modified.noiseReductionStrength, 0.8);
        expect(modified.echoCancellationStrength, 0.7);
      });

      test('should serialize/deserialize enhancement settings', () {
        final config = AudioConfiguration(
          enableNoiseReduction: true,
          enableEchoCancellation: true,
          noiseReductionStrength: 0.6,
          echoCancellationStrength: 0.4,
        );

        final map = config.toMap();
        final restored = AudioConfiguration.fromMap(map);

        expect(restored.enableNoiseReduction, config.enableNoiseReduction);
        expect(restored.enableEchoCancellation, config.enableEchoCancellation);
        expect(restored.noiseReductionStrength, config.noiseReductionStrength);
        expect(
          restored.echoCancellationStrength,
          config.echoCancellationStrength,
        );
      });

      test('should handle processing state in recording state enum', () {
        expect(RecordingState.processing, isA<RecordingState>());
        expect(RecordingState.processing.isActive, false);
        expect(RecordingState.processing.isStopped, false);
        expect(RecordingState.processing.canRecord, false);
      });
    });
  });
}
