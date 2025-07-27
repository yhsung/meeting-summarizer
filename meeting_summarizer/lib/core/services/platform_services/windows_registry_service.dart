/// Windows Registry Integration Service
///
/// Handles Windows Registry operations for file associations,
/// startup configuration, and application settings.
library;

import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Registry hive types
enum RegistryHive {
  classesRoot('HKEY_CLASSES_ROOT'),
  currentUser('HKEY_CURRENT_USER'),
  localMachine('HKEY_LOCAL_MACHINE'),
  users('HKEY_USERS'),
  currentConfig('HKEY_CURRENT_CONFIG');

  const RegistryHive(this.identifier);
  final String identifier;
}

/// File association configuration
class FileAssociation {
  final String extension;
  final String progId;
  final String description;
  final String iconPath;
  final String commandLine;
  final List<String> contextMenuActions;

  const FileAssociation({
    required this.extension,
    required this.progId,
    required this.description,
    required this.iconPath,
    required this.commandLine,
    this.contextMenuActions = const [],
  });

  Map<String, dynamic> toJson() => {
        'extension': extension,
        'progId': progId,
        'description': description,
        'iconPath': iconPath,
        'commandLine': commandLine,
        'contextMenuActions': contextMenuActions,
      };
}

/// Windows Registry Service
class WindowsRegistryService {
  static const String _logTag = 'WindowsRegistryService';
  static const String _channelName =
      'com.yhsung.meeting_summarizer/windows_registry';

  // Platform channel for native Windows registry operations
  static const MethodChannel _platform = MethodChannel(_channelName);

  bool _isInitialized = false;
  bool _hasRegistryAccess = false;
  final List<FileAssociation> _registeredAssociations = [];

  /// Initialize Windows registry service
  Future<bool> initialize() async {
    try {
      if (!Platform.isWindows) {
        log('$_logTag: Registry service only available on Windows',
            name: _logTag);
        return false;
      }

      // Initialize platform channel
      await _initializePlatformChannel();

      // Check registry access permissions
      _hasRegistryAccess = await _checkRegistryAccess();

      if (_hasRegistryAccess) {
        _isInitialized = true;
        log('$_logTag: Windows registry service initialized', name: _logTag);
        return true;
      } else {
        log('$_logTag: Insufficient permissions for registry access',
            name: _logTag);
        return false;
      }
    } catch (e) {
      log('$_logTag: Failed to initialize Windows registry service: $e',
          name: _logTag);
      return false;
    }
  }

  /// Check if service is available
  bool get isAvailable => Platform.isWindows && _isInitialized;
  bool get hasRegistryAccess => _hasRegistryAccess;

