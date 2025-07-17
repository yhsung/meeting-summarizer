import 'dart:async';
import 'dart:io';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/models/recording_session.dart';
import '../audio_recording_service.dart';

/// Manages background recording capabilities across different platforms
class BackgroundRecordingManager {
  static BackgroundRecordingManager? _instance;

  factory BackgroundRecordingManager() {
    return _instance ??= BackgroundRecordingManager._internal();
  }

  BackgroundRecordingManager._internal();

  // Platform channels for native background functionality
  static const MethodChannel _androidChannel = MethodChannel(
    'com.meeting_summarizer/background_audio',
  );
  static const MethodChannel _iosChannel = MethodChannel(
    'com.meeting_summarizer/background_session',
  );

  // App lifecycle tracking
  AppLifecycleState? _lastLifecycleState;
  bool _isBackgroundRecordingEnabled = false;
  bool _isInBackground = false;
  bool _isDisposed = false;

  // Audio service reference
  AudioRecordingService? _audioService;
  RecordingSession? _backgroundSession;

  // Event controllers
  final StreamController<BackgroundRecordingEvent> _eventController =
      StreamController<BackgroundRecordingEvent>.broadcast();

  Stream<BackgroundRecordingEvent> get eventStream => _eventController.stream;

  /// Safely add event to stream controller if not disposed
  void _addEvent(BackgroundRecordingEvent event) {
    if (_isDisposed || _eventController.isClosed) {
      log(
        'BackgroundRecordingManager: Cannot add event after disposal: $event',
      );
      return;
    }
    _eventController.add(event);
  }

  /// Initialize background recording capabilities
  Future<void> initialize(AudioRecordingService audioService) async {
    _audioService = audioService;

    try {
      // Register app lifecycle observer - only in non-test environments
      try {
        WidgetsBinding.instance.addObserver(_AppLifecycleObserver(this));
      } catch (e) {
        // Binding not initialized (likely in test environment)
        log(
          'BackgroundRecordingManager: Could not register lifecycle observer: $e',
        );
      }

      // Initialize platform-specific background capabilities
      if (Platform.isAndroid) {
        await _initializeAndroidBackground();
      } else if (Platform.isIOS) {
        await _initializeIOSBackground();
      } else if (kIsWeb) {
        await _initializeWebBackground();
      }

      log('BackgroundRecordingManager: Initialized successfully');
    } catch (e) {
      log('BackgroundRecordingManager: Initialization failed: $e');
      rethrow;
    }
  }

  /// Enable background recording mode
  Future<bool> enableBackgroundRecording() async {
    try {
      if (Platform.isAndroid) {
        final result = await _androidChannel.invokeMethod('enableBackground');
        _isBackgroundRecordingEnabled = result == true;
      } else if (Platform.isIOS) {
        final result = await _iosChannel.invokeMethod(
          'enableBackgroundSession',
        );
        _isBackgroundRecordingEnabled = result == true;
      } else if (kIsWeb) {
        _isBackgroundRecordingEnabled = await _enableWebBackground();
      } else {
        // Desktop platforms - always allow background recording
        _isBackgroundRecordingEnabled = true;
      }

      if (_isBackgroundRecordingEnabled) {
        _addEvent(BackgroundRecordingEvent.enabled);
      }

      return _isBackgroundRecordingEnabled;
    } catch (e) {
      log('BackgroundRecordingManager: Failed to enable background: $e');
      return false;
    }
  }

  /// Disable background recording mode
  Future<void> disableBackgroundRecording() async {
    try {
      if (Platform.isAndroid) {
        await _androidChannel.invokeMethod('disableBackground');
      } else if (Platform.isIOS) {
        await _iosChannel.invokeMethod('disableBackgroundSession');
      } else if (kIsWeb) {
        await _disableWebBackground();
      }

      _isBackgroundRecordingEnabled = false;
      _addEvent(BackgroundRecordingEvent.disabled);
    } catch (e) {
      log(
        'BackgroundRecordingManager: Failed to disable background: $e',
      );
    }
  }

  /// Check if background recording is currently available
  bool get isBackgroundRecordingEnabled => _isBackgroundRecordingEnabled;

  /// Check if app is currently in background
  bool get isInBackground => _isInBackground;

  /// Get current background recording session
  RecordingSession? get backgroundSession => _backgroundSession;

  /// Handle app lifecycle changes
  void _handleAppLifecycleChanged(AppLifecycleState state) {
    final previousState = _lastLifecycleState;
    _lastLifecycleState = state;

    switch (state) {
      case AppLifecycleState.paused:
        _onAppBackgrounded(previousState);
        break;
      case AppLifecycleState.resumed:
        _onAppForegrounded(previousState);
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      case AppLifecycleState.inactive:
        // Handle inactive state (iOS transitional state)
        break;
      case AppLifecycleState.hidden:
        // Handle hidden state (new in Flutter 3.13+)
        break;
    }
  }

  /// Handle app going to background
  void _onAppBackgrounded(AppLifecycleState? previousState) async {
    log('BackgroundRecordingManager: App backgrounded');
    _isInBackground = true;

    // If recording is active and background is enabled, maintain recording
    if (_audioService?.currentSession?.isActive == true &&
        _isBackgroundRecordingEnabled) {
      _backgroundSession = _audioService!.currentSession;
      await _startBackgroundRecording();
      _addEvent(BackgroundRecordingEvent.backgroundRecordingStarted);
    } else if (_audioService?.currentSession?.isActive == true) {
      // Background not enabled - pause recording
      await _audioService?.pauseRecording();
      _addEvent(BackgroundRecordingEvent.recordingPausedForBackground);
    }
  }

