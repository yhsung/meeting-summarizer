/// Comprehensive iOS Platform Services Integration
///
/// This service provides complete iOS-specific functionality including:
/// - Siri Shortcuts integration for voice-activated recording
/// - Apple Watch companion app for remote control
/// - CallKit integration for automatic call recording
/// - iOS widgets for home screen controls
/// - Spotlight Search integration for quick access
/// - Files app integration for document management
/// - NSUserActivity Handoff support for continuity
library;

import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'platform_services/platform_service_interface.dart';
import 'platform_services/siri_shortcuts_service.dart';
import 'platform_services/apple_watch_service.dart';
import 'platform_services/callkit_service.dart';

/// iOS-specific platform service implementation
class IOSPlatformService
    implements PlatformIntegrationInterface, PlatformSystemInterface {
  static const String _logTag = 'IOSPlatformService';
  static const String _channelName =
      'com.yhsung.meeting_summarizer/ios_platform';

  // Platform channel for native iOS communication
  static const MethodChannel _platform = MethodChannel(_channelName);

  // Sub-services
  late final SiriShortcutsService _siriShortcutsService;
  late final AppleWatchService _appleWatchService;
  late final CallKitService _callKitService;
  // Notifications plugin for iOS integration
  // Note: Currently used by sub-services, may be used for direct notifications in future
  late final FlutterLocalNotificationsPlugin _notificationsPlugin;

  // Service state
  bool _isInitialized = false;
  bool _handoffEnabled = false;
  bool _spotlightEnabled = false;
  bool _filesAppEnabled = false;
  bool _widgetsEnabled = false;
  String? _currentUserActivity;

  // Callbacks
  void Function(String action, Map<String, dynamic>? parameters)?
      onPlatformAction;
  void Function(String shortcutId, Map<String, dynamic>? parameters)?
      onSiriShortcut;
  void Function(String callId, bool isRecording)? onCallRecordingChanged;
  void Function(String query)? onSpotlightSearch;
  void Function(String activityType, Map<String, dynamic>? userInfo)?
      onHandoffActivity;

  /// Initialize all iOS platform services
  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      if (!Platform.isIOS) {
        log('$_logTag: iOS platform services only available on iOS',
            name: _logTag);
        return false;
      }

      // Initialize notifications plugin for iOS integration
      _notificationsPlugin = FlutterLocalNotificationsPlugin();

      // Initialize notifications for iOS-specific features
      const initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        requestCriticalPermission: false,
      );

      const initializationSettings = InitializationSettings(
        iOS: initializationSettingsIOS,
      );

      await _notificationsPlugin.initialize(initializationSettings);

      // Initialize sub-services
      _siriShortcutsService = SiriShortcutsService();
      _appleWatchService = AppleWatchService();
      _callKitService = CallKitService();

      // Initialize platform channel communication
      await _initializePlatformChannel();

      // Initialize individual iOS services
      await _initializeSiriShortcuts();
      await _initializeAppleWatch();
      await _initializeCallKit();
      await _initializeHomeScreenWidgets();
      await _initializeSpotlightSearch();
      await _initializeFilesAppIntegration();
      await _initializeHandoffSupport();

      _isInitialized = true;
      log('$_logTag: iOS platform services initialized successfully',
          name: _logTag);
      return true;
    } catch (e) {
      log('$_logTag: Failed to initialize iOS platform services: $e',
          name: _logTag);
      return false;
    }
  }

  /// Check if iOS platform services are available
  @override
  bool get isAvailable => Platform.isIOS && _isInitialized;

  /// Initialize platform channel for native iOS communication
  Future<void> _initializePlatformChannel() async {
    try {
      // Set up method call handler for platform channel
      _platform.setMethodCallHandler(_handleNativeMethodCall);

      // Test platform channel connectivity
      final result = await _platform.invokeMethod<bool>('initialize') ?? false;
      if (!result) {
        log('$_logTag: Failed to initialize native iOS platform channel',
            name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Platform channel initialization error: $e', name: _logTag);
    }
  }

  /// Handle method calls from native iOS code
  Future<void> _handleNativeMethodCall(MethodCall call) async {
    try {
      log('$_logTag: Received native method call: ${call.method}',
          name: _logTag);

      switch (call.method) {
        case 'onSiriShortcut':
          final shortcutId = call.arguments['shortcutId'] as String?;
          final parameters =
              call.arguments['parameters'] as Map<String, dynamic>?;
          if (shortcutId != null) {
            await _handleSiriShortcut(shortcutId, parameters);
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

        case 'onSpotlightSearch':
          final query = call.arguments['query'] as String?;
          if (query != null) {
            await _handleSpotlightSearch(query);
          }
          break;

        case 'onHandoffActivity':
          final activityType = call.arguments['activityType'] as String?;
          final userInfo = call.arguments['userInfo'] as Map<String, dynamic>?;
          if (activityType != null) {
            await _handleHandoffActivity(activityType, userInfo);
          }
          break;

        case 'onCallStateChanged':
          final callId = call.arguments['callId'] as String?;
          final isRecording = call.arguments['isRecording'] as bool? ?? false;
          if (callId != null) {
            _handleCallStateChanged(callId, isRecording);
          }
          break;

        default:
          log('$_logTag: Unknown native method call: ${call.method}',
              name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error handling native method call: $e', name: _logTag);
    }
  }

  // ==================== SUBTASK 4.1: Siri Shortcuts Integration ====================

  /// Initialize Siri Shortcuts integration
  Future<void> _initializeSiriShortcuts() async {
    try {
      final initialized = await _siriShortcutsService.initialize();
      if (initialized) {
        await _siriShortcutsService.registerShortcuts();
        log('$_logTag: Siri Shortcuts enabled successfully', name: _logTag);
      } else {
        log('$_logTag: Failed to enable Siri Shortcuts', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing Siri Shortcuts: $e', name: _logTag);
    }
  }

  /// Handle Siri shortcut execution
  Future<void> _handleSiriShortcut(
      String shortcutId, Map<String, dynamic>? parameters) async {
    try {
      log('$_logTag: Handling Siri shortcut: $shortcutId', name: _logTag);

      // Execute shortcut through service
      await _siriShortcutsService.handleShortcutExecution(
          shortcutId, parameters);

      // Notify callback
      onSiriShortcut?.call(shortcutId, parameters);

      // Create NSUserActivity for this action
      await _createUserActivity(
        activityType: 'com.yhsung.meeting_summarizer.siri_shortcut',
        title: 'Siri Shortcut Executed',
        userInfo: {
          'shortcutId': shortcutId,
          'parameters': parameters ?? {},
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      log('$_logTag: Error handling Siri shortcut: $e', name: _logTag);
    }
  }

  /// Update Siri shortcuts based on app state
  Future<void> updateSiriShortcuts({
    required bool isRecording,
    bool hasRecordings = false,
    bool hasTranscriptions = false,
  }) async {
    if (!isAvailable) return;

    try {
      await _siriShortcutsService.updateShortcuts(
        isRecording: isRecording,
        hasRecordings: hasRecordings,
        hasTranscriptions: hasTranscriptions,
      );
    } catch (e) {
      log('$_logTag: Failed to update Siri shortcuts: $e', name: _logTag);
    }
  }

  // ==================== SUBTASK 4.2: Apple Watch Companion App ====================

  /// Initialize Apple Watch integration
  Future<void> _initializeAppleWatch() async {
    try {
      final initialized = await _appleWatchService.initialize();
      if (initialized) {
        // Set up watch action callback
        _appleWatchService.onWatchAction = (action, parameters) {
          _handleWatchAction(action, parameters);
        };
        log('$_logTag: Apple Watch integration enabled', name: _logTag);
      } else {
        log('$_logTag: Apple Watch integration not available', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing Apple Watch: $e', name: _logTag);
    }
  }

  /// Handle Apple Watch action
  Future<void> _handleWatchAction(
      WatchAction action, Map<String, dynamic>? parameters) async {
    try {
      log('$_logTag: Handling Apple Watch action: ${action.displayName}',
          name: _logTag);

      // Convert watch action to platform action
      String platformAction;
      switch (action) {
        case WatchAction.startRecording:
          platformAction = 'start_recording';
          break;
        case WatchAction.stopRecording:
          platformAction = 'stop_recording';
          break;
        case WatchAction.pauseRecording:
          platformAction = 'pause_recording';
          break;
        case WatchAction.resumeRecording:
          platformAction = 'resume_recording';
          break;
        case WatchAction.addBookmark:
          platformAction = 'add_bookmark';
          break;
        case WatchAction.viewStatus:
          platformAction = 'view_status';
          break;
      }

      // Execute platform action
      await handleAction(platformAction, {
        ...?parameters,
        'source': 'apple_watch',
        'watchAction': action.identifier,
      });
    } catch (e) {
      log('$_logTag: Error handling watch action: $e', name: _logTag);
    }
  }

  /// Update Apple Watch with recording status
  Future<void> updateAppleWatch({
    required bool isRecording,
    bool isPaused = false,
    Duration? duration,
    String? meetingTitle,
    double transcriptionProgress = 0.0,
    bool isTranscribing = false,
  }) async {
    if (!isAvailable) return;

    try {
      await _appleWatchService.updateRecordingStatus(
        isRecording: isRecording,
        isPaused: isPaused,
        duration: duration,
        meetingTitle: meetingTitle,
      );

      await _appleWatchService.updateTranscriptionProgress(
        isTranscribing: isTranscribing,
        progress: transcriptionProgress,
      );

      await _appleWatchService.updateActionAvailability(
        isRecording: isRecording,
        isPaused: isPaused,
      );
    } catch (e) {
      log('$_logTag: Failed to update Apple Watch: $e', name: _logTag);
    }
  }

  // ==================== SUBTASK 4.3: CallKit Integration ====================

  /// Initialize CallKit integration
  Future<void> _initializeCallKit() async {
    try {
      final initialized = await _callKitService.initialize();
      if (initialized) {
        // Configure CallKit provider
        await _callKitService.configureProvider(
          providerName: 'Meeting Summarizer',
          supportsVideo: false,
          maximumCallGroups: 1,
          maximumCallsPerCallGroup: 1,
        );

        // Set up callbacks
        _callKitService.onCallStarted = (call) {
          _handleCallStarted(call);
        };

        _callKitService.onCallEnded = (call) {
          _handleCallEnded(call);
        };

        _callKitService.onRecordingStateChanged = (call, state) {
          _handleCallRecordingStateChanged(call, state);
        };

        log('$_logTag: CallKit integration enabled', name: _logTag);
      } else {
        log('$_logTag: CallKit integration not available', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing CallKit: $e', name: _logTag);
    }
  }

  /// Handle call started event
  void _handleCallStarted(CallInfo call) {
    log('$_logTag: Call started: ${call.contactName}', name: _logTag);

    // Create NSUserActivity for call
    _createUserActivity(
      activityType: 'com.yhsung.meeting_summarizer.call',
      title: 'Call: ${call.contactName ?? 'Unknown'}',
      userInfo: call.toJson(),
    );

    // Auto-start recording if enabled
    // TODO: Check user preferences for auto-recording
  }

  /// Handle call ended event
  void _handleCallEnded(CallInfo call) {
    log('$_logTag: Call ended: ${call.contactName}', name: _logTag);

    // Clear current user activity
    _invalidateCurrentUserActivity();
  }

  /// Handle call recording state changes
  void _handleCallRecordingStateChanged(
      CallInfo call, CallRecordingState state) {
    log('$_logTag: Call recording state changed: ${state.value}',
        name: _logTag);
    onCallRecordingChanged?.call(call.callId, call.isRecording);
  }

  /// Handle call state change from native
  void _handleCallStateChanged(String callId, bool isRecording) {
    log('$_logTag: Call state changed: $callId, recording: $isRecording',
        name: _logTag);
    onCallRecordingChanged?.call(callId, isRecording);
  }

  // ==================== SUBTASK 4.4: iOS Home Screen Widgets ====================

  /// Initialize home screen widgets
  Future<void> _initializeHomeScreenWidgets() async {
    try {
      final result =
          await _platform.invokeMethod<bool>('setupHomeScreenWidgets') ?? false;
      _widgetsEnabled = result;

      if (result) {
        await _setupWidgetConfiguration();
        log('$_logTag: Home screen widgets enabled', name: _logTag);
      } else {
        log('$_logTag: Failed to enable home screen widgets', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing home screen widgets: $e',
          name: _logTag);
    }
  }

  /// Set up widget configuration and layouts
  Future<void> _setupWidgetConfiguration() async {
    try {
      await _platform.invokeMethod('configureWidgets', {
        'supportedSizes': ['small', 'medium', 'large'],
        'refreshInterval': 300, // 5 minutes
        'showRecordingButton': true,
        'showRecentRecordings': true,
        'showTranscriptionStatus': true,
      });
    } catch (e) {
      log('$_logTag: Failed to setup widget configuration: $e', name: _logTag);
    }
  }

  /// Handle widget action
  void _handleWidgetAction(String action, Map<String, dynamic>? parameters) {
    try {
      log('$_logTag: Handling widget action: $action', name: _logTag);
      onPlatformAction?.call(action, {
        ...?parameters,
        'source': 'ios_widget',
      });
    } catch (e) {
      log('$_logTag: Error handling widget action: $e', name: _logTag);
    }
  }

  /// Update home screen widgets with current state
  Future<void> updateHomeScreenWidgets({
    required bool isRecording,
    Duration? recordingDuration,
    bool isTranscribing = false,
    double transcriptionProgress = 0.0,
    int recentRecordingsCount = 0,
    String? status,
  }) async {
    if (!_widgetsEnabled) return;

    try {
      await _platform.invokeMethod('updateWidgets', {
        'isRecording': isRecording,
        'recordingDuration': recordingDuration?.inSeconds ?? 0,
        'isTranscribing': isTranscribing,
        'transcriptionProgress': transcriptionProgress,
        'recentRecordingsCount': recentRecordingsCount,
        'status': status ?? (isRecording ? 'Recording' : 'Ready'),
        'lastUpdate': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      log('$_logTag: Failed to update home screen widgets: $e', name: _logTag);
    }
  }

  // ==================== SUBTASK 4.5: Spotlight Search Integration ====================

  /// Initialize Spotlight Search integration
  Future<void> _initializeSpotlightSearch() async {
    try {
      final result =
          await _platform.invokeMethod<bool>('setupSpotlightSearch') ?? false;
      _spotlightEnabled = result;

      if (result) {
        log('$_logTag: Spotlight Search integration enabled', name: _logTag);
      } else {
        log('$_logTag: Failed to enable Spotlight Search', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing Spotlight Search: $e', name: _logTag);
    }
  }

  /// Index recording for Spotlight Search
  Future<void> indexRecordingForSpotlight({
    required String recordingId,
    required String title,
    required String transcript,
    required DateTime createdAt,
    Duration? duration,
    List<String>? keywords,
  }) async {
    if (!_spotlightEnabled) return;

    try {
      await _platform.invokeMethod('indexRecording', {
        'recordingId': recordingId,
        'title': title,
        'transcript': transcript,
        'createdAt': createdAt.toIso8601String(),
        'duration': duration?.inSeconds,
        'keywords': keywords ?? [],
        'contentType': 'com.yhsung.meeting_summarizer.recording',
      });
    } catch (e) {
      log('$_logTag: Failed to index recording for Spotlight: $e',
          name: _logTag);
    }
  }

  /// Handle Spotlight search query
  Future<void> _handleSpotlightSearch(String query) async {
    try {
      log('$_logTag: Handling Spotlight search: $query', name: _logTag);
      onSpotlightSearch?.call(query);

      // Create NSUserActivity for search
      await _createUserActivity(
        activityType: 'com.yhsung.meeting_summarizer.search',
        title: 'Search: $query',
        userInfo: {
          'query': query,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      log('$_logTag: Error handling Spotlight search: $e', name: _logTag);
    }
  }

  /// Remove recording from Spotlight index
  Future<void> removeRecordingFromSpotlight(String recordingId) async {
    if (!_spotlightEnabled) return;

    try {
      await _platform.invokeMethod('removeFromIndex', {
        'recordingId': recordingId,
      });
    } catch (e) {
      log('$_logTag: Failed to remove recording from Spotlight: $e',
          name: _logTag);
    }
  }

  // ==================== SUBTASK 4.6: Files App Integration ====================

  /// Initialize Files app integration
  Future<void> _initializeFilesAppIntegration() async {
    try {
      final result =
          await _platform.invokeMethod<bool>('setupFilesAppIntegration') ??
              false;
      _filesAppEnabled = result;

      if (result) {
        log('$_logTag: Files app integration enabled', name: _logTag);
      } else {
        log('$_logTag: Failed to enable Files app integration', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing Files app integration: $e',
          name: _logTag);
    }
  }

  /// Export recording to Files app
  Future<bool> exportRecordingToFilesApp({
    required String recordingPath,
    required String fileName,
    String? folderName,
  }) async {
    if (!_filesAppEnabled) return false;

    try {
      final result = await _platform.invokeMethod<bool>('exportToFiles', {
        'recordingPath': recordingPath,
        'fileName': fileName,
        'folderName': folderName ?? 'Meeting Recordings',
      });

      return result ?? false;
    } catch (e) {
      log('$_logTag: Failed to export recording to Files app: $e',
          name: _logTag);
      return false;
    }
  }

  /// Import file from Files app
  Future<String?> importFileFromFilesApp({
    List<String>? allowedTypes,
  }) async {
    if (!_filesAppEnabled) return null;

    try {
      final result = await _platform.invokeMethod<String>('importFromFiles', {
        'allowedTypes': allowedTypes ?? ['public.audio'],
      });

      return result;
    } catch (e) {
      log('$_logTag: Failed to import file from Files app: $e', name: _logTag);
      return null;
    }
  }

  // ==================== SUBTASK 4.7: NSUserActivity Handoff Support ====================

  /// Initialize Handoff support
  Future<void> _initializeHandoffSupport() async {
    try {
      final result =
          await _platform.invokeMethod<bool>('setupHandoffSupport') ?? false;
      _handoffEnabled = result;

      if (result) {
        log('$_logTag: Handoff support enabled', name: _logTag);
      } else {
        log('$_logTag: Failed to enable Handoff support', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing Handoff support: $e', name: _logTag);
    }
  }

  /// Create NSUserActivity for Handoff
  Future<void> _createUserActivity({
    required String activityType,
    required String title,
    Map<String, dynamic>? userInfo,
    String? webpageURL,
  }) async {
    if (!_handoffEnabled) return;

    try {
      await _platform.invokeMethod('createUserActivity', {
        'activityType': activityType,
        'title': title,
        'userInfo': userInfo ?? {},
        'webpageURL': webpageURL,
        'eligibleForHandoff': true,
        'eligibleForSearch': true,
        'eligibleForPrediction': true,
      });

      _currentUserActivity = activityType;
    } catch (e) {
      log('$_logTag: Failed to create user activity: $e', name: _logTag);
    }
  }

  /// Handle Handoff activity continuation
  Future<void> _handleHandoffActivity(
      String activityType, Map<String, dynamic>? userInfo) async {
    try {
      log('$_logTag: Handling Handoff activity: $activityType', name: _logTag);
      onHandoffActivity?.call(activityType, userInfo);
    } catch (e) {
      log('$_logTag: Error handling Handoff activity: $e', name: _logTag);
    }
  }

  /// Invalidate current user activity
  Future<void> _invalidateCurrentUserActivity() async {
    if (!_handoffEnabled || _currentUserActivity == null) return;

    try {
      await _platform.invokeMethod('invalidateUserActivity');
      _currentUserActivity = null;
    } catch (e) {
      log('$_logTag: Failed to invalidate user activity: $e', name: _logTag);
    }
  }

  // ==================== Platform Service Interface Implementation ====================

  @override
  Future<bool> registerIntegrations() async {
    try {
      // Re-register all integrations
      await _initializeSiriShortcuts();
      await _initializeHomeScreenWidgets();
      await _initializeSpotlightSearch();
      await _initializeFilesAppIntegration();
      await _initializeHandoffSupport();

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

        case 'add_bookmark':
          await _handleAddBookmark(parameters);
          break;

        case 'view_status':
          await _handleViewStatus(parameters);
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
      final meetingTitle = state['meetingTitle'] as String?;
      final isPaused = state['isPaused'] as bool? ?? false;

      // Update all integrations with current state
      await updateSiriShortcuts(
        isRecording: isRecording,
        hasRecordings: recentCount > 0,
        hasTranscriptions: transcriptionProgress > 0,
      );

      await updateAppleWatch(
        isRecording: isRecording,
        isPaused: isPaused,
        duration: recordingDuration,
        meetingTitle: meetingTitle,
        transcriptionProgress: transcriptionProgress,
        isTranscribing: isTranscribing,
      );

      await updateHomeScreenWidgets(
        isRecording: isRecording,
        recordingDuration: recordingDuration,
        isTranscribing: isTranscribing,
        transcriptionProgress: transcriptionProgress,
        recentRecordingsCount: recentCount,
        status: state['status'] as String?,
      );

      // Create user activity for current state
      if (isRecording) {
        await _createUserActivity(
          activityType: 'com.yhsung.meeting_summarizer.recording',
          title: 'Recording: ${meetingTitle ?? 'Meeting'}',
          userInfo: {
            'isRecording': isRecording,
            'duration': recordingDuration?.inSeconds ?? 0,
            'meetingTitle': meetingTitle ?? 'Meeting',
          },
        );
      }
    } catch (e) {
      log('$_logTag: Error updating integrations: $e', name: _logTag);
    }
  }

  @override
  Future<bool> showSystemUI() async {
    // Enable all iOS UI elements
    try {
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
      await _invalidateCurrentUserActivity();
    } catch (e) {
      log('$_logTag: Error hiding system UI: $e', name: _logTag);
    }
  }

  @override
  Future<void> updateSystemUIState(Map<String, dynamic> state) async {
    await updateIntegrations(state);
  }

  // ==================== Action Handlers ====================

  /// Handle start recording action
  Future<void> _handleStartRecording(Map<String, dynamic>? parameters) async {
    try {
      log('$_logTag: Handling start recording action', name: _logTag);

      // Create user activity for recording
      await _createUserActivity(
        activityType: 'com.yhsung.meeting_summarizer.recording',
        title: 'Starting Recording',
        userInfo: {
          'action': 'start_recording',
          'timestamp': DateTime.now().toIso8601String(),
          'source': parameters?['source'] ?? 'unknown',
        },
      );
    } catch (e) {
      log('$_logTag: Error handling start recording: $e', name: _logTag);
    }
  }

  /// Handle stop recording action
  Future<void> _handleStopRecording(Map<String, dynamic>? parameters) async {
    try {
      log('$_logTag: Handling stop recording action', name: _logTag);

      // Invalidate recording user activity
      await _invalidateCurrentUserActivity();
    } catch (e) {
      log('$_logTag: Error handling stop recording: $e', name: _logTag);
    }
  }

  /// Handle pause recording action
  Future<void> _handlePauseRecording(Map<String, dynamic>? parameters) async {
    try {
      log('$_logTag: Handling pause recording action', name: _logTag);
    } catch (e) {
      log('$_logTag: Error handling pause recording: $e', name: _logTag);
    }
  }

  /// Handle resume recording action
  Future<void> _handleResumeRecording(Map<String, dynamic>? parameters) async {
    try {
      log('$_logTag: Handling resume recording action', name: _logTag);
    } catch (e) {
      log('$_logTag: Error handling resume recording: $e', name: _logTag);
    }
  }

  /// Handle add bookmark action
  Future<void> _handleAddBookmark(Map<String, dynamic>? parameters) async {
    try {
      log('$_logTag: Handling add bookmark action', name: _logTag);
    } catch (e) {
      log('$_logTag: Error handling add bookmark: $e', name: _logTag);
    }
  }

  /// Handle view status action
  Future<void> _handleViewStatus(Map<String, dynamic>? parameters) async {
    try {
      log('$_logTag: Handling view status action', name: _logTag);
    } catch (e) {
      log('$_logTag: Error handling view status: $e', name: _logTag);
    }
  }

  // ==================== Helper Methods ====================

  /// Get comprehensive service status
  Map<String, dynamic> getServiceStatus() {
    return {
      'isInitialized': _isInitialized,
      'isAvailable': isAvailable,
      'siriShortcutsAvailable': _siriShortcutsService.isAvailable,
      'appleWatchConnected': _appleWatchService.isWatchConnected,
      'callKitAvailable': _callKitService.isAvailable,
      'widgetsEnabled': _widgetsEnabled,
      'spotlightEnabled': _spotlightEnabled,
      'filesAppEnabled': _filesAppEnabled,
      'handoffEnabled': _handoffEnabled,
      'currentUserActivity': _currentUserActivity,
      'platform': 'ios',
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// Get sub-services for direct access
  SiriShortcutsService get siriShortcutsService => _siriShortcutsService;
  AppleWatchService get appleWatchService => _appleWatchService;
  CallKitService get callKitService => _callKitService;

  /// Dispose all resources and cleanup
  @override
  void dispose() {
    try {
      // Invalidate current user activity
      if (_currentUserActivity != null) {
        _invalidateCurrentUserActivity();
      }

      // Dispose sub-services
      _siriShortcutsService.dispose();
      _appleWatchService.dispose();
      _callKitService.dispose();

      // Clear callbacks - ensure they're properly nullified
      onPlatformAction = null;
      onSiriShortcut = null;
      onCallRecordingChanged = null;
      onSpotlightSearch = null;
      onHandoffActivity = null;

      _isInitialized = false;
      log('$_logTag: iOS platform service disposed', name: _logTag);
    } catch (e) {
      log('$_logTag: Error disposing service: $e', name: _logTag);
    }
  }
}
