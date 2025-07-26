/// User rights request models for GDPR compliance
library;

/// Types of user rights requests under GDPR
enum UserRightType {
  /// Right to access personal data (Article 15)
  access(
    'access',
    'Right to Access',
    'Request a copy of all personal data being processed',
  ),

  /// Right to rectification of inaccurate data (Article 16)
  rectification(
    'rectification',
    'Right to Rectification',
    'Request correction of inaccurate or incomplete data',
  ),

  /// Right to erasure/deletion (Article 17)
  erasure(
    'erasure',
    'Right to Erasure',
    'Request deletion of personal data (right to be forgotten)',
  ),

  /// Right to restrict processing (Article 18)
  restriction(
    'restriction',
    'Right to Restrict Processing',
    'Request limitation of data processing activities',
  ),

  /// Right to data portability (Article 20)
  portability(
    'portability',
    'Right to Data Portability',
    'Request data in a machine-readable format for transfer',
  ),

  /// Right to object to processing (Article 21)
  objection(
    'objection',
    'Right to Object',
    'Object to processing of personal data',
  ),

  /// Rights related to automated decision making (Article 22)
  automatedDecision(
    'automated_decision',
    'Automated Decision Rights',
    'Request review of automated decisions and profiling',
  );

  const UserRightType(this.value, this.displayName, this.description);

  /// String value for database storage
  final String value;

  /// Human-readable display name
  final String displayName;

  /// Description of the right
  final String description;

  /// Create UserRightType from string value
  static UserRightType fromString(String value) {
    return UserRightType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => UserRightType.access,
    );
  }

  /// Get all user right types
  static List<UserRightType> get allTypes => UserRightType.values;

  @override
  String toString() => value;
}

/// Status of a user rights request
enum RequestStatus {
  /// Request submitted and pending review
  pending('pending', 'Pending'),

  /// Request is being processed
  inProgress('in_progress', 'In Progress'),

  /// Request completed successfully
  completed('completed', 'Completed'),

  /// Request rejected due to invalid or excessive request
  rejected('rejected', 'Rejected'),

  /// Request cancelled by user
  cancelled('cancelled', 'Cancelled'),

  /// Request failed due to technical issues
  failed('failed', 'Failed');

  const RequestStatus(this.value, this.displayName);

  /// String value for database storage
  final String value;

  /// Human-readable display name
  final String displayName;

  /// Create RequestStatus from string value
  static RequestStatus fromString(String value) {
    return RequestStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => RequestStatus.pending,
    );
  }

  /// Check if request is in a final state
  bool get isFinal => [
        RequestStatus.completed,
        RequestStatus.rejected,
        RequestStatus.cancelled,
        RequestStatus.failed,
      ].contains(this);

  /// Check if request is still active
  bool get isActive => !isFinal;

  @override
  String toString() => value;
}

/// User rights request record
class UserRightsRequest {
  /// Unique identifier for this request
  final String id;

  /// User identifier who made the request
  final String userId;

  /// Type of right being exercised
  final UserRightType rightType;

  /// Current status of the request
  final RequestStatus status;

  /// User's description or details of the request
  final String description;

  /// Specific data categories the request applies to
  final List<String> dataCategories;

  /// Verification method used to confirm user identity
  final String? verificationMethod;

  /// Whether user identity has been verified
  final bool identityVerified;

  /// Timestamp when request was submitted
  final DateTime submittedAt;

  /// Timestamp when request processing started
  final DateTime? processingStartedAt;

  /// Timestamp when request was completed
  final DateTime? completedAt;

  /// Due date for completing the request (30 days from submission)
  final DateTime dueDate;

  /// Staff member assigned to handle the request
  final String? assignedTo;

  /// Notes from staff processing the request
  final String? processingNotes;

  /// Reason for rejection (if applicable)
  final String? rejectionReason;

  /// File paths or references to fulfillment data
  final List<String> fulfillmentFiles;

  /// Priority level of the request
  final int priority;

  /// Whether request involves sensitive data
  final bool involvesSensitiveData;

  /// Additional metadata about the request
  final Map<String, dynamic> metadata;

  /// Timestamp when record was created
  final DateTime createdAt;

  /// Timestamp when record was last updated
  final DateTime updatedAt;

