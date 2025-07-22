/// Access audit log model for comprehensive audit trail logging
library;

import '../../enums/user_rights_enums.dart';

/// Represents a comprehensive audit log entry for user rights activities
class AccessAuditLog {
  /// Unique identifier for the audit log entry
  final String id;

  /// User ID who performed the action
  final String userId;

  /// Type of action performed
  final AccessAuditAction action;

  /// Resource that was accessed or modified
  final String resource;

  /// Detailed description of what occurred
  final String description;

  /// IP address of the user when action occurred
  final String? ipAddress;

  /// User agent (browser/app) information
  final String? userAgent;

  /// Geographic location information
  final String? location;

  /// Whether the action was successful
  final bool success;

  /// Error message if action failed
  final String? errorMessage;

  /// Additional context data
  final Map<String, dynamic> contextData;

  /// Risk level of the action
  final String riskLevel;

  /// Session ID when action occurred
  final String? sessionId;

  /// When the action occurred
  final DateTime timestamp;

  /// Additional metadata about the audit entry
  final Map<String, dynamic> metadata;

  const AccessAuditLog({
    required this.id,
    required this.userId,
    required this.action,
    required this.resource,
    required this.description,
    this.ipAddress,
    this.userAgent,
    this.location,
    this.success = true,
    this.errorMessage,
    this.contextData = const {},
    this.riskLevel = 'low',
    this.sessionId,
    required this.timestamp,
    this.metadata = const {},
  });

