import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:meeting_summarizer/core/database/database_migrations.dart';
import 'package:meeting_summarizer/core/database/database_schema.dart';

void main() {
  group('Database Migrations Tests', () {
    late Database db;

    setUpAll(() {
      // Initialize sqflite for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Create an in-memory database for each test
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          // Create initial schema (version 1)
          await _createInitialSchema(db);
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    group('Migration System', () {
      test('should migrate from version 1 to 2 successfully', () async {
        // Verify starting version
        expect(await _getDatabaseVersion(db), equals(1));

        // Run migration
        await DatabaseMigrations.migrate(db, 1, 2);

        // Verify migration completed
        expect(await _getDatabaseVersion(db), equals(2));

        // Verify new columns exist
        final recordingsInfo = await _getTableInfo(db, 'recordings');
        final hasEncryptionColumns = recordingsInfo.any(
          (column) => column['name'] == 'is_encrypted',
        );
        expect(hasEncryptionColumns, isTrue);

        // Verify new settings exist
        final settingsCount = await _getSettingsCount(db);
        expect(
          settingsCount,
          greaterThan(10),
        ); // Should have new encryption settings
      });

      test('should migrate from version 1 to 3 successfully', () async {
        // Run migration to version 3
        await DatabaseMigrations.migrate(db, 1, 3);

        // Verify final version
        expect(await _getDatabaseVersion(db), equals(3));

        // Verify shares table exists
        final tables = await _getTableNames(db);
        expect(tables, contains('shares'));

        // Verify sharing columns in recordings
        final recordingsInfo = await _getTableInfo(db, 'recordings');
        final hasShareColumns = recordingsInfo.any(
          (column) => column['name'] == 'is_shared',
        );
        expect(hasShareColumns, isTrue);
      });

      test('should migrate from version 1 to 4 successfully', () async {
        // Run migration to version 4
        await DatabaseMigrations.migrate(db, 1, 4);

        // Verify final version
        expect(await _getDatabaseVersion(db), equals(4));

        // Verify analytics tables exist
        final tables = await _getTableNames(db);
        expect(tables, contains('analytics_events'));
        expect(tables, contains('user_sessions'));

        // Verify analytics columns in recordings
        final recordingsInfo = await _getTableInfo(db, 'recordings');
        final hasAnalyticsColumns = recordingsInfo.any(
          (column) => column['name'] == 'play_count',
        );
        expect(hasAnalyticsColumns, isTrue);
      });

      test('should handle incremental migrations correctly', () async {
        // Migrate step by step
        await DatabaseMigrations.migrate(db, 1, 2);
        expect(await _getDatabaseVersion(db), equals(2));

        await DatabaseMigrations.migrate(db, 2, 3);
        expect(await _getDatabaseVersion(db), equals(3));

        await DatabaseMigrations.migrate(db, 3, 4);
        expect(await _getDatabaseVersion(db), equals(4));

        // Verify all features from all versions exist
        final tables = await _getTableNames(db);
        expect(tables, contains('shares'));
        expect(tables, contains('analytics_events'));
        expect(tables, contains('user_sessions'));
      });

      test('should preserve existing data during migration', () async {
        // Insert test data before migration
        await db.insert('recordings', {
          'id': 'test-recording-1',
          'filename': 'test.wav',
          'file_path': '/test/test.wav',
          'duration': 60000,
          'file_size': 1024000,
          'format': 'wav',
          'quality': 'high',
          'sample_rate': 44100,
          'bit_depth': 16,
          'channels': 1,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });

        await db.insert('settings', {
          'key': 'test_setting',
          'value': 'test_value',
          'type': 'string',
          'category': 'test',
          'description': 'Test setting',
          'is_sensitive': 0,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });

        // Run migration
        await DatabaseMigrations.migrate(db, 1, 4);

        // Verify data still exists
        final recordings = await db.query('recordings');
        expect(recordings.length, equals(1));
        expect(recordings.first['id'], equals('test-recording-1'));

        final testSetting = await db.query(
          'settings',
          where: 'key = ?',
          whereArgs: ['test_setting'],
        );
        expect(testSetting.length, equals(1));
        expect(testSetting.first['value'], equals('test_value'));
      });
    });

    group('Migration Validation', () {
      test('should validate successful migration', () async {
        await DatabaseMigrations.migrate(db, 1, 4);

        final isValid = await DatabaseMigrations.validateMigration(db, 4);
        expect(isValid, isTrue);
      });

      test('should detect version mismatch', () async {
        // Don't run migration, but try to validate version 4
        final isValid = await DatabaseMigrations.validateMigration(db, 4);
        expect(isValid, isFalse);
      });

      test('should validate table structure', () async {
        await DatabaseMigrations.migrate(db, 1, 3);

        // Should pass validation for version 3
        final isValid = await DatabaseMigrations.validateMigration(db, 3);
        expect(isValid, isTrue);
      });

      test('should validate data integrity', () async {
        // Insert data with proper foreign key relationships
        await db.insert('recordings', {
          'id': 'recording-1',
          'filename': 'test.wav',
          'file_path': '/test/test.wav',
          'duration': 60000,
          'file_size': 1024000,
          'format': 'wav',
          'quality': 'high',
          'sample_rate': 44100,
          'bit_depth': 16,
          'channels': 1,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });

        await db.insert('transcriptions', {
          'id': 'transcription-1',
          'recording_id': 'recording-1',
          'text': 'Test transcription',
          'confidence': 0.95,
          'language': 'en',
          'provider': 'test',
          'status': 'completed',
          'word_count': 2,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });

        await DatabaseMigrations.migrate(db, 1, 4);

        final isValid = await DatabaseMigrations.validateMigration(db, 4);
        expect(isValid, isTrue);
      });
    });

    group('Error Handling', () {
      test('should handle migration errors gracefully', () async {
        // Create a corrupted database state
        await db.execute('DROP TABLE recordings');

        // Migration should fail
        expect(() => DatabaseMigrations.migrate(db, 1, 2), throwsException);
      });

      test('should handle backup creation', () async {
        final backupPath = await DatabaseMigrations.createBackup(db);
        expect(backupPath, isNotNull);
        expect(backupPath, contains('backup'));
      });

      test('should handle backup restoration', () async {
        final backupPath = await DatabaseMigrations.createBackup(db);

        // This should not throw (even though it's a simplified implementation)
        await DatabaseMigrations.restoreFromBackup(db.path, backupPath);
      });
    });

    group('Edge Cases', () {
      test('should handle migration to same version', () async {
        await DatabaseMigrations.migrate(db, 1, 1);
        expect(await _getDatabaseVersion(db), equals(1));
      });

      test('should handle unknown migration version', () async {
        // This should not crash, just log and continue
        await DatabaseMigrations.migrate(db, 1, 10);
        // Should be at version 10 even though no migration scripts exist for versions 5-10
        expect(await _getDatabaseVersion(db), equals(10));
      });
    });
  });
}

/// Helper function to create initial database schema
Future<void> _createInitialSchema(Database db) async {
  // Create the initial tables (version 1)
  await db.execute(DatabaseSchema.createRecordingsTable);
  await db.execute(DatabaseSchema.createTranscriptionsTable);
  await db.execute(DatabaseSchema.createSummariesTable);
  await db.execute(DatabaseSchema.createSettingsTable);
  await db.execute(DatabaseSchema.createSearchIndexTable);

  // Create indexes
  for (final index in DatabaseSchema.createIndexes) {
    await db.execute(index);
  }

  // Create triggers
  for (final trigger in DatabaseSchema.createTriggers) {
    await db.execute(trigger);
  }

  // Insert default settings
  for (final setting in DatabaseSchema.defaultSettings) {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('settings', {
      ...setting,
      'created_at': now,
      'updated_at': now,
    });
  }

  // Set database version
  await db.execute('PRAGMA user_version = 1');
}

/// Get current database version
Future<int> _getDatabaseVersion(Database db) async {
  final result = await db.rawQuery('PRAGMA user_version');
  return result.first['user_version'] as int;
}

/// Get table information
Future<List<Map<String, dynamic>>> _getTableInfo(
  Database db,
  String tableName,
) async {
  return await db.rawQuery('PRAGMA table_info($tableName)');
}

/// Get all table names in the database
Future<List<String>> _getTableNames(Database db) async {
  final result = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
  );
  return result.map((row) => row['name'] as String).toList();
}

/// Get count of settings
Future<int> _getSettingsCount(Database db) async {
  final result = await db.rawQuery('SELECT COUNT(*) as count FROM settings');
  return result.first['count'] as int;
}
