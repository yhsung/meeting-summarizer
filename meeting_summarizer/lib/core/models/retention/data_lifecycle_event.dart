/// Data lifecycle event model for audit trail and notifications
library;

import '../../../core/enums/data_category.dart';

/// Represents a data lifecycle event in the retention system
class DataLifecycleEvent {
  /// Unique identifier for the event
  final String id;

  /// Type of lifecycle event
  final LifecycleEventType type;

  /// Brief description of the event
  final String description;

  /// When the event occurred
  final DateTime timestamp;

  /// ID of the data item affected
  final String? itemId;

  /// Data category affected
  final DataCategory? dataCategory;

  /// Policy ID that triggered the event
  final String? policyId;

  /// User ID associated with the event
  final String? userId;

  /// Additional metadata about the event
  final Map<String, dynamic> metadata;

  /// Severity level of the event
  final EventSeverity severity;

  const DataLifecycleEvent({
    required this.id,
    required this.type,
    required this.description,
    required this.timestamp,
    this.itemId,
    this.dataCategory,
    this.policyId,
    this.userId,
    this.metadata = const {},
    this.severity = EventSeverity.info,
  });

  /// Factory constructor for service initialization
  factory DataLifecycleEvent.serviceInitialized({
    required DateTime timestamp,
    Map<String, dynamic> metadata = const {},
  }) {
    return DataLifecycleEvent(
      id: _generateEventId(),
      type: LifecycleEventType.serviceInitialized,
      description: 'Data retention service initialized successfully',
      timestamp: timestamp,
      metadata: metadata,
      severity: EventSeverity.info,
    );
  }

  /// Factory constructor for policy updates
  factory DataLifecycleEvent.policyUpdated({
    required String policyId,
    required DateTime timestamp,
    String? userId,
    Map<String, dynamic> metadata = const {},
  }) {
    return DataLifecycleEvent(
      id: _generateEventId(),
      type: LifecycleEventType.policyUpdated,
      description: 'Retention policy updated',
      timestamp: timestamp,
      policyId: policyId,
      userId: userId,
      metadata: metadata,
      severity: EventSeverity.info,
    );
  }

  /// Factory constructor for policy deletion
  factory DataLifecycleEvent.policyDeleted({
    required String policyId,
    required DateTime timestamp,
    String? userId,
    Map<String, dynamic> metadata = const {},
  }) {
    return DataLifecycleEvent(
      id: _generateEventId(),
      type: LifecycleEventType.policyDeleted,
      description: 'Retention policy deleted',
      timestamp: timestamp,
      policyId: policyId,
      userId: userId,
      metadata: metadata,
      severity: EventSeverity.warning,
    );
  }

  /// Factory constructor for data archival
  factory DataLifecycleEvent.dataArchived({
    required String itemId,
    required DataCategory dataCategory,
    required DateTime timestamp,
    String? policyId,
    Map<String, dynamic> metadata = const {},
  }) {
    return DataLifecycleEvent(
      id: _generateEventId(),
      type: LifecycleEventType.dataArchived,
      description: 'Data item archived according to retention policy',
      timestamp: timestamp,
      itemId: itemId,
      dataCategory: dataCategory,
      policyId: policyId,
      metadata: metadata,
      severity: EventSeverity.info,
    );
  }

  /// Factory constructor for data deletion
  factory DataLifecycleEvent.dataDeleted({
    required String itemId,
    required DataCategory dataCategory,
    required DateTime timestamp,
    String? policyId,
    Map<String, dynamic> metadata = const {},
  }) {
    return DataLifecycleEvent(
      id: _generateEventId(),
      type: LifecycleEventType.dataDeleted,
      description: 'Data item deleted according to retention policy',
      timestamp: timestamp,
      itemId: itemId,
      dataCategory: dataCategory,
      policyId: policyId,
      metadata: metadata,
      severity: EventSeverity.info,
    );
  }

  /// Factory constructor for data anonymization
  factory DataLifecycleEvent.dataAnonymized({
    required String itemId,
    required DataCategory dataCategory,
    required DateTime timestamp,
    String? policyId,
    Map<String, dynamic> metadata = const {},
  }) {
    return DataLifecycleEvent(
      id: _generateEventId(),
      type: LifecycleEventType.dataAnonymized,
      description: 'Data item anonymized according to retention policy',
      timestamp: timestamp,
      itemId: itemId,
      dataCategory: dataCategory,
      policyId: policyId,
      metadata: metadata,
      severity: EventSeverity.info,
    );
  }

