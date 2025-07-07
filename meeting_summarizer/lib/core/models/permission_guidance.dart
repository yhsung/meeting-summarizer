/// Guidance information for permission requests
class PermissionGuidance {
  final String message;
  final bool shouldShowRationale;
  final String rationaleTitle;
  final String rationaleMessage;
  final bool shouldRedirectToSettings;
  final String? settingsMessage;
  final bool enableRetry;
  final int maxRetryAttempts;
  final Duration retryDelay;

  const PermissionGuidance({
    required this.message,
    required this.shouldShowRationale,
    required this.rationaleTitle,
    required this.rationaleMessage,
    required this.shouldRedirectToSettings,
    this.settingsMessage,
    required this.enableRetry,
    required this.maxRetryAttempts,
    this.retryDelay = const Duration(seconds: 1),
  });
}

/// Result of a permission recovery attempt
class PermissionRecoveryResult {
  final bool success;
  final String message;
  final bool requiresUserAction;
  final String? recommendedAction;

  const PermissionRecoveryResult({
    required this.success,
    required this.message,
    this.requiresUserAction = false,
    this.recommendedAction,
  });
}

/// Result of checking recording readiness
class RecordingReadinessResult {
  final bool isReady;
  final String reason;
  final String guidance;
  final bool canRecover;
  final String? recommendedAction;

  const RecordingReadinessResult({
    required this.isReady,
    required this.reason,
    required this.guidance,
    this.canRecover = false,
    this.recommendedAction,
  });
}
