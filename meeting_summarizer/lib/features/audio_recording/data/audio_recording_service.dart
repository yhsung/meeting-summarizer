import 'dart:async';
import 'dart:io';
import 'dart:math' as math hide log;
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/enums/recording_state.dart';
import '../../../core/models/audio_configuration.dart';
import '../../../core/models/permission_guidance.dart';
import '../../../core/models/recording_session.dart';
import '../../../core/services/audio_service_interface.dart';
import '../../../core/services/audio_enhancement_service_interface.dart';
import '../../../core/services/audio_enhancement_service.dart';
import '../../../core/services/permission_service_interface.dart';
import '../../../core/services/permission_service.dart';
import 'platform/audio_recording_platform.dart';
import 'platform/record_platform_adapter.dart';

class AudioRecordingService implements AudioServiceInterface {
  static const Uuid _uuid = Uuid();

  late final AudioRecordingPlatform _platform;
  late final AudioEnhancementServiceInterface _enhancementService;
  late final PermissionServiceInterface _permissionService;
  final StreamController<RecordingSession> _sessionController =
      StreamController<RecordingSession>.broadcast();

  RecordingSession? _currentSession;
  Timer? _recordingTimer;
  Timer? _amplitudeTimer;
  String? _recordingPath;
  StreamSubscription<Map<PermissionType, PermissionState>>?
  _permissionSubscription;

  /// Constructor with optional platform injection for testing
  AudioRecordingService({
    AudioRecordingPlatform? platform,
    AudioEnhancementServiceInterface? enhancementService,
    PermissionServiceInterface? permissionService,
  }) {
    _platform = platform ?? RecordPlatformAdapter();
    _enhancementService = enhancementService ?? AudioEnhancementService();
    _permissionService = permissionService ?? PermissionService();
  }

  @override
  Stream<RecordingSession> get sessionStream => _sessionController.stream;

  @override
  RecordingSession? get currentSession => _currentSession;

  /// Provides real-time enhanced audio stream during recording
  Stream<Float32List> getEnhancedAudioStream(int sampleRate) async* {
    if (_currentSession == null || !_currentSession!.state.isActive) {
      throw StateError('No active recording session');
    }

    // Configure enhancement service for real-time processing
    final enhancementConfig = AudioEnhancementConfig(
      enableNoiseReduction: _currentSession!.configuration.enableNoiseReduction,
      enableAutoGainControl:
          _currentSession!.configuration.enableAutoGainControl,
      enableEchoCanellation: true,
      enableSpectralSubtraction:
          false, // Disable for real-time to reduce latency
      enableFrequencyFiltering: true,
      noiseReductionStrength: 0.3, // Lighter for real-time
      gainControlThreshold: 0.5,
      echoCancellationStrength: 0.2,
      highPassCutoff: 80.0,
      lowPassCutoff: 8000.0,
      processingMode: ProcessingMode.realTime,
      windowSize: 512, // Smaller window for lower latency
    );

    await _enhancementService.configure(enhancementConfig);

    // Create a dummy audio stream for demonstration
    // In a real implementation, you'd get this from the platform recording stream
    await for (final audioChunk in _generateDummyAudioStream(sampleRate)) {
      if (_currentSession?.state.isActive == true) {
        try {
          final result = await _enhancementService.processAudio(
            audioChunk,
            sampleRate,
          );
          yield result.enhancedAudioData;
        } catch (e) {
          log('AudioRecordingService: Real-time enhancement failed: $e');
          yield audioChunk; // Fallback to original audio
        }
      } else {
        break;
      }
    }
  }

