/// Service for managing biometric authentication
library;

import 'dart:async';
import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents the result of a biometric authentication attempt
class BiometricAuthResult {
  final bool isSuccess;
  final String? errorMessage;
  final BiometricAuthMethod? method;

  const BiometricAuthResult({
    required this.isSuccess,
    this.errorMessage,
    this.method,
  });

  const BiometricAuthResult.success(this.method)
      : isSuccess = true,
        errorMessage = null;

  const BiometricAuthResult.failure(String error)
      : isSuccess = false,
        errorMessage = error,
        method = null;
}

/// Available biometric authentication methods
enum BiometricAuthMethod {
  fingerprint,
  face,
  iris,
  weak,
  strong;

  String get displayName {
    switch (this) {
      case BiometricAuthMethod.fingerprint:
        return 'Fingerprint';
      case BiometricAuthMethod.face:
        return 'Face ID';
      case BiometricAuthMethod.iris:
        return 'Iris';
      case BiometricAuthMethod.weak:
        return 'Device PIN/Pattern';
      case BiometricAuthMethod.strong:
        return 'Strong Biometric';
    }
  }
}

/// Configuration for biometric authentication prompts
class BiometricAuthConfig {
  final String localizedFallbackTitle;
  final String signInTitle;
  final String cancelButton;
  final String? subtitle;
  final String? description;
  final bool stickyAuth;
  final bool sensitiveTransaction;
  final bool biometricOnly;

  const BiometricAuthConfig({
    this.localizedFallbackTitle = 'Use PIN/Password',
    this.signInTitle = 'Authenticate to access Meeting Summarizer',
    this.cancelButton = 'Cancel',
    this.subtitle,
    this.description,
    this.stickyAuth = false,
    this.sensitiveTransaction = true,
    this.biometricOnly = false,
  });
}

/// Session management for biometric authentication
class BiometricSession {
  final DateTime startTime;
  final Duration validDuration;
  final String sessionId;

  BiometricSession({
    required this.sessionId,
    DateTime? startTime,
    this.validDuration = const Duration(minutes: 30),
  }) : startTime = startTime ?? DateTime.now();

  bool get isValid {
    final now = DateTime.now();
    return now.difference(startTime) < validDuration;
  }

  Duration get timeRemaining {
    final now = DateTime.now();
    final elapsed = now.difference(startTime);
    final remaining = validDuration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

/// Service for managing biometric authentication with session management
class BiometricAuthService {
  static const String _enabledKey = 'biometric_auth_enabled';
  static const String _lastAuthTimeKey = 'last_biometric_auth_time';

  final LocalAuthentication _localAuth;
  final SharedPreferences? _prefs;

  BiometricSession? _currentSession;
  Timer? _sessionTimer;

  BiometricAuthService({
    LocalAuthentication? localAuth,
    SharedPreferences? preferences,
  })  : _localAuth = localAuth ?? LocalAuthentication(),
        _prefs = preferences;

  /// Check if biometric authentication is available on this device
  Future<bool> isAvailable() async {
    try {
      final isAvailable = await _localAuth.isDeviceSupported();
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;

      log(
        'BiometricAuthService: Device supported: $isAvailable, Can check: $canCheckBiometrics',
      );
      return isAvailable && canCheckBiometrics;
    } catch (e) {
      log('BiometricAuthService: Error checking availability: $e');
      return false;
    }
  }

  /// Get list of available biometric types on this device
  Future<List<BiometricAuthMethod>> getAvailableBiometrics() async {
    try {
      final availableTypes = await _localAuth.getAvailableBiometrics();
      final methods = <BiometricAuthMethod>[];

      for (final type in availableTypes) {
        switch (type) {
          case BiometricType.fingerprint:
            methods.add(BiometricAuthMethod.fingerprint);
            break;
          case BiometricType.face:
            methods.add(BiometricAuthMethod.face);
            break;
          case BiometricType.iris:
            methods.add(BiometricAuthMethod.iris);
            break;
          case BiometricType.weak:
            methods.add(BiometricAuthMethod.weak);
            break;
          case BiometricType.strong:
            methods.add(BiometricAuthMethod.strong);
            break;
        }
      }

      log(
        'BiometricAuthService: Available methods: ${methods.map((m) => m.displayName).join(', ')}',
      );
      return methods;
    } catch (e) {
      log('BiometricAuthService: Error getting available biometrics: $e');
      return [];
    }
  }

  /// Check if biometric authentication is enabled by user
  Future<bool> isEnabled() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? false;
    } catch (e) {
      log('BiometricAuthService: Error checking if enabled: $e');
      return false;
    }
  }

