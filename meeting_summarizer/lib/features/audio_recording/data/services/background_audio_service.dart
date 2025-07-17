import 'dart:async';
import 'dart:developer';

import '../../../../core/models/audio_configuration.dart';
import '../../../../core/models/recording_session.dart';
import '../../../../core/services/audio_service_interface.dart';
import '../audio_recording_service.dart';
import 'background_recording_manager.dart';

/// Enhanced audio recording service with background recording capabilities
class BackgroundAudioService implements AudioServiceInterface {
  late final AudioRecordingService _baseService;
  late final BackgroundRecordingManager _backgroundManager;

  final StreamController<RecordingSession> _sessionController =
      StreamController<RecordingSession>.broadcast();
  final StreamController<BackgroundRecordingEvent> _backgroundEventController =
      StreamController<BackgroundRecordingEvent>.broadcast();

  RecordingSession? _currentSession;
  bool _isBackgroundModeEnabled = false;
  bool _isDisposed = false;
  StreamSubscription<RecordingSession>? _baseServiceSubscription;
  StreamSubscription<BackgroundRecordingEvent>? _backgroundEventSubscription;

  /// Constructor
  BackgroundAudioService({
    AudioRecordingService? baseService,
    BackgroundRecordingManager? backgroundManager,
  }) {
    _baseService = baseService ?? AudioRecordingService();
    _backgroundManager = backgroundManager ?? BackgroundRecordingManager();
  }

  @override
  Stream<RecordingSession> get sessionStream => _sessionController.stream;

  /// Stream of background recording events
  Stream<BackgroundRecordingEvent> get backgroundEventStream =>
      _backgroundEventController.stream;

  /// Safely add session update to stream controller if not disposed
  void _addSessionUpdate(RecordingSession session) {
    if (_isDisposed || _sessionController.isClosed) {
      log('BackgroundAudioService: Cannot add session update after disposal');
      return;
    }
    _sessionController.add(session);
  }

  /// Safely add background event to stream controller if not disposed
  void _addBackgroundEvent(BackgroundRecordingEvent event) {
    if (_isDisposed || _backgroundEventController.isClosed) {
      log(
        'BackgroundAudioService: Cannot add background event after disposal: $event',
      );
      return;
    }
    _backgroundEventController.add(event);
  }

  @override
  RecordingSession? get currentSession => _currentSession;

  /// Check if background recording is enabled
  bool get isBackgroundModeEnabled => _isBackgroundModeEnabled;

  /// Check if currently recording in background
  bool get isRecordingInBackground =>
      _backgroundManager.isInBackground &&
      _backgroundManager.backgroundSession != null;

  /// Get background capabilities for current platform
  BackgroundCapabilities get backgroundCapabilities =>
      _backgroundManager.getCapabilities();

