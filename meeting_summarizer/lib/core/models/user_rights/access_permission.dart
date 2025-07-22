/// Access permission model for fine-grained permission management
library;

import '../../enums/user_rights_enums.dart';

/// Represents a specific access permission with detailed control
class AccessPermission {
  /// Unique identifier for the permission
  final String id;

  /// User ID this permission is granted to (null for role permissions)
  final String? userId;

  /// Resource this permission applies to
  final String resource;

  /// List of actions allowed on the resource
  final List<AccessAction> actions;

  /// Who granted this permission
  final String grantedBy;

  /// When the permission was granted
  final DateTime grantedAt;

  /// When the permission expires (null for permanent)
  final DateTime? expiresAt;

  /// Whether the permission is currently active
  final bool isActive;

  /// Reason for granting the permission
  final String? reason;

  /// Additional conditions or constraints
  final Map<String, dynamic> conditions;

  /// Permission-specific metadata
  final Map<String, dynamic> metadata;

  /// When the permission was created
  final DateTime createdAt;

  /// When the permission was last updated
  final DateTime updatedAt;

  const AccessPermission({
    required this.id,
    this.userId,
    required this.resource,
    required this.actions,
    required this.grantedBy,
    required this.grantedAt,
    this.expiresAt,
    this.isActive = true,
    this.reason,
    this.conditions = const {},
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a copy with updated fields
  AccessPermission copyWith({
    String? id,
    String? userId,
    String? resource,
    List<AccessAction>? actions,
    String? grantedBy,
    DateTime? grantedAt,
    DateTime? expiresAt,
    bool? isActive,
    String? reason,
    Map<String, dynamic>? conditions,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccessPermission(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      resource: resource ?? this.resource,
      actions: actions ?? this.actions,
      grantedBy: grantedBy ?? this.grantedBy,
      grantedAt: grantedAt ?? this.grantedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      reason: reason ?? this.reason,
      conditions: conditions ?? this.conditions,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if the permission is currently expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Check if the permission is currently valid
  bool get isValid => isActive && !isExpired;

  /// Check if permission allows specific action
  bool allowsAction(AccessAction action) {
    return isValid && actions.contains(action);
  }

  /// Check if permission allows any of the specified actions
  bool allowsAnyAction(List<AccessAction> actions) {
    return isValid && actions.any((action) => this.actions.contains(action));
  }

  /// Check if permission allows all specified actions
  bool allowsAllActions(List<AccessAction> actions) {
    return isValid && actions.every((action) => this.actions.contains(action));
  }

  /// Get remaining time until expiration
  Duration? get remainingTime {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (expiresAt!.isBefore(now)) return Duration.zero;
    return expiresAt!.difference(now);
  }

  /// Get days until expiration
  int? get daysUntilExpiration {
    final remaining = remainingTime;
    if (remaining == null) return null;
    return remaining.inDays;
  }

  /// Check if permission is expiring soon (within specified days)
  bool isExpiringSoon([int days = 7]) {
    final daysLeft = daysUntilExpiration;
    return daysLeft != null && daysLeft <= days && daysLeft > 0;
  }

  /// Check if condition is met
  bool checkCondition(String key, dynamic value) {
    return conditions[key] == value;
  }

  /// Factory method to create full access permission
  static AccessPermission createFullAccess({
    String? userId,
    required String resource,
    required String grantedBy,
    String? reason,
    DateTime? expiresAt,
    Map<String, dynamic> conditions = const {},
  }) {
    final now = DateTime.now();
    return AccessPermission(
      id: _generatePermissionId(),
      userId: userId,
      resource: resource,
      actions: AccessAction.values,
      grantedBy: grantedBy,
      grantedAt: now,
      expiresAt: expiresAt,
      isActive: true,
      reason: reason ?? 'Full access permission',
      conditions: conditions,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Factory method to create read-only access permission
  static AccessPermission createReadOnlyAccess({
    String? userId,
    required String resource,
    required String grantedBy,
    String? reason,
    DateTime? expiresAt,
    Map<String, dynamic> conditions = const {},
  }) {
    final now = DateTime.now();
    return AccessPermission(
      id: _generatePermissionId(),
      userId: userId,
      resource: resource,
      actions: [AccessAction.read],
      grantedBy: grantedBy,
      grantedAt: now,
      expiresAt: expiresAt,
      isActive: true,
      reason: reason ?? 'Read-only access permission',
      conditions: conditions,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Factory method to create basic user access permission
  static AccessPermission createBasicAccess({
    String? userId,
    required String resource,
    required String grantedBy,
    String? reason,
    DateTime? expiresAt,
    Map<String, dynamic> conditions = const {},
  }) {
    final now = DateTime.now();
    return AccessPermission(
      id: _generatePermissionId(),
      userId: userId,
      resource: resource,
      actions: [
        AccessAction.read,
        AccessAction.write,
        AccessAction.create,
        AccessAction.update,
      ],
      grantedBy: grantedBy,
      grantedAt: now,
      expiresAt: expiresAt,
      isActive: true,
      reason: reason ?? 'Basic user access permission',
      conditions: conditions,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Factory method to create guardian access permission
  static AccessPermission createGuardianAccess({
    String? userId,
    required String resource,
    required String grantedBy,
    String? reason,
    DateTime? expiresAt,
    Map<String, dynamic> conditions = const {},
  }) {
    final now = DateTime.now();
    return AccessPermission(
      id: _generatePermissionId(),
      userId: userId,
      resource: resource,
      actions: [
        AccessAction.read,
        AccessAction.write,
        AccessAction.update,
        AccessAction.admin,
      ],
      grantedBy: grantedBy,
      grantedAt: now,
      expiresAt: expiresAt,
      isActive: true,
      reason: reason ?? 'Guardian access permission',
      conditions: conditions,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'resource': resource,
      'actions': AccessAction.toStringList(actions),
      'grantedBy': grantedBy,
      'grantedAt': grantedAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'isActive': isActive,
      'reason': reason,
      'conditions': conditions,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create from JSON representation
  factory AccessPermission.fromJson(Map<String, dynamic> json) {
    return AccessPermission(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      resource: json['resource'] as String,
      actions: AccessAction.fromStringList(
        List<String>.from(json['actions'] as List? ?? []),
      ),
      grantedBy: json['grantedBy'] as String,
      grantedAt: DateTime.parse(json['grantedAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      reason: json['reason'] as String?,
      conditions: Map<String, dynamic>.from(json['conditions'] as Map? ?? {}),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Create database map representation
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'user_id': userId,
      'resource': resource,
      'actions': AccessAction.toStringList(actions).join(','),
      'granted_by': grantedBy,
      'granted_at': grantedAt.millisecondsSinceEpoch,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
      'is_active': isActive ? 1 : 0,
      'reason': reason,
      'conditions': conditions.isNotEmpty ? conditions : null,
      'metadata': metadata.isNotEmpty ? metadata : null,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Create from database map representation
  factory AccessPermission.fromDatabaseMap(Map<String, dynamic> map) {
    return AccessPermission(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      resource: map['resource'] as String,
      actions: AccessAction.fromStringList(
        (map['actions'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
      ),
      grantedBy: map['granted_by'] as String,
      grantedAt: DateTime.fromMillisecondsSinceEpoch(map['granted_at'] as int),
      expiresAt: map['expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int)
          : null,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      reason: map['reason'] as String?,
      conditions: Map<String, dynamic>.from(map['conditions'] as Map? ?? {}),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  /// Generate unique permission ID
  static String _generatePermissionId() {
    return 'perm_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccessPermission && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AccessPermission(id: $id, resource: $resource, '
        'actions: ${actions.map((a) => a.value).join(', ')}, '
        'valid: $isValid)';
  }
}
