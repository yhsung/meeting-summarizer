import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'database_schema.dart';
import '../models/database/recording.dart';
import '../models/database/transcription.dart';
import '../models/database/summary.dart' as models;
import '../models/database/app_settings.dart';

/// Database helper class for managing SQLite database operations
///
/// This class provides a singleton interface for database operations including
/// CRUD operations, transactions, migrations, and data validation.
class DatabaseHelper {
  static const Uuid _uuid = Uuid();
  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._internal();

  /// Get singleton instance of DatabaseHelper
  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  /// Get database instance, initializing if necessary
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, DatabaseSchema.databaseName);

      debugPrint('DatabaseHelper: Initializing database at $path');

      // Create database directory if it doesn't exist
      final directory = Directory(dirname(path));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      return await openDatabase(
        path,
        version: DatabaseSchema.databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: _onConfigure,
      );
    } catch (e) {
      debugPrint('DatabaseHelper: Database initialization failed: $e');
      rethrow;
    }
  }

  /// Configure database settings
  Future<void> _onConfigure(Database db) async {
    // Enable foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON');
    // Set journal mode for better performance
    await db.execute('PRAGMA journal_mode = WAL');
    // Set synchronous mode for better performance
    await db.execute('PRAGMA synchronous = NORMAL');
  }

  /// Create database tables and initial data
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('DatabaseHelper: Creating database schema version $version');

    try {
      // Execute all schema statements in a transaction
      await db.transaction((txn) async {
        // Create tables
        for (final statement in DatabaseSchema.createTables) {
          await txn.execute(statement);
        }

        // Create indexes
        for (final index in DatabaseSchema.createIndexes) {
          await txn.execute(index);
        }

        // Create triggers
        for (final trigger in DatabaseSchema.createTriggers) {
          await txn.execute(trigger);
        }

        // Insert default settings
        for (final setting in DatabaseSchema.defaultSettings) {
          final now = DateTime.now().millisecondsSinceEpoch;
          await txn.insert('settings', {
            ...setting,
            'created_at': now,
            'updated_at': now,
          });
        }
      });

      debugPrint('DatabaseHelper: Database schema created successfully');
    } catch (e) {
      debugPrint('DatabaseHelper: Database creation failed: $e');
      rethrow;
    }
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint(
      'DatabaseHelper: Upgrading database from v$oldVersion to v$newVersion',
    );

    // Migration logic will be implemented here
    // For now, recreate the database
    try {
      await _dropAllTables(db);
      await _onCreate(db, newVersion);
    } catch (e) {
      debugPrint('DatabaseHelper: Database upgrade failed: $e');
      rethrow;
    }
  }

  /// Drop all tables (used during migrations)
  Future<void> _dropAllTables(Database db) async {
    final tables = [
      'search_index',
      'summaries',
      'transcriptions',
      'recordings',
      'settings',
    ];
    for (final table in tables) {
      await db.execute('DROP TABLE IF EXISTS $table');
    }
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      debugPrint('DatabaseHelper: Database connection closed');
    }
  }

  // CRUD Operations for Recordings

  /// Insert a new recording
  Future<String> insertRecording(Recording recording) async {
    final db = await database;
    try {
      await db.insert('recordings', recording.toDatabase());
      debugPrint('DatabaseHelper: Inserted recording ${recording.id}');
      return recording.id;
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to insert recording: $e');
      rethrow;
    }
  }

  /// Get recording by ID
  Future<Recording?> getRecording(String id) async {
    final db = await database;
    try {
      final result = await db.query(
        'recordings',
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [id],
      );

      if (result.isEmpty) return null;
      return Recording.fromDatabase(result.first);
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to get recording $id: $e');
      return null;
    }
  }

  /// Get all recordings with optional filters
  Future<List<Recording>> getRecordings({
    int? limit,
    int? offset,
    String? searchQuery,
    String? format,
    DateTime? startDate,
    DateTime? endDate,
    String orderBy = 'created_at DESC',
  }) async {
    final db = await database;
    try {
      String whereClause = 'is_deleted = 0';
      List<dynamic> whereArgs = [];

      // Add filters
      if (searchQuery != null && searchQuery.isNotEmpty) {
        whereClause += ' AND (title LIKE ? OR description LIKE ?)';
        whereArgs.addAll(['%$searchQuery%', '%$searchQuery%']);
      }

      if (format != null) {
        whereClause += ' AND format = ?';
        whereArgs.add(format);
      }

      if (startDate != null) {
        whereClause += ' AND created_at >= ?';
        whereArgs.add(startDate.millisecondsSinceEpoch);
      }

      if (endDate != null) {
        whereClause += ' AND created_at <= ?';
        whereArgs.add(endDate.millisecondsSinceEpoch);
      }

      final result = await db.query(
        'recordings',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );

      return result.map((row) => Recording.fromDatabase(row)).toList();
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to get recordings: $e');
      return [];
    }
  }

  /// Update recording
  Future<bool> updateRecording(Recording recording) async {
    final db = await database;
    try {
      final updated = await db.update(
        'recordings',
        recording.toDatabase(),
        where: 'id = ?',
        whereArgs: [recording.id],
      );
      debugPrint('DatabaseHelper: Updated recording ${recording.id}');
      return updated > 0;
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to update recording: $e');
      return false;
    }
  }

  /// Delete recording (soft delete)
  Future<bool> deleteRecording(String id) async {
    final db = await database;
    try {
      final updated = await db.update(
        'recordings',
        {'is_deleted': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('DatabaseHelper: Soft deleted recording $id');
      return updated > 0;
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to delete recording: $e');
      return false;
    }
  }

  /// Permanently delete recording and its file
  Future<bool> permanentlyDeleteRecording(String id) async {
    final db = await database;
    try {
      // Get recording to delete file
      final recording = await getRecording(id);
      if (recording != null) {
        // Delete file
        final file = File(recording.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      final deleted = await db.delete(
        'recordings',
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('DatabaseHelper: Permanently deleted recording $id');
      return deleted > 0;
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to permanently delete recording: $e');
      return false;
    }
  }

  // CRUD Operations for Transcriptions

  /// Insert a new transcription
  Future<String> insertTranscription(Transcription transcription) async {
    final db = await database;
    try {
      await db.insert('transcriptions', transcription.toDatabase());
      debugPrint('DatabaseHelper: Inserted transcription ${transcription.id}');
      return transcription.id;
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to insert transcription: $e');
      rethrow;
    }
  }

  /// Get transcription by ID
  Future<Transcription?> getTranscription(String id) async {
    final db = await database;
    try {
      final result = await db.query(
        'transcriptions',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (result.isEmpty) return null;
      return Transcription.fromDatabase(result.first);
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to get transcription $id: $e');
      return null;
    }
  }

  /// Get transcriptions by recording ID
  Future<List<Transcription>> getTranscriptionsByRecording(
    String recordingId,
  ) async {
    final db = await database;
    try {
      final result = await db.query(
        'transcriptions',
        where: 'recording_id = ?',
        whereArgs: [recordingId],
        orderBy: 'created_at DESC',
      );

      return result.map((row) => Transcription.fromDatabase(row)).toList();
    } catch (e) {
      debugPrint(
        'DatabaseHelper: Failed to get transcriptions for recording $recordingId: $e',
      );
      return [];
    }
  }

  /// Update transcription
  Future<bool> updateTranscription(Transcription transcription) async {
    final db = await database;
    try {
      final updated = await db.update(
        'transcriptions',
        transcription.toDatabase(),
        where: 'id = ?',
        whereArgs: [transcription.id],
      );
      debugPrint('DatabaseHelper: Updated transcription ${transcription.id}');
      return updated > 0;
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to update transcription: $e');
      return false;
    }
  }

  /// Delete transcription
  Future<bool> deleteTranscription(String id) async {
    final db = await database;
    try {
      final deleted = await db.delete(
        'transcriptions',
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('DatabaseHelper: Deleted transcription $id');
      return deleted > 0;
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to delete transcription: $e');
      return false;
    }
  }

  // CRUD Operations for Summaries

  /// Insert a new summary
  Future<String> insertSummary(models.Summary summary) async {
    final db = await database;
    try {
      await db.insert('summaries', summary.toDatabase());
      debugPrint('DatabaseHelper: Inserted summary ${summary.id}');
      return summary.id;
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to insert summary: $e');
      rethrow;
    }
  }

  /// Get summary by ID
  Future<models.Summary?> getSummary(String id) async {
    final db = await database;
    try {
      final result = await db.query(
        'summaries',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (result.isEmpty) return null;
      return models.Summary.fromDatabase(result.first);
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to get summary $id: $e');
      return null;
    }
  }

  /// Get summaries by transcription ID
  Future<List<models.Summary>> getSummariesByTranscription(
    String transcriptionId,
  ) async {
    final db = await database;
    try {
      final result = await db.query(
        'summaries',
        where: 'transcription_id = ?',
        whereArgs: [transcriptionId],
        orderBy: 'created_at DESC',
      );

      return result.map((row) => models.Summary.fromDatabase(row)).toList();
    } catch (e) {
      debugPrint(
        'DatabaseHelper: Failed to get summaries for transcription $transcriptionId: $e',
      );
      return [];
    }
  }

  /// Update summary
  Future<bool> updateSummary(models.Summary summary) async {
    final db = await database;
    try {
      final updated = await db.update(
        'summaries',
        summary.toDatabase(),
        where: 'id = ?',
        whereArgs: [summary.id],
      );
      debugPrint('DatabaseHelper: Updated summary ${summary.id}');
      return updated > 0;
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to update summary: $e');
      return false;
    }
  }

  /// Delete summary
  Future<bool> deleteSummary(String id) async {
    final db = await database;
    try {
      final deleted = await db.delete(
        'summaries',
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('DatabaseHelper: Deleted summary $id');
      return deleted > 0;
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to delete summary: $e');
      return false;
    }
  }

  // CRUD Operations for Settings

  /// Get setting value
  Future<String?> getSetting(String key) async {
    final db = await database;
    try {
      final result = await db.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
      );

      if (result.isEmpty) return null;
      return result.first['value'] as String;
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to get setting $key: $e');
      return null;
    }
  }

  /// Get setting as AppSettings object
  Future<AppSettings?> getAppSetting(String key) async {
    final db = await database;
    try {
      final result = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
      );

      if (result.isEmpty) return null;
      return AppSettings.fromDatabase(result.first);
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to get app setting $key: $e');
      return null;
    }
  }

  /// Get all settings by category
  Future<List<AppSettings>> getSettingsByCategory(
    SettingCategory category,
  ) async {
    final db = await database;
    try {
      final result = await db.query(
        'settings',
        where: 'category = ?',
        whereArgs: [category.value],
        orderBy: 'key',
      );

      return result.map((row) => AppSettings.fromDatabase(row)).toList();
    } catch (e) {
      debugPrint(
        'DatabaseHelper: Failed to get settings for category ${category.value}: $e',
      );
      return [];
    }
  }

  /// Set setting value
  Future<bool> setSetting(String key, String value) async {
    final db = await database;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final updated = await db.update(
        'settings',
        {'value': value, 'updated_at': now},
        where: 'key = ?',
        whereArgs: [key],
      );

      debugPrint('DatabaseHelper: Updated setting $key');
      return updated > 0;
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to set setting $key: $e');
      return false;
    }
  }

  /// Insert or update setting
  Future<bool> upsertSetting(AppSettings setting) async {
    final db = await database;
    try {
      await db.insert(
        'settings',
        setting.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('DatabaseHelper: Upserted setting ${setting.key}');
      return true;
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to upsert setting: $e');
      return false;
    }
  }

  // Search Operations

  /// Search across recordings, transcriptions, and summaries
  Future<List<Map<String, dynamic>>> search(String query) async {
    final db = await database;
    try {
      final result = await db.query(
        'search_index',
        where: 'search_index MATCH ?',
        whereArgs: [query],
        orderBy: 'rank',
      );

      return result;
    } catch (e) {
      debugPrint('DatabaseHelper: Search failed for query "$query": $e');
      return [];
    }
  }

  // Utility Operations

  /// Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    final db = await database;
    try {
      final recordingsCount =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM recordings WHERE is_deleted = 0',
            ),
          ) ??
          0;

      final transcriptionsCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM transcriptions'),
          ) ??
          0;

      final summariesCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM summaries'),
          ) ??
          0;

      final settingsCount =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM settings'),
          ) ??
          0;

      return {
        'recordings': recordingsCount,
        'transcriptions': transcriptionsCount,
        'summaries': summariesCount,
        'settings': settingsCount,
      };
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to get database stats: $e');
      return {};
    }
  }

  /// Generate a new UUID
  static String generateId() => _uuid.v4();

  /// Cleanup old data based on retention policies
  Future<int> cleanupOldData({int retentionDays = 30}) async {
    final db = await database;
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));

      final deletedCount = await db.delete(
        'recordings',
        where: 'is_deleted = 1 AND updated_at < ?',
        whereArgs: [cutoffDate.millisecondsSinceEpoch],
      );

      debugPrint('DatabaseHelper: Cleaned up $deletedCount old recordings');
      return deletedCount;
    } catch (e) {
      debugPrint('DatabaseHelper: Cleanup failed: $e');
      return 0;
    }
  }

  /// Execute a transaction
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  /// Vacuum database to optimize storage
  Future<void> vacuum() async {
    final db = await database;
    try {
      await db.execute('VACUUM');
      debugPrint('DatabaseHelper: Database vacuumed successfully');
    } catch (e) {
      debugPrint('DatabaseHelper: Database vacuum failed: $e');
    }
  }
}
