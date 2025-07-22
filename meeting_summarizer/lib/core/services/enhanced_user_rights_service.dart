/// Enhanced user rights service with role-based access control and comprehensive user management
library;

import 'dart:async';
import 'dart:developer';

import '../models/user_rights/user_profile.dart';
import '../models/user_rights/user_role.dart';
import '../models/user_rights/access_permission.dart';
import '../models/user_rights/rights_delegation.dart';
import '../models/user_rights/access_audit_log.dart';
import '../enums/user_rights_enums.dart';
import '../enums/data_category.dart';
import '../enums/legal_basis.dart';
import '../database/database_helper.dart';
import '../dao/user_rights_dao.dart';
import '../models/user_rights/user_rights_service_event.dart';
import 'user_rights_manager.dart';
import 'gdpr_compliance_service.dart';
import 'data_processing_audit_logger.dart';

/// Comprehensive service for user rights management with role-based access control
class EnhancedUserRightsService {
  static EnhancedUserRightsService? _instance;
  bool _isInitialized = false;

  /// Core services
  late final DatabaseHelper _databaseHelper;
  late final UserRightsDao _userRightsDao;
  late final UserRightsManager _userRightsManager;
  late final GDPRComplianceService _gdprService;
  late final DataProcessingAuditLogger _auditLogger;

  /// In-memory caches
  final Map<String, UserProfile> _userProfilesCache = {};
  final Map<String, UserRole> _rolesCache = {};
  final Map<String, List<AccessPermission>> _permissionsCache = {};

  /// Stream controllers
  final StreamController<UserRightsServiceEvent> _eventController =
      StreamController<UserRightsServiceEvent>.broadcast();

  /// Private constructor for singleton
  EnhancedUserRightsService._();

  /// Get singleton instance
  static EnhancedUserRightsService get instance {
    _instance ??= EnhancedUserRightsService._();
    return _instance!;
  }

  /// Initialize the enhanced user rights service
  Future<void> initialize({
    DatabaseHelper? databaseHelper,
    UserRightsManager? userRightsManager,
    GDPRComplianceService? gdprService,
    DataProcessingAuditLogger? auditLogger,
  }) async {
    if (_isInitialized) return;

    try {
      log('EnhancedUserRightsService: Initializing...');

      // Initialize core services
      _databaseHelper = databaseHelper ?? DatabaseHelper();
      _userRightsManager = userRightsManager ?? UserRightsManager();
      _gdprService = gdprService ?? GDPRComplianceService.instance;
      _auditLogger = auditLogger ?? DataProcessingAuditLogger();

      _userRightsDao = UserRightsDao(_databaseHelper);

      // Ensure dependencies are initialized
      await _databaseHelper.database;
      await _userRightsManager.initialize();
      await _gdprService.initialize();
      await _auditLogger.initialize();

      // Load cached data
      await _loadUserProfiles();
      await _loadRoles();
      await _loadPermissions();

      // Initialize default roles if none exist
      await _initializeDefaultRoles();

      _isInitialized = true;
      log('EnhancedUserRightsService: Initialization completed');

      // Emit initialization event
      _eventController.add(
        UserRightsServiceEvent.createServiceInitialized(
          metadata: {'profilesCount': _userProfilesCache.length},
        ),
      );
    } catch (e) {
      log('EnhancedUserRightsService: Initialization failed: $e');
      throw UserRightsException(
        'Failed to initialize enhanced user rights service: $e',
      );
    }
  }

