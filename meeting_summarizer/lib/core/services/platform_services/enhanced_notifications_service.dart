/// Enhanced notification service with platform-specific actions and features
library;

import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification categories for different types of notifications
enum NotificationCategory {
  recording('recording', 'Recording Control'),
  transcription('transcription', 'Transcription Progress'),
  summary('summary', 'Summary Generation'),
  reminder('reminder', 'Meeting Reminders'),
  error('error', 'Error Notifications'),
  status('status', 'Status Updates');

  const NotificationCategory(this.identifier, this.displayName);
  final String identifier;
  final String displayName;
}

/// Notification priority levels
enum NotificationPriority {
  low('low', -1),
  normal('normal', 0),
  high('high', 1),
  critical('critical', 2);

  const NotificationPriority(this.identifier, this.androidImportance);
  final String identifier;
  final int androidImportance;
}

/// Notification action types
enum NotificationActionType {
  startRecording('start_recording', 'Start Recording'),
  stopRecording('stop_recording', 'Stop Recording'),
  pauseRecording('pause_recording', 'Pause'),
  resumeRecording('resume_recording', 'Resume'),
  openApp('open_app', 'Open App'),
  dismissRecording('dismiss_recording', 'Dismiss'),
  viewTranscription('view_transcription', 'View Transcript'),
  generateSummary('generate_summary', 'Summarize'),
  shareRecording('share_recording', 'Share'),
  deleteRecording('delete_recording', 'Delete');

  const NotificationActionType(this.identifier, this.displayName);
  final String identifier;
  final String displayName;
}

/// Enhanced notification service with platform-specific features
class EnhancedNotificationsService {
  static const String _logTag = 'EnhancedNotificationsService';

  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _isInitialized = false;

  /// Callbacks for notification actions
  void Function(NotificationActionType action, Map<String, dynamic>? data)?
      onNotificationAction;
  void Function(int id, String? payload)? onNotificationTapped;

  /// Initialize the enhanced notifications service
  Future<bool> initialize() async {
    try {
      _notificationsPlugin = FlutterLocalNotificationsPlugin();

      // Android-specific initialization
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      // iOS-specific initialization
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        requestCriticalPermission: false,
      );

      // macOS-specific initialization
      const macosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: macosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse:
            _onBackgroundNotificationResponse,
      );

      // Create notification channels for Android
      if (Platform.isAndroid) {
        await _createNotificationChannels();
      }

      // Request permissions
      await requestPermissions();

