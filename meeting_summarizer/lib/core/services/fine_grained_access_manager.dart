/// Fine-grained access control manager for detailed permission validation
library;

import 'dart:async';
import 'dart:developer';

import '../models/user_rights/access_permission.dart';
import '../models/user_rights/access_audit_log.dart';
import '../enums/user_rights_enums.dart';
import '../dao/user_rights_dao.dart';
import 'permission_inheritance_manager.dart';

/// Provides fine-grained access control with detailed validation and auditing
class FineGrainedAccessManager {
  final UserRightsDao _dao;
  final PermissionInheritanceManager _inheritanceManager;

  /// Access decision cache for performance
  final Map<String, _AccessDecision> _decisionCache = {};
  static const Duration _decisionCacheExpiry = Duration(minutes: 5);

  FineGrainedAccessManager(this._dao)
    : _inheritanceManager = PermissionInheritanceManager(_dao);

  /// Validate access with detailed conditions and constraints
  Future<AccessValidationResult> validateAccess({
    required String userId,
    required String resource,
    required AccessAction action,
    Map<String, dynamic> context = const {},
    String? sessionId,
    String? ipAddress,
  }) async {
    try {
      final cacheKey = _generateCacheKey(userId, resource, action);

      // Check decision cache
      if (_isDecisionCached(cacheKey)) {
        final cachedDecision = _decisionCache[cacheKey]!;
        return AccessValidationResult._fromCached(cachedDecision);
      }

      final userProfile = await _dao.getUserProfile(userId);
      if (userProfile == null) {
        return _createDeniedResult('User not found', userId, resource, action);
      }

      // Check if user account is active
      if (!userProfile.isActive) {
        return _createDeniedResult(
          'User account is not active',
          userId,
          resource,
          action,
        );
      }

      // Get effective permissions
      final permissions = await _inheritanceManager.getResourcePermissions(
        userId,
        resource,
      );

      if (permissions.isEmpty) {
        return _createDeniedResult(
          'No permissions found for resource',
          userId,
          resource,
          action,
        );
      }

      // Find applicable permissions
      final applicablePermissions = permissions
          .where((p) => p.actions.contains(action))
          .toList();

      if (applicablePermissions.isEmpty) {
        return _createDeniedResult(
          'Action not permitted for resource',
          userId,
          resource,
          action,
        );
      }

      // Validate conditions for each applicable permission
      final validationResults = <PermissionValidationResult>[];

      for (final permission in applicablePermissions) {
        final result = await _validatePermissionConditions(
          permission,
          context,
          sessionId,
          ipAddress,
        );
        validationResults.add(result);
      }

      // Check if any permission grants access
      final grantingResults = validationResults
          .where((r) => r.isGranted)
          .toList();

      AccessValidationResult finalResult;

      if (grantingResults.isNotEmpty) {
        finalResult = AccessValidationResult.granted(
          userId: userId,
          resource: resource,
          action: action,
          grantingPermissions: grantingResults
              .map((r) => r.permission)
              .toList(),
          validationDetails: validationResults,
          context: context,
        );
      } else {
        final reasons = validationResults
            .where((r) => !r.isGranted)
            .map((r) => r.reason)
            .toSet()
            .join('; ');

        finalResult = _createDeniedResult(
          reasons.isNotEmpty ? reasons : 'Permission conditions not met',
          userId,
          resource,
          action,
          validationDetails: validationResults,
        );
      }

      // Cache the decision
      _cacheDecision(cacheKey, finalResult);

      // Log the access attempt
      await _logAccessAttempt(finalResult, sessionId, ipAddress);

      return finalResult;
    } catch (e) {
      log('FineGrainedAccessManager: Error validating access: $e');
      return _createDeniedResult(
        'Access validation error: $e',
        userId,
        resource,
        action,
      );
    }
  }

