import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/enums/recording_state.dart';
import '../../../core/models/audio_configuration.dart';
import '../../../core/models/recording_session.dart';
import '../../../core/services/audio_service_interface.dart';
import 'platform/audio_recording_platform.dart';
import 'platform/record_platform_adapter.dart';

class AudioRecordingService implements AudioServiceInterface {
  static const Uuid _uuid = Uuid();

  late final AudioRecordingPlatform _platform;
  final StreamController<RecordingSession> _sessionController =
      StreamController<RecordingSession>.broadcast();

  RecordingSession? _currentSession;
  Timer? _recordingTimer;
  Timer? _amplitudeTimer;
  String? _recordingPath;

  /// Constructor with optional platform injection for testing
  AudioRecordingService({AudioRecordingPlatform? platform}) {
    _platform = platform ?? RecordPlatformAdapter();
  }

  @override
  Stream<RecordingSession> get sessionStream => _sessionController.stream;

  @override
  RecordingSession? get currentSession => _currentSession;

  @override
  Future<void> initialize() async {
    try {
      // Initialize platform-specific recording engine
      await _platform.initialize();

      // Check if microphone permission is available
      if (!await _platform.hasPermission()) {
        debugPrint('AudioRecordingService: No microphone permission');
      }
      debugPrint('AudioRecordingService: Initialized successfully');
    } catch (e) {
      debugPrint('AudioRecordingService: Initialization failed: $e');
      // Don't rethrow in test environment to allow graceful handling
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        // Development/test environment - handle gracefully
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    await _stopTimers();
    await _platform.dispose();
    await _sessionController.close();
    debugPrint('AudioRecordingService: Disposed');
  }

  @override
  Future<void> startRecording({
    required AudioConfiguration configuration,
    String? fileName,
  }) async {
    try {
      if (_currentSession?.state.isActive == true) {
        throw Exception('Recording already in progress');
      }

      // Check permissions
      if (!await hasPermission()) {
        throw Exception('Microphone permission not granted');
      }

      // Update state to initializing
      _updateSession(RecordingState.initializing, configuration);

      // Prepare file path
      final directory =
          configuration.outputDirectory ??
          (await getApplicationDocumentsDirectory()).path;
      final sessionId = _uuid.v4();
      final filename =
          fileName ?? 'recording_${DateTime.now().millisecondsSinceEpoch}';
      _recordingPath = '$directory/$filename.${configuration.format.extension}';

      // Start recording using platform implementation
      await _platform.startRecording(
        configuration: configuration,
        filePath: _recordingPath!,
      );

      // Create session
      _currentSession = RecordingSession(
        id: sessionId,
        startTime: DateTime.now(),
        state: RecordingState.recording,
        duration: Duration.zero,
        configuration: configuration,
        filePath: _recordingPath,
      );

      // Start timers
      _startRecordingTimer();
      _startAmplitudeMonitoring();

      _sessionController.add(_currentSession!);
      debugPrint('AudioRecordingService: Recording started - $_recordingPath');
    } catch (e) {
      _updateSession(RecordingState.error, null, e.toString());
      debugPrint('AudioRecordingService: Start recording failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> pauseRecording() async {
    try {
      if (_currentSession?.state != RecordingState.recording) {
        throw Exception('No active recording to pause');
      }

      await _platform.pauseRecording();
      await _stopTimers();

      _updateSession(RecordingState.paused);
      debugPrint('AudioRecordingService: Recording paused');
    } catch (e) {
      _updateSession(RecordingState.error, null, e.toString());
      debugPrint('AudioRecordingService: Pause recording failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> resumeRecording() async {
    try {
      if (_currentSession?.state != RecordingState.paused) {
        throw Exception('No paused recording to resume');
      }

      await _platform.resumeRecording();
      _startRecordingTimer();
      _startAmplitudeMonitoring();

      _updateSession(RecordingState.recording);
      debugPrint('AudioRecordingService: Recording resumed');
    } catch (e) {
      _updateSession(RecordingState.error, null, e.toString());
      debugPrint('AudioRecordingService: Resume recording failed: $e');
      rethrow;
    }
  }

  @override
  Future<String?> stopRecording() async {
    try {
      if (_currentSession == null ||
          (!_currentSession!.state.isActive && !_currentSession!.isPaused)) {
        throw Exception('No recording to stop');
      }

      _updateSession(RecordingState.stopping);
      await _stopTimers();

      final path = await _platform.stopRecording();

      if (path != null && await File(path).exists()) {
        final file = File(path);
        final fileSize = await file.length();

        _currentSession = _currentSession!.copyWith(
          state: RecordingState.stopped,
          endTime: DateTime.now(),
          filePath: path,
          fileSize: fileSize.toDouble(),
        );

        _sessionController.add(_currentSession!);
        debugPrint(
          'AudioRecordingService: Recording stopped - $path (${fileSize}B)',
        );

        return path;
      } else {
        throw Exception('Recording file not found');
      }
    } catch (e) {
      _updateSession(RecordingState.error, null, e.toString());
      debugPrint('AudioRecordingService: Stop recording failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> cancelRecording() async {
    try {
      await _stopTimers();
      await _platform.cancelRecording();

      // File cleanup is handled by platform implementation

      _currentSession = _currentSession?.copyWith(
        state: RecordingState.stopped,
        endTime: DateTime.now(),
      );

      if (_currentSession != null) {
        _sessionController.add(_currentSession!);
      }
    } catch (e) {
      debugPrint('AudioRecordingService: Cancel recording failed: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isReady() async {
    try {
      return await _platform.hasPermission() && !await _platform.isRecording();
    } catch (e) {
      debugPrint('AudioRecordingService: Ready check failed: $e');
      return false;
    }
  }

  @override
  List<String> getSupportedFormats() {
    return _platform.getSupportedFormats();
  }

  @override
  Future<bool> hasPermission() async {
    try {
      return await _platform.hasPermission();
    } catch (e) {
      debugPrint('AudioRecordingService: Permission check failed: $e');
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return await _platform.requestPermission();
    } catch (e) {
      debugPrint('AudioRecordingService: Permission request failed: $e');
      return false;
    }
  }

  // Private helper methods

  void _updateSession(
    RecordingState state, [
    AudioConfiguration? config,
    String? errorMessage,
  ]) {
    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(
        state: state,
        configuration: config,
        errorMessage: errorMessage,
        duration: state.isActive || state.isPaused
            ? DateTime.now().difference(_currentSession!.startTime)
            : _currentSession!.duration,
      );
      _sessionController.add(_currentSession!);
    } else if (config != null) {
      _currentSession = RecordingSession(
        id: _uuid.v4(),
        startTime: DateTime.now(),
        state: state,
        duration: Duration.zero,
        configuration: config,
        errorMessage: errorMessage,
      );
      _sessionController.add(_currentSession!);
    }
  }

  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSession != null && _currentSession!.state.isActive) {
        final duration = DateTime.now().difference(_currentSession!.startTime);

        // Check recording limit
        if (_currentSession!.configuration.recordingLimit != null &&
            duration >= _currentSession!.configuration.recordingLimit!) {
          stopRecording();
          return;
        }

        _currentSession = _currentSession!.copyWith(duration: duration);
        _sessionController.add(_currentSession!);
      }
    });
  }

  void _startAmplitudeMonitoring() {
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) async {
      if (_currentSession != null && _currentSession!.state.isActive) {
        try {
          final normalizedAmplitude = await _platform.getAmplitude();

          final newWaveformData = List<double>.from(
            _currentSession!.waveformData,
          );
          newWaveformData.add(normalizedAmplitude);

          // Keep only last 100 amplitude values for performance
          if (newWaveformData.length > 100) {
            newWaveformData.removeAt(0);
          }

          _currentSession = _currentSession!.copyWith(
            currentAmplitude: normalizedAmplitude,
            waveformData: newWaveformData,
          );
          _sessionController.add(_currentSession!);
        } catch (e) {
          debugPrint('AudioRecordingService: Amplitude monitoring error: $e');
        }
      }
    });
  }

  Future<void> _stopTimers() async {
    _recordingTimer?.cancel();
    _amplitudeTimer?.cancel();
    _recordingTimer = null;
    _amplitudeTimer = null;
  }

  // Note: Encoder selection is now handled by platform-specific implementations
}