  /// Factory constructor for retention execution completion
  factory DataLifecycleEvent.executionCompleted({
    required DateTime timestamp,
    Map<String, dynamic> metadata = const {},
  }) {
    return DataLifecycleEvent(
      id: _generateEventId(),
      type: LifecycleEventType.executionCompleted,
      description: 'Retention policy execution completed',
      timestamp: timestamp,
      metadata: metadata,
      severity: EventSeverity.info,
    );
  }

  /// Factory constructor for retention warnings
  factory DataLifecycleEvent.retentionWarning({
    required String message,
    required DateTime timestamp,
    String? itemId,
    DataCategory? dataCategory,
    String? policyId,
    Map<String, dynamic> metadata = const {},
  }) {
    return DataLifecycleEvent(
      id: _generateEventId(),
      type: LifecycleEventType.retentionWarning,
      description: message,
      timestamp: timestamp,
      itemId: itemId,
      dataCategory: dataCategory,
      policyId: policyId,
      metadata: metadata,
      severity: EventSeverity.warning,
    );
  }

  /// Factory constructor for retention errors
  factory DataLifecycleEvent.retentionError({
    required String error,
    required DateTime timestamp,
    String? itemId,
    DataCategory? dataCategory,
    String? policyId,
    Map<String, dynamic> metadata = const {},
  }) {
    return DataLifecycleEvent(
      id: _generateEventId(),
      type: LifecycleEventType.retentionError,
      description: error,
      timestamp: timestamp,
      itemId: itemId,
      dataCategory: dataCategory,
      policyId: policyId,
      metadata: metadata,
      severity: EventSeverity.error,
    );
  }

  /// Factory constructor for user action events
  factory DataLifecycleEvent.userAction({
    required String userId,
    required String action,
    required DateTime timestamp,
    String? itemId,
    DataCategory? dataCategory,
    String? policyId,
    Map<String, dynamic> metadata = const {},
  }) {
    return DataLifecycleEvent(
      id: _generateEventId(),
      type: LifecycleEventType.userAction,
      description: 'User performed retention action: $action',
      timestamp: timestamp,
      userId: userId,
      itemId: itemId,
      dataCategory: dataCategory,
      policyId: policyId,
      metadata: {...metadata, 'action': action},
      severity: EventSeverity.info,
    );
  }

  /// Check if this event is recent (within last 24 hours)
  bool get isRecent {
    final dayAgo = DateTime.now().subtract(const Duration(days: 1));
    return timestamp.isAfter(dayAgo);
  }

  /// Check if this event requires attention
  bool get requiresAttention {
    return severity == EventSeverity.warning || severity == EventSeverity.error;
  }

