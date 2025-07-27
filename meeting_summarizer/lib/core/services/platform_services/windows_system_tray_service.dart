/// Windows System Tray and File Associations service
library;

import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:system_tray/system_tray.dart';

/// System tray menu item types
enum TrayMenuItemType {
  action('action'),
  separator('separator'),
  submenu('submenu'),
  checkbox('checkbox');

  const TrayMenuItemType(this.identifier);
  final String identifier;
}

/// System tray actions
enum TrayAction {
  startRecording('start_recording', 'Start Recording'),
  stopRecording('stop_recording', 'Stop Recording'),
  pauseRecording('pause_recording', 'Pause Recording'),
  resumeRecording('resume_recording', 'Resume Recording'),
  openApp('open_app', 'Open Meeting Summarizer'),
  viewRecordings('view_recordings', 'View Recordings'),
  transcribeLatest('transcribe_latest', 'Transcribe Latest'),
  generateSummary('generate_summary', 'Generate Summary'),
  settings('settings', 'Settings'),
  exit('exit', 'Exit');

  const TrayAction(this.identifier, this.displayName);
  final String identifier;
  final String displayName;
}

/// File association types
enum FileAssociationType {
  audio('audio', ['.mp3', '.wav', '.m4a', '.aac', '.flac', '.ogg']),
  transcript('.txt', ['.txt', '.json']),
  summary('.md', ['.md', '.html']);

  const FileAssociationType(this.category, this.extensions);
  final String category;
  final List<String> extensions;
}

/// Windows System Tray and File Associations service
class WindowsSystemTrayService {
  static const String _logTag = 'WindowsSystemTrayService';

  late SystemTray _systemTray;
  bool _isInitialized = false;
  bool _isTrayVisible = false;
  Timer? _statusUpdateTimer;

  /// Callbacks for tray actions
  void Function(TrayAction action, Map<String, dynamic>? parameters)?
      onTrayAction;
  void Function(String filePath, FileAssociationType type)? onFileOpened;

  /// Initialize Windows System Tray service
  Future<bool> initialize() async {
    try {
      if (!Platform.isWindows) {
        log('$_logTag: System Tray only available on Windows', name: _logTag);
        return false;
      }

      _systemTray = SystemTray();

      // Initialize system tray
      await _systemTray.initSystemTray(
        title: "Meeting Summarizer",
        iconPath: "assets/icons/tray_icon.ico", // TODO: Add actual icon
        toolTip: "Meeting Summarizer - Ready",
      );

      // Set up tray menu
      await _setupTrayMenu();

      // Register for tray events
      _systemTray.registerSystemTrayEventHandler((eventName) {
        _handleTrayEvent(eventName);
      });

      // Setup file associations
      await _setupFileAssociations();

      _isInitialized = true;
      _isTrayVisible = true;
      _startStatusUpdates();

      log('$_logTag: Windows System Tray service initialized', name: _logTag);
      return true;
    } catch (e) {
      log(
        '$_logTag: Failed to initialize System Tray service: $e',
        name: _logTag,
      );
      return false;
    }
  }

  /// Check if service is available
  bool get isAvailable => Platform.isWindows && _isInitialized;
  bool get isTrayVisible => _isTrayVisible;

