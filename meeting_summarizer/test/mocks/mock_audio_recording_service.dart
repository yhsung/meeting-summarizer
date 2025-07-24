import 'dart:async';
import 'dart:math' as math;
import 'dart:developer';
import 'dart:typed_data';

import 'package:meeting_summarizer/core/enums/recording_state.dart';
import 'package:meeting_summarizer/core/models/audio_configuration.dart';
import 'package:meeting_summarizer/core/models/recording_session.dart';
import 'package:meeting_summarizer/core/models/permission_guidance.dart';
import 'package:meeting_summarizer/core/services/audio_service_interface.dart';
import 'package:meeting_summarizer/core/services/permission_service_interface.dart';

/// Comprehensive mock audio recording service for testing
class MockAudioRecordingService implements AudioServiceInterface {
  static const int _maxRecordingDuration = 300; // 5 minutes max for tests
  static const int _defaultSampleRate = 44100;

  // State management
  RecordingSession? _currentSession;
  Timer? _recordingTimer;
  Timer? _amplitudeTimer;
  bool _isInitialized = false;
  bool _hasPermission = true;
  String? _recordingPath;
  int _sessionCounter = 0;

  // Mock behavior configuration
  bool _shouldFailPermission = false;
  bool _shouldFailRecording = false;
  bool _shouldFailInitialization = false;
  double _mockAmplitude = 0.5;
  Duration _mockInitializationDelay = Duration.zero;
  Duration _mockRecordingDelay = Duration.zero;

  // Streams
  final StreamController<RecordingSession> _sessionController =
      StreamController<RecordingSession>.broadcast();

  @override
  Stream<RecordingSession> get sessionStream => _sessionController.stream;

  @override
  RecordingSession? get currentSession => _currentSession;

  // Mock configuration methods for testing

  /// Configure mock to simulate permission failures
  void setMockPermissionFailure(bool shouldFail) {
    _shouldFailPermission = shouldFail;
    _hasPermission = !shouldFail;
  }

  /// Configure mock to simulate recording failures
  void setMockRecordingFailure(bool shouldFail) {
    _shouldFailRecording = shouldFail;
  }

  /// Configure mock to simulate initialization failures
  void setMockInitializationFailure(bool shouldFail) {
    _shouldFailInitialization = shouldFail;
  }

  /// Set mock amplitude value for testing
  void setMockAmplitude(double amplitude) {
    _mockAmplitude = math.max(0.0, math.min(1.0, amplitude));
  }

  /// Set mock delays for testing timing scenarios
  void setMockDelays({
    Duration? initializationDelay,
    Duration? recordingDelay,
  }) {
    _mockInitializationDelay = initializationDelay ?? Duration.zero;
    _mockRecordingDelay = recordingDelay ?? Duration.zero;
  }

  /// Reset all mock state to defaults
  void resetMockState() {
    _shouldFailPermission = false;
    _shouldFailRecording = false;
    _shouldFailInitialization = false;
    _hasPermission = true;
    _mockAmplitude = 0.5;
    _mockInitializationDelay = Duration.zero;
    _mockRecordingDelay = Duration.zero;
    _sessionCounter = 0;
  }

  @override
  Future<void> initialize() async {
    if (_shouldFailInitialization) {
      throw Exception('Mock initialization failure');
    }

    if (_mockInitializationDelay > Duration.zero) {
      await Future.delayed(_mockInitializationDelay);
    }

    _isInitialized = true;
    log('MockAudioRecordingService: Initialized successfully');
  }

  @override
  Future<void> dispose() async {
    await _stopTimers();
    _isInitialized = false;
    _currentSession = null;
    _recordingPath = null;
    await _sessionController.close();
    log('MockAudioRecordingService: Disposed');
  }

