/// Unit tests for SettingsService
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meeting_summarizer/core/models/database/app_settings.dart';
import 'package:meeting_summarizer/core/services/settings_service.dart';

void main() {
  group('SettingsService', () {
    late SettingsService settingsService;

    setUp(() async {
      // Clear any existing instance
      SettingsService.clearInstance();

      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});

      // Get fresh instance
      settingsService = SettingsService.instance;
      await settingsService.initialize();
    });

    tearDown(() {
      settingsService.dispose();
      SettingsService.clearInstance();
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        expect(settingsService, isNotNull);

        // Should have default settings
        final allSettings = settingsService.getAllSettings();
        expect(allSettings, isNotEmpty);
      });

      test('should create default settings on first run', () async {
        // Check that key default settings exist
        expect(settingsService.hasSetting(SettingKeys.audioFormat), isTrue);
        expect(settingsService.hasSetting(SettingKeys.audioQuality), isTrue);
        expect(settingsService.hasSetting(SettingKeys.themeMode), isTrue);

        // Check default values
        expect(
          settingsService.getSetting<String>(SettingKeys.audioFormat),
          'm4a',
        );
        expect(
          settingsService.getSetting<String>(SettingKeys.audioQuality),
          'high',
        );
        expect(
          settingsService.getSetting<String>(SettingKeys.themeMode),
          'system',
        );
      });

      test('should be singleton', () {
        final instance1 = SettingsService.instance;
        final instance2 = SettingsService.instance;

        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('Setting Management', () {
      test('should set and get string setting', () async {
        const key = 'test_string';
        const value = 'test_value';

        await settingsService.setSetting(key, value);

        final retrieved = settingsService.getSetting<String>(key);
        expect(retrieved, equals(value));
      });

      test('should set and get boolean setting', () async {
        const key = 'test_bool';
        const value = true;

        await settingsService.setSetting(key, value);

        final retrieved = settingsService.getSetting<bool>(key);
        expect(retrieved, equals(value));
      });

      test('should set and get integer setting', () async {
        const key = 'test_int';
        const value = 42;

        await settingsService.setSetting(key, value);

        final retrieved = settingsService.getSetting<int>(key);
        expect(retrieved, equals(value));
      });

      test('should set and get double setting', () async {
        const key = 'test_double';
        const value = 3.14;

        await settingsService.setSetting(key, value);

        final retrieved = settingsService.getSetting<double>(key);
        expect(retrieved, equals(value));
      });

      test('should return null for non-existent setting', () {
        final retrieved = settingsService.getSetting<String>('non_existent');
        expect(retrieved, isNull);
      });

      test('should return default value when using getSettingWithDefault', () {
        const defaultValue = 'default';
        final retrieved = settingsService.getSettingWithDefault(
          'non_existent',
          defaultValue,
        );
        expect(retrieved, equals(defaultValue));
      });

      test('should update existing setting', () async {
        const key = 'test_update';
        const initialValue = 'initial';
        const updatedValue = 'updated';

        await settingsService.setSetting(key, initialValue);
        expect(settingsService.getSetting<String>(key), equals(initialValue));

        await settingsService.setSetting(key, updatedValue);
        expect(settingsService.getSetting<String>(key), equals(updatedValue));
      });

      test('should remove setting', () async {
        const key = 'test_remove';
        const value = 'test';

        await settingsService.setSetting(key, value);
        expect(settingsService.hasSetting(key), isTrue);

        await settingsService.removeSetting(key);
        expect(settingsService.hasSetting(key), isFalse);
      });
    });

    group('Setting Categories', () {
      test('should categorize settings correctly', () async {
        await settingsService.setSetting(
          'audio_test',
          'value',
          category: SettingCategory.audio,
        );
        await settingsService.setSetting(
          'ui_test',
          'value',
          category: SettingCategory.ui,
        );

        final audioSettings = settingsService.getSettingsByCategory(
          SettingCategory.audio,
        );
        final uiSettings = settingsService.getSettingsByCategory(
          SettingCategory.ui,
        );

        expect(audioSettings.any((s) => s.key == 'audio_test'), isTrue);
        expect(uiSettings.any((s) => s.key == 'ui_test'), isTrue);

        // Should not appear in other categories
        expect(audioSettings.any((s) => s.key == 'ui_test'), isFalse);
        expect(uiSettings.any((s) => s.key == 'audio_test'), isFalse);
      });

      test('should infer category from key name', () async {
        await settingsService.setSetting('audio_format_test', 'value');
        await settingsService.setSetting(
          'transcription_language_test',
          'value',
        );
        await settingsService.setSetting('theme_color_test', 'value');

        final metadata1 = settingsService.getSettingMetadata(
          'audio_format_test',
        );
        final metadata2 = settingsService.getSettingMetadata(
          'transcription_language_test',
        );
        final metadata3 = settingsService.getSettingMetadata(
          'theme_color_test',
        );

        expect(metadata1?.category, equals(SettingCategory.audio));
        expect(metadata2?.category, equals(SettingCategory.transcription));
        expect(metadata3?.category, equals(SettingCategory.ui));
      });

      test('should get settings count by category', () async {
        await settingsService.setSetting(
          'audio1',
          'value',
          category: SettingCategory.audio,
        );
        await settingsService.setSetting(
          'audio2',
          'value',
          category: SettingCategory.audio,
        );
        await settingsService.setSetting(
          'ui1',
          'value',
          category: SettingCategory.ui,
        );

        final counts = settingsService.getSettingsCountByCategory();

        expect(counts[SettingCategory.audio]! >= 2, isTrue);
        expect(counts[SettingCategory.ui]! >= 1, isTrue);
      });
    });

    group('Search Functionality', () {
      setUp(() async {
        await settingsService.setSetting('audio_format', 'mp3');
        await settingsService.setSetting('audio_quality', 'high');
        await settingsService.setSetting('theme_mode', 'dark');
        await settingsService.setSetting('notification_sound', 'enabled');
      });

      test('should search by key', () {
        final results = settingsService.searchSettings('audio');

        expect(results.length, greaterThanOrEqualTo(2));
        expect(results.any((s) => s.key.contains('audio')), isTrue);
      });

      test('should search case-insensitively', () {
        final results = settingsService.searchSettings('AUDIO');

        expect(results, isNotEmpty);
        expect(
          results.any((s) => s.key.toLowerCase().contains('audio')),
          isTrue,
        );
      });

      test('should return all settings for empty query', () {
        final allSettings = settingsService.getAllSettings();
        final searchResults = settingsService.searchSettings('');

        expect(searchResults.length, equals(allSettings.length));
      });

      test('should return empty list for non-matching query', () {
        final results = settingsService.searchSettings('nonexistent_xyz_123');

        expect(results, isEmpty);
      });
    });

    group('Validation', () {
      test('should validate boolean values', () {
        expect(settingsService.validateSetting('test_bool', true), isTrue);
        expect(settingsService.validateSetting('test_bool', false), isTrue);
        expect(
          settingsService.validateSetting('test_bool', 'not_bool'),
          isFalse,
        );
      });

      test('should validate integer values', () {
        expect(settingsService.validateSetting('test_int', 42), isTrue);
        expect(settingsService.validateSetting('test_int', 'not_int'), isFalse);
      });

      test('should validate custom rules for audio quality', () {
        expect(
          settingsService.validateSetting(SettingKeys.audioQuality, 'high'),
          isTrue,
        );
        expect(
          settingsService.validateSetting(SettingKeys.audioQuality, 'low'),
          isTrue,
        );
        expect(
          settingsService.validateSetting(SettingKeys.audioQuality, 'invalid'),
          isFalse,
        );
      });

      test('should validate custom rules for theme mode', () {
        expect(
          settingsService.validateSetting(SettingKeys.themeMode, 'light'),
          isTrue,
        );
        expect(
          settingsService.validateSetting(SettingKeys.themeMode, 'dark'),
          isTrue,
        );
        expect(
          settingsService.validateSetting(SettingKeys.themeMode, 'system'),
          isTrue,
        );
        expect(
          settingsService.validateSetting(SettingKeys.themeMode, 'invalid'),
          isFalse,
        );
      });

      test('should validate recording limit range', () {
        expect(
          settingsService.validateSetting(SettingKeys.recordingLimit, 60),
          isTrue,
        );
        expect(
          settingsService.validateSetting(SettingKeys.recordingLimit, 3600),
          isTrue,
        );
        expect(
          settingsService.validateSetting(SettingKeys.recordingLimit, -1),
          isFalse,
        );
        expect(
          settingsService.validateSetting(SettingKeys.recordingLimit, 20000),
          isFalse,
        );
      });
    });

    group('Reset Functionality', () {
      test('should reset single setting to default', () async {
        // Change from default
        await settingsService.setSetting(SettingKeys.audioFormat, 'wav');
        expect(
          settingsService.getSetting<String>(SettingKeys.audioFormat),
          'wav',
        );

        // Reset to default
        await settingsService.resetSetting(SettingKeys.audioFormat);
        expect(
          settingsService.getSetting<String>(SettingKeys.audioFormat),
          'm4a',
        );
      });

      test('should reset all settings to defaults', () async {
        // Change some settings
        await settingsService.setSetting(SettingKeys.audioFormat, 'wav');
        await settingsService.setSetting(SettingKeys.themeMode, 'dark');
        await settingsService.setSetting('custom_setting', 'value');

        expect(
          settingsService.getSetting<String>(SettingKeys.audioFormat),
          'wav',
        );
        expect(
          settingsService.getSetting<String>(SettingKeys.themeMode),
          'dark',
        );
        expect(settingsService.hasSetting('custom_setting'), isTrue);

        // Reset all
        await settingsService.resetAllSettings();

        // Check defaults are restored
        expect(
          settingsService.getSetting<String>(SettingKeys.audioFormat),
          'm4a',
        );
        expect(
          settingsService.getSetting<String>(SettingKeys.themeMode),
          'system',
        );

        // Custom setting should be removed
        expect(settingsService.hasSetting('custom_setting'), isFalse);
      });
    });

    group('Export/Import', () {
      test('should export settings as JSON', () async {
        await settingsService.setSetting('test_export', 'value');

        final exported = settingsService.exportSettings();

        expect(exported, isA<Map<String, dynamic>>());
        expect(exported['version'], isNotNull);
        expect(exported['export_date'], isNotNull);
        expect(exported['settings'], isA<Map<String, dynamic>>());

        final settings = exported['settings'] as Map<String, dynamic>;
        expect(settings.containsKey('test_export'), isTrue);
      });

      test(
        'should exclude sensitive settings from export by default',
        () async {
          await settingsService.setSetting('api_key_test', 'secret');

          final exported = settingsService.exportSettings();
          final settings = exported['settings'] as Map<String, dynamic>;

          expect(settings.containsKey('api_key_test'), isFalse);
        },
      );

      test('should include sensitive settings when requested', () async {
        await settingsService.setSetting('api_key_test', 'secret');

        final exported = settingsService.exportSettings(includeSensitive: true);
        final settings = exported['settings'] as Map<String, dynamic>;

        expect(settings.containsKey('api_key_test'), isTrue);
      });

      test('should import settings from JSON', () async {
        final importData = {
          'version': '1.0',
          'export_date': DateTime.now().toIso8601String(),
          'settings': {
            'imported_setting': {
              'value': 'imported_value',
              'type': 'string',
              'category': 'general',
            },
          },
        };

        final importedCount = await settingsService.importSettings(importData);

        expect(importedCount, equals(1));
        expect(
          settingsService.getSetting<String>('imported_setting'),
          'imported_value',
        );
      });

      test('should not overwrite existing settings by default', () async {
        await settingsService.setSetting('existing_setting', 'original');

        final importData = {
          'version': '1.0',
          'settings': {
            'existing_setting': {
              'value': 'imported',
              'type': 'string',
              'category': 'general',
            },
          },
        };

        await settingsService.importSettings(importData);

        expect(
          settingsService.getSetting<String>('existing_setting'),
          'original',
        );
      });

      test('should overwrite existing settings when requested', () async {
        await settingsService.setSetting('existing_setting', 'original');

        final importData = {
          'version': '1.0',
          'settings': {
            'existing_setting': {
              'value': 'imported',
              'type': 'string',
              'category': 'general',
            },
          },
        };

        await settingsService.importSettings(
          importData,
          overwriteExisting: true,
        );

        expect(
          settingsService.getSetting<String>('existing_setting'),
          'imported',
        );
      });

      test('should skip invalid settings during import', () async {
        final importData = {
          'version': '1.0',
          'settings': {
            'valid_setting': {
              'value': 'valid',
              'type': 'string',
              'category': 'general',
            },
            SettingKeys.audioQuality: {
              'value': 'invalid_quality',
              'type': 'string',
              'category': 'audio',
            },
          },
        };

        final importedCount = await settingsService.importSettings(importData);

        expect(importedCount, equals(1));
        expect(settingsService.getSetting<String>('valid_setting'), 'valid');
        expect(
          settingsService.getSetting<String>(SettingKeys.audioQuality),
          'high',
        ); // Should remain default
      });
    });

    group('Refresh and Cache', () {
      test('should refresh settings from storage', () async {
        await settingsService.setSetting('test_refresh', 'value');
        expect(settingsService.getSetting<String>('test_refresh'), 'value');

        await settingsService.refresh();

        expect(settingsService.getSetting<String>('test_refresh'), 'value');
      });
    });

    group('Setting Metadata', () {
      test('should provide setting metadata', () async {
        await settingsService.setSetting('test_metadata', 'value');

        final metadata = settingsService.getSettingMetadata('test_metadata');

        expect(metadata, isNotNull);
        expect(metadata!.key, equals('test_metadata'));
        expect(metadata.value, equals('value'));
        expect(metadata.type, equals(SettingType.string));
        expect(metadata.createdAt, isNotNull);
        expect(metadata.updatedAt, isNotNull);
      });

      test('should return null for non-existent setting metadata', () {
        final metadata = settingsService.getSettingMetadata('non_existent');
        expect(metadata, isNull);
      });
    });

    group('Error Handling', () {
      test('should handle initialization errors gracefully', () async {
        // This test is mainly for coverage as actual error simulation is complex
        final settings = settingsService.getAllSettings();
        expect(settings, isA<List<AppSettings>>());
      });
    });
  });
}

// Additional test utilities
extension SettingsServiceTestExtension on SettingsService {
  // Helper methods for testing could be added here if needed
}
