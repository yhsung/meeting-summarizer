import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:meeting_summarizer/core/services/settings_backup_service.dart';
import 'package:meeting_summarizer/core/services/settings_service.dart';
import 'package:meeting_summarizer/core/models/database/app_settings.dart';

import '../../mocks/mock_services.mocks.dart';

void main() {
  group('SettingsBackupService', () {
    late SettingsBackupService backupService;
    late MockSettingsService mockSettingsService;
    late Directory tempDir;

    setUpAll(() async {
      // Create temporary directory for tests
      tempDir = await Directory.systemTemp.createTemp('settings_backup_test');
    });

    setUp(() async {
      // Clear singleton instances
      SettingsBackupService.clearInstance();
      SettingsService.clearInstance();

      // Create mocks
      mockSettingsService = MockSettingsService();

      // Set up test directory
      final testDir = Directory(
        '${tempDir.path}/test_${DateTime.now().millisecondsSinceEpoch}',
      );
      await testDir.create(recursive: true);

      backupService = SettingsBackupService.instance;
    });

    tearDownAll(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Backup Creation', () {
      test('should create local backup successfully', () async {
        // Arrange
        final testSettings = {
          'version': '1.0',
          'export_date': DateTime.now().toIso8601String(),
          'settings': {
            'audio_quality': {
              'value': 'high',
              'type': 'string',
              'category': 'audio',
              'description': 'Audio quality setting',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
            'theme_mode': {
              'value': 'dark',
              'type': 'string',
              'category': 'ui',
              'description': 'Theme mode setting',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          },
        };

        when(
          mockSettingsService.exportSettings(includeSensitive: false),
        ).thenReturn(testSettings);
        when(
          mockSettingsService.getSetting<String>(SettingKeys.appVersion),
        ).thenReturn('1.0.0');

        // Act
        final result = await backupService.createLocalBackup(
          backupName: 'test_backup',
          includeSensitive: false,
          encrypt: false,
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.backupPath, isNotNull);
        expect(result.settingsCount, equals(2));
        expect(result.encrypted, isFalse);
        expect(File(result.backupPath!).existsSync(), isTrue);

        // Verify backup content
        final backupFile = File(result.backupPath!);
        final backupContent = json.decode(await backupFile.readAsString());
        expect(
          backupContent['backup_info']['backup_name'],
          equals('test_backup'),
        );
        expect(backupContent['backup_info']['total_settings'], equals(2));
        expect(backupContent['settings_data'], equals(testSettings));
      });

      test('should create encrypted local backup successfully', () async {
        // Arrange
        final testSettings = {
          'version': '1.0',
          'export_date': DateTime.now().toIso8601String(),
          'settings': {
            'secure_setting': {
              'value': 'secret_value',
              'type': 'string',
              'category': 'security',
              'description': 'Secure setting',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          },
        };

        when(
          mockSettingsService.exportSettings(includeSensitive: true),
        ).thenReturn(testSettings);
        when(
          mockSettingsService.getSetting<String>(SettingKeys.appVersion),
        ).thenReturn('1.0.0');

        // Act
        final result = await backupService.createLocalBackup(
          backupName: 'encrypted_test_backup',
          includeSensitive: true,
          encrypt: true,
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.backupPath, isNotNull);
        expect(result.settingsCount, equals(1));
        expect(result.encrypted, isTrue);
        expect(File(result.backupPath!).existsSync(), isTrue);

        // Verify backup is encrypted (can't read as plain JSON)
        final backupFile = File(result.backupPath!);
        final backupContent = await backupFile.readAsString();
        expect(() => json.decode(backupContent), throwsFormatException);
      });

      test('should handle backup creation errors gracefully', () async {
        // Arrange
        when(
          mockSettingsService.exportSettings(includeSensitive: false),
        ).thenThrow(Exception('Settings export failed'));

        // Act
        final result = await backupService.createLocalBackup(
          backupName: 'failing_backup',
          includeSensitive: false,
          encrypt: false,
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('Settings export failed'));
      });
    });

    group('Backup Restoration', () {
      test('should restore from unencrypted backup successfully', () async {
        // Arrange
        final testSettings = {
          'version': '1.0',
          'export_date': DateTime.now().toIso8601String(),
          'settings': {
            'restored_setting': {
              'value': 'restored_value',
              'type': 'string',
              'category': 'general',
              'description': 'Restored setting',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          },
        };

        final backupData = {
          'backup_info': {
            'created_at': DateTime.now().toIso8601String(),
            'app_version': '1.0.0',
            'backup_name': 'test_backup',
            'includes_sensitive': false,
            'encrypted': false,
            'total_settings': 1,
          },
          'settings_data': testSettings,
        };

        // Create backup file
        final backupFile = File('${tempDir.path}/test_backup.json');
        await backupFile.writeAsString(json.encode(backupData));

        when(
          mockSettingsService.importSettings(any, overwriteExisting: false),
        ).thenAnswer((_) async => 1);
        when(
          mockSettingsService.getSetting<String>(SettingKeys.appVersion),
        ).thenReturn('1.0.0');

        // Act
        final result = await backupService.restoreFromLocalBackup(
          backupFilePath: backupFile.path,
          overwriteExisting: false,
          decrypt: false,
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.settingsImported, equals(1));
        expect(result.backupVersion, equals('1.0.0'));
        expect(result.migrationApplied, isFalse);

        // Verify settings were imported
        verify(
          mockSettingsService.importSettings(
            testSettings,
            overwriteExisting: false,
          ),
        ).called(1);
      });

      test('should handle restoration from non-existent backup', () async {
        // Act
        final result = await backupService.restoreFromLocalBackup(
          backupFilePath: '${tempDir.path}/non_existent_backup.json',
          overwriteExisting: false,
          decrypt: false,
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('Backup file not found'));
      });

      test('should handle invalid backup format', () async {
        // Arrange - Create invalid backup file
        final backupFile = File('${tempDir.path}/invalid_backup.json');
        await backupFile.writeAsString('{"invalid": "format"}');

        // Act
        final result = await backupService.restoreFromLocalBackup(
          backupFilePath: backupFile.path,
          overwriteExisting: false,
          decrypt: false,
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('Invalid backup file format'));
      });
    });

    group('Settings Migration', () {
      test('should perform version migration successfully', () async {
        // Arrange
        final currentSettings = {
          'version': '1.0',
          'export_date': DateTime.now().toIso8601String(),
          'settings': {
            'audio_quality': {
              'value': 'max', // Old value that should be migrated
              'type': 'string',
              'category': 'audio',
              'description': 'Audio quality setting',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          },
        };

        when(
          mockSettingsService.exportSettings(includeSensitive: true),
        ).thenReturn(currentSettings);
        when(
          mockSettingsService.importSettings(any, overwriteExisting: true),
        ).thenAnswer((_) async => 1);
        when(
          mockSettingsService.setSetting(SettingKeys.appVersion, '1.1.0'),
        ).thenAnswer((_) async {});
        when(
          mockSettingsService.getSetting<String>(SettingKeys.appVersion),
        ).thenReturn('1.0.0');

        // Act
        final result = await backupService.migrateSettings(
          fromVersion: '1.0.0',
          toVersion: '1.1.0',
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.fromVersion, equals('1.0.0'));
        expect(result.toVersion, equals('1.1.0'));
        expect(result.settingsChanged, equals(1)); // 'max' -> 'highest'
        expect(result.backupCreated, isTrue);

        // Verify version was updated
        verify(
          mockSettingsService.setSetting(SettingKeys.appVersion, '1.1.0'),
        ).called(1);
      });

      test('should skip migration for same version', () async {
        // Arrange
        when(
          mockSettingsService.getSetting<String>(SettingKeys.appVersion),
        ).thenReturn('1.0.0');

        // Act
        final result = await backupService.migrateSettings(
          fromVersion: '1.0.0',
          toVersion: '1.0.0',
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.settingsChanged, equals(0));
        expect(result.settingsAdded, equals(0));
        expect(result.settingsRemoved, equals(0));
      });
    });

    group('Backup Management', () {
      test('should list local backups correctly', () async {
        // Arrange - Create test backup files
        final backup1 = File('${tempDir.path}/backup1_123456789.json');
        final backup2 = File('${tempDir.path}/backup2_123456790.json');

        final backupData1 = {
          'backup_info': {
            'created_at': DateTime.now()
                .subtract(const Duration(hours: 1))
                .toIso8601String(),
            'app_version': '1.0.0',
            'backup_name': 'backup1',
            'total_settings': 5,
            'encrypted': false,
          },
          'settings_data': {},
        };

        final backupData2 = {
          'backup_info': {
            'created_at': DateTime.now().toIso8601String(),
            'app_version': '1.1.0',
            'backup_name': 'backup2',
            'total_settings': 8,
            'encrypted': true,
          },
          'settings_data': {},
        };

        await backup1.writeAsString(json.encode(backupData1));
        await backup2.writeAsString(json.encode(backupData2));

        when(
          mockSettingsService.getSetting<String>(SettingKeys.appVersion),
        ).thenReturn('1.1.0');

        // Act
        final backups = await backupService.listLocalBackups();

        // Assert
        expect(backups.length, equals(2));

        // Should be sorted by newest first
        expect(backups[0].backupName, equals('backup2'));
        expect(backups[0].settingsCount, equals(8));
        expect(backups[0].encrypted, isTrue);

        expect(backups[1].backupName, equals('backup1'));
        expect(backups[1].settingsCount, equals(5));
        expect(backups[1].encrypted, isFalse);
      });

      test('should delete local backup successfully', () async {
        // Arrange
        final backupFile = File('${tempDir.path}/delete_test_backup.json');
        await backupFile.writeAsString('{"test": "data"}');
        expect(await backupFile.exists(), isTrue);

        // Act
        final result = await backupService.deleteLocalBackup(backupFile.path);

        // Assert
        expect(result, isTrue);
        expect(await backupFile.exists(), isFalse);
      });

      test('should handle deleting non-existent backup', () async {
        // Act
        final result = await backupService.deleteLocalBackup(
          '${tempDir.path}/non_existent.json',
        );

        // Assert
        expect(result, isFalse);
      });
    });

    group('Migration Rules', () {
      test('should register and apply custom migration rules', () async {
        // Arrange
        final customRule = SettingsMigrationRule(
          ruleId: 'test_custom_rule_1.2.0',
          description: 'Test custom migration rule',
          apply: (settings) async {
            final settingsMap =
                settings['settings'] as Map<String, dynamic>? ?? {};
            settingsMap['new_custom_setting'] = {
              'value': 'custom_value',
              'type': 'string',
              'category': 'general',
              'description': 'Custom setting added by migration',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            };
            return settings;
          },
        );

        // Register custom rule
        backupService.registerMigrationRule('1.2.0', customRule);

        final currentSettings = {
          'version': '1.0',
          'export_date': DateTime.now().toIso8601String(),
          'settings': {
            'existing_setting': {
              'value': 'existing_value',
              'type': 'string',
              'category': 'general',
            },
          },
        };

        when(
          mockSettingsService.exportSettings(includeSensitive: true),
        ).thenReturn(currentSettings);
        when(
          mockSettingsService.importSettings(any, overwriteExisting: true),
        ).thenAnswer((_) async => 2); // 1 existing + 1 new
        when(
          mockSettingsService.setSetting(SettingKeys.appVersion, '1.2.0'),
        ).thenAnswer((_) async {});
        when(
          mockSettingsService.getSetting<String>(SettingKeys.appVersion),
        ).thenReturn('1.0.0');

        // Act
        final result = await backupService.migrateSettings(
          fromVersion: '1.0.0',
          toVersion: '1.2.0',
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.settingsAdded, equals(1)); // Custom setting was added
      });
    });

    group('Migration History', () {
      test('should track migration history', () async {
        // Arrange
        final currentSettings = {
          'version': '1.0',
          'export_date': DateTime.now().toIso8601String(),
          'settings': {},
        };

        when(
          mockSettingsService.exportSettings(includeSensitive: true),
        ).thenReturn(currentSettings);
        when(
          mockSettingsService.importSettings(any, overwriteExisting: true),
        ).thenAnswer((_) async => 0);
        when(
          mockSettingsService.setSetting(SettingKeys.appVersion, '1.1.0'),
        ).thenAnswer((_) async {});
        when(
          mockSettingsService.getSetting<String>(SettingKeys.appVersion),
        ).thenReturn('1.0.0');

        // Act
        await backupService.migrateSettings(
          fromVersion: '1.0.0',
          toVersion: '1.1.0',
        );

        final history = await backupService.getMigrationHistory();

        // Assert
        expect(history.isNotEmpty, isTrue);
        final lastMigration = history.last;
        expect(lastMigration.operation, equals(MigrationOperation.migration));
        expect(lastMigration.fromVersion, equals('1.0.0'));
        expect(lastMigration.toVersion, equals('1.1.0'));
      });
    });
  });
}
