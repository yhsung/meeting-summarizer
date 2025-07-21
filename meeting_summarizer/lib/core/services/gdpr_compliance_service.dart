/// Core GDPR compliance service for privacy management
library;

import 'dart:async';
import 'dart:developer';

import '../models/gdpr/consent_record.dart';
import '../models/gdpr/data_processing_record.dart';
import '../models/gdpr/user_rights_request.dart';
import '../enums/gdpr_consent_type.dart';
import 'consent_manager.dart';
import 'user_rights_manager.dart';
import 'data_processing_audit_logger.dart';

/// Service for managing GDPR compliance across the application
class GDPRComplianceService {
  static GDPRComplianceService? _instance;
  bool _isInitialized = false;

  /// Consent management component
  late final ConsentManager _consentManager;

  /// User rights management component
  late final UserRightsManager _userRightsManager;

  /// Data processing audit logger
  late final DataProcessingAuditLogger _auditLogger;

  /// Stream controller for compliance events
  final StreamController<GDPRComplianceEvent> _eventController =
      StreamController<GDPRComplianceEvent>.broadcast();

  /// Private constructor for singleton
  GDPRComplianceService._();

  /// Get singleton instance
  static GDPRComplianceService get instance {
    _instance ??= GDPRComplianceService._();
    return _instance!;
  }

  /// Initialize the GDPR compliance service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log('GDPRComplianceService: Initializing...');

      // Initialize components
      _consentManager = ConsentManager();
      _userRightsManager = UserRightsManager();
      _auditLogger = DataProcessingAuditLogger();

      await _consentManager.initialize();
      await _userRightsManager.initialize();
      await _auditLogger.initialize();

      _isInitialized = true;
      log('GDPRComplianceService: Initialization completed');

