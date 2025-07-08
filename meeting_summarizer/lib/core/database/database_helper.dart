import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'database_schema.dart';
import 'database_migrations.dart';
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

  // Instance fields for test isolation
  Database? _instanceDatabase;
  final String? _customDatabaseName;

  DatabaseHelper._internal({String? customDatabaseName})
    : _customDatabaseName = customDatabaseName;

  /// Get singleton instance of DatabaseHelper
  factory DatabaseHelper({String? customDatabaseName}) {
    // If a custom database name is provided, create a new instance
    if (customDatabaseName != null) {
      return DatabaseHelper._internal(customDatabaseName: customDatabaseName);
    }

    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  /// Get database instance, initializing if necessary
  Future<Database> get database async {
    if (_customDatabaseName != null) {
      _instanceDatabase ??= await _initDatabase();
      return _instanceDatabase!;
    }

    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final databaseName = _customDatabaseName ?? DatabaseSchema.databaseName;
      final path = join(databasesPath, databaseName);

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

  /// Handle database upgrades with proper migration system
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint(
      'DatabaseHelper: Upgrading database from v$oldVersion to v$newVersion',
    );

    // Validate version compatibility
    if (oldVersion < DatabaseSchema.minSupportedVersion) {
      throw Exception(
        'Database version $oldVersion is too old. Minimum supported version is ${DatabaseSchema.minSupportedVersion}',
      );
    }

    if (newVersion > DatabaseSchema.maxSupportedVersion) {
      throw Exception(
        'Database version $newVersion is not supported. Maximum supported version is ${DatabaseSchema.maxSupportedVersion}',
      );
    }

    try {
      // Create backup before migration
      final backupPath = await DatabaseMigrations.createBackup(db);

      try {
        // Execute migration
        await DatabaseMigrations.migrate(db, oldVersion, newVersion);

        // Validate migration success
        final isValid = await DatabaseMigrations.validateMigration(
          db,
          newVersion,
        );
        if (!isValid) {
          throw Exception('Migration validation failed');
        }

        debugPrint('DatabaseHelper: Database upgrade completed successfully');
      } catch (migrationError) {
        debugPrint(
          'DatabaseHelper: Migration failed, attempting to restore backup',
        );

        // Attempt to restore from backup
        try {
          await DatabaseMigrations.restoreFromBackup(db.path, backupPath);
          debugPrint('DatabaseHelper: Backup restored successfully');
        } catch (restoreError) {
          debugPrint(
            'DatabaseHelper: Backup restoration failed: $restoreError',
          );
        }

        rethrow;
      }
    } catch (e) {
      debugPrint('DatabaseHelper: Database upgrade failed: $e');
      rethrow;
    }
  }

  /// Close database connection
  Future<void> close() async {
    if (_customDatabaseName != null && _instanceDatabase != null) {
      await _instanceDatabase!.close();
      _instanceDatabase = null;
      debugPrint('DatabaseHelper: Instance database connection closed');
    } else if (_database != null) {
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

  /// Set setting value (upsert - insert if not exists, update if exists)
  Future<bool> setSetting(String key, String value) async {
    final db = await database;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Try to update first
      final updated = await db.update(
        'settings',
        {'value': value, 'updated_at': now},
        where: 'key = ?',
        whereArgs: [key],
      );

      if (updated > 0) {
        debugPrint('DatabaseHelper: Updated setting $key');
        return true;
      }

      // If no rows were updated, insert a new setting
      await db.insert('settings', {
        'key': key,
        'value': value,
        'type': 'string', // Default type
        'category': 'general', // Default category
        'description': 'User setting',
        'is_sensitive': 0,
        'created_at': now,
        'updated_at': now,
      });

      debugPrint('DatabaseHelper: Inserted new setting $key');
      return true;
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

  /// Get current database version
  Future<int> getDatabaseVersion() async {
    final db = await database;
    final result = await db.rawQuery('PRAGMA user_version');
    return result.first['user_version'] as int;
  }

  /// Check if database needs migration
  Future<bool> needsMigration() async {
    final currentVersion = await getDatabaseVersion();
    return currentVersion < DatabaseSchema.databaseVersion;
  }

  /// Get migration information
  Future<Map<String, dynamic>> getMigrationInfo() async {
    final currentVersion = await getDatabaseVersion();
    final targetVersion = DatabaseSchema.databaseVersion;
    final needsMigration = currentVersion < targetVersion;

    return {
      'currentVersion': currentVersion,
      'targetVersion': targetVersion,
      'needsMigration': needsMigration,
      'minSupportedVersion': DatabaseSchema.minSupportedVersion,
      'maxSupportedVersion': DatabaseSchema.maxSupportedVersion,
      'isVersionSupported':
          currentVersion >= DatabaseSchema.minSupportedVersion,
    };
  }

  // Performance Monitoring and Optimization Methods

  /// Get database performance statistics
  Future<Map<String, dynamic>> getPerformanceStats() async {
    final db = await database;
    try {
      final stats = <String, dynamic>{};

      // Database size information
      final sizeResult = await db.rawQuery('PRAGMA page_count');
      final pageSizeResult = await db.rawQuery('PRAGMA page_size');
      final pageCount = sizeResult.first['page_count'] as int;
      final pageSize = pageSizeResult.first['page_size'] as int;
      stats['database_size_bytes'] = pageCount * pageSize;
      stats['page_count'] = pageCount;
      stats['page_size'] = pageSize;

      // Index usage statistics
      final indexStats = await _getIndexUsageStats();
      stats['index_usage'] = indexStats;

      // Query performance metrics
      final queryStats = await _getQueryPerformanceStats();
      stats['query_performance'] = queryStats;

      // Table statistics
      final tableStats = await _getTableStatistics();
      stats['table_statistics'] = tableStats;

      // Cache hit ratio
      final cacheStats = await _getCacheStatistics();
      stats['cache_statistics'] = cacheStats;

      return stats;
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to get performance stats: $e');
      return {};
    }
  }

  /// Get index usage statistics
  Future<Map<String, dynamic>> _getIndexUsageStats() async {
    final db = await database;
    try {
      final result = await db.rawQuery('''
        SELECT name, tbl_name 
        FROM sqlite_master 
        WHERE type = 'index' AND name NOT LIKE 'sqlite_%'
        ORDER BY name
      ''');

      final indexInfo = <String, Map<String, dynamic>>{};
      for (final row in result) {
        final indexName = row['name'] as String;
        final tableName = row['tbl_name'] as String;

        // Get index info
        final indexDetails = await db.rawQuery('PRAGMA index_info($indexName)');
        indexInfo[indexName] = {
          'table': tableName,
          'columns': indexDetails.map((col) => col['name']).toList(),
          'column_count': indexDetails.length,
        };
      }

      return {'total_indexes': result.length, 'index_details': indexInfo};
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to get index usage stats: $e');
      return {};
    }
  }

  /// Get query performance statistics
  Future<Map<String, dynamic>> _getQueryPerformanceStats() async {
    final db = await database;
    try {
      // Enable query planner for analysis
      await db.execute('PRAGMA query_only = ON');

      final stats = <String, dynamic>{};

      // Test common query patterns and measure performance
      final testQueries = [
        'SELECT COUNT(*) FROM recordings WHERE is_deleted = 0',
        'SELECT * FROM recordings WHERE is_deleted = 0 ORDER BY created_at DESC LIMIT 10',
        'SELECT * FROM transcriptions WHERE recording_id = ? ORDER BY created_at DESC',
        'SELECT * FROM summaries WHERE transcription_id = ? ORDER BY created_at DESC',
        'SELECT * FROM settings WHERE category = ?',
      ];

      final queryPlans = <String, String>{};
      for (final query in testQueries) {
        try {
          final plan = await db.rawQuery('EXPLAIN QUERY PLAN $query');
          queryPlans[query] = plan
              .map((row) => row.values.join(' '))
              .join('\n');
        } catch (e) {
          queryPlans[query] = 'Analysis failed: $e';
        }
      }

      await db.execute('PRAGMA query_only = OFF');

      stats['query_plans'] = queryPlans;
      return stats;
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to get query performance stats: $e');
      await db.execute('PRAGMA query_only = OFF'); // Ensure it's turned off
      return {};
    }
  }

  /// Get table statistics
  Future<Map<String, dynamic>> _getTableStatistics() async {
    final db = await database;
    try {
      final tables = [
        'recordings',
        'transcriptions',
        'summaries',
        'settings',
        'search_index',
      ];
      final tableStats = <String, Map<String, dynamic>>{};

      for (final table in tables) {
        // Row count
        final countResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $table',
        );
        final rowCount = countResult.first['count'] as int;

        // Table info
        final tableInfo = await db.rawQuery('PRAGMA table_info($table)');
        final columnCount = tableInfo.length;

        tableStats[table] = {
          'row_count': rowCount,
          'column_count': columnCount,
          'columns': tableInfo
              .map(
                (col) => {
                  'name': col['name'],
                  'type': col['type'],
                  'nullable': col['notnull'] == 0,
                  'primary_key': col['pk'] == 1,
                },
              )
              .toList(),
        };
      }

      return tableStats;
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to get table statistics: $e');
      return {};
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> _getCacheStatistics() async {
    final db = await database;
    try {
      final cacheSize = await db.rawQuery('PRAGMA cache_size');
      final cacheSpill = await db.rawQuery('PRAGMA cache_spill');

      return {
        'cache_size': cacheSize.first['cache_size'],
        'cache_spill': cacheSpill.first['cache_spill'],
      };
    } catch (e) {
      debugPrint('DatabaseHelper: Failed to get cache statistics: $e');
      return {};
    }
  }

  /// Optimize database performance
  Future<Map<String, dynamic>> optimizeDatabase() async {
    final optimizations = <String, dynamic>{};

    try {
      final db = await database;
      final startTime = DateTime.now();

      // Analyze tables for optimization opportunities
      debugPrint('DatabaseHelper: Starting database optimization');

      // Update table statistics
      await db.execute('ANALYZE');
      optimizations['analyze_completed'] = true;

      // Optimize cache settings
      await db.execute('PRAGMA cache_size = -32768'); // 32MB cache
      await db.execute('PRAGMA temp_store = MEMORY');
      optimizations['cache_optimized'] = true;

      // Optimize journal mode if not already set
      final journalMode = await db.rawQuery('PRAGMA journal_mode');
      if (journalMode.first['journal_mode'] != 'wal') {
        await db.execute('PRAGMA journal_mode = WAL');
        optimizations['journal_mode_optimized'] = true;
      }

      // Optimize synchronous mode
      await db.execute('PRAGMA synchronous = NORMAL');
      optimizations['synchronous_optimized'] = true;

      // Vacuum if needed (only if database is large)
      final pageCount = await db.rawQuery('PRAGMA page_count');
      final pages = pageCount.first['page_count'] as int;

      if (pages > 1000) {
        // Only vacuum if database has more than 1000 pages
        await vacuum();
        optimizations['vacuum_completed'] = true;
      }

      final endTime = DateTime.now();
      optimizations['optimization_time_ms'] = endTime
          .difference(startTime)
          .inMilliseconds;
      optimizations['success'] = true;

      debugPrint(
        'DatabaseHelper: Database optimization completed in ${optimizations['optimization_time_ms']}ms',
      );

      return optimizations;
    } catch (e) {
      debugPrint('DatabaseHelper: Database optimization failed: $e');
      optimizations['success'] = false;
      optimizations['error'] = e.toString();
      return optimizations;
    }
  }

  /// Benchmark query performance
  Future<Map<String, dynamic>> benchmarkQueries({int iterations = 100}) async {
    final db = await database;
    final benchmarks = <String, Map<String, dynamic>>{};

    try {
      debugPrint(
        'DatabaseHelper: Starting query benchmarks with $iterations iterations',
      );

      // Define benchmark queries
      final queries = {
        'simple_count': 'SELECT COUNT(*) FROM recordings WHERE is_deleted = 0',
        'recent_recordings':
            'SELECT * FROM recordings WHERE is_deleted = 0 ORDER BY created_at DESC LIMIT 10',
        'filtered_recordings':
            'SELECT * FROM recordings WHERE is_deleted = 0 AND format = ? LIMIT 20',
        'transcription_lookup':
            'SELECT * FROM transcriptions WHERE recording_id = ? LIMIT 5',
        'summary_lookup':
            'SELECT * FROM summaries WHERE transcription_id = ? LIMIT 5',
        'settings_by_category': 'SELECT * FROM settings WHERE category = ?',
        'search_query':
            'SELECT * FROM search_index WHERE search_index MATCH ? LIMIT 10',
      };

      // Sample data for parameterized queries
      final sampleData = {
        'format': 'wav',
        'recording_id': 'sample-recording-id',
        'transcription_id': 'sample-transcription-id',
        'category': 'general',
        'search_term': 'test',
      };

      for (final entry in queries.entries) {
        final queryName = entry.key;
        final query = entry.value;

        final times = <int>[];

        for (int i = 0; i < iterations; i++) {
          final start = DateTime.now().microsecondsSinceEpoch;

          try {
            if (query.contains('?')) {
              // Parameterized query
              final param = _getParameterForQuery(queryName, sampleData);
              await db.rawQuery(query, [param]);
            } else {
              // Simple query
              await db.rawQuery(query);
            }
          } catch (e) {
            // Skip errors for sample queries
            continue;
          }

          final end = DateTime.now().microsecondsSinceEpoch;
          times.add(end - start);
        }

        if (times.isNotEmpty) {
          times.sort();
          benchmarks[queryName] = {
            'iterations': times.length,
            'avg_microseconds': times.reduce((a, b) => a + b) / times.length,
            'min_microseconds': times.first,
            'max_microseconds': times.last,
            'median_microseconds': times[times.length ~/ 2],
            'p95_microseconds': times[(times.length * 0.95).floor()],
          };
        }
      }

      debugPrint('DatabaseHelper: Query benchmarks completed');
      return benchmarks;
    } catch (e) {
      debugPrint('DatabaseHelper: Query benchmarking failed: $e');
      return {};
    }
  }

  /// Helper method to get appropriate parameter for benchmark queries
  String _getParameterForQuery(
    String queryName,
    Map<String, String> sampleData,
  ) {
    switch (queryName) {
      case 'filtered_recordings':
        return sampleData['format']!;
      case 'transcription_lookup':
        return sampleData['recording_id']!;
      case 'summary_lookup':
        return sampleData['transcription_id']!;
      case 'settings_by_category':
        return sampleData['category']!;
      case 'search_query':
        return sampleData['search_term']!;
      default:
        return '';
    }
  }

  /// Get optimized query suggestions
  Future<List<String>> getOptimizationSuggestions() async {
    final suggestions = <String>[];

    try {
      final stats = await getPerformanceStats();
      final tableStats =
          stats['table_statistics'] as Map<String, dynamic>? ?? {};

      // Analyze table sizes and suggest optimizations
      for (final entry in tableStats.entries) {
        final tableName = entry.key;
        final tableData = entry.value as Map<String, dynamic>;
        final rowCount = tableData['row_count'] as int? ?? 0;

        if (rowCount > 10000) {
          suggestions.add(
            'Consider partitioning large table: $tableName ($rowCount rows)',
          );
        }

        if (rowCount > 1000 && tableName == 'recordings') {
          suggestions.add(
            'Consider archiving old recordings to improve query performance',
          );
        }
      }

      // Check database size
      final dbSize = stats['database_size_bytes'] as int? ?? 0;
      if (dbSize > 100 * 1024 * 1024) {
        // 100MB
        suggestions.add(
          'Database size is large (${(dbSize / 1024 / 1024).toStringAsFixed(1)}MB). Consider running VACUUM',
        );
      }

      // Check for missing indexes based on common patterns
      final indexUsage = stats['index_usage'] as Map<String, dynamic>? ?? {};
      final indexCount = indexUsage['total_indexes'] as int? ?? 0;

      if (indexCount < 10) {
        suggestions.add(
          'Consider adding more indexes for frequently queried columns',
        );
      }

      if (suggestions.isEmpty) {
        suggestions.add('Database performance appears to be well optimized');
      }

      return suggestions;
    } catch (e) {
      debugPrint(
        'DatabaseHelper: Failed to generate optimization suggestions: $e',
      );
      return ['Unable to analyze performance - check database integrity'];
    }
  }

  /// Force database recreation (emergency fallback)
  Future<void> recreateDatabase() async {
    try {
      await close();

      final databasesPath = await getDatabasesPath();
      final databaseName = _customDatabaseName ?? DatabaseSchema.databaseName;
      final path = join(databasesPath, databaseName);

      // Delete existing database
      await deleteDatabase(path);

      // Reinitialize
      if (_customDatabaseName != null) {
        _instanceDatabase = null;
      } else {
        _database = null;
      }
      await database;

      debugPrint('DatabaseHelper: Database recreated successfully');
    } catch (e) {
      debugPrint('DatabaseHelper: Database recreation failed: $e');
      rethrow;
    }
  }
}