  /// Initialize platform channel
  Future<void> _initializePlatformChannel() async {
    try {
      _platform.setMethodCallHandler(_handleNativeMethodCall);

      // Test connectivity
      final result = await _platform.invokeMethod<bool>('initialize') ?? false;
      if (!result) {
        log('$_logTag: Failed to initialize native registry channel',
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
        case 'onRegistryChange':
          final keyPath = call.arguments['keyPath'] as String?;
          final valueName = call.arguments['valueName'] as String?;

          if (keyPath != null) {
            log('$_logTag: Registry change detected: $keyPath/$valueName',
                name: _logTag);
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

  /// Check if registry access is available
  Future<bool> _checkRegistryAccess() async {
    try {
      final result = await _platform.invokeMethod<bool>('checkAccess') ?? false;
      log('$_logTag: Registry access: $result', name: _logTag);
      return result;
    } catch (e) {
      log('$_logTag: Failed to check registry access: $e', name: _logTag);
      return false;
    }
  }

  /// Register file association
  Future<bool> registerFileAssociation(FileAssociation association) async {
    if (!isAvailable) return false;

    try {
      final result = await _platform.invokeMethod<bool>(
            'registerFileAssociation',
            association.toJson(),
          ) ??
          false;

      if (result) {
        _registeredAssociations.add(association);
        log('$_logTag: File association registered: ${association.extension}',
            name: _logTag);
      }

      return result;
    } catch (e) {
      log('$_logTag: Failed to register file association: $e', name: _logTag);
      return false;
    }
  }

  /// Unregister file association
  Future<bool> unregisterFileAssociation(String extension) async {
    if (!isAvailable) return false;

    try {
      final result = await _platform.invokeMethod<bool>(
            'unregisterFileAssociation',
            {'extension': extension},
          ) ??
          false;

      if (result) {
        _registeredAssociations
            .removeWhere((assoc) => assoc.extension == extension);
        log('$_logTag: File association unregistered: $extension',
            name: _logTag);
      }

      return result;
    } catch (e) {
      log('$_logTag: Failed to unregister file association: $e', name: _logTag);
      return false;
    }
  }

  /// Register all default file associations
  Future<void> registerDefaultAssociations() async {
    if (!isAvailable) return;

    try {
      final associations = [
        FileAssociation(
          extension: '.ms-recording',
          progId: 'MeetingSummarizer.Recording',
          description: 'Meeting Summarizer Recording',
          iconPath: 'assets/icons/recording_file.ico',
          commandLine: '"{{AppPath}}" --open-recording "{{FilePath}}"',
          contextMenuActions: ['Open', 'Transcribe', 'Generate Summary'],
        ),
        FileAssociation(
          extension: '.ms-transcript',
          progId: 'MeetingSummarizer.Transcript',
          description: 'Meeting Summarizer Transcript',
          iconPath: 'assets/icons/transcript_file.ico',
          commandLine: '"{{AppPath}}" --open-transcript "{{FilePath}}"',
          contextMenuActions: ['Open', 'Edit', 'Generate Summary'],
        ),
      ];

      for (final association in associations) {
        await registerFileAssociation(association);
      }
    } catch (e) {
      log('$_logTag: Failed to register default associations: $e',
          name: _logTag);
    }
  }

  /// Configure application startup
  Future<bool> configureStartup({
    required bool startWithWindows,
    bool startMinimized = false,
    List<String>? arguments,
  }) async {
    if (!isAvailable) return false;

    try {
      final result = await _platform.invokeMethod<bool>(
            'configureStartup',
            {
              'startWithWindows': startWithWindows,
              'startMinimized': startMinimized,
              'arguments': arguments ?? [],
            },
          ) ??
          false;

      log('$_logTag: Startup configuration updated: $startWithWindows',
          name: _logTag);
      return result;
    } catch (e) {
      log('$_logTag: Failed to configure startup: $e', name: _logTag);
      return false;
    }
  }

  /// Check if application is set to start with Windows
  Future<bool> isStartupEnabled() async {
    if (!isAvailable) return false;

    try {
      final result =
          await _platform.invokeMethod<bool>('isStartupEnabled') ?? false;
      return result;
    } catch (e) {
      log('$_logTag: Failed to check startup status: $e', name: _logTag);
      return false;
    }
  }

  /// Set registry value
  Future<bool> setValue({
    required RegistryHive hive,
    required String keyPath,
    required String valueName,
    required dynamic value,
  }) async {
    if (!isAvailable) return false;

    try {
      final result = await _platform.invokeMethod<bool>(
            'setValue',
            {
              'hive': hive.identifier,
              'keyPath': keyPath,
              'valueName': valueName,
              'value': value,
            },
          ) ??
          false;

      log('$_logTag: Registry value set: ${hive.identifier}\\$keyPath\\$valueName',
          name: _logTag);
      return result;
    } catch (e) {
      log('$_logTag: Failed to set registry value: $e', name: _logTag);
      return false;
    }
  }

  /// Get registry value
  Future<dynamic> getValue({
    required RegistryHive hive,
    required String keyPath,
    required String valueName,
  }) async {
    if (!isAvailable) return null;

    try {
      final result = await _platform.invokeMethod(
        'getValue',
        {
          'hive': hive.identifier,
          'keyPath': keyPath,
          'valueName': valueName,
        },
      );

      return result;
    } catch (e) {
      log('$_logTag: Failed to get registry value: $e', name: _logTag);
      return null;
    }
  }

  /// Delete registry value
  Future<bool> deleteValue({
    required RegistryHive hive,
    required String keyPath,
    required String valueName,
  }) async {
    if (!isAvailable) return false;

    try {
      final result = await _platform.invokeMethod<bool>(
            'deleteValue',
            {
              'hive': hive.identifier,
              'keyPath': keyPath,
              'valueName': valueName,
            },
          ) ??
          false;

      log('$_logTag: Registry value deleted: ${hive.identifier}\\$keyPath\\$valueName',
          name: _logTag);
      return result;
    } catch (e) {
      log('$_logTag: Failed to delete registry value: $e', name: _logTag);
      return false;
    }
  }

  /// Create registry key
  Future<bool> createKey({
    required RegistryHive hive,
    required String keyPath,
  }) async {
    if (!isAvailable) return false;

    try {
      final result = await _platform.invokeMethod<bool>(
            'createKey',
            {
              'hive': hive.identifier,
              'keyPath': keyPath,
            },
          ) ??
          false;

      log('$_logTag: Registry key created: ${hive.identifier}\\$keyPath',
          name: _logTag);
      return result;
    } catch (e) {
      log('$_logTag: Failed to create registry key: $e', name: _logTag);
      return false;
    }
  }

  /// Delete registry key
  Future<bool> deleteKey({
    required RegistryHive hive,
    required String keyPath,
    bool recursive = false,
  }) async {
    if (!isAvailable) return false;

    try {
      final result = await _platform.invokeMethod<bool>(
            'deleteKey',
            {
              'hive': hive.identifier,
              'keyPath': keyPath,
              'recursive': recursive,
            },
          ) ??
          false;

      log('$_logTag: Registry key deleted: ${hive.identifier}\\$keyPath',
          name: _logTag);
      return result;
    } catch (e) {
      log('$_logTag: Failed to delete registry key: $e', name: _logTag);
      return false;
    }
  }

  /// Get registered file associations
  List<FileAssociation> get registeredAssociations =>
      List.unmodifiable(_registeredAssociations);

  /// Get service status
  Map<String, dynamic> getServiceStatus() {
    return {
      'isAvailable': isAvailable,
      'hasRegistryAccess': hasRegistryAccess,
      'registeredAssociationsCount': _registeredAssociations.length,
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  }

  /// Dispose resources
  void dispose() {
    try {
      _registeredAssociations.clear();
      _isInitialized = false;
      log('$_logTag: Service disposed', name: _logTag);
    } catch (e) {
      log('$_logTag: Error disposing service: $e', name: _logTag);
    }
  }
}
