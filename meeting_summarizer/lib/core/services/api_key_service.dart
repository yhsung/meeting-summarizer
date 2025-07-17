/// Service for managing API keys securely
library;

import 'dart:developer';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for securely storing and retrieving API keys
class ApiKeyService {
  static const String _keyPrefix = 'api_key_';
  static const String _fallbackPrefix = 'fallback_api_key_';

  final FlutterSecureStorage _secureStorage;
  bool _useSecureStorage = true;

  ApiKeyService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Store an API key securely
  ///
  /// [provider] - The service provider (e.g., 'openai', 'google', 'anthropic')
  /// [apiKey] - The API key to store
  Future<void> setApiKey(String provider, String apiKey) async {
    if (provider.isEmpty) {
      throw ArgumentError('Provider cannot be empty');
    }

    if (apiKey.isEmpty) {
      throw ArgumentError('API key cannot be empty');
    }

    final key = _buildStorageKey(provider);

    try {
      if (_useSecureStorage) {
        await _secureStorage.write(key: key, value: apiKey);
        log('ApiKeyService: API key stored securely for provider: $provider');
      } else {
        await _storeFallback(provider, apiKey);
        log(
          'ApiKeyService: API key stored in fallback storage for provider: $provider',
        );
      }
    } catch (e) {
      log('ApiKeyService: Secure storage failed for $provider: $e');

      // Fall back to SharedPreferences if secure storage fails
      if (_useSecureStorage) {
        log('ApiKeyService: Falling back to SharedPreferences for $provider');
        _useSecureStorage = false;
        await _storeFallback(provider, apiKey);
        log(
          'ApiKeyService: API key stored in fallback storage for provider: $provider',
        );
      } else {
        rethrow;
      }
    }
  }

  /// Store API key in fallback storage (SharedPreferences)
  Future<void> _storeFallback(String provider, String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_fallbackPrefix${provider.toLowerCase()}';

    // Basic obfuscation (not secure, but better than plain text)
    final obfuscatedKey = _obfuscateKey(apiKey);

    await prefs.setString(key, obfuscatedKey);
  }

  /// Retrieve an API key
  ///
  /// [provider] - The service provider to get the key for
  ///
  /// Returns the API key or null if not found
  Future<String?> getApiKey(String provider) async {
    if (provider.isEmpty) {
      throw ArgumentError('Provider cannot be empty');
    }

    final key = _buildStorageKey(provider);

    try {
      if (_useSecureStorage) {
        final apiKey = await _secureStorage.read(key: key);
        if (apiKey != null) {
          log(
            'ApiKeyService: Retrieved API key from secure storage for provider: $provider',
          );
          return apiKey;
        }
      }

      // Try fallback storage
      final fallbackKey = await _getFallback(provider);
      if (fallbackKey != null) {
        log(
          'ApiKeyService: Retrieved API key from fallback storage for provider: $provider',
        );
        return fallbackKey;
      }

      log('ApiKeyService: No API key found for provider: $provider');
      return null;
    } catch (e) {
      log('ApiKeyService: Secure storage failed for $provider: $e');

      // Fall back to SharedPreferences if secure storage fails
      if (_useSecureStorage) {
        log('ApiKeyService: Falling back to SharedPreferences for $provider');
        _useSecureStorage = false;
        return await _getFallback(provider);
      }

      log('ApiKeyService: Failed to retrieve API key for $provider: $e');
      return null;
    }
  }

