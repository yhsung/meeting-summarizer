/// Data Access Object for user rights management database operations
library;

import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/user_rights/user_profile.dart';
import '../models/user_rights/user_role.dart';
import '../models/user_rights/access_permission.dart';
import '../models/user_rights/rights_delegation.dart';
import '../models/user_rights/access_audit_log.dart';
import '../models/user_rights/user_rights_service_event.dart';

/// Database Access Object for user rights management operations
class UserRightsDao {
  static const String _userProfilesTable = 'user_profiles';
  static const String _userRolesTable = 'user_roles';
  static const String _accessPermissionsTable = 'access_permissions';
  static const String _rightsDelegationsTable = 'rights_delegations';
  static const String _accessAuditLogsTable = 'access_audit_logs';
  static const String _userRightsEventsTable = 'user_rights_events';
  static const String _userRoleAssignmentsTable = 'user_role_assignments';
  static const String _rolePermissionsTable = 'role_permissions';

  final DatabaseHelper _databaseHelper;

  UserRightsDao(this._databaseHelper);

  /// Get database instance
  Future<Database> get _database async => await _databaseHelper.database;

  // User Profile Operations

  /// Create a new user profile
  Future<void> createUserProfile(UserProfile profile) async {
    final db = await _database;
    await db.insert(_userProfilesTable, profile.toDatabaseMap());
  }