  /// Validate conditions for a specific permission
  Future<PermissionValidationResult> _validatePermissionConditions(
    AccessPermission permission,
    Map<String, dynamic> context,
    String? sessionId,
    String? ipAddress,
  ) async {
    try {
      // Check if permission is expired
      if (permission.isExpired) {
        return PermissionValidationResult.denied(
          permission: permission,
          reason: 'Permission expired',
        );
      }

      // Check if permission is active
      if (!permission.isActive) {
        return PermissionValidationResult.denied(
          permission: permission,
          reason: 'Permission not active',
        );
      }

      // Validate custom conditions
      final conditionResults = await _validateCustomConditions(
        permission.conditions,
        context,
        sessionId,
        ipAddress,
      );

      if (conditionResults.isNotEmpty) {
        return PermissionValidationResult.denied(
          permission: permission,
          reason: 'Conditions not met: ${conditionResults.join(', ')}',
          failedConditions: conditionResults,
        );
      }

      // Validate time-based restrictions
      if (!_validateTimeRestrictions(permission, context)) {
        return PermissionValidationResult.denied(
          permission: permission,
          reason: 'Time restrictions not met',
        );
      }

      // Validate IP restrictions
      if (!_validateIPRestrictions(permission, ipAddress)) {
        return PermissionValidationResult.denied(
          permission: permission,
          reason: 'IP address restrictions not met',
        );
      }

      // Validate session requirements
      if (!_validateSessionRequirements(permission, sessionId)) {
        return PermissionValidationResult.denied(
          permission: permission,
          reason: 'Session requirements not met',
        );
      }

      return PermissionValidationResult.granted(
        permission: permission,
        reason: 'All conditions met',
      );
    } catch (e) {
      log(
        'FineGrainedAccessManager: Error validating permission conditions: $e',
      );
      return PermissionValidationResult.denied(
        permission: permission,
        reason: 'Validation error: $e',
      );
    }
  }

  /// Validate custom conditions defined in the permission
  Future<List<String>> _validateCustomConditions(
    Map<String, dynamic> conditions,
    Map<String, dynamic> context,
    String? sessionId,
    String? ipAddress,
  ) async {
    final failedConditions = <String>[];

    for (final entry in conditions.entries) {
      final key = entry.key;
      final expectedValue = entry.value;

      switch (key) {
        case 'requires_2fa':
          if (expectedValue == true) {
            final has2FA = context['has_2fa'] as bool? ?? false;
            if (!has2FA) {
              failedConditions.add('Two-factor authentication required');
            }
          }
          break;

        case 'max_concurrent_sessions':
          final maxSessions = expectedValue as int?;
          if (maxSessions != null && sessionId != null) {
            // This would require checking active sessions - simplified for now
            // final activeSessions = await _getActiveSessionCount(userId);
            // if (activeSessions >= maxSessions) {
            //   failedConditions.add('Maximum concurrent sessions exceeded');
            // }
          }
          break;

        case 'allowed_user_agents':
          final allowedAgents = expectedValue as List<String>?;
          final userAgent = context['user_agent'] as String?;
          if (allowedAgents != null && userAgent != null) {
            final isAllowed = allowedAgents.any(
              (agent) => userAgent.toLowerCase().contains(agent.toLowerCase()),
            );
            if (!isAllowed) {
              failedConditions.add('User agent not allowed');
            }
          }
          break;

        case 'required_role':
          final requiredRole = expectedValue as String?;
          if (requiredRole != null) {
            final userRoles = context['user_roles'] as List<String>? ?? [];
            if (!userRoles.contains(requiredRole)) {
              failedConditions.add('Required role not present: $requiredRole');
            }
          }
          break;

        case 'data_sensitivity_level':
          final requiredLevel = expectedValue as String?;
          final contextLevel = context['data_sensitivity'] as String?;
          if (requiredLevel != null && contextLevel != null) {
            if (!_validateSensitivityLevel(contextLevel, requiredLevel)) {
              failedConditions.add(
                'Insufficient access level for data sensitivity',
              );
            }
          }
          break;

        default:
          // Generic condition validation
          final contextValue = context[key];
          if (contextValue != expectedValue) {
            failedConditions.add('Condition $key not met');
          }
          break;
      }
    }

    return failedConditions;
  }

