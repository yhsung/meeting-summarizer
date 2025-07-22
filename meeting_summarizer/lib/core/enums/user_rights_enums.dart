/// Enumerations for comprehensive user rights management system
library;

/// User account status enumeration
enum UserAccountStatus {
  active('active', 'Active'),
  inactive('inactive', 'Inactive'),
  suspended('suspended', 'Suspended'),
  pending('pending', 'Pending Verification'),
  blocked('blocked', 'Blocked'),
  deleted('deleted', 'Deleted');

  const UserAccountStatus(this.value, this.displayName);

  final String value;
  final String displayName;

  static UserAccountStatus fromString(String value) {
    return UserAccountStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => UserAccountStatus.pending,
    );
  }
}

/// Access actions that can be performed on resources
enum AccessAction {
  read('read', 'Read'),
  write('write', 'Write'),
  delete('delete', 'Delete'),
  create('create', 'Create'),
  update('update', 'Update'),
  execute('execute', 'Execute'),
  admin('admin', 'Admin'),
  share('share', 'Share'),
  export('export', 'Export'),
  import('import', 'Import');

  const AccessAction(this.value, this.displayName);

  final String value;
  final String displayName;

  static AccessAction fromString(String value) {
    return AccessAction.values.firstWhere(
      (action) => action.value == value,
      orElse: () => AccessAction.read,
    );
  }

  static List<AccessAction> fromStringList(List<String> values) {
    return values.map((value) => fromString(value)).toList();
  }

  static List<String> toStringList(List<AccessAction> actions) {
    return actions.map((action) => action.value).toList();
  }
}

/// Rights delegation status
enum DelegationStatus {
  active('active', 'Active'),
  expired('expired', 'Expired'),
  revoked('revoked', 'Revoked'),
  suspended('suspended', 'Suspended');

  const DelegationStatus(this.value, this.displayName);

  final String value;
  final String displayName;

  static DelegationStatus fromString(String value) {
    return DelegationStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => DelegationStatus.active,
    );
  }
}

/// Access audit actions for logging
enum AccessAuditAction {
  login('login', 'Login'),
  logout('logout', 'Logout'),
  dataAccess('data_access', 'Data Access'),
  dataModification('data_modification', 'Data Modification'),
  permissionGranted('permission_granted', 'Permission Granted'),
  permissionRevoked('permission_revoked', 'Permission Revoked'),
  roleAssigned('role_assigned', 'Role Assigned'),
  roleRemoved('role_removed', 'Role Removed'),
  rightsDelegate('rights_delegate', 'Rights Delegated'),
  rightsRevoke('rights_revoke', 'Rights Revoked'),
  identityVerification('identity_verification', 'Identity Verification'),
  sensitiveDataAccess('sensitive_data_access', 'Sensitive Data Access'),
  adminAction('admin_action', 'Admin Action'),
  complianceCheck('compliance_check', 'Compliance Check');

  const AccessAuditAction(this.value, this.displayName);

  final String value;
  final String displayName;

  static AccessAuditAction fromString(String value) {
    return AccessAuditAction.values.firstWhere(
      (action) => action.value == value,
      orElse: () => AccessAuditAction.dataAccess,
    );
  }
}

/// User rights service event types
enum UserRightsServiceEventType {
  serviceInitialized('service_initialized', 'Service Initialized'),
  profileCreated('profile_created', 'Profile Created'),
  profileUpdated('profile_updated', 'Profile Updated'),
  profileDeleted('profile_deleted', 'Profile Deleted'),
  roleAssigned('role_assigned', 'Role Assigned'),
  roleRemoved('role_removed', 'Role Removed'),
  permissionGranted('permission_granted', 'Permission Granted'),
  permissionRevoked('permission_revoked', 'Permission Revoked'),
  rightsDelegate('rights_delegate', 'Rights Delegated'),
  rightsRevoke('rights_revoke', 'Rights Revoked'),
  accessDenied('access_denied', 'Access Denied'),
  identityVerified('identity_verified', 'Identity Verified'),
  complianceViolation('compliance_violation', 'Compliance Violation'),
  guardianshipAssigned('guardianship_assigned', 'Guardianship Assigned'),
  guardianshipRevoked('guardianship_revoked', 'Guardianship Revoked');

  const UserRightsServiceEventType(this.value, this.displayName);

  final String value;
  final String displayName;

  static UserRightsServiceEventType fromString(String value) {
    return UserRightsServiceEventType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => UserRightsServiceEventType.serviceInitialized,
    );
  }
}

/// Role hierarchy levels
enum RoleLevel {
  system(0, 'System'),
  admin(1, 'Administrator'),
  manager(2, 'Manager'),
  user(3, 'User'),
  limited(4, 'Limited User'),
  guest(5, 'Guest');

  const RoleLevel(this.level, this.displayName);

  final int level;
  final String displayName;

  /// Check if this role level is higher than another
  bool isHigherThan(RoleLevel other) => level < other.level;

  /// Check if this role level is lower than another
  bool isLowerThan(RoleLevel other) => level > other.level;

  /// Check if this role level is equal to another
  bool isEqualTo(RoleLevel other) => level == other.level;
}

/// Guardian relationship types
enum GuardianshipType {
  parent('parent', 'Parent'),
  legalGuardian('legal_guardian', 'Legal Guardian'),
  temporaryGuardian('temporary_guardian', 'Temporary Guardian'),
  courtAppointed('court_appointed', 'Court Appointed'),
  powerOfAttorney('power_of_attorney', 'Power of Attorney'),
  custodian('custodian', 'Custodian');

  const GuardianshipType(this.value, this.displayName);

  final String value;
  final String displayName;

  static GuardianshipType fromString(String value) {
    return GuardianshipType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => GuardianshipType.parent,
    );
  }
}

/// Permission scopes for fine-grained access control
enum PermissionScope {
  global('global', 'Global'),
  organization('organization', 'Organization'),
  group('group', 'Group'),
  personal('personal', 'Personal'),
  restricted('restricted', 'Restricted');

  const PermissionScope(this.value, this.displayName);

  final String value;
  final String displayName;

  static PermissionScope fromString(String value) {
    return PermissionScope.values.firstWhere(
      (scope) => scope.value == value,
      orElse: () => PermissionScope.personal,
    );
  }
}