      // Emit initialization event
      _eventController.add(GDPRComplianceEvent.serviceInitialized());
    } catch (e) {
      log('GDPRComplianceService: Initialization failed: $e');
      throw GDPRComplianceException(
        'Failed to initialize GDPR compliance service: $e',
      );
    }
  }

  /// Dispose of the service and clean up resources
  Future<void> dispose() async {
    try {
      await _consentManager.dispose();
      await _userRightsManager.dispose();
      await _auditLogger.dispose();
      await _eventController.close();

      _isInitialized = false;
      log('GDPRComplianceService: Disposed');
    } catch (e) {
      log('GDPRComplianceService: Error during disposal: $e');
    }
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Get consent manager
  ConsentManager get consent {
    _ensureInitialized();
    return _consentManager;
  }

  /// Get user rights manager
  UserRightsManager get userRights {
    _ensureInitialized();
    return _userRightsManager;
  }

  /// Get audit logger
  DataProcessingAuditLogger get audit {
    _ensureInitialized();
    return _auditLogger;
  }

  /// Stream of GDPR compliance events
  Stream<GDPRComplianceEvent> get events => _eventController.stream;

  /// Check if user has given required consents
  Future<bool> hasRequiredConsents(String userId) async {
    _ensureInitialized();

    try {
      final summary = await _consentManager.getConsentSummary(userId);
      return summary.isCompliant;
    } catch (e) {
      log('GDPRComplianceService: Error checking required consents: $e');
      return false;
    }
  }

  /// Get overall compliance status for a user
  Future<ComplianceStatus> getComplianceStatus(String userId) async {
    _ensureInitialized();

    try {
      // Check consent compliance
      final consentSummary = await _consentManager.getConsentSummary(userId);

      // Check pending user rights requests
      final pendingRequests = await _userRightsManager.getPendingRequests(
        userId,
      );

      // Check for overdue data retention
      final overdueData = await _auditLogger.getOverdueRetentionData(userId);

      return ComplianceStatus(
        userId: userId,
        consentCompliance: consentSummary.complianceScore,
        pendingUserRightsRequests: pendingRequests.length,
        overdueDataRetentionCount: overdueData.length,
        lastAssessmentDate: DateTime.now(),
        overallScore: _calculateOverallComplianceScore(
          consentSummary.complianceScore,
          pendingRequests.length,
          overdueData.length,
        ),
      );
    } catch (e) {
      log('GDPRComplianceService: Error getting compliance status: $e');
      throw GDPRComplianceException('Failed to get compliance status: $e');
    }
  }

  /// Perform comprehensive compliance audit
  Future<ComplianceAuditReport> performComplianceAudit() async {
    _ensureInitialized();

    try {
      log('GDPRComplianceService: Starting compliance audit...');

      // Get all consent records
      final allConsents = await _consentManager.getAllConsentRecords();

      // Get all user rights requests
      final allRequests = await _userRightsManager.getAllRequests();

      // Get processing records
      final processingRecords = await _auditLogger.getAllProcessingRecords();

      // Analyze compliance metrics
      final auditReport = ComplianceAuditReport(
        auditId: 'audit_${DateTime.now().millisecondsSinceEpoch}',
        performedAt: DateTime.now(),
        totalUsers: allConsents.map((c) => c.userId).toSet().length,
        totalConsentRecords: allConsents.length,
        activeConsents: allConsents.where((c) => c.isValid).length,
        expiredConsents: allConsents.where((c) => c.isExpired).length,
        totalUserRightsRequests: allRequests.length,
        pendingRequests: allRequests.where((r) => r.status.isActive).length,
        overdueRequests: allRequests.where((r) => r.isOverdue).length,
        totalProcessingRecords: processingRecords.length,
        highRiskProcessing: processingRecords
            .where((r) => r.complianceRiskLevel >= 2)
            .length,
        complianceIssues: _identifyComplianceIssues(
          allConsents,
          allRequests,
          processingRecords,
        ),
        recommendations: _generateRecommendations(
          allConsents,
          allRequests,
          processingRecords,
        ),
      );

      log('GDPRComplianceService: Compliance audit completed');
      _eventController.add(GDPRComplianceEvent.auditCompleted(auditReport));

      return auditReport;
    } catch (e) {
      log('GDPRComplianceService: Compliance audit failed: $e');
      throw GDPRComplianceException('Failed to perform compliance audit: $e');
    }
  }

  /// Ensure service is initialized before use
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw GDPRComplianceException('GDPR compliance service not initialized');
    }
  }

  /// Calculate overall compliance score
  double _calculateOverallComplianceScore(
    double consentScore,
    int pendingRequests,
    int overdueData,
  ) {
    double score = consentScore;

    // Reduce score for pending requests
    if (pendingRequests > 0) {
      score -= (pendingRequests * 0.1).clamp(0.0, 0.3);
    }

    // Reduce score for overdue data
    if (overdueData > 0) {
      score -= (overdueData * 0.05).clamp(0.0, 0.2);
    }

    return score.clamp(0.0, 1.0);
  }

  /// Identify compliance issues from audit data
  List<ComplianceIssue> _identifyComplianceIssues(
    List<ConsentRecord> consents,
    List<UserRightsRequest> requests,
    List<DataProcessingRecord> processing,
  ) {
    final issues = <ComplianceIssue>[];

    // Check for expired consents
    final expiredConsents = consents.where((c) => c.isExpired).length;
    if (expiredConsents > 0) {
      issues.add(
        ComplianceIssue(
          type: 'expired_consents',
          severity: 'medium',
          description: '$expiredConsents consent records have expired',
          recommendation: 'Request consent renewal from affected users',
        ),
      );
    }

    // Check for overdue user rights requests
    final overdueRequests = requests.where((r) => r.isOverdue).length;
    if (overdueRequests > 0) {
      issues.add(
        ComplianceIssue(
          type: 'overdue_requests',
          severity: 'high',
          description: '$overdueRequests user rights requests are overdue',
          recommendation:
              'Process overdue requests immediately to avoid compliance violations',
        ),
      );
    }

    // Check for high-risk processing
    final highRiskProcessing = processing
        .where((p) => p.complianceRiskLevel >= 2)
        .length;
    if (highRiskProcessing > 0) {
      issues.add(
        ComplianceIssue(
          type: 'high_risk_processing',
          severity: 'high',
          description:
              '$highRiskProcessing data processing activities are high risk',
          recommendation:
              'Review and implement additional security measures for high-risk processing',
        ),
      );
    }

    return issues;
  }

  /// Generate recommendations based on audit data
  List<String> _generateRecommendations(
    List<ConsentRecord> consents,
    List<UserRightsRequest> requests,
    List<DataProcessingRecord> processing,
  ) {
    final recommendations = <String>[];

    // Consent recommendations
    final consentsByType = <GDPRConsentType, int>{};
    for (final consent in consents) {
      consentsByType[consent.consentType] =
          (consentsByType[consent.consentType] ?? 0) + 1;
    }

    if ((consentsByType[GDPRConsentType.analytics] ?? 0) <
        consents.length * 0.7) {
      recommendations.add(
        'Consider improving analytics consent opt-in rate through better UX',
      );
    }

    // User rights recommendations
    final avgProcessingTime = requests.isNotEmpty
        ? requests
                  .where((r) => r.processingDuration != null)
                  .map((r) => r.processingDuration!.inDays)
                  .fold(0, (sum, days) => sum + days) /
              requests.length
        : 0;

    if (avgProcessingTime > 14) {
      recommendations.add(
        'Improve user rights request processing time (current average: ${avgProcessingTime.toStringAsFixed(1)} days)',
      );
    }

    // Data processing recommendations
    final processingWithoutSecurityMeasures = processing
        .where((p) => p.securityMeasures.isEmpty)
        .length;
    if (processingWithoutSecurityMeasures > 0) {
      recommendations.add(
        'Implement security measures for all data processing activities',
      );
    }

    return recommendations;
  }
}

