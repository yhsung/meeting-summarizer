import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import 'permission_service_interface.dart';

/// Default permission service implementation
class PermissionService implements PermissionServiceInterface {
  static const Duration _defaultMonitoringInterval = Duration(seconds: 5);

  bool _isInitialized = false;
  Timer? _monitoringTimer;

  final StreamController<Map<PermissionType, PermissionState>>
  _permissionStateController =
      StreamController<Map<PermissionType, PermissionState>>.broadcast();

  Map<PermissionType, PermissionState> _currentStates = {};
  Map<PermissionType, int> _requestCounts = {};
  Map<PermissionType, DateTime> _lastRequestTimes = {};
  Map<PermissionType, List<PermissionState>> _requestHistory = {};

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize permission tracking
      _currentStates = {};
      _requestCounts = {};
      _lastRequestTimes = {};
      _requestHistory = {};

      // Start monitoring permission states
      await _startPermissionMonitoring();

      _isInitialized = true;
      debugPrint('PermissionService: Initialized successfully');
    } catch (e) {
      debugPrint('PermissionService: Initialization failed: $e');
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    _monitoringTimer?.cancel();
    await _permissionStateController.close();
    _isInitialized = false;
    debugPrint('PermissionService: Disposed');
  }

  @override
  Future<PermissionState> checkPermission(PermissionType type) async {
    try {
      // For macOS, assume permissions are granted for now
      // This is a workaround since permission_handler doesn't fully support macOS
      if (Platform.isMacOS) {
        debugPrint('PermissionService: macOS detected, assuming $type permission is granted');
        final state = PermissionState.granted;
        _currentStates[type] = state;
        return state;
      }

      final permission = _getPermissionHandler(type);
      final status = await permission.status;
      final state = _mapPermissionStatus(status);

      // Update cached state
      _currentStates[type] = state;

      return state;
    } catch (e) {
      debugPrint('PermissionService: Check permission failed for $type: $e');
      // For macOS, fallback to granted state
      if (Platform.isMacOS) {
        debugPrint('PermissionService: macOS fallback, assuming $type permission is granted');
        final state = PermissionState.granted;
        _currentStates[type] = state;
        return state;
      }
      return PermissionState.unknown;
    }
  }

  @override
  Future<Map<PermissionType, PermissionState>> checkPermissions(
    List<PermissionType> types,
  ) async {
    final results = <PermissionType, PermissionState>{};

    for (final type in types) {
      results[type] = await checkPermission(type);
    }

    return results;
  }

  @override
  Future<PermissionResult> requestPermission(
    PermissionType type, {
    PermissionConfig? config,
  }) async {
    final effectiveConfig = config ?? const PermissionConfig();

    try {
      // Track request attempt
      _trackPermissionRequest(type);

      // For macOS, assume permissions are granted for now
      if (Platform.isMacOS) {
        debugPrint('PermissionService: macOS detected, granting $type permission');
        final state = PermissionState.granted;
        _currentStates[type] = state;
        return PermissionResult.granted();
      }

      // Check current state first
      final currentState = await checkPermission(type);
      if (currentState == PermissionState.granted) {
        return PermissionResult.granted();
      }

      // Handle permanently denied case
      if (currentState == PermissionState.permanentlyDenied) {
        return await _handlePermanentlyDenied(type, effectiveConfig);
      }

      // Show rationale if needed
      if (effectiveConfig.showRationale && await shouldShowRationale(type)) {
        final shouldProceed = await _showRationale(type, effectiveConfig);
        if (!shouldProceed) {
          return PermissionResult.denied(
            errorMessage: 'User declined permission rationale',
          );
        }
      }

      // Request permission with retry mechanism
      return await _requestWithRetry(type, effectiveConfig);
    } catch (e) {
      debugPrint('PermissionService: Request permission failed for $type: $e');
      return PermissionResult.error('Permission request failed: $e');
    }
  }

  @override
  Future<Map<PermissionType, PermissionResult>> requestPermissions(
    List<PermissionType> types, {
    PermissionConfig? config,
  }) async {
    final results = <PermissionType, PermissionResult>{};

    // Request permissions sequentially to avoid conflicts
    for (final type in types) {
      results[type] = await requestPermission(type, config: config);
    }

    return results;
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      return await ph.openAppSettings();
    } catch (e) {
      debugPrint('PermissionService: Open app settings failed: $e');
      return false;
    }
  }

  @override
  Future<bool> shouldShowRationale(PermissionType type) async {
    try {
      final permission = _getPermissionHandler(type);

      // Platform-specific rationale logic
      if (Platform.isAndroid) {
        return await permission.shouldShowRequestRationale;
      } else if (Platform.isIOS) {
        // iOS doesn't have shouldShowRequestRationale
        // Check if permission was previously denied
        final status = await permission.status;
        return status == ph.PermissionStatus.denied &&
            _wasRequestedBefore(type);
      }

      return false;
    } catch (e) {
      debugPrint(
        'PermissionService: Should show rationale check failed for $type: $e',
      );
      return false;
    }
  }

  @override
  Stream<Map<PermissionType, PermissionState>> get permissionStateStream =>
      _permissionStateController.stream;

  @override
  Map<String, dynamic> getPlatformPermissionInfo(PermissionType type) {
    final permission = _getPermissionHandler(type);

    return {
      'permissionType': type.toString(),
      'platformPermission': permission.toString(),
      'platform': Platform.operatingSystem,
      'isSupported': _isPermissionSupported(type),
      'requiresSpecialHandling': _requiresSpecialHandling(type),
      'settingsKey': _getSettingsKey(type),
    };
  }

  @override
  Future<bool> hasRequiredPermissions() async {
    final requiredPermissions = _getRequiredPermissions();
    final states = await checkPermissions(requiredPermissions);

    return states.values.every((state) => state == PermissionState.granted);
  }

  @override
  Future<List<PermissionType>> getMissingRequiredPermissions() async {
    final requiredPermissions = _getRequiredPermissions();
    final states = await checkPermissions(requiredPermissions);

    return states.entries
        .where((entry) => entry.value != PermissionState.granted)
        .map((entry) => entry.key)
        .toList();
  }

  @override
  void resetPermissionTracking() {
    _requestCounts.clear();
    _lastRequestTimes.clear();
    _requestHistory.clear();
    _currentStates.clear();
    debugPrint('PermissionService: Permission tracking reset');
  }

  @override
  Map<String, dynamic> getPermissionAnalytics() {
    return {
      'requestCounts': _requestCounts.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'lastRequestTimes': _lastRequestTimes.map(
        (key, value) => MapEntry(key.toString(), value.toIso8601String()),
      ),
      'currentStates': _currentStates.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      'requestHistory': _requestHistory.map(
        (key, value) =>
            MapEntry(key.toString(), value.map((s) => s.toString()).toList()),
      ),
      'totalRequests': _requestCounts.values.fold(
        0,
        (sum, count) => sum + count,
      ),
      'successRate': _calculateSuccessRate(),
    };
  }

  // Private helper methods

  ph.Permission _getPermissionHandler(PermissionType type) {
    switch (type) {
      case PermissionType.microphone:
        return ph.Permission.microphone;
      case PermissionType.storage:
        return Platform.isAndroid
            ? ph.Permission.storage
            : ph.Permission.photos;
      case PermissionType.notification:
        return ph.Permission.notification;
      case PermissionType.backgroundRefresh:
        return ph.Permission.backgroundRefresh;
      case PermissionType.phone:
        return ph.Permission.phone;
    }
  }

  PermissionState _mapPermissionStatus(ph.PermissionStatus status) {
    switch (status) {
      case ph.PermissionStatus.granted:
        return PermissionState.granted;
      case ph.PermissionStatus.denied:
        return PermissionState.denied;
      case ph.PermissionStatus.permanentlyDenied:
        return PermissionState.permanentlyDenied;
      case ph.PermissionStatus.restricted:
        return PermissionState.restricted;
      case ph.PermissionStatus.limited:
        return PermissionState.limited;
      case ph.PermissionStatus.provisional:
        return PermissionState.granted; // Treat provisional as granted
    }
  }

  void _trackPermissionRequest(PermissionType type) {
    _requestCounts[type] = (_requestCounts[type] ?? 0) + 1;
    _lastRequestTimes[type] = DateTime.now();

    // Track in history
    if (!_requestHistory.containsKey(type)) {
      _requestHistory[type] = [];
    }
  }

  bool _wasRequestedBefore(PermissionType type) {
    return _requestCounts.containsKey(type) && _requestCounts[type]! > 0;
  }

  Future<PermissionResult> _handlePermanentlyDenied(
    PermissionType type,
    PermissionConfig config,
  ) async {
    if (config.autoRedirectToSettings) {
      final success = await _showSettingsRedirectDialog(type, config);
      return PermissionResult.permanentlyDenied(
        wasRedirectedToSettings: success,
        errorMessage: success ? null : 'Failed to open settings',
      );
    }

    return PermissionResult.permanentlyDenied(
      errorMessage: 'Permission permanently denied',
    );
  }

  Future<bool> _showRationale(
    PermissionType type,
    PermissionConfig config,
  ) async {
    // In a real implementation, this would show a dialog to the user
    // For now, we'll return true to proceed with the request
    debugPrint('PermissionService: Would show rationale for $type');
    return true;
  }

  Future<bool> _showSettingsRedirectDialog(
    PermissionType type,
    PermissionConfig config,
  ) async {
    // In a real implementation, this would show a dialog and potentially open settings
    // For now, we'll try to open settings directly
    debugPrint(
      'PermissionService: Would show settings redirect dialog for $type',
    );
    return await openAppSettings();
  }

  Future<PermissionResult> _requestWithRetry(
    PermissionType type,
    PermissionConfig config,
  ) async {
    int attempts = 0;

    while (attempts < config.maxRetryAttempts) {
      try {
        final permission = _getPermissionHandler(type);
        final status = await permission.request();
        final state = _mapPermissionStatus(status);

        // Update tracking
        _requestHistory[type]?.add(state);
        _currentStates[type] = state;

        if (state == PermissionState.granted) {
          return PermissionResult.granted(metadata: {'attempts': attempts + 1});
        } else if (state == PermissionState.permanentlyDenied) {
          return await _handlePermanentlyDenied(type, config);
        }

        // If denied and retries are enabled, wait and try again
        if (config.enableRetry && attempts < config.maxRetryAttempts - 1) {
          await Future.delayed(config.retryDelay);
          attempts++;
          continue;
        }

        return PermissionResult.denied(
          errorMessage: 'Permission denied after ${attempts + 1} attempts',
          metadata: {'attempts': attempts + 1},
        );
      } catch (e) {
        if (attempts < config.maxRetryAttempts - 1) {
          await Future.delayed(config.retryDelay);
          attempts++;
          continue;
        }

        return PermissionResult.error(
          'Permission request failed: $e',
          metadata: {'attempts': attempts + 1},
        );
      }
    }

    return PermissionResult.error('Max retry attempts exceeded');
  }

  List<PermissionType> _getRequiredPermissions() {
    return [
      PermissionType.microphone,
      // Add other required permissions based on app functionality
    ];
  }

  bool _isPermissionSupported(PermissionType type) {
    switch (type) {
      case PermissionType.microphone:
        return true;
      case PermissionType.storage:
        return true;
      case PermissionType.notification:
        return true;
      case PermissionType.backgroundRefresh:
        return Platform.isIOS;
      case PermissionType.phone:
        return Platform.isAndroid;
    }
  }

  bool _requiresSpecialHandling(PermissionType type) {
    switch (type) {
      case PermissionType.backgroundRefresh:
        return Platform.isIOS;
      case PermissionType.phone:
        return Platform.isAndroid;
      default:
        return false;
    }
  }

  String _getSettingsKey(PermissionType type) {
    // Platform-specific settings keys for deep linking to specific permission settings
    if (Platform.isIOS) {
      switch (type) {
        case PermissionType.microphone:
          return 'Privacy & Security > Microphone';
        case PermissionType.storage:
          return 'Privacy & Security > Photos';
        case PermissionType.notification:
          return 'Notifications';
        default:
          return 'Privacy & Security';
      }
    } else if (Platform.isAndroid) {
      switch (type) {
        case PermissionType.microphone:
          return 'App permissions > Microphone';
        case PermissionType.storage:
          return 'App permissions > Storage';
        case PermissionType.notification:
          return 'App notifications';
        default:
          return 'App permissions';
      }
    }

    return 'App Settings';
  }

  Future<void> _startPermissionMonitoring() async {
    _monitoringTimer = Timer.periodic(_defaultMonitoringInterval, (
      timer,
    ) async {
      if (!_isInitialized) {
        timer.cancel();
        return;
      }

      try {
        final requiredPermissions = _getRequiredPermissions();
        final newStates = await checkPermissions(requiredPermissions);

        // Check if any states have changed
        bool hasChanges = false;
        for (final entry in newStates.entries) {
          if (_currentStates[entry.key] != entry.value) {
            hasChanges = true;
            break;
          }
        }

        if (hasChanges) {
          _currentStates.addAll(newStates);
          _permissionStateController.add(Map.from(_currentStates));
        }
      } catch (e) {
        debugPrint('PermissionService: Monitoring error: $e');
      }
    });
  }

  double _calculateSuccessRate() {
    if (_requestHistory.isEmpty) return 0.0;

    int totalRequests = 0;
    int successfulRequests = 0;

    for (final history in _requestHistory.values) {
      totalRequests += history.length;
      successfulRequests += history
          .where((state) => state == PermissionState.granted)
          .length;
    }

    return totalRequests > 0 ? (successfulRequests / totalRequests) * 100 : 0.0;
  }
}