  /// Enable or disable biometric authentication
  Future<void> setEnabled(bool enabled) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled);

      if (!enabled) {
        await _invalidateSession();
      }

      log(
        'BiometricAuthService: Biometric auth ${enabled ? 'enabled' : 'disabled'}',
      );
    } catch (e) {
      log('BiometricAuthService: Error setting enabled state: $e');
      throw Exception('Failed to update biometric authentication setting');
    }
  }

  /// Authenticate using biometrics with custom configuration
  Future<BiometricAuthResult> authenticate({
    BiometricAuthConfig? config,
  }) async {
    try {
      if (!await isAvailable()) {
        return const BiometricAuthResult.failure(
          'Biometric authentication not available',
        );
      }

      if (!await isEnabled()) {
        return const BiometricAuthResult.failure(
          'Biometric authentication not enabled',
        );
      }

      final authConfig = config ?? const BiometricAuthConfig();

      final authOptions = AuthenticationOptions(
        stickyAuth: authConfig.stickyAuth,
        sensitiveTransaction: authConfig.sensitiveTransaction,
        biometricOnly: authConfig.biometricOnly,
      );

      log('BiometricAuthService: Starting authentication...');

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: authConfig.description ?? authConfig.signInTitle,
        options: authOptions,
      );

      if (didAuthenticate) {
        await _recordSuccessfulAuth();
        await _startSession();

        // Determine which method was used (simplified approach)
        final availableMethods = await getAvailableBiometrics();
        final method = availableMethods.isNotEmpty
            ? availableMethods.first
            : BiometricAuthMethod.strong;

        log(
          'BiometricAuthService: Authentication successful using ${method.displayName}',
        );
        return BiometricAuthResult.success(method);
      } else {
        log(
          'BiometricAuthService: Authentication failed - user cancelled or failed',
        );
        return const BiometricAuthResult.failure(
          'Authentication cancelled or failed',
        );
      }
    } on PlatformException catch (e) {
      log(
        'BiometricAuthService: Platform exception during authentication: ${e.code} - ${e.message}',
      );
      return BiometricAuthResult.failure(_handlePlatformException(e));
    } catch (e) {
      log('BiometricAuthService: Unexpected error during authentication: $e');
      return BiometricAuthResult.failure(
        'Authentication error: ${e.toString()}',
      );
    }
  }

  /// Check if current session is valid
  bool get hasValidSession {
    return _currentSession?.isValid ?? false;
  }

  /// Get current session information
  BiometricSession? get currentSession => _currentSession;

  /// Get time remaining in current session
  Duration get sessionTimeRemaining {
    return _currentSession?.timeRemaining ?? Duration.zero;
  }

  /// Invalidate current session
  Future<void> invalidateSession() async {
    await _invalidateSession();
    log('BiometricAuthService: Session manually invalidated');
  }

  /// Get the last successful authentication time
  Future<DateTime?> getLastAuthTime() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastAuthTimeKey);
      return timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null;
    } catch (e) {
      log('BiometricAuthService: Error getting last auth time: $e');
      return null;
    }
  }

  /// Check if re-authentication is required based on time threshold
  Future<bool> requiresReauth({
    Duration threshold = const Duration(hours: 24),
  }) async {
    final lastAuth = await getLastAuthTime();
    if (lastAuth == null) return true;

    final now = DateTime.now();
    final timeSinceAuth = now.difference(lastAuth);
    return timeSinceAuth > threshold;
  }

  /// Start a new biometric session
  Future<void> _startSession() async {
    _invalidateCurrentTimer();

    _currentSession = BiometricSession(
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    // Set up auto-invalidation timer
    _sessionTimer = Timer(_currentSession!.validDuration, () {
      _invalidateSession();
      log('BiometricAuthService: Session automatically expired');
    });

    log(
      'BiometricAuthService: New session started, valid for ${_currentSession!.validDuration.inMinutes} minutes',
    );
  }

  /// Invalidate current session
  Future<void> _invalidateSession() async {
    _currentSession = null;
    _invalidateCurrentTimer();
  }

  /// Cancel current session timer
  void _invalidateCurrentTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  /// Record successful authentication timestamp
  Future<void> _recordSuccessfulAuth() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_lastAuthTimeKey, now);
    } catch (e) {
      log('BiometricAuthService: Error recording auth time: $e');
    }
  }

  /// Handle platform-specific authentication errors
  String _handlePlatformException(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return 'Biometric authentication not available on this device';
      case 'NotEnrolled':
        return 'No biometric credentials enrolled. Please set up biometric authentication in Settings';
      case 'PasscodeNotSet':
        return 'Device passcode not set. Please set up a device passcode first';
      case 'LockedOut':
        return 'Biometric authentication temporarily locked. Try again later';
      case 'PermanentlyLockedOut':
        return 'Biometric authentication permanently locked. Use device passcode';
      case 'UserCancel':
        return 'Authentication cancelled by user';
      case 'UserFallback':
        return 'User chose to use fallback authentication';
      case 'SystemCancel':
        return 'Authentication cancelled by system';
      case 'InvalidContext':
        return 'Authentication context is invalid';
      case 'NotInteractive':
        return 'Authentication requires user interaction';
      default:
        return e.message ?? 'Unknown biometric authentication error';
    }
  }

  /// Clean up resources
  void dispose() {
    _invalidateCurrentTimer();
    _currentSession = null;
    log('BiometricAuthService: Service disposed');
  }
}
