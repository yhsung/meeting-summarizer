/// Permission inheritance manager for role-based access control with hierarchical permissions
library;

import 'dart:async';
import 'dart:developer';

import '../models/user_rights/user_profile.dart';
import '../models/user_rights/access_permission.dart';
import '../enums/user_rights_enums.dart';
import '../dao/user_rights_dao.dart';

/// Manages permission inheritance across role hierarchies and user relationships
class PermissionInheritanceManager {
  final UserRightsDao _dao;

  /// Cache for computed permissions to improve performance
  final Map<String, List<AccessPermission>> _computedPermissionsCache = {};

  /// Cache expiry time
  static const Duration _cacheExpiry = Duration(minutes: 15);
  final Map<String, DateTime> _cacheTimestamps = {};

  PermissionInheritanceManager(this._dao);

  /// Get all effective permissions for a user (including inherited permissions)
  Future<List<AccessPermission>> getEffectivePermissions(String userId) async {
    try {
      // Check cache first
      if (_isCacheValid(userId)) {
        return _computedPermissionsCache[userId]!;
      }

      final userProfile = await _dao.getUserProfile(userId);
      if (userProfile == null) {
        log('PermissionInheritanceManager: User $userId not found');
        return [];
      }

      final effectivePermissions = <AccessPermission>[];
      final processedRoles = <String>{};

      // Get direct user permissions
      final directPermissions = await _dao.getUserPermissions(userId);
      effectivePermissions.addAll(directPermissions);

      // Get permissions from all assigned roles (with inheritance)
      for (final roleId in userProfile.roleIds) {
        await _addRolePermissions(roleId, effectivePermissions, processedRoles);
      }

      // Get permissions from delegated rights
      final delegatedPermissions = await _getDelegatedPermissions(userId);
      effectivePermissions.addAll(delegatedPermissions);

      // Get guardian permissions if user is a minor
      if (userProfile.isMinor && userProfile.hasGuardians) {
        final guardianPermissions = await _getGuardianPermissions(userProfile);
        effectivePermissions.addAll(guardianPermissions);
      }

      // Remove duplicates and merge overlapping permissions
      final mergedPermissions = _mergePermissions(effectivePermissions);

      // Cache the result
      _computedPermissionsCache[userId] = mergedPermissions;
      _cacheTimestamps[userId] = DateTime.now();

      log(
        'PermissionInheritanceManager: Computed ${mergedPermissions.length} effective permissions for user $userId',
      );
      return mergedPermissions;
    } catch (e) {
      log(
        'PermissionInheritanceManager: Error computing effective permissions for $userId: $e',
      );
      return [];
    }
  }

  /// Add permissions from a role and its parent roles recursively
  Future<void> _addRolePermissions(
    String roleId,
    List<AccessPermission> permissions,
    Set<String> processedRoles,
  ) async {
    if (processedRoles.contains(roleId)) {
      return; // Avoid circular references
    }

    processedRoles.add(roleId);

    final role = await _dao.getUserRole(roleId);
    if (role == null || !role.isActive) {
      return;
    }

    // Add direct role permissions
    permissions.addAll(role.permissions);

    // Recursively add parent role permissions
    for (final parentRoleId in role.parentRoleIds) {
      await _addRolePermissions(parentRoleId, permissions, processedRoles);
    }
  }

  /// Get permissions delegated to this user
  Future<List<AccessPermission>> _getDelegatedPermissions(String userId) async {
    try {
      final delegations = await _dao.getDelegationsToUser(userId);
      final permissions = <AccessPermission>[];

      for (final delegation in delegations) {
        if (!delegation.isActive || delegation.isExpired) {
          continue;
        }

        // Convert delegated rights to permissions
        for (final right in delegation.delegatedRights) {
          final permission = AccessPermission.createBasicAccess(
            userId: userId,
            resource: right,
            grantedBy: delegation.fromUserId,
            reason: 'Delegated from ${delegation.fromUserId}',
            expiresAt: delegation.expiresAt,
            conditions: {
              'delegation_id': delegation.id,
              'delegated_from': delegation.fromUserId,
            },
          );
          permissions.add(permission);
        }
      }

      return permissions;
    } catch (e) {
      log(
        'PermissionInheritanceManager: Error getting delegated permissions for $userId: $e',
      );
      return [];
    }
  }

  /// Get permissions available to guardians for managing dependent users
  Future<List<AccessPermission>> _getGuardianPermissions(
    UserProfile userProfile,
  ) async {
    try {
      final permissions = <AccessPermission>[];

      for (final guardianId in userProfile.guardianIds) {
        final guardianProfile = await _dao.getUserProfile(guardianId);
        if (guardianProfile == null) continue;

        // Check if guardian has guardian role
        final guardianRoles = await _dao.getUserRoles(guardianId);
        final hasGuardianRole = guardianRoles.any(
          (role) =>
              role.id == 'guardian' ||
              role.name.toLowerCase().contains('guardian'),
        );

        if (hasGuardianRole) {
          // Grant guardian permissions for managing this user's data
          permissions.addAll([
            AccessPermission.createGuardianAccess(
              userId: userProfile.id,
              resource: 'dependent_user_data',
              grantedBy: 'system',
              reason: 'Guardian access for dependent user',
              conditions: {
                'guardian_id': guardianId,
                'dependent_user_id': userProfile.id,
              },
            ),
            AccessPermission.createBasicAccess(
              userId: userProfile.id,
              resource: 'consent_management',
              grantedBy: 'system',
              reason: 'Guardian consent management',
              conditions: {
                'guardian_id': guardianId,
                'dependent_user_id': userProfile.id,
              },
            ),
          ]);
        }
      }

      return permissions;
    } catch (e) {
      log(
        'PermissionInheritanceManager: Error getting guardian permissions: $e',
      );
      return [];
    }
  }

