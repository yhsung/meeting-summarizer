import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../models/cloud_sync/cloud_provider.dart';
import 'cloud_provider_interface.dart';
import 'google_drive_provider.dart';
import 'icloud_provider.dart';
import 'onedrive_provider.dart';
import 'dropbox_provider.dart';

/// Factory class for creating cloud provider instances
class CloudProviderFactory {
  static CloudProviderFactory? _instance;
  static CloudProviderFactory get instance =>
      _instance ??= CloudProviderFactory._();
  CloudProviderFactory._();

  bool _isInitialized = false;

  /// Initialize the factory
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log('CloudProviderFactory: Initializing...');

      // Initialize any global provider dependencies here

      _isInitialized = true;
      log('CloudProviderFactory: Initialization completed');
    } catch (e, stackTrace) {
      log(
        'CloudProviderFactory: Initialization failed: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create a cloud provider instance
  Future<CloudProviderInterface?> createProvider(
    CloudProvider provider,
    Map<String, String> credentials,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      log(
        'CloudProviderFactory: Creating provider for ${provider.displayName}',
      );

      // Check if provider is supported on current platform
      final currentPlatform = _getCurrentPlatform();
      if (!provider.isSupportedOnPlatform(currentPlatform)) {
        log(
          'CloudProviderFactory: Provider ${provider.displayName} not supported on $currentPlatform',
        );
        return null;
      }

      CloudProviderInterface? providerInterface;

      switch (provider) {
        case CloudProvider.googleDrive:
          providerInterface = GoogleDriveProvider();
          break;
        case CloudProvider.icloud:
          providerInterface = ICloudProvider();
          break;
        case CloudProvider.oneDrive:
          providerInterface = OneDriveProvider();
          break;
        case CloudProvider.dropbox:
          providerInterface = DropboxProvider();
          break;
      }

      await providerInterface.initialize(credentials);
      log(
        'CloudProviderFactory: Successfully created ${provider.displayName} provider',
      );
      return providerInterface;
    } catch (e, stackTrace) {
      log(
        'CloudProviderFactory: Error creating provider ${provider.displayName}: $e',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Get list of supported providers for current platform
  List<CloudProvider> getSupportedProviders() {
    final platform = _getCurrentPlatform();
    return CloudProvider.getSupportedProviders(platform);
  }

  /// Check if a provider is supported on current platform
  bool isProviderSupported(CloudProvider provider) {
    final platform = _getCurrentPlatform();
    return provider.isSupportedOnPlatform(platform);
  }

  /// Get current platform identifier
  String _getCurrentPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// Get provider configuration requirements
  Map<String, dynamic> getProviderRequirements(CloudProvider provider) {
    return provider.getConfigurationRequirements();
  }

  /// Get provider storage limits
  CloudStorageLimits getProviderLimits(CloudProvider provider) {
    return provider.getStorageLimits();
  }

  /// Validate provider credentials
  Future<bool> validateCredentials(
    CloudProvider provider,
    Map<String, String> credentials,
  ) async {
    try {
      final providerInterface = await createProvider(provider, credentials);
      if (providerInterface == null) return false;

      final connected = await providerInterface.testConnection();
      return connected;
    } catch (e) {
      log(
        'CloudProviderFactory: Credential validation failed for ${provider.displayName}: $e',
      );
      return false;
    }
  }
}
