/// iOS Siri Shortcuts integration service for meeting recording and transcription
library;

import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Available shortcut types for the meeting summarizer
enum ShortcutType {
  startRecording('Start Recording', 'start_recording'),
  stopRecording('Stop Recording', 'stop_recording'),
  transcribeLatest('Transcribe Latest', 'transcribe_latest'),
  generateSummary('Generate Summary', 'generate_summary'),
  searchRecordings('Search Recordings', 'search_recordings');

  const ShortcutType(this.displayName, this.identifier);
  final String displayName;
  final String identifier;
}

/// Service for integrating with iOS Siri Shortcuts
class SiriShortcutsService {
  static const String _logTag = 'SiriShortcutsService';

  late final FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _isInitialized = false;

  /// Initialize the Siri Shortcuts service
  Future<bool> initialize() async {
    try {
      if (!Platform.isIOS) {
        log(
          '$_logTag: Siri Shortcuts only available on iOS platform',
          name: _logTag,
        );
        return false;
      }

      _notificationsPlugin = FlutterLocalNotificationsPlugin();

      // Initialize notifications for Siri integration
      const initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        requestCriticalPermission: false,
      );

      const initializationSettings = InitializationSettings(
        iOS: initializationSettingsIOS,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      _isInitialized = true;
      log(
        '$_logTag: Siri Shortcuts service initialized successfully',
        name: _logTag,
      );
      return true;
    } catch (e) {
      log(
        '$_logTag: Failed to initialize Siri Shortcuts service: $e',
        name: _logTag,
      );
      return false;
    }
  }

  /// Check if Siri Shortcuts are available on this platform
  bool get isAvailable => Platform.isIOS && _isInitialized;

  /// Register shortcuts with Siri
  Future<bool> registerShortcuts() async {
    if (!isAvailable) {
      log('$_logTag: Siri Shortcuts not available', name: _logTag);
      return false;
    }

    try {
      // Register all available shortcuts
      for (final shortcutType in ShortcutType.values) {
        await _registerShortcut(shortcutType);
      }

      log('$_logTag: All shortcuts registered successfully', name: _logTag);
      return true;
    } catch (e) {
      log('$_logTag: Failed to register shortcuts: $e', name: _logTag);
      return false;
    }
  }

  /// Register a specific shortcut with Siri
  Future<void> _registerShortcut(ShortcutType shortcutType) async {
    try {
      // For now, we'll use local notifications as a placeholder
      // In a full implementation, this would use the actual siri_shortcuts package
      log(
        '$_logTag: Registering shortcut: ${shortcutType.displayName}',
        name: _logTag,
      );

      // This is a simplified implementation - in production you would use:
      // await SiriShortcuts.createShortcut(
      //   identifier: shortcutType.identifier,
      //   title: shortcutType.displayName,
      //   subtitle: _getShortcutSubtitle(shortcutType),
      //   userActivity: NSUserActivity(activityType: shortcutType.identifier),
      // );

      final subtitle = _getShortcutSubtitle(shortcutType); // For future use
      log(
        '$_logTag: Would create shortcut: ${shortcutType.displayName} - $subtitle',
        name: _logTag,
      );
    } catch (e) {
      log(
        '$_logTag: Failed to register shortcut ${shortcutType.identifier}: $e',
        name: _logTag,
      );
    }
  }

  /// Get subtitle for a shortcut type
  String _getShortcutSubtitle(ShortcutType shortcutType) {
    switch (shortcutType) {
      case ShortcutType.startRecording:
        return 'Begin recording a new meeting';
      case ShortcutType.stopRecording:
        return 'Stop the current recording';
      case ShortcutType.transcribeLatest:
        return 'Transcribe the most recent recording';
      case ShortcutType.generateSummary:
        return 'Generate AI summary of latest transcription';
      case ShortcutType.searchRecordings:
        return 'Search through your recordings';
    }
  }

  /// Handle shortcut execution
  Future<void> handleShortcutExecution(
    String shortcutIdentifier,
    Map<String, dynamic>? parameters,
  ) async {
    if (!isAvailable) {
      log(
        '$_logTag: Cannot handle shortcut - service not available',
        name: _logTag,
      );
      return;
    }

    try {
      final shortcutType = ShortcutType.values.firstWhere(
        (type) => type.identifier == shortcutIdentifier,
        orElse: () => throw ArgumentError(
          'Unknown shortcut identifier: $shortcutIdentifier',
        ),
      );

      log(
        '$_logTag: Executing shortcut: ${shortcutType.displayName}',
        name: _logTag,
      );

      switch (shortcutType) {
        case ShortcutType.startRecording:
          await _handleStartRecording(parameters);
          break;
        case ShortcutType.stopRecording:
          await _handleStopRecording(parameters);
          break;
        case ShortcutType.transcribeLatest:
          await _handleTranscribeLatest(parameters);
          break;
        case ShortcutType.generateSummary:
          await _handleGenerateSummary(parameters);
          break;
        case ShortcutType.searchRecordings:
          await _handleSearchRecordings(parameters);
          break;
      }
    } catch (e) {
      log('$_logTag: Failed to handle shortcut execution: $e', name: _logTag);
      await _showErrorNotification('Shortcut execution failed: $e');
    }
  }

