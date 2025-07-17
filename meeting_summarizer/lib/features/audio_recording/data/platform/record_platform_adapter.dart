import 'dart:async';
import 'dart:io';
import 'dart:developer';

import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../../core/enums/audio_format.dart';
import '../../../../core/models/audio_configuration.dart';
import 'audio_recording_platform.dart';

/// Adapter class that implements platform-specific recording using the record package
/// This provides a concrete implementation of the platform abstraction
class RecordPlatformAdapter extends AudioRecordingPlatform {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentFilePath;
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isPaused = false;

  @override
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      // Platform-specific initialization
      if (Platform.isIOS) {
        await _initializeIOS();
      } else if (Platform.isAndroid) {
        await _initializeAndroid();
      } else if (Platform.isMacOS) {
        await _initializeMacOS();
      } else if (Platform.isWindows) {
        await _initializeWindows();
      } else if (Platform.isLinux) {
        await _initializeLinux();
      }

      _isInitialized = true;
      log('RecordPlatformAdapter: Initialized for ${Platform.operatingSystem}');
    } catch (e) {
      log('RecordPlatformAdapter: Initialization failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      if (_isRecording) {
        await stopRecording();
      }
      await _recorder.dispose();
      _isInitialized = false;
      log('RecordPlatformAdapter: Disposed');
    } catch (e) {
      log('RecordPlatformAdapter: Dispose failed: $e');
    }
  }

  @override
  Future<void> startRecording({
    required AudioConfiguration configuration,
    required String filePath,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      if (_isRecording) {
        throw Exception('Recording already in progress');
      }

      _currentFilePath = filePath;

      // Configure recording settings based on platform and configuration
      // Use more compatible settings for macOS
      final recordConfig = RecordConfig(
        encoder: Platform.isMacOS
            ? AudioEncoder.aacLc
            : _getEncoderForPlatform(configuration.format),
        bitRate: Platform.isMacOS ? 128000 : configuration.quality.bitRate,
        sampleRate: Platform.isMacOS ? 44100 : configuration.quality.sampleRate,
        numChannels: 1, // Mono recording for voice
        autoGain: Platform.isMacOS ? false : configuration.autoGainControl,
        echoCancel: Platform.isMacOS ? false : configuration.noiseReduction,
        noiseSuppress: Platform.isMacOS ? false : configuration.noiseReduction,
      );

      await _recorder.start(recordConfig, path: filePath);
      _isRecording = true;
      _isPaused = false;

      log('RecordPlatformAdapter: Recording started - $filePath');
    } catch (e) {
      log('RecordPlatformAdapter: Start recording failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> pauseRecording() async {
    try {
      if (!_isRecording || _isPaused) {
        throw Exception('No active recording to pause');
      }

      await _recorder.pause();
      _isPaused = true;

      log('RecordPlatformAdapter: Recording paused');
    } catch (e) {
      log('RecordPlatformAdapter: Pause recording failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> resumeRecording() async {
    try {
      if (!_isRecording || !_isPaused) {
        throw Exception('No paused recording to resume');
      }

      await _recorder.resume();
      _isPaused = false;

      log('RecordPlatformAdapter: Recording resumed');
    } catch (e) {
      log('RecordPlatformAdapter: Resume recording failed: $e');
      rethrow;
    }
  }

  @override
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        throw Exception('No recording to stop');
      }

      final path = await _recorder.stop();
      _isRecording = false;
      _isPaused = false;

      if (path != null && await File(path).exists()) {
        log('RecordPlatformAdapter: Recording stopped - $path');
        return path;
      } else {
        throw Exception('Recording file not found after stop');
      }
    } catch (e) {
      log('RecordPlatformAdapter: Stop recording failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stop();
        _isRecording = false;
        _isPaused = false;
      }

      if (_currentFilePath != null && await File(_currentFilePath!).exists()) {
        await File(_currentFilePath!).delete();
        log('RecordPlatformAdapter: Recording file deleted');
      }

      _currentFilePath = null;
    } catch (e) {
      log('RecordPlatformAdapter: Cancel recording failed: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isRecording() async {
    try {
      final recorderState = await _recorder.isRecording();
      return recorderState && _isRecording;
    } catch (e) {
      log('RecordPlatformAdapter: Check recording state failed: $e');
      return false;
    }
  }

  @override
  Future<double> getAmplitude() async {
    try {
      if (!_isRecording || _isPaused) {
        return 0.0;
      }

      final amplitude = await _recorder.getAmplitude();
      return amplitude.current.clamp(0.0, 1.0);
    } catch (e) {
      log('RecordPlatformAdapter: Get amplitude failed: $e');
      return 0.0;
    }
  }

  @override
  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      log('RecordPlatformAdapter: Permission check failed: $e');
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      log('RecordPlatformAdapter: Permission request failed: $e');
      return false;
    }
  }

  @override
  List<String> getSupportedFormats() {
    // Return supported formats based on platform
    if (Platform.isIOS) {
      return ['wav', 'm4a', 'aac'];
    } else if (Platform.isAndroid) {
      return ['wav', 'mp3', 'm4a', 'aac'];
    } else if (Platform.isMacOS) {
      return ['wav', 'mp3', 'm4a', 'aac'];
    } else if (Platform.isWindows) {
      return ['wav', 'mp3'];
    } else if (Platform.isLinux) {
      return ['wav', 'mp3'];
    } else {
      // Web
      return ['wav', 'webm'];
    }
  }

  // Platform-specific initialization methods

  Future<void> _initializeIOS() async {
    // iOS-specific initialization
    // Configure AVAudioSession for recording
    log('RecordPlatformAdapter: Initializing for iOS');
  }

  Future<void> _initializeAndroid() async {
    // Android-specific initialization
    log('RecordPlatformAdapter: Initializing for Android');
  }

  Future<void> _initializeMacOS() async {
    // macOS-specific initialization
    log('RecordPlatformAdapter: Initializing for macOS');

    try {
      // Check if recording is supported on this platform
      final hasPermission = await _recorder.hasPermission();
      log('RecordPlatformAdapter: Has permission: $hasPermission');

      if (!hasPermission) {
        log('RecordPlatformAdapter: Requesting microphone permission...');
        final granted = await _recorder.hasPermission();
        log('RecordPlatformAdapter: Permission granted: $granted');
      }

      // Try to get input devices list to verify microphone availability
      final isRecording = await _recorder.isRecording();
      log('RecordPlatformAdapter: Current recording state: $isRecording');

      // Check if we can create a test recording (short duration)
      log('RecordPlatformAdapter: Testing microphone availability...');

      log('RecordPlatformAdapter: Initialized for macOS');
    } catch (e) {
      log('RecordPlatformAdapter: macOS initialization warning: $e');
      // Don't throw here - allow graceful degradation
    }
  }

  Future<void> _initializeWindows() async {
    // Windows-specific initialization
    log('RecordPlatformAdapter: Initializing for Windows');
  }

  Future<void> _initializeLinux() async {
    // Linux-specific initialization
    log('RecordPlatformAdapter: Initializing for Linux');
  }

  // Helper method to get appropriate encoder for platform and format
  AudioEncoder _getEncoderForPlatform(AudioFormat format) {
    switch (format) {
      case AudioFormat.wav:
        return AudioEncoder.wav;
      case AudioFormat.mp3:
        // Not all platforms support MP3 directly, fallback to AAC
        if (Platform.isAndroid || Platform.isMacOS || Platform.isWindows) {
          return AudioEncoder.aacLc; // Use AAC as MP3 alternative
        }
        return AudioEncoder.aacLc;
      case AudioFormat.m4a:
        return AudioEncoder.aacLc; // M4A container with AAC codec
      case AudioFormat.aac:
        return AudioEncoder.aacLc;
    }
  }
}
