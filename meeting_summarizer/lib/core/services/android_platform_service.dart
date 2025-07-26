/// Comprehensive Android Platform Services Integration
///
/// This service provides complete Android-specific functionality including:
/// - Android Auto integration for in-vehicle recording
/// - Quick Settings tile for one-tap recording access
/// - Home screen widgets for recording controls
/// - Google Assistant integration for voice activation
/// - Work Profile support for enterprise security
/// - Foreground service for background recording capabilities
library;

import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'platform_services/android_auto_service.dart';
import 'platform_services/platform_service_interface.dart';

/// Android-specific platform service implementation
class AndroidPlatformService
    implements PlatformIntegrationInterface, PlatformSystemInterface {
  static const String _logTag = 'AndroidPlatformService';
  static const String _channelName =
      'com.yhsung.meeting_summarizer/android_platform';

  // Platform channel for native Android communication
  static const MethodChannel _platform = MethodChannel(_channelName);

  // Sub-services
  late final AndroidAutoService _androidAutoService;
  late final FlutterLocalNotificationsPlugin _notificationsPlugin;

  // Service state
  bool _isInitialized = false;
  bool _foregroundServiceActive = false;
  bool _quickSettingsTileEnabled = false;
  bool _workProfileSupported = false;

  // Callbacks
  void Function(String action, Map<String, dynamic>? parameters)?
      onPlatformAction;
  void Function(String assistantCommand, Map<String, dynamic>? parameters)?
      onAssistantCommand;
  void Function(bool isActive)? onForegroundServiceStateChanged;

  /// Initialize all Android platform services
  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      if (!Platform.isAndroid) {
        log('$_logTag: Android platform services only available on Android',
            name: _logTag);
        return false;
      }

      // Initialize notifications plugin
      _notificationsPlugin = FlutterLocalNotificationsPlugin();

      // Initialize Android Auto service
      _androidAutoService = AndroidAutoService();
      await _androidAutoService.initialize();

      // Set up Android Auto callbacks
      _androidAutoService.onWidgetAction = (action, params) {
        _handleWidgetAction(action.identifier, params);
      };

      // Initialize platform channel communication
      await _initializePlatformChannel();

      // Initialize individual Android services
      await _initializeQuickSettingsTile();
      await _initializeHomeScreenWidgets();
      await _initializeGoogleAssistant();
      await _initializeWorkProfileSupport();
      await _initializeForegroundService();

      _isInitialized = true;
      log('$_logTag: Android platform services initialized successfully',
          name: _logTag);
      return true;
    } catch (e) {
      log('$_logTag: Failed to initialize Android platform services: $e',
          name: _logTag);
      return false;
    }
  }

  /// Check if Android platform services are available
  @override
  bool get isAvailable => Platform.isAndroid && _isInitialized;

  /// Initialize platform channel for native Android communication
  Future<void> _initializePlatformChannel() async {
    try {
      // Set up method call handler for platform channel
      _platform.setMethodCallHandler(_handleNativeMethodCall);

      // Test platform channel connectivity
      final result = await _platform.invokeMethod<bool>('initialize') ?? false;
      if (!result) {
        log('$_logTag: Failed to initialize native Android platform channel',
            name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Platform channel initialization error: $e', name: _logTag);
    }
  }

  /// Handle method calls from native Android code
  Future<void> _handleNativeMethodCall(MethodCall call) async {
    try {
      log('$_logTag: Received native method call: ${call.method}',
          name: _logTag);

      switch (call.method) {
        case 'onQuickSettingsTileClick':
          await _handleQuickSettingsTileClick();
          break;

        case 'onAssistantCommand':
          final command = call.arguments['command'] as String?;
          final parameters =
              call.arguments['parameters'] as Map<String, dynamic>?;
          if (command != null) {
            await _handleAssistantCommand(command, parameters);
          }
          break;

        case 'onWidgetAction':
          final action = call.arguments['action'] as String?;
          final parameters =
              call.arguments['parameters'] as Map<String, dynamic>?;
          if (action != null) {
            _handleWidgetAction(action, parameters);
          }
          break;

        case 'onForegroundServiceStateChanged':
          final isActive = call.arguments['isActive'] as bool? ?? false;
          _foregroundServiceActive = isActive;
          onForegroundServiceStateChanged?.call(isActive);
          break;

        default:
          log('$_logTag: Unknown native method call: ${call.method}',
              name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error handling native method call: $e', name: _logTag);
    }
  }

  // ==================== SUBTASK 5.1: Android Auto Integration ====================

  /// Get Android Auto service for direct access
  AndroidAutoService get androidAutoService => _androidAutoService;

  /// Update Android Auto display with recording status
  Future<void> updateAndroidAutoDisplay({
    required bool isRecording,
    Duration? recordingDuration,
    bool isTranscribing = false,
    String? status,
  }) async {
    if (!isAvailable) return;

    try {
      await _androidAutoService.updateAutoDisplay(
        title: isRecording
            ? 'Meeting Recorder - Recording'
            : 'Meeting Recorder - Ready',
        subtitle: isRecording
            ? 'Duration: ${_formatDuration(recordingDuration)}'
            : (isTranscribing ? 'Transcribing...' : 'Tap to start recording'),
        actions: isRecording
            ? ['Stop Recording', 'Pause Recording']
            : ['Start Recording', 'View Recordings'],
        isRecording: isRecording,
      );

      // Also update widgets
      await _androidAutoService.updateHomeWidgets(
        isRecording: isRecording,
        recordingDuration: recordingDuration,
        isTranscribing: isTranscribing,
        status: status ?? (isRecording ? 'Recording' : 'Ready'),
      );
    } catch (e) {
      log('$_logTag: Failed to update Android Auto display: $e', name: _logTag);
    }
  }

  // ==================== SUBTASK 5.2: Quick Settings Tile ====================

  /// Initialize Quick Settings tile
  Future<void> _initializeQuickSettingsTile() async {
    try {
      final result =
          await _platform.invokeMethod<bool>('setupQuickSettingsTile') ?? false;
      _quickSettingsTileEnabled = result;

      if (result) {
        log('$_logTag: Quick Settings tile enabled successfully',
            name: _logTag);
      } else {
        log('$_logTag: Failed to enable Quick Settings tile', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing Quick Settings tile: $e',
          name: _logTag);
    }
  }

  /// Handle Quick Settings tile click
  Future<void> _handleQuickSettingsTileClick() async {
    try {
      log('$_logTag: Quick Settings tile clicked', name: _logTag);

      // Toggle recording state
      onPlatformAction?.call('toggle_recording', {'source': 'quick_settings'});

      // Update tile state
      await updateQuickSettingsTile(isRecording: !_foregroundServiceActive);
    } catch (e) {
      log('$_logTag: Error handling Quick Settings tile click: $e',
          name: _logTag);
    }
  }

  /// Update Quick Settings tile state
  Future<void> updateQuickSettingsTile({
    required bool isRecording,
    String? status,
  }) async {
    if (!_quickSettingsTileEnabled) return;

    try {
      await _platform.invokeMethod('updateQuickSettingsTile', {
        'isRecording': isRecording,
        'status':
            status ?? (isRecording ? 'Recording Active' : 'Tap to Record'),
        'subtitle': isRecording ? 'Tap to stop' : 'Start new recording',
      });
    } catch (e) {
      log('$_logTag: Failed to update Quick Settings tile: $e', name: _logTag);
    }
  }

  // ==================== SUBTASK 5.3: Home Screen Widgets ====================

  /// Initialize home screen widgets
  Future<void> _initializeHomeScreenWidgets() async {
    try {
      // Already initialized through AndroidAutoService
      await _androidAutoService.setupWidgetConfiguration();

      // Configure additional widget layouts
      await _setupAdvancedWidgetLayouts();

      log('$_logTag: Home screen widgets initialized', name: _logTag);
    } catch (e) {
      log('$_logTag: Error initializing home screen widgets: $e',
          name: _logTag);
    }
  }

  /// Set up advanced widget layouts and configurations
  Future<void> _setupAdvancedWidgetLayouts() async {
    try {
      // Configure widget data for different widget sizes
      await HomeWidget.saveWidgetData('widget_theme', 'material_you');
      await HomeWidget.saveWidgetData('show_waveform', true);
      await HomeWidget.saveWidgetData('auto_start_enabled', false);
      await HomeWidget.saveWidgetData('battery_optimization_warning', false);

      // Set up widget action URLs
      await HomeWidget.saveWidgetData('start_recording_url',
          'meetingsummarizer://action?type=start_recording&source=widget');
      await HomeWidget.saveWidgetData('stop_recording_url',
          'meetingsummarizer://action?type=stop_recording&source=widget');
      await HomeWidget.saveWidgetData('open_app_url',
          'meetingsummarizer://action?type=open_app&source=widget');
    } catch (e) {
      log('$_logTag: Failed to setup advanced widget layouts: $e',
          name: _logTag);
    }
  }

  /// Update all home screen widgets with current state
  Future<void> updateHomeScreenWidgets({
    required bool isRecording,
    Duration? recordingDuration,
    bool isTranscribing = false,
    double transcriptionProgress = 0.0,
    int recentRecordingsCount = 0,
    String? batteryLevel,
    bool lowPowerMode = false,
  }) async {
    try {
      await _androidAutoService.updateHomeWidgets(
        isRecording: isRecording,
        recordingDuration: recordingDuration,
        isTranscribing: isTranscribing,
        transcriptionProgress: transcriptionProgress,
        recentRecordingsCount: recentRecordingsCount,
        status: _getWidgetStatus(isRecording, isTranscribing, lowPowerMode),
      );

      // Update additional widget data
      if (batteryLevel != null) {
        await HomeWidget.saveWidgetData('battery_level', batteryLevel);
      }
      await HomeWidget.saveWidgetData('low_power_mode', lowPowerMode);
      await HomeWidget.saveWidgetData(
          'last_sync', DateTime.now().toIso8601String());
    } catch (e) {
      log('$_logTag: Failed to update home screen widgets: $e', name: _logTag);
    }
  }

  /// Get appropriate widget status text
  String _getWidgetStatus(
      bool isRecording, bool isTranscribing, bool lowPowerMode) {
    if (lowPowerMode && isRecording) return 'Recording (Battery Saver)';
    if (isRecording) return 'Recording Active';
    if (isTranscribing) return 'Processing Audio';
    if (lowPowerMode) return 'Ready (Battery Saver)';
    return 'Ready to Record';
  }

  // ==================== SUBTASK 5.4: Google Assistant Integration ====================

  /// Initialize Google Assistant integration
  Future<void> _initializeGoogleAssistant() async {
    try {
      final result =
          await _platform.invokeMethod<bool>('setupGoogleAssistant') ?? false;

      if (result) {
        log('$_logTag: Google Assistant integration enabled', name: _logTag);
        await _registerAssistantActions();
      } else {
        log('$_logTag: Google Assistant integration not available',
            name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing Google Assistant: $e', name: _logTag);
    }
  }

  /// Register Assistant actions and shortcuts
  Future<void> _registerAssistantActions() async {
    try {
      final actions = [
        {
          'action': 'start_recording',
          'phrases': [
            'start recording meeting',
            'begin recording',
            'record meeting'
          ],
          'description': 'Start recording a new meeting',
        },
        {
          'action': 'stop_recording',
          'phrases': ['stop recording', 'end recording', 'finish recording'],
          'description': 'Stop the current recording',
        },
        {
          'action': 'transcribe_recording',
          'phrases': [
            'transcribe recording',
            'convert to text',
            'generate transcript'
          ],
          'description': 'Start transcription of the recording',
        },
        {
          'action': 'show_recent_recordings',
          'phrases': ['show recordings', 'my recordings', 'recent meetings'],
          'description': 'Display recent recordings list',
        },
      ];

      for (final action in actions) {
        await _platform.invokeMethod('registerAssistantAction', action);
      }
    } catch (e) {
      log('$_logTag: Failed to register Assistant actions: $e', name: _logTag);
    }
  }

  /// Handle Google Assistant command
  Future<void> _handleAssistantCommand(
      String command, Map<String, dynamic>? parameters) async {
    try {
      log('$_logTag: Handling Assistant command: $command', name: _logTag);

      // Provide audio feedback for Assistant
      await _provideAssistantFeedback(command);

      // Execute the command
      onAssistantCommand?.call(command, parameters);

      // Update Assistant with result
      await _updateAssistantResult(command, true);
    } catch (e) {
      log('$_logTag: Error handling Assistant command: $e', name: _logTag);
      await _updateAssistantResult(command, false, error: e.toString());
    }
  }

  /// Provide audio feedback for Assistant interactions
  Future<void> _provideAssistantFeedback(String command) async {
    try {
      String feedback;
      switch (command) {
        case 'start_recording':
          feedback = 'Starting meeting recording';
          break;
        case 'stop_recording':
          feedback = 'Stopping recording';
          break;
        case 'transcribe_recording':
          feedback = 'Starting transcription';
          break;
        default:
          feedback = 'Processing request';
      }

      await _platform
          .invokeMethod('speakAssistantFeedback', {'text': feedback});
    } catch (e) {
      log('$_logTag: Failed to provide Assistant feedback: $e', name: _logTag);
    }
  }

  /// Update Assistant with command result
  Future<void> _updateAssistantResult(String command, bool success,
      {String? error}) async {
    try {
      await _platform.invokeMethod('updateAssistantResult', {
        'command': command,
        'success': success,
        'error': error,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      log('$_logTag: Failed to update Assistant result: $e', name: _logTag);
    }
  }

  // ==================== SUBTASK 5.5: Work Profile Support ====================

  /// Initialize work profile support
  Future<void> _initializeWorkProfileSupport() async {
    try {
      final result =
          await _platform.invokeMethod<Map>('checkWorkProfileSupport');

      if (result != null) {
        _workProfileSupported = result['supported'] as bool? ?? false;

        if (_workProfileSupported) {
          await _setupWorkProfileFeatures(result);
          log('$_logTag: Work profile support enabled', name: _logTag);
        } else {
          log('$_logTag: Work profile not available', name: _logTag);
        }
      }
    } catch (e) {
      log('$_logTag: Error checking work profile support: $e', name: _logTag);
    }
  }

  /// Set up work profile specific features
  Future<void> _setupWorkProfileFeatures(Map workProfileInfo) async {
    try {
      final isWorkProfile = workProfileInfo['isWorkProfile'] as bool? ?? false;
      final hasWorkPolicyRestrictions =
          workProfileInfo['hasPolicyRestrictions'] as bool? ?? false;

      if (isWorkProfile) {
        // Configure for work profile environment
        await _configureWorkProfileSecurity();
        await _setupWorkProfileCompliance();

        if (hasWorkPolicyRestrictions) {
          await _applyWorkProfileRestrictions(workProfileInfo);
        }
      }
    } catch (e) {
      log('$_logTag: Failed to setup work profile features: $e', name: _logTag);
    }
  }

  /// Configure security features for work profile
  Future<void> _configureWorkProfileSecurity() async {
    try {
      await _platform.invokeMethod('configureWorkProfileSecurity', {
        'requireBiometric': true,
        'enforceScreenLock': true,
        'restrictFileSharing': true,
        'enableAuditLogging': true,
      });
    } catch (e) {
      log('$_logTag: Failed to configure work profile security: $e',
          name: _logTag);
    }
  }

  /// Setup work profile compliance monitoring
  Future<void> _setupWorkProfileCompliance() async {
    try {
      await _platform.invokeMethod('setupWorkProfileCompliance', {
        'monitorDataUsage': true,
        'trackRecordingLocations': true,
        'enforceRetentionPolicies': true,
        'enableRemoteWipe': true,
      });
    } catch (e) {
      log('$_logTag: Failed to setup work profile compliance: $e',
          name: _logTag);
    }
  }

  /// Apply work profile policy restrictions
  Future<void> _applyWorkProfileRestrictions(Map restrictions) async {
    try {
      await _platform.invokeMethod(
          'applyWorkProfileRestrictions', restrictions);
      log('$_logTag: Work profile restrictions applied', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to apply work profile restrictions: $e',
          name: _logTag);
    }
  }

  /// Check if currently running in work profile
  Future<bool> isWorkProfile() async {
    if (!_workProfileSupported) return false;

    try {
      return await _platform.invokeMethod<bool>('isWorkProfile') ?? false;
    } catch (e) {
      log('$_logTag: Failed to check work profile status: $e', name: _logTag);
      return false;
    }
  }

  // ==================== SUBTASK 5.6: Foreground Service ====================

  /// Initialize foreground service
  Future<void> _initializeForegroundService() async {
    try {
      final result =
          await _platform.invokeMethod<bool>('initializeForegroundService') ??
              false;

      if (result) {
        log('$_logTag: Foreground service initialized', name: _logTag);
      } else {
        log('$_logTag: Failed to initialize foreground service', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing foreground service: $e', name: _logTag);
    }
  }

  /// Start foreground service for background recording
  Future<bool> startForegroundService({
    required String title,
    required String content,
    String? channelId,
    String? channelName,
  }) async {
    if (!isAvailable) return false;

    try {
      final result =
          await _platform.invokeMethod<bool>('startForegroundService', {
        'title': title,
        'content': content,
        'channelId': channelId ?? 'recording_service',
        'channelName': channelName ?? 'Recording Service',
        'importance': 'high',
        'priority': 'high',
        'showWhen': true,
        'ongoing': true,
        'autoCancel': false,
      });

      if (result == true) {
        _foregroundServiceActive = true;
        onForegroundServiceStateChanged?.call(true);
        log('$_logTag: Foreground service started', name: _logTag);
      }

      return result ?? false;
    } catch (e) {
      log('$_logTag: Failed to start foreground service: $e', name: _logTag);
      return false;
    }
  }

  /// Update foreground service notification
  Future<void> updateForegroundService({
    String? title,
    String? content,
    int? progress,
    bool? indeterminate,
    Map<String, String>? actions,
  }) async {
    if (!_foregroundServiceActive) return;

    try {
      await _platform.invokeMethod('updateForegroundService', {
        'title': title,
        'content': content,
        'progress': progress,
        'indeterminate': indeterminate ?? false,
        'actions': actions ?? {},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      log('$_logTag: Failed to update foreground service: $e', name: _logTag);
    }
  }

  /// Stop foreground service
  Future<void> stopForegroundService() async {
    if (!_foregroundServiceActive) return;

    try {
      await _platform.invokeMethod('stopForegroundService');
      _foregroundServiceActive = false;
      onForegroundServiceStateChanged?.call(false);
      log('$_logTag: Foreground service stopped', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to stop foreground service: $e', name: _logTag);
    }
  }

  /// Get foreground service status
  bool get isForegroundServiceActive => _foregroundServiceActive;

  // ==================== Platform Service Interface Implementation ====================

  @override
  Future<bool> registerIntegrations() async {
    try {
      // Re-register all integrations
      await _initializeQuickSettingsTile();
      await _initializeHomeScreenWidgets();
      await _initializeGoogleAssistant();

      return true;
    } catch (e) {
      log('$_logTag: Failed to register integrations: $e', name: _logTag);
      return false;
    }
  }

  @override
  Future<void> handleAction(
      String action, Map<String, dynamic>? parameters) async {
    try {
      log('$_logTag: Handling platform action: $action', name: _logTag);

      switch (action) {
        case 'start_recording':
          await startForegroundService(
            title: 'Recording Meeting',
            content: 'Tap to stop recording',
          );
          break;

        case 'stop_recording':
          await stopForegroundService();
          break;

        case 'toggle_recording':
          if (_foregroundServiceActive) {
            await stopForegroundService();
          } else {
            await startForegroundService(
              title: 'Recording Meeting',
              content: 'Tap to stop recording',
            );
          }
          break;

        default:
          log('$_logTag: Unknown platform action: $action', name: _logTag);
      }

      // Notify callback
      onPlatformAction?.call(action, parameters);
    } catch (e) {
      log('$_logTag: Error handling platform action: $e', name: _logTag);
    }
  }

  @override
  Future<void> updateIntegrations(Map<String, dynamic> state) async {
    try {
      final isRecording = state['isRecording'] as bool? ?? false;
      final recordingDuration = state['recordingDuration'] as Duration?;
      final isTranscribing = state['isTranscribing'] as bool? ?? false;
      final transcriptionProgress =
          state['transcriptionProgress'] as double? ?? 0.0;
      final recentCount = state['recentRecordingsCount'] as int? ?? 0;
      final batteryLevel = state['batteryLevel'] as String?;
      final lowPowerMode = state['lowPowerMode'] as bool? ?? false;

      // Update all integrations with current state
      await updateAndroidAutoDisplay(
        isRecording: isRecording,
        recordingDuration: recordingDuration,
        isTranscribing: isTranscribing,
      );

      await updateQuickSettingsTile(
        isRecording: isRecording,
        status: state['status'] as String?,
      );

      await updateHomeScreenWidgets(
        isRecording: isRecording,
        recordingDuration: recordingDuration,
        isTranscribing: isTranscribing,
        transcriptionProgress: transcriptionProgress,
        recentRecordingsCount: recentCount,
        batteryLevel: batteryLevel,
        lowPowerMode: lowPowerMode,
      );

      // Update foreground service if active
      if (_foregroundServiceActive && isRecording) {
        await updateForegroundService(
          title: 'Recording Meeting',
          content: 'Duration: ${_formatDuration(recordingDuration)}',
          progress:
              isTranscribing ? (transcriptionProgress * 100).toInt() : null,
          indeterminate: isRecording && !isTranscribing,
        );
      }
    } catch (e) {
      log('$_logTag: Error updating integrations: $e', name: _logTag);
    }
  }

  @override
  Future<bool> showSystemUI() async {
    // Enable all Android UI elements
    try {
      await updateQuickSettingsTile(isRecording: false);
      await updateHomeScreenWidgets(isRecording: false);
      return true;
    } catch (e) {
      log('$_logTag: Failed to show system UI: $e', name: _logTag);
      return false;
    }
  }

  @override
  Future<void> hideSystemUI() async {
    // Hide non-essential UI elements but keep core functionality
    try {
      await stopForegroundService();
    } catch (e) {
      log('$_logTag: Error hiding system UI: $e', name: _logTag);
    }
  }

  @override
  Future<void> updateSystemUIState(Map<String, dynamic> state) async {
    await updateIntegrations(state);
  }

  // ==================== Helper Methods ====================

  /// Handle widget action from any source
  void _handleWidgetAction(String action, Map<String, dynamic>? parameters) {
    try {
      log('$_logTag: Handling widget action: $action', name: _logTag);
      onPlatformAction?.call(action, parameters);
    } catch (e) {
      log('$_logTag: Error handling widget action: $e', name: _logTag);
    }
  }

  /// Format duration for display
  String _formatDuration(Duration? duration) {
    if (duration == null) return '00:00';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Get comprehensive service status
  Map<String, dynamic> getServiceStatus() {
    return {
      'isInitialized': _isInitialized,
      'isAvailable': isAvailable,
      'foregroundServiceActive': _foregroundServiceActive,
      'quickSettingsTileEnabled': _quickSettingsTileEnabled,
      'workProfileSupported': _workProfileSupported,
      'androidAutoState': _androidAutoService.autoState.value,
      'platform': 'android',
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// Dispose all resources and cleanup
  @override
  void dispose() {
    try {
      // Stop foreground service
      if (_foregroundServiceActive) {
        stopForegroundService();
      }

      // Dispose sub-services
      _androidAutoService.dispose();

      // Clear callbacks
      onPlatformAction = null;
      onAssistantCommand = null;
      onForegroundServiceStateChanged = null;

      _isInitialized = false;
      log('$_logTag: Android platform service disposed', name: _logTag);
    } catch (e) {
      log('$_logTag: Error disposing service: $e', name: _logTag);
    }
  }
}
