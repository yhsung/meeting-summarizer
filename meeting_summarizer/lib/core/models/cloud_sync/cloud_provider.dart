/// Supported cloud storage providers
enum CloudProvider {
  /// Apple iCloud Drive
  icloud('icloud', 'iCloud Drive', ['ios', 'macos']),

  /// Google Drive
  googleDrive('google_drive', 'Google Drive', [
    'android',
    'ios',
    'web',
    'windows',
    'macos',
    'linux',
  ]),

  /// Microsoft OneDrive
  oneDrive('onedrive', 'Microsoft OneDrive', [
    'android',
    'ios',
    'web',
    'windows',
    'macos',
    'linux',
  ]),

  /// Dropbox
  dropbox('dropbox', 'Dropbox', [
    'android',
    'ios',
    'web',
    'windows',
    'macos',
    'linux',
  ]);

  const CloudProvider(this.id, this.displayName, this.supportedPlatforms);

  /// Unique identifier for the provider
  final String id;

  /// Human-readable display name
  final String displayName;

  /// List of supported platforms
  final List<String> supportedPlatforms;

  /// Check if provider is supported on current platform
  bool isSupportedOnPlatform(String platform) {
    return supportedPlatforms.contains(platform);
  }

  /// Get provider by ID
  static CloudProvider? fromId(String id) {
    try {
      return CloudProvider.values.firstWhere((provider) => provider.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get all providers supported on a specific platform
  static List<CloudProvider> getSupportedProviders(String platform) {
    return CloudProvider.values
        .where((provider) => provider.isSupportedOnPlatform(platform))
        .toList();
  }

  /// Get provider configuration requirements
  Map<String, dynamic> getConfigurationRequirements() {
    switch (this) {
      case CloudProvider.icloud:
        return {
          'requiresAppleId': true,
          'requiresApiKey': false,
          'requiresOAuth': false,
          'authMethod': 'platform',
        };
      case CloudProvider.googleDrive:
        return {
          'requiresGoogleAccount': true,
          'requiresApiKey': true,
          'requiresOAuth': true,
          'authMethod': 'oauth2',
          'scopes': ['https://www.googleapis.com/auth/drive.file'],
        };
      case CloudProvider.oneDrive:
        return {
          'requiresMicrosoftAccount': true,
          'requiresApiKey': true,
          'requiresOAuth': true,
          'authMethod': 'oauth2',
          'scopes': ['Files.ReadWrite.All'],
        };
      case CloudProvider.dropbox:
        return {
          'requiresDropboxAccount': true,
          'requiresApiKey': true,
          'requiresOAuth': true,
          'authMethod': 'oauth2',
          'scopes': ['files.content.write', 'files.content.read'],
        };
    }
  }

  /// Get provider-specific storage limits
  CloudStorageLimits getStorageLimits() {
    switch (this) {
      case CloudProvider.icloud:
        return const CloudStorageLimits(
          freeStorageGB: 5,
          maxFileSizeGB: 50,
          maxFileNameLength: 255,
          supportedFormats: ['*'], // Supports all formats
        );
      case CloudProvider.googleDrive:
        return const CloudStorageLimits(
          freeStorageGB: 15,
          maxFileSizeGB: 5120, // 5TB for paid accounts
          maxFileNameLength: 255,
          supportedFormats: ['*'],
        );
      case CloudProvider.oneDrive:
        return const CloudStorageLimits(
          freeStorageGB: 5,
          maxFileSizeGB: 250,
          maxFileNameLength: 255,
          supportedFormats: ['*'],
        );
      case CloudProvider.dropbox:
        return const CloudStorageLimits(
          freeStorageGB: 2,
          maxFileSizeGB: 50,
          maxFileNameLength: 255,
          supportedFormats: ['*'],
        );
    }
  }

  @override
  String toString() => displayName;
}

/// Storage limits for cloud providers
class CloudStorageLimits {
  final int freeStorageGB;
  final int maxFileSizeGB;
  final int maxFileNameLength;
  final List<String> supportedFormats;

  const CloudStorageLimits({
    required this.freeStorageGB,
    required this.maxFileSizeGB,
    required this.maxFileNameLength,
    required this.supportedFormats,
  });

  /// Check if file size is within limits
  bool isFileSizeAllowed(int fileSizeBytes) {
    final fileSizeGB = fileSizeBytes / (1024 * 1024 * 1024);
    return fileSizeGB <= maxFileSizeGB;
  }

  /// Check if file name length is within limits
  bool isFileNameLengthAllowed(String fileName) {
    return fileName.length <= maxFileNameLength;
  }

  /// Check if file format is supported
  bool isFormatSupported(String fileExtension) {
    if (supportedFormats.contains('*')) return true;
    return supportedFormats.contains(fileExtension.toLowerCase());
  }
}