  /// Validate time-based restrictions
  bool _validateTimeRestrictions(
    AccessPermission permission,
    Map<String, dynamic> context,
  ) {
    final timeRestrictions =
        permission.conditions['time_restrictions'] as Map<String, dynamic>?;
    if (timeRestrictions == null) return true;

    final now = DateTime.now();

    // Check business hours
    final businessHoursOnly =
        timeRestrictions['business_hours_only'] as bool? ?? false;
    if (businessHoursOnly) {
      final hour = now.hour;
      final isWeekday = now.weekday <= 5; // Monday = 1, Friday = 5
      if (!isWeekday || hour < 9 || hour >= 17) {
        return false;
      }
    }

    // Check specific time ranges
    final allowedTimes =
        timeRestrictions['allowed_times'] as List<Map<String, dynamic>>?;
    if (allowedTimes != null) {
      final currentTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final isInAllowedTime = allowedTimes.any((timeRange) {
        final start = timeRange['start'] as String?;
        final end = timeRange['end'] as String?;
        if (start == null || end == null) return false;
        return _isTimeInRange(currentTime, start, end);
      });
      if (!isInAllowedTime) return false;
    }

    return true;
  }

  /// Validate IP address restrictions
  bool _validateIPRestrictions(AccessPermission permission, String? ipAddress) {
    if (ipAddress == null) return true;

    final ipRestrictions =
        permission.conditions['ip_restrictions'] as Map<String, dynamic>?;
    if (ipRestrictions == null) return true;

    final allowedIPs = ipRestrictions['allowed_ips'] as List<String>?;
    if (allowedIPs != null && !allowedIPs.contains(ipAddress)) {
      return false;
    }

    final blockedIPs = ipRestrictions['blocked_ips'] as List<String>?;
    if (blockedIPs != null && blockedIPs.contains(ipAddress)) {
      return false;
    }

    return true;
  }

  /// Validate session requirements
  bool _validateSessionRequirements(
    AccessPermission permission,
    String? sessionId,
  ) {
    if (sessionId == null) return true;

    final sessionReqs =
        permission.conditions['session_requirements'] as Map<String, dynamic>?;
    if (sessionReqs == null) return true;

    final requiresSession = sessionReqs['requires_session'] as bool? ?? false;
    if (requiresSession && sessionId.isEmpty) {
      return false;
    }

    return true;
  }

  /// Check if time is within allowed range
  bool _isTimeInRange(String currentTime, String startTime, String endTime) {
    try {
      final current = _parseTime(currentTime);
      final start = _parseTime(startTime);
      final end = _parseTime(endTime);

      if (start <= end) {
        return current >= start && current <= end;
      } else {
        // Range crosses midnight
        return current >= start || current <= end;
      }
    } catch (e) {
      log('FineGrainedAccessManager: Error parsing time range: $e');
      return false;
    }
  }

  /// Parse time string to minutes since midnight
  int _parseTime(String time) {
    final parts = time.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    return hours * 60 + minutes;
  }

  /// Validate data sensitivity levels
  bool _validateSensitivityLevel(String contextLevel, String requiredLevel) {
    const levels = ['public', 'internal', 'confidential', 'restricted'];
    final contextIndex = levels.indexOf(contextLevel.toLowerCase());
    final requiredIndex = levels.indexOf(requiredLevel.toLowerCase());

    return contextIndex >= requiredIndex;
  }

  /// Log access attempt for auditing
  Future<void> _logAccessAttempt(
    AccessValidationResult result,
    String? sessionId,
    String? ipAddress,
  ) async {
    try {
      final auditLog = AccessAuditLog.createDataAccess(
        userId: result.userId,
        resource: result.resource,
        description: result.isGranted
            ? 'Access granted to ${result.resource} for ${result.action.displayName}'
            : 'Access denied to ${result.resource} for ${result.action.displayName}: ${result.reason}',
        ipAddress: ipAddress,
        success: result.isGranted,
        errorMessage: result.isGranted ? null : result.reason,
        contextData: {
          'action': result.action.value,
          'validation_details': result.validationDetails
              ?.map((d) => d.toJson())
              .toList(),
          if (result.grantingPermissions != null)
            'granting_permissions': result.grantingPermissions!
                .map((p) => p.id)
                .toList(),
        },
        riskLevel: result.isGranted ? 'low' : 'medium',
        sessionId: sessionId,
      );

      await _dao.createAuditLog(auditLog);
    } catch (e) {
      log('FineGrainedAccessManager: Error logging access attempt: $e');
    }
  }

