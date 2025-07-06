import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/enums/audio_format.dart';
import 'package:meeting_summarizer/core/enums/audio_quality.dart';
import 'package:meeting_summarizer/core/models/audio_configuration.dart';
import 'package:meeting_summarizer/features/audio_recording/data/platform/audio_recording_platform.dart';
import 'package:meeting_summarizer/features/audio_recording/data/platform/record_platform_adapter.dart';

/// Mock platform implementation for testing
class MockAudioRecordingPlatform extends AudioRecordingPlatform {
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isPaused = false;
  bool _hasPermission = true;
  String? _currentFilePath;
  double _currentAmplitude = 0.5;

  // Expose private fields for testing
  bool get isInitialized => _isInitialized;
  String? get currentFilePath => _currentFilePath;
  bool get isPausedState => _isPaused;

  @override
  Future<void> initialize() async {
    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    _isRecording = false;
    _isPaused = false;
  }

  @override
  Future<void> startRecording({
    required AudioConfiguration configuration,
    required String filePath,
  }) async {
    if (!_isInitialized) {
      throw Exception('Platform not initialized');
    }
    if (!_hasPermission) {
      throw Exception('Microphone permission not granted');
    }
    _currentFilePath = filePath;
    _isRecording = true;
    _isPaused = false;
  }

  @override
  Future<void> pauseRecording() async {
    if (!_isRecording || _isPaused) {
      throw Exception('No active recording to pause');
    }
    _isPaused = true;
  }

  @override
  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused) {
      throw Exception('No paused recording to resume');
    }
    _isPaused = false;
  }

  @override
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      throw Exception('No recording to stop');
    }
    _isRecording = false;
    _isPaused = false;
    return _currentFilePath;
  }

  @override
  Future<void> cancelRecording() async {
    _isRecording = false;
    _isPaused = false;
    _currentFilePath = null;
  }

  @override
  Future<bool> isRecording() async {
    return _isRecording && !_isPaused;
  }

  @override
  Future<double> getAmplitude() async {
    return _isRecording && !_isPaused ? _currentAmplitude : 0.0;
  }

  @override
  Future<bool> hasPermission() async {
    return _hasPermission;
  }

  @override
  Future<bool> requestPermission() async {
    _hasPermission = true;
    return true;
  }

  @override
  List<String> getSupportedFormats() {
    return ['wav', 'mp3', 'm4a', 'aac'];
  }

  // Test helpers
  void setPermission(bool hasPermission) {
    _hasPermission = hasPermission;
  }

  void setAmplitude(double amplitude) {
    _currentAmplitude = amplitude;
  }
}

void main() {
  group('AudioRecordingPlatform', () {
    late MockAudioRecordingPlatform platform;
    late AudioConfiguration testConfig;

    setUp(() {
      platform = MockAudioRecordingPlatform();
      testConfig = const AudioConfiguration(
        format: AudioFormat.wav,
        quality: AudioQuality.high,
      );
    });

    group('Platform Creation', () {
      test('should create appropriate platform instance', () {
        // Note: This test would need platform-specific mocking in a real scenario
        expect(AudioRecordingPlatform.create, returnsNormally);
      });
    });

    group('Platform Lifecycle', () {
      test('should initialize successfully', () async {
        await platform.initialize();
        expect(platform.isInitialized, true);
      });

      test('should dispose successfully', () async {
        await platform.initialize();
        await platform.dispose();
        expect(platform.isInitialized, false);
      });
    });

    group('Recording Operations', () {
      setUp(() async {
        await platform.initialize();
      });

      test('should start recording with valid configuration', () async {
        const filePath = '/test/recording.wav';

        await platform.startRecording(
          configuration: testConfig,
          filePath: filePath,
        );

        expect(await platform.isRecording(), true);
        expect(platform.currentFilePath, filePath);
      });

      test('should fail to start recording without permission', () async {
        platform.setPermission(false);

        expect(
          () => platform.startRecording(
            configuration: testConfig,
            filePath: '/test/recording.wav',
          ),
          throwsException,
        );
      });

      test('should pause and resume recording', () async {
        await platform.startRecording(
          configuration: testConfig,
          filePath: '/test/recording.wav',
        );

        await platform.pauseRecording();
        expect(platform.isPausedState, true);
        expect(await platform.isRecording(), false);

        await platform.resumeRecording();
        expect(platform.isPausedState, false);
        expect(await platform.isRecording(), true);
      });

      test('should stop recording and return file path', () async {
        const filePath = '/test/recording.wav';

        await platform.startRecording(
          configuration: testConfig,
          filePath: filePath,
        );

        final resultPath = await platform.stopRecording();
        expect(resultPath, filePath);
        expect(await platform.isRecording(), false);
      });

      test('should cancel recording', () async {
        await platform.startRecording(
          configuration: testConfig,
          filePath: '/test/recording.wav',
        );

        await platform.cancelRecording();
        expect(await platform.isRecording(), false);
        expect(platform.currentFilePath, null);
      });
    });

    group('Audio Monitoring', () {
      setUp(() async {
        await platform.initialize();
      });

      test('should return amplitude when recording', () async {
        platform.setAmplitude(0.8);

        await platform.startRecording(
          configuration: testConfig,
          filePath: '/test/recording.wav',
        );

        final amplitude = await platform.getAmplitude();
        expect(amplitude, 0.8);
      });

      test('should return zero amplitude when not recording', () async {
        platform.setAmplitude(0.8);

        final amplitude = await platform.getAmplitude();
        expect(amplitude, 0.0);
      });
    });

    group('Permission Management', () {
      test('should check permission status', () async {
        platform.setPermission(true);
        expect(await platform.hasPermission(), true);

        platform.setPermission(false);
        expect(await platform.hasPermission(), false);
      });

      test('should request permission successfully', () async {
        platform.setPermission(false);
        expect(await platform.hasPermission(), false);

        final granted = await platform.requestPermission();
        expect(granted, true);
        expect(await platform.hasPermission(), true);
      });
    });

    group('Format Support', () {
      test('should return supported formats', () {
        final formats = platform.getSupportedFormats();
        expect(formats, isNotEmpty);
        expect(formats, contains('wav'));
      });
    });
  });

  group('RecordPlatformAdapter', () {
    late RecordPlatformAdapter adapter;

    setUp(() {
      adapter = RecordPlatformAdapter();
    });

    tearDown(() async {
      await adapter.dispose();
    });

    test('should initialize without errors', () async {
      expect(() => adapter.initialize(), returnsNormally);
    });

    test('should dispose without errors', () async {
      await adapter.initialize();
      expect(() => adapter.dispose(), returnsNormally);
    });

    test('should return platform-specific supported formats', () {
      final formats = adapter.getSupportedFormats();
      expect(formats, isNotEmpty);
      expect(formats, contains('wav'));
    });
  });
}
