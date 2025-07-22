/// User profile model for comprehensive user rights management
library;

import '../../enums/user_rights_enums.dart';

/// Represents a comprehensive user profile with role-based access control
class UserProfile {
  /// Unique identifier for the user
  final String id;

  /// User's email address (primary identifier)
  final String email;

  /// Display name for the user
  final String displayName;

  /// User's first name
  final String? firstName;

  /// User's last name
  final String? lastName;

  /// User's date of birth
  final DateTime? dateOfBirth;

  /// User's phone number
  final String? phoneNumber;

  /// List of role IDs assigned to the user
  final List<String> roleIds;

  /// Current status of the user account
  final UserAccountStatus status;

  /// List of guardian user IDs (for minors or dependent users)
  final List<String> guardianIds;

  /// Whether this user requires parental consent for data processing
  final bool requiresParentalConsent;

  /// User preferences and settings
  final Map<String, dynamic> preferences;

  /// Additional metadata about the user
  final Map<String, dynamic> metadata;

  /// When the profile was created
  final DateTime createdAt;

  /// When the profile was last updated
  final DateTime updatedAt;

  /// When the user last logged in
  final DateTime? lastLoginAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    this.phoneNumber,
    required this.roleIds,
    required this.status,
    this.guardianIds = const [],
    this.requiresParentalConsent = false,
    this.preferences = const {},
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
  });

  /// Create a copy with updated fields
  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    String? phoneNumber,
    List<String>? roleIds,
    UserAccountStatus? status,
    List<String>? guardianIds,
    bool? requiresParentalConsent,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      roleIds: roleIds ?? this.roleIds,
      status: status ?? this.status,
      guardianIds: guardianIds ?? this.guardianIds,
      requiresParentalConsent:
          requiresParentalConsent ?? this.requiresParentalConsent,
      preferences: preferences ?? this.preferences,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  /// Get user's full name
  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    }
    return displayName;
  }

  /// Check if the user is active
  bool get isActive => status == UserAccountStatus.active;

  /// Check if the user is blocked or suspended
  bool get isBlocked =>
      status == UserAccountStatus.blocked ||
      status == UserAccountStatus.suspended;

  /// Check if the user is a minor based on age
  bool get isMinor {
    if (dateOfBirth == null) return requiresParentalConsent;

    final age = DateTime.now().difference(dateOfBirth!).inDays / 365.25;
    return age < 18;
  }

  /// Check if the user has guardians
  bool get hasGuardians => guardianIds.isNotEmpty;

  /// Check if the user has a specific role
  bool hasRole(String roleId) => roleIds.contains(roleId);

  /// Check if the user has any of the specified roles
  bool hasAnyRole(List<String> roleIds) =>
      this.roleIds.any((roleId) => roleIds.contains(roleId));

  /// Check if the user has all specified roles
  bool hasAllRoles(List<String> roleIds) =>
      roleIds.every((roleId) => this.roleIds.contains(roleId));

  /// Get user preference value
  T? getPreference<T>(String key) {
    return preferences[key] as T?;
  }

  /// Get user preference with default value
  T getPreferenceWithDefault<T>(String key, T defaultValue) {
    return preferences[key] as T? ?? defaultValue;
  }

  /// Get metadata value
  T? getMetadata<T>(String key) {
    return metadata[key] as T?;
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'firstName': firstName,
      'lastName': lastName,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'phoneNumber': phoneNumber,
      'roleIds': roleIds,
      'status': status.value,
      'guardianIds': guardianIds,
      'requiresParentalConsent': requiresParentalConsent,
      'preferences': preferences,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  /// Create from JSON representation
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'] as String)
          : null,
      phoneNumber: json['phoneNumber'] as String?,
      roleIds: List<String>.from(json['roleIds'] as List? ?? []),
      status: UserAccountStatus.fromString(json['status'] as String),
      guardianIds: List<String>.from(json['guardianIds'] as List? ?? []),
      requiresParentalConsent:
          json['requiresParentalConsent'] as bool? ?? false,
      preferences: Map<String, dynamic>.from(json['preferences'] as Map? ?? {}),
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
    );
  }

  /// Create database map representation
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'first_name': firstName,
      'last_name': lastName,
      'date_of_birth': dateOfBirth?.millisecondsSinceEpoch,
      'phone_number': phoneNumber,
      'role_ids': roleIds.join(','),
      'status': status.value,
      'guardian_ids': guardianIds.join(','),
      'requires_parental_consent': requiresParentalConsent ? 1 : 0,
      'preferences': preferences.isNotEmpty ? preferences : null,
      'metadata': metadata.isNotEmpty ? metadata : null,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'last_login_at': lastLoginAt?.millisecondsSinceEpoch,
    };
  }

  /// Create from database map representation
  factory UserProfile.fromDatabaseMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      email: map['email'] as String,
      displayName: map['display_name'] as String,
      firstName: map['first_name'] as String?,
      lastName: map['last_name'] as String?,
      dateOfBirth: map['date_of_birth'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['date_of_birth'] as int)
          : null,
      phoneNumber: map['phone_number'] as String?,
      roleIds: (map['role_ids'] as String? ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList(),
      status: UserAccountStatus.fromString(map['status'] as String),
      guardianIds: (map['guardian_ids'] as String? ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList(),
      requiresParentalConsent:
          (map['requires_parental_consent'] as int? ?? 0) == 1,
      preferences: Map<String, dynamic>.from(map['preferences'] as Map? ?? {}),
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      lastLoginAt: map['last_login_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_login_at'] as int)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.id == id && other.email == email;
  }

  @override
  int get hashCode => Object.hash(id, email);

  @override
  String toString() {
    return 'UserProfile(id: $id, email: $email, displayName: $displayName, '
        'status: $status, roles: ${roleIds.length})';
  }
}
