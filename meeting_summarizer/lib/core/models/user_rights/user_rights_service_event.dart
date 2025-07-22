/// User rights service event model for event system integration
library;

import '../../enums/user_rights_enums.dart';

/// Represents an event in the user rights service system
class UserRightsServiceEvent {
  /// Unique identifier for the event
  final String id;

  /// Type of event that occurred
  final UserRightsServiceEventType type;

  /// User ID associated with the event
  final String? userId;

  /// Resource affected by the event
  final String? resource;

  /// Event payload data
  final Map<String, dynamic> payload;

  /// Event source identifier
  final String source;

  /// Event severity level
  final String severity;

  /// Whether the event requires immediate attention
  final bool requiresAction;

  /// Event correlation ID for tracking related events
  final String? correlationId;

  /// When the event occurred
  final DateTime timestamp;

  /// Additional event metadata
  final Map<String, dynamic> metadata;

  const UserRightsServiceEvent({
    required this.id,
    required this.type,
    this.userId,
    this.resource,
    this.payload = const {},
    this.source = 'user_rights_service',
    this.severity = 'info',
    this.requiresAction = false,
    this.correlationId,
    required this.timestamp,
    this.metadata = const {},
  });

  /// Create a copy with updated fields
  UserRightsServiceEvent copyWith({
    String? id,
    UserRightsServiceEventType? type,
    String? userId,
    String? resource,
    Map<String, dynamic>? payload,
    String? source,
    String? severity,
    bool? requiresAction,
    String? correlationId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return UserRightsServiceEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      userId: userId ?? this.userId,
      resource: resource ?? this.resource,
      payload: payload ?? this.payload,
      source: source ?? this.source,
      severity: severity ?? this.severity,
      requiresAction: requiresAction ?? this.requiresAction,
      correlationId: correlationId ?? this.correlationId,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Check if this is a high severity event
  bool get isHighSeverity => severity == 'high' || severity == 'critical';

  /// Check if this is a medium severity event
  bool get isMediumSeverity => severity == 'medium' || severity == 'warning';

  /// Check if this is a low severity event
  bool get isLowSeverity => severity == 'low' || severity == 'info';

  /// Check if this event is critical
  bool get isCritical => severity == 'critical';

  /// Get age of the event
  Duration get age => DateTime.now().difference(timestamp);

  /// Check if event is recent (within specified duration)
  bool isRecent([Duration duration = const Duration(hours: 1)]) {
    return age <= duration;
  }

  /// Get payload value
  T? getPayloadValue<T>(String key) {
    return payload[key] as T?;
  }

  /// Check if payload contains key
  bool hasPayloadKey(String key) => payload.containsKey(key);

  /// Get metadata value
  T? getMetadata<T>(String key) {
    return metadata[key] as T?;
  }

  /// Factory method to create service initialized event
  static UserRightsServiceEvent createServiceInitialized({
    Map<String, dynamic> payload = const {},
    String? correlationId,
    Map<String, dynamic> metadata = const {},
  }) {
    return UserRightsServiceEvent(
      id: _generateEventId(),
      type: UserRightsServiceEventType.serviceInitialized,
      payload: payload,
      severity: 'info',
      requiresAction: false,
      correlationId: correlationId,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Factory method to create profile created event
  static UserRightsServiceEvent createProfileCreated({
    required String userId,
    Map<String, dynamic> payload = const {},
    String? correlationId,
    Map<String, dynamic> metadata = const {},
  }) {
    return UserRightsServiceEvent(
      id: _generateEventId(),
      type: UserRightsServiceEventType.profileCreated,
      userId: userId,
      resource: 'user_profile',
      payload: payload,
      severity: 'info',
      requiresAction: false,
      correlationId: correlationId,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Factory method to create permission granted event
  static UserRightsServiceEvent createPermissionGranted({
    required String userId,
    required String resource,
    Map<String, dynamic> payload = const {},
    String? correlationId,
    Map<String, dynamic> metadata = const {},
  }) {
    return UserRightsServiceEvent(
      id: _generateEventId(),
      type: UserRightsServiceEventType.permissionGranted,
      userId: userId,
      resource: resource,
      payload: payload,
      severity: 'medium',
      requiresAction: false,
      correlationId: correlationId,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Factory method to create access denied event
  static UserRightsServiceEvent createAccessDenied({
    required String userId,
    required String resource,
    Map<String, dynamic> payload = const {},
    String? correlationId,
    Map<String, dynamic> metadata = const {},
  }) {
    return UserRightsServiceEvent(
      id: _generateEventId(),
      type: UserRightsServiceEventType.accessDenied,
      userId: userId,
      resource: resource,
      payload: payload,
      severity: 'warning',
      requiresAction: true,
      correlationId: correlationId,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Factory method to create compliance violation event
  static UserRightsServiceEvent createComplianceViolation({
    required String userId,
    required String resource,
    Map<String, dynamic> payload = const {},
    String? correlationId,
    Map<String, dynamic> metadata = const {},
  }) {
    return UserRightsServiceEvent(
      id: _generateEventId(),
      type: UserRightsServiceEventType.complianceViolation,
      userId: userId,
      resource: resource,
      payload: payload,
      severity: 'critical',
      requiresAction: true,
      correlationId: correlationId,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Factory method to create guardianship assigned event
  static UserRightsServiceEvent createGuardianshipAssigned({
    required String userId,
    required String guardianId,
    Map<String, dynamic> payload = const {},
    String? correlationId,
    Map<String, dynamic> metadata = const {},
  }) {
    return UserRightsServiceEvent(
      id: _generateEventId(),
      type: UserRightsServiceEventType.guardianshipAssigned,
      userId: userId,
      resource: 'guardianship',
      payload: {...payload, 'guardianId': guardianId},
      severity: 'medium',
      requiresAction: false,
      correlationId: correlationId,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Factory method to create identity verified event
  static UserRightsServiceEvent createIdentityVerified({
    required String userId,
    Map<String, dynamic> payload = const {},
    String? correlationId,
    Map<String, dynamic> metadata = const {},
  }) {
    return UserRightsServiceEvent(
      id: _generateEventId(),
      type: UserRightsServiceEventType.identityVerified,
      userId: userId,
      resource: 'identity_verification',
      payload: payload,
      severity: 'info',
      requiresAction: false,
      correlationId: correlationId,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.value,
      'userId': userId,
      'resource': resource,
      'payload': payload,
      'source': source,
      'severity': severity,
      'requiresAction': requiresAction,
      'correlationId': correlationId,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create from JSON representation
  factory UserRightsServiceEvent.fromJson(Map<String, dynamic> json) {
    return UserRightsServiceEvent(
      id: json['id'] as String,
      type: UserRightsServiceEventType.fromString(json['type'] as String),
      userId: json['userId'] as String?,
      resource: json['resource'] as String?,
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      source: json['source'] as String? ?? 'user_rights_service',
      severity: json['severity'] as String? ?? 'info',
      requiresAction: json['requiresAction'] as bool? ?? false,
      correlationId: json['correlationId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }

  /// Create database map representation
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'type': type.value,
      'user_id': userId,
      'resource': resource,
      'payload': payload.isNotEmpty ? payload : null,
      'source': source,
      'severity': severity,
      'requires_action': requiresAction ? 1 : 0,
      'correlation_id': correlationId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'metadata': metadata.isNotEmpty ? metadata : null,
    };
  }

  /// Create from database map representation
  factory UserRightsServiceEvent.fromDatabaseMap(Map<String, dynamic> map) {
    return UserRightsServiceEvent(
      id: map['id'] as String,
      type: UserRightsServiceEventType.fromString(map['type'] as String),
      userId: map['user_id'] as String?,
      resource: map['resource'] as String?,
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? {}),
      source: map['source'] as String? ?? 'user_rights_service',
      severity: map['severity'] as String? ?? 'info',
      requiresAction: (map['requires_action'] as int? ?? 0) == 1,
      correlationId: map['correlation_id'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  /// Generate unique event ID
  static String _generateEventId() {
    return 'event_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserRightsServiceEvent && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UserRightsServiceEvent(id: $id, type: ${type.displayName}, '
        'user: $userId, resource: $resource, severity: $severity, '
        'timestamp: ${timestamp.toLocal()})';
  }
}