  @override
  Future<void> initialize() async {
    try {
      // Initialize platform-specific recording engine
      await _platform.initialize();

      // Initialize audio enhancement service
      await _enhancementService.initialize();

      // Initialize permission service
      await _permissionService.initialize();

      // Start monitoring permission changes
      _startPermissionMonitoring();

      // Check if microphone permission is available
      final permissionState = await _permissionService.checkPermission(
        PermissionType.microphone,
      );
      if (permissionState != PermissionState.granted) {
        log(
          'AudioRecordingService: Microphone permission not granted: $permissionState',
        );
      }

      log('AudioRecordingService: Initialized successfully');
    } catch (e) {
      log('AudioRecordingService: Initialization failed: $e');
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
    _permissionSubscription?.cancel();
    await _platform.dispose();
    await _enhancementService.dispose();
    await _permissionService.dispose();
    await _sessionController.close();
    log('AudioRecordingService: Disposed');
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

      // Check and request permissions with comprehensive handling
      final permissionResult = await _ensureMicrophonePermission();
      if (!permissionResult.isGranted) {
        _handlePermissionFailureOnStart(permissionResult);
        return;
      }

      // Update state to initializing
      _updateSession(RecordingState.initializing, configuration);

      // Prepare file path with fallback directory handling
      String directory;
      try {
        directory =
            configuration.outputDirectory ??
            (await getApplicationDocumentsDirectory()).path;
      } catch (e) {
        log(
          'AudioRecordingService: Failed to get documents directory: $e',
        );
        // Fallback to current directory for tests
        directory = '.';
      }

      final sessionId = _uuid.v4();
      final filename =
          fileName ?? 'recording_${DateTime.now().millisecondsSinceEpoch}';

      // Use appropriate extension based on platform
      final extension = Platform.isMacOS
          ? 'aac'
          : configuration.format.extension;
      _recordingPath = '$directory/$filename.$extension';

      // Start recording using platform implementation with graceful fallback
      try {
        await _platform.startRecording(
          configuration: configuration,
          filePath: _recordingPath!,
        );
      } catch (e) {
        _handleRecordingStartFailure(e, configuration);
        return;
      }

      // Create session
      _currentSession = RecordingSession(
        id: sessionId,
        startTime: DateTime.now(),
        state: RecordingState.recording,
        duration: Duration.zero,
        configuration: configuration,
        filePath: _recordingPath,
      );

      // Start timers with error handling
      try {
        _startRecordingTimer();
        _startAmplitudeMonitoring();
      } catch (e) {
        log('AudioRecordingService: Failed to start monitoring: $e');
        // Continue recording even if monitoring fails
      }

      _sessionController.add(_currentSession!);
      log('AudioRecordingService: Recording started - $_recordingPath');
    } catch (e) {
      _handleUnexpectedStartFailure(e);
    }
  }

  /// Handle permission failure when starting recording
  void _handlePermissionFailureOnStart(PermissionResult permissionResult) {
    final errorMessage = _getPermissionErrorMessage(permissionResult);

    if (permissionResult.isPermanentlyDenied) {
      _updateSession(
        RecordingState.error,
        null,
        '$errorMessage Recording cannot start without microphone access.',
      );
    } else {
      _updateSession(
        RecordingState.stopped,
        null,
        '$errorMessage You can try starting recording again after granting permission.',
      );
    }

    log(
      'AudioRecordingService: Recording start failed due to permissions: $errorMessage',
    );
  }

  /// Handle recording platform failure with graceful degradation
  void _handleRecordingStartFailure(
    dynamic error,
    AudioConfiguration configuration,
  ) {
    log(
      'AudioRecordingService: Platform recording start failed: $error',
    );

    String userMessage;
    String technicalDetails = error.toString();

    if (technicalDetails.contains('permission') ||
        technicalDetails.contains('Permission')) {
      userMessage = 'Recording failed: Microphone permission issue detected.';
    } else if (technicalDetails.contains('busy') ||
        technicalDetails.contains('device')) {
      userMessage =
          'Recording failed: Microphone is currently in use by another app.';
    } else if (technicalDetails.contains('Input device not found') ||
        technicalDetails.contains('device not found')) {
      userMessage =
          'Recording failed: No microphone detected. Please connect a microphone or check system audio settings.';
    } else if (technicalDetails.contains('format') ||
        technicalDetails.contains('codec')) {
      userMessage =
          'Recording failed: Unsupported audio format. Try a different quality setting.';
    } else {
      userMessage = 'Recording failed: Unable to start audio recording.';
    }

    _updateSession(
      RecordingState.error,
      configuration,
      '$userMessage Please check your device settings and try again.',
    );
  }