      _isInitialized = true;
      log(
        '$_logTag: Enhanced notifications service initialized',
        name: _logTag,
      );
      return true;
    } catch (e) {
      log(
        '$_logTag: Failed to initialize notifications service: $e',
        name: _logTag,
      );
      return false;
    }
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    if (!Platform.isAndroid) return;

    try {
      final androidPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin == null) return;

      for (final category in NotificationCategory.values) {
        await androidPlugin.createNotificationChannel(
          AndroidNotificationChannel(
            category.identifier,
            category.displayName,
            description:
                'Notifications for ${category.displayName.toLowerCase()}',
            importance: Importance.high,
            enableVibration: true,
            enableLights: true,
            ledColor: const Color.fromARGB(255, 255, 0, 0),
          ),
        );
      }

      log('$_logTag: Android notification channels created', name: _logTag);
    } catch (e) {
      log(
        '$_logTag: Failed to create notification channels: $e',
        name: _logTag,
      );
    }
  }

  /// Check if notifications are available
  bool get isAvailable => _isInitialized;

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      bool? granted = false;

      if (Platform.isAndroid) {
        final androidPlugin =
            _notificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        granted = await androidPlugin?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        final iosPlugin =
            _notificationsPlugin.resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        granted = await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: false,
        );
      } else if (Platform.isMacOS) {
        final macosPlugin =
            _notificationsPlugin.resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin>();
        granted = await macosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: false,
        );
      }

      log(
        '$_logTag: Notification permissions granted: $granted',
        name: _logTag,
      );
      return granted ?? false;
    } catch (e) {
      log(
        '$_logTag: Failed to request notification permissions: $e',
        name: _logTag,
      );
      return false;
    }
  }

  /// Show recording control notification
  Future<void> showRecordingNotification({
    required bool isRecording,
    Duration? duration,
    bool isPaused = false,
    String? meetingTitle,
  }) async {
    if (!isAvailable) return;

    try {
      final title = isRecording
          ? (isPaused ? 'Recording Paused' : 'Recording Active')
          : 'Recording Stopped';

      final body = meetingTitle != null
          ? '$meetingTitle${duration != null ? ' • ${_formatDuration(duration)}' : ''}'
          : duration != null
              ? 'Duration: ${_formatDuration(duration)}'
              : 'Meeting recording';

      final actions = _getRecordingActions(isRecording, isPaused);

      await _showNotificationWithActions(
        id: 1001,
        title: title,
        body: body,
        category: NotificationCategory.recording,
        priority: NotificationPriority.high,
        actions: actions,
        ongoing: isRecording,
        payload: {
          'type': 'recording',
          'isRecording': isRecording,
          'isPaused': isPaused,
          'duration': duration?.inSeconds,
          'meetingTitle': meetingTitle,
        },
      );
    } catch (e) {
      log('$_logTag: Failed to show recording notification: $e', name: _logTag);
    }
  }

  /// Show transcription progress notification
  Future<void> showTranscriptionNotification({
    required bool isTranscribing,
    double progress = 0.0,
    String? status,
    String? fileName,
  }) async {
    if (!isAvailable) return;

    try {
      final title =
          isTranscribing ? 'Transcribing Audio' : 'Transcription Complete';

      final body = isTranscribing
          ? '${(progress * 100).toInt()}% • ${status ?? 'Processing...'}'
          : fileName != null
              ? 'Transcription ready for $fileName'
              : 'Transcription completed successfully';

      final actions = isTranscribing
          ? <NotificationActionType>[]
          : [
              NotificationActionType.viewTranscription,
              NotificationActionType.generateSummary,
            ];

      await _showNotificationWithActions(
        id: 1002,
        title: title,
        body: body,
        category: NotificationCategory.transcription,
        priority: NotificationPriority.normal,
        actions: actions,
        progress: isTranscribing ? progress : null,
        payload: {
          'type': 'transcription',
          'isTranscribing': isTranscribing,
          'progress': progress,
          'status': status,
          'fileName': fileName,
        },
      );
    } catch (e) {
      log(
        '$_logTag: Failed to show transcription notification: $e',
        name: _logTag,
      );
    }
  }

  /// Show summary generation notification
  Future<void> showSummaryNotification({
    required bool isGenerating,
    String? summaryType,
    String? fileName,
    bool completed = false,
  }) async {
    if (!isAvailable) return;

    try {
      final title = isGenerating
          ? 'Generating Summary'
          : completed
              ? 'Summary Ready'
              : 'Summary Generation Failed';

      final body = isGenerating
          ? 'Creating ${summaryType ?? 'summary'} for ${fileName ?? 'recording'}'
          : completed
              ? 'AI summary generated successfully'
              : 'Failed to generate summary';

      final actions = completed
          ? [
              NotificationActionType.openApp,
              NotificationActionType.shareRecording,
            ]
          : <NotificationActionType>[];

      await _showNotificationWithActions(
        id: 1003,
        title: title,
        body: body,
        category: NotificationCategory.summary,
        priority: NotificationPriority.normal,
        actions: actions,
        payload: {
          'type': 'summary',
          'isGenerating': isGenerating,
          'summaryType': summaryType,
          'fileName': fileName,
          'completed': completed,
        },
      );
    } catch (e) {
      log('$_logTag: Failed to show summary notification: $e', name: _logTag);
    }
  }

  /// Show error notification
  Future<void> showErrorNotification({
    required String title,
    required String message,
    String? details,
    bool canRetry = false,
  }) async {
    if (!isAvailable) return;

    try {
      final body = details != null ? '$message\n$details' : message;
      final actions = canRetry
          ? [NotificationActionType.openApp]
          : <NotificationActionType>[];

      await _showNotificationWithActions(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        category: NotificationCategory.error,
        priority: NotificationPriority.high,
        actions: actions,
        payload: {
          'type': 'error',
          'title': title,
          'message': message,
          'details': details,
          'canRetry': canRetry,
        },
      );
    } catch (e) {
      log('$_logTag: Failed to show error notification: $e', name: _logTag);
    }
  }

  /// Show status update notification
  Future<void> showStatusNotification({
    required String title,
    required String message,
    NotificationPriority priority = NotificationPriority.normal,
    Map<String, dynamic>? data,
  }) async {
    if (!isAvailable) return;

    try {
      await _showNotificationWithActions(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: message,
        category: NotificationCategory.status,
        priority: priority,
        actions: [],
        payload: {
          'type': 'status',
          'title': title,
          'message': message,
          'data': data,
        },
      );
    } catch (e) {
      log('$_logTag: Failed to show status notification: $e', name: _logTag);
    }
  }

  /// Show notification with actions
  Future<void> _showNotificationWithActions({
    required int id,
    required String title,
    required String body,
    required NotificationCategory category,
    required NotificationPriority priority,
    required List<NotificationActionType> actions,
    bool ongoing = false,
    double? progress,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        category.identifier,
        category.displayName,
        channelDescription:
            'Notifications for ${category.displayName.toLowerCase()}',
        importance: _getAndroidImportance(priority),
        priority: _getAndroidPriority(priority),
        ongoing: ongoing,
        autoCancel: !ongoing,
        enableVibration: true,
        enableLights: true,
        ledColor: const Color.fromARGB(255, 255, 0, 0),
        showProgress: progress != null,
        maxProgress: progress != null ? 100 : 0,
        progress: progress != null ? (progress * 100).toInt() : 0,
        actions: actions
            .map(
              (action) => AndroidNotificationAction(
                action.identifier,
                action.displayName,
                cancelNotification: false,
                showsUserInterface: _shouldShowUI(action),
              ),
            )
            .toList(),
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: _getIOSInterruptionLevel(priority),
        categoryIdentifier: category.identifier,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload != null ? _encodePayload(payload) : null,
      );

      log('$_logTag: Notification shown: $title (ID: $id)', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to show notification: $e', name: _logTag);
    }
  }

  /// Get recording actions based on state
  List<NotificationActionType> _getRecordingActions(
    bool isRecording,
    bool isPaused,
  ) {
    if (!isRecording) {
      return [
        NotificationActionType.startRecording,
        NotificationActionType.openApp,
      ];
    }

    if (isPaused) {
      return [
        NotificationActionType.resumeRecording,
        NotificationActionType.stopRecording,
        NotificationActionType.openApp,
      ];
    }

    return [
      NotificationActionType.pauseRecording,
      NotificationActionType.stopRecording,
      NotificationActionType.openApp,
    ];
  }

  /// Handle notification response
  void _onNotificationResponse(NotificationResponse response) {
    try {
      final actionId = response.actionId;
      final payload = response.payload;

      if (actionId != null) {
        // Handle notification action
        final action = NotificationActionType.values.firstWhere(
          (a) => a.identifier == actionId,
          orElse: () => throw ArgumentError('Unknown action: $actionId'),
        );

        final data = payload != null ? _decodePayload(payload) : null;
        log(
          '$_logTag: Notification action triggered: ${action.displayName}',
          name: _logTag,
        );
        onNotificationAction?.call(action, data);
      } else if (payload != null) {
        // Handle notification tap
        _decodePayload(payload); // Decode for potential future use
        final notificationId = response.id ?? 0;
        log('$_logTag: Notification tapped: ID $notificationId', name: _logTag);
        onNotificationTapped?.call(notificationId, payload);
      }
    } catch (e) {
      log(
        '$_logTag: Failed to handle notification response: $e',
        name: _logTag,
      );
    }
  }

  /// Handle background notification response
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    // This runs in background/isolate context
    try {
      log(
        'EnhancedNotificationsService: Background notification action: ${response.actionId}',
      );

      // TODO: Handle background actions
      // In a full implementation, this might:
      // - Start/stop recording service
      // - Update app state
      // - Send data to main isolate
    } catch (e) {
      log('EnhancedNotificationsService: Error in background callback: $e');
    }
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int id) async {
    if (!isAvailable) return;

    try {
      await _notificationsPlugin.cancel(id);
      log('$_logTag: Notification cancelled: ID $id', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to cancel notification: $e', name: _logTag);
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    if (!isAvailable) return;

    try {
      await _notificationsPlugin.cancelAll();
      log('$_logTag: All notifications cancelled', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to cancel all notifications: $e', name: _logTag);
    }
  }

  /// Helper methods
  Importance _getAndroidImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Importance.low;
      case NotificationPriority.normal:
        return Importance.defaultImportance;
      case NotificationPriority.high:
        return Importance.high;
      case NotificationPriority.critical:
        return Importance.max;
    }
  }

  Priority _getAndroidPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Priority.low;
      case NotificationPriority.normal:
        return Priority.defaultPriority;
      case NotificationPriority.high:
        return Priority.high;
      case NotificationPriority.critical:
        return Priority.max;
    }
  }

  InterruptionLevel _getIOSInterruptionLevel(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return InterruptionLevel.passive;
      case NotificationPriority.normal:
        return InterruptionLevel.active;
      case NotificationPriority.high:
        return InterruptionLevel.timeSensitive;
      case NotificationPriority.critical:
        return InterruptionLevel.critical;
    }
  }

  bool _shouldShowUI(NotificationActionType action) {
    switch (action) {
      case NotificationActionType.openApp:
      case NotificationActionType.viewTranscription:
        return true;
      default:
        return false;
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String _encodePayload(Map<String, dynamic> data) {
    // Simple JSON encoding for payload
    try {
      return data.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
    } catch (e) {
      return '';
    }
  }

  Map<String, dynamic> _decodePayload(String payload) {
    // Simple payload decoding
    try {
      final data = <String, dynamic>{};
      for (final pair in payload.split('&')) {
        final parts = pair.split('=');
        if (parts.length == 2) {
          data[parts[0]] = Uri.decodeComponent(parts[1]);
        }
      }
      return data;
    } catch (e) {
      return {};
    }
  }

  /// Dispose resources
  void dispose() {
    _isInitialized = false;
    onNotificationAction = null;
    onNotificationTapped = null;
    log('$_logTag: Service disposed', name: _logTag);
  }
}
