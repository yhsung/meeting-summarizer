import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for monitoring network connectivity and providing connectivity status
class NetworkConnectivityService {
  static NetworkConnectivityService? _instance;
  static NetworkConnectivityService get instance =>
      _instance ??= NetworkConnectivityService._();
  NetworkConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<List<ConnectivityResult>> _connectivityController =
      StreamController<List<ConnectivityResult>>.broadcast();

  bool _isInitialized = false;
  List<ConnectivityResult> _currentConnectivityResults = [
    ConnectivityResult.none,
  ];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Stream of connectivity changes
  Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivityController.stream;

  /// Current connectivity results
  List<ConnectivityResult> get currentConnectivityResults =>
      _currentConnectivityResults;

  /// Primary connectivity result (first non-none result or none if all are none)
  ConnectivityResult get primaryConnectivityResult {
    return _currentConnectivityResults.firstWhere(
      (result) => result != ConnectivityResult.none,
      orElse: () => ConnectivityResult.none,
    );
  }

  /// Initialize the connectivity service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log('NetworkConnectivityService: Initializing...');

      // Get initial connectivity status
      _currentConnectivityResults = await _connectivity.checkConnectivity();
      log(
        'NetworkConnectivityService: Initial connectivity: $_currentConnectivityResults',
      );

      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (error) {
          log('NetworkConnectivityService: Connectivity stream error: $error');
        },
      );

      _isInitialized = true;
      log('NetworkConnectivityService: Initialization completed');
    } catch (e, stackTrace) {
      log(
        'NetworkConnectivityService: Initialization failed: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    log('NetworkConnectivityService: Connectivity changed: $results');

    _currentConnectivityResults = results;
    _connectivityController.add(results);
  }

  /// Check if device is currently connected to internet
  Future<bool> get isConnected async {
    final connectivityResults = await _connectivity.checkConnectivity();

    // Update current status
    if (connectivityResults != _currentConnectivityResults) {
      _currentConnectivityResults = connectivityResults;
      _connectivityController.add(connectivityResults);
    }

    // Consider all as disconnected if all are none, otherwise potentially connected
    if (connectivityResults.every(
      (result) => result == ConnectivityResult.none,
    )) {
      return false;
    }

    // Perform actual internet connectivity test for more reliable detection
    return await _hasInternetConnection();
  }

  /// Test actual internet connectivity by attempting to connect to reliable hosts
  Future<bool> _hasInternetConnection() async {
    try {
      // List of reliable hosts to test connectivity
      final testHosts = [
        'google.com',
        'cloudflare.com',
        '8.8.8.8', // Google DNS
      ];

      for (final host in testHosts) {
        try {
          final result = await InternetAddress.lookup(
            host,
          ).timeout(const Duration(seconds: 3));

          if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
            log(
              'NetworkConnectivityService: Internet connectivity confirmed via $host',
            );
            return true;
          }
        } catch (e) {
          log('NetworkConnectivityService: Failed to reach $host: $e');
          // Continue to next host
        }
      }

      log('NetworkConnectivityService: No internet connectivity detected');
      return false;
    } catch (e) {
      log(
        'NetworkConnectivityService: Error testing internet connectivity: $e',
      );
      return false;
    }
  }

  /// Get connectivity type as string for logging/display
  String get connectivityTypeString {
    final primaryResult = primaryConnectivityResult;
    switch (primaryResult) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.other:
        return 'Other';
      case ConnectivityResult.none:
        return 'No Connection';
    }
  }

  /// Check if current connectivity is suitable for large file transfers
  bool get isSuitableForLargeTransfers {
    final primaryResult = primaryConnectivityResult;
    switch (primaryResult) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
        return true;
      case ConnectivityResult.mobile:
        // Mobile data is suitable but should consider data usage
        return true;
      case ConnectivityResult.bluetooth:
      case ConnectivityResult.vpn:
      case ConnectivityResult.other:
        // These might be slower but still usable
        return true;
      case ConnectivityResult.none:
        return false;
    }
  }

  /// Check if current connectivity is metered (mobile data)
  bool get isMeteredConnection {
    return _currentConnectivityResults.contains(ConnectivityResult.mobile);
  }

  /// Wait for internet connectivity to be available
  Future<void> waitForConnectivity({
    Duration timeout = const Duration(minutes: 5),
  }) async {
    // If already connected, return immediately
    if (await isConnected) {
      return;
    }

    log('NetworkConnectivityService: Waiting for connectivity...');

    final completer = Completer<void>();
    late StreamSubscription<List<ConnectivityResult>> subscription;

    // Set up timeout
    final timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.completeError(
          TimeoutException('Timeout waiting for connectivity', timeout),
        );
      }
    });

    // Listen for connectivity changes
    subscription = connectivityStream.listen((results) async {
      if (results.any((result) => result != ConnectivityResult.none)) {
        // Check actual internet connectivity
        if (await _hasInternetConnection()) {
          timeoutTimer.cancel();
          subscription.cancel();
          if (!completer.isCompleted) {
            log('NetworkConnectivityService: Connectivity restored');
            completer.complete();
          }
        }
      }
    });

    return completer.future;
  }

  /// Get connectivity statistics for monitoring
  ConnectivityStats getConnectivityStats() {
    return ConnectivityStats(
      currentResults: _currentConnectivityResults,
      primaryResult: primaryConnectivityResult,
      isConnected: primaryConnectivityResult != ConnectivityResult.none,
      isMetered: isMeteredConnection,
      isSuitableForLargeTransfers: isSuitableForLargeTransfers,
      connectivityType: connectivityTypeString,
    );
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
    _isInitialized = false;
  }
}

/// Connectivity statistics for monitoring and decision making
class ConnectivityStats {
  final List<ConnectivityResult> currentResults;
  final ConnectivityResult primaryResult;
  final bool isConnected;
  final bool isMetered;
  final bool isSuitableForLargeTransfers;
  final String connectivityType;

  const ConnectivityStats({
    required this.currentResults,
    required this.primaryResult,
    required this.isConnected,
    required this.isMetered,
    required this.isSuitableForLargeTransfers,
    required this.connectivityType,
  });

  Map<String, dynamic> toJson() => {
    'currentResults': currentResults.map((r) => r.toString()).toList(),
    'primaryResult': primaryResult.toString(),
    'isConnected': isConnected,
    'isMetered': isMetered,
    'isSuitableForLargeTransfers': isSuitableForLargeTransfers,
    'connectivityType': connectivityType,
  };

  @override
  String toString() {
    return 'ConnectivityStats(type: $connectivityType, connected: $isConnected, '
        'metered: $isMetered, suitable: $isSuitableForLargeTransfers)';
  }
}

/// Exception thrown when waiting for connectivity times out
class TimeoutException implements Exception {
  final String message;
  final Duration timeout;

  const TimeoutException(this.message, this.timeout);

  @override
  String toString() => 'TimeoutException: $message (timeout: $timeout)';
}
