/// Comprehensive settings management service using shared_preferences
library;

import 'dart:developer';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/database/app_settings.dart';

/// Service for managing application settings with persistence
class SettingsService {
  static SettingsService? _instance;
  SharedPreferences? _prefs;
  final Map<String, AppSettings> _cachedSettings = {};
  final Map<String, dynamic> _defaultValues = {};

  SettingsService._();

  /// Get singleton instance
  static SettingsService get instance {
    _instance ??= SettingsService._();
    return _instance!;
  }

  /// Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _initializeDefaultValues();
    await _loadAllSettings();
    log('SettingsService: Initialized with ${_cachedSettings.length} settings');
  }

  /// Initialize default values for all settings
  void _initializeDefaultValues() {
    // Audio settings defaults
    _defaultValues[SettingKeys.audioFormat] = 'm4a';
    _defaultValues[SettingKeys.audioQuality] = 'high';
    _defaultValues[SettingKeys.recordingLimit] = 3600; // 1 hour in seconds
    _defaultValues[SettingKeys.enableNoiseReduction] = true;
    _defaultValues[SettingKeys.enableAutoGainControl] = true;

    // Transcription settings defaults
    _defaultValues[SettingKeys.transcriptionLanguage] = 'auto';
    _defaultValues[SettingKeys.transcriptionProvider] = 'openaiWhisper';
    _defaultValues[SettingKeys.autoTranscribe] = true;

    // Summary settings defaults
    _defaultValues[SettingKeys.summaryType] = 'comprehensive';
    _defaultValues[SettingKeys.autoSummarize] = false;

    // UI settings defaults
    _defaultValues[SettingKeys.themeMode] = 'system';
    _defaultValues[SettingKeys.waveformEnabled] = true;

    // General settings defaults
    _defaultValues[SettingKeys.firstLaunch] = true;

    // Security settings defaults
    _defaultValues[SettingKeys.encryptRecordings] = false;
    _defaultValues[SettingKeys.autoLockTimeout] = 300; // 5 minutes

    // Storage settings defaults
    _defaultValues[SettingKeys.maxStorageSize] = 1024; // 1GB in MB
    _defaultValues[SettingKeys.autoCleanup] = true;
    _defaultValues[SettingKeys.backupEnabled] = false;

    // Notification settings defaults
    _defaultValues['notification_enabled'] = true;
    _defaultValues['notification_sound'] = true;
    _defaultValues['notification_vibration'] = true;
    _defaultValues['notification_recording_start'] = true;
    _defaultValues['notification_recording_stop'] = true;
    _defaultValues['notification_transcription_complete'] = true;

    // Privacy settings defaults
    _defaultValues['data_collection_analytics'] = false;
    _defaultValues['data_collection_crash_reports'] = true;
    _defaultValues['data_retention_days'] = 30;
    _defaultValues['share_anonymous_usage'] = false;

    // Export settings defaults
    _defaultValues['export_format'] = 'txt';
    _defaultValues['export_include_timestamps'] = true;
    _defaultValues['export_include_summary'] = true;
    _defaultValues['export_include_metadata'] = false;

    // Cloud sync settings defaults
    _defaultValues['cloud_sync_enabled'] = false;
    _defaultValues['cloud_sync_provider'] = 'none';
    _defaultValues['cloud_sync_auto'] = false;
    _defaultValues['cloud_sync_wifi_only'] = true;

    // Advanced settings defaults
    _defaultValues['developer_mode'] = false;
    _defaultValues['debug_logging'] = false;
    _defaultValues['performance_mode'] = 'balanced';
    _defaultValues['experimental_features'] = false;
  }

  /// Load all settings from shared preferences
  Future<void> _loadAllSettings() async {
    if (_prefs == null) return;

    final keys = _prefs!.getKeys();
    final now = DateTime.now();

    for (final key in keys) {
      // Skip non-setting keys
      if (key.startsWith('_') || key.contains('temp_')) continue;

      try {
        final value = _prefs!.get(key);
        if (value != null) {
          final settingType = _inferSettingType(value);
          final category = _inferSettingCategory(key);

          final setting = AppSettings(
            key: key,
            value: value.toString(),
            type: settingType,
            category: category,
            description: _getSettingDescription(key),
            isSensitive: _isSettingSensitive(key),
            createdAt: now,
            updatedAt: now,
          );

          _cachedSettings[key] = setting;
        }
      } catch (e) {
        log('SettingsService: Error loading setting $key: $e');
      }
    }

    // Ensure all default settings exist
    await _ensureDefaultSettings();
  }

  /// Ensure all default settings are created if they don't exist
  Future<void> _ensureDefaultSettings() async {
    for (final entry in _defaultValues.entries) {
      if (!_cachedSettings.containsKey(entry.key)) {
        await _createDefaultSetting(entry.key, entry.value);
      }
    }
  }

  /// Create a default setting
  Future<void> _createDefaultSetting(String key, dynamic value) async {
    final settingType = _inferSettingType(value);
    final category = _inferSettingCategory(key);
    final now = DateTime.now();

    final setting = AppSettings(
      key: key,
      value: value.toString(),
      type: settingType,
      category: category,
      description: _getSettingDescription(key),
      isSensitive: _isSettingSensitive(key),
      createdAt: now,
      updatedAt: now,
    );

    _cachedSettings[key] = setting;
    await _persistSetting(setting);
  }

  /// Infer setting type from value
  SettingType _inferSettingType(dynamic value) {
    if (value is bool) return SettingType.bool;
    if (value is int) return SettingType.int;
    if (value is double) return SettingType.double;
    if (value is String) {
      // Try to parse as JSON for complex objects
      try {
        json.decode(value);
        return SettingType.json;
      } catch (_) {
        return SettingType.string;
      }
    }
    return SettingType.string;
  }

  /// Infer setting category from key
  SettingCategory _inferSettingCategory(String key) {
    final lowercaseKey = key.toLowerCase();

    if (lowercaseKey.contains('audio') || lowercaseKey.contains('recording')) {
      return SettingCategory.audio;
    }
    if (lowercaseKey.contains('transcription') ||
        lowercaseKey.contains('whisper')) {
      return SettingCategory.transcription;
    }
    if (lowercaseKey.contains('summary') ||
        lowercaseKey.contains('summarize')) {
      return SettingCategory.summary;
    }
    if (lowercaseKey.contains('theme') ||
        lowercaseKey.contains('ui') ||
        lowercaseKey.contains('waveform')) {
      return SettingCategory.ui;
    }
    if (lowercaseKey.contains('security') ||
        lowercaseKey.contains('encrypt') ||
        lowercaseKey.contains('lock')) {
      return SettingCategory.security;
    }
    if (lowercaseKey.contains('storage') ||
        lowercaseKey.contains('backup') ||
        lowercaseKey.contains('cleanup')) {
      return SettingCategory.storage;
    }

    return SettingCategory.general;
  }

  /// Get human-readable description for a setting
  String? _getSettingDescription(String key) {
    final descriptions = {
      SettingKeys.audioFormat: 'Audio file format for recordings',
      SettingKeys.audioQuality: 'Quality level for audio recordings',
      SettingKeys.recordingLimit: 'Maximum recording duration in seconds',
      SettingKeys.enableNoiseReduction:
          'Reduce background noise during recording',
      SettingKeys.enableAutoGainControl:
          'Automatically adjust recording volume',
      SettingKeys.transcriptionLanguage:
          'Language for speech-to-text conversion',
      SettingKeys.transcriptionProvider: 'Service provider for transcription',
      SettingKeys.autoTranscribe: 'Automatically transcribe recordings',
      SettingKeys.summaryType: 'Type of summary to generate',
      SettingKeys.autoSummarize: 'Automatically generate summaries',
      SettingKeys.themeMode: 'App theme preference (light, dark, system)',
      SettingKeys.waveformEnabled: 'Show audio waveform visualization',
      SettingKeys.firstLaunch:
          'Flag indicating if this is the first app launch',
      SettingKeys.encryptRecordings: 'Encrypt audio recordings on device',
      SettingKeys.autoLockTimeout:
          'Time before app locks automatically (seconds)',
      SettingKeys.maxStorageSize: 'Maximum storage size for recordings (MB)',
      SettingKeys.autoCleanup: 'Automatically delete old recordings',
      SettingKeys.backupEnabled: 'Enable cloud backup of recordings',
      'notification_enabled': 'Enable push notifications',
      'notification_sound': 'Play sound for notifications',
      'notification_vibration': 'Vibrate for notifications',
      'data_collection_analytics': 'Allow anonymous analytics collection',
      'data_collection_crash_reports': 'Send crash reports to improve the app',
      'cloud_sync_enabled': 'Enable cloud synchronization',
      'developer_mode': 'Enable developer features and debugging',
    };

    return descriptions[key];
  }

  /// Check if a setting contains sensitive data
  bool _isSettingSensitive(String key) {
    final sensitiveKeys = {
      'api_key',
      'password',
      'token',
      'secret',
      'auth',
      'user_id',
      'email',
      'phone',
      'location',
    };

    final lowercaseKey = key.toLowerCase();
    return sensitiveKeys.any((sensitive) => lowercaseKey.contains(sensitive));
  }

  /// Persist a setting to shared preferences
  Future<void> _persistSetting(AppSettings setting) async {
    if (_prefs == null) throw Exception('SettingsService not initialized');

    try {
      switch (setting.type) {
        case SettingType.bool:
          await _prefs!.setBool(setting.key, setting.getValue<bool>());
          break;
        case SettingType.int:
          await _prefs!.setInt(setting.key, setting.getValue<int>());
          break;
        case SettingType.double:
          await _prefs!.setDouble(setting.key, setting.getValue<double>());
          break;
        case SettingType.string:
        case SettingType.json:
          await _prefs!.setString(setting.key, setting.value);
          break;
      }
      log('SettingsService: Persisted setting ${setting.key}');
    } catch (e) {
      log('SettingsService: Error persisting setting ${setting.key}: $e');
      throw Exception('Failed to persist setting: $e');
    }
  }

  /// Get a setting value with type safety
  T? getSetting<T>(String key) {
    final setting = _cachedSettings[key];
    if (setting == null) {
      // Return default value if available
      final defaultValue = _defaultValues[key];
      return defaultValue is T ? defaultValue : null;
    }

    try {
      return setting.getValue<T>();
    } catch (e) {
      log('SettingsService: Error getting setting $key: $e');
      return null;
    }
  }

  /// Set a setting value
  Future<void> setSetting<T>(
    String key,
    T value, {
    SettingCategory? category,
  }) async {
    final settingType = _inferSettingType(value);
    final settingCategory = category ?? _inferSettingCategory(key);
    final now = DateTime.now();

    final existingSetting = _cachedSettings[key];
    final setting = AppSettings(
      key: key,
      value: value.toString(),
      type: settingType,
      category: settingCategory,
      description: _getSettingDescription(key),
      isSensitive: _isSettingSensitive(key),
      createdAt: existingSetting?.createdAt ?? now,
      updatedAt: now,
    );

    _cachedSettings[key] = setting;
    await _persistSetting(setting);
    log('SettingsService: Updated setting $key = $value');
  }

  /// Get all settings in a category
  List<AppSettings> getSettingsByCategory(SettingCategory category) {
    return _cachedSettings.values
        .where((setting) => setting.category == category)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
  }

  /// Get all settings
  List<AppSettings> getAllSettings() {
    return _cachedSettings.values.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
  }

  /// Search settings by key or description
  List<AppSettings> searchSettings(String query) {
    if (query.isEmpty) return getAllSettings();

    final lowercaseQuery = query.toLowerCase();
    return _cachedSettings.values
        .where(
          (setting) =>
              setting.key.toLowerCase().contains(lowercaseQuery) ||
              (setting.description?.toLowerCase().contains(lowercaseQuery) ??
                  false),
        )
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
  }

  /// Validate setting value
  bool validateSetting(String key, dynamic value) {
    try {
      // Custom validation rules for specific keys come first
      if (key == SettingKeys.audioQuality ||
          key == SettingKeys.audioFormat ||
          key == SettingKeys.themeMode ||
          key == SettingKeys.recordingLimit ||
          key == SettingKeys.autoLockTimeout ||
          key == SettingKeys.maxStorageSize) {
        return _validateSettingRules(key, value);
      }

      // Generic type-based validation for other keys
      final inferredType = _inferSettingType(value);
      switch (inferredType) {
        case SettingType.bool:
          if (value is! bool) return false;
          break;
        case SettingType.int:
          if (value is! int) return false;
          break;
        case SettingType.double:
          if (value is! double && value is! int) return false;
          break;
        case SettingType.string:
          if (value is! String) return false;
          break;
        case SettingType.json:
          if (value is String) {
            try {
              json.decode(value);
            } catch (_) {
              return false;
            }
          }
          break;
      }

      // Apply custom validation rules
      return _validateSettingRules(key, value);
    } catch (e) {
      log('SettingsService: Validation error for $key: $e');
      return false;
    }
  }

  /// Apply custom validation rules
  bool _validateSettingRules(String key, dynamic value) {
    switch (key) {
      case SettingKeys.audioQuality:
        return ['low', 'medium', 'high', 'highest'].contains(value);
      case SettingKeys.audioFormat:
        return ['m4a', 'wav', 'mp3', 'aac'].contains(value);
      case SettingKeys.themeMode:
        return ['light', 'dark', 'system'].contains(value);
      case SettingKeys.recordingLimit:
        return value is int && value > 0 && value <= 14400; // Max 4 hours
      case SettingKeys.autoLockTimeout:
        return value is int && value >= 30; // Min 30 seconds
      case SettingKeys.maxStorageSize:
        return value is int && value > 0; // Must be positive
      default:
        return true; // No specific rules
    }
  }

  /// Reset a setting to its default value
  Future<void> resetSetting(String key) async {
    final defaultValue = _defaultValues[key];
    if (defaultValue != null) {
      await setSetting(key, defaultValue);
      log('SettingsService: Reset setting $key to default value');
    } else {
      await removeSetting(key);
      log('SettingsService: Removed setting $key (no default value)');
    }
  }

  /// Remove a setting
  Future<void> removeSetting(String key) async {
    if (_prefs == null) throw Exception('SettingsService not initialized');

    _cachedSettings.remove(key);
    await _prefs!.remove(key);
    log('SettingsService: Removed setting $key');
  }

  /// Reset all settings to defaults
  Future<void> resetAllSettings() async {
    if (_prefs == null) throw Exception('SettingsService not initialized');

    await _prefs!.clear();
    _cachedSettings.clear();
    await _ensureDefaultSettings();
    log('SettingsService: Reset all settings to defaults');
  }

  /// Export settings as JSON
  Map<String, dynamic> exportSettings({bool includeSensitive = false}) {
    final export = <String, dynamic>{};

    for (final setting in _cachedSettings.values) {
      if (!includeSensitive && setting.isSensitive) continue;

      export[setting.key] = {
        'value': setting.getValue(),
        'type': setting.type.value,
        'category': setting.category.value,
        'description': setting.description,
        'created_at': setting.createdAt.toIso8601String(),
        'updated_at': setting.updatedAt.toIso8601String(),
      };
    }

    return {
      'version': '1.0',
      'export_date': DateTime.now().toIso8601String(),
      'settings': export,
    };
  }

  /// Import settings from JSON
  Future<int> importSettings(
    Map<String, dynamic> data, {
    bool overwriteExisting = false,
  }) async {
    if (data['settings'] is! Map<String, dynamic>) {
      throw Exception('Invalid settings data format');
    }

    final settings = data['settings'] as Map<String, dynamic>;
    int importedCount = 0;

    for (final entry in settings.entries) {
      final key = entry.key;
      final settingData = entry.value as Map<String, dynamic>;

      // Skip if setting exists and overwrite is not enabled
      if (!overwriteExisting && _cachedSettings.containsKey(key)) {
        continue;
      }

      try {
        final value = settingData['value'];
        final category = SettingCategory.fromString(
          settingData['category'] ?? 'general',
        );

        if (validateSetting(key, value)) {
          await setSetting(key, value, category: category);
          importedCount++;
        } else {
          log('SettingsService: Skipped invalid setting during import: $key');
        }
      } catch (e) {
        log('SettingsService: Error importing setting $key: $e');
      }
    }

    log('SettingsService: Imported $importedCount settings');
    return importedCount;
  }

  /// Get setting with fallback to default
  T getSettingWithDefault<T>(String key, T defaultValue) {
    return getSetting<T>(key) ?? defaultValue;
  }

  /// Check if a setting exists
  bool hasSetting(String key) {
    return _cachedSettings.containsKey(key);
  }

  /// Get setting metadata
  AppSettings? getSettingMetadata(String key) {
    return _cachedSettings[key];
  }

  /// Get settings count by category
  Map<SettingCategory, int> getSettingsCountByCategory() {
    final counts = <SettingCategory, int>{};

    for (final category in SettingCategory.values) {
      counts[category] = getSettingsByCategory(category).length;
    }

    return counts;
  }

  /// Clear cache and reload from storage
  Future<void> refresh() async {
    _cachedSettings.clear();
    await _loadAllSettings();
    log('SettingsService: Refreshed settings cache');
  }

  /// Dispose resources
  void dispose() {
    _cachedSettings.clear();
    _prefs = null;
  }

  /// Clear singleton instance (for testing only)
  @visibleForTesting
  static void clearInstance() {
    _instance = null;
  }
}
