import '../models/audio_configuration.dart';
import '../models/recording_session.dart';

/// Abstract interface for audio recording services
abstract class AudioServiceInterface {
  /// Stream of recording session updates
  Stream<RecordingSession> get sessionStream;

  /// Current recording session
  RecordingSession? get currentSession;

  /// Initialize the audio service
  Future<void> initialize();

  /// Dispose and cleanup resources
  Future<void> dispose();

  /// Start a new recording session
  Future<void> startRecording({
    required AudioConfiguration configuration,
    String? fileName,
  });

  /// Pause the current recording
  Future<void> pauseRecording();

  /// Resume a paused recording
  Future<void> resumeRecording();

  /// Stop the current recording
  Future<String?> stopRecording();

  /// Cancel the current recording (delete file)
  Future<void> cancelRecording();

  /// Check if the service is ready to record
  Future<bool> isReady();

  /// Get available audio formats for the current platform
  List<String> getSupportedFormats();

  /// Check microphone permission status
  Future<bool> hasPermission();

  /// Request microphone permission
  Future<bool> requestPermission();
}