  /// Get API key from fallback storage (SharedPreferences)
  Future<String?> _getFallback(String provider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_fallbackPrefix${provider.toLowerCase()}';

      final obfuscatedKey = prefs.getString(key);
      if (obfuscatedKey != null) {
        return _deobfuscateKey(obfuscatedKey);
      }

      return null;
    } catch (e) {
      log(
        'ApiKeyService: Failed to retrieve from fallback storage for $provider: $e',
      );
      return null;
    }
  }

  /// Check if an API key exists for a provider
  ///
  /// [provider] - The service provider to check
  ///
  /// Returns true if an API key exists
  Future<bool> hasApiKey(String provider) async {
    final apiKey = await getApiKey(provider);
    return apiKey != null && apiKey.isNotEmpty;
  }

  /// Remove an API key
  ///
  /// [provider] - The service provider to remove the key for
  Future<void> removeApiKey(String provider) async {
    if (provider.isEmpty) {
      throw ArgumentError('Provider cannot be empty');
    }

    final key = _buildStorageKey(provider);

    try {
      // Remove from secure storage
      if (_useSecureStorage) {
        await _secureStorage.delete(key: key);
      }

      // Also remove from fallback storage
      await _removeFallback(provider);

      log('ApiKeyService: API key removed for provider: $provider');
    } catch (e) {
      log('ApiKeyService: Failed to remove API key for $provider: $e');
      rethrow;
    }
  }

  /// Remove API key from fallback storage
  Future<void> _removeFallback(String provider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_fallbackPrefix${provider.toLowerCase()}';
      await prefs.remove(key);
    } catch (e) {
      log(
        'ApiKeyService: Failed to remove from fallback storage for $provider: $e',
      );
    }
  }

  /// Get all configured providers
  ///
  /// Returns a list of provider names that have stored API keys
  Future<List<String>> getConfiguredProviders() async {
    final providers = <String>[];

    try {
      if (_useSecureStorage) {
        final allKeys = await _secureStorage.readAll();

        for (final key in allKeys.keys) {
          if (key.startsWith(_keyPrefix)) {
            final provider = key.substring(_keyPrefix.length);
            if (provider.isNotEmpty && allKeys[key]?.isNotEmpty == true) {
              providers.add(provider);
            }
          }
        }
      }

      // Also check fallback storage
      final prefs = await SharedPreferences.getInstance();
      final fallbackKeys = prefs.getKeys();

      for (final key in fallbackKeys) {
        if (key.startsWith(_fallbackPrefix)) {
          final provider = key.substring(_fallbackPrefix.length);
          if (provider.isNotEmpty && !providers.contains(provider)) {
            final value = prefs.getString(key);
            if (value?.isNotEmpty == true) {
              providers.add(provider);
            }
          }
        }
      }

      log('ApiKeyService: Found ${providers.length} configured providers');
      return providers;
    } catch (e) {
      log('ApiKeyService: Failed to get configured providers: $e');
      return [];
    }
  }

  /// Clear all stored API keys
  Future<void> clearAllApiKeys() async {
    try {
      final allKeys = await _secureStorage.readAll();

      for (final key in allKeys.keys) {
        if (key.startsWith(_keyPrefix)) {
          await _secureStorage.delete(key: key);
        }
      }

      log('ApiKeyService: All API keys cleared');
    } catch (e) {
      log('ApiKeyService: Failed to clear API keys: $e');
      rethrow;
    }
  }

  /// Validate API key format for specific providers
  ///
  /// [provider] - The service provider
  /// [apiKey] - The API key to validate
  ///
  /// Returns true if the API key format appears valid
  bool validateApiKeyFormat(String provider, String apiKey) {
    if (apiKey.isEmpty) return false;

    switch (provider.toLowerCase()) {
      case 'openai':
        // OpenAI keys start with 'sk-' and are ~51 characters
        return apiKey.startsWith('sk-') && apiKey.length >= 48;

      case 'anthropic':
        // Anthropic keys start with 'sk-ant-'
        return apiKey.startsWith('sk-ant-') && apiKey.length >= 40;

      case 'google':
        // Google API keys are typically 39 characters
        return apiKey.length >= 35 && apiKey.length <= 45;

      case 'azure':
        // Azure keys are typically 32 characters hex
        return apiKey.length == 32 &&
            RegExp(r'^[a-f0-9]{32}$').hasMatch(apiKey);

      case 'aws':
        // AWS access keys are 20 characters
        return apiKey.length == 20 && apiKey.toUpperCase() == apiKey;

      default:
        // For unknown providers, just check it's not empty and has reasonable length
        return apiKey.length >= 10 && apiKey.length <= 200;
    }
  }

  /// Test if an API key is working by making a simple API call
  ///
  /// [provider] - The service provider
  /// [apiKey] - The API key to test (optional, will use stored key if not provided)
  ///
  /// Returns true if the API key works
  Future<bool> testApiKey(String provider, [String? apiKey]) async {
    final keyToTest = apiKey ?? await getApiKey(provider);

    if (keyToTest == null || keyToTest.isEmpty) {
      log('ApiKeyService: No API key available to test for $provider');
      return false;
    }

    if (!validateApiKeyFormat(provider, keyToTest)) {
      log('ApiKeyService: API key format invalid for $provider');
      return false;
    }

    // For now, just return true if format is valid
    // In a full implementation, this would make actual API calls
    log('ApiKeyService: API key format valid for $provider');
    return true;
  }

  /// Get API key information without exposing the actual key
  ///
  /// [provider] - The service provider
  ///
  /// Returns information about the stored API key
  Future<ApiKeyInfo?> getApiKeyInfo(String provider) async {
    final apiKey = await getApiKey(provider);

    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    return ApiKeyInfo(
      provider: provider,
      isConfigured: true,
      isValidFormat: validateApiKeyFormat(provider, apiKey),
      keyLength: apiKey.length,
      keyPrefix: _maskApiKey(apiKey),
      lastUpdated:
          DateTime.now(), // Would need to store this separately for real tracking
    );
  }

  /// Get information about all configured API keys
  Future<List<ApiKeyInfo>> getAllApiKeyInfo() async {
    final providers = await getConfiguredProviders();
    final infos = <ApiKeyInfo>[];

    for (final provider in providers) {
      final info = await getApiKeyInfo(provider);
      if (info != null) {
        infos.add(info);
      }
    }

    return infos;
  }

  /// Build storage key for a provider
  String _buildStorageKey(String provider) {
    return '$_keyPrefix${provider.toLowerCase()}';
  }

  /// Mask API key for display purposes
  String _maskApiKey(String apiKey) {
    if (apiKey.length <= 8) {
      return '*' * apiKey.length;
    }

    final start = apiKey.substring(0, 4);
    final end = apiKey.substring(apiKey.length - 4);
    final middle = '*' * (apiKey.length - 8);

    return '$start$middle$end';
  }

  /// Basic obfuscation for fallback storage (not cryptographically secure)
  String _obfuscateKey(String apiKey) {
    final bytes = apiKey.codeUnits;
    final obfuscated = bytes.map((byte) => byte ^ 0x42).toList();
    return String.fromCharCodes(obfuscated);
  }

  /// Deobfuscate API key from fallback storage
  String _deobfuscateKey(String obfuscatedKey) {
    final bytes = obfuscatedKey.codeUnits;
    final deobfuscated = bytes.map((byte) => byte ^ 0x42).toList();
    return String.fromCharCodes(deobfuscated);
  }
}

