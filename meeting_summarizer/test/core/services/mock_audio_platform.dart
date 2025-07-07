import 'package:meeting_summarizer/core/models/audio_configuration.dart';
import 'package:meeting_summarizer/features/audio_recording/data/platform/audio_recording_platform.dart';

/// Mock audio recording platform for testing
class MockAudioRecordingPlatform implements AudioRecordingPlatform {
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isPaused = false;
  bool _hasPermission = false;
  String? _currentRecordingPath;

  // Test configuration
  void setMockPermission(bool hasPermission) {
    _hasPermission = hasPermission;
  }

  void setMockRecordingState(bool isRecording) {
    _isRecording = isRecording;
  }

  @override
  Future<void> initialize() async {
    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    _isRecording = false;
    _isPaused = false;
    _currentRecordingPath = null;
  }

  @override
  Future<void> startRecording({
    required AudioConfiguration configuration,
    required String filePath,
  }) async {
    if (!_isInitialized) {
      throw StateError('Platform not initialized');
    }
    if (!_hasPermission) {
      throw Exception('No permission to record audio');
    }
    if (_isRecording) {
      throw Exception('Already recording');
    }

    _isRecording = true;
    _isPaused = false;
    _currentRecordingPath = filePath;
  }

  @override
  Future<void> pauseRecording() async {
    if (!_isRecording || _isPaused) {
      throw Exception('No recording to pause');
    }
    _isPaused = true;
  }

  @override
  Future<void> resumeRecording() async {
    if (!_isPaused) {
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
    final path = _currentRecordingPath;
    _currentRecordingPath = null;
    return path;
  }

  @override
  Future<void> cancelRecording() async {
    _isRecording = false;
    _isPaused = false;
    _currentRecordingPath = null;
  }

  @override
  Future<bool> hasPermission() async {
    return _hasPermission;
  }

  @override
  Future<bool> requestPermission() async {
    // Mock always grants permission when requested
    _hasPermission = true;
    return _hasPermission;
  }

  @override
  Future<bool> isRecording() async {
    return _isRecording;
  }

  @override
  Future<double> getAmplitude() async {
    if (!_isRecording || _isPaused) {
      return 0.0;
    }
    // Return a mock amplitude value
    return 0.5;
  }

  @override
  List<String> getSupportedFormats() {
    return ['wav', 'mp3', 'aac'];
  }
}
