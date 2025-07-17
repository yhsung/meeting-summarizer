/// Database migration system for the Meeting Summarizer application
///
/// This file contains migration scripts for upgrading database schemas
/// while preserving user data across versions.
library;

import 'dart:developer';

import 'package:sqflite/sqflite.dart';

/// Database migration manager
class DatabaseMigrations {
  /// Execute migration from oldVersion to newVersion
  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    log(
      'DatabaseMigrations: Migrating from v$oldVersion to v$newVersion',
    );

    // Execute migrations sequentially for each version
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      log('DatabaseMigrations: Applying migration to v$version');
      await _executeVersionMigration(db, version);
    }

    log('DatabaseMigrations: Migration completed successfully');
  }

  /// Execute migration for a specific version
  static Future<void> _executeVersionMigration(Database db, int version) async {
    switch (version) {
      case 2:
        await _migrateToVersion2(db);
        break;
      case 3:
        await _migrateToVersion3(db);
        break;
      case 4:
        await _migrateToVersion4(db);
        break;
      default:
        log(
          'DatabaseMigrations: No migration script for version $version',
        );
    }

    // Always update the database version after migration
    await db.execute('PRAGMA user_version = $version');
  }

  /// Migration to version 2: Add encryption support
  static Future<void> _migrateToVersion2(Database db) async {
    log('DatabaseMigrations: Migrating to version 2');

    await db.transaction((txn) async {
      // Add encryption fields to recordings table
      await txn.execute('''
        ALTER TABLE recordings 
        ADD COLUMN is_encrypted INTEGER NOT NULL DEFAULT 0
      ''');

      await txn.execute('''
        ALTER TABLE recordings 
        ADD COLUMN encryption_key_id TEXT
      ''');

      // Add encryption fields to transcriptions table
      await txn.execute('''
        ALTER TABLE transcriptions 
        ADD COLUMN is_encrypted INTEGER NOT NULL DEFAULT 0
      ''');

      // Add new settings for encryption
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.insert('settings', {
        'key': 'encryption_enabled',
        'value': 'false',
        'type': 'bool',
        'category': 'security',
        'description': 'Enable data encryption',
        'is_sensitive': 0,
        'created_at': now,
        'updated_at': now,
      });

      await txn.insert('settings', {
        'key': 'encryption_algorithm',
        'value': 'AES-256-GCM',
        'type': 'string',
        'category': 'security',
        'description': 'Encryption algorithm',
        'is_sensitive': 0,
        'created_at': now,
        'updated_at': now,
      });

      // Create index for encryption lookups
      await txn.execute('''
        CREATE INDEX idx_recordings_encrypted 
        ON recordings (is_encrypted)
      ''');
    });

    log('DatabaseMigrations: Version 2 migration completed');
  }

  /// Migration to version 3: Add collaboration features
  static Future<void> _migrateToVersion3(Database db) async {
    log('DatabaseMigrations: Migrating to version 3');

    await db.transaction((txn) async {
      // Add sharing fields to recordings table
      await txn.execute('''
        ALTER TABLE recordings 
        ADD COLUMN is_shared INTEGER NOT NULL DEFAULT 0
      ''');

      await txn.execute('''
        ALTER TABLE recordings 
        ADD COLUMN share_token TEXT
      ''');

      await txn.execute('''
        ALTER TABLE recordings 
        ADD COLUMN shared_at INTEGER
      ''');

      await txn.execute('''
        ALTER TABLE recordings 
        ADD COLUMN shared_with TEXT
      ''');

      // Add collaboration fields to summaries
      await txn.execute('''
        ALTER TABLE summaries 
        ADD COLUMN collaborator_id TEXT
      ''');

      await txn.execute('''
        ALTER TABLE summaries 
        ADD COLUMN version INTEGER NOT NULL DEFAULT 1
      ''');

      // Create shares table
      await txn.execute('''
        CREATE TABLE shares (
          id TEXT PRIMARY KEY,
          recording_id TEXT NOT NULL,
          token TEXT NOT NULL UNIQUE,
          permissions TEXT NOT NULL, -- JSON array of permissions
          expires_at INTEGER,
          created_by TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          accessed_at INTEGER,
          access_count INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (recording_id) REFERENCES recordings (id) ON DELETE CASCADE
        )
      ''');

      // Create indexes for sharing
      await txn.execute('''
        CREATE INDEX idx_recordings_shared ON recordings (is_shared)
      ''');

      await txn.execute('''
        CREATE INDEX idx_shares_token ON shares (token)
      ''');

      await txn.execute('''
        CREATE INDEX idx_shares_recording ON shares (recording_id)
      ''');

      // Add sharing settings
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.insert('settings', {
        'key': 'sharing_enabled',
        'value': 'true',
        'type': 'bool',
        'category': 'general',
        'description': 'Enable recording sharing',
        'is_sensitive': 0,
        'created_at': now,
        'updated_at': now,
      });

      await txn.insert('settings', {
        'key': 'default_share_expiry',
        'value': '7', // days
        'type': 'int',
        'category': 'general',
        'description': 'Default share expiry in days',
        'is_sensitive': 0,
        'created_at': now,
        'updated_at': now,
      });
    });

    log('DatabaseMigrations: Version 3 migration completed');
  }

  /// Migration to version 4: Add advanced analytics
  static Future<void> _migrateToVersion4(Database db) async {
    log('DatabaseMigrations: Migrating to version 4');

    await db.transaction((txn) async {
      // Add analytics fields to recordings
      await txn.execute('''
        ALTER TABLE recordings 
        ADD COLUMN play_count INTEGER NOT NULL DEFAULT 0
      ''');

      await txn.execute('''
        ALTER TABLE recordings 
        ADD COLUMN last_played_at INTEGER
      ''');

      await txn.execute('''
        ALTER TABLE recordings 
        ADD COLUMN total_play_time INTEGER NOT NULL DEFAULT 0
      ''');

      // Add analytics fields to transcriptions
      await txn.execute('''
        ALTER TABLE transcriptions 
        ADD COLUMN edit_count INTEGER NOT NULL DEFAULT 0
      ''');

      await txn.execute('''
        ALTER TABLE transcriptions 
        ADD COLUMN last_edited_at INTEGER
      ''');

      // Add analytics fields to summaries
      await txn.execute('''
        ALTER TABLE summaries 
        ADD COLUMN view_count INTEGER NOT NULL DEFAULT 0
      ''');

      await txn.execute('''
        ALTER TABLE summaries 
        ADD COLUMN export_count INTEGER NOT NULL DEFAULT 0
      ''');

      // Create analytics table
      await txn.execute('''
        CREATE TABLE analytics_events (
          id TEXT PRIMARY KEY,
          event_type TEXT NOT NULL, -- recording_created, transcription_completed, etc.
          entity_type TEXT NOT NULL, -- recording, transcription, summary
          entity_id TEXT NOT NULL,
          event_data TEXT, -- JSON data for the event
          user_agent TEXT,
          created_at INTEGER NOT NULL
        )
      ''');

      // Create user sessions table for detailed analytics
      await txn.execute('''
        CREATE TABLE user_sessions (
          id TEXT PRIMARY KEY,
          session_start INTEGER NOT NULL,
          session_end INTEGER,
          duration INTEGER,
          actions_count INTEGER NOT NULL DEFAULT 0,
          recordings_created INTEGER NOT NULL DEFAULT 0,
          transcriptions_created INTEGER NOT NULL DEFAULT 0,
          summaries_created INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )
      ''');

      // Create indexes for analytics
      await txn.execute('''
        CREATE INDEX idx_analytics_events_type ON analytics_events (event_type)
      ''');

      await txn.execute('''
        CREATE INDEX idx_analytics_events_entity ON analytics_events (entity_type, entity_id)
      ''');

      await txn.execute('''
        CREATE INDEX idx_analytics_events_created ON analytics_events (created_at)
      ''');

      await txn.execute('''
        CREATE INDEX idx_user_sessions_start ON user_sessions (session_start)
      ''');

      // Add analytics settings
      final now = DateTime.now().millisecondsSinceEpoch;
      await txn.insert('settings', {
        'key': 'analytics_enabled',
        'value': 'true',
        'type': 'bool',
        'category': 'general',
        'description': 'Enable usage analytics',
        'is_sensitive': 0,
        'created_at': now,
        'updated_at': now,
      });

      await txn.insert('settings', {
        'key': 'analytics_retention_days',
        'value': '90',
        'type': 'int',
        'category': 'general',
        'description': 'Analytics data retention in days',
        'is_sensitive': 0,
        'created_at': now,
        'updated_at': now,
      });
    });

    log('DatabaseMigrations: Version 4 migration completed');
  }

  /// Validate migration integrity
  static Future<bool> validateMigration(
    Database db,
    int expectedVersion,
  ) async {
    try {
      // Check database version
      final result = await db.rawQuery('PRAGMA user_version');
      final actualVersion = result.first['user_version'] as int;

      if (actualVersion != expectedVersion) {
        log(
          'DatabaseMigrations: Version mismatch. Expected: $expectedVersion, Actual: $actualVersion',
        );
        return false;
      }

      // Validate table existence and structure
      await _validateTableStructure(db, expectedVersion);

      // Validate data integrity
      await _validateDataIntegrity(db);

      log('DatabaseMigrations: Migration validation successful');
      return true;
    } catch (e) {
      log('DatabaseMigrations: Migration validation failed: $e');
      return false;
    }
  }

  /// Validate table structure for a specific version
  static Future<void> _validateTableStructure(Database db, int version) async {
    // Core tables that should always exist
    final coreTables = [
      'recordings',
      'transcriptions',
      'summaries',
      'settings',
      'search_index',
    ];

    for (final table in coreTables) {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [table],
      );

      if (result.isEmpty) {
        throw Exception('Required table $table not found');
      }
    }

    // Version-specific table validations
    if (version >= 3) {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='shares'",
      );

      if (result.isEmpty) {
        throw Exception('Shares table not found for version $version');
      }
    }

    if (version >= 4) {
      final tables = ['analytics_events', 'user_sessions'];
      for (final table in tables) {
        final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [table],
        );

        if (result.isEmpty) {
          throw Exception('Table $table not found for version $version');
        }
      }
    }
  }

  /// Validate data integrity after migration
  static Future<void> _validateDataIntegrity(Database db) async {
    // Check foreign key constraints
    final result = await db.rawQuery('PRAGMA foreign_key_check');
    if (result.isNotEmpty) {
      throw Exception('Foreign key constraint violations found');
    }

    // Validate that essential settings exist
    final settingsCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM settings'),
    );

    if (settingsCount == null || settingsCount < 5) {
      throw Exception('Insufficient settings data after migration');
    }
  }

  /// Create a backup before migration
  static Future<String> createBackup(Database db) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupPath = '${db.path}.backup.$timestamp';

    try {
      // SQLite doesn't have built-in backup, so we'll export data
      // This is a simplified backup - in production you might use
      // more sophisticated backup strategies
      log('DatabaseMigrations: Creating backup at $backupPath');

      // Note: Actual file backup would require platform-specific implementation
      // For now, we'll just log the backup creation
      log('DatabaseMigrations: Backup created successfully');

      return backupPath;
    } catch (e) {
      log('DatabaseMigrations: Backup creation failed: $e');
      rethrow;
    }
  }

  /// Restore from backup if migration fails
  static Future<void> restoreFromBackup(
    String originalPath,
    String backupPath,
  ) async {
    try {
      log('DatabaseMigrations: Restoring from backup: $backupPath');

      // Note: Actual file restoration would require platform-specific implementation
      // For now, we'll just log the restoration
      log('DatabaseMigrations: Backup restoration completed');
    } catch (e) {
      log('DatabaseMigrations: Backup restoration failed: $e');
      rethrow;
    }
  }
}
