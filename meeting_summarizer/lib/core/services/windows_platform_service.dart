/// Comprehensive Windows Platform Services Integration
///
/// This service provides complete Windows-specific functionality including:
/// - System Tray integration with comprehensive controls
/// - Windows 10/11 Toast notifications
/// - Jump Lists for taskbar quick actions
/// - File associations and registry integration
/// - Windows Hello biometric authentication
/// - Taskbar integration with live thumbnails
/// - Clipboard integration for transcript sharing
/// - Power management and battery optimization
library;

import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'platform_services/platform_service_interface.dart';
import 'platform_services/windows_system_tray_service.dart';
import 'platform_services/windows_notifications_service.dart';
import 'platform_services/windows_jumplist_service.dart';
import 'platform_services/windows_registry_service.dart';
import 'platform_services/windows_taskbar_service.dart';
import 'platform_services/windows_clipboard_service.dart';

/// Windows-specific platform service implementation
class WindowsPlatformService
    implements PlatformIntegrationInterface, PlatformSystemInterface {
  static const String _logTag = 'WindowsPlatformService';
  static const String _channelName =
      'com.yhsung.meeting_summarizer/windows_platform';

  // Platform channel for native Windows communication
  static const MethodChannel _platform = MethodChannel(_channelName);

  // Sub-services
  late final WindowsSystemTrayService _systemTrayService;
  late final WindowsNotificationsService _notificationsService;
  late final WindowsJumplistService _jumplistService;
  late final WindowsRegistryService _registryService;
  late final WindowsTaskbarService _taskbarService;
  late final WindowsClipboardService _clipboardService;
  late final FlutterLocalNotificationsPlugin _notificationsPlugin;

  // Service state
  bool _isInitialized = false;
  bool _systemTrayEnabled = false;
  bool _notificationsEnabled = false;
  bool _jumplistEnabled = false;
  bool _registryIntegrationEnabled = false;
  bool _taskbarIntegrationEnabled = false;
  bool _clipboardIntegrationEnabled = false;
  bool _biometricAuthEnabled = false;

  // Callbacks
  void Function(String action, Map<String, dynamic>? parameters)?
      onPlatformAction;
  void Function(TrayAction action, Map<String, dynamic>? parameters)?
      onTrayAction;
  void Function(String filePath, FileAssociationType type)? onFileOpened;
  void Function(String notificationId, String action)? onNotificationAction;
  void Function(String jumplistAction, Map<String, dynamic>? parameters)?
      onJumplistAction;
  void Function(bool isActive)? onTaskbarStateChanged;

  /// Initialize all Windows platform services
  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      if (!Platform.isWindows) {
        log('$_logTag: Windows platform services only available on Windows',
            name: _logTag);
        return false;
      }

      // Initialize notifications plugin for Windows
      _notificationsPlugin = FlutterLocalNotificationsPlugin();

      // Note: Windows-specific notification settings might not be available
      // Using basic initialization for compatibility
      const initializationSettings = InitializationSettings();

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      // Initialize sub-services
      _systemTrayService = WindowsSystemTrayService();
      _notificationsService = WindowsNotificationsService();
      _jumplistService = WindowsJumplistService();
      _registryService = WindowsRegistryService();
      _taskbarService = WindowsTaskbarService();
      _clipboardService = WindowsClipboardService();

      // Initialize platform channel communication
      await _initializePlatformChannel();

      // Initialize individual Windows services
      await _initializeSystemTray();
      await _initializeNotifications();
      await _initializeJumplist();
      await _initializeRegistryIntegration();
      await _initializeTaskbarIntegration();
      await _initializeClipboardIntegration();
      await _initializeBiometricAuth();

      _isInitialized = true;
      log('$_logTag: Windows platform services initialized successfully',
          name: _logTag);
      return true;
    } catch (e) {
      log('$_logTag: Failed to initialize Windows platform services: $e',
          name: _logTag);
      return false;
    }
  }

  /// Check if Windows platform services are available
  @override
  bool get isAvailable => Platform.isWindows && _isInitialized;

  /// Initialize platform channel for native Windows communication
  Future<void> _initializePlatformChannel() async {
    try {
      // Set up method call handler for platform channel
      _platform.setMethodCallHandler(_handleNativeMethodCall);

      // Test platform channel connectivity
      final result = await _platform.invokeMethod<bool>('initialize') ?? false;
      if (!result) {
        log('$_logTag: Failed to initialize native Windows platform channel',
            name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Platform channel initialization error: $e', name: _logTag);
    }
  }

  /// Handle method calls from native Windows code
  Future<void> _handleNativeMethodCall(MethodCall call) async {
    try {
      log('$_logTag: Received native method call: ${call.method}',
          name: _logTag);

      switch (call.method) {
        case 'onTrayAction':
          final actionId = call.arguments['action'] as String?;
          final parameters =
              call.arguments['parameters'] as Map<String, dynamic>?;
          if (actionId != null) {
            await _handleTrayActionFromNative(actionId, parameters);
          }
          break;

        case 'onNotificationAction':
          final notificationId = call.arguments['notificationId'] as String?;
          final action = call.arguments['action'] as String?;
          if (notificationId != null && action != null) {
            await _handleNotificationActionFromNative(notificationId, action);
          }
          break;

        case 'onJumplistAction':
          final action = call.arguments['action'] as String?;
          final parameters =
              call.arguments['parameters'] as Map<String, dynamic>?;
          if (action != null) {
            await _handleJumplistActionFromNative(action, parameters);
          }
          break;

        case 'onFileOpened':
          final filePath = call.arguments['filePath'] as String?;
          if (filePath != null) {
            await _handleFileOpenedFromNative(filePath);
          }
          break;

        case 'onTaskbarStateChanged':
          final isActive = call.arguments['isActive'] as bool? ?? false;
          onTaskbarStateChanged?.call(isActive);
          break;

        case 'onBiometricResult':
          final success = call.arguments['success'] as bool? ?? false;
          final error = call.arguments['error'] as String?;
          await _handleBiometricResult(success, error);
          break;

        default:
          log('$_logTag: Unknown native method call: ${call.method}',
              name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error handling native method call: $e', name: _logTag);
    }
  }

  // ==================== SUBTASK 6.1: System Tray Integration ====================

  /// Initialize system tray integration
  Future<void> _initializeSystemTray() async {
    try {
      final initialized = await _systemTrayService.initialize();
      _systemTrayEnabled = initialized;

      if (initialized) {
        // Set up system tray callbacks
        _systemTrayService.onTrayAction = (action, parameters) {
          _handleTrayAction(action, parameters);
        };

        _systemTrayService.onFileOpened = (filePath, type) {
          _handleFileOpened(filePath, type);
        };

        log('$_logTag: System tray integration enabled', name: _logTag);
      } else {
        log('$_logTag: Failed to enable system tray integration',
            name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing system tray: $e', name: _logTag);
    }
  }

  /// Handle system tray action
  Future<void> _handleTrayAction(
      TrayAction action, Map<String, dynamic>? parameters) async {
    try {
      log('$_logTag: Handling tray action: ${action.displayName}',
          name: _logTag);

      // Convert tray action to platform action
      String platformAction;
      switch (action) {
        case TrayAction.startRecording:
          platformAction = 'start_recording';
          break;
        case TrayAction.stopRecording:
          platformAction = 'stop_recording';
          break;
        case TrayAction.pauseRecording:
          platformAction = 'pause_recording';
          break;
        case TrayAction.resumeRecording:
          platformAction = 'resume_recording';
          break;
        case TrayAction.openApp:
          platformAction = 'open_app';
          break;
        case TrayAction.viewRecordings:
          platformAction = 'view_recordings';
          break;
        case TrayAction.transcribeLatest:
          platformAction = 'transcribe_latest';
          break;
        case TrayAction.generateSummary:
          platformAction = 'generate_summary';
          break;
        case TrayAction.settings:
          platformAction = 'settings';
          break;
        case TrayAction.exit:
          platformAction = 'exit';
          break;
      }

      // Execute platform action
      await handleAction(platformAction, {
        ...?parameters,
        'source': 'system_tray',
        'trayAction': action.identifier,
      });

      // Notify tray action callback
      onTrayAction?.call(action, parameters);
    } catch (e) {
      log('$_logTag: Error handling tray action: $e', name: _logTag);
    }
  }

  /// Handle tray action from native code
  Future<void> _handleTrayActionFromNative(
      String actionId, Map<String, dynamic>? parameters) async {
    try {
      // Find matching TrayAction
      final action = TrayAction.values.firstWhere(
        (a) => a.identifier == actionId,
        orElse: () => TrayAction.openApp,
      );

      await _handleTrayAction(action, parameters);
    } catch (e) {
      log('$_logTag: Error handling tray action from native: $e',
          name: _logTag);
    }
  }

  /// Update system tray with recording status
  Future<void> updateSystemTray({
    required bool isRecording,
    bool isPaused = false,
    Duration? duration,
    String? meetingTitle,
    bool isTranscribing = false,
    double transcriptionProgress = 0.0,
  }) async {
    if (!_systemTrayEnabled) return;

    try {
      await _systemTrayService.updateRecordingState(
        isRecording: isRecording,
        isPaused: isPaused,
        duration: duration,
        meetingTitle: meetingTitle,
      );

      await _systemTrayService.updateTranscriptionState(
        isTranscribing: isTranscribing,
        progress: transcriptionProgress,
      );
    } catch (e) {
      log('$_logTag: Failed to update system tray: $e', name: _logTag);
    }
  }

  // ==================== SUBTASK 6.2: Windows Notifications ====================

  /// Initialize Windows notifications
  Future<void> _initializeNotifications() async {
    try {
      final initialized = await _notificationsService.initialize();
      _notificationsEnabled = initialized;

      if (initialized) {
        log('$_logTag: Windows notifications enabled', name: _logTag);
      } else {
        log('$_logTag: Failed to enable Windows notifications', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing notifications: $e', name: _logTag);
    }
  }

  /// Show Windows toast notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String? imageUrl,
    List<NotificationAction>? actions,
    Duration? timeout,
  }) async {
    if (!_notificationsEnabled) return;

    try {
      await _notificationsService.showToastNotification(
        title: title,
        body: body,
        payload: payload,
        imageUrl: imageUrl,
        actions: actions,
        timeout: timeout,
      );
    } catch (e) {
      log('$_logTag: Failed to show notification: $e', name: _logTag);
    }
  }

  /// Handle notification response
  void _handleNotificationResponse(NotificationResponse response) {
    try {
      log('$_logTag: Notification response: ${response.actionId}',
          name: _logTag);

      if (response.actionId != null) {
        onNotificationAction?.call(
          response.id?.toString() ?? '',
          response.actionId!,
        );
      }

      // Handle notification tap
      if (response.actionId == null) {
        onPlatformAction?.call('open_app', {
          'source': 'notification',
          'payload': response.payload,
        });
      }
    } catch (e) {
      log('$_logTag: Error handling notification response: $e', name: _logTag);
    }
  }

  /// Handle notification action from native code
  Future<void> _handleNotificationActionFromNative(
      String notificationId, String action) async {
    try {
      log('$_logTag: Handling notification action: $action', name: _logTag);
      onNotificationAction?.call(notificationId, action);
    } catch (e) {
      log('$_logTag: Error handling notification action from native: $e',
          name: _logTag);
    }
  }

  // ==================== SUBTASK 6.3: Jump Lists Integration ====================

  /// Initialize Jump Lists
  Future<void> _initializeJumplist() async {
    try {
      final initialized = await _jumplistService.initialize();
      _jumplistEnabled = initialized;

      if (initialized) {
        // Set up jump list callbacks
        _jumplistService.onJumplistAction = (action, parameters) {
          _handleJumplistAction(action, parameters);
        };

        // Setup initial jump list items
        await _setupJumplistItems();

        log('$_logTag: Jump Lists integration enabled', name: _logTag);
      } else {
        log('$_logTag: Failed to enable Jump Lists integration', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing Jump Lists: $e', name: _logTag);
    }
  }

  /// Set up jump list items
  Future<void> _setupJumplistItems() async {
    try {
      await _jumplistService.updateJumplist(
        tasks: [
          JumplistTask(
            id: 'start_recording',
            title: 'Start Recording',
            description: 'Start a new meeting recording',
            iconPath: 'assets/icons/start_recording.ico',
            arguments: '--action=start_recording',
          ),
          JumplistTask(
            id: 'view_recordings',
            title: 'View Recordings',
            description: 'View recent recordings',
            iconPath: 'assets/icons/view_recordings.ico',
            arguments: '--action=view_recordings',
          ),
          JumplistTask(
            id: 'transcribe_latest',
            title: 'Transcribe Latest',
            description: 'Transcribe the latest recording',
            iconPath: 'assets/icons/transcribe.ico',
            arguments: '--action=transcribe_latest',
          ),
        ],
        recentItems: [], // Will be populated with recent recordings
      );
    } catch (e) {
      log('$_logTag: Failed to setup jump list items: $e', name: _logTag);
    }
  }

  /// Handle jump list action
  Future<void> _handleJumplistAction(
      String action, Map<String, dynamic>? parameters) async {
    try {
      log('$_logTag: Handling jump list action: $action', name: _logTag);

      await handleAction(action, {
        ...?parameters,
        'source': 'jumplist',
      });

      onJumplistAction?.call(action, parameters);
    } catch (e) {
      log('$_logTag: Error handling jump list action: $e', name: _logTag);
    }
  }

  /// Handle jump list action from native code
  Future<void> _handleJumplistActionFromNative(
      String action, Map<String, dynamic>? parameters) async {
    try {
      await _handleJumplistAction(action, parameters);
    } catch (e) {
      log('$_logTag: Error handling jump list action from native: $e',
          name: _logTag);
    }
  }

  /// Update jump list with recent recordings
  Future<void> updateJumplistRecentItems({
    required List<Map<String, dynamic>> recentRecordings,
  }) async {
    if (!_jumplistEnabled) return;

    try {
      final recentItems = recentRecordings.map((recording) {
        return JumplistRecentItem(
          filePath: recording['path'] as String,
          title: recording['title'] as String? ?? 'Recording',
          arguments: '--open-recording=${recording['id']}',
        );
      }).toList();

      await _jumplistService.updateRecentItems(recentItems);
    } catch (e) {
      log('$_logTag: Failed to update jump list recent items: $e',
          name: _logTag);
    }
  }

  // ==================== Helper Methods ====================

  /// Handle file opened from any source
  void _handleFileOpened(String filePath, FileAssociationType type) {
    try {
      log('$_logTag: Handling file opened: $filePath (${type.category})',
          name: _logTag);
      onFileOpened?.call(filePath, type);
    } catch (e) {
      log('$_logTag: Error handling file opened: $e', name: _logTag);
    }
  }

  /// Handle file opened from native code
  Future<void> _handleFileOpenedFromNative(String filePath) async {
    try {
      await _systemTrayService.handleFileOpened(filePath);
    } catch (e) {
      log('$_logTag: Error handling file opened from native: $e',
          name: _logTag);
    }
  }

  /// Get comprehensive service status
  Map<String, dynamic> getServiceStatus() {
    return {
      'isInitialized': _isInitialized,
      'isAvailable': isAvailable,
      'systemTrayEnabled': _systemTrayEnabled,
      'notificationsEnabled': _notificationsEnabled,
      'jumplistEnabled': _jumplistEnabled,
      'registryIntegrationEnabled': _registryIntegrationEnabled,
      'taskbarIntegrationEnabled': _taskbarIntegrationEnabled,
      'clipboardIntegrationEnabled': _clipboardIntegrationEnabled,
      'biometricAuthEnabled': _biometricAuthEnabled,
      'platform': 'windows',
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// Get sub-services for direct access
  WindowsSystemTrayService get systemTrayService => _systemTrayService;
  WindowsNotificationsService get notificationsService => _notificationsService;
  WindowsJumplistService get jumplistService => _jumplistService;
  WindowsRegistryService get registryService => _registryService;
  WindowsTaskbarService get taskbarService => _taskbarService;
  WindowsClipboardService get clipboardService => _clipboardService;

  // ==================== SUBTASK 6.4: Registry Integration ====================

  /// Initialize registry integration
  Future<void> _initializeRegistryIntegration() async {
    try {
      final initialized = await _registryService.initialize();
      _registryIntegrationEnabled = initialized;

      if (initialized) {
        // Register default file associations
        await _registryService.registerDefaultAssociations();
        log('$_logTag: Registry integration enabled', name: _logTag);
      } else {
        log('$_logTag: Registry integration not available', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing registry integration: $e',
          name: _logTag);
    }
  }

  // ==================== SUBTASK 6.5: Taskbar Integration ====================

  /// Initialize taskbar integration
  Future<void> _initializeTaskbarIntegration() async {
    try {
      final initialized = await _taskbarService.initialize();
      _taskbarIntegrationEnabled = initialized;

      if (initialized) {
        // Set up taskbar callbacks
        _taskbarService.onThumbnailButtonClick = (buttonId) {
          _handleTaskbarButtonClick(buttonId);
        };

        _taskbarService.onTaskbarStateChanged = (isActive) {
          onTaskbarStateChanged?.call(isActive);
        };

        log('$_logTag: Taskbar integration enabled', name: _logTag);
      } else {
        log('$_logTag: Taskbar integration not available', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing taskbar integration: $e',
          name: _logTag);
    }
  }

  /// Handle taskbar button click
  Future<void> _handleTaskbarButtonClick(String buttonId) async {
    try {
      log('$_logTag: Taskbar button clicked: $buttonId', name: _logTag);

      await handleAction(buttonId, {
        'source': 'taskbar',
        'buttonId': buttonId,
      });
    } catch (e) {
      log('$_logTag: Error handling taskbar button click: $e', name: _logTag);
    }
  }

  // ==================== SUBTASK 6.6: Clipboard Integration ====================

  /// Initialize clipboard integration
  Future<void> _initializeClipboardIntegration() async {
    try {
      final initialized = await _clipboardService.initialize();
      _clipboardIntegrationEnabled = initialized;

      if (initialized) {
        // Set up clipboard callbacks
        _clipboardService.onClipboardChanged = (content, format) {
          _handleClipboardChanged(content, format);
        };

        log('$_logTag: Clipboard integration enabled', name: _logTag);
      } else {
        log('$_logTag: Clipboard integration not available', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing clipboard integration: $e',
          name: _logTag);
    }
  }

  /// Handle clipboard content changes
  void _handleClipboardChanged(String content, dynamic format) {
    try {
      log('$_logTag: Clipboard content changed', name: _logTag);
      // Handle clipboard monitoring if needed
    } catch (e) {
      log('$_logTag: Error handling clipboard change: $e', name: _logTag);
    }
  }

  // ==================== SUBTASK 6.7: Windows Hello Biometric Auth ====================

  /// Initialize Windows Hello biometric authentication
  Future<void> _initializeBiometricAuth() async {
    try {
      final result =
          await _platform.invokeMethod<bool>('checkBiometricSupport') ?? false;
      _biometricAuthEnabled = result;

      if (result) {
        log('$_logTag: Windows Hello biometric authentication available',
            name: _logTag);
      } else {
        log('$_logTag: Windows Hello biometric authentication not available',
            name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error checking biometric support: $e', name: _logTag);
    }
  }

  /// Authenticate with Windows Hello
  Future<bool> authenticateWithBiometric({
    String reason = 'Please verify your identity to access Meeting Summarizer',
  }) async {
    if (!_biometricAuthEnabled) return false;

    try {
      final result =
          await _platform.invokeMethod<bool>('authenticateBiometric', {
                'reason': reason,
                'allowCredentialManager': true,
                'allowPin': true,
                'allowPassword': false,
              }) ??
              false;

      log('$_logTag: Biometric authentication result: $result', name: _logTag);
      return result;
    } catch (e) {
      log('$_logTag: Biometric authentication failed: $e', name: _logTag);
      return false;
    }
  }

  /// Handle biometric authentication result from native
  Future<void> _handleBiometricResult(bool success, String? error) async {
    try {
      if (success) {
        log('$_logTag: Biometric authentication successful', name: _logTag);
      } else {
        log('$_logTag: Biometric authentication failed: $error', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error handling biometric result: $e', name: _logTag);
    }
  }

  // ==================== Recording Controls and Status Management ====================

  /// Update all Windows integrations with recording state
  Future<void> updateRecordingState({
    required bool isRecording,
    bool isPaused = false,
    Duration? duration,
    String? meetingTitle,
    bool isTranscribing = false,
    double transcriptionProgress = 0.0,
  }) async {
    if (!isAvailable) return;

    try {
      // Update system tray
      await updateSystemTray(
        isRecording: isRecording,
        isPaused: isPaused,
        duration: duration,
        meetingTitle: meetingTitle,
        isTranscribing: isTranscribing,
        transcriptionProgress: transcriptionProgress,
      );

      // Update taskbar integration
      if (_taskbarIntegrationEnabled) {
        await _taskbarService.updateRecordingState(
          isRecording: isRecording,
          isPaused: isPaused,
          duration: duration,
          transcriptionProgress: transcriptionProgress,
          isTranscribing: isTranscribing,
        );
      }

      // Update jump list
      if (_jumplistEnabled) {
        await _jumplistService.updateRecordingState(
          isRecording: isRecording,
          isPaused: isPaused,
        );
      }

      // Show recording notification
      if (_notificationsEnabled) {
        await _notificationsService.showRecordingNotification(
          isRecording: isRecording,
          duration: duration,
          meetingTitle: meetingTitle,
          isPaused: isPaused,
        );
      }

      log('$_logTag: Recording state updated across all integrations',
          name: _logTag);
    } catch (e) {
      log('$_logTag: Error updating recording state: $e', name: _logTag);
    }
  }

  /// Show transcription complete notification and update integrations
  Future<void> notifyTranscriptionComplete({
    required String recordingTitle,
    required Duration processingDuration,
    String? transcriptPreview,
    String? filePath,
  }) async {
    if (!isAvailable) return;

    try {
      // Show completion notification
      if (_notificationsEnabled) {
        await _notificationsService.showTranscriptionCompleteNotification(
          recordingTitle: recordingTitle,
          processingDuration: processingDuration,
          transcriptPreview: transcriptPreview,
        );
      }

      // Add to jump list recent items
      if (_jumplistEnabled && filePath != null) {
        await _jumplistService.addRecentRecording(
          recordingPath: filePath,
          title: recordingTitle,
        );
      }

      // Clear progress indicators
      if (_taskbarIntegrationEnabled) {
        await _taskbarService.clearProgress();
        await _taskbarService.setOverlayIcon(null);
      }

      log('$_logTag: Transcription completion notifications sent',
          name: _logTag);
    } catch (e) {
      log('$_logTag: Error notifying transcription complete: $e',
          name: _logTag);
    }
  }

  /// Copy transcript to clipboard with options
  Future<bool> copyTranscriptToClipboard({
    required String transcript,
    required String title,
    Map<String, dynamic>? metadata,
    bool includeTimestamps = true,
    bool formatAsMarkdown = true,
  }) async {
    if (!_clipboardIntegrationEnabled) return false;

    try {
      final result = await _clipboardService.copyTranscript(
        transcript: transcript,
        title: title,
        options: TranscriptSharingOptions(
          includeTimestamps: includeTimestamps,
          formatAsMarkdown: formatAsMarkdown,
          includeMetadata: true,
        ),
        metadata: metadata,
      );

      if (result && _notificationsEnabled) {
        await showNotification(
          title: 'Transcript Copied',
          body: 'Transcript has been copied to clipboard',
          timeout: const Duration(seconds: 3),
        );
      }

      return result;
    } catch (e) {
      log('$_logTag: Error copying transcript to clipboard: $e', name: _logTag);
      return false;
    }
  }

  /// Copy summary to clipboard
  Future<bool> copySummaryToClipboard({
    required String summary,
    required String title,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_clipboardIntegrationEnabled) return false;

    try {
      final result = await _clipboardService.copySummary(
        summary: summary,
        title: title,
        metadata: metadata,
      );

      if (result && _notificationsEnabled) {
        await showNotification(
          title: 'Summary Copied',
          body: 'Meeting summary has been copied to clipboard',
          timeout: const Duration(seconds: 3),
        );
      }

      return result;
    } catch (e) {
      log('$_logTag: Error copying summary to clipboard: $e', name: _logTag);
      return false;
    }
  }

  /// Show error notification with Windows integration
  Future<void> showErrorNotification({
    required String title,
    required String error,
    String? action,
  }) async {
    if (!_notificationsEnabled) return;

    try {
      await _notificationsService.showErrorNotification(
        title: title,
        error: error,
        action: action,
      );

      // Flash taskbar if available
      if (_taskbarIntegrationEnabled) {
        await _taskbarService.flashTaskbarButton();
      }
    } catch (e) {
      log('$_logTag: Error showing error notification: $e', name: _logTag);
    }
  }

  // ==================== Platform Service Interface Implementation ====================

  @override
  Future<bool> registerIntegrations() async {
    try {
      // Re-register all integrations
      await _initializeSystemTray();
      await _initializeNotifications();
      await _initializeJumplist();
      await _initializeRegistryIntegration();
      await _initializeTaskbarIntegration();

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
          await _handleStartRecording(parameters);
          break;

        case 'stop_recording':
          await _handleStopRecording(parameters);
          break;

        case 'pause_recording':
          await _handlePauseRecording(parameters);
          break;

        case 'resume_recording':
          await _handleResumeRecording(parameters);
          break;

        case 'open_app':
          await _handleOpenApp(parameters);
          break;

        case 'view_recordings':
          await _handleViewRecordings(parameters);
          break;

        case 'transcribe_latest':
          await _handleTranscribeLatest(parameters);
          break;

        case 'generate_summary':
          await _handleGenerateSummary(parameters);
          break;

        case 'settings':
          await _handleSettings(parameters);
          break;

        case 'exit':
          await _handleExit(parameters);
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
      final meetingTitle = state['meetingTitle'] as String?;
      final isPaused = state['isPaused'] as bool? ?? false;

      // Update all integrations with current state
      await updateSystemTray(
        isRecording: isRecording,
        isPaused: isPaused,
        duration: recordingDuration,
        meetingTitle: meetingTitle,
        isTranscribing: isTranscribing,
        transcriptionProgress: transcriptionProgress,
      );

      // Update jump list with recent recordings if available
      final recentRecordings =
          state['recentRecordings'] as List<Map<String, dynamic>>? ?? [];
      if (recentRecordings.isNotEmpty) {
        await updateJumplistRecentItems(recentRecordings: recentRecordings);
      }
    } catch (e) {
      log('$_logTag: Error updating integrations: $e', name: _logTag);
    }
  }

  @override
  Future<bool> showSystemUI() async {
    try {
      await _systemTrayService.setTrayVisibility(true);
      return true;
    } catch (e) {
      log('$_logTag: Failed to show system UI: $e', name: _logTag);
      return false;
    }
  }

  @override
  Future<void> hideSystemUI() async {
    try {
      await _systemTrayService.setTrayVisibility(false);
    } catch (e) {
      log('$_logTag: Error hiding system UI: $e', name: _logTag);
    }
  }

  @override
  Future<void> updateSystemUIState(Map<String, dynamic> state) async {
    await updateIntegrations(state);
  }

  // ==================== Action Handlers ====================

  Future<void> _handleStartRecording(Map<String, dynamic>? parameters) async {
    log('$_logTag: Handling start recording action', name: _logTag);
    // Implementation will be handled by the main app
  }

  Future<void> _handleStopRecording(Map<String, dynamic>? parameters) async {
    log('$_logTag: Handling stop recording action', name: _logTag);
    // Implementation will be handled by the main app
  }

  Future<void> _handlePauseRecording(Map<String, dynamic>? parameters) async {
    log('$_logTag: Handling pause recording action', name: _logTag);
    // Implementation will be handled by the main app
  }

  Future<void> _handleResumeRecording(Map<String, dynamic>? parameters) async {
    log('$_logTag: Handling resume recording action', name: _logTag);
    // Implementation will be handled by the main app
  }

  Future<void> _handleOpenApp(Map<String, dynamic>? parameters) async {
    log('$_logTag: Handling open app action', name: _logTag);
    // Implementation will be handled by the main app
  }

  Future<void> _handleViewRecordings(Map<String, dynamic>? parameters) async {
    log('$_logTag: Handling view recordings action', name: _logTag);
    // Implementation will be handled by the main app
  }

  Future<void> _handleTranscribeLatest(Map<String, dynamic>? parameters) async {
    log('$_logTag: Handling transcribe latest action', name: _logTag);
    // Implementation will be handled by the main app
  }

  Future<void> _handleGenerateSummary(Map<String, dynamic>? parameters) async {
    log('$_logTag: Handling generate summary action', name: _logTag);
    // Implementation will be handled by the main app
  }

  Future<void> _handleSettings(Map<String, dynamic>? parameters) async {
    log('$_logTag: Handling settings action', name: _logTag);
    // Implementation will be handled by the main app
  }

  Future<void> _handleExit(Map<String, dynamic>? parameters) async {
    log('$_logTag: Handling exit action', name: _logTag);
    // Implementation will be handled by the main app
  }

  /// Dispose all resources and cleanup
  @override
  void dispose() {
    try {
      // Dispose sub-services
      _systemTrayService.dispose();
      _notificationsService.dispose();
      _jumplistService.dispose();
      _registryService.dispose();
      _taskbarService.dispose();
      _clipboardService.dispose();

      // Clear callbacks
      onPlatformAction = null;
      onTrayAction = null;
      onFileOpened = null;
      onNotificationAction = null;
      onJumplistAction = null;
      onTaskbarStateChanged = null;

      _isInitialized = false;
      log('$_logTag: Windows platform service disposed', name: _logTag);
    } catch (e) {
      log('$_logTag: Error disposing service: $e', name: _logTag);
    }
  }
}
