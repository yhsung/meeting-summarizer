/// Comprehensive macOS Platform Services Integration
///
/// This service provides complete macOS-specific functionality including:
/// - Menu bar integration with system-wide controls
/// - Spotlight Search integration for content indexing
/// - Dock integration with badges and context menus
/// - Touch Bar support for MacBook Pro devices
/// - Notification Center integration for rich notifications
/// - Services menu integration for system-wide access
/// - Native keyboard shortcuts and global hotkeys
/// - File associations and drag-drop support
library;

import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'platform_services/platform_service_interface.dart';
import 'platform_services/macos_menubar_service.dart';

/// macOS-specific platform service implementation
class MacOSPlatformService
    implements PlatformIntegrationInterface, PlatformSystemInterface {
  static const String _logTag = 'MacOSPlatformService';
  static const String _channelName =
      'com.yhsung.meeting_summarizer/macos_platform';

  // Platform channel for native macOS communication
  static const MethodChannel _platform = MethodChannel(_channelName);

  // Sub-services
  late final MacOSMenuBarService _menuBarService;
  late final FlutterLocalNotificationsPlugin _notificationsPlugin;

  // Service state
  bool _isInitialized = false;
  bool _spotlightEnabled = false;
  bool _dockIntegrationEnabled = false;
  bool _touchBarEnabled = false;
  bool _notificationCenterEnabled = false;
  bool _servicesMenuEnabled = false;
  bool _globalHotkeysEnabled = false;
  bool _fileAssociationsEnabled = false;

  // Current state tracking
  bool _isRecording = false;
  bool _isPaused = false;
  Duration? _recordingDuration;
  String? _currentMeetingTitle;
  double _transcriptionProgress = 0.0;
  bool _isTranscribing = false;
  int _recentRecordingsCount = 0;

  // Callbacks
  void Function(String action, Map<String, dynamic>? parameters)?
      onPlatformAction;
  void Function(String query, Map<String, dynamic>? userInfo)?
      onSpotlightSearch;
  void Function(String action, Map<String, dynamic>? parameters)? onDockAction;
  void Function(String action, Map<String, dynamic>? parameters)?
      onTouchBarAction;
  void Function(String notificationId, String? actionId)? onNotificationAction;
  void Function(String serviceName, String? text, String? filePath)?
      onServicesMenuAction;
  void Function(String hotkeyId, Map<String, dynamic>? parameters)?
      onGlobalHotkey;
  void Function(List<String> filePaths, String dropTarget)? onFilesDropped;

  /// Initialize all macOS platform services
  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      if (!Platform.isMacOS) {
        log('$_logTag: macOS platform services only available on macOS',
            name: _logTag);
        return false;
      }

      // Initialize notifications plugin for macOS integration
      _notificationsPlugin = FlutterLocalNotificationsPlugin();

      // Initialize notifications for macOS-specific features
      const initializationSettingsMacOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        requestCriticalPermission: false,
      );

      const initializationSettings = InitializationSettings(
        macOS: initializationSettingsMacOS,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      // Initialize menu bar service (existing)
      _menuBarService = MacOSMenuBarService();

      // Initialize platform channel communication
      await _initializePlatformChannel();

      // Initialize individual macOS services
      await _initializeMenuBarIntegration();
      await _initializeSpotlightSearch();
      await _initializeDockIntegration();
      await _initializeTouchBarSupport();
      await _initializeNotificationCenter();
      await _initializeServicesMenu();
      await _initializeGlobalHotkeys();
      await _initializeFileAssociations();

      _isInitialized = true;
      log('$_logTag: macOS platform services initialized successfully',
          name: _logTag);
      return true;
    } catch (e) {
      log('$_logTag: Failed to initialize macOS platform services: $e',
          name: _logTag);
      return false;
    }
  }

  /// Check if macOS platform services are available
  @override
  bool get isAvailable => Platform.isMacOS && _isInitialized;

  /// Initialize platform channel for native macOS communication
  Future<void> _initializePlatformChannel() async {
    try {
      // Set up method call handler for platform channel
      _platform.setMethodCallHandler(_handleNativeMethodCall);

      // Test platform channel connectivity
      final result = await _platform.invokeMethod<bool>('initialize') ?? false;
      if (!result) {
        log('$_logTag: Failed to initialize native macOS platform channel',
            name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Platform channel initialization error: $e', name: _logTag);
    }
  }

  /// Handle method calls from native macOS code
  Future<void> _handleNativeMethodCall(MethodCall call) async {
    try {
      log('$_logTag: Received native method call: ${call.method}',
          name: _logTag);

      switch (call.method) {
        case 'onMenuBarAction':
          final action = call.arguments['action'] as String?;
          final parameters =
              call.arguments['parameters'] as Map<String, dynamic>?;
          if (action != null) {
            await _handleMenuBarAction(action, parameters);
          }
          break;

        case 'onSpotlightSearch':
          final query = call.arguments['query'] as String?;
          final userInfo = call.arguments['userInfo'] as Map<String, dynamic>?;
          if (query != null) {
            await _handleSpotlightSearch(query, userInfo);
          }
          break;

        case 'onDockAction':
          final action = call.arguments['action'] as String?;
          final parameters =
              call.arguments['parameters'] as Map<String, dynamic>?;
          if (action != null) {
            _handleDockAction(action, parameters);
          }
          break;

        case 'onTouchBarAction':
          final action = call.arguments['action'] as String?;
          final parameters =
              call.arguments['parameters'] as Map<String, dynamic>?;
          if (action != null) {
            _handleTouchBarAction(action, parameters);
          }
          break;

        case 'onServicesMenuAction':
          final serviceName = call.arguments['serviceName'] as String?;
          final text = call.arguments['text'] as String?;
          final filePath = call.arguments['filePath'] as String?;
          if (serviceName != null) {
            _handleServicesMenuAction(serviceName, text, filePath);
          }
          break;

        case 'onGlobalHotkey':
          final hotkeyId = call.arguments['hotkeyId'] as String?;
          final parameters =
              call.arguments['parameters'] as Map<String, dynamic>?;
          if (hotkeyId != null) {
            _handleGlobalHotkey(hotkeyId, parameters);
          }
          break;

        case 'onFilesDropped':
          final filePaths = (call.arguments['filePaths'] as List?)
              ?.map((e) => e.toString())
              .toList();
          final dropTarget = call.arguments['dropTarget'] as String? ?? 'app';
          if (filePaths != null && filePaths.isNotEmpty) {
            _handleFilesDropped(filePaths, dropTarget);
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

  // ==================== MENU BAR INTEGRATION ====================

  /// Initialize menu bar integration
  Future<void> _initializeMenuBarIntegration() async {
    try {
      final initialized = await _menuBarService.initialize();
      if (initialized) {
        // Set up menu bar action callback
        _menuBarService.onMenuBarAction = (action, parameters) {
          _handleMenuBarAction(action.identifier, parameters);
        };

        // Set up Spotlight search callback
        _menuBarService.onSpotlightSearch = (query, type) {
          _handleSpotlightSearch(query, {'result_type': type.identifier});
        };

        log('$_logTag: Menu bar integration enabled successfully',
            name: _logTag);
      } else {
        log('$_logTag: Failed to enable menu bar integration', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing menu bar integration: $e',
          name: _logTag);
    }
  }

  /// Handle menu bar action
  Future<void> _handleMenuBarAction(
      String action, Map<String, dynamic>? parameters) async {
    try {
      log('$_logTag: Handling menu bar action: $action', name: _logTag);

      // Execute platform action
      await handleAction(action, {
        ...?parameters,
        'source': 'macos_menu_bar',
      });
    } catch (e) {
      log('$_logTag: Error handling menu bar action: $e', name: _logTag);
    }
  }

  // ==================== SPOTLIGHT SEARCH INTEGRATION ====================

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
  Future<void> _handleSpotlightSearch(
      String query, Map<String, dynamic>? userInfo) async {
    try {
      log('$_logTag: Handling Spotlight search: $query', name: _logTag);
      onSpotlightSearch?.call(query, userInfo);
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

  // ==================== DOCK INTEGRATION ====================

  /// Initialize Dock integration
  Future<void> _initializeDockIntegration() async {
    try {
      final result =
          await _platform.invokeMethod<bool>('setupDockIntegration') ?? false;
      _dockIntegrationEnabled = result;

      if (result) {
        await _setupDockMenu();
        log('$_logTag: Dock integration enabled', name: _logTag);
      } else {
        log('$_logTag: Failed to enable Dock integration', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing Dock integration: $e', name: _logTag);
    }
  }

  /// Set up dock menu with quick actions
  Future<void> _setupDockMenu() async {
    try {
      await _platform.invokeMethod('setupDockMenu', {
        'menuItems': [
          {
            'title': 'Start Recording',
            'action': 'start_recording',
            'enabled': true,
          },
          {
            'title': 'View Recent Recordings',
            'action': 'view_recordings',
            'enabled': true,
          },
          {
            'title': 'Open Transcription',
            'action': 'open_transcription',
            'enabled': true,
          },
          {
            'title': 'Settings',
            'action': 'open_settings',
            'enabled': true,
          },
        ],
      });
    } catch (e) {
      log('$_logTag: Failed to setup dock menu: $e', name: _logTag);
    }
  }

  /// Handle dock action
  void _handleDockAction(String action, Map<String, dynamic>? parameters) {
    try {
      log('$_logTag: Handling dock action: $action', name: _logTag);
      onDockAction?.call(action, parameters);

      // Execute platform action
      handleAction(action, {
        ...?parameters,
        'source': 'macos_dock',
      });
    } catch (e) {
      log('$_logTag: Error handling dock action: $e', name: _logTag);
    }
  }

  /// Update dock badge with recording count
  Future<void> updateDockBadge({
    int? recordingCount,
    bool? isRecording,
    bool clearBadge = false,
  }) async {
    if (!_dockIntegrationEnabled) return;

    try {
      if (clearBadge) {
        await _platform.invokeMethod('clearDockBadge');
      } else {
        await _platform.invokeMethod('updateDockBadge', {
          'recordingCount': recordingCount,
          'isRecording': isRecording ?? false,
          'showProgress': isRecording ?? false,
        });
      }
    } catch (e) {
      log('$_logTag: Failed to update dock badge: $e', name: _logTag);
    }
  }

  // ==================== TOUCH BAR SUPPORT ====================

  /// Initialize Touch Bar support for MacBook Pro
  Future<void> _initializeTouchBarSupport() async {
    try {
      final result =
          await _platform.invokeMethod<bool>('setupTouchBar') ?? false;
      _touchBarEnabled = result;

      if (result) {
        await _setupTouchBarControls();
        log('$_logTag: Touch Bar support enabled', name: _logTag);
      } else {
        log('$_logTag: Touch Bar not available or failed to enable',
            name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing Touch Bar: $e', name: _logTag);
    }
  }

  /// Set up Touch Bar controls
  Future<void> _setupTouchBarControls() async {
    try {
      await _platform.invokeMethod('setupTouchBarControls', {
        'controls': [
          {
            'identifier': 'record_button',
            'type': 'button',
            'title': 'Record',
            'action': 'start_recording',
            'color': 'red',
          },
          {
            'identifier': 'pause_button',
            'type': 'button',
            'title': 'Pause',
            'action': 'pause_recording',
            'enabled': false,
          },
          {
            'identifier': 'stop_button',
            'type': 'button',
            'title': 'Stop',
            'action': 'stop_recording',
            'enabled': false,
          },
          {
            'identifier': 'scrubber',
            'type': 'scrubber',
            'action': 'scrub_recording',
            'enabled': false,
          },
        ],
      });
    } catch (e) {
      log('$_logTag: Failed to setup Touch Bar controls: $e', name: _logTag);
    }
  }

  /// Handle Touch Bar action
  void _handleTouchBarAction(String action, Map<String, dynamic>? parameters) {
    try {
      log('$_logTag: Handling Touch Bar action: $action', name: _logTag);
      onTouchBarAction?.call(action, parameters);

      // Execute platform action
      handleAction(action, {
        ...?parameters,
        'source': 'macos_touch_bar',
      });
    } catch (e) {
      log('$_logTag: Error handling Touch Bar action: $e', name: _logTag);
    }
  }

  /// Update Touch Bar for recording state
  Future<void> updateTouchBar({
    required bool isRecording,
    bool isPaused = false,
    Duration? duration,
    double? progress,
  }) async {
    if (!_touchBarEnabled) return;

    try {
      await _platform.invokeMethod('updateTouchBar', {
        'isRecording': isRecording,
        'isPaused': isPaused,
        'duration': duration?.inSeconds ?? 0,
        'progress': progress ?? 0.0,
        'recordButtonEnabled': !isRecording,
        'pauseButtonEnabled': isRecording && !isPaused,
        'stopButtonEnabled': isRecording,
        'scrubberEnabled': isRecording,
      });
    } catch (e) {
      log('$_logTag: Failed to update Touch Bar: $e', name: _logTag);
    }
  }

  // ==================== NOTIFICATION CENTER INTEGRATION ====================

  /// Initialize Notification Center integration
  Future<void> _initializeNotificationCenter() async {
    try {
      final result =
          await _platform.invokeMethod<bool>('setupNotificationCenter') ??
              false;
      _notificationCenterEnabled = result;

      if (result) {
        await _setupNotificationCategories();
        log('$_logTag: Notification Center integration enabled', name: _logTag);
      } else {
        log('$_logTag: Failed to enable Notification Center', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing Notification Center: $e',
          name: _logTag);
    }
  }

  /// Set up notification categories with actions
  Future<void> _setupNotificationCategories() async {
    try {
      await _platform.invokeMethod('setupNotificationCategories', {
        'categories': [
          {
            'identifier': 'recording_complete',
            'actions': [
              {
                'identifier': 'view_recording',
                'title': 'View Recording',
                'foreground': true,
              },
              {
                'identifier': 'transcribe_now',
                'title': 'Transcribe Now',
                'foreground': false,
              },
            ],
          },
          {
            'identifier': 'transcription_complete',
            'actions': [
              {
                'identifier': 'view_transcription',
                'title': 'View Transcription',
                'foreground': true,
              },
              {
                'identifier': 'generate_summary',
                'title': 'Generate Summary',
                'foreground': false,
              },
            ],
          },
        ],
      });
    } catch (e) {
      log('$_logTag: Failed to setup notification categories: $e',
          name: _logTag);
    }
  }

  /// Handle notification response
  void _onNotificationResponse(NotificationResponse response) {
    try {
      final notificationId = response.id?.toString() ?? '';
      final actionId = response.actionId;

      log('$_logTag: Notification response: $notificationId, action: $actionId',
          name: _logTag);

      onNotificationAction?.call(notificationId, actionId);

      // Handle specific notification actions
      if (actionId != null) {
        _handleNotificationAction(actionId, response.payload);
      }
    } catch (e) {
      log('$_logTag: Error handling notification response: $e', name: _logTag);
    }
  }

  /// Handle notification action
  void _handleNotificationAction(String actionId, String? payload) {
    try {
      final parameters = <String, dynamic>{
        'source': 'macos_notification',
        'payload': payload,
      };

      switch (actionId) {
        case 'view_recording':
          handleAction('view_recording', parameters);
          break;
        case 'transcribe_now':
          handleAction('start_transcription', parameters);
          break;
        case 'view_transcription':
          handleAction('view_transcription', parameters);
          break;
        case 'generate_summary':
          handleAction('generate_summary', parameters);
          break;
        default:
          log('$_logTag: Unknown notification action: $actionId',
              name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error handling notification action: $e', name: _logTag);
    }
  }

  /// Show recording complete notification
  Future<void> showRecordingCompleteNotification({
    required String recordingId,
    required String title,
    Duration? duration,
  }) async {
    if (!_notificationCenterEnabled) return;

    try {
      const darwinNotificationDetails = DarwinNotificationDetails(
        categoryIdentifier: 'recording_complete',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        macOS: darwinNotificationDetails,
      );

      final body = duration != null
          ? 'Recording completed (${_formatDuration(duration)})'
          : 'Recording completed';

      await _notificationsPlugin.show(
        recordingId.hashCode,
        'Recording Complete: $title',
        body,
        notificationDetails,
        payload: recordingId,
      );
    } catch (e) {
      log('$_logTag: Failed to show recording complete notification: $e',
          name: _logTag);
    }
  }

  /// Show transcription complete notification
  Future<void> showTranscriptionCompleteNotification({
    required String transcriptionId,
    required String recordingTitle,
    int? wordCount,
  }) async {
    if (!_notificationCenterEnabled) return;

    try {
      const darwinNotificationDetails = DarwinNotificationDetails(
        categoryIdentifier: 'transcription_complete',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        macOS: darwinNotificationDetails,
      );

      final body = wordCount != null
          ? 'Transcription completed ($wordCount words)'
          : 'Transcription completed';

      await _notificationsPlugin.show(
        transcriptionId.hashCode,
        'Transcription Complete: $recordingTitle',
        body,
        notificationDetails,
        payload: transcriptionId,
      );
    } catch (e) {
      log('$_logTag: Failed to show transcription complete notification: $e',
          name: _logTag);
    }
  }

  // ==================== SERVICES MENU INTEGRATION ====================

  /// Initialize Services menu integration
  Future<void> _initializeServicesMenu() async {
    try {
      final result =
          await _platform.invokeMethod<bool>('setupServicesMenu') ?? false;
      _servicesMenuEnabled = result;

      if (result) {
        log('$_logTag: Services menu integration enabled', name: _logTag);
      } else {
        log('$_logTag: Failed to enable Services menu', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing Services menu: $e', name: _logTag);
    }
  }

  /// Handle Services menu action
  void _handleServicesMenuAction(
      String serviceName, String? text, String? filePath) {
    try {
      log('$_logTag: Handling Services menu action: $serviceName',
          name: _logTag);
      onServicesMenuAction?.call(serviceName, text, filePath);

      // Execute appropriate action based on service
      final parameters = <String, dynamic>{
        'source': 'macos_services_menu',
        'serviceName': serviceName,
        'text': text,
        'filePath': filePath,
      };

      if (serviceName.contains('transcribe')) {
        handleAction('transcribe_file', parameters);
      } else if (serviceName.contains('summarize')) {
        handleAction('summarize_text', parameters);
      }
    } catch (e) {
      log('$_logTag: Error handling Services menu action: $e', name: _logTag);
    }
  }

  // ==================== GLOBAL HOTKEYS ====================

  /// Initialize global hotkeys
  Future<void> _initializeGlobalHotkeys() async {
    try {
      final result =
          await _platform.invokeMethod<bool>('setupGlobalHotkeys') ?? false;
      _globalHotkeysEnabled = result;

      if (result) {
        await _registerGlobalHotkeys();
        log('$_logTag: Global hotkeys enabled', name: _logTag);
      } else {
        log('$_logTag: Failed to enable global hotkeys', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing global hotkeys: $e', name: _logTag);
    }
  }

  /// Register global hotkeys
  Future<void> _registerGlobalHotkeys() async {
    try {
      await _platform.invokeMethod('registerGlobalHotkeys', {
        'hotkeys': [
          {
            'identifier': 'start_recording',
            'keyCode': 'R',
            'modifiers': ['command', 'shift'],
            'description': 'Start/Stop Recording',
          },
          {
            'identifier': 'quick_transcribe',
            'keyCode': 'T',
            'modifiers': ['command', 'shift'],
            'description': 'Quick Transcribe',
          },
          {
            'identifier': 'show_app',
            'keyCode': 'M',
            'modifiers': ['command', 'shift'],
            'description': 'Show Meeting Summarizer',
          },
        ],
      });
    } catch (e) {
      log('$_logTag: Failed to register global hotkeys: $e', name: _logTag);
    }
  }

  /// Handle global hotkey
  void _handleGlobalHotkey(String hotkeyId, Map<String, dynamic>? parameters) {
    try {
      log('$_logTag: Handling global hotkey: $hotkeyId', name: _logTag);
      onGlobalHotkey?.call(hotkeyId, parameters);

      // Execute appropriate action
      final actionParameters = {
        ...?parameters,
        'source': 'macos_global_hotkey',
        'hotkeyId': hotkeyId,
      };

      switch (hotkeyId) {
        case 'start_recording':
          final action = _isRecording ? 'stop_recording' : 'start_recording';
          handleAction(action, actionParameters);
          break;
        case 'quick_transcribe':
          handleAction('quick_transcribe', actionParameters);
          break;
        case 'show_app':
          handleAction('show_app', actionParameters);
          break;
      }
    } catch (e) {
      log('$_logTag: Error handling global hotkey: $e', name: _logTag);
    }
  }

  // ==================== FILE ASSOCIATIONS & DRAG-DROP ====================

  /// Initialize file associations and drag-drop support
  Future<void> _initializeFileAssociations() async {
    try {
      final result =
          await _platform.invokeMethod<bool>('setupFileAssociations') ?? false;
      _fileAssociationsEnabled = result;

      if (result) {
        log('$_logTag: File associations enabled', name: _logTag);
      } else {
        log('$_logTag: Failed to enable file associations', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error initializing file associations: $e', name: _logTag);
    }
  }

  /// Handle files dropped on app
  void _handleFilesDropped(List<String> filePaths, String dropTarget) {
    try {
      log('$_logTag: Files dropped: ${filePaths.length} files on $dropTarget',
          name: _logTag);
      onFilesDropped?.call(filePaths, dropTarget);

      // Process dropped files
      for (final filePath in filePaths) {
        if (_isAudioFile(filePath)) {
          handleAction('import_audio_file', {
            'filePath': filePath,
            'source': 'macos_drag_drop',
            'dropTarget': dropTarget,
          });
        }
      }
    } catch (e) {
      log('$_logTag: Error handling dropped files: $e', name: _logTag);
    }
  }

  /// Check if file is an audio file
  bool _isAudioFile(String filePath) {
    final audioExtensions = [
      '.mp3',
      '.wav',
      '.m4a',
      '.aac',
      '.flac',
      '.ogg',
      '.wma'
    ];
    final extension = filePath.toLowerCase();
    return audioExtensions.any((ext) => extension.endsWith(ext));
  }

  // ==================== Platform Service Interface Implementation ====================

  @override
  Future<bool> registerIntegrations() async {
    try {
      // Re-register all integrations
      await _initializeMenuBarIntegration();
      await _initializeSpotlightSearch();
      await _initializeDockIntegration();
      await _initializeTouchBarSupport();
      await _initializeNotificationCenter();
      await _initializeServicesMenu();
      await _initializeGlobalHotkeys();
      await _initializeFileAssociations();

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
        case 'view_recordings':
          await _handleViewRecordings(parameters);
          break;
        case 'open_transcription':
          await _handleOpenTranscription(parameters);
          break;
        case 'generate_summary':
          await _handleGenerateSummary(parameters);
          break;
        case 'show_app':
          await _handleShowApp(parameters);
          break;
        case 'import_audio_file':
          await _handleImportAudioFile(parameters);
          break;
        case 'transcribe_file':
          await _handleTranscribeFile(parameters);
          break;
        case 'summarize_text':
          await _handleSummarizeText(parameters);
          break;
        case 'quick_transcribe':
          await _handleQuickTranscribe(parameters);
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
      // Update internal state
      _isRecording = state['isRecording'] as bool? ?? false;
      _isPaused = state['isPaused'] as bool? ?? false;
      _recordingDuration = state['recordingDuration'] as Duration?;
      _currentMeetingTitle = state['meetingTitle'] as String?;
      _isTranscribing = state['isTranscribing'] as bool? ?? false;
      _transcriptionProgress = state['transcriptionProgress'] as double? ?? 0.0;
      _recentRecordingsCount = state['recentRecordingsCount'] as int? ?? 0;

      // Update all integrations with current state
      await _updateMenuBarState();
      await _updateDockState();
      await _updateTouchBarState();

      // Index content if transcription is complete
      if (state['transcriptionComplete'] == true) {
        final recordingId = state['recordingId'] as String?;
        final title = state['title'] as String?;
        final transcript = state['transcript'] as String?;
        final createdAt = state['createdAt'] as DateTime?;

        if (recordingId != null &&
            title != null &&
            transcript != null &&
            createdAt != null) {
          await indexRecordingForSpotlight(
            recordingId: recordingId,
            title: title,
            transcript: transcript,
            createdAt: createdAt,
            duration: _recordingDuration,
          );
        }
      }
    } catch (e) {
      log('$_logTag: Error updating integrations: $e', name: _logTag);
    }
  }

  @override
  Future<bool> showSystemUI() async {
    try {
      await updateDockBadge(clearBadge: false, isRecording: _isRecording);
      await _updateMenuBarState();
      await _updateTouchBarState();
      return true;
    } catch (e) {
      log('$_logTag: Failed to show system UI: $e', name: _logTag);
      return false;
    }
  }

  @override
  Future<void> hideSystemUI() async {
    try {
      await updateDockBadge(clearBadge: true);
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
    _isRecording = true;
    await _updateAllIntegrations();
  }

  Future<void> _handleStopRecording(Map<String, dynamic>? parameters) async {
    log('$_logTag: Handling stop recording action', name: _logTag);
    _isRecording = false;
    _isPaused = false;
    await _updateAllIntegrations();
  }

  Future<void> _handlePauseRecording(Map<String, dynamic>? parameters) async {
    log('$_logTag: Handling pause recording action', name: _logTag);
    _isPaused = true;
    await _updateAllIntegrations();
  }

  Future<void> _handleResumeRecording(Map<String, dynamic>? parameters) async {
    log('$_logTag: Handling resume recording action', name: _logTag);
    _isPaused = false;
    await _updateAllIntegrations();
  }

  Future<void> _handleViewRecordings(Map<String, dynamic>? parameters) async {
    log('$_logTag: Handling view recordings action', name: _logTag);
  }

  Future<void> _handleOpenTranscription(
      Map<String, dynamic>? parameters) async {
    log('$_logTag: Handling open transcription action', name: _logTag);
  }

  Future<void> _handleGenerateSummary(Map<String, dynamic>? parameters) async {
    log('$_logTag: Handling generate summary action', name: _logTag);
  }

  Future<void> _handleShowApp(Map<String, dynamic>? parameters) async {
    log('$_logTag: Handling show app action', name: _logTag);
    await _platform.invokeMethod('showApp');
  }

  Future<void> _handleImportAudioFile(Map<String, dynamic>? parameters) async {
    final filePath = parameters?['filePath'] as String?;
    log('$_logTag: Handling import audio file: $filePath', name: _logTag);
  }

  Future<void> _handleTranscribeFile(Map<String, dynamic>? parameters) async {
    final filePath = parameters?['filePath'] as String?;
    log('$_logTag: Handling transcribe file: $filePath', name: _logTag);
  }

  Future<void> _handleSummarizeText(Map<String, dynamic>? parameters) async {
    final text = parameters?['text'] as String?;
    log('$_logTag: Handling summarize text: ${text?.length} characters',
        name: _logTag);
  }

  Future<void> _handleQuickTranscribe(Map<String, dynamic>? parameters) async {
    log('$_logTag: Handling quick transcribe action', name: _logTag);
  }

  // ==================== Helper Methods ====================

  /// Update all integrations with current state
  Future<void> _updateAllIntegrations() async {
    await _updateMenuBarState();
    await _updateDockState();
    await _updateTouchBarState();
  }

  /// Update menu bar state
  Future<void> _updateMenuBarState() async {
    await _menuBarService.updateRecordingState(
      isRecording: _isRecording,
      isPaused: _isPaused,
      duration: _recordingDuration,
      meetingTitle: _currentMeetingTitle,
    );

    await _menuBarService.updateTranscriptionState(
      isTranscribing: _isTranscribing,
      progress: _transcriptionProgress,
    );
  }

  /// Update dock state
  Future<void> _updateDockState() async {
    await updateDockBadge(
      recordingCount: _recentRecordingsCount,
      isRecording: _isRecording,
    );
  }

  /// Update Touch Bar state
  Future<void> _updateTouchBarState() async {
    await updateTouchBar(
      isRecording: _isRecording,
      isPaused: _isPaused,
      duration: _recordingDuration,
      progress: _transcriptionProgress,
    );
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Get comprehensive service status
  Map<String, dynamic> getServiceStatus() {
    return {
      'isInitialized': _isInitialized,
      'isAvailable': isAvailable,
      'menuBarEnabled': _menuBarService.isAvailable,
      'spotlightEnabled': _spotlightEnabled,
      'dockIntegrationEnabled': _dockIntegrationEnabled,
      'touchBarEnabled': _touchBarEnabled,
      'notificationCenterEnabled': _notificationCenterEnabled,
      'servicesMenuEnabled': _servicesMenuEnabled,
      'globalHotkeysEnabled': _globalHotkeysEnabled,
      'fileAssociationsEnabled': _fileAssociationsEnabled,
      'currentState': {
        'isRecording': _isRecording,
        'isPaused': _isPaused,
        'duration': _recordingDuration?.inSeconds,
        'meetingTitle': _currentMeetingTitle,
        'isTranscribing': _isTranscribing,
        'transcriptionProgress': _transcriptionProgress,
        'recentRecordingsCount': _recentRecordingsCount,
      },
      'platform': 'macos',
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// Get menu bar service for direct access
  MacOSMenuBarService get menuBarService => _menuBarService;

  /// Dispose all resources and cleanup
  @override
  void dispose() {
    try {
      // Dispose sub-services
      _menuBarService.dispose();

      // Clear callbacks
      onPlatformAction = null;
      onSpotlightSearch = null;
      onDockAction = null;
      onTouchBarAction = null;
      onNotificationAction = null;
      onServicesMenuAction = null;
      onGlobalHotkey = null;
      onFilesDropped = null;

      _isInitialized = false;
      log('$_logTag: macOS platform service disposed', name: _logTag);
    } catch (e) {
      log('$_logTag: Error disposing service: $e', name: _logTag);
    }
  }
}
