import 'dart:async';

import 'package:meeting_summarizer/core/services/permission_service_interface.dart';

/// Mock implementation of PermissionServiceInterface for testing
class MockPermissionService implements PermissionServiceInterface {
  bool _isInitialized = false;
  final Map<PermissionType, PermissionState> _mockStates = {};
  final Map<PermissionType, int> _requestCounts = {};
  final StreamController<Map<PermissionType, PermissionState>> _controller =
      StreamController<Map<PermissionType, PermissionState>>.broadcast();

  /// Configure mock responses for testing
  void setMockPermissionState(PermissionType type, PermissionState state) {
    _mockStates[type] = state;
  }

  /// Simulate permission state change
  void simulatePermissionChange(PermissionType type, PermissionState newState) {
    _mockStates[type] = newState;
    _controller.add(Map.from(_mockStates));
  }

  @override
  Future<void> initialize() async {
    _isInitialized = true;
    // Set default states
    _mockStates[PermissionType.microphone] = PermissionState.denied;
    _mockStates[PermissionType.storage] = PermissionState.granted;
    _mockStates[PermissionType.notification] = PermissionState.unknown;
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    await _controller.close();
  }

  @override
  Future<PermissionState> checkPermission(PermissionType type) async {
    if (!_isInitialized) throw StateError('Service not initialized');
    return _mockStates[type] ?? PermissionState.unknown;
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
    if (!_isInitialized) throw StateError('Service not initialized');

    _requestCounts[type] = (_requestCounts[type] ?? 0) + 1;

    final currentState = _mockStates[type] ?? PermissionState.unknown;

    // Simulate different scenarios based on current state
    switch (currentState) {
      case PermissionState.granted:
        return PermissionResult.granted();
      case PermissionState.denied:
        // Simulate granting permission on request
        _mockStates[type] = PermissionState.granted;
        _controller.add(Map.from(_mockStates));
        return PermissionResult.granted();
      case PermissionState.permanentlyDenied:
        // Simulate opening settings for permanently denied permissions
        if (config?.autoRedirectToSettings == true) {
          return PermissionResult.permanentlyDenied(
            errorMessage: 'Permission permanently denied in settings',
            wasRedirectedToSettings: true,
          );
        }
        return PermissionResult.permanentlyDenied(
          errorMessage: 'Permission permanently denied in settings',
        );
      case PermissionState.restricted:
        return PermissionResult.denied(
          errorMessage: 'Permission restricted by device policy',
        );
      default:
        return PermissionResult.error('Unknown permission state');
    }
  }

  @override
  Future<Map<PermissionType, PermissionResult>> requestPermissions(
    List<PermissionType> types, {
    PermissionConfig? config,
  }) async {
    final results = <PermissionType, PermissionResult>{};
    for (final type in types) {
      results[type] = await requestPermission(type, config: config);
    }
    return results;
  }

  @override
  Future<bool> openAppSettings() async {
    // Simulate successful settings opening
    return true;
  }

  @override
  Future<bool> shouldShowRationale(PermissionType type) async {
    // Simulate rationale logic
    return _requestCounts[type] != null && _requestCounts[type]! > 0;
  }

  @override
  Stream<Map<PermissionType, PermissionState>> get permissionStateStream =>
      _controller.stream;

  @override
  Map<String, dynamic> getPlatformPermissionInfo(PermissionType type) {
    return {
      'permissionType': type.toString(),
      'platform': 'mock',
      'isSupported': true,
      'settingsKey': 'Mock Settings',
    };
  }

  @override
  Future<bool> hasRequiredPermissions() async {
    final requiredPermissions = [PermissionType.microphone];
    final states = await checkPermissions(requiredPermissions);
    return states.values.every((state) => state == PermissionState.granted);
  }

  @override
  Future<List<PermissionType>> getMissingRequiredPermissions() async {
    final requiredPermissions = [PermissionType.microphone];
    final states = await checkPermissions(requiredPermissions);
    return states.entries
        .where((entry) => entry.value != PermissionState.granted)
        .map((entry) => entry.key)
        .toList();
  }

  @override
  void resetPermissionTracking() {
    _requestCounts.clear();
    _mockStates.clear();
  }

  @override
  Map<String, dynamic> getPermissionAnalytics() {
    return {
      'requestCounts': _requestCounts.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'currentStates': _mockStates.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      'totalRequests': _requestCounts.values.fold(
        0,
        (sum, count) => sum + count,
      ),
      'successRate': _calculateSuccessRate(),
    };
  }

  double _calculateSuccessRate() {
    final totalRequests = _requestCounts.values.fold(
      0,
      (sum, count) => sum + count,
    );
    if (totalRequests == 0) return 0.0;

    final granted = _mockStates.values
        .where((state) => state == PermissionState.granted)
        .length;
    return (granted / _mockStates.length) * 100;
  }
}