  /// Handle app returning to foreground
  void _onAppForegrounded(AppLifecycleState? previousState) async {
    log('BackgroundRecordingManager: App foregrounded');
    _isInBackground = false;

    // If we had a background session, transition back to foreground
    if (_backgroundSession != null) {
      await _stopBackgroundRecording();
      _addEvent(BackgroundRecordingEvent.backgroundRecordingStopped);
      _backgroundSession = null;
    }

    // Resume paused recording if applicable
    if (_audioService?.currentSession?.isPaused == true) {
      await _audioService?.resumeRecording();
      _addEvent(BackgroundRecordingEvent.recordingResumedFromBackground);
    }
  }

  /// Handle app being detached/terminated
  void _onAppDetached() async {
    log('BackgroundRecordingManager: App detached');

    // Save any ongoing recording before termination
    if (_audioService?.currentSession?.isActive == true) {
      await _audioService?.stopRecording();
      _addEvent(BackgroundRecordingEvent.recordingStoppedForTermination);
    }
  }

  // Platform-specific initialization methods

  Future<void> _initializeAndroidBackground() async {
    try {
      await _androidChannel.invokeMethod('initialize');
    } catch (e) {
      log('BackgroundRecordingManager: Android init failed: $e');
    }
  }

  Future<void> _initializeIOSBackground() async {
    try {
      await _iosChannel.invokeMethod('initialize');
    } catch (e) {
      log('BackgroundRecordingManager: iOS init failed: $e');
    }
  }

  Future<void> _initializeWebBackground() async {
    // Web initialization - register page visibility change listeners
    // This would be implemented with JS interop in a real implementation
    log('BackgroundRecordingManager: Web background initialized');
  }

  // Background recording control methods

  Future<void> _startBackgroundRecording() async {
    try {
      if (Platform.isAndroid) {
        await _androidChannel.invokeMethod('startForegroundService', {
          'title': 'Recording in progress',
          'message': 'Meeting Summarizer is recording audio',
          'sessionId': _backgroundSession?.id,
        });
      } else if (Platform.isIOS) {
        await _iosChannel.invokeMethod('startBackgroundTask', {
          'sessionId': _backgroundSession?.id,
        });
      }
    } catch (e) {
      log(
        'BackgroundRecordingManager: Failed to start background recording: $e',
      );
    }
  }

  Future<void> _stopBackgroundRecording() async {
    try {
      if (Platform.isAndroid) {
        await _androidChannel.invokeMethod('stopForegroundService');
      } else if (Platform.isIOS) {
        await _iosChannel.invokeMethod('endBackgroundTask');
      }
    } catch (e) {
      log(
        'BackgroundRecordingManager: Failed to stop background recording: $e',
      );
    }
  }

  Future<bool> _enableWebBackground() async {
    // Web-specific background enabling logic
    // In a real implementation, this would use Page Visibility API
    return true;
  }

  Future<void> _disableWebBackground() async {
    // Web-specific background disabling logic
  }

  /// Get background recording capabilities for current platform
  BackgroundCapabilities getCapabilities() {
    if (Platform.isAndroid) {
      return BackgroundCapabilities(
        supportsBackground: true,
        requiresPermission: true,
        maxBackgroundDuration: null, // Unlimited with foreground service
        supportsNotification: true,
        platformName: 'Android',
      );
    } else if (Platform.isIOS) {
      return BackgroundCapabilities(
        supportsBackground: true,
        requiresPermission: true,
        maxBackgroundDuration: const Duration(
          minutes: 3,
        ), // iOS background task limit
        supportsNotification: false,
        platformName: 'iOS',
      );
    } else if (kIsWeb) {
      return BackgroundCapabilities(
        supportsBackground: true,
        requiresPermission: false,
        maxBackgroundDuration: null, // Depends on browser
        supportsNotification: true,
        platformName: 'Web',
      );
    } else {
      return BackgroundCapabilities(
        supportsBackground: true,
        requiresPermission: false,
        maxBackgroundDuration: null,
        supportsNotification: false,
        platformName: 'Desktop',
      );
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _isDisposed = true;

    if (!_eventController.isClosed) {
      await _eventController.close();
    }

    if (Platform.isAndroid) {
      await _androidChannel.invokeMethod('dispose');
    } else if (Platform.isIOS) {
      await _iosChannel.invokeMethod('dispose');
    }
  }

  /// Simulate app lifecycle change for testing purposes
  @visibleForTesting
  void simulateAppLifecycleChange(AppLifecycleState state) {
    _handleAppLifecycleChanged(state);
  }
}

/// App lifecycle observer for background recording management
class _AppLifecycleObserver extends WidgetsBindingObserver {
  final BackgroundRecordingManager _manager;

  _AppLifecycleObserver(this._manager);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _manager._handleAppLifecycleChanged(state);
  }
}

/// Background recording event types
enum BackgroundRecordingEvent {
  enabled,
  disabled,
  backgroundRecordingStarted,
  backgroundRecordingStopped,
  recordingPausedForBackground,
  recordingResumedFromBackground,
  recordingStoppedForTermination,
  permissionRequired,
  permissionDenied,
}

/// Platform background capabilities
class BackgroundCapabilities {
  final bool supportsBackground;
  final bool requiresPermission;
  final Duration? maxBackgroundDuration;
  final bool supportsNotification;
  final String platformName;

  const BackgroundCapabilities({
    required this.supportsBackground,
    required this.requiresPermission,
    required this.maxBackgroundDuration,
    required this.supportsNotification,
    required this.platformName,
  });

  @override
  String toString() {
    return 'BackgroundCapabilities($platformName: '
        'supported=$supportsBackground, '
        'permission=$requiresPermission, '
        'maxDuration=$maxBackgroundDuration, '
        'notification=$supportsNotification)';
  }
}