  @override
  Future<void> startRecording({
    required AudioConfiguration configuration,
    String? fileName,
  }) async {
    if (!_isInitialized) {
      throw StateError('Service not initialized');
    }

    if (_currentSession?.state.isActive == true) {
      throw Exception('Recording already in progress');
    }

    if (_shouldFailPermission) {
      throw Exception('No permission to record audio');
    }

    if (_shouldFailRecording) {
      throw Exception('Mock recording failure');
    }

    if (_mockRecordingDelay > Duration.zero) {
      await Future.delayed(_mockRecordingDelay);
    }

    // Generate mock session
    _sessionCounter++;
    final sessionId = 'mock_session_$_sessionCounter';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final mockFileName = fileName ?? 'mock_recording_$timestamp';
    _recordingPath =
        '/mock/path/$mockFileName.${configuration.format.extension}';

    _currentSession = RecordingSession(
      id: sessionId,
      startTime: DateTime.now(),
      state: RecordingState.recording,
      duration: Duration.zero,
      configuration: configuration,
      filePath: _recordingPath,
    );

    _startRecordingTimer();
    _startAmplitudeMonitoring();
    _sessionController.add(_currentSession!);

    log('MockAudioRecordingService: Recording started - $_recordingPath');
  }

  @override
  Future<void> pauseRecording() async {
    if (_currentSession?.state != RecordingState.recording) {
      throw Exception('No active recording to pause');
    }

    await _stopTimers();
    _updateSession(RecordingState.paused);
    log('MockAudioRecordingService: Recording paused');
  }

  @override
  Future<void> resumeRecording() async {
    if (_currentSession?.state != RecordingState.paused) {
      throw Exception('No paused recording to resume');
    }

    _startRecordingTimer();
    _startAmplitudeMonitoring();
    _updateSession(RecordingState.recording);
    log('MockAudioRecordingService: Recording resumed');
  }

  @override
  Future<String?> stopRecording() async {
    if (_currentSession == null ||
        (!_currentSession!.state.isActive && !_currentSession!.isPaused)) {
      throw Exception('No recording to stop');
    }

    _updateSession(RecordingState.stopping);
    await _stopTimers();

    // Simulate file creation and size calculation
    final mockFileSize = _calculateMockFileSize(
      _currentSession!.duration,
      _currentSession!.configuration,
    );

    _currentSession = _currentSession!.copyWith(
      state: RecordingState.stopped,
      endTime: DateTime.now(),
      fileSize: mockFileSize,
    );

    _sessionController.add(_currentSession!);

    final path = _recordingPath;
    log(
      'MockAudioRecordingService: Recording stopped - $path (${mockFileSize}B)',
    );
    return path;
  }

  @override
  Future<void> cancelRecording() async {
    await _stopTimers();

    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(
        state: RecordingState.stopped,
        endTime: DateTime.now(),
      );
      _sessionController.add(_currentSession!);
    }

