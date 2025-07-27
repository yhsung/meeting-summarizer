/// Windows Jump Lists Service
///
/// Provides integration with Windows taskbar jump lists for quick access
/// to recording functions and recent recordings.
library;

import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Jump list task item
class JumplistTask {
  final String id;
  final String title;
  final String description;
  final String? iconPath;
  final String arguments;
  final String? workingDirectory;

  const JumplistTask({
    required this.id,
    required this.title,
    required this.description,
    required this.arguments,
    this.iconPath,
    this.workingDirectory,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'iconPath': iconPath,
        'arguments': arguments,
        'workingDirectory': workingDirectory,
      };
}

/// Jump list recent item
class JumplistRecentItem {
  final String filePath;
  final String title;
  final String? arguments;
  final String? iconPath;

  const JumplistRecentItem({
    required this.filePath,
    required this.title,
    this.arguments,
    this.iconPath,
  });

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'title': title,
        'arguments': arguments,
        'iconPath': iconPath,
      };
}

/// Jump list category
class JumplistCategory {
  final String name;
  final List<JumplistTask> tasks;
  final bool visible;

  const JumplistCategory({
    required this.name,
    required this.tasks,
    this.visible = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'tasks': tasks.map((task) => task.toJson()).toList(),
        'visible': visible,
      };
}

/// Jump list types
enum JumplistType {
  task('task'),
  recent('recent'),
  frequent('frequent'),
  custom('custom');

  const JumplistType(this.identifier);
  final String identifier;
}

/// Windows Jump Lists Service
class WindowsJumplistService {
  static const String _logTag = 'WindowsJumplistService';
  static const String _channelName =
      'com.yhsung.meeting_summarizer/windows_jumplist';

  // Platform channel for native Windows jump list integration
  static const MethodChannel _platform = MethodChannel(_channelName);

  bool _isInitialized = false;
  bool _jumplistSupported = false;
  List<JumplistTask> _currentTasks = [];
  List<JumplistRecentItem> _recentItems = [];

  // Callbacks
  void Function(String action, Map<String, dynamic>? parameters)?
      onJumplistAction;

  /// Initialize Windows jump list service
  Future<bool> initialize() async {
    try {
      if (!Platform.isWindows) {
        log('$_logTag: Jump lists only available on Windows', name: _logTag);
        return false;
      }

      // Initialize platform channel
      await _initializePlatformChannel();

      // Check if jump lists are supported
      _jumplistSupported = await _checkJumplistSupport();

      if (_jumplistSupported) {
        // Initialize jump list with default structure
        await _initializeDefaultJumplist();

        _isInitialized = true;
        log('$_logTag: Windows jump list service initialized', name: _logTag);
        return true;
      } else {
        log('$_logTag: Jump lists not supported on this system', name: _logTag);
        return false;
      }
    } catch (e) {
      log('$_logTag: Failed to initialize Windows jump lists: $e',
          name: _logTag);
      return false;
    }
  }

  /// Check if service is available
  bool get isAvailable => Platform.isWindows && _isInitialized;
  bool get isSupported => _jumplistSupported;