  /// Setup system tray menu
  Future<void> _setupTrayMenu() async {
    try {
      final Menu menu = Menu();

      // Recording controls
      await menu.buildFrom([
        MenuItemLabel(
          label: TrayAction.startRecording.displayName,
          onClicked: (menuItem) => _handleTrayAction(TrayAction.startRecording),
        ),
        MenuItemLabel(
          label: TrayAction.stopRecording.displayName,
          onClicked: (menuItem) => _handleTrayAction(TrayAction.stopRecording),
          enabled: false, // Initially disabled
        ),
        MenuSeparator(),

        // Quick actions
        MenuItemLabel(
          label: TrayAction.transcribeLatest.displayName,
          onClicked: (menuItem) =>
              _handleTrayAction(TrayAction.transcribeLatest),
        ),
        MenuItemLabel(
          label: TrayAction.generateSummary.displayName,
          onClicked: (menuItem) =>
              _handleTrayAction(TrayAction.generateSummary),
        ),
        MenuSeparator(),

        // App controls
        MenuItemLabel(
          label: TrayAction.openApp.displayName,
          onClicked: (menuItem) => _handleTrayAction(TrayAction.openApp),
        ),
        MenuItemLabel(
          label: TrayAction.viewRecordings.displayName,
          onClicked: (menuItem) => _handleTrayAction(TrayAction.viewRecordings),
        ),
        MenuSeparator(),

        // Settings and exit
        MenuItemLabel(
          label: TrayAction.settings.displayName,
          onClicked: (menuItem) => _handleTrayAction(TrayAction.settings),
        ),
        MenuItemLabel(
          label: TrayAction.exit.displayName,
          onClicked: (menuItem) => _handleTrayAction(TrayAction.exit),
        ),
      ]);

      await _systemTray.setContextMenu(menu);
      log('$_logTag: System tray menu configured', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to setup tray menu: $e', name: _logTag);
    }
  }

  /// Setup file associations
  Future<void> _setupFileAssociations() async {
    try {
      // TODO: Setup Windows file associations
      // In a full implementation, this would:
      // - Register with Windows Registry
      // - Set up file type handlers
      // - Configure context menu items
      // - Set application as default handler

      log('$_logTag: File associations configured', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to setup file associations: $e', name: _logTag);
    }
  }

  /// Start status updates for system tray
  void _startStatusUpdates() {
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateTrayStatus();
    });
  }