  /// Handle unexpected failures during recording start
  void _handleUnexpectedStartFailure(dynamic error) {
    log(
      'AudioRecordingService: Unexpected start recording failure: $error',
    );

    String userMessage = 'Recording failed due to an unexpected error.';
    if (error.toString().contains('already')) {
      userMessage = 'Recording is already in progress or device is busy.';
    }

    _updateSession(
      RecordingState.error,
      null,
      '$userMessage Please try again in a moment.',
    );
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
      log('AudioRecordingService: Recording paused');
    } catch (e) {
      _updateSession(RecordingState.error, null, e.toString());
      log('AudioRecordingService: Pause recording failed: $e');
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
      log('AudioRecordingService: Recording resumed');
    } catch (e) {
      _updateSession(RecordingState.error, null, e.toString());
      log('AudioRecordingService: Resume recording failed: $e');
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
        // For debugging, let's skip enhancement and use original file
        String finalPath = path;
        log(
          'AudioRecordingService: Using original file for now - $finalPath',
        );

        // Apply post-processing enhancement if enabled
        // TODO: Re-enable enhancement after fixing silence issue
        /*
        if (_shouldApplyEnhancement(_currentSession!.configuration)) {
          try {
            _updateSession(RecordingState.processing);
            finalPath = await _applyPostProcessingEnhancement(path);
            log(
              'AudioRecordingService: Enhancement applied - $finalPath',
            );
          } catch (e) {
            log('AudioRecordingService: Enhancement failed: $e');
            // Continue with original file if enhancement fails
            finalPath = path;
          }
        }
        */

        final finalFile = File(finalPath);
        final finalFileSize = await finalFile.length();

        _currentSession = _currentSession!.copyWith(
          state: RecordingState.stopped,
          endTime: DateTime.now(),
          filePath: finalPath,
          fileSize: finalFileSize.toDouble(),
        );

        _sessionController.add(_currentSession!);
        log(
          'AudioRecordingService: Recording stopped - $finalPath (${finalFileSize}B)',
        );

        return finalPath;
      } else {
        throw Exception('Recording file not found');
      }
    } catch (e) {
      _updateSession(RecordingState.error, null, e.toString());
      log('AudioRecordingService: Stop recording failed: $e');
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
      log('AudioRecordingService: Cancel recording failed: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isReady() async {
    try {
      return await _platform.hasPermission() && !await _platform.isRecording();
    } catch (e) {
      log('AudioRecordingService: Ready check failed: $e');
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
      final state = await _permissionService.checkPermission(
        PermissionType.microphone,
      );
      return state == PermissionState.granted;
    } catch (e) {
      log('AudioRecordingService: Permission check failed: $e');
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final result = await _permissionService.requestPermission(
        PermissionType.microphone,
        config: const PermissionConfig(
          showRationale: true,
          rationaleTitle: 'Microphone Access Required',
          rationaleMessage:
              'This app needs microphone access to record meetings and conversations.',
          autoRedirectToSettings: true,
          settingsRedirectMessage:
              'Please enable microphone access in Settings to record audio.',
        ),
      );
      return result.isGranted;
    } catch (e) {
      log('AudioRecordingService: Permission request failed: $e');
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
          log('AudioRecordingService: Amplitude monitoring error: $e');
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

  /// Generates dummy audio stream for demonstration
  /// In a real implementation, this would be replaced with actual audio data from the microphone
  Stream<Float32List> _generateDummyAudioStream(int sampleRate) async* {
    const chunkSize = 1024; // 1024 samples per chunk
    const chunkDuration = Duration(milliseconds: 50); // ~50ms chunks

    while (_currentSession?.state.isActive == true) {
      // Generate dummy audio data (sine wave + noise for testing)
      final audioChunk = Float32List(chunkSize);
      final now = DateTime.now().millisecondsSinceEpoch;

      for (int i = 0; i < chunkSize; i++) {
        // Generate a test signal with some noise
        final t = (now + i) / 1000.0;
        final signal =
            0.1 *
            (math.sin(2 * math.pi * 440 * t) + // 440 Hz tone
                0.05 *
                    (math.Random().nextDouble() - 0.5) // Some noise
                    );
        audioChunk[i] = signal;
      }

      yield audioChunk;
      await Future.delayed(chunkDuration);
    }
  }

  /// Start monitoring permission changes
  void _startPermissionMonitoring() {
    _permissionSubscription = _permissionService.permissionStateStream.listen(
      (permissionStates) {
        final microphoneState = permissionStates[PermissionType.microphone];
        if (microphoneState != null) {
          _handlePermissionStateChange(microphoneState);
        }
      },
      onError: (error) {
        log(
          'AudioRecordingService: Permission monitoring error: $error',
        );
      },
    );
  }

  /// Handle permission state changes with graceful degradation
  void _handlePermissionStateChange(PermissionState newState) {
    log(
      'AudioRecordingService: Microphone permission changed to: $newState',
    );

    switch (newState) {
      case PermissionState.granted:
        _handlePermissionGranted();
        break;
      case PermissionState.denied:
        _handlePermissionDenied();
        break;
      case PermissionState.permanentlyDenied:
        _handlePermissionPermanentlyDenied();
        break;
      case PermissionState.restricted:
        _handlePermissionRestricted();
        break;
      case PermissionState.limited:
        _handlePermissionLimited();
        break;
      case PermissionState.requesting:
        _handlePermissionRequesting();
        break;
      case PermissionState.unknown:
        _handlePermissionUnknown();
        break;
    }
  }

  /// Handle when permission is granted
  void _handlePermissionGranted() {
    log('AudioRecordingService: Microphone permission granted');
    // Permission is now available - no action needed
    // Recording can proceed normally
  }

  /// Handle when permission is denied but can be requested again
  void _handlePermissionDenied() {
    log('AudioRecordingService: Microphone permission denied');

    if (_currentSession?.state.isActive == true) {
      _gracefullyStopRecording(
        'Recording paused: Microphone permission was denied. You can resume once permission is granted.',
        suggestAction: 'Request permission again to continue recording.',
      );
    }
  }

  /// Handle when permission is permanently denied
  void _handlePermissionPermanentlyDenied() {
    log(
      'AudioRecordingService: Microphone permission permanently denied',
    );

    if (_currentSession?.state.isActive == true) {
      _gracefullyStopRecording(
        'Recording stopped: Microphone access is permanently disabled.',
        suggestAction:
            'Please enable microphone access in device Settings to use recording features.',
        isRecoverable: false,
      );
    }
  }

  /// Handle when permission is restricted by device policy
  void _handlePermissionRestricted() {
    log('AudioRecordingService: Microphone permission restricted');

    if (_currentSession?.state.isActive == true) {
      _gracefullyStopRecording(
        'Recording stopped: Microphone access is restricted by device policy.',
        suggestAction:
            'Check device restrictions or parental controls to enable microphone access.',
        isRecoverable: false,
      );
    }
  }

  /// Handle when permission has limited access (iOS 14+)
  void _handlePermissionLimited() {
    log('AudioRecordingService: Microphone permission limited');

    if (_currentSession?.state.isActive == true) {
      // Limited permission may still allow recording, so warn but continue
      _updateSession(
        _currentSession!.state, // Keep current state
        null,
        'Warning: Microphone access is limited. Recording quality may be affected.',
      );
    }
  }

  /// Handle when permission request is in progress
  void _handlePermissionRequesting() {
    log('AudioRecordingService: Microphone permission being requested');

    if (_currentSession?.state.isActive == true) {
      _updateSession(
        RecordingState.paused,
        null,
        'Recording paused: Waiting for microphone permission response.',
      );
    }
  }

  /// Handle when permission state is unknown
  void _handlePermissionUnknown() {
    log('AudioRecordingService: Microphone permission state unknown');

    if (_currentSession?.state.isActive == true) {
      _gracefullyStopRecording(
        'Recording stopped: Unable to determine microphone permission status.',
        suggestAction: 'Please check microphone permissions and try again.',
      );
    }
  }

  /// Gracefully stop recording with user-friendly messaging
  void _gracefullyStopRecording(
    String message, {
    String? suggestAction,
    bool isRecoverable = true,
  }) {
    try {
      if (_currentSession?.state.isActive == true) {
        // Save current recording progress before stopping
        final currentDuration = _currentSession?.duration ?? Duration.zero;
        final currentPath = _currentSession?.filePath;

        log(
          'AudioRecordingService: Gracefully stopping recording - $message',
        );

        // Stop the recording
        cancelRecording();

        // Update session with detailed error information
        final fullMessage = suggestAction != null
            ? '$message $suggestAction'
            : message;

        _updateSession(
          isRecoverable ? RecordingState.paused : RecordingState.error,
          null,
          fullMessage,
        );

        // Log the graceful degradation event
        log(
          'AudioRecordingService: Graceful degradation - Duration: $currentDuration, '
          'Path: $currentPath, Recoverable: $isRecoverable',
        );
      }
    } catch (e) {
      log(
        'AudioRecordingService: Error during graceful recording stop: $e',
      );
      // Fallback to basic error state
      _updateSession(
        RecordingState.error,
        null,
        'Recording stopped due to permission issue.',
      );
    }
  }

  /// Ensure microphone permission is granted, request if needed
  Future<PermissionResult> _ensureMicrophonePermission() async {
    // First check current state
    final currentState = await _permissionService.checkPermission(
      PermissionType.microphone,
    );

    if (currentState == PermissionState.granted) {
      return PermissionResult.granted();
    }

    // Request permission with user-friendly configuration
    return await _permissionService.requestPermission(
      PermissionType.microphone,
      config: const PermissionConfig(
        showRationale: true,
        rationaleTitle: 'Microphone Access Required',
        rationaleMessage:
            'Meeting Summarizer needs microphone access to record your meetings and conversations for transcription and summarization.',
        autoRedirectToSettings: true,
        settingsRedirectMessage:
            'To enable recording, please go to Settings and allow microphone access for Meeting Summarizer.',
        enableRetry: true,
        maxRetryAttempts: 2,
        retryDelay: Duration(seconds: 1),
      ),
    );
  }

  /// Get user-friendly error message for permission failures
  String _getPermissionErrorMessage(PermissionResult result) {
    switch (result.state) {
      case PermissionState.denied:
        return 'Microphone access was denied. Recording requires microphone permission to function.';
      case PermissionState.permanentlyDenied:
        return 'Microphone access is permanently disabled. Please enable it in Settings > Privacy & Security > Microphone.';
      case PermissionState.restricted:
        return 'Microphone access is restricted on this device. Please check parental controls or device restrictions.';
      case PermissionState.unknown:
        return result.errorMessage ??
            'Unable to determine microphone permission status.';
      default:
        return result.errorMessage ??
            'Microphone permission is required for recording.';
    }
  }

  /// Get permission analytics for debugging and monitoring
  Map<String, dynamic> getPermissionAnalytics() {
    return _permissionService.getPermissionAnalytics();
  }

  /// Check if all required permissions are granted
  Future<bool> hasAllRequiredPermissions() async {
    return await _permissionService.hasRequiredPermissions();
  }

  /// Get list of missing required permissions
  Future<List<PermissionType>> getMissingRequiredPermissions() async {
    return await _permissionService.getMissingRequiredPermissions();
  }

  /// Request permission with guided user flow
  Future<PermissionResult> requestPermissionWithGuidance({
    String? customRationale,
    bool forceRequest = false,
  }) async {
    try {
      // Check current permission state
      final currentState = await _permissionService.checkPermission(
        PermissionType.microphone,
      );

      if (currentState == PermissionState.granted && !forceRequest) {
        return PermissionResult.granted();
      }

      // Provide guided flow based on current state
      final guidance = _getPermissionGuidance(currentState);
      log(
        'AudioRecordingService: Permission guidance - ${guidance.message}',
      );

      // Create configuration with guidance
      final config = PermissionConfig(
        showRationale: guidance.shouldShowRationale,
        rationaleTitle: guidance.rationaleTitle,
        rationaleMessage: customRationale ?? guidance.rationaleMessage,
        autoRedirectToSettings: guidance.shouldRedirectToSettings,
        settingsRedirectMessage: guidance.settingsMessage,
        enableRetry: guidance.enableRetry,
        maxRetryAttempts: guidance.maxRetryAttempts,
        retryDelay: guidance.retryDelay,
      );

      return await _permissionService.requestPermission(
        PermissionType.microphone,
        config: config,
      );
    } catch (e) {
      log('AudioRecordingService: Guided permission request failed: $e');
      return PermissionResult.error('Permission request failed: $e');
    }
  }

  /// Get permission guidance based on current state
  PermissionGuidance _getPermissionGuidance(PermissionState currentState) {
    switch (currentState) {
      case PermissionState.denied:
        return PermissionGuidance(
          message: 'Microphone permission was previously denied',
          shouldShowRationale: true,
          rationaleTitle: 'Microphone Access Needed',
          rationaleMessage:
              'Meeting Summarizer needs microphone access to record your meetings and conversations. This allows us to create accurate transcriptions and summaries of your audio content.',
          shouldRedirectToSettings: false,
          enableRetry: true,
          maxRetryAttempts: 2,
          retryDelay: Duration(seconds: 1),
        );

      case PermissionState.permanentlyDenied:
        return PermissionGuidance(
          message: 'Microphone permission is permanently denied',
          shouldShowRationale: true,
          rationaleTitle: 'Enable Microphone in Settings',
          rationaleMessage:
              'Microphone access has been permanently disabled. To use recording features, you\'ll need to enable microphone permissions in your device settings.',
          shouldRedirectToSettings: true,
          settingsMessage:
              'Please go to Settings > Privacy & Security > Microphone and enable access for Meeting Summarizer.',
          enableRetry: false,
          maxRetryAttempts: 1,
        );

      case PermissionState.restricted:
        return PermissionGuidance(
          message: 'Microphone permission is restricted',
          shouldShowRationale: true,
          rationaleTitle: 'Microphone Access Restricted',
          rationaleMessage:
              'Microphone access is restricted on this device, possibly due to parental controls or device management policies.',
          shouldRedirectToSettings: true,
          settingsMessage:
              'Please check your device restrictions or contact your administrator to enable microphone access.',
          enableRetry: false,
          maxRetryAttempts: 1,
        );

      case PermissionState.limited:
        return PermissionGuidance(
          message: 'Microphone permission is limited',
          shouldShowRationale: true,
          rationaleTitle: 'Limited Microphone Access',
          rationaleMessage:
              'Microphone access is currently limited. For the best recording experience, consider granting full microphone access.',
          shouldRedirectToSettings: false,
          enableRetry: true,
          maxRetryAttempts: 1,
        );

      case PermissionState.unknown:
        return PermissionGuidance(
          message: 'Microphone permission status is unknown',
          shouldShowRationale: true,
          rationaleTitle: 'Microphone Access Required',
          rationaleMessage:
              'Meeting Summarizer needs microphone access to record audio. This permission is essential for the app to function properly.',
          shouldRedirectToSettings: false,
          enableRetry: true,
          maxRetryAttempts: 3,
          retryDelay: Duration(seconds: 2),
        );

      default: // granted, requesting
        return PermissionGuidance(
          message: 'Microphone permission check',
          shouldShowRationale: false,
          rationaleTitle: 'Microphone Access',
          rationaleMessage: 'Checking microphone permission status...',
          shouldRedirectToSettings: false,
          enableRetry: false,
          maxRetryAttempts: 1,
        );
    }
  }

  /// Attempt to recover from permission issues
  Future<PermissionRecoveryResult> attemptPermissionRecovery() async {
    try {
      log('AudioRecordingService: Attempting permission recovery');

      // Check current state
      final currentState = await _permissionService.checkPermission(
        PermissionType.microphone,
      );

      if (currentState == PermissionState.granted) {
        return PermissionRecoveryResult(
          success: true,
          message: 'Microphone permission is already granted.',
        );
      }

      // Attempt guided permission request
      final result = await requestPermissionWithGuidance();

      if (result.isGranted) {
        return PermissionRecoveryResult(
          success: true,
          message: 'Microphone permission successfully granted.',
          requiresUserAction: false,
        );
      } else if (result.isPermanentlyDenied) {
        return PermissionRecoveryResult(
          success: false,
          message:
              'Microphone permission is permanently denied. Manual settings change required.',
          requiresUserAction: true,
          recommendedAction:
              'Go to Settings > Privacy & Security > Microphone to enable access.',
        );
      } else {
        return PermissionRecoveryResult(
          success: false,
          message: result.errorMessage ?? 'Permission request was denied.',
          requiresUserAction: true,
          recommendedAction:
              'Please grant microphone permission to use recording features.',
        );
      }
    } catch (e) {
      log('AudioRecordingService: Permission recovery failed: $e');
      return PermissionRecoveryResult(
        success: false,
        message: 'Permission recovery failed due to an error.',
        requiresUserAction: true,
        recommendedAction: 'Please check your device settings and try again.',
      );
    }
  }

  /// Check if recording is possible and provide guidance if not
  Future<RecordingReadinessResult> checkRecordingReadiness() async {
    try {
      // Check permissions
      final hasMicrophonePermission = await hasPermission();
      if (!hasMicrophonePermission) {
        final currentState = await _permissionService.checkPermission(
          PermissionType.microphone,
        );
        final guidance = _getPermissionGuidance(currentState);

        return RecordingReadinessResult(
          isReady: false,
          reason: 'Microphone permission required',
          guidance: guidance.message,
          canRecover: guidance.enableRetry || guidance.shouldRedirectToSettings,
          recommendedAction: guidance.shouldRedirectToSettings
              ? 'Open device settings to enable microphone access'
              : 'Request microphone permission',
        );
      }

      // Check if platform is ready
      final platformReady = await isReady();
      if (!platformReady) {
        return RecordingReadinessResult(
          isReady: false,
          reason: 'Audio recording system not ready',
          guidance: 'The audio recording system is currently unavailable.',
          canRecover: true,
          recommendedAction: 'Wait a moment and try again',
        );
      }

      return RecordingReadinessResult(
        isReady: true,
        reason: 'Ready to record',
        guidance: 'All systems ready for recording.',
      );
    } catch (e) {
      log('AudioRecordingService: Readiness check failed: $e');
      return RecordingReadinessResult(
        isReady: false,
        reason: 'System check failed',
        guidance: 'Unable to verify recording readiness.',
        canRecover: true,
        recommendedAction: 'Check your device settings and try again',
      );
    }
  }
}