  /// Initialize platform channel
  Future<void> _initializePlatformChannel() async {
    try {
      _platform.setMethodCallHandler(_handleNativeMethodCall);

      // Test connectivity
      final result = await _platform.invokeMethod<bool>('initialize') ?? false;
      if (!result) {
        log('$_logTag: Failed to initialize native jump list channel',
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
        case 'onJumplistAction':
          final action = call.arguments['action'] as String?;
          final parameters =
              call.arguments['parameters'] as Map<String, dynamic>?;

          if (action != null) {
            log('$_logTag: Jump list action triggered: $action', name: _logTag);
            onJumplistAction?.call(action, parameters);
          }
          break;

        case 'onRecentItemOpened':
          final filePath = call.arguments['filePath'] as String?;
          if (filePath != null) {
            log('$_logTag: Recent item opened: $filePath', name: _logTag);
            onJumplistAction?.call('open_recent', {'filePath': filePath});
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

  /// Check if jump lists are supported
  Future<bool> _checkJumplistSupport() async {
    try {
      final result =
          await _platform.invokeMethod<bool>('checkSupport') ?? false;
      log('$_logTag: Jump list support: $result', name: _logTag);
      return result;
    } catch (e) {
      log('$_logTag: Failed to check jump list support: $e', name: _logTag);
      return false;
    }
  }

  /// Initialize default jump list structure
  Future<void> _initializeDefaultJumplist() async {
    try {
      // Set up default tasks
      final defaultTasks = [
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
      ];

      await updateJumplist(tasks: defaultTasks, recentItems: []);
    } catch (e) {
      log('$_logTag: Failed to initialize default jump list: $e',
          name: _logTag);
    }
  }

  /// Update jump list with new tasks and recent items
  Future<void> updateJumplist({
    List<JumplistTask>? tasks,
    List<JumplistRecentItem>? recentItems,
    List<JumplistCategory>? categories,
    bool clearExisting = false,
  }) async {
    if (!isAvailable) return;

    try {
      if (clearExisting) {
        await _clearJumplist();
      }

      // Update tasks
      if (tasks != null) {
        await _updateTasks(tasks);
        _currentTasks = tasks;
      }

      // Update recent items
      if (recentItems != null) {
        await _updateRecentItems(recentItems);
        _recentItems = recentItems;
      }

      // Update custom categories
      if (categories != null) {
        await _updateCategories(categories);
      }

      // Commit changes
      await _commitJumplist();

      log('$_logTag: Jump list updated successfully', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to update jump list: $e', name: _logTag);
    }
  }

  /// Update jump list tasks
  Future<void> _updateTasks(List<JumplistTask> tasks) async {
    try {
      final tasksJson = tasks.map((task) => task.toJson()).toList();
      await _platform.invokeMethod('updateTasks', {'tasks': tasksJson});
    } catch (e) {
      log('$_logTag: Failed to update tasks: $e', name: _logTag);
    }
  }

  /// Update recent items
  Future<void> _updateRecentItems(List<JumplistRecentItem> items) async {
    try {
      final itemsJson = items.map((item) => item.toJson()).toList();
      await _platform.invokeMethod('updateRecentItems', {'items': itemsJson});
    } catch (e) {
      log('$_logTag: Failed to update recent items: $e', name: _logTag);
    }
  }

  /// Update custom categories
  Future<void> _updateCategories(List<JumplistCategory> categories) async {
    try {
      final categoriesJson = categories.map((cat) => cat.toJson()).toList();
      await _platform
          .invokeMethod('updateCategories', {'categories': categoriesJson});
    } catch (e) {
      log('$_logTag: Failed to update categories: $e', name: _logTag);
    }
  }

  /// Clear jump list
  Future<void> _clearJumplist() async {
    try {
      await _platform.invokeMethod('clearJumplist');
      _currentTasks.clear();
      _recentItems.clear();
    } catch (e) {
      log('$_logTag: Failed to clear jump list: $e', name: _logTag);
    }
  }

  /// Commit jump list changes
  Future<void> _commitJumplist() async {
    try {
      await _platform.invokeMethod('commitChanges');
    } catch (e) {
      log('$_logTag: Failed to commit jump list changes: $e', name: _logTag);
    }
  }

  /// Add recording to recent items
  Future<void> addRecentRecording({
    required String recordingPath,
    required String title,
    String? arguments,
  }) async {
    if (!isAvailable) return;

    try {
      final recentItem = JumplistRecentItem(
        filePath: recordingPath,
        title: title,
        arguments: arguments ?? '--open-recording=$recordingPath',
        iconPath: 'assets/icons/audio_file.ico',
      );

      // Add to beginning of list and limit to 10 items
      _recentItems.insert(0, recentItem);
      if (_recentItems.length > 10) {
        _recentItems = _recentItems.take(10).toList();
      }

      await updateRecentItems(_recentItems);
      log('$_logTag: Added recent recording: $title', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to add recent recording: $e', name: _logTag);
    }
  }

  /// Remove recording from recent items
  Future<void> removeRecentRecording(String recordingPath) async {
    if (!isAvailable) return;

    try {
      _recentItems.removeWhere((item) => item.filePath == recordingPath);
      await updateRecentItems(_recentItems);
      log('$_logTag: Removed recent recording: $recordingPath', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to remove recent recording: $e', name: _logTag);
    }
  }

  /// Update recent items only
  Future<void> updateRecentItems(List<JumplistRecentItem> items) async {
    if (!isAvailable) return;

    try {
      await _updateRecentItems(items);
      await _commitJumplist();
      _recentItems = items;
    } catch (e) {
      log('$_logTag: Failed to update recent items: $e', name: _logTag);
    }
  }

  /// Update recording state in jump list
  Future<void> updateRecordingState({
    required bool isRecording,
    bool isPaused = false,
  }) async {
    if (!isAvailable) return;

    try {
      final tasks = <JumplistTask>[];

      if (isRecording) {
        if (isPaused) {
          tasks.addAll([
            JumplistTask(
              id: 'resume_recording',
              title: 'Resume Recording',
              description: 'Resume the paused recording',
              iconPath: 'assets/icons/resume_recording.ico',
              arguments: '--action=resume_recording',
            ),
            JumplistTask(
              id: 'stop_recording',
              title: 'Stop Recording',
              description: 'Stop the current recording',
              iconPath: 'assets/icons/stop_recording.ico',
              arguments: '--action=stop_recording',
            ),
          ]);
        } else {
          tasks.addAll([
            JumplistTask(
              id: 'pause_recording',
              title: 'Pause Recording',
              description: 'Pause the current recording',
              iconPath: 'assets/icons/pause_recording.ico',
              arguments: '--action=pause_recording',
            ),
            JumplistTask(
              id: 'stop_recording',
              title: 'Stop Recording',
              description: 'Stop the current recording',
              iconPath: 'assets/icons/stop_recording.ico',
              arguments: '--action=stop_recording',
            ),
          ]);
        }
      } else {
        tasks.addAll([
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
        ]);
      }

      await updateJumplist(tasks: tasks);
    } catch (e) {
      log('$_logTag: Failed to update recording state: $e', name: _logTag);
    }
  }

  /// Create category for recording controls
  Future<void> createRecordingCategory({
    required bool isRecording,
    bool isPaused = false,
  }) async {
    if (!isAvailable) return;

    try {
      final categoryTasks = <JumplistTask>[];

      if (isRecording) {
        if (!isPaused) {
          categoryTasks.add(JumplistTask(
            id: 'pause_recording',
            title: 'Pause Recording',
            description: 'Pause the current recording',
            iconPath: 'assets/icons/pause_recording.ico',
            arguments: '--action=pause_recording',
          ));
        } else {
          categoryTasks.add(JumplistTask(
            id: 'resume_recording',
            title: 'Resume Recording',
            description: 'Resume the paused recording',
            iconPath: 'assets/icons/resume_recording.ico',
            arguments: '--action=resume_recording',
          ));
        }
        categoryTasks.add(JumplistTask(
          id: 'stop_recording',
          title: 'Stop Recording',
          description: 'Stop the current recording',
          iconPath: 'assets/icons/stop_recording.ico',
          arguments: '--action=stop_recording',
        ));
      } else {
        categoryTasks.add(JumplistTask(
          id: 'start_recording',
          title: 'Start Recording',
          description: 'Start a new meeting recording',
          iconPath: 'assets/icons/start_recording.ico',
          arguments: '--action=start_recording',
        ));
      }

      final recordingCategory = JumplistCategory(
        name: 'Recording Controls',
        tasks: categoryTasks,
      );

      final quickActionsCategory = JumplistCategory(
        name: 'Quick Actions',
        tasks: [
          JumplistTask(
            id: 'view_recordings',
            title: 'View Recordings',
            description: 'View recent recordings',
            iconPath: 'assets/icons/view_recordings.ico',
            arguments: '--action=view_recordings',
          ),
          JumplistTask(
            id: 'settings',
            title: 'Settings',
            description: 'Open application settings',
            iconPath: 'assets/icons/settings.ico',
            arguments: '--action=settings',
          ),
        ],
      );

      await updateJumplist(
          categories: [recordingCategory, quickActionsCategory]);
    } catch (e) {
      log('$_logTag: Failed to create recording category: $e', name: _logTag);
    }
  }

  /// Get current jump list state
  Map<String, dynamic> getJumplistState() {
    return {
      'isAvailable': isAvailable,
      'isSupported': isSupported,
      'tasksCount': _currentTasks.length,
      'recentItemsCount': _recentItems.length,
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  }

  /// Get current tasks
  List<JumplistTask> get currentTasks => List.unmodifiable(_currentTasks);

  /// Get current recent items
  List<JumplistRecentItem> get recentItems => List.unmodifiable(_recentItems);

  /// Dispose resources
  void dispose() {
    try {
      // Clear callbacks
      onJumplistAction = null;

      // Clear jump list data
      _currentTasks.clear();
      _recentItems.clear();

      _isInitialized = false;
      log('$_logTag: Service disposed', name: _logTag);
    } catch (e) {
      log('$_logTag: Error disposing service: $e', name: _logTag);
    }
  }
}
