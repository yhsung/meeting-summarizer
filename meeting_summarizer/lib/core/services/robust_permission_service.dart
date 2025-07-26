import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;
import 'package:permission_handler/permission_handler.dart';

/// Robust permission service that handles MissingPluginException gracefully
class RobustPermissionService {
  static final RobustPermissionService _instance =
      RobustPermissionService._internal();
  static RobustPermissionService get instance => _instance;
  RobustPermissionService._internal();

  bool _isInitialized = false;
  bool _pluginAvailable = false;

  /// Initialize the permission service and test plugin availability
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Test if permission handler plugin is available
      await _testPluginAvailability();
      _isInitialized = true;
      debugPrint(
        'RobustPermissionService: Initialized successfully, plugin available: $_pluginAvailable',
      );
    } catch (e) {
      debugPrint('RobustPermissionService: Initialization failed: $e');
      _isInitialized = true; // Still mark as initialized
    }
  }

  /// Test if the permission handler plugin is available
  Future<void> _testPluginAvailability() async {
    try {
      if (kIsWeb) {
        _pluginAvailable = false;
        return;
      }

      // Try a simple permission check
      await Permission.microphone.status;
      _pluginAvailable = true;
      debugPrint('RobustPermissionService: Plugin test successful');
    } on MissingPluginException catch (e) {
      debugPrint('RobustPermissionService: Plugin not available - $e');
      _pluginAvailable = false;
    } catch (e) {
      debugPrint('RobustPermissionService: Plugin test failed - $e');
      _pluginAvailable = false;
    }
  }

  /// Check permission status with fallback handling
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (kIsWeb || !_pluginAvailable) {
      // Web platform or plugin not available - return granted for basic functionality
      debugPrint(
        'RobustPermissionService: Fallback to granted for $permission (web: $kIsWeb, plugin: $_pluginAvailable)',
      );
      return PermissionStatus.granted;
    }

    try {
      return await permission.status;
    } on MissingPluginException catch (e) {
      debugPrint(
        'RobustPermissionService: MissingPluginException for $permission: $e',
      );
      _pluginAvailable = false;
      return PermissionStatus.denied;
    } on PlatformException catch (e) {
      debugPrint(
        'RobustPermissionService: PlatformException for $permission: $e',
      );
      return PermissionStatus.denied;
    } catch (e) {
      debugPrint(
        'RobustPermissionService: Unexpected error for $permission: $e',
      );
      return PermissionStatus.denied;
    }
  }

  /// Request permission with fallback handling
  Future<PermissionStatus> requestPermission(Permission permission) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (kIsWeb || !_pluginAvailable) {
      // Web platform or plugin not available - return granted for basic functionality
      debugPrint(
        'RobustPermissionService: Fallback request granted for $permission (web: $kIsWeb, plugin: $_pluginAvailable)',
      );
      return PermissionStatus.granted;
    }

    try {
      return await permission.request();
    } on MissingPluginException catch (e) {
      debugPrint(
        'RobustPermissionService: MissingPluginException requesting $permission: $e',
      );
      _pluginAvailable = false;
      return PermissionStatus.denied;
    } on PlatformException catch (e) {
      debugPrint(
        'RobustPermissionService: PlatformException requesting $permission: $e',
      );
      return PermissionStatus.denied;
    } catch (e) {
      debugPrint(
        'RobustPermissionService: Unexpected error requesting $permission: $e',
      );
      return PermissionStatus.denied;
    }
  }

  /// Request multiple permissions with fallback handling
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (kIsWeb || !_pluginAvailable) {
      // Web platform or plugin not available - return granted for all
      debugPrint(
        'RobustPermissionService: Fallback request granted for all permissions (web: $kIsWeb, plugin: $_pluginAvailable)',
      );
      return {for (var p in permissions) p: PermissionStatus.granted};
    }

    try {
      return await permissions.request();
    } on MissingPluginException catch (e) {
      debugPrint(
        'RobustPermissionService: MissingPluginException requesting permissions: $e',
      );
      _pluginAvailable = false;
      // Fallback: try individual requests
      return await _requestIndividualPermissions(permissions);
    } on PlatformException catch (e) {
      debugPrint(
        'RobustPermissionService: PlatformException requesting permissions: $e',
      );
      return await _requestIndividualPermissions(permissions);
    } catch (e) {
      debugPrint(
        'RobustPermissionService: Unexpected error requesting permissions: $e',
      );
      return await _requestIndividualPermissions(permissions);
    }
  }

  /// Fallback method to request permissions individually
  Future<Map<Permission, PermissionStatus>> _requestIndividualPermissions(
    List<Permission> permissions,
  ) async {
    final results = <Permission, PermissionStatus>{};

    for (final permission in permissions) {
      results[permission] = await requestPermission(permission);
    }

    return results;
  }

  /// Check if permission is granted
  Future<bool> isPermissionGranted(Permission permission) async {
    final status = await checkPermissionStatus(permission);
    return status == PermissionStatus.granted;
  }

  /// Check if permission is permanently denied
  Future<bool> isPermissionPermanentlyDenied(Permission permission) async {
    final status = await checkPermissionStatus(permission);
    return status == PermissionStatus.permanentlyDenied;
  }

  /// Open app settings with fallback handling
  Future<bool> openAppSettings() async {
    if (kIsWeb || !_pluginAvailable) {
      debugPrint(
        'RobustPermissionService: Cannot open app settings (web: $kIsWeb, plugin: $_pluginAvailable)',
      );
      return false;
    }

    try {
      // Import the static method from permission_handler
      final bool result = await permission_handler.openAppSettings();
      return result;
    } catch (e) {
      debugPrint('RobustPermissionService: Error opening app settings: $e');
      return false;
    }
  }

  /// Get a human-readable description for the permission
  String getPermissionDescription(Permission permission) {
    switch (permission) {
      case Permission.microphone:
        return 'Microphone access is required to record audio for transcription.';
      case Permission.storage:
        return 'Storage access is required to save and manage recordings.';
      case Permission.notification:
        return 'Notification permission helps keep you updated on progress.';
      default:
        return 'This permission is required for the app to function properly.';
    }
  }

  /// Check if the service is properly initialized
  bool get isInitialized => _isInitialized;

  /// Check if the plugin is available
  bool get isPluginAvailable => _pluginAvailable;

  /// Force re-test plugin availability (useful after hot restart)
  Future<void> retestPluginAvailability() async {
    await _testPluginAvailability();
    debugPrint(
      'RobustPermissionService: Retested plugin availability: $_pluginAvailable',
    );
  }
}