  /// Create denied access result
  AccessValidationResult _createDeniedResult(
    String reason,
    String userId,
    String resource,
    AccessAction action, {
    List<PermissionValidationResult>? validationDetails,
  }) {
    return AccessValidationResult.denied(
      userId: userId,
      resource: resource,
      action: action,
      reason: reason,
      validationDetails: validationDetails ?? [],
      context: {},
    );
  }

  /// Generate cache key for access decisions
  String _generateCacheKey(
    String userId,
    String resource,
    AccessAction action,
  ) {
    return '$userId:$resource:${action.value}';
  }

  /// Check if decision is cached and valid
  bool _isDecisionCached(String cacheKey) {
    final decision = _decisionCache[cacheKey];
    if (decision == null) return false;

    return DateTime.now().difference(decision.timestamp) <=
        _decisionCacheExpiry;
  }

  /// Cache access decision
  void _cacheDecision(String cacheKey, AccessValidationResult result) {
    _decisionCache[cacheKey] = _AccessDecision(
      isGranted: result.isGranted,
      reason: result.reason,
      timestamp: DateTime.now(),
    );
  }

  /// Clear cache for specific user
  void clearUserCache(String userId) {
    _decisionCache.removeWhere((key, _) => key.startsWith('$userId:'));
    _inheritanceManager.clearUserCache(userId);
  }

  /// Clear all cache
  void clearAllCache() {
    _decisionCache.clear();
    _inheritanceManager.clearAllCache();
  }

  /// Dispose resources
  void dispose() {
    clearAllCache();
  }
}

/// Cached access decision
class _AccessDecision {
  final bool isGranted;
  final String reason;
  final DateTime timestamp;

  _AccessDecision({
    required this.isGranted,
    required this.reason,
    required this.timestamp,
  });
}

/// Result of access validation
class AccessValidationResult {
  final bool isGranted;
  final String userId;
  final String resource;
  final AccessAction action;
  final String reason;
  final List<AccessPermission>? grantingPermissions;
  final List<PermissionValidationResult>? validationDetails;
  final Map<String, dynamic> context;
  final DateTime timestamp;

  AccessValidationResult.granted({
    required this.userId,
    required this.resource,
    required this.action,
    required this.grantingPermissions,
    this.validationDetails,
    this.context = const {},
  }) : isGranted = true,
       reason = 'Access granted',
       timestamp = DateTime.now();

  AccessValidationResult.denied({
    required this.userId,
    required this.resource,
    required this.action,
    required this.reason,
    this.validationDetails,
    this.context = const {},
  }) : isGranted = false,
       grantingPermissions = null,
       timestamp = DateTime.now();

  AccessValidationResult._fromCached(_AccessDecision decision)
    : isGranted = decision.isGranted,
      userId = '',
      resource = '',
      action = AccessAction.read,
      reason = decision.reason,
      grantingPermissions = null,
      validationDetails = null,
      context = const {},
      timestamp = decision.timestamp;
}

/// Result of individual permission validation
class PermissionValidationResult {
  final bool isGranted;
  final AccessPermission permission;
  final String reason;
  final List<String>? failedConditions;

  PermissionValidationResult.granted({
    required this.permission,
    required this.reason,
  }) : isGranted = true,
       failedConditions = null;

  PermissionValidationResult.denied({
    required this.permission,
    required this.reason,
    this.failedConditions,
  }) : isGranted = false;

  Map<String, dynamic> toJson() {
    return {
      'isGranted': isGranted,
      'permissionId': permission.id,
      'reason': reason,
      'failedConditions': failedConditions,
    };
  }
}