  /// Create a copy with updated fields
  AccessAuditLog copyWith({
    String? id,
    String? userId,
    AccessAuditAction? action,
    String? resource,
    String? description,
    String? ipAddress,
    String? userAgent,
    String? location,
    bool? success,
    String? errorMessage,
    Map<String, dynamic>? contextData,
    String? riskLevel,
    String? sessionId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return AccessAuditLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      action: action ?? this.action,
      resource: resource ?? this.resource,
      description: description ?? this.description,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      location: location ?? this.location,
      success: success ?? this.success,
      errorMessage: errorMessage ?? this.errorMessage,
      contextData: contextData ?? this.contextData,
      riskLevel: riskLevel ?? this.riskLevel,
      sessionId: sessionId ?? this.sessionId,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Check if this is a high-risk action
  bool get isHighRisk => riskLevel == 'high';

  /// Check if this is a medium-risk action
  bool get isMediumRisk => riskLevel == 'medium';

  /// Check if this is a low-risk action
  bool get isLowRisk => riskLevel == 'low';

  /// Check if the action failed
  bool get failed => !success;

  /// Get age of the audit log entry
  Duration get age => DateTime.now().difference(timestamp);

  /// Check if audit entry is recent (within specified duration)
  bool isRecent([Duration duration = const Duration(hours: 24)]) {
    return age <= duration;
  }

  /// Check if this is a sensitive data access
  bool get isSensitiveDataAccess =>
      action == AccessAuditAction.sensitiveDataAccess;

  /// Check if this is an admin action
  bool get isAdminAction => action == AccessAuditAction.adminAction;

  /// Get context data value
  T? getContextData<T>(String key) {
    return contextData[key] as T?;
  }

  /// Check if context data contains key
  bool hasContextData(String key) => contextData.containsKey(key);

  /// Factory method to create login audit log
  static AccessAuditLog createLogin({
    required String userId,
    required String ipAddress,
    String? userAgent,
    String? location,
    bool success = true,
    String? errorMessage,
    String? sessionId,
    Map<String, dynamic> contextData = const {},
  }) {
    return AccessAuditLog(
      id: _generateAuditId(),
      userId: userId,
      action: AccessAuditAction.login,
      resource: 'authentication',
      description: success
          ? 'User logged in successfully'
          : 'Login attempt failed',
      ipAddress: ipAddress,
      userAgent: userAgent,
      location: location,
      success: success,
      errorMessage: errorMessage,
      contextData: contextData,
      riskLevel: success ? 'low' : 'medium',
      sessionId: sessionId,
      timestamp: DateTime.now(),
    );
  }

  /// Factory method to create data access audit log
  static AccessAuditLog createDataAccess({
    required String userId,
    required String resource,
    required String description,
    String? ipAddress,
    String? userAgent,
    bool success = true,
    String? errorMessage,
    Map<String, dynamic> contextData = const {},
    String riskLevel = 'low',
    String? sessionId,
  }) {
    return AccessAuditLog(
      id: _generateAuditId(),
      userId: userId,
      action: AccessAuditAction.dataAccess,
      resource: resource,
      description: description,
      ipAddress: ipAddress,
      userAgent: userAgent,
      success: success,
      errorMessage: errorMessage,
      contextData: contextData,
      riskLevel: riskLevel,
      sessionId: sessionId,
      timestamp: DateTime.now(),
    );
  }

  /// Factory method to create permission change audit log
  static AccessAuditLog createPermissionChange({
    required String userId,
    required String resource,
    required String description,
    required AccessAuditAction action,
    String? ipAddress,
    Map<String, dynamic> contextData = const {},
    String? sessionId,
  }) {
    return AccessAuditLog(
      id: _generateAuditId(),
      userId: userId,
      action: action,
      resource: resource,
      description: description,
      ipAddress: ipAddress,
      success: true,
      contextData: contextData,
      riskLevel: 'medium',
      sessionId: sessionId,
      timestamp: DateTime.now(),
    );
  }

  /// Factory method to create admin action audit log
  static AccessAuditLog createAdminAction({
    required String userId,
    required String resource,
    required String description,
    String? ipAddress,
    String? userAgent,
    bool success = true,
    String? errorMessage,
    Map<String, dynamic> contextData = const {},
    String? sessionId,
  }) {
    return AccessAuditLog(
      id: _generateAuditId(),
      userId: userId,
      action: AccessAuditAction.adminAction,
      resource: resource,
      description: description,
      ipAddress: ipAddress,
      userAgent: userAgent,
      success: success,
      errorMessage: errorMessage,
      contextData: contextData,
      riskLevel: 'high',
      sessionId: sessionId,
      timestamp: DateTime.now(),
    );
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'action': action.value,
      'resource': resource,
      'description': description,
      'ipAddress': ipAddress,
      'userAgent': userAgent,
      'location': location,
      'success': success,
      'errorMessage': errorMessage,
      'contextData': contextData,
      'riskLevel': riskLevel,
      'sessionId': sessionId,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create from JSON representation
  factory AccessAuditLog.fromJson(Map<String, dynamic> json) {
    return AccessAuditLog(
      id: json['id'] as String,
      userId: json['userId'] as String,
      action: AccessAuditAction.fromString(json['action'] as String),
      resource: json['resource'] as String,
      description: json['description'] as String,
      ipAddress: json['ipAddress'] as String?,
      userAgent: json['userAgent'] as String?,
      location: json['location'] as String?,
      success: json['success'] as bool? ?? true,
      errorMessage: json['errorMessage'] as String?,
      contextData: Map<String, dynamic>.from(json['contextData'] as Map? ?? {}),
      riskLevel: json['riskLevel'] as String? ?? 'low',
      sessionId: json['sessionId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }

  /// Create database map representation
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'user_id': userId,
      'action': action.value,
      'resource': resource,
      'description': description,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'location': location,
      'success': success ? 1 : 0,
      'error_message': errorMessage,
      'context_data': contextData.isNotEmpty ? contextData : null,
      'risk_level': riskLevel,
      'session_id': sessionId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'metadata': metadata.isNotEmpty ? metadata : null,
    };
  }

  /// Create from database map representation
  factory AccessAuditLog.fromDatabaseMap(Map<String, dynamic> map) {
    return AccessAuditLog(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      action: AccessAuditAction.fromString(map['action'] as String),
      resource: map['resource'] as String,
      description: map['description'] as String,
      ipAddress: map['ip_address'] as String?,
      userAgent: map['user_agent'] as String?,
      location: map['location'] as String?,
      success: (map['success'] as int? ?? 1) == 1,
      errorMessage: map['error_message'] as String?,
      contextData: Map<String, dynamic>.from(map['context_data'] as Map? ?? {}),
      riskLevel: map['risk_level'] as String? ?? 'low',
      sessionId: map['session_id'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  /// Generate unique audit log ID
  static String _generateAuditId() {
    return 'audit_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccessAuditLog && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AccessAuditLog(id: $id, user: $userId, action: ${action.displayName}, '
        'resource: $resource, success: $success, risk: $riskLevel, '
        'timestamp: ${timestamp.toLocal()})';
  }
}
