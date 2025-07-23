/// Interface for platform-specific services
library;

/// Base interface for all platform-specific services
abstract class PlatformServiceInterface {
  /// Initialize the service
  Future<bool> initialize();

  /// Check if the service is available on the current platform
  bool get isAvailable;

  /// Dispose resources and cleanup
  void dispose();
}

/// Interface for platform notification services
abstract class PlatformNotificationInterface extends PlatformServiceInterface {
  /// Show a notification
  Future<void> showNotification(String title, String body, {String? payload});

  /// Request notification permissions
  Future<bool> requestPermissions();
}

/// Interface for platform integration services (Siri, Android Auto, etc.)
abstract class PlatformIntegrationInterface extends PlatformServiceInterface {
  /// Register platform integrations (shortcuts, widgets, etc.)
  Future<bool> registerIntegrations();

  /// Handle platform-specific actions
  Future<void> handleAction(String action, Map<String, dynamic>? parameters);

  /// Update integrations based on app state
  Future<void> updateIntegrations(Map<String, dynamic> state);
}

/// Interface for platform system services (menu bar, system tray, etc.)
abstract class PlatformSystemInterface extends PlatformServiceInterface {
  /// Show system UI element (menu bar, system tray, etc.)
  Future<bool> showSystemUI();

  /// Hide system UI element
  Future<void> hideSystemUI();

  /// Update system UI state
  Future<void> updateSystemUIState(Map<String, dynamic> state);
}