/// GDPR compliance event for notifications
class GDPRComplianceEvent {
  final String type;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  const GDPRComplianceEvent({
    required this.type,
    required this.description,
    required this.timestamp,
    this.data = const {},
  });

  factory GDPRComplianceEvent.serviceInitialized() {
    return GDPRComplianceEvent(
      type: 'service_initialized',
      description: 'GDPR compliance service initialized',
      timestamp: DateTime.now(),
    );
  }

  factory GDPRComplianceEvent.consentGranted(ConsentRecord consent) {
    return GDPRComplianceEvent(
      type: 'consent_granted',
      description: 'User granted ${consent.consentType.displayName} consent',
      timestamp: DateTime.now(),
      data: {'consentId': consent.id, 'userId': consent.userId},
    );
  }

  factory GDPRComplianceEvent.consentWithdrawn(ConsentRecord consent) {
    return GDPRComplianceEvent(
      type: 'consent_withdrawn',
      description: 'User withdrew ${consent.consentType.displayName} consent',
      timestamp: DateTime.now(),
      data: {'consentId': consent.id, 'userId': consent.userId},
    );
  }

  factory GDPRComplianceEvent.userRightRequested(UserRightsRequest request) {
    return GDPRComplianceEvent(
      type: 'user_right_requested',
      description: 'User requested ${request.rightType.displayName}',
      timestamp: DateTime.now(),
      data: {'requestId': request.id, 'userId': request.userId},
    );
  }

  factory GDPRComplianceEvent.auditCompleted(ComplianceAuditReport report) {
    return GDPRComplianceEvent(
      type: 'audit_completed',
      description: 'Compliance audit completed',
      timestamp: DateTime.now(),
      data: {
        'auditId': report.auditId,
        'issuesFound': report.complianceIssues.length,
      },
    );
  }
}

/// Overall compliance status for a user
class ComplianceStatus {
  final String userId;
  final double consentCompliance;
  final int pendingUserRightsRequests;
  final int overdueDataRetentionCount;
  final DateTime lastAssessmentDate;
  final double overallScore;