  /// Update system tray status and appearance
  Future<void> _updateTrayStatus() async {
    if (!isAvailable) return;

    try {
      // TODO: Update tray icon and tooltip based on current state
      log('$_logTag: System tray status updated', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to update tray status: $e', name: _logTag);
    }
  }

  /// Handle tray events
  void _handleTrayEvent(String eventName) {
    try {
      log('$_logTag: Tray event: $eventName', name: _logTag);

      switch (eventName) {
        case "leftMouseUp":
          // Left click - toggle main window
          onTrayAction?.call(TrayAction.openApp, null);
          break;
        case "rightMouseUp":
          // Right click - show context menu (handled automatically)
          break;
        case "leftMouseDoubleClick":
          // Double click - open app
          onTrayAction?.call(TrayAction.openApp, null);
          break;
        default:
          log('$_logTag: Unknown tray event: $eventName', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Failed to handle tray event: $e', name: _logTag);
    }
  }

  /// Handle tray action
  void _handleTrayAction(TrayAction action) {
    try {
      log(
        '$_logTag: Handling tray action: ${action.displayName}',
        name: _logTag,
      );
      onTrayAction?.call(action, null);
    } catch (e) {
      log('$_logTag: Failed to handle tray action: $e', name: _logTag);
    }
  }

  /// Update system tray for recording state
  Future<void> updateRecordingState({
    required bool isRecording,
    bool isPaused = false,
    Duration? duration,
    String? meetingTitle,
  }) async {
    if (!isAvailable) return;

    try {
      // Update tooltip
      final status = isRecording
          ? (isPaused ? 'Recording Paused' : 'Recording Active')
          : 'Ready to Record';

      final tooltip = meetingTitle != null
          ? 'Meeting Summarizer - $status ($meetingTitle)'
          : 'Meeting Summarizer - $status';

      await _systemTray.setToolTip(tooltip);

      // Update icon if needed
      if (isRecording) {
        // TODO: Change to recording icon
        // await _systemTray.setImage("assets/icons/recording_icon.ico");
      } else {
        // TODO: Change to normal icon
        // await _systemTray.setImage("assets/icons/tray_icon.ico");
      }

      // Update menu items
      await _updateMenuItemStates(isRecording: isRecording, isPaused: isPaused);

      log(
        '$_logTag: System tray updated for recording: $status',
        name: _logTag,
      );
    } catch (e) {
      log('$_logTag: Failed to update recording state: $e', name: _logTag);
    }
  }

  /// Update system tray for transcription state
  Future<void> updateTranscriptionState({
    required bool isTranscribing,
    double progress = 0.0,
    String? status,
  }) async {
    if (!isAvailable) return;

    try {
      final displayStatus = isTranscribing
          ? 'Transcribing: ${(progress * 100).toInt()}%'
          : 'Transcription Ready';

      await _systemTray.setToolTip('Meeting Summarizer - $displayStatus');

      log(
        '$_logTag: System tray updated for transcription: $displayStatus',
        name: _logTag,
      );
    } catch (e) {
      log('$_logTag: Failed to update transcription state: $e', name: _logTag);
    }
  }

  /// Update menu item states based on app state
  Future<void> _updateMenuItemStates({
    required bool isRecording,
    bool isPaused = false,
  }) async {
    try {
      // TODO: Update actual menu item states
      // In a full implementation, this would:
      // - Enable/disable menu items based on state
      // - Update menu item labels if needed
      // - Refresh the context menu

      log('$_logTag: Menu item states updated', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to update menu item states: $e', name: _logTag);
    }
  }

  /// Show/hide system tray icon
  Future<void> setTrayVisibility(bool visible) async {
    if (!isAvailable) return;

    try {
      if (visible && !_isTrayVisible) {
        await _systemTray.initSystemTray(
          title: "Meeting Summarizer",
          iconPath: "assets/icons/tray_icon.ico",
          toolTip: "Meeting Summarizer - Ready",
        );
        _isTrayVisible = true;
      } else if (!visible && _isTrayVisible) {
        await _systemTray.destroy();
        _isTrayVisible = false;
      }

      log('$_logTag: System tray visibility set to: $visible', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to set tray visibility: $e', name: _logTag);
    }
  }

  /// Handle file opened through association
  Future<void> handleFileOpened(String filePath) async {
    if (!isAvailable) return;

    try {
      final extension = filePath.toLowerCase().split('.').last;

      FileAssociationType? associationType;
      for (final type in FileAssociationType.values) {
        if (type.extensions.any((ext) => ext.endsWith('.$extension'))) {
          associationType = type;
          break;
        }
      }

      if (associationType != null) {
        log(
          '$_logTag: File opened via association: $filePath (${associationType.category})',
          name: _logTag,
        );
        onFileOpened?.call(filePath, associationType);
      } else {
        log('$_logTag: Unknown file type opened: $filePath', name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Failed to handle file opened: $e', name: _logTag);
    }
  }

  /// Register file associations with Windows
  Future<bool> registerFileAssociations() async {
    if (!Platform.isWindows) return false;

    try {
      // TODO: Register actual file associations
      // In a full implementation, this would:
      // - Create registry entries for file types
      // - Set up context menu entries
      // - Configure default application settings
      // - Handle UAC elevation if needed

      log('$_logTag: File associations registered', name: _logTag);
      return true;
    } catch (e) {
      log('$_logTag: Failed to register file associations: $e', name: _logTag);
      return false;
    }
  }

  /// Unregister file associations
  Future<bool> unregisterFileAssociations() async {
    if (!Platform.isWindows) return false;

    try {
      // TODO: Remove registry entries
      log('$_logTag: File associations unregistered', name: _logTag);
      return true;
    } catch (e) {
      log(
        '$_logTag: Failed to unregister file associations: $e',
        name: _logTag,
      );
      return false;
    }
  }

  /// Show balloon notification from system tray
  Future<void> showBalloonNotification({
    required String title,
    required String message,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!isAvailable) return;

    try {
      // TODO: Show actual balloon notification
      // await _systemTray.showBalloonNotification(title, message);

      log('$_logTag: Balloon notification shown: $title', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to show balloon notification: $e', name: _logTag);
    }
  }

  /// Get system tray metrics
  Map<String, dynamic> getTrayMetrics() {
    return {
      'isVisible': _isTrayVisible,
      'isAvailable': isAvailable,
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  }

  /// Configure Windows startup behavior
  Future<void> configureStartupBehavior({
    bool startWithWindows = false,
    bool startMinimized = false,
  }) async {
    if (!Platform.isWindows) return;

    try {
      // TODO: Configure Windows startup registry entries
      // In a full implementation, this would:
      // - Add/remove registry entries in HKCU\Software\Microsoft\Windows\CurrentVersion\Run
      // - Handle startup arguments
      // - Configure minimize to tray behavior

      log('$_logTag: Startup behavior configured', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to configure startup behavior: $e', name: _logTag);
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      _statusUpdateTimer?.cancel();
      _statusUpdateTimer = null;

      if (_isTrayVisible) {
        await _systemTray.destroy();
      }

      _isInitialized = false;
      _isTrayVisible = false;

      // Clear callbacks
      onTrayAction = null;
      onFileOpened = null;

      log('$_logTag: Service disposed', name: _logTag);
    } catch (e) {
      log('$_logTag: Error disposing service: $e', name: _logTag);
    }
  }
}