    _recordingPath = null;
    log('MockAudioRecordingService: Recording cancelled');
  }

  @override
  Future<bool> isReady() async {
    return _isInitialized &&
        _hasPermission &&
        (_currentSession?.state.isActive != true);
  }

  @override
  List<String> getSupportedFormats() {
    return ['wav', 'mp3', 'aac', 'm4a'];
  }

  @override
  Future<bool> hasPermission() async {
    return _hasPermission;
  }

  @override
  Future<bool> requestPermission() async {
    if (_shouldFailPermission) {
      return false;
    }
    _hasPermission = true;
    return true;
  }

  /// Provides mock enhanced audio stream for testing
  Stream<Float32List> getEnhancedAudioStream(int sampleRate) async* {
    if (_currentSession == null || !_currentSession!.state.isActive) {
      throw StateError('No active recording session');
    }

    final effectiveSampleRate = sampleRate > 0
        ? sampleRate
        : _defaultSampleRate;
    const chunkSize = 1024;
    const chunkDuration = Duration(milliseconds: 50);

    while (_currentSession?.state.isActive == true) {
      final audioChunk = _generateMockAudioChunk(
        chunkSize,
        effectiveSampleRate,
      );
      yield audioChunk;
      await Future.delayed(chunkDuration);
    }
  }

  /// Generate mock permission results for testing
  Future<PermissionResult> mockRequestPermissionWithGuidance({
    String? customRationale,
    bool forceRequest = false,
  }) async {
    if (_shouldFailPermission) {
      return PermissionResult.denied(errorMessage: 'Mock permission denied');
    }

    return PermissionResult.granted();
  }

  /// Mock permission recovery for testing
  Future<PermissionRecoveryResult> mockAttemptPermissionRecovery() async {
    if (_shouldFailPermission) {
      return PermissionRecoveryResult(
        success: false,
        message: 'Mock permission recovery failed',
        requiresUserAction: true,
        recommendedAction: 'Grant permission in settings',
      );
    }

    return PermissionRecoveryResult(
      success: true,
      message: 'Mock permission recovery successful',
    );
  }

  /// Mock recording readiness check for testing
  Future<RecordingReadinessResult> mockCheckRecordingReadiness() async {
    if (_shouldFailPermission) {
      return RecordingReadinessResult(
        isReady: false,
        reason: 'Mock permission required',
        guidance: 'Grant microphone permission to proceed',
        canRecover: true,
        recommendedAction: 'Request permission',
      );
    }

    if (!_isInitialized) {
      return RecordingReadinessResult(
        isReady: false,
        reason: 'Mock service not initialized',
        guidance: 'Initialize the service first',
        canRecover: true,
        recommendedAction: 'Call initialize()',
      );
    }

    return RecordingReadinessResult(
      isReady: true,
      reason: 'Mock ready to record',
      guidance: 'All systems ready for recording',
    );
  }

  // Private helper methods

  void _updateSession(RecordingState state, [String? errorMessage]) {
    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(
        state: state,
        errorMessage: errorMessage,
        duration: state.isActive || state.isPaused
            ? DateTime.now().difference(_currentSession!.startTime)
            : _currentSession!.duration,
      );
      _sessionController.add(_currentSession!);
    }
  }

  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSession != null && _currentSession!.state.isActive) {
        final duration = DateTime.now().difference(_currentSession!.startTime);

        // Auto-stop at max duration
        if (duration.inSeconds >= _maxRecordingDuration) {
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
    ) {
      if (_currentSession != null && _currentSession!.state.isActive) {
        // Generate realistic amplitude variation
        final baseAmplitude = _mockAmplitude;
        final variation = (math.Random().nextDouble() - 0.5) * 0.2;
        final amplitude = math.max(
          0.0,
          math.min(1.0, baseAmplitude + variation),
        );

        final newWaveformData = List<double>.from(
          _currentSession!.waveformData,
        );
        newWaveformData.add(amplitude);

        // Keep only last 100 amplitude values
        if (newWaveformData.length > 100) {
          newWaveformData.removeAt(0);
        }

        _currentSession = _currentSession!.copyWith(
          currentAmplitude: amplitude,
          waveformData: newWaveformData,
        );
        _sessionController.add(_currentSession!);
      }
    });
  }

  Future<void> _stopTimers() async {
    _recordingTimer?.cancel();
    _amplitudeTimer?.cancel();
    _recordingTimer = null;
    _amplitudeTimer = null;
  }

  double _calculateMockFileSize(Duration duration, AudioConfiguration config) {
    // Calculate approximate file size based on audio configuration
    final durationSeconds = duration.inMilliseconds / 1000.0;
    final bitRate = config.bitRate ?? 128000; // Default to 128kbps
    final bytesPerSecond = bitRate / 8.0;
    return durationSeconds * bytesPerSecond;
  }

  Float32List _generateMockAudioChunk(int chunkSize, int sampleRate) {
    final audioChunk = Float32List(chunkSize);
    final now = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < chunkSize; i++) {
      // Generate test signal with controlled amplitude
      final t = (now + i) / 1000.0;
      final signal =
          _mockAmplitude *
          0.1 *
          (math.sin(2 * math.pi * 440 * t) + // 440 Hz tone
              0.05 *
                  (math.Random().nextDouble() - 0.5) // Some noise
                  );
      audioChunk[i] = signal;
    }

    return audioChunk;
  }

  /// Get current mock state for debugging
  Map<String, dynamic> getMockState() {
    return {
      'isInitialized': _isInitialized,
      'hasPermission': _hasPermission,
      'shouldFailPermission': _shouldFailPermission,
      'shouldFailRecording': _shouldFailRecording,
      'shouldFailInitialization': _shouldFailInitialization,
      'mockAmplitude': _mockAmplitude,
      'sessionCounter': _sessionCounter,
      'currentSessionId': _currentSession?.id,
      'currentState': _currentSession?.state.toString(),
      'recordingPath': _recordingPath,
    };
  }
}