  /// Merge overlapping permissions and remove duplicates
  List<AccessPermission> _mergePermissions(List<AccessPermission> permissions) {
    final resourcePermissions = <String, List<AccessPermission>>{};

    // Group permissions by resource
    for (final permission in permissions) {
      if (!permission.isValid) continue;

      resourcePermissions.putIfAbsent(permission.resource, () => []);
      resourcePermissions[permission.resource]!.add(permission);
    }

    final mergedPermissions = <AccessPermission>[];

    // Merge permissions for each resource
    for (final entry in resourcePermissions.entries) {
      final resource = entry.key;
      final perms = entry.value;

      if (perms.length == 1) {
        mergedPermissions.add(perms.first);
        continue;
      }

      // Combine actions from all permissions for this resource
      final allActions = <AccessAction>{};
      final conditions = <String, dynamic>{};
      DateTime? earliestExpiry;
      String grantedBy = perms.first.grantedBy;
      DateTime grantedAt = perms.first.grantedAt;

      for (final perm in perms) {
        allActions.addAll(perm.actions);
        conditions.addAll(perm.conditions);

        if (perm.expiresAt != null) {
          if (earliestExpiry == null ||
              perm.expiresAt!.isBefore(earliestExpiry)) {
            earliestExpiry = perm.expiresAt;
          }
        }

        // Use the most recent grant
        if (perm.grantedAt.isAfter(grantedAt)) {
          grantedAt = perm.grantedAt;
          grantedBy = perm.grantedBy;
        }
      }

      // Create merged permission
      final mergedPermission = AccessPermission(
        id: _generatePermissionId(),
        userId: perms.first.userId,
        resource: resource,
        actions: allActions.toList(),
        grantedBy: grantedBy,
        grantedAt: grantedAt,
        expiresAt: earliestExpiry,
        isActive: true,
        reason: 'Merged permissions for $resource',
        conditions: conditions,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      mergedPermissions.add(mergedPermission);
    }

    return mergedPermissions;
  }

  /// Check if a user has specific permission (considering inheritance)
  Future<bool> hasPermission(
    String userId,
    String resource,
    AccessAction action,
  ) async {
    try {
      final effectivePermissions = await getEffectivePermissions(userId);

      return effectivePermissions.any(
        (permission) =>
            (permission.resource == resource || permission.resource == '*') &&
            permission.allowsAction(action),
      );
    } catch (e) {
      log(
        'PermissionInheritanceManager: Error checking permission for $userId: $e',
      );
      return false;
    }
  }

  /// Check if a user has any of the specified permissions
  Future<bool> hasAnyPermission(
    String userId,
    String resource,
    List<AccessAction> actions,
  ) async {
    try {
      for (final action in actions) {
        if (await hasPermission(userId, resource, action)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      log(
        'PermissionInheritanceManager: Error checking any permission for $userId: $e',
      );
      return false;
    }
  }

  /// Check if a user has all specified permissions
  Future<bool> hasAllPermissions(
    String userId,
    String resource,
    List<AccessAction> actions,
  ) async {
    try {
      for (final action in actions) {
        if (!await hasPermission(userId, resource, action)) {
          return false;
        }
      }
      return true;
    } catch (e) {
      log(
        'PermissionInheritanceManager: Error checking all permissions for $userId: $e',
      );
      return false;
    }
  }

  /// Get all resources a user has access to
  Future<Set<String>> getAccessibleResources(String userId) async {
    try {
      final effectivePermissions = await getEffectivePermissions(userId);
      return effectivePermissions
          .where((p) => p.isValid)
          .map((p) => p.resource)
          .toSet();
    } catch (e) {
      log(
        'PermissionInheritanceManager: Error getting accessible resources for $userId: $e',
      );
      return {};
    }
  }

  /// Get permissions for a specific resource
  Future<List<AccessPermission>> getResourcePermissions(
    String userId,
    String resource,
  ) async {
    try {
      final effectivePermissions = await getEffectivePermissions(userId);
      return effectivePermissions
          .where((p) => p.resource == resource || p.resource == '*')
          .where((p) => p.isValid)
          .toList();
    } catch (e) {
      log(
        'PermissionInheritanceManager: Error getting resource permissions: $e',
      );
      return [];
    }
  }

  /// Clear permissions cache for a user
  void clearUserCache(String userId) {
    _computedPermissionsCache.remove(userId);
    _cacheTimestamps.remove(userId);
  }

  /// Clear all permissions cache
  void clearAllCache() {
    _computedPermissionsCache.clear();
    _cacheTimestamps.clear();
  }

  /// Check if cache is valid for user
  bool _isCacheValid(String userId) {
    if (!_computedPermissionsCache.containsKey(userId) ||
        !_cacheTimestamps.containsKey(userId)) {
      return false;
    }

    final timestamp = _cacheTimestamps[userId]!;
    return DateTime.now().difference(timestamp) <= _cacheExpiry;
  }

  /// Generate unique permission ID
  String _generatePermissionId() {
    return 'merged_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  /// Dispose resources
  void dispose() {
    clearAllCache();
  }
}
