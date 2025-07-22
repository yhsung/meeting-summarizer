/// User role model for role-based access control
library;

import '../../enums/user_rights_enums.dart';
import 'access_permission.dart';

/// Represents a user role with hierarchical permissions and inheritance
class UserRole {
  /// Unique identifier for the role
  final String id;

  /// Human-readable name of the role
  final String name;

  /// Detailed description of the role
  final String description;

  /// Role hierarchy level
  final RoleLevel level;

  /// List of parent role IDs for inheritance
  final List<String> parentRoleIds;

  /// Direct permissions assigned to this role
  final List<AccessPermission> permissions;

  /// Whether the role is currently active
  final bool isActive;

  /// Whether this is a system-defined role
  final bool isSystemRole;

  /// Scope of the role permissions
  final PermissionScope scope;

  /// Maximum number of users that can have this role
  final int? maxUsers;

  /// Role-specific metadata
  final Map<String, dynamic> metadata;

  /// When the role was created
  final DateTime createdAt;

  /// When the role was last updated
  final DateTime updatedAt;

  /// Who created this role
  final String? createdBy;

  const UserRole({
    required this.id,
    required this.name,
    required this.description,
    required this.level,
    this.parentRoleIds = const [],
    this.permissions = const [],
    this.isActive = true,
    this.isSystemRole = false,
    this.scope = PermissionScope.organization,
    this.maxUsers,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  /// Create a copy with updated fields
  UserRole copyWith({
    String? id,
    String? name,
    String? description,
    RoleLevel? level,
    List<String>? parentRoleIds,
    List<AccessPermission>? permissions,
    bool? isActive,
    bool? isSystemRole,
    PermissionScope? scope,
    int? maxUsers,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return UserRole(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      level: level ?? this.level,
      parentRoleIds: parentRoleIds ?? this.parentRoleIds,
      permissions: permissions ?? this.permissions,
      isActive: isActive ?? this.isActive,
      isSystemRole: isSystemRole ?? this.isSystemRole,
      scope: scope ?? this.scope,
      maxUsers: maxUsers ?? this.maxUsers,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// Check if this role has a specific permission
  bool hasPermission(String resource, AccessAction action) {
    return permissions.any(
      (permission) =>
          permission.resource == resource &&
          permission.actions.contains(action) &&
          permission.isActive &&
          !permission.isExpired,
    );
  }

  /// Check if this role has any of the specified permissions
  bool hasAnyPermission(String resource, List<AccessAction> actions) {
    return actions.any((action) => hasPermission(resource, action));
  }

  /// Check if this role has all specified permissions
  bool hasAllPermissions(String resource, List<AccessAction> actions) {
    return actions.every((action) => hasPermission(resource, action));
  }

  /// Get all permissions for a specific resource
  List<AccessPermission> getResourcePermissions(String resource) {
    return permissions.where((p) => p.resource == resource).toList();
  }

  /// Get all unique resources this role has access to
  Set<String> get accessibleResources {
    return permissions.map((p) => p.resource).toSet();
  }

  /// Check if role is at a higher level than another role
  bool isHigherThan(UserRole other) => level.isHigherThan(other.level);

  /// Check if role is at a lower level than another role
  bool isLowerThan(UserRole other) => level.isLowerThan(other.level);

  /// Check if role can inherit from another role
  bool canInheritFrom(UserRole other) {
    // Can inherit from roles at same or higher level
    return level.level >= other.level.level && other.isActive;
  }

  /// Factory method to create default admin role
  static UserRole createAdmin() {
    return UserRole(
      id: 'admin',
      name: 'Administrator',
      description: 'Full system administration privileges with all permissions',
      level: RoleLevel.admin,
      parentRoleIds: [],
      permissions: [
        AccessPermission.createFullAccess(
          resource: '*',
          grantedBy: 'system',
          reason: 'Administrator full access',
        ),
      ],
      isActive: true,
      isSystemRole: true,
      scope: PermissionScope.global,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'system',
    );
  }

  /// Factory method to create default user role
  static UserRole createUser() {
    return UserRole(
      id: 'user',
      name: 'User',
      description:
          'Standard user with basic access to personal data and features',
      level: RoleLevel.user,
      parentRoleIds: [],
      permissions: [
        AccessPermission.createBasicAccess(
          resource: 'personal_data',
          grantedBy: 'system',
          reason: 'User basic access',
        ),
        AccessPermission.createBasicAccess(
          resource: 'recordings',
          grantedBy: 'system',
          reason: 'User recording access',
        ),
      ],
      isActive: true,
      isSystemRole: true,
      scope: PermissionScope.personal,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'system',
    );
  }

  /// Factory method to create default guest role
  static UserRole createGuest() {
    return UserRole(
      id: 'guest',
      name: 'Guest',
      description: 'Limited guest access with read-only permissions',
      level: RoleLevel.guest,
      parentRoleIds: [],
      permissions: [
        AccessPermission.createReadOnlyAccess(
          resource: 'public_data',
          grantedBy: 'system',
          reason: 'Guest read-only access',
        ),
      ],
      isActive: true,
      isSystemRole: true,
      scope: PermissionScope.restricted,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'system',
    );
  }

  /// Factory method to create guardian role
  static UserRole createGuardian() {
    return UserRole(
      id: 'guardian',
      name: 'Guardian',
      description:
          'Guardian role with rights to manage dependent users and consent',
      level: RoleLevel.user,
      parentRoleIds: ['user'],
      permissions: [
        AccessPermission.createGuardianAccess(
          resource: 'dependent_users',
          grantedBy: 'system',
          reason: 'Guardian access to dependent users',
        ),
        AccessPermission.createGuardianAccess(
          resource: 'consent_management',
          grantedBy: 'system',
          reason: 'Guardian consent management',
        ),
      ],
      isActive: true,
      isSystemRole: true,
      scope: PermissionScope.group,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'system',
    );
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'level': level.level,
      'parentRoleIds': parentRoleIds,
      'permissions': permissions.map((p) => p.toJson()).toList(),
      'isActive': isActive,
      'isSystemRole': isSystemRole,
      'scope': scope.value,
      'maxUsers': maxUsers,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  /// Create from JSON representation
  factory UserRole.fromJson(Map<String, dynamic> json) {
    return UserRole(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      level: RoleLevel.values.firstWhere(
        (l) => l.level == json['level'] as int,
      ),
      parentRoleIds: List<String>.from(json['parentRoleIds'] as List? ?? []),
      permissions: (json['permissions'] as List? ?? [])
          .map((p) => AccessPermission.fromJson(p as Map<String, dynamic>))
          .toList(),
      isActive: json['isActive'] as bool? ?? true,
      isSystemRole: json['isSystemRole'] as bool? ?? false,
      scope: PermissionScope.fromString(
        json['scope'] as String? ?? 'organization',
      ),
      maxUsers: json['maxUsers'] as int?,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      createdBy: json['createdBy'] as String?,
    );
  }

  /// Create database map representation
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'level': level.level,
      'parent_role_ids': parentRoleIds.join(','),
      'is_active': isActive ? 1 : 0,
      'is_system_role': isSystemRole ? 1 : 0,
      'scope': scope.value,
      'max_users': maxUsers,
      'metadata': metadata.isNotEmpty ? metadata : null,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'created_by': createdBy,
    };
  }

  /// Create from database map representation
  factory UserRole.fromDatabaseMap(Map<String, dynamic> map) {
    return UserRole(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      level: RoleLevel.values.firstWhere((l) => l.level == map['level'] as int),
      parentRoleIds: (map['parent_role_ids'] as String? ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList(),
      permissions: [], // Permissions loaded separately
      isActive: (map['is_active'] as int? ?? 1) == 1,
      isSystemRole: (map['is_system_role'] as int? ?? 0) == 1,
      scope: PermissionScope.fromString(
        map['scope'] as String? ?? 'organization',
      ),
      maxUsers: map['max_users'] as int?,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      createdBy: map['created_by'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserRole && other.id == id && other.name == name;
  }

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() {
    return 'UserRole(id: $id, name: $name, level: ${level.displayName}, '
        'permissions: ${permissions.length}, active: $isActive)';
  }
}