  const ComplianceStatus({
    required this.userId,
    required this.consentCompliance,
    required this.pendingUserRightsRequests,
    required this.overdueDataRetentionCount,
    required this.lastAssessmentDate,
    required this.overallScore,
  });

  /// Check if user is fully compliant
  bool get isCompliant => overallScore >= 0.9;

  /// Get compliance level description
  String get complianceLevel {
    if (overallScore >= 0.9) return 'Excellent';
    if (overallScore >= 0.8) return 'Good';
    if (overallScore >= 0.7) return 'Fair';
    if (overallScore >= 0.6) return 'Poor';
    return 'Critical';
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'consentCompliance': consentCompliance,
      'pendingUserRightsRequests': pendingUserRightsRequests,
      'overdueDataRetentionCount': overdueDataRetentionCount,
      'lastAssessmentDate': lastAssessmentDate.toIso8601String(),
      'overallScore': overallScore,
    };
  }
}

/// Compliance audit report
class ComplianceAuditReport {
  final String auditId;
  final DateTime performedAt;
  final int totalUsers;
  final int totalConsentRecords;
  final int activeConsents;
  final int expiredConsents;
  final int totalUserRightsRequests;
  final int pendingRequests;
  final int overdueRequests;
  final int totalProcessingRecords;
  final int highRiskProcessing;
  final List<ComplianceIssue> complianceIssues;
  final List<String> recommendations;

  const ComplianceAuditReport({
    required this.auditId,
    required this.performedAt,
    required this.totalUsers,
    required this.totalConsentRecords,
    required this.activeConsents,
    required this.expiredConsents,
    required this.totalUserRightsRequests,
    required this.pendingRequests,
    required this.overdueRequests,
    required this.totalProcessingRecords,
    required this.highRiskProcessing,
    required this.complianceIssues,
    required this.recommendations,
  });

  /// Get overall audit score
  double get auditScore {
    double score = 1.0;

    // Reduce score for expired consents
    if (totalConsentRecords > 0) {
      score -= (expiredConsents / totalConsentRecords) * 0.3;
    }

    // Reduce score for overdue requests
    if (totalUserRightsRequests > 0) {
      score -= (overdueRequests / totalUserRightsRequests) * 0.4;
    }

    // Reduce score for high-risk processing
    if (totalProcessingRecords > 0) {
      score -= (highRiskProcessing / totalProcessingRecords) * 0.3;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Get audit grade
  String get auditGrade {
    final score = auditScore;
    if (score >= 0.9) return 'A';
    if (score >= 0.8) return 'B';
    if (score >= 0.7) return 'C';
    if (score >= 0.6) return 'D';
    return 'F';
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'auditId': auditId,
      'performedAt': performedAt.toIso8601String(),
      'totalUsers': totalUsers,
      'totalConsentRecords': totalConsentRecords,
      'activeConsents': activeConsents,
      'expiredConsents': expiredConsents,
      'totalUserRightsRequests': totalUserRightsRequests,
      'pendingRequests': pendingRequests,
      'overdueRequests': overdueRequests,
      'totalProcessingRecords': totalProcessingRecords,
      'highRiskProcessing': highRiskProcessing,
      'complianceIssues': complianceIssues
          .map((issue) => issue.toJson())
          .toList(),
      'recommendations': recommendations,
      'auditScore': auditScore,
      'auditGrade': auditGrade,
    };
  }
}

/// Individual compliance issue
class ComplianceIssue {
  final String type;
  final String severity;
  final String description;
  final String recommendation;

  const ComplianceIssue({
    required this.type,
    required this.severity,
    required this.description,
    required this.recommendation,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'severity': severity,
      'description': description,
      'recommendation': recommendation,
    };
  }
}

/// GDPR compliance exception
class GDPRComplianceException implements Exception {
  final String message;
  final String? code;
  final dynamic cause;

  const GDPRComplianceException(this.message, {this.code, this.cause});

  @override
  String toString() => 'GDPRComplianceException: $message';
}