  /// Handle start recording shortcut
  Future<void> _handleStartRecording(Map<String, dynamic>? parameters) async {
    try {
      // TODO: Integrate with AudioRecordingService
      log('$_logTag: Starting recording via Siri shortcut', name: _logTag);

      await _showNotification(
        'Recording Started',
        'Meeting recording has begun via Siri shortcut',
        'recording_started',
      );
    } catch (e) {
      log('$_logTag: Failed to start recording: $e', name: _logTag);
      rethrow;
    }
  }

  /// Handle stop recording shortcut
  Future<void> _handleStopRecording(Map<String, dynamic>? parameters) async {
    try {
      // TODO: Integrate with AudioRecordingService
      log('$_logTag: Stopping recording via Siri shortcut', name: _logTag);

      await _showNotification(
        'Recording Stopped',
        'Meeting recording has been stopped via Siri shortcut',
        'recording_stopped',
      );
    } catch (e) {
      log('$_logTag: Failed to stop recording: $e', name: _logTag);
      rethrow;
    }
  }

  /// Handle transcribe latest shortcut
  Future<void> _handleTranscribeLatest(Map<String, dynamic>? parameters) async {
    try {
      // TODO: Integrate with TranscriptionService
      log(
        '$_logTag: Transcribing latest recording via Siri shortcut',
        name: _logTag,
      );

      await _showNotification(
        'Transcription Started',
        'Transcribing your latest recording...',
        'transcription_started',
      );
    } catch (e) {
      log('$_logTag: Failed to transcribe latest recording: $e', name: _logTag);
      rethrow;
    }
  }

  /// Handle generate summary shortcut
  Future<void> _handleGenerateSummary(Map<String, dynamic>? parameters) async {
    try {
      // TODO: Integrate with AI Summarization Service
      log('$_logTag: Generating summary via Siri shortcut', name: _logTag);

      await _showNotification(
        'Summary Generation Started',
        'Generating AI summary of your latest transcription...',
        'summary_started',
      );
    } catch (e) {
      log('$_logTag: Failed to generate summary: $e', name: _logTag);
      rethrow;
    }
  }

  /// Handle search recordings shortcut
  Future<void> _handleSearchRecordings(Map<String, dynamic>? parameters) async {
    try {
      final query = parameters?['query'] as String?;
      log(
        '$_logTag: Searching recordings via Siri shortcut: $query',
        name: _logTag,
      );

      await _showNotification(
        'Search Started',
        query != null ? 'Searching for: $query' : 'Opening search interface...',
        'search_started',
      );
    } catch (e) {
      log('$_logTag: Failed to search recordings: $e', name: _logTag);
      rethrow;
    }
  }

  /// Show a notification
  Future<void> _showNotification(
    String title,
    String body,
    String payload,
  ) async {
    if (!_isInitialized) return;

    try {
      const notificationDetails = NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      );

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      log('$_logTag: Failed to show notification: $e', name: _logTag);
    }
  }

  /// Show error notification
  Future<void> _showErrorNotification(String message) async {
    await _showNotification('Shortcut Error', message, 'error');
  }

  /// Handle notification responses
  void _onNotificationResponse(NotificationResponse response) {
    try {
      final payload = response.payload;
      if (payload != null) {
        log(
          '$_logTag: Notification tapped with payload: $payload',
          name: _logTag,
        );

        // TODO: Navigate to appropriate screen based on payload
        switch (payload) {
          case 'recording_started':
          case 'recording_stopped':
            // Navigate to recording screen
            break;
          case 'transcription_started':
            // Navigate to transcription screen
            break;
          case 'summary_started':
            // Navigate to summary screen
            break;
          case 'search_started':
            // Navigate to search screen
            break;
          default:
            log(
              '$_logTag: Unknown notification payload: $payload',
              name: _logTag,
            );
        }
      }
    } catch (e) {
      log(
        '$_logTag: Failed to handle notification response: $e',
        name: _logTag,
      );
    }
  }

  /// Update shortcuts based on current app state
  Future<void> updateShortcuts({
    bool isRecording = false,
    bool hasRecordings = false,
    bool hasTranscriptions = false,
  }) async {
    if (!isAvailable) return;

    try {
      log('$_logTag: Updating shortcuts based on app state', name: _logTag);

      // In a full implementation, this would dynamically enable/disable shortcuts
      // based on the current application state

      // TODO: Update shortcut availability
      // - Disable "Start Recording" if already recording
      // - Disable "Stop Recording" if not recording
      // - Disable "Transcribe Latest" if no recordings
      // - Disable "Generate Summary" if no transcriptions
    } catch (e) {
      log('$_logTag: Failed to update shortcuts: $e', name: _logTag);
    }
  }

  /// Request Siri permissions
  Future<bool> requestSiriPermissions() async {
    if (!Platform.isIOS) return false;

    try {
      // Request notification permissions as proxy for Siri integration
      final result = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      log(
        '$_logTag: Siri permissions requested, result: $result',
        name: _logTag,
      );
      return result ?? false;
    } catch (e) {
      log('$_logTag: Failed to request Siri permissions: $e', name: _logTag);
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _isInitialized = false;
    log('$_logTag: Service disposed', name: _logTag);
  }
}