  const UserRightsRequest({
    required this.id,
    required this.userId,
    required this.rightType,
    required this.status,
    required this.description,
    this.dataCategories = const [],
    this.verificationMethod,
    this.identityVerified = false,
    required this.submittedAt,
    this.processingStartedAt,
    this.completedAt,
    required this.dueDate,
    this.assignedTo,
    this.processingNotes,
    this.rejectionReason,
    this.fulfillmentFiles = const [],
    this.priority = 1,
    this.involvesSensitiveData = false,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create user rights request from JSON
  factory UserRightsRequest.fromJson(Map<String, dynamic> json) {
    return UserRightsRequest(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      rightType: UserRightType.fromString(json['rightType'] ?? ''),
      status: RequestStatus.fromString(json['status'] ?? ''),
      description: json['description'] ?? '',
      dataCategories: (json['dataCategories'] as List<dynamic>? ?? [])
          .map((category) => category.toString())
          .toList(),
      verificationMethod: json['verificationMethod'],
      identityVerified: json['identityVerified'] ?? false,
      submittedAt:
          DateTime.tryParse(json['submittedAt'] ?? '') ?? DateTime.now(),
      processingStartedAt: json['processingStartedAt'] != null
          ? DateTime.tryParse(json['processingStartedAt'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,
      dueDate: DateTime.tryParse(json['dueDate'] ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
      assignedTo: json['assignedTo'],
      processingNotes: json['processingNotes'],
      rejectionReason: json['rejectionReason'],
      fulfillmentFiles: (json['fulfillmentFiles'] as List<dynamic>? ?? [])
          .map((file) => file.toString())
          .toList(),
      priority: json['priority'] ?? 1,
      involvesSensitiveData: json['involvesSensitiveData'] ?? false,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  /// Convert user rights request to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'rightType': rightType.value,
      'status': status.value,
      'description': description,
      'dataCategories': dataCategories,
      'verificationMethod': verificationMethod,
      'identityVerified': identityVerified,
      'submittedAt': submittedAt.toIso8601String(),
      'processingStartedAt': processingStartedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'assignedTo': assignedTo,
      'processingNotes': processingNotes,
      'rejectionReason': rejectionReason,
      'fulfillmentFiles': fulfillmentFiles,
      'priority': priority,
      'involvesSensitiveData': involvesSensitiveData,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  UserRightsRequest copyWith({
    String? id,
    String? userId,
    UserRightType? rightType,
    RequestStatus? status,
    String? description,
    List<String>? dataCategories,
    String? verificationMethod,
    bool? identityVerified,
    DateTime? submittedAt,
    DateTime? processingStartedAt,
    DateTime? completedAt,
    DateTime? dueDate,
    String? assignedTo,
    String? processingNotes,
    String? rejectionReason,
    List<String>? fulfillmentFiles,
    int? priority,
    bool? involvesSensitiveData,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserRightsRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      rightType: rightType ?? this.rightType,
      status: status ?? this.status,
      description: description ?? this.description,
      dataCategories: dataCategories ?? this.dataCategories,
      verificationMethod: verificationMethod ?? this.verificationMethod,
      identityVerified: identityVerified ?? this.identityVerified,
      submittedAt: submittedAt ?? this.submittedAt,
      processingStartedAt: processingStartedAt ?? this.processingStartedAt,
      completedAt: completedAt ?? this.completedAt,
      dueDate: dueDate ?? this.dueDate,
      assignedTo: assignedTo ?? this.assignedTo,
      processingNotes: processingNotes ?? this.processingNotes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      fulfillmentFiles: fulfillmentFiles ?? this.fulfillmentFiles,
      priority: priority ?? this.priority,
      involvesSensitiveData:
          involvesSensitiveData ?? this.involvesSensitiveData,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if request is overdue
  bool get isOverdue {
    if (status.isFinal) return false;
    return DateTime.now().isAfter(dueDate);
  }

  /// Get days until due date (negative if overdue)
  int get daysUntilDue {
    return dueDate.difference(DateTime.now()).inDays;
  }

  /// Get processing duration
  Duration? get processingDuration {
    if (processingStartedAt == null) return null;
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(processingStartedAt!);
  }

  /// Get total request duration from submission
  Duration get totalDuration {
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(submittedAt);
  }

  /// Check if request needs urgent attention
  bool get needsUrgentAttention {
    if (status.isFinal) return false;
    return isOverdue || daysUntilDue <= 3 || involvesSensitiveData;
  }

  /// Get urgency level (0 = low, 1 = medium, 2 = high)
  int get urgencyLevel {
    if (status.isFinal) return 0;

    int urgency = 0;
    if (isOverdue) {
      urgency += 2;
    } else if (daysUntilDue <= 7) {
      urgency += 1;
    }

    if (involvesSensitiveData) {
      urgency += 1;
    }
    if (priority > 1) {
      urgency += 1;
    }

    return urgency.clamp(0, 2);
  }

  /// Get urgency level description
  String get urgencyLevelDescription {
    switch (urgencyLevel) {
      case 0:
        return 'Low Priority';
      case 1:
        return 'Medium Priority';
      case 2:
      default:
        return 'High Priority';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserRightsRequest && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UserRightsRequest(id: $id, type: ${rightType.value}, status: ${status.value})';
  }
}