  /// Get user profile by ID
  Future<UserProfile?> getUserProfile(String userId) async {
    final db = await _database;
    final maps = await db.query(
      _userProfilesTable,
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (maps.isEmpty) return null;
    return UserProfile.fromDatabaseMap(maps.first);
  }

  /// Get user profile by email
  Future<UserProfile?> getUserProfileByEmail(String email) async {
    final db = await _database;
    final maps = await db.query(
      _userProfilesTable,
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isEmpty) return null;
    return UserProfile.fromDatabaseMap(maps.first);
  }

  /// Update user profile
  Future<void> updateUserProfile(UserProfile profile) async {
    final db = await _database;
    await db.update(
      _userProfilesTable,
      profile.toDatabaseMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  /// Delete user profile
  Future<void> deleteUserProfile(String userId) async {
    final db = await _database;
    await db.delete(_userProfilesTable, where: 'id = ?', whereArgs: [userId]);
  }

  /// Get all user profiles
  Future<List<UserProfile>> getAllUserProfiles() async {
    final db = await _database;
    final maps = await db.query(_userProfilesTable);
    return maps.map((map) => UserProfile.fromDatabaseMap(map)).toList();
  }

  // User Role Operations

  /// Create a new user role
  Future<void> createUserRole(UserRole role) async {
    final db = await _database;
    await db.transaction((txn) async {
      // Insert role
      await txn.insert(_userRolesTable, role.toDatabaseMap());

      // Insert role permissions
      for (final permission in role.permissions) {
        await txn.insert(_rolePermissionsTable, {
          'role_id': role.id,
          'permission_id': permission.id,
        });
        await txn.insert(_accessPermissionsTable, permission.toDatabaseMap());
      }
    });
  }

  /// Get user role by ID
  Future<UserRole?> getUserRole(String roleId) async {
    final db = await _database;
    final maps = await db.query(
      _userRolesTable,
      where: 'id = ?',
      whereArgs: [roleId],
    );

    if (maps.isEmpty) return null;
    final role = UserRole.fromDatabaseMap(maps.first);

    // Load permissions
    final permissions = await _getRolePermissions(roleId);
    return role.copyWith(permissions: permissions);
  }

  /// Get role permissions
  Future<List<AccessPermission>> _getRolePermissions(String roleId) async {
    final db = await _database;
    final maps = await db.rawQuery(
      '''
      SELECT p.* FROM $_accessPermissionsTable p
      JOIN $_rolePermissionsTable rp ON p.id = rp.permission_id
      WHERE rp.role_id = ?
    ''',
      [roleId],
    );

    return maps.map((map) => AccessPermission.fromDatabaseMap(map)).toList();
  }

  /// Update user role
  Future<void> updateUserRole(UserRole role) async {
    final db = await _database;
    await db.transaction((txn) async {
      // Update role
      await txn.update(
        _userRolesTable,
        role.toDatabaseMap(),
        where: 'id = ?',
        whereArgs: [role.id],
      );

      // Delete existing role permissions
      await txn.delete(
        _rolePermissionsTable,
        where: 'role_id = ?',
        whereArgs: [role.id],
      );

      // Insert updated permissions
      for (final permission in role.permissions) {
        await txn.insert(_rolePermissionsTable, {
          'role_id': role.id,
          'permission_id': permission.id,
        });
        await txn.insert(
          _accessPermissionsTable,
          permission.toDatabaseMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Delete user role
  Future<void> deleteUserRole(String roleId) async {
    final db = await _database;
    await db.delete(_userRolesTable, where: 'id = ?', whereArgs: [roleId]);
  }

  /// Get all user roles
  Future<List<UserRole>> getAllUserRoles() async {
    final db = await _database;
    final maps = await db.query(_userRolesTable);
    final roles = <UserRole>[];

    for (final map in maps) {
      final role = UserRole.fromDatabaseMap(map);
      final permissions = await _getRolePermissions(role.id);
      roles.add(role.copyWith(permissions: permissions));
    }

    return roles;
  }

  // User Role Assignment Operations

  /// Assign role to user
  Future<void> assignRoleToUser(String userId, String roleId) async {
    final db = await _database;
    await db.insert(_userRoleAssignmentsTable, {
      'user_id': userId,
      'role_id': roleId,
      'assigned_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Remove role from user
  Future<void> removeRoleFromUser(String userId, String roleId) async {
    final db = await _database;
    await db.delete(
      _userRoleAssignmentsTable,
      where: 'user_id = ? AND role_id = ?',
      whereArgs: [userId, roleId],
    );
  }

  /// Get user roles
  Future<List<UserRole>> getUserRoles(String userId) async {
    final db = await _database;
    final maps = await db.rawQuery(
      '''
      SELECT r.* FROM $_userRolesTable r
      JOIN $_userRoleAssignmentsTable ura ON r.id = ura.role_id
      WHERE ura.user_id = ?
    ''',
      [userId],
    );

    final roles = <UserRole>[];
    for (final map in maps) {
      final role = UserRole.fromDatabaseMap(map);
      final permissions = await _getRolePermissions(role.id);
      roles.add(role.copyWith(permissions: permissions));
    }

    return roles;
  }

  // Access Permission Operations

  /// Create access permission
  Future<void> createAccessPermission(AccessPermission permission) async {
    final db = await _database;
    await db.insert(_accessPermissionsTable, permission.toDatabaseMap());
  }

  /// Get access permission by ID
  Future<AccessPermission?> getAccessPermission(String permissionId) async {
    final db = await _database;
    final maps = await db.query(
      _accessPermissionsTable,
      where: 'id = ?',
      whereArgs: [permissionId],
    );

    if (maps.isEmpty) return null;
    return AccessPermission.fromDatabaseMap(maps.first);
  }

  /// Get user permissions
  Future<List<AccessPermission>> getUserPermissions(String userId) async {
    final db = await _database;
    final maps = await db.query(
      _accessPermissionsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    return maps.map((map) => AccessPermission.fromDatabaseMap(map)).toList();
  }

  /// Update access permission
  Future<void> updateAccessPermission(AccessPermission permission) async {
    final db = await _database;
    await db.update(
      _accessPermissionsTable,
      permission.toDatabaseMap(),
      where: 'id = ?',
      whereArgs: [permission.id],
    );
  }

  /// Delete access permission
  Future<void> deleteAccessPermission(String permissionId) async {
    final db = await _database;
    await db.delete(
      _accessPermissionsTable,
      where: 'id = ?',
      whereArgs: [permissionId],
    );
  }

  // Rights Delegation Operations

  /// Create rights delegation
  Future<void> createRightsDelegation(RightsDelegation delegation) async {
    final db = await _database;
    await db.insert(_rightsDelegationsTable, delegation.toDatabaseMap());
  }

  /// Get rights delegation by ID
  Future<RightsDelegation?> getRightsDelegation(String delegationId) async {
    final db = await _database;
    final maps = await db.query(
      _rightsDelegationsTable,
      where: 'id = ?',
      whereArgs: [delegationId],
    );

    if (maps.isEmpty) return null;
    return RightsDelegation.fromDatabaseMap(maps.first);
  }

  /// Get delegations from user
  Future<List<RightsDelegation>> getDelegationsFromUser(
    String fromUserId,
  ) async {
    final db = await _database;
    final maps = await db.query(
      _rightsDelegationsTable,
      where: 'from_user_id = ?',
      whereArgs: [fromUserId],
    );

    return maps.map((map) => RightsDelegation.fromDatabaseMap(map)).toList();
  }

  /// Get delegations to user
  Future<List<RightsDelegation>> getDelegationsToUser(String toUserId) async {
    final db = await _database;
    final maps = await db.query(
      _rightsDelegationsTable,
      where: 'to_user_id = ?',
      whereArgs: [toUserId],
    );

    return maps.map((map) => RightsDelegation.fromDatabaseMap(map)).toList();
  }

  /// Update rights delegation
  Future<void> updateRightsDelegation(RightsDelegation delegation) async {
    final db = await _database;
    await db.update(
      _rightsDelegationsTable,
      delegation.toDatabaseMap(),
      where: 'id = ?',
      whereArgs: [delegation.id],
    );
  }

  /// Delete rights delegation
  Future<void> deleteRightsDelegation(String delegationId) async {
    final db = await _database;
    await db.delete(
      _rightsDelegationsTable,
      where: 'id = ?',
      whereArgs: [delegationId],
    );
  }

  // Audit Log Operations

  /// Create audit log entry
  Future<void> createAuditLog(AccessAuditLog auditLog) async {
    final db = await _database;
    await db.insert(_accessAuditLogsTable, auditLog.toDatabaseMap());
  }

  /// Get audit logs for user
  Future<List<AccessAuditLog>> getUserAuditLogs(
    String userId, {
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await _database;
    final maps = await db.query(
      _accessAuditLogsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => AccessAuditLog.fromDatabaseMap(map)).toList();
  }

  /// Get audit logs by resource
  Future<List<AccessAuditLog>> getResourceAuditLogs(
    String resource, {
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await _database;
    final maps = await db.query(
      _accessAuditLogsTable,
      where: 'resource = ?',
      whereArgs: [resource],
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => AccessAuditLog.fromDatabaseMap(map)).toList();
  }

  /// Get recent audit logs
  Future<List<AccessAuditLog>> getRecentAuditLogs({
    int limit = 100,
    Duration? since,
  }) async {
    final db = await _database;
    final sinceTimestamp = since != null
        ? DateTime.now().subtract(since).millisecondsSinceEpoch
        : 0;

    final maps = await db.query(
      _accessAuditLogsTable,
      where: 'timestamp >= ?',
      whereArgs: [sinceTimestamp],
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return maps.map((map) => AccessAuditLog.fromDatabaseMap(map)).toList();
  }

  // Service Event Operations

  /// Create service event
  Future<void> createServiceEvent(UserRightsServiceEvent event) async {
    final db = await _database;
    await db.insert(_userRightsEventsTable, event.toDatabaseMap());
  }

  /// Get service events
  Future<List<UserRightsServiceEvent>> getServiceEvents({
    String? userId,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await _database;
    final maps = await db.query(
      _userRightsEventsTable,
      where: userId != null ? 'user_id = ?' : null,
      whereArgs: userId != null ? [userId] : null,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return maps
        .map((map) => UserRightsServiceEvent.fromDatabaseMap(map))
        .toList();
  }

  /// Get events requiring action
  Future<List<UserRightsServiceEvent>> getEventsRequiringAction({
    int limit = 50,
  }) async {
    final db = await _database;
    final maps = await db.query(
      _userRightsEventsTable,
      where: 'requires_action = 1',
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return maps
        .map((map) => UserRightsServiceEvent.fromDatabaseMap(map))
        .toList();
  }

  // Database Schema Operations

  /// Create all user rights tables
  Future<void> createTables(Database db) async {
    await _createUserProfilesTable(db);
    await _createUserRolesTable(db);
    await _createAccessPermissionsTable(db);
    await _createRightsDelegationsTable(db);
    await _createAccessAuditLogsTable(db);
    await _createUserRightsEventsTable(db);
    await _createUserRoleAssignmentsTable(db);
    await _createRolePermissionsTable(db);
  }

  Future<void> _createUserProfilesTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_userProfilesTable (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL UNIQUE,
        display_name TEXT NOT NULL,
        first_name TEXT,
        last_name TEXT,
        date_of_birth INTEGER,
        phone_number TEXT,
        role_ids TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'pending',
        guardian_ids TEXT NOT NULL DEFAULT '',
        requires_parental_consent INTEGER NOT NULL DEFAULT 0,
        preferences TEXT,
        metadata TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        last_login_at INTEGER
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_user_profiles_email ON $_userProfilesTable(email)',
    );
    await db.execute(
      'CREATE INDEX idx_user_profiles_status ON $_userProfilesTable(status)',
    );
  }

  Future<void> _createUserRolesTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_userRolesTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        level INTEGER NOT NULL,
        parent_role_ids TEXT NOT NULL DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1,
        is_system_role INTEGER NOT NULL DEFAULT 0,
        scope TEXT NOT NULL DEFAULT 'organization',
        max_users INTEGER,
        metadata TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        created_by TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_user_roles_level ON $_userRolesTable(level)',
    );
    await db.execute(
      'CREATE INDEX idx_user_roles_active ON $_userRolesTable(is_active)',
    );
  }

  Future<void> _createAccessPermissionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_accessPermissionsTable (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        resource TEXT NOT NULL,
        actions TEXT NOT NULL,
        granted_by TEXT NOT NULL,
        granted_at INTEGER NOT NULL,
        expires_at INTEGER,
        is_active INTEGER NOT NULL DEFAULT 1,
        reason TEXT,
        conditions TEXT,
        metadata TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_access_permissions_user_id ON $_accessPermissionsTable(user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_access_permissions_resource ON $_accessPermissionsTable(resource)',
    );
  }

  Future<void> _createRightsDelegationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_rightsDelegationsTable (
        id TEXT PRIMARY KEY,
        from_user_id TEXT NOT NULL,
        to_user_id TEXT NOT NULL,
        delegated_rights TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'active',
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        reason TEXT,
        conditions TEXT NOT NULL DEFAULT '',
        metadata TEXT,
        updated_at INTEGER,
        approved_by TEXT,
        approved_at INTEGER,
        revoked_by TEXT,
        revoked_at INTEGER,
        revocation_reason TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_rights_delegations_from_user ON $_rightsDelegationsTable(from_user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_rights_delegations_to_user ON $_rightsDelegationsTable(to_user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_rights_delegations_status ON $_rightsDelegationsTable(status)',
    );
  }

  Future<void> _createAccessAuditLogsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_accessAuditLogsTable (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        action TEXT NOT NULL,
        resource TEXT NOT NULL,
        description TEXT NOT NULL,
        ip_address TEXT,
        user_agent TEXT,
        location TEXT,
        success INTEGER NOT NULL DEFAULT 1,
        error_message TEXT,
        context_data TEXT,
        risk_level TEXT NOT NULL DEFAULT 'low',
        session_id TEXT,
        timestamp INTEGER NOT NULL,
        metadata TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_access_audit_logs_user_id ON $_accessAuditLogsTable(user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_access_audit_logs_resource ON $_accessAuditLogsTable(resource)',
    );
    await db.execute(
      'CREATE INDEX idx_access_audit_logs_timestamp ON $_accessAuditLogsTable(timestamp)',
    );
    await db.execute(
      'CREATE INDEX idx_access_audit_logs_action ON $_accessAuditLogsTable(action)',
    );
  }

  Future<void> _createUserRightsEventsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_userRightsEventsTable (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        user_id TEXT,
        resource TEXT,
        payload TEXT,
        source TEXT NOT NULL DEFAULT 'user_rights_service',
        severity TEXT NOT NULL DEFAULT 'info',
        requires_action INTEGER NOT NULL DEFAULT 0,
        correlation_id TEXT,
        timestamp INTEGER NOT NULL,
        metadata TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_user_rights_events_user_id ON $_userRightsEventsTable(user_id)',
    );
    await db.execute(
      'CREATE INDEX idx_user_rights_events_type ON $_userRightsEventsTable(type)',
    );
    await db.execute(
      'CREATE INDEX idx_user_rights_events_timestamp ON $_userRightsEventsTable(timestamp)',
    );
    await db.execute(
      'CREATE INDEX idx_user_rights_events_requires_action ON $_userRightsEventsTable(requires_action)',
    );
  }

  Future<void> _createUserRoleAssignmentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_userRoleAssignmentsTable (
        user_id TEXT NOT NULL,
        role_id TEXT NOT NULL,
        assigned_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, role_id)
      )
    ''');
  }

  Future<void> _createRolePermissionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_rolePermissionsTable (
        role_id TEXT NOT NULL,
        permission_id TEXT NOT NULL,
        PRIMARY KEY (role_id, permission_id)
      )
    ''');
  }
}