  /// Dispose of the service
  Future<void> dispose() async {
    try {
      await _eventController.close();
      _userProfilesCache.clear();
      _rolesCache.clear();
      _permissionsCache.clear();
      _isInitialized = false;
      log('EnhancedUserRightsService: Disposed');
    } catch (e) {
      log('EnhancedUserRightsService: Error during disposal: $e');
    }
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Stream of user rights service events
  Stream<UserRightsServiceEvent> get events => _eventController.stream;

  /// Get user profile by ID
  Future<UserProfile?> getUserProfile(String userId) async {
    _ensureInitialized();

    if (_userProfilesCache.containsKey(userId)) {
      return _userProfilesCache[userId];
    }

    try {
      final profile = await _userRightsDao.getUserProfile(userId);
      if (profile != null) {
        _userProfilesCache[userId] = profile;
      }
      return profile;
    } catch (e) {
      log('EnhancedUserRightsService: Error getting user profile $userId: $e');
      return null;
    }
  }

  /// Create or update user profile
  Future<UserProfile> createOrUpdateUserProfile({
    required String userId,
    required String email,
    String? displayName,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    String? phoneNumber,
    List<String> roleIds = const ['user'],
    UserAccountStatus status = UserAccountStatus.active,
    List<String> guardianIds = const [],
    bool requiresParentalConsent = false,
    Map<String, dynamic> preferences = const {},
    Map<String, dynamic> metadata = const {},
  }) async {
    _ensureInitialized();

    try {
      final profile = UserProfile(
        id: userId,
        email: email,
        displayName: displayName ?? email.split('@')[0],
        firstName: firstName,
        lastName: lastName,
        dateOfBirth: dateOfBirth,
        phoneNumber: phoneNumber,
        roleIds: roleIds,
        status: status,
        guardianIds: guardianIds,
        requiresParentalConsent: requiresParentalConsent,
        preferences: Map<String, dynamic>.from(preferences),
        metadata: Map<String, dynamic>.from(metadata),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastLoginAt: null,
      );

      // Save to database
      await _userRightsDao.createUserProfile(profile);

      // Update cache
      _userProfilesCache[userId] = profile;

      // Log profile creation/update
      await _auditLogger.logProcessingStart(
        userId: userId,
        dataCategory: DataCategory.personalInfo,
        purpose: ProcessingPurpose.coreService,
        legalBasis: LegalBasis.contract,
        description: 'Created/updated user profile',
        metadata: {'profileId': userId, 'roleIds': roleIds},
      );

      // Emit profile update event
      _eventController.add(
        UserRightsServiceEvent.createProfileCreated(
          userId: userId,
          metadata: {'roles': roleIds},
        ),
      );

      log('EnhancedUserRightsService: Profile $userId created/updated');
      return profile;
    } catch (e) {
      log(
        'EnhancedUserRightsService: Error creating/updating profile $userId: $e',
      );
      throw UserRightsException('Failed to create/update user profile: $e');
    }
  }

  /// Check if user has specific permission
  Future<bool> hasPermission(
    String userId,
    String resource,
    AccessAction action,
  ) async {
    _ensureInitialized();

    try {
      final profile = await getUserProfile(userId);
      if (profile == null || profile.status != UserAccountStatus.active) {
        return false;
      }

      // Check direct permissions
      final userPermissions = _permissionsCache[userId] ?? [];
      for (final permission in userPermissions) {
        if (permission.resource == resource &&
            permission.actions.contains(action) &&
            permission.isActive &&
            !permission.isExpired) {
          return true;
        }
      }

      // Check role-based permissions
      for (final roleId in profile.roleIds) {
        final role = _rolesCache[roleId];
        if (role == null || !role.isActive) continue;

        for (final permission in role.permissions) {
          if (permission.resource == resource &&
              permission.actions.contains(action) &&
              permission.isActive &&
              !permission.isExpired) {
            return true;
          }
        }
      }

      // Check inherited permissions from parent roles
      for (final roleId in profile.roleIds) {
        if (await _hasInheritedPermission(roleId, resource, action)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      log(
        'EnhancedUserRightsService: Error checking permission for $userId: $e',
      );
      return false;
    }
  }

  /// Check if user has any of the specified permissions
  Future<bool> hasAnyPermission(
    String userId,
    List<String> resources,
    AccessAction action,
  ) async {
    for (final resource in resources) {
      if (await hasPermission(userId, resource, action)) {
        return true;
      }
    }
    return false;
  }

  /// Check if user has all specified permissions
  Future<bool> hasAllPermissions(
    String userId,
    List<String> resources,
    AccessAction action,
  ) async {
    for (final resource in resources) {
      if (!await hasPermission(userId, resource, action)) {
        return false;
      }
    }
    return true;
  }

  /// Grant permission to user
  Future<AccessPermission> grantPermission({
    required String userId,
    required String resource,
    required List<AccessAction> actions,
    required String grantedBy,
    DateTime? expiresAt,
    String? reason,
    Map<String, dynamic> conditions = const {},
  }) async {
    _ensureInitialized();

    try {
      final permission = AccessPermission(
        id: _generatePermissionId(),
        userId: userId,
        resource: resource,
        actions: actions,
        grantedBy: grantedBy,
        grantedAt: DateTime.now(),
        expiresAt: expiresAt,
        isActive: true,
        reason: reason,
        conditions: Map<String, dynamic>.from(conditions),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to database
      await _userRightsDao.createAccessPermission(permission);

      // Update cache
      _permissionsCache.putIfAbsent(userId, () => []).add(permission);

      // Log permission grant
      await _logAccessEvent(
        userId: userId,
        action: AccessAuditAction.permissionGranted,
        resource: resource,
        details:
            'Granted ${actions.map((a) => a.value).join(', ')} permissions',
        performedBy: grantedBy,
        metadata: {'permissionId': permission.id},
      );

      // Emit permission granted event
      _eventController.add(
        UserRightsServiceEvent.createPermissionGranted(
          userId: userId,
          resource: resource,
          metadata: {'actions': actions.map((a) => a.value).toList()},
        ),
      );

      log(
        'EnhancedUserRightsService: Permission granted to $userId for $resource',
      );
      return permission;
    } catch (e) {
      log('EnhancedUserRightsService: Error granting permission: $e');
      throw UserRightsException('Failed to grant permission: $e');
    }
  }

  /// Revoke permission from user
  Future<void> revokePermission(
    String permissionId,
    String revokedBy, {
    String? reason,
  }) async {
    _ensureInitialized();

    try {
      // Get permission
      final permission = await _userRightsDao.getAccessPermission(permissionId);
      if (permission == null) {
        throw UserRightsException('Permission not found: $permissionId');
      }

      // Update permission status
      final revokedPermission = permission.copyWith(
        isActive: false,
        updatedAt: DateTime.now(),
      );

      await _userRightsDao.updateAccessPermission(revokedPermission);

      // Update cache
      final userPermissions = _permissionsCache[permission.userId];
      if (userPermissions != null) {
        final index = userPermissions.indexWhere((p) => p.id == permissionId);
        if (index != -1) {
          userPermissions[index] = revokedPermission;
        }
      }

      // Log permission revocation
      if (permission.userId != null) {
        await _logAccessEvent(
          userId: permission.userId!,
          action: AccessAuditAction.permissionRevoked,
          resource: permission.resource,
          details: reason ?? 'Permission revoked',
          performedBy: revokedBy,
          metadata: {'permissionId': permissionId},
        );
      }

      // Emit permission revoked event
      if (permission.userId != null) {
        _eventController.add(
          UserRightsServiceEvent.createPermissionGranted(
            userId: permission.userId!,
            resource: permission.resource,
            metadata: {
              'actions': permission.actions.map((a) => a.value).toList(),
              'revoked': true,
              'reason': reason ?? 'Permission revoked',
            },
          ),
        );
      }

      log('EnhancedUserRightsService: Permission $permissionId revoked');
    } catch (e) {
      log('EnhancedUserRightsService: Error revoking permission: $e');
      throw UserRightsException('Failed to revoke permission: $e');
    }
  }

  /// Create rights delegation
  Future<RightsDelegation> createDelegation({
    required String fromUserId,
    required String toUserId,
    required List<String> delegatedRights,
    required DateTime expiresAt,
    String? reason,
    List<String> conditions = const [],
  }) async {
    _ensureInitialized();

    try {
      // Verify both users exist and have appropriate status
      final fromUser = await getUserProfile(fromUserId);
      final toUser = await getUserProfile(toUserId);

      if (fromUser == null || toUser == null) {
        throw UserRightsException('One or more users not found');
      }

      if (fromUser.status != UserAccountStatus.active ||
          toUser.status != UserAccountStatus.active) {
        throw UserRightsException('Both users must be active for delegation');
      }

      final delegation = RightsDelegation(
        id: _generateDelegationId(),
        fromUserId: fromUserId,
        toUserId: toUserId,
        delegatedRights: delegatedRights,
        status: DelegationStatus.active,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        reason: reason,
        conditions: conditions,
        metadata: {},
      );

      // Save to database
      await _userRightsDao.createRightsDelegation(delegation);

      // Log delegation creation
      await _logAccessEvent(
        userId: fromUserId,
        action: AccessAuditAction.rightsDelegate,
        resource: 'user_rights',
        details: 'Delegated rights to $toUserId: ${delegatedRights.join(', ')}',
        performedBy: fromUserId,
        metadata: {
          'delegationId': delegation.id,
          'toUserId': toUserId,
          'rights': delegatedRights,
        },
      );

      // Emit delegation created event
      _eventController.add(
        UserRightsServiceEvent.createGuardianshipAssigned(
          userId: fromUserId,
          guardianId: toUserId,
          metadata: {
            'delegatedRights': delegatedRights,
            'delegationType': 'rights_delegation',
          },
        ),
      );

      log(
        'EnhancedUserRightsService: Rights delegation created: ${delegation.id}',
      );
      return delegation;
    } catch (e) {
      log('EnhancedUserRightsService: Error creating delegation: $e');
      throw UserRightsException('Failed to create rights delegation: $e');
    }
  }

  /// Get user's access history
  Future<List<AccessAuditLog>> getUserAccessHistory(
    String userId, {
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 100,
  }) async {
    _ensureInitialized();

    try {
      return await _userRightsDao.getUserAuditLogs(userId, limit: limit);
    } catch (e) {
      log(
        'EnhancedUserRightsService: Error getting access history for $userId: $e',
      );
      return [];
    }
  }

  /// Check if user has inherited permission through role hierarchy
  Future<bool> _hasInheritedPermission(
    String roleId,
    String resource,
    AccessAction action,
  ) async {
    final role = _rolesCache[roleId];
    if (role == null) return false;

    for (final parentRoleId in role.parentRoleIds) {
      final parentRole = _rolesCache[parentRoleId];
      if (parentRole == null || !parentRole.isActive) continue;

      // Check parent role permissions
      for (final permission in parentRole.permissions) {
        if (permission.resource == resource &&
            permission.actions.contains(action) &&
            permission.isActive &&
            !permission.isExpired) {
          return true;
        }
      }

      // Check recursively
      if (await _hasInheritedPermission(parentRoleId, resource, action)) {
        return true;
      }
    }

    return false;
  }

  /// Log access event
  Future<void> _logAccessEvent({
    required String userId,
    required AccessAuditAction action,
    required String resource,
    required String details,
    required String performedBy,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final auditLog = AccessAuditLog(
        id: _generateAuditId(),
        userId: userId,
        action: action,
        resource: resource,
        timestamp: DateTime.now(),
        description: details,
        ipAddress: null, // Would be populated in real implementation
        userAgent: null, // Would be populated in real implementation
        success: true,
        contextData: Map<String, dynamic>.from(metadata),
        metadata: {'performedBy': performedBy},
      );

      await _userRightsDao.createAuditLog(auditLog);
    } catch (e) {
      log('EnhancedUserRightsService: Error logging access event: $e');
    }
  }

  /// Load user profiles from database
  Future<void> _loadUserProfiles() async {
    try {
      final profiles = await _userRightsDao.getAllUserProfiles();
      _userProfilesCache.clear();
      for (final profile in profiles) {
        _userProfilesCache[profile.id] = profile;
      }
      log('EnhancedUserRightsService: Loaded ${profiles.length} user profiles');
    } catch (e) {
      log('EnhancedUserRightsService: Error loading user profiles: $e');
    }
  }

  /// Load roles from database
  Future<void> _loadRoles() async {
    try {
      final roles = await _userRightsDao.getAllUserRoles();
      _rolesCache.clear();
      for (final role in roles) {
        _rolesCache[role.id] = role;
      }
      log('EnhancedUserRightsService: Loaded ${roles.length} roles');
    } catch (e) {
      log('EnhancedUserRightsService: Error loading roles: $e');
    }
  }

  /// Load permissions from database
  Future<void> _loadPermissions() async {
    try {
      // Load permissions for all users
      final profiles = await _userRightsDao.getAllUserProfiles();
      final allPermissions = <AccessPermission>[];
      for (final profile in profiles) {
        final userPermissions = await _userRightsDao.getUserPermissions(
          profile.id,
        );
        allPermissions.addAll(userPermissions);
      }
      _permissionsCache.clear();
      for (final permission in allPermissions) {
        if (permission.userId != null) {
          _permissionsCache
              .putIfAbsent(permission.userId!, () => [])
              .add(permission);
        }
      }
      log(
        'EnhancedUserRightsService: Loaded ${allPermissions.length} permissions',
      );
    } catch (e) {
      log('EnhancedUserRightsService: Error loading permissions: $e');
    }
  }

  /// Initialize default roles
  Future<void> _initializeDefaultRoles() async {
    if (_rolesCache.isNotEmpty) return;

    try {
      final defaultRoles = [
        UserRole.createAdmin(),
        UserRole.createUser(),
        UserRole.createGuest(),
        UserRole.createGuardian(),
      ];

      for (final role in defaultRoles) {
        await _userRightsDao.createUserRole(role);
        _rolesCache[role.id] = role;
      }

      log(
        'EnhancedUserRightsService: Created ${defaultRoles.length} default roles',
      );
    } catch (e) {
      log('EnhancedUserRightsService: Error creating default roles: $e');
    }
  }

  /// Generate permission ID
  String _generatePermissionId() =>
      'perm_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';

  /// Generate delegation ID
  String _generateDelegationId() =>
      'deleg_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';

  /// Generate audit ID
  String _generateAuditId() =>
      'audit_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';

  /// Get user permissions (for dashboard compatibility)
  Future<List<AccessPermission>> getUserPermissions(String userId) async {
    try {
      _ensureInitialized();
      return await _userRightsDao.getUserPermissions(userId);
    } catch (e) {
      log('EnhancedUserRightsService: Error getting user permissions: $e');
      return [];
    }
  }

  /// Get delegations from user (for dashboard compatibility)
  Future<List<RightsDelegation>> getDelegationsFromUser(String userId) async {
    try {
      _ensureInitialized();
      return await _userRightsDao.getDelegationsFromUser(userId);
    } catch (e) {
      log('EnhancedUserRightsService: Error getting delegations from user: $e');
      return [];
    }
  }

  /// Get delegations to user (for dashboard compatibility)
  Future<List<RightsDelegation>> getDelegationsToUser(String userId) async {
    try {
      _ensureInitialized();
      return await _userRightsDao.getDelegationsToUser(userId);
    } catch (e) {
      log('EnhancedUserRightsService: Error getting delegations to user: $e');
      return [];
    }
  }

  /// Ensure service is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw UserRightsException('Enhanced user rights service not initialized');
    }
  }
}

/// User rights exception
class UserRightsException implements Exception {
  final String message;
  final String? code;
  final dynamic cause;

  const UserRightsException(this.message, {this.code, this.cause});

  @override
  String toString() => 'UserRightsException: $message';
}