  /// Get formatted timestamp for display
  String get formattedTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return timestamp.toLocal().toString().split('.')[0];
    }
  }

  /// Create copy with updated fields
  DataLifecycleEvent copyWith({
    String? id,
    LifecycleEventType? type,
    String? description,
    DateTime? timestamp,
    String? itemId,
    DataCategory? dataCategory,
    String? policyId,
    String? userId,
    Map<String, dynamic>? metadata,
    EventSeverity? severity,
  }) {
    return DataLifecycleEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      itemId: itemId ?? this.itemId,
      dataCategory: dataCategory ?? this.dataCategory,
      policyId: policyId ?? this.policyId,
      userId: userId ?? this.userId,
      metadata: metadata ?? this.metadata,
      severity: severity ?? this.severity,
    );
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.value,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'itemId': itemId,
      'dataCategory': dataCategory?.value,
      'policyId': policyId,
      'userId': userId,
      'metadata': metadata,
      'severity': severity.value,
      'formattedTimestamp': formattedTimestamp,
      'requiresAttention': requiresAttention,
    };
  }

  /// Create from JSON representation
  factory DataLifecycleEvent.fromJson(Map<String, dynamic> json) {
    return DataLifecycleEvent(
      id: json['id'] as String,
      type: LifecycleEventType.fromString(json['type'] as String),
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      itemId: json['itemId'] as String?,
      dataCategory: json['dataCategory'] != null
          ? DataCategory.fromString(json['dataCategory'] as String)
          : null,
      policyId: json['policyId'] as String?,
      userId: json['userId'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      severity: EventSeverity.fromString(json['severity'] as String? ?? 'info'),
    );
  }

  /// Create database map representation
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'type': type.value,
      'description': description,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'item_id': itemId,
      'data_category': dataCategory?.value,
      'policy_id': policyId,
      'user_id': userId,
      'metadata': metadata.isNotEmpty ? metadata : null,
      'severity': severity.value,
    };
  }

  /// Create from database map representation
  factory DataLifecycleEvent.fromDatabaseMap(Map<String, dynamic> map) {
    return DataLifecycleEvent(
      id: map['id'] as String,
      type: LifecycleEventType.fromString(map['type'] as String),
      description: map['description'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      itemId: map['item_id'] as String?,
      dataCategory: map['data_category'] != null
          ? DataCategory.fromString(map['data_category'] as String)
          : null,
      policyId: map['policy_id'] as String?,
      userId: map['user_id'] as String?,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      severity: EventSeverity.fromString(map['severity'] as String? ?? 'info'),
    );
  }

  /// Generate unique event ID
  static String _generateEventId() {
    return 'event_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataLifecycleEvent &&
        other.id == id &&
        other.type == type &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(id, type, timestamp);

  @override
  String toString() {
    return 'DataLifecycleEvent(id: $id, type: ${type.displayName}, '
        'description: $description, timestamp: $timestamp)';
  }
}

/// Types of data lifecycle events
enum LifecycleEventType {
  serviceInitialized('service_initialized', 'Service Initialized'),
  policyCreated('policy_created', 'Policy Created'),
  policyUpdated('policy_updated', 'Policy Updated'),
  policyDeleted('policy_deleted', 'Policy Deleted'),
  policyActivated('policy_activated', 'Policy Activated'),
  policyDeactivated('policy_deactivated', 'Policy Deactivated'),
  dataArchived('data_archived', 'Data Archived'),
  dataDeleted('data_deleted', 'Data Deleted'),
  dataAnonymized('data_anonymized', 'Data Anonymized'),
  dataExpired('data_expired', 'Data Expired'),
  executionStarted('execution_started', 'Execution Started'),
  executionCompleted('execution_completed', 'Execution Completed'),
  executionFailed('execution_failed', 'Execution Failed'),
  retentionWarning('retention_warning', 'Retention Warning'),
  retentionError('retention_error', 'Retention Error'),
  userAction('user_action', 'User Action'),
  systemMaintenance('system_maintenance', 'System Maintenance');

  const LifecycleEventType(this.value, this.displayName);

  final String value;
  final String displayName;

  static LifecycleEventType fromString(String value) {
    return LifecycleEventType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => LifecycleEventType.systemMaintenance,
    );
  }

  /// Check if this is a high-impact event type
  bool get isHighImpact {
    return [
      LifecycleEventType.dataDeleted,
      LifecycleEventType.policyDeleted,
      LifecycleEventType.executionFailed,
      LifecycleEventType.retentionError,
    ].contains(this);
  }

  /// Check if this is a user-initiated event type
  bool get isUserInitiated {
    return [
      LifecycleEventType.userAction,
      LifecycleEventType.policyCreated,
      LifecycleEventType.policyUpdated,
      LifecycleEventType.policyDeleted,
    ].contains(this);
  }

  /// Check if this is a system-initiated event type
  bool get isSystemInitiated => !isUserInitiated;
}

/// Severity levels for lifecycle events
enum EventSeverity {
  info('info', 'Information'),
  warning('warning', 'Warning'),
  error('error', 'Error'),
  critical('critical', 'Critical');

  const EventSeverity(this.value, this.displayName);

  final String value;
  final String displayName;

  static EventSeverity fromString(String value) {
    return EventSeverity.values.firstWhere(
      (severity) => severity.value == value,
      orElse: () => EventSeverity.info,
    );
  }

  /// Check if this severity level requires immediate attention
  bool get requiresImmediateAttention {
    return this == EventSeverity.error || this == EventSeverity.critical;
  }

  /// Get color representation for UI
  String get colorCode {
    switch (this) {
      case EventSeverity.info:
        return '#2196F3'; // Blue
      case EventSeverity.warning:
        return '#FF9800'; // Orange
      case EventSeverity.error:
        return '#F44336'; // Red
      case EventSeverity.critical:
        return '#9C27B0'; // Purple
    }
  }
}
