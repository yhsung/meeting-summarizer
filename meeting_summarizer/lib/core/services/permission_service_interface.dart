import 'dart:async';

/// Enum representing different permission states
enum PermissionState {
  /// Permission status is unknown or not checked yet
  unknown,

  /// Permission has been granted by the user
  granted,

  /// Permission has been denied by the user but can be requested again
  denied,

  /// Permission has been permanently denied (Android) or restricted (iOS)
  permanentlyDenied,

  /// Permission is restricted (iOS only - parental controls)
  restricted,

  /// Permission is limited (iOS 14+ only - limited photo access)
  limited,

  /// Permission request is in progress
  requesting,
}

/// Enum representing different types of permissions
enum PermissionType {
  /// Microphone permission for audio recording
  microphone,

  /// Storage permission for saving recordings
  storage,

  /// Notification permission for background alerts
  notification,

  /// Background app refresh permission
  backgroundRefresh,

  /// Phone permission for call recording (Android)
  phone,
}

/// Configuration for permission request flows
class PermissionConfig {
  /// Whether to show rationale before requesting permission
  final bool showRationale;

  /// Custom rationale message to show to user
  final String? rationaleMessage;

  /// Title for rationale dialog
  final String? rationaleTitle;

  /// Whether to automatically redirect to settings if permanently denied
  final bool autoRedirectToSettings;

  /// Custom message for settings redirect dialog
  final String? settingsRedirectMessage;

  /// Whether to enable retry mechanism for failed requests
  final bool enableRetry;

  /// Maximum number of retry attempts
  final int maxRetryAttempts;

  /// Delay between retry attempts
  final Duration retryDelay;

  const PermissionConfig({
    this.showRationale = true,
    this.rationaleMessage,
    this.rationaleTitle,
    this.autoRedirectToSettings = true,
    this.settingsRedirectMessage,
    this.enableRetry = true,
    this.maxRetryAttempts = 3,
    this.retryDelay = const Duration(seconds: 1),
  });

  PermissionConfig copyWith({
    bool? showRationale,
    String? rationaleMessage,
    String? rationaleTitle,
    bool? autoRedirectToSettings,
    String? settingsRedirectMessage,
    bool? enableRetry,
    int? maxRetryAttempts,
    Duration? retryDelay,
  }) {
    return PermissionConfig(
      showRationale: showRationale ?? this.showRationale,
      rationaleMessage: rationaleMessage ?? this.rationaleMessage,
      rationaleTitle: rationaleTitle ?? this.rationaleTitle,
      autoRedirectToSettings:
          autoRedirectToSettings ?? this.autoRedirectToSettings,
      settingsRedirectMessage:
          settingsRedirectMessage ?? this.settingsRedirectMessage,
      enableRetry: enableRetry ?? this.enableRetry,
      maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
      retryDelay: retryDelay ?? this.retryDelay,
    );
  }
}

/// Result of a permission request operation
class PermissionResult {
  /// The final permission state after the request
  final PermissionState state;

  /// Whether the request was successful (granted)
  final bool isGranted;

  /// Whether the permission was permanently denied
  final bool isPermanentlyDenied;

  /// Whether the user was redirected to settings
  final bool wasRedirectedToSettings;

  /// Error message if the request failed
  final String? errorMessage;

  /// Additional context or metadata
  final Map<String, dynamic>? metadata;

  const PermissionResult({
    required this.state,
    required this.isGranted,
    required this.isPermanentlyDenied,
    this.wasRedirectedToSettings = false,
    this.errorMessage,
    this.metadata,
  });

  factory PermissionResult.granted({Map<String, dynamic>? metadata}) {
    return PermissionResult(
      state: PermissionState.granted,
      isGranted: true,
      isPermanentlyDenied: false,
      metadata: metadata,
    );
  }

  factory PermissionResult.denied({
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) {
    return PermissionResult(
      state: PermissionState.denied,
      isGranted: false,
      isPermanentlyDenied: false,
      errorMessage: errorMessage,
      metadata: metadata,
    );
  }

  factory PermissionResult.permanentlyDenied({
    bool wasRedirectedToSettings = false,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) {
    return PermissionResult(
      state: PermissionState.permanentlyDenied,
      isGranted: false,
      isPermanentlyDenied: true,
      wasRedirectedToSettings: wasRedirectedToSettings,
      errorMessage: errorMessage,
      metadata: metadata,
    );
  }

  factory PermissionResult.error(
    String errorMessage, {
    Map<String, dynamic>? metadata,
  }) {
    return PermissionResult(
      state: PermissionState.unknown,
      isGranted: false,
      isPermanentlyDenied: false,
      errorMessage: errorMessage,
      metadata: metadata,
    );
  }
}

/// Interface for comprehensive permission management service
abstract class PermissionServiceInterface {
  /// Initialize the permission service
  Future<void> initialize();

  /// Dispose of the permission service and clean up resources
  Future<void> dispose();

  /// Check the current state of a specific permission
  Future<PermissionState> checkPermission(PermissionType type);

  /// Check multiple permissions at once
  Future<Map<PermissionType, PermissionState>> checkPermissions(
    List<PermissionType> types,
  );

  /// Request a specific permission with optional configuration
  Future<PermissionResult> requestPermission(
    PermissionType type, {
    PermissionConfig? config,
  });

  /// Request multiple permissions at once
  Future<Map<PermissionType, PermissionResult>> requestPermissions(
    List<PermissionType> types, {
    PermissionConfig? config,
  });

  /// Open system settings for the app (useful for permanently denied permissions)
  Future<bool> openAppSettings();

  /// Check if permission rationale should be shown to user
  Future<bool> shouldShowRationale(PermissionType type);

  /// Stream of permission state changes for monitoring
  Stream<Map<PermissionType, PermissionState>> get permissionStateStream;

  /// Get platform-specific permission information
  Map<String, dynamic> getPlatformPermissionInfo(PermissionType type);

  /// Check if the app has all required permissions for core functionality
  Future<bool> hasRequiredPermissions();

  /// Get list of missing required permissions
  Future<List<PermissionType>> getMissingRequiredPermissions();

  /// Reset permission request tracking (useful for testing)
  void resetPermissionTracking();

  /// Get permission request history and analytics
  Map<String, dynamic> getPermissionAnalytics();
}
