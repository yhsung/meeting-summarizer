/// Windows Taskbar Integration Service
///
/// Provides integration with Windows taskbar features including:
/// - Live thumbnails and preview windows
/// - Progress indicators on taskbar icon
/// - Taskbar button states and overlays
/// - Thumbnail toolbar with custom buttons
library;

import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Taskbar progress state
enum TaskbarProgressState {
  none('none'),
  indeterminate('indeterminate'),
  normal('normal'),
  error('error'),
  paused('paused');

  const TaskbarProgressState(this.identifier);
  final String identifier;
}

/// Taskbar overlay icon
class TaskbarOverlay {
  final String iconPath;
  final String description;
  final bool visible;

  const TaskbarOverlay({
    required this.iconPath,
    required this.description,
    this.visible = true,
  });

  Map<String, dynamic> toJson() => {
        'iconPath': iconPath,
        'description': description,
        'visible': visible,
      };
}

/// Thumbnail toolbar button
class ThumbnailButton {
  final String id;
  final String iconPath;
  final String tooltip;
  final bool enabled;
  final bool visible;
  final bool dismissOnClick;

  const ThumbnailButton({
    required this.id,
    required this.iconPath,
    required this.tooltip,
    this.enabled = true,
    this.visible = true,
    this.dismissOnClick = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'iconPath': iconPath,
        'tooltip': tooltip,
        'enabled': enabled,
        'visible': visible,
        'dismissOnClick': dismissOnClick,
      };
}

/// Taskbar flash info
class TaskbarFlashInfo {
  final int count;
  final Duration duration;
  final bool stopOnForeground;

  const TaskbarFlashInfo({
    this.count = 3,
    this.duration = const Duration(milliseconds: 500),
    this.stopOnForeground = true,
  });

  Map<String, dynamic> toJson() => {
        'count': count,
        'duration': duration.inMilliseconds,
        'stopOnForeground': stopOnForeground,
      };
}

/// Windows Taskbar Service
class WindowsTaskbarService {
  static const String _logTag = 'WindowsTaskbarService';
  static const String _channelName =
      'com.yhsung.meeting_summarizer/windows_taskbar';

  // Platform channel for native Windows taskbar integration
  static const MethodChannel _platform = MethodChannel(_channelName);

  bool _isInitialized = false;
  bool _taskbarSupported = false;
  TaskbarProgressState _currentProgressState = TaskbarProgressState.none;
  double _currentProgress = 0.0;
  List<ThumbnailButton> _thumbnailButtons = [];

  // Callbacks
  void Function(String buttonId)? onThumbnailButtonClick;
  void Function(bool isActive)? onTaskbarStateChanged;

  /// Initialize Windows taskbar service
  Future<bool> initialize() async {
    try {
      if (!Platform.isWindows) {
        log('$_logTag: Taskbar integration only available on Windows',
            name: _logTag);
        return false;
      }

      // Initialize platform channel
      await _initializePlatformChannel();

      // Check if taskbar integration is supported
      _taskbarSupported = await _checkTaskbarSupport();

      if (_taskbarSupported) {
        // Initialize default thumbnail toolbar
        await _initializeDefaultThumbnailToolbar();

        _isInitialized = true;
        log('$_logTag: Windows taskbar service initialized', name: _logTag);
        return true;
      } else {
        log('$_logTag: Taskbar integration not supported on this system',
            name: _logTag);
        return false;
      }
    } catch (e) {
      log('$_logTag: Failed to initialize Windows taskbar service: $e',
          name: _logTag);
      return false;
    }
  }

  /// Check if service is available
  bool get isAvailable => Platform.isWindows && _isInitialized;
  bool get isSupported => _taskbarSupported;

