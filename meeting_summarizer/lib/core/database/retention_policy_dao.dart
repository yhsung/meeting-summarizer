/// Data Access Object for retention policy database operations
library;

import 'dart:developer';
import 'package:sqflite/sqflite.dart';

import '../models/retention/retention_policy.dart';
import 'database_helper.dart';

/// DAO for managing retention policies in the database
class RetentionPolicyDao {
  final DatabaseHelper _databaseHelper;

  const RetentionPolicyDao(this._databaseHelper);

  /// Table name for retention policies
  static const String tableName = 'retention_policies';

  /// Create the retention policies table
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        data_category TEXT NOT NULL,
        retention_period TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_user_configurable INTEGER NOT NULL DEFAULT 1,
        user_id TEXT,
        auto_delete_enabled INTEGER NOT NULL DEFAULT 1,
        archival_enabled INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        metadata TEXT
      )
    ''');

    // Create indexes for better query performance
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_retention_policies_data_category 
      ON $tableName (data_category)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_retention_policies_user_id 
      ON $tableName (user_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_retention_policies_active 
      ON $tableName (is_active)
    ''');
  }

  /// Insert or update a retention policy
  Future<void> insertOrUpdatePolicy(RetentionPolicy policy) async {
    try {
      final db = await _databaseHelper.database;
      final map = policy.toDatabaseMap();

      await db.insert(
        tableName,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      log(
        'RetentionPolicyDao: Policy ${policy.id} inserted/updated successfully',
      );
    } catch (e) {
      log(
        'RetentionPolicyDao: Error inserting/updating policy ${policy.id}: $e',
      );
      rethrow;
    }
  }

  /// Get a retention policy by ID
  Future<RetentionPolicy?> getPolicyById(String id) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;

      return RetentionPolicy.fromDatabaseMap(maps.first);
    } catch (e) {
      log('RetentionPolicyDao: Error getting policy by ID $id: $e');
      rethrow;
    }
  }

  /// Get all retention policies
  Future<List<RetentionPolicy>> getAllPolicies() async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(tableName, orderBy: 'created_at DESC');

      return maps.map((map) => RetentionPolicy.fromDatabaseMap(map)).toList();
    } catch (e) {
      log('RetentionPolicyDao: Error getting all policies: $e');
      rethrow;
    }
  }

  /// Get active retention policies
  Future<List<RetentionPolicy>> getActivePolicies() async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        tableName,
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'created_at DESC',
      );

      return maps.map((map) => RetentionPolicy.fromDatabaseMap(map)).toList();
    } catch (e) {
      log('RetentionPolicyDao: Error getting active policies: $e');
      rethrow;
    }
  }

  /// Get retention policies by data category
  Future<List<RetentionPolicy>> getPoliciesByCategory(
    String dataCategory,
  ) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        tableName,
        where: 'data_category = ?',
        whereArgs: [dataCategory],
        orderBy: 'created_at DESC',
      );

      return maps.map((map) => RetentionPolicy.fromDatabaseMap(map)).toList();
    } catch (e) {
      log(
        'RetentionPolicyDao: Error getting policies by category $dataCategory: $e',
      );
      rethrow;
    }
  }

  /// Get retention policies for a specific user
  Future<List<RetentionPolicy>> getPoliciesByUserId(String userId) async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        tableName,
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );

      return maps.map((map) => RetentionPolicy.fromDatabaseMap(map)).toList();
    } catch (e) {
      log('RetentionPolicyDao: Error getting policies by user ID $userId: $e');
      rethrow;
    }
  }

  /// Get user-configurable retention policies
  Future<List<RetentionPolicy>> getUserConfigurablePolicies() async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        tableName,
        where: 'is_user_configurable = ?',
        whereArgs: [1],
        orderBy: 'data_category, created_at DESC',
      );

      return maps.map((map) => RetentionPolicy.fromDatabaseMap(map)).toList();
    } catch (e) {
      log('RetentionPolicyDao: Error getting user-configurable policies: $e');
      rethrow;
    }
  }

  /// Update policy active status
  Future<void> updatePolicyStatus(String policyId, bool isActive) async {
    try {
      final db = await _databaseHelper.database;
      await db.update(
        tableName,
        {
          'is_active': isActive ? 1 : 0,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [policyId],
      );

      log(
        'RetentionPolicyDao: Policy $policyId status updated to ${isActive ? 'active' : 'inactive'}',
      );
    } catch (e) {
      log('RetentionPolicyDao: Error updating policy status for $policyId: $e');
      rethrow;
    }
  }

  /// Delete a retention policy
  Future<void> deletePolicy(String policyId) async {
    try {
      final db = await _databaseHelper.database;
      final rowsDeleted = await db.delete(
        tableName,
        where: 'id = ?',
        whereArgs: [policyId],
      );

      if (rowsDeleted == 0) {
        log('RetentionPolicyDao: Policy $policyId not found for deletion');
      } else {
        log('RetentionPolicyDao: Policy $policyId deleted successfully');
      }
    } catch (e) {
      log('RetentionPolicyDao: Error deleting policy $policyId: $e');
      rethrow;
    }
  }

  /// Delete all retention policies for a user
  Future<void> deletePoliciesByUserId(String userId) async {
    try {
      final db = await _databaseHelper.database;
      final rowsDeleted = await db.delete(
        tableName,
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      log('RetentionPolicyDao: $rowsDeleted policies deleted for user $userId');
    } catch (e) {
      log('RetentionPolicyDao: Error deleting policies for user $userId: $e');
      rethrow;
    }
  }

  /// Count total policies
  Future<int> countAllPolicies() async {
    try {
      final db = await _databaseHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName',
      );
      return result.first['count'] as int;
    } catch (e) {
      log('RetentionPolicyDao: Error counting policies: $e');
      rethrow;
    }
  }

  /// Count active policies
  Future<int> countActivePolicies() async {
    try {
      final db = await _databaseHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE is_active = 1',
      );
      return result.first['count'] as int;
    } catch (e) {
      log('RetentionPolicyDao: Error counting active policies: $e');
      rethrow;
    }
  }

  /// Check if a policy exists
  Future<bool> policyExists(String policyId) async {
    try {
      final db = await _databaseHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE id = ?',
        [policyId],
      );
      return (result.first['count'] as int) > 0;
    } catch (e) {
      log('RetentionPolicyDao: Error checking if policy $policyId exists: $e');
      rethrow;
    }
  }

  /// Get policies that need archival or deletion
  Future<List<RetentionPolicy>> getPoliciesForCleanup() async {
    try {
      final db = await _databaseHelper.database;
      final maps = await db.query(
        tableName,
        where:
            'is_active = 1 AND (auto_delete_enabled = 1 OR archival_enabled = 1)',
        orderBy: 'data_category, retention_period',
      );

      return maps.map((map) => RetentionPolicy.fromDatabaseMap(map)).toList();
    } catch (e) {
      log('RetentionPolicyDao: Error getting policies for cleanup: $e');
      rethrow;
    }
  }

  /// Get policy statistics
  Future<Map<String, int>> getPolicyStatistics() async {
    try {
      final db = await _databaseHelper.database;

      // Get total counts
      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName',
      );
      final activeResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE is_active = 1',
      );
      final userConfigurableResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE is_user_configurable = 1',
      );
      final autoDeleteResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE auto_delete_enabled = 1',
      );
      final archivalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName WHERE archival_enabled = 1',
      );

      return {
        'total': totalResult.first['count'] as int,
        'active': activeResult.first['count'] as int,
        'userConfigurable': userConfigurableResult.first['count'] as int,
        'autoDelete': autoDeleteResult.first['count'] as int,
        'archival': archivalResult.first['count'] as int,
      };
    } catch (e) {
      log('RetentionPolicyDao: Error getting policy statistics: $e');
      rethrow;
    }
  }

  /// Bulk insert retention policies
  Future<void> bulkInsertPolicies(List<RetentionPolicy> policies) async {
    try {
      final db = await _databaseHelper.database;
      final batch = db.batch();

      for (final policy in policies) {
        batch.insert(
          tableName,
          policy.toDatabaseMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      log('RetentionPolicyDao: Bulk inserted ${policies.length} policies');
    } catch (e) {
      log('RetentionPolicyDao: Error bulk inserting policies: $e');
      rethrow;
    }
  }

  /// Clear all retention policies (use with caution)
  Future<void> clearAllPolicies() async {
    try {
      final db = await _databaseHelper.database;
      final rowsDeleted = await db.delete(tableName);
      log('RetentionPolicyDao: Cleared $rowsDeleted policies from database');
    } catch (e) {
      log('RetentionPolicyDao: Error clearing all policies: $e');
      rethrow;
    }
  }
}
