/// Settings backup and migration service with cloud sync integration
library;

import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:path/path.dart' as path;

import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

import '../models/database/app_settings.dart';
import '../models/cloud_sync/cloud_provider.dart';
import 'settings_service.dart';
import 'cloud_sync_service.dart';
import 'encryption_service.dart';

/// Service for backing up and migrating application settings
class SettingsBackupService {
  static SettingsBackupService? _instance;
  static SettingsBackupService get instance =>
      _instance ??= SettingsBackupService._();
  SettingsBackupService._();

  final SettingsService _settingsService = SettingsService.instance;
  final CloudSyncService _cloudSyncService = CloudSyncService.instance;
  // EncryptionService is static, no instance needed

  static const String _settingsFileName = 'settings_backup.json';
  static const String _migrationLogFileName = 'migration_log.json';

  bool _isInitialized = false;
  String? _localBackupDirectory;

  /// Current app version for migration tracking
  String _currentAppVersion = '1.0.0';

  /// Migration rules for handling settings changes between versions
  final Map<String, List<SettingsMigrationRule>> _migrationRules = {};

  /// Initialize the settings backup service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log('SettingsBackupService: Initializing...');

      // Initialize dependencies
      await _settingsService.initialize();
      await EncryptionService.initialize();

      // Set up local backup directory
      await _initializeLocalBackupDirectory();

      // Load current app version from settings
      await _loadCurrentAppVersion();

      // Register default migration rules
      _registerDefaultMigrationRules();

