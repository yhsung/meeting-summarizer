/// Retention policy model for data lifecycle management
library;

import '../../../core/enums/legal_basis.dart';
import '../../../core/enums/data_category.dart';

/// Represents a data retention policy configuration
class RetentionPolicy {
  /// Unique identifier for the policy
  final String id;

  /// Human-readable name for the policy
  final String name;

  /// Detailed description of the policy
  final String description;

  /// Data category this policy applies to
  final DataCategory dataCategory;

  /// Retention period configuration
  final RetentionPeriod retentionPeriod;

  /// Whether the policy is currently active
  final bool isActive;

  /// Whether users can modify this policy
  final bool isUserConfigurable;

  /// User ID if this is a user-specific policy override
  final String? userId;

  /// Whether automatic deletion is enabled
  final bool autoDeleteEnabled;

  /// Whether archival is enabled before deletion
  final bool archivalEnabled;

  /// When the policy was created
  final DateTime createdAt;

  /// When the policy was last updated
  final DateTime updatedAt;

  /// Additional metadata for the policy
  final Map<String, dynamic> metadata;

  const RetentionPolicy({
    required this.id,
    required this.name,
    required this.description,
    required this.dataCategory,
    required this.retentionPeriod,
    required this.isActive,
    required this.isUserConfigurable,
    this.userId,
    required this.autoDeleteEnabled,
    required this.archivalEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const {},
  });

  /// Create a copy of the policy with updated fields
  RetentionPolicy copyWith({
    String? id,
    String? name,
    String? description,
    DataCategory? dataCategory,
    RetentionPeriod? retentionPeriod,
    bool? isActive,
    bool? isUserConfigurable,
    String? userId,
    bool? autoDeleteEnabled,
    bool? archivalEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return RetentionPolicy(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      dataCategory: dataCategory ?? this.dataCategory,
      retentionPeriod: retentionPeriod ?? this.retentionPeriod,
      isActive: isActive ?? this.isActive,
      isUserConfigurable: isUserConfigurable ?? this.isUserConfigurable,
      userId: userId ?? this.userId,
      autoDeleteEnabled: autoDeleteEnabled ?? this.autoDeleteEnabled,
      archivalEnabled: archivalEnabled ?? this.archivalEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Get the archival date for a given start date
  DateTime? getArchivalDate(DateTime startDate) {
    if (!archivalEnabled || retentionPeriod.isIndefinite) return null;

    // Archive halfway through the retention period
    final archivalDays = (retentionPeriod.days / 2).floor();
    return startDate.add(Duration(days: archivalDays));
  }

  /// Get the deletion date for a given start date
  DateTime? getDeletionDate(DateTime startDate) {
    if (!autoDeleteEnabled || retentionPeriod.isIndefinite) return null;

    return retentionPeriod.getRetentionDate(startDate);
  }

  /// Check if data should be archived now
  bool shouldArchiveNow(DateTime dataCreationDate) {
    final archivalDate = getArchivalDate(dataCreationDate);
    if (archivalDate == null) return false;

    return DateTime.now().isAfter(archivalDate);
  }

  /// Check if data should be deleted now
  bool shouldDeleteNow(DateTime dataCreationDate) {
    final deletionDate = getDeletionDate(dataCreationDate);
    if (deletionDate == null) return false;

    return DateTime.now().isAfter(deletionDate);
  }

  /// Get days until archival for given data
  int? getDaysUntilArchival(DateTime dataCreationDate) {
    final archivalDate = getArchivalDate(dataCreationDate);
    if (archivalDate == null) return null;

    final diff = archivalDate.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Get days until deletion for given data
  int? getDaysUntilDeletion(DateTime dataCreationDate) {
    final deletionDate = getDeletionDate(dataCreationDate);
    if (deletionDate == null) return null;

    final diff = deletionDate.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'dataCategory': dataCategory.value,
      'retentionPeriod': retentionPeriod.value,
      'isActive': isActive,
      'isUserConfigurable': isUserConfigurable,
      'userId': userId,
      'autoDeleteEnabled': autoDeleteEnabled,
      'archivalEnabled': archivalEnabled,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create from JSON representation
  factory RetentionPolicy.fromJson(Map<String, dynamic> json) {
    return RetentionPolicy(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      dataCategory: DataCategory.fromString(json['dataCategory'] as String),
      retentionPeriod: RetentionPeriod.fromString(
        json['retentionPeriod'] as String,
      ),
      isActive: json['isActive'] as bool,
      isUserConfigurable: json['isUserConfigurable'] as bool,
      userId: json['userId'] as String?,
      autoDeleteEnabled: json['autoDeleteEnabled'] as bool,
      archivalEnabled: json['archivalEnabled'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }

  /// Create database map representation
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'data_category': dataCategory.value,
      'retention_period': retentionPeriod.value,
      'is_active': isActive ? 1 : 0,
      'is_user_configurable': isUserConfigurable ? 1 : 0,
      'user_id': userId,
      'auto_delete_enabled': autoDeleteEnabled ? 1 : 0,
      'archival_enabled': archivalEnabled ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'metadata': metadata.isNotEmpty ? metadata : null,
    };
  }

  /// Create from database map representation
  factory RetentionPolicy.fromDatabaseMap(Map<String, dynamic> map) {
    return RetentionPolicy(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      dataCategory: DataCategory.fromString(map['data_category'] as String),
      retentionPeriod: RetentionPeriod.fromString(
        map['retention_period'] as String,
      ),
      isActive: (map['is_active'] as int) == 1,
      isUserConfigurable: (map['is_user_configurable'] as int) == 1,
      userId: map['user_id'] as String?,
      autoDeleteEnabled: (map['auto_delete_enabled'] as int) == 1,
      archivalEnabled: (map['archival_enabled'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RetentionPolicy &&
        other.id == id &&
        other.name == name &&
        other.dataCategory == dataCategory &&
        other.retentionPeriod == retentionPeriod &&
        other.userId == userId;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, dataCategory, retentionPeriod, userId);
  }

  @override
  String toString() {
    return 'RetentionPolicy(id: $id, name: $name, dataCategory: $dataCategory, '
        'retentionPeriod: $retentionPeriod, isActive: $isActive)';
  }
}
