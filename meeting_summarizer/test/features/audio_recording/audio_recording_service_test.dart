import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/enums/audio_format.dart';
import 'package:meeting_summarizer/core/enums/audio_quality.dart';
import 'package:meeting_summarizer/core/enums/recording_state.dart';
import 'package:meeting_summarizer/core/models/audio_configuration.dart';
import 'package:meeting_summarizer/features/audio_recording/data/audio_recording_service.dart';

import 'platform/audio_recording_platform_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioRecordingService', () {
    late AudioRecordingService audioService;
    late MockAudioRecordingPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockAudioRecordingPlatform();
      audioService = AudioRecordingService(platform: mockPlatform);

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
        const config = AudioConfiguration();
        expect(config.format, AudioFormat.wav);
        expect(config.quality, AudioQuality.high);
        expect(config.noiseReduction, true);
        expect(config.autoGainControl, true);
      });

      test('should create custom configuration', () {
        const config = AudioConfiguration(
          format: AudioFormat.mp3,
          quality: AudioQuality.medium,
          noiseReduction: false,
        );
        expect(config.format, AudioFormat.mp3);
        expect(config.quality, AudioQuality.medium);
        expect(config.noiseReduction, false);
      });

      test('should support copyWith', () {
        const original = AudioConfiguration();
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
  });
}