  @override
  Future<void> initialize() async {
    try {
      // Initialize base audio service
      await _baseService.initialize();

      // Initialize background manager
      await _backgroundManager.initialize(_baseService);

      // Subscribe to base service session updates
      _baseServiceSubscription = _baseService.sessionStream.listen(
        _handleBaseServiceSessionUpdate,
        onError: (error) {
          log('BackgroundAudioService: Base service error: $error');
          _sessionController.addError(error);
        },
      );

      // Subscribe to background events
      _backgroundEventSubscription = _backgroundManager.eventStream.listen(
        _handleBackgroundEvent,
        onError: (error) {
          log('BackgroundAudioService: Background event error: $error');
          _backgroundEventController.addError(error);
        },
      );

      log('BackgroundAudioService: Initialized successfully');
    } catch (e) {
      log('BackgroundAudioService: Initialization failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    _isDisposed = true;

    // Cancel subscriptions first to prevent new events
    await _baseServiceSubscription?.cancel();
    await _backgroundEventSubscription?.cancel();

    // Close controllers safely
    if (!_sessionController.isClosed) {
      await _sessionController.close();
    }
    if (!_backgroundEventController.isClosed) {
      await _backgroundEventController.close();
    }

    // Dispose dependencies
    await _backgroundManager.dispose();
    await _baseService.dispose();
    log('BackgroundAudioService: Disposed');
  }

  /// Enable background recording mode
  Future<bool> enableBackgroundMode() async {
    try {
      final success = await _backgroundManager.enableBackgroundRecording();
      _isBackgroundModeEnabled = success;

      if (success) {
        log('BackgroundAudioService: Background mode enabled');
      } else {
        log('BackgroundAudioService: Failed to enable background mode');
      }

      return success;
    } catch (e) {
      log('BackgroundAudioService: Error enabling background mode: $e');
      return false;
    }
  }

  /// Disable background recording mode
  Future<void> disableBackgroundMode() async {
    try {
      await _backgroundManager.disableBackgroundRecording();
      _isBackgroundModeEnabled = false;
      log('BackgroundAudioService: Background mode disabled');
    } catch (e) {
      log('BackgroundAudioService: Error disabling background mode: $e');
    }
  }

  @override
  Future<void> startRecording({
    required AudioConfiguration configuration,
    String? fileName,
  }) async {
    try {
      // Start recording with base service
      await _baseService.startRecording(
        configuration: configuration,
        fileName: fileName,
      );

      log('BackgroundAudioService: Recording started');
    } catch (e) {
      log('BackgroundAudioService: Failed to start recording: $e');
      rethrow;
    }
  }

  @override
  Future<void> pauseRecording() async {
    try {
      await _baseService.pauseRecording();
      log('BackgroundAudioService: Recording paused');
    } catch (e) {
      log('BackgroundAudioService: Failed to pause recording: $e');
      rethrow;
    }
  }

  @override
  Future<void> resumeRecording() async {
    try {
      await _baseService.resumeRecording();
      log('BackgroundAudioService: Recording resumed');
    } catch (e) {
      log('BackgroundAudioService: Failed to resume recording: $e');
      rethrow;
    }
  }

  @override
  Future<String?> stopRecording() async {
    try {
      final result = await _baseService.stopRecording();
      log('BackgroundAudioService: Recording stopped');
      return result;
    } catch (e) {
      log('BackgroundAudioService: Failed to stop recording: $e');
      rethrow;
    }
  }

  @override
  Future<void> cancelRecording() async {
    try {
      await _baseService.cancelRecording();
      log('BackgroundAudioService: Recording cancelled');
    } catch (e) {
      log('BackgroundAudioService: Failed to cancel recording: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isReady() async {
    return await _baseService.isReady();
  }

  @override
  List<String> getSupportedFormats() {
    return _baseService.getSupportedFormats();
  }

  @override
  Future<bool> hasPermission() async {
    return await _baseService.hasPermission();
  }

  @override
  Future<bool> requestPermission() async {
    return await _baseService.requestPermission();
  }

  /// Handle session updates from base service
  void _handleBaseServiceSessionUpdate(RecordingSession session) {
    _currentSession = _enhanceSessionWithBackgroundInfo(session);
    _addSessionUpdate(_currentSession!);
  }

  /// Handle background recording events
  void _handleBackgroundEvent(BackgroundRecordingEvent event) {
    _addBackgroundEvent(event);

    // Update current session with background status if applicable
    if (_currentSession != null) {
      _currentSession = _enhanceSessionWithBackgroundInfo(_currentSession!);
      _addSessionUpdate(_currentSession!);
    }
  }

  /// Enhance session with background recording information
  RecordingSession _enhanceSessionWithBackgroundInfo(RecordingSession session) {
    // Create enhanced session with background info
    // This would require extending RecordingSession model in a real implementation
    return session.copyWith(
      // Add background-specific metadata here
    );
  }

  /// Get detailed background status information
  BackgroundRecordingStatus getBackgroundStatus() {
    return BackgroundRecordingStatus(
      isBackgroundModeEnabled: _isBackgroundModeEnabled,
      isInBackground: _backgroundManager.isInBackground,
      isRecordingInBackground: isRecordingInBackground,
      backgroundSession: _backgroundManager.backgroundSession,
      capabilities: backgroundCapabilities,
      currentSession: _currentSession,
    );
  }

  /// Request background recording permissions if needed
  Future<bool> requestBackgroundPermissions() async {
    try {
      final capabilities = backgroundCapabilities;

      if (!capabilities.requiresPermission) {
        return true;
      }

      // Platform-specific permission requests would go here
      // For now, return true as this would be implemented with native code
      log('BackgroundAudioService: Background permissions requested');
      return true;
    } catch (e) {
      log('BackgroundAudioService: Failed to request permissions: $e');
      return false;
    }
  }
}

/// Background recording status information
class BackgroundRecordingStatus {
  final bool isBackgroundModeEnabled;
  final bool isInBackground;
  final bool isRecordingInBackground;
  final RecordingSession? backgroundSession;
  final BackgroundCapabilities capabilities;
  final RecordingSession? currentSession;

  const BackgroundRecordingStatus({
    required this.isBackgroundModeEnabled,
    required this.isInBackground,
    required this.isRecordingInBackground,
    required this.backgroundSession,
    required this.capabilities,
    required this.currentSession,
  });

  @override
  String toString() {
    return 'BackgroundRecordingStatus('
        'backgroundMode=$isBackgroundModeEnabled, '
        'inBackground=$isInBackground, '
        'recordingInBackground=$isRecordingInBackground, '
        'hasBackgroundSession=${backgroundSession != null}, '
        'hasCurrentSession=${currentSession != null}'
        ')';
  }
}
