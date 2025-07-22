/// Rights delegation model for delegating user rights between users
library;

import '../../enums/user_rights_enums.dart';

/// Represents a delegation of rights from one user to another
class RightsDelegation {
  /// Unique identifier for the delegation
  final String id;

  /// User ID delegating the rights
  final String fromUserId;

  /// User ID receiving the delegated rights
  final String toUserId;

  /// List of rights being delegated
  final List<String> delegatedRights;

  /// Current status of the delegation
  final DelegationStatus status;

  /// When the delegation was created
  final DateTime createdAt;

  /// When the delegation expires
  final DateTime expiresAt;

  /// Reason for the delegation
  final String? reason;

  /// Conditions that must be met for delegation to be valid
  final List<String> conditions;

  /// Additional metadata about the delegation
  final Map<String, dynamic> metadata;

  /// When the delegation was last updated
  final DateTime? updatedAt;

  /// Who approved the delegation (if required)
  final String? approvedBy;

  /// When the delegation was approved
  final DateTime? approvedAt;

  /// Who revoked the delegation (if applicable)
  final String? revokedBy;

  /// When the delegation was revoked
  final DateTime? revokedAt;

  /// Reason for revocation
  final String? revocationReason;

  const RightsDelegation({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.delegatedRights,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.reason,
    this.conditions = const [],
    this.metadata = const {},
    this.updatedAt,
    this.approvedBy,
    this.approvedAt,
    this.revokedBy,
    this.revokedAt,
    this.revocationReason,
  });

  /// Create a copy with updated fields
  RightsDelegation copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    List<String>? delegatedRights,
    DelegationStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? reason,
    List<String>? conditions,
    Map<String, dynamic>? metadata,
    DateTime? updatedAt,
    String? approvedBy,
    DateTime? approvedAt,
    String? revokedBy,
    DateTime? revokedAt,
    String? revocationReason,
  }) {
    return RightsDelegation(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      delegatedRights: delegatedRights ?? this.delegatedRights,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      reason: reason ?? this.reason,
      conditions: conditions ?? this.conditions,
      metadata: metadata ?? this.metadata,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      revokedBy: revokedBy ?? this.revokedBy,
      revokedAt: revokedAt ?? this.revokedAt,
      revocationReason: revocationReason ?? this.revocationReason,
    );
  }

  /// Check if the delegation is currently active
  bool get isActive => status == DelegationStatus.active && !isExpired;

  /// Check if the delegation is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if the delegation is revoked
  bool get isRevoked => status == DelegationStatus.revoked;

  /// Check if the delegation is suspended
  bool get isSuspended => status == DelegationStatus.suspended;

  /// Get remaining time until expiration
  Duration get remainingTime {
    final now = DateTime.now();
    if (expiresAt.isBefore(now)) return Duration.zero;
    return expiresAt.difference(now);
  }

  /// Get days until expiration
  int get daysUntilExpiration => remainingTime.inDays;

  /// Check if delegation is expiring soon (within specified days)
  bool isExpiringSoon([int days = 7]) {
    return daysUntilExpiration <= days && daysUntilExpiration > 0;
  }

  /// Check if a specific right is delegated
  bool isDelegatedRight(String right) => delegatedRights.contains(right);

  /// Check if any of the specified rights are delegated
  bool hasAnyDelegatedRight(List<String> rights) {
    return rights.any((right) => delegatedRights.contains(right));
  }

  /// Check if all specified rights are delegated
  bool hasAllDelegatedRights(List<String> rights) {
    return rights.every((right) => delegatedRights.contains(right));
  }

  /// Check if condition is met
  bool checkCondition(String condition) => conditions.contains(condition);

  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'delegatedRights': delegatedRights,
      'status': status.value,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'reason': reason,
      'conditions': conditions,
      'metadata': metadata,
      'updatedAt': updatedAt?.toIso8601String(),
      'approvedBy': approvedBy,
      'approvedAt': approvedAt?.toIso8601String(),
      'revokedBy': revokedBy,
      'revokedAt': revokedAt?.toIso8601String(),
      'revocationReason': revocationReason,
    };
  }

  /// Create from JSON representation
  factory RightsDelegation.fromJson(Map<String, dynamic> json) {
    return RightsDelegation(
      id: json['id'] as String,
      fromUserId: json['fromUserId'] as String,
      toUserId: json['toUserId'] as String,
      delegatedRights: List<String>.from(
        json['delegatedRights'] as List? ?? [],
      ),
      status: DelegationStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      reason: json['reason'] as String?,
      conditions: List<String>.from(json['conditions'] as List? ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      approvedBy: json['approvedBy'] as String?,
      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'] as String)
          : null,
      revokedBy: json['revokedBy'] as String?,
      revokedAt: json['revokedAt'] != null
          ? DateTime.parse(json['revokedAt'] as String)
          : null,
      revocationReason: json['revocationReason'] as String?,
    );
  }

  /// Create database map representation
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'delegated_rights': delegatedRights.join(','),
      'status': status.value,
      'created_at': createdAt.millisecondsSinceEpoch,
      'expires_at': expiresAt.millisecondsSinceEpoch,
      'reason': reason,
      'conditions': conditions.join(','),
      'metadata': metadata.isNotEmpty ? metadata : null,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.millisecondsSinceEpoch,
      'revoked_by': revokedBy,
      'revoked_at': revokedAt?.millisecondsSinceEpoch,
      'revocation_reason': revocationReason,
    };
  }

  /// Create from database map representation
  factory RightsDelegation.fromDatabaseMap(Map<String, dynamic> map) {
    return RightsDelegation(
      id: map['id'] as String,
      fromUserId: map['from_user_id'] as String,
      toUserId: map['to_user_id'] as String,
      delegatedRights: (map['delegated_rights'] as String? ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList(),
      status: DelegationStatus.fromString(map['status'] as String),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int),
      reason: map['reason'] as String?,
      conditions: (map['conditions'] as String? ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList(),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int)
          : null,
      approvedBy: map['approved_by'] as String?,
      approvedAt: map['approved_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['approved_at'] as int)
          : null,
      revokedBy: map['revoked_by'] as String?,
      revokedAt: map['revoked_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['revoked_at'] as int)
          : null,
      revocationReason: map['revocation_reason'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RightsDelegation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'RightsDelegation(id: $id, from: $fromUserId, to: $toUserId, '
        'rights: ${delegatedRights.length}, status: $status, '
        'expires: ${expiresAt.toLocal()})';
  }
}