  /// Initialize platform channel
  Future<void> _initializePlatformChannel() async {
    try {
      _platform.setMethodCallHandler(_handleNativeMethodCall);

      // Test connectivity
      final result = await _platform.invokeMethod<bool>('initialize') ?? false;
      if (!result) {
        log('$_logTag: Failed to initialize native taskbar channel',
            name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Platform channel initialization error: $e', name: _logTag);
    }
  }

  /// Handle method calls from native Windows code
  Future<void> _handleNativeMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onThumbnailButtonClick':
          final buttonId = call.arguments['buttonId'] as String?;
          if (buttonId != null) {
            log('$_logTag: Thumbnail button clicked: $buttonId', name: _logTag);
            onThumbnailButtonClick?.call(buttonId);
          }
          break;

        case 'onTaskbarStateChanged':
          final isActive = call.arguments['isActive'] as bool? ?? false;
          onTaskbarStateChanged?.call(isActive);
          break;

        default:
          log('$_logTag: Unknown native method call: ${call.method}',
              name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error handling native method call: $e', name: _logTag);
    }
  }

  /// Check if taskbar integration is supported
  Future<bool> _checkTaskbarSupport() async {
    try {
      final result =
          await _platform.invokeMethod<bool>('checkSupport') ?? false;
      log('$_logTag: Taskbar integration support: $result', name: _logTag);
      return result;
    } catch (e) {
      log('$_logTag: Failed to check taskbar support: $e', name: _logTag);
      return false;
    }
  }

  /// Initialize default thumbnail toolbar
  Future<void> _initializeDefaultThumbnailToolbar() async {
    try {
      final defaultButtons = [
        ThumbnailButton(
          id: 'start_recording',
          iconPath: 'assets/icons/start_recording.ico',
          tooltip: 'Start Recording',
        ),
        ThumbnailButton(
          id: 'view_recordings',
          iconPath: 'assets/icons/view_recordings.ico',
          tooltip: 'View Recordings',
        ),
        ThumbnailButton(
          id: 'settings',
          iconPath: 'assets/icons/settings.ico',
          tooltip: 'Settings',
        ),
      ];

      await setThumbnailButtons(defaultButtons);
    } catch (e) {
      log('$_logTag: Failed to initialize default thumbnail toolbar: $e',
          name: _logTag);
    }
  }

  /// Set taskbar progress
  Future<void> setProgress({
    required double progress,
    TaskbarProgressState state = TaskbarProgressState.normal,
  }) async {
    if (!isAvailable) return;

    try {
      await _platform.invokeMethod('setProgress', {
        'progress': (progress * 100).toInt(),
        'state': state.identifier,
      });

      _currentProgress = progress;
      _currentProgressState = state;

      log('$_logTag: Taskbar progress set: ${(progress * 100).toInt()}% (${state.identifier})',
          name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to set taskbar progress: $e', name: _logTag);
    }
  }

  /// Clear taskbar progress
  Future<void> clearProgress() async {
    if (!isAvailable) return;

    try {
      await _platform.invokeMethod('clearProgress');
      _currentProgress = 0.0;
      _currentProgressState = TaskbarProgressState.none;
      log('$_logTag: Taskbar progress cleared', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to clear taskbar progress: $e', name: _logTag);
    }
  }

  /// Set taskbar overlay icon
  Future<void> setOverlayIcon(TaskbarOverlay? overlay) async {
    if (!isAvailable) return;

    try {
      if (overlay != null) {
        await _platform.invokeMethod('setOverlayIcon', overlay.toJson());
        log('$_logTag: Taskbar overlay icon set: ${overlay.description}',
            name: _logTag);
      } else {
        await _platform.invokeMethod('clearOverlayIcon');
        log('$_logTag: Taskbar overlay icon cleared', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Failed to set taskbar overlay icon: $e', name: _logTag);
    }
  }

  /// Set thumbnail toolbar buttons
  Future<void> setThumbnailButtons(List<ThumbnailButton> buttons) async {
    if (!isAvailable) return;

    try {
      final buttonsJson = buttons.map((button) => button.toJson()).toList();
      await _platform.invokeMethod('setThumbnailButtons', {
        'buttons': buttonsJson,
      });

      _thumbnailButtons = buttons;
      log('$_logTag: Thumbnail toolbar buttons set: ${buttons.length} buttons',
          name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to set thumbnail buttons: $e', name: _logTag);
    }
  }

  /// Update thumbnail button state
  Future<void> updateThumbnailButton({
    required String buttonId,
    bool? enabled,
    bool? visible,
    String? iconPath,
    String? tooltip,
  }) async {
    if (!isAvailable) return;

    try {
      await _platform.invokeMethod('updateThumbnailButton', {
        'buttonId': buttonId,
        'enabled': enabled,
        'visible': visible,
        'iconPath': iconPath,
        'tooltip': tooltip,
      });

      // Update local state
      final buttonIndex = _thumbnailButtons.indexWhere((b) => b.id == buttonId);
      if (buttonIndex != -1) {
        final button = _thumbnailButtons[buttonIndex];
        _thumbnailButtons[buttonIndex] = ThumbnailButton(
          id: button.id,
          iconPath: iconPath ?? button.iconPath,
          tooltip: tooltip ?? button.tooltip,
          enabled: enabled ?? button.enabled,
          visible: visible ?? button.visible,
          dismissOnClick: button.dismissOnClick,
        );
      }

      log('$_logTag: Thumbnail button updated: $buttonId', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to update thumbnail button: $e', name: _logTag);
    }
  }

  /// Flash taskbar button
  Future<void> flashTaskbarButton([TaskbarFlashInfo? flashInfo]) async {
    if (!isAvailable) return;

    try {
      final info = flashInfo ?? const TaskbarFlashInfo();
      await _platform.invokeMethod('flashTaskbarButton', info.toJson());
      log('$_logTag: Taskbar button flashed', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to flash taskbar button: $e', name: _logTag);
    }
  }

  /// Set window thumbnail clip area
  Future<void> setThumbnailClip({
    required int x,
    required int y,
    required int width,
    required int height,
  }) async {
    if (!isAvailable) return;

    try {
      await _platform.invokeMethod('setThumbnailClip', {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      });
      log('$_logTag: Thumbnail clip area set: $x,$y ${width}x$height',
          name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to set thumbnail clip: $e', name: _logTag);
    }
  }

  /// Clear window thumbnail clip area
  Future<void> clearThumbnailClip() async {
    if (!isAvailable) return;

    try {
      await _platform.invokeMethod('clearThumbnailClip');
      log('$_logTag: Thumbnail clip area cleared', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to clear thumbnail clip: $e', name: _logTag);
    }
  }

  /// Update recording state in taskbar
  Future<void> updateRecordingState({
    required bool isRecording,
    bool isPaused = false,
    Duration? duration,
    double transcriptionProgress = 0.0,
    bool isTranscribing = false,
  }) async {
    if (!isAvailable) return;

    try {
      // Update progress based on state
      if (isRecording && !isPaused) {
        await setProgress(
          progress: duration != null ? (duration.inSeconds % 60) / 60.0 : 0.0,
          state: TaskbarProgressState.normal,
        );
      } else if (isPaused) {
        await setProgress(
          progress: _currentProgress,
          state: TaskbarProgressState.paused,
        );
      } else if (isTranscribing) {
        await setProgress(
          progress: transcriptionProgress,
          state: TaskbarProgressState.indeterminate,
        );
      } else {
        await clearProgress();
      }

      // Update overlay icon
      TaskbarOverlay? overlay;
      if (isRecording && !isPaused) {
        overlay = const TaskbarOverlay(
          iconPath: 'assets/icons/recording_overlay.ico',
          description: 'Recording Active',
        );
      } else if (isPaused) {
        overlay = const TaskbarOverlay(
          iconPath: 'assets/icons/paused_overlay.ico',
          description: 'Recording Paused',
        );
      } else if (isTranscribing) {
        overlay = const TaskbarOverlay(
          iconPath: 'assets/icons/transcribing_overlay.ico',
          description: 'Transcribing',
        );
      }
      await setOverlayIcon(overlay);

      // Update thumbnail buttons
      final buttons = <ThumbnailButton>[];
      if (isRecording) {
        if (isPaused) {
          buttons.addAll([
            const ThumbnailButton(
              id: 'resume_recording',
              iconPath: 'assets/icons/resume_recording.ico',
              tooltip: 'Resume Recording',
            ),
            const ThumbnailButton(
              id: 'stop_recording',
              iconPath: 'assets/icons/stop_recording.ico',
              tooltip: 'Stop Recording',
            ),
          ]);
        } else {
          buttons.addAll([
            const ThumbnailButton(
              id: 'pause_recording',
              iconPath: 'assets/icons/pause_recording.ico',
              tooltip: 'Pause Recording',
            ),
            const ThumbnailButton(
              id: 'stop_recording',
              iconPath: 'assets/icons/stop_recording.ico',
              tooltip: 'Stop Recording',
            ),
          ]);
        }
      } else {
        buttons.addAll([
          const ThumbnailButton(
            id: 'start_recording',
            iconPath: 'assets/icons/start_recording.ico',
            tooltip: 'Start Recording',
          ),
          const ThumbnailButton(
            id: 'view_recordings',
            iconPath: 'assets/icons/view_recordings.ico',
            tooltip: 'View Recordings',
          ),
          const ThumbnailButton(
            id: 'settings',
            iconPath: 'assets/icons/settings.ico',
            tooltip: 'Settings',
          ),
        ]);
      }

      await setThumbnailButtons(buttons);
    } catch (e) {
      log('$_logTag: Failed to update recording state: $e', name: _logTag);
    }
  }

  /// Get current taskbar state
  Map<String, dynamic> getTaskbarState() {
    return {
      'isAvailable': isAvailable,
      'isSupported': isSupported,
      'currentProgress': _currentProgress,
      'currentProgressState': _currentProgressState.identifier,
      'thumbnailButtonsCount': _thumbnailButtons.length,
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  }

  /// Get current thumbnail buttons
  List<ThumbnailButton> get thumbnailButtons =>
      List.unmodifiable(_thumbnailButtons);

  /// Get current progress
  double get currentProgress => _currentProgress;

  /// Get current progress state
  TaskbarProgressState get currentProgressState => _currentProgressState;

  /// Dispose resources
  void dispose() {
    try {
      // Clear callbacks
      onThumbnailButtonClick = null;
      onTaskbarStateChanged = null;

      // Clear taskbar state
      _thumbnailButtons.clear();
      _currentProgress = 0.0;
      _currentProgressState = TaskbarProgressState.none;

      _isInitialized = false;
      log('$_logTag: Service disposed', name: _logTag);
    } catch (e) {
      log('$_logTag: Error disposing service: $e', name: _logTag);
    }
  }
}