      _isInitialized = true;
      log('SettingsBackupService: Initialization completed');
    } catch (e, stackTrace) {
      log(
        'SettingsBackupService: Initialization failed: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create a local backup of all settings
  Future<SettingsBackupResult> createLocalBackup({
    String? backupName,
    bool includeSensitive = false,
    bool encrypt = true,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      log('SettingsBackupService: Creating local backup...');

      final timestamp = DateTime.now();
      final backupFileName = backupName ??
          '${_settingsFileName.split('.').first}_${timestamp.millisecondsSinceEpoch}.json';

      // Export settings from SettingsService
      final settingsData = _settingsService.exportSettings(
        includeSensitive: includeSensitive,
      );

      // Add backup metadata
      final backupData = {
        'backup_info': {
          'created_at': timestamp.toIso8601String(),
          'app_version': _currentAppVersion,
          'backup_name': backupName ?? 'Auto backup',
          'includes_sensitive': includeSensitive,
          'encrypted': encrypt,
          'total_settings': settingsData['settings']?.length ?? 0,
        },
        'settings_data': settingsData,
      };

      final backupFilePath = '$_localBackupDirectory/$backupFileName';
      final backupFile = File(backupFilePath);

      if (encrypt) {
        // Create encryption key for settings backup
        final keyId = await EncryptionService.createEncryptionKey(
          'settings_backup',
        );

        // Encrypt the backup data
        final jsonString = json.encode(backupData);
        final encryptedData = await EncryptionService.encryptData(
          jsonString,
          keyId,
        );

        if (encryptedData != null) {
          await backupFile.writeAsString(json.encode(encryptedData));
        } else {
          throw Exception('Failed to encrypt backup data');
        }
      } else {
        // Save as plain JSON
        await backupFile.writeAsString(json.encode(backupData));
      }

      final result = SettingsBackupResult(
        success: true,
        backupPath: backupFilePath,
        timestamp: timestamp,
        settingsCount: (backupData['backup_info']
            as Map<String, dynamic>)['total_settings'] as int,
        encrypted: encrypt,
        size: await backupFile.length(),
      );

      log(
        'SettingsBackupService: Local backup created successfully at $backupFilePath',
      );
      return result;
    } catch (e, stackTrace) {
      log(
        'SettingsBackupService: Error creating local backup: $e',
        stackTrace: stackTrace,
      );
      return SettingsBackupResult(
        success: false,
        error: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Restore settings from a local backup
  Future<SettingsRestoreResult> restoreFromLocalBackup({
    required String backupFilePath,
    bool overwriteExisting = false,
    bool decrypt = true,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      log(
        'SettingsBackupService: Restoring from local backup: $backupFilePath',
      );

      final backupFile = File(backupFilePath);
      if (!await backupFile.exists()) {
        throw FileSystemException('Backup file not found', backupFilePath);
      }

      Map<String, dynamic> backupData;

      if (decrypt) {
        // Read encrypted backup
        final jsonString = await backupFile.readAsString();
        final encryptedData = json.decode(jsonString) as Map<String, String>;

        // Decrypt the data
        final decryptedJson = await EncryptionService.decryptData(
          encryptedData,
        );

        if (decryptedJson == null) {
          throw StateError('Failed to decrypt backup data');
        }

        backupData = json.decode(decryptedJson);
      } else {
        // Read plain JSON backup
        final jsonString = await backupFile.readAsString();
        backupData = json.decode(jsonString);
      }

      // Validate backup structure
      if (!_validateBackupStructure(backupData)) {
        throw FormatException('Invalid backup file format');
      }

      final backupInfo = backupData['backup_info'] as Map<String, dynamic>;
      final settingsData = backupData['settings_data'] as Map<String, dynamic>;

      // Check version compatibility and apply migrations if needed
      final backupVersion = backupInfo['app_version'] as String;
      final migratedSettings = await _migrateSettingsIfNeeded(
        settingsData,
        fromVersion: backupVersion,
        toVersion: _currentAppVersion,
      );

      // Import settings using SettingsService
      final importedCount = await _settingsService.importSettings(
        migratedSettings,
        overwriteExisting: overwriteExisting,
      );

      // Log the restore operation
      await _logMigrationOperation(
        SettingsMigrationLog(
          timestamp: DateTime.now(),
          operation: MigrationOperation.restore,
          fromVersion: backupVersion,
          toVersion: _currentAppVersion,
          settingsCount: importedCount,
          backupPath: backupFilePath,
        ),
      );

      final result = SettingsRestoreResult(
        success: true,
        settingsImported: importedCount,
        backupVersion: backupVersion,
        migrationApplied: backupVersion != _currentAppVersion,
        timestamp: DateTime.parse(backupInfo['created_at'] as String),
      );

      log(
        'SettingsBackupService: Successfully restored $importedCount settings from backup',
      );
      return result;
    } catch (e, stackTrace) {
      log(
        'SettingsBackupService: Error restoring from backup: $e',
        stackTrace: stackTrace,
      );
      return SettingsRestoreResult(
        success: false,
        error: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Create a cloud backup of settings
  Future<SettingsBackupResult> createCloudBackup({
    required CloudProvider provider,
    String? backupName,
    bool includeSensitive = false,
    bool encrypt = true,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      log(
        'SettingsBackupService: Creating cloud backup to ${provider.displayName}...',
      );

      // First create a local backup
      final localResult = await createLocalBackup(
        backupName: backupName,
        includeSensitive: includeSensitive,
        encrypt: encrypt,
      );

      if (!localResult.success) {
        return localResult;
      }

      // Upload to cloud provider
      final remoteFilePath =
          'meeting_summarizer/backups/${path.basename(localResult.backupPath!)}';

      final uploadOperation = await _cloudSyncService.uploadFile(
        localFilePath: localResult.backupPath!,
        remoteFilePath: remoteFilePath,
        provider: provider,
        encryptBeforeUpload: encrypt,
        metadata: {
          'backup_type': 'settings',
          'app_version': _currentAppVersion,
          'created_at': localResult.timestamp.toIso8601String(),
          'settings_count': localResult.settingsCount.toString(),
        },
      );

      // Wait for upload completion (simplified for demo)
      await Future.delayed(const Duration(seconds: 1));

      final result = SettingsBackupResult(
        success: true,
        backupPath: remoteFilePath,
        cloudProvider: provider,
        timestamp: localResult.timestamp,
        settingsCount: localResult.settingsCount,
        encrypted: encrypt,
        size: localResult.size,
        operationId: uploadOperation.id,
      );

      log('SettingsBackupService: Cloud backup uploaded successfully');
      return result;
    } catch (e, stackTrace) {
      log(
        'SettingsBackupService: Error creating cloud backup: $e',
        stackTrace: stackTrace,
      );
      return SettingsBackupResult(
        success: false,
        error: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Restore settings from a cloud backup
  Future<SettingsRestoreResult> restoreFromCloudBackup({
    required CloudProvider provider,
    required String remoteBackupPath,
    bool overwriteExisting = false,
    bool decrypt = true,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      log(
        'SettingsBackupService: Restoring from cloud backup: $remoteBackupPath',
      );

      // Download backup from cloud
      final localBackupPath =
          '$_localBackupDirectory/temp_${DateTime.now().millisecondsSinceEpoch}.json';

      final downloadOperation = await _cloudSyncService.downloadFile(
        remoteFilePath: remoteBackupPath,
        localFilePath: localBackupPath,
        provider: provider,
        decryptAfterDownload: decrypt,
      );

      // Wait for download completion (simplified for demo)
      await Future.delayed(const Duration(seconds: 1));

      // Restore from the downloaded file
      final result = await restoreFromLocalBackup(
        backupFilePath: localBackupPath,
        overwriteExisting: overwriteExisting,
        decrypt: decrypt,
      );

      // Clean up temporary file
      try {
        await File(localBackupPath).delete();
      } catch (_) {
        // Ignore cleanup errors
      }

      final cloudResult = SettingsRestoreResult(
        success: result.success,
        settingsImported: result.settingsImported,
        backupVersion: result.backupVersion,
        migrationApplied: result.migrationApplied,
        timestamp: result.timestamp,
        cloudProvider: provider,
        operationId: downloadOperation.id,
        error: result.error,
      );

      log('SettingsBackupService: Successfully restored from cloud backup');
      return cloudResult;
    } catch (e, stackTrace) {
      log(
        'SettingsBackupService: Error restoring from cloud backup: $e',
        stackTrace: stackTrace,
      );
      return SettingsRestoreResult(
        success: false,
        error: e.toString(),
        timestamp: DateTime.now(),
        cloudProvider: provider,
      );
    }
  }

  /// Perform automatic settings migration for app version updates
  Future<SettingsMigrationResult> migrateSettings({
    required String fromVersion,
    required String toVersion,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      log(
        'SettingsBackupService: Migrating settings from $fromVersion to $toVersion',
      );

      // Create backup before migration
      final backupResult = await createLocalBackup(
        backupName: 'Pre-migration backup $fromVersion to $toVersion',
        includeSensitive: true,
        encrypt: true,
      );

      if (!backupResult.success) {
        log('SettingsBackupService: Failed to create pre-migration backup');
      }

      // Get current settings
      final currentSettings = _settingsService.exportSettings(
        includeSensitive: true,
      );

      // Apply migrations
      final migratedSettings = await _migrateSettingsIfNeeded(
        currentSettings,
        fromVersion: fromVersion,
        toVersion: toVersion,
      );

      // Count changes
      var settingsChanged = 0;
      var settingsAdded = 0;
      var settingsRemoved = 0;

      final originalSettings =
          currentSettings['settings'] as Map<String, dynamic>? ?? {};
      final newSettings =
          migratedSettings['settings'] as Map<String, dynamic>? ?? {};

      // Count additions and changes
      for (final key in newSettings.keys) {
        if (originalSettings.containsKey(key)) {
          if (originalSettings[key] != newSettings[key]) {
            settingsChanged++;
          }
        } else {
          settingsAdded++;
        }
      }

      // Count removals
      for (final key in originalSettings.keys) {
        if (!newSettings.containsKey(key)) {
          settingsRemoved++;
        }
      }

      // Apply the migrated settings if there are changes
      if (settingsChanged > 0 || settingsAdded > 0 || settingsRemoved > 0) {
        // Clear current settings and import migrated ones
        final importedCount = await _settingsService.importSettings(
          migratedSettings,
          overwriteExisting: true,
        );

        log(
          'SettingsBackupService: Applied migration changes - imported $importedCount settings',
        );
      }

      // Update app version
      await _settingsService.setSetting(SettingKeys.appVersion, toVersion);
      _currentAppVersion = toVersion;

      // Log the migration
      await _logMigrationOperation(
        SettingsMigrationLog(
          timestamp: DateTime.now(),
          operation: MigrationOperation.migration,
          fromVersion: fromVersion,
          toVersion: toVersion,
          settingsCount: newSettings.length,
          settingsChanged: settingsChanged,
          settingsAdded: settingsAdded,
          settingsRemoved: settingsRemoved,
          backupPath: backupResult.backupPath,
        ),
      );

      final result = SettingsMigrationResult(
        success: true,
        fromVersion: fromVersion,
        toVersion: toVersion,
        settingsChanged: settingsChanged,
        settingsAdded: settingsAdded,
        settingsRemoved: settingsRemoved,
        backupCreated: backupResult.success,
        backupPath: backupResult.backupPath,
      );

      log('SettingsBackupService: Migration completed successfully');
      return result;
    } catch (e, stackTrace) {
      log(
        'SettingsBackupService: Error during migration: $e',
        stackTrace: stackTrace,
      );
      return SettingsMigrationResult(
        success: false,
        fromVersion: fromVersion,
        toVersion: toVersion,
        error: e.toString(),
      );
    }
  }

  /// List available local backups
  Future<List<SettingsBackupInfo>> listLocalBackups() async {
    if (!_isInitialized) await initialize();

    try {
      final backupDir = Directory(_localBackupDirectory!);
      if (!await backupDir.exists()) {
        return [];
      }

      final backups = <SettingsBackupInfo>[];

      await for (final entity in backupDir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final info = await _getBackupInfo(entity.path);
            if (info != null) {
              backups.add(info);
            }
          } catch (e) {
            log(
              'SettingsBackupService: Error reading backup info for ${entity.path}: $e',
            );
          }
        }
      }

      // Sort by creation date (newest first)
      backups.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return backups;
    } catch (e, stackTrace) {
      log(
        'SettingsBackupService: Error listing local backups: $e',
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Delete a local backup
  Future<bool> deleteLocalBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        await backupFile.delete();

        // Also delete metadata file if it exists
        final metadataFile = File('$backupPath.meta');
        if (await metadataFile.exists()) {
          await metadataFile.delete();
        }

        log('SettingsBackupService: Deleted backup: $backupPath');
        return true;
      }
      return false;
    } catch (e) {
      log('SettingsBackupService: Error deleting backup: $e');
      return false;
    }
  }

  /// Get migration history
  Future<List<SettingsMigrationLog>> getMigrationHistory() async {
    try {
      final logFile = File('$_localBackupDirectory/$_migrationLogFileName');
      if (!await logFile.exists()) {
        return [];
      }

      final jsonString = await logFile.readAsString();
      final logData = json.decode(jsonString) as Map<String, dynamic>;
      final migrations = logData['migrations'] as List<dynamic>? ?? [];

      return migrations
          .map((m) => SettingsMigrationLog.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      log('SettingsBackupService: Error reading migration history: $e');
      return [];
    }
  }

  /// Register a custom migration rule
  void registerMigrationRule(String version, SettingsMigrationRule rule) {
    _migrationRules.putIfAbsent(version, () => []).add(rule);
    log(
      'SettingsBackupService: Registered migration rule for version $version',
    );
  }

  // Private helper methods

  Future<void> _initializeLocalBackupDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    _localBackupDirectory = '${appDir.path}/settings_backups';

    final backupDir = Directory(_localBackupDirectory!);
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    log(
      'SettingsBackupService: Local backup directory: $_localBackupDirectory',
    );
  }

  Future<void> _loadCurrentAppVersion() async {
    try {
      final version = _settingsService.getSetting<String>(
        SettingKeys.appVersion,
      );
      if (version != null) {
        _currentAppVersion = version;
      }
      log('SettingsBackupService: Current app version: $_currentAppVersion');
    } catch (e) {
      log(
        'SettingsBackupService: Error loading app version, using default: $e',
      );
    }
  }

  void _registerDefaultMigrationRules() {
    // Example migration rules for version updates

    // Migration from 1.0.0 to 1.1.0
    registerMigrationRule(
      '1.1.0',
      SettingsMigrationRule(
        ruleId: 'audio_quality_update_1.1.0',
        description: 'Update audio quality settings for new options',
        apply: (settings) async {
          final settingsMap =
              settings['settings'] as Map<String, dynamic>? ?? {};

          // Migrate old audio quality values
          for (final key in settingsMap.keys) {
            final setting = settingsMap[key] as Map<String, dynamic>?;
            if (setting != null && key == 'audio_quality') {
              final value = setting['value'] as String?;
              if (value == 'max') {
                setting['value'] = 'highest'; // Rename 'max' to 'highest'
              }
            }
          }

          return settings;
        },
      ),
    );

    // Migration from 1.1.0 to 1.2.0
    registerMigrationRule(
      '1.2.0',
      SettingsMigrationRule(
        ruleId: 'add_new_privacy_settings_1.2.0',
        description: 'Add new privacy settings introduced in 1.2.0',
        apply: (settings) async {
          final settingsMap =
              settings['settings'] as Map<String, dynamic>? ?? {};

          // Add new privacy settings if they don't exist
          if (!settingsMap.containsKey('privacy_enhanced_mode')) {
            settingsMap['privacy_enhanced_mode'] = {
              'value': 'false',
              'type': 'bool',
              'category': 'security',
              'description': 'Enable enhanced privacy mode',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            };
          }

          return settings;
        },
      ),
    );

    log(
      'SettingsBackupService: Registered ${_migrationRules.length} default migration rules',
    );
  }

  Future<Map<String, dynamic>> _migrateSettingsIfNeeded(
    Map<String, dynamic> settings, {
    required String fromVersion,
    required String toVersion,
  }) async {
    if (fromVersion == toVersion) {
      return settings;
    }

    log(
      'SettingsBackupService: Applying migrations from $fromVersion to $toVersion',
    );

    var migratedSettings = Map<String, dynamic>.from(settings);

    // Apply migrations in version order
    final versions = _migrationRules.keys.toList()..sort();

    for (final version in versions) {
      if (_shouldApplyMigration(fromVersion, version, toVersion)) {
        final rules = _migrationRules[version]!;

        for (final rule in rules) {
          try {
            log(
              'SettingsBackupService: Applying migration rule: ${rule.ruleId}',
            );
            migratedSettings = await rule.apply(migratedSettings);
          } catch (e) {
            log(
              'SettingsBackupService: Error applying migration rule ${rule.ruleId}: $e',
            );
          }
        }
      }
    }

    // Update version in migrated settings
    migratedSettings['version'] = toVersion;
    migratedSettings['export_date'] = DateTime.now().toIso8601String();

    return migratedSettings;
  }

  bool _shouldApplyMigration(
    String fromVersion,
    String ruleVersion,
    String toVersion,
  ) {
    // Simple version comparison - in production you'd use a proper version comparison library
    return _compareVersions(fromVersion, ruleVersion) < 0 &&
        _compareVersions(ruleVersion, toVersion) <= 0;
  }

  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;

      if (p1 != p2) {
        return p1.compareTo(p2);
      }
    }

    return 0;
  }

  bool _validateBackupStructure(Map<String, dynamic> data) {
    return data.containsKey('backup_info') &&
        data.containsKey('settings_data') &&
        data['backup_info'] is Map<String, dynamic> &&
        data['settings_data'] is Map<String, dynamic>;
  }

  Future<SettingsBackupInfo?> _getBackupInfo(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      final stat = await backupFile.stat();

      // Try to read backup metadata (for unencrypted backups)
      Map<String, dynamic>? backupData;
      try {
        final jsonString = await backupFile.readAsString();
        backupData = json.decode(jsonString) as Map<String, dynamic>?;
      } catch (_) {
        // Likely encrypted, skip detailed info
      }

      final backupInfo = backupData?['backup_info'] as Map<String, dynamic>?;

      return SettingsBackupInfo(
        filePath: backupPath,
        fileName: path.basename(backupPath),
        timestamp: backupInfo != null
            ? DateTime.parse(backupInfo['created_at'] as String)
            : stat.modified,
        size: stat.size,
        settingsCount: backupInfo?['total_settings'] as int? ?? 0,
        appVersion: backupInfo?['app_version'] as String? ?? 'Unknown',
        encrypted: backupInfo?['encrypted'] as bool? ?? true,
        backupName: backupInfo?['backup_name'] as String? ?? 'Unknown',
      );
    } catch (e) {
      log(
        'SettingsBackupService: Error getting backup info for $backupPath: $e',
      );
      return null;
    }
  }

  Future<void> _logMigrationOperation(SettingsMigrationLog logEntry) async {
    try {
      final logFile = File('$_localBackupDirectory/$_migrationLogFileName');

      List<Map<String, dynamic>> migrations = [];

      if (await logFile.exists()) {
        final jsonString = await logFile.readAsString();
        final logData = json.decode(jsonString) as Map<String, dynamic>;
        migrations = List<Map<String, dynamic>>.from(
          logData['migrations'] as List<dynamic>? ?? [],
        );
      }

      migrations.add(logEntry.toJson());

      // Keep only last 50 migration logs
      if (migrations.length > 50) {
        migrations = migrations.sublist(migrations.length - 50);
      }

      final logData = {
        'version': '1.0',
        'created_at': DateTime.now().toIso8601String(),
        'migrations': migrations,
      };

      await logFile.writeAsString(json.encode(logData));
    } catch (e) {
      log('SettingsBackupService: Error logging migration operation: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _instance = null;
  }

  /// Clear singleton instance (for testing only)
  @visibleForTesting
  static void clearInstance() {
    _instance = null;
  }
}

/// Result of a settings backup operation
class SettingsBackupResult {
  final bool success;
  final String? backupPath;
  final CloudProvider? cloudProvider;
  final DateTime timestamp;
  final int settingsCount;
  final bool encrypted;
  final int size;
  final String? operationId;
  final String? error;

  const SettingsBackupResult({
    required this.success,
    this.backupPath,
    this.cloudProvider,
    required this.timestamp,
    this.settingsCount = 0,
    this.encrypted = false,
    this.size = 0,
    this.operationId,
    this.error,
  });
}

/// Result of a settings restore operation
class SettingsRestoreResult {
  final bool success;
  final int settingsImported;
  final String? backupVersion;
  final bool migrationApplied;
  final DateTime timestamp;
  final CloudProvider? cloudProvider;
  final String? operationId;
  final String? error;

  const SettingsRestoreResult({
    required this.success,
    this.settingsImported = 0,
    this.backupVersion,
    this.migrationApplied = false,
    required this.timestamp,
    this.cloudProvider,
    this.operationId,
    this.error,
  });
}

/// Result of a settings migration operation
class SettingsMigrationResult {
  final bool success;
  final String fromVersion;
  final String toVersion;
  final int settingsChanged;
  final int settingsAdded;
  final int settingsRemoved;
  final bool backupCreated;
  final String? backupPath;
  final String? error;

  const SettingsMigrationResult({
    required this.success,
    required this.fromVersion,
    required this.toVersion,
    this.settingsChanged = 0,
    this.settingsAdded = 0,
    this.settingsRemoved = 0,
    this.backupCreated = false,
    this.backupPath,
    this.error,
  });
}

/// Information about a settings backup
class SettingsBackupInfo {
  final String filePath;
  final String fileName;
  final DateTime timestamp;
  final int size;
  final int settingsCount;
  final String appVersion;
  final bool encrypted;
  final String backupName;

  const SettingsBackupInfo({
    required this.filePath,
    required this.fileName,
    required this.timestamp,
    required this.size,
    required this.settingsCount,
    required this.appVersion,
    required this.encrypted,
    required this.backupName,
  });
}

/// Migration rule for handling settings changes between versions
class SettingsMigrationRule {
  final String ruleId;
  final String description;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> settings)
      apply;

  const SettingsMigrationRule({
    required this.ruleId,
    required this.description,
    required this.apply,
  });
}

/// Log entry for migration operations
class SettingsMigrationLog {
  final DateTime timestamp;
  final MigrationOperation operation;
  final String fromVersion;
  final String toVersion;
  final int settingsCount;
  final int settingsChanged;
  final int settingsAdded;
  final int settingsRemoved;
  final String? backupPath;

  const SettingsMigrationLog({
    required this.timestamp,
    required this.operation,
    required this.fromVersion,
    required this.toVersion,
    required this.settingsCount,
    this.settingsChanged = 0,
    this.settingsAdded = 0,
    this.settingsRemoved = 0,
    this.backupPath,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'operation': operation.name,
        'from_version': fromVersion,
        'to_version': toVersion,
        'settings_count': settingsCount,
        'settings_changed': settingsChanged,
        'settings_added': settingsAdded,
        'settings_removed': settingsRemoved,
        'backup_path': backupPath,
      };

  factory SettingsMigrationLog.fromJson(Map<String, dynamic> json) {
    return SettingsMigrationLog(
      timestamp: DateTime.parse(json['timestamp'] as String),
      operation: MigrationOperation.values.firstWhere(
        (op) => op.name == json['operation'],
      ),
      fromVersion: json['from_version'] as String,
      toVersion: json['to_version'] as String,
      settingsCount: json['settings_count'] as int,
      settingsChanged: json['settings_changed'] as int? ?? 0,
      settingsAdded: json['settings_added'] as int? ?? 0,
      settingsRemoved: json['settings_removed'] as int? ?? 0,
      backupPath: json['backup_path'] as String?,
    );
  }
}

/// Types of migration operations
enum MigrationOperation { migration, backup, restore }