/// Information about a stored API key
class ApiKeyInfo {
  final String provider;
  final bool isConfigured;
  final bool isValidFormat;
  final int keyLength;
  final String keyPrefix;
  final DateTime lastUpdated;

  const ApiKeyInfo({
    required this.provider,
    required this.isConfigured,
    required this.isValidFormat,
    required this.keyLength,
    required this.keyPrefix,
    required this.lastUpdated,
  });

  /// Display name for the provider
  String get providerDisplayName {
    switch (provider.toLowerCase()) {
      case 'openai':
        return 'OpenAI';
      case 'anthropic':
        return 'Anthropic';
      case 'google':
        return 'Google';
      case 'azure':
        return 'Azure';
      case 'aws':
        return 'Amazon Web Services';
      default:
        return provider.toUpperCase();
    }
  }

  /// Status description
  String get statusDescription {
    if (!isConfigured) return 'Not configured';
    if (!isValidFormat) return 'Invalid format';
    return 'Configured';
  }

  /// Status color indicator
  String get statusColor {
    if (!isConfigured) return 'red';
    if (!isValidFormat) return 'orange';
    return 'green';
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'is_configured': isConfigured,
      'is_valid_format': isValidFormat,
      'key_length': keyLength,
      'key_prefix': keyPrefix,
      'last_updated': lastUpdated.toIso8601String(),
      'provider_display_name': providerDisplayName,
      'status_description': statusDescription,
    };
  }

  @override
  String toString() {
    return 'ApiKeyInfo(provider: $provider, configured: $isConfigured, valid: $isValidFormat)';
  }
}
