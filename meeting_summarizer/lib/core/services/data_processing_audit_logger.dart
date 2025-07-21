/// Data processing audit logger for GDPR compliance tracking
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/gdpr/data_processing_record.dart';
import '../enums/data_category.dart';
import '../enums/legal_basis.dart';
import 'gdpr_compliance_service.dart';

/// Service for logging and tracking data processing activities for GDPR compliance
class DataProcessingAuditLogger {
  static const String _auditLogStorageKey = 'gdpr_processing_audit_log';
  static const String _retentionPoliciesKey = 'gdpr_retention_policies';

  bool _isInitialized = false;
  SharedPreferences? _prefs;

  /// In-memory cache of processing records
  final Map<String, DataProcessingRecord> _processingCache = {};

  /// Default retention policies by data category
  final Map<DataCategory, RetentionPeriod> _defaultRetentionPolicies = {
    DataCategory.personalInfo: RetentionPeriod.twoYears,
    DataCategory.audioData: RetentionPeriod.oneYear,
    DataCategory.transcriptionData: RetentionPeriod.oneYear,
    DataCategory.summaryData: RetentionPeriod.oneYear,
    DataCategory.deviceData: RetentionPeriod.sixMonths,
    DataCategory.usageData: RetentionPeriod.sixMonths,
    DataCategory.locationData: RetentionPeriod.thirtyDays,
    DataCategory.fileSystemData: RetentionPeriod.oneYear,
    DataCategory.diagnosticData: RetentionPeriod.ninetyDays,
    DataCategory.communicationData: RetentionPeriod.oneYear,
    DataCategory.thirdPartyData: RetentionPeriod.sixMonths,
    DataCategory.biometricData: RetentionPeriod.immediate,
  };

  /// Stream controller for processing events
  final StreamController<ProcessingAuditEvent> _eventController =
      StreamController<ProcessingAuditEvent>.broadcast();

  /// Initialize the audit logger
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log('DataProcessingAuditLogger: Initializing...');

      _prefs = await SharedPreferences.getInstance();
      await _loadProcessingRecords();
      await _loadRetentionPolicies();

      // Start background cleanup task
      _startPeriodicCleanup();

      _isInitialized = true;
      log('DataProcessingAuditLogger: Initialization completed');
    } catch (e) {
      log('DataProcessingAuditLogger: Initialization failed: $e');
      throw GDPRComplianceException('Failed to initialize audit logger: $e');
    }
  }

  /// Dispose of the audit logger
  Future<void> dispose() async {
    try {
      await _eventController.close();
      _processingCache.clear();
      _isInitialized = false;
      log('DataProcessingAuditLogger: Disposed');
    } catch (e) {
      log('DataProcessingAuditLogger: Error during disposal: $e');
    }
  }

  /// Stream of processing audit events
  Stream<ProcessingAuditEvent> get events => _eventController.stream;

  /// Log the start of data processing activity
  Future<DataProcessingRecord> logProcessingStart({
    required String userId,
    required DataCategory dataCategory,
    required ProcessingPurpose purpose,
    required LegalBasis legalBasis,
    required String description,
    String? dataSource,
    String? dataRecipient,
    bool sharedWithThirdParty = false,
    String? thirdPartyDetails,
    RetentionPeriod? retentionPeriod,
    bool involvedAutomatedDecision = false,
    String? automatedDecisionDetails,
    bool transferredOutsideEU = false,
    String? internationalTransferDetails,
    List<String> securityMeasures = const [],
    Map<String, dynamic> metadata = const {},
  }) async {
    _ensureInitialized();

    try {
      final now = DateTime.now();
      final effectiveRetentionPeriod =
          retentionPeriod ??
          _defaultRetentionPolicies[dataCategory] ??
          RetentionPeriod.oneYear;

      final record = DataProcessingRecord(
        id: _generateProcessingId(userId, dataCategory, purpose),
        userId: userId,
        dataCategory: dataCategory,
        purpose: purpose,
        legalBasis: legalBasis,
        startedAt: now,
        description: description,
        dataSource: dataSource,
        dataRecipient: dataRecipient,
        sharedWithThirdParty: sharedWithThirdParty,
        thirdPartyDetails: thirdPartyDetails,
        retentionPeriod: effectiveRetentionPeriod,
        expectedDeletionDate: effectiveRetentionPeriod.getRetentionDate(now),
        involvedAutomatedDecision: involvedAutomatedDecision,
        automatedDecisionDetails: automatedDecisionDetails,
        transferredOutsideEU: transferredOutsideEU,
        internationalTransferDetails: internationalTransferDetails,
        securityMeasures: securityMeasures,
        metadata: metadata,
        createdAt: now,
        updatedAt: now,
      );

      await _storeProcessingRecord(record);

      _eventController.add(ProcessingAuditEvent.processingStarted(record));

      log('DataProcessingAuditLogger: Processing started: ${record.id}');
      return record;
    } catch (e) {
      log('DataProcessingAuditLogger: Error logging processing start: $e');
      throw GDPRComplianceException('Failed to log processing start: $e');
    }
  }

  /// Log the completion of data processing activity
  Future<DataProcessingRecord> logProcessingComplete(String recordId) async {
    _ensureInitialized();

    try {
      final record = _processingCache[recordId];
      if (record == null) {
        throw GDPRComplianceException('Processing record not found: $recordId');
      }

      final completedRecord = record.copyWith(
        completedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _storeProcessingRecord(completedRecord);

      _eventController.add(
        ProcessingAuditEvent.processingCompleted(completedRecord),
      );

      log('DataProcessingAuditLogger: Processing completed: $recordId');
      return completedRecord;
    } catch (e) {
      log('DataProcessingAuditLogger: Error logging processing completion: $e');
      throw GDPRComplianceException('Failed to log processing completion: $e');
    }
  }

  /// Update processing record with additional information
  Future<DataProcessingRecord> updateProcessingRecord(
    String recordId, {
    String? dataRecipient,
    bool? sharedWithThirdParty,
    String? thirdPartyDetails,
    List<String>? securityMeasures,
    Map<String, dynamic>? metadata,
  }) async {
    _ensureInitialized();

    try {
      final record = _processingCache[recordId];
      if (record == null) {
        throw GDPRComplianceException('Processing record not found: $recordId');
      }

      final updatedRecord = record.copyWith(
        dataRecipient: dataRecipient ?? record.dataRecipient,
        sharedWithThirdParty:
            sharedWithThirdParty ?? record.sharedWithThirdParty,
        thirdPartyDetails: thirdPartyDetails ?? record.thirdPartyDetails,
        securityMeasures: securityMeasures ?? record.securityMeasures,
        metadata: metadata != null
            ? {...record.metadata, ...metadata}
            : record.metadata,
        updatedAt: DateTime.now(),
      );

      await _storeProcessingRecord(updatedRecord);

      _eventController.add(ProcessingAuditEvent.recordUpdated(updatedRecord));

      log('DataProcessingAuditLogger: Processing record updated: $recordId');
      return updatedRecord;
    } catch (e) {
      log('DataProcessingAuditLogger: Error updating processing record: $e');
      throw GDPRComplianceException('Failed to update processing record: $e');
    }
  }

  /// Get processing record by ID
  Future<DataProcessingRecord?> getProcessingRecord(String recordId) async {
    _ensureInitialized();
    return _processingCache[recordId];
  }

  /// Get all processing records for a user
  Future<List<DataProcessingRecord>> getUserProcessingRecords(
    String userId,
  ) async {
    _ensureInitialized();

    return _processingCache.values
        .where((record) => record.userId == userId)
        .toList();
  }

  /// Get all processing records
  Future<List<DataProcessingRecord>> getAllProcessingRecords() async {
    _ensureInitialized();
    return _processingCache.values.toList();
  }

  /// Get processing records by data category
  Future<List<DataProcessingRecord>> getProcessingRecordsByCategory(
    DataCategory category,
  ) async {
    _ensureInitialized();

    return _processingCache.values
        .where((record) => record.dataCategory == category)
        .toList();
  }

  /// Get processing records by purpose
  Future<List<DataProcessingRecord>> getProcessingRecordsByPurpose(
    ProcessingPurpose purpose,
  ) async {
    _ensureInitialized();

    return _processingCache.values
        .where((record) => record.purpose == purpose)
        .toList();
  }

  /// Get overdue retention data for a user
  Future<List<DataProcessingRecord>> getOverdueRetentionData(
    String userId,
  ) async {
    _ensureInitialized();

    return _processingCache.values
        .where((record) => record.userId == userId && record.isOverdue)
        .toList();
  }

  /// Get all overdue retention data
  Future<List<DataProcessingRecord>> getAllOverdueRetentionData() async {
    _ensureInitialized();

    return _processingCache.values.where((record) => record.isOverdue).toList();
  }

  /// Get records due for deletion within specified days
  Future<List<DataProcessingRecord>> getRecordsDueForDeletion(int days) async {
    _ensureInitialized();

    return _processingCache.values
        .where((record) => record.isDueSoonForDeletion(days))
        .toList();
  }

  /// Get high-risk processing records
  Future<List<DataProcessingRecord>> getHighRiskProcessingRecords() async {
    _ensureInitialized();

    return _processingCache.values
        .where((record) => record.complianceRiskLevel >= 2)
        .toList();
  }

  /// Get ongoing processing activities
  Future<List<DataProcessingRecord>> getOngoingProcessing() async {
    _ensureInitialized();

    return _processingCache.values.where((record) => record.isOngoing).toList();
  }

  /// Update retention policy for a data category
  Future<void> updateRetentionPolicy(
    DataCategory category,
    RetentionPeriod period,
  ) async {
    _ensureInitialized();

    try {
      _defaultRetentionPolicies[category] = period;
      await _saveRetentionPolicies();

      log(
        'DataProcessingAuditLogger: Retention policy updated for ${category.value}: ${period.value}',
      );

      _eventController.add(
        ProcessingAuditEvent.retentionPolicyUpdated(category, period),
      );
    } catch (e) {
      log('DataProcessingAuditLogger: Error updating retention policy: $e');
      throw GDPRComplianceException('Failed to update retention policy: $e');
    }
  }

  /// Get current retention policies
  Map<DataCategory, RetentionPeriod> getRetentionPolicies() {
    _ensureInitialized();
    return Map.from(_defaultRetentionPolicies);
  }

  /// Perform data cleanup based on retention policies
  Future<int> performDataCleanup() async {
    _ensureInitialized();

    try {
      log('DataProcessingAuditLogger: Starting data cleanup...');

      final overdueRecords = await getAllOverdueRetentionData();
      int cleanedCount = 0;

      for (final record in overdueRecords) {
        try {
          await _performRecordCleanup(record);
          cleanedCount++;

          _eventController.add(ProcessingAuditEvent.dataCleanedUp(record));
        } catch (e) {
          log(
            'DataProcessingAuditLogger: Error cleaning up record ${record.id}: $e',
          );
        }
      }

      log(
        'DataProcessingAuditLogger: Data cleanup completed. Cleaned $cleanedCount records.',
      );
      return cleanedCount;
    } catch (e) {
      log('DataProcessingAuditLogger: Error during data cleanup: $e');
      throw GDPRComplianceException('Failed to perform data cleanup: $e');
    }
  }

  /// Generate processing activity report
  Future<ProcessingActivityReport> generateActivityReport({
    String? userId,
    DataCategory? category,
    ProcessingPurpose? purpose,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _ensureInitialized();

    try {
      var records = _processingCache.values.toList();

      // Apply filters
      if (userId != null) {
        records = records.where((r) => r.userId == userId).toList();
      }
      if (category != null) {
        records = records.where((r) => r.dataCategory == category).toList();
      }
      if (purpose != null) {
        records = records.where((r) => r.purpose == purpose).toList();
      }
      if (startDate != null) {
        records = records.where((r) => r.startedAt.isAfter(startDate)).toList();
      }
      if (endDate != null) {
        records = records.where((r) => r.startedAt.isBefore(endDate)).toList();
      }

      return ProcessingActivityReport(
        reportId: 'report_${DateTime.now().millisecondsSinceEpoch}',
        generatedAt: DateTime.now(),
        filters: {
          if (userId != null) 'userId': userId,
          if (category != null) 'category': category.value,
          if (purpose != null) 'purpose': purpose.value,
          if (startDate != null) 'startDate': startDate.toIso8601String(),
          if (endDate != null) 'endDate': endDate.toIso8601String(),
        },
        totalRecords: records.length,
        ongoingActivities: records.where((r) => r.isOngoing).length,
        completedActivities: records.where((r) => r.isCompleted).length,
        highRiskActivities: records
            .where((r) => r.complianceRiskLevel >= 2)
            .length,
        overdueRetention: records.where((r) => r.isOverdue).length,
        records: records,
        categoryBreakdown: _generateCategoryBreakdown(records),
        purposeBreakdown: _generatePurposeBreakdown(records),
        legalBasisBreakdown: _generateLegalBasisBreakdown(records),
      );
    } catch (e) {
      log('DataProcessingAuditLogger: Error generating activity report: $e');
      throw GDPRComplianceException('Failed to generate activity report: $e');
    }
  }

  /// Clear all processing data for a user (for account deletion)
  Future<void> clearUserProcessingData(String userId) async {
    _ensureInitialized();

    try {
      final userRecords = await getUserProcessingRecords(userId);

      for (final record in userRecords) {
        _processingCache.remove(record.id);
      }

      await _saveProcessingRecords();

      log(
        'DataProcessingAuditLogger: Cleared all processing data for user $userId',
      );
    } catch (e) {
      log('DataProcessingAuditLogger: Error clearing user processing data: $e');
      throw GDPRComplianceException('Failed to clear user processing data: $e');
    }
  }

  /// Generate category breakdown for reports
  Map<String, int> _generateCategoryBreakdown(
    List<DataProcessingRecord> records,
  ) {
    final breakdown = <String, int>{};

    for (final record in records) {
      final category = record.dataCategory.value;
      breakdown[category] = (breakdown[category] ?? 0) + 1;
    }

    return breakdown;
  }

  /// Generate purpose breakdown for reports
  Map<String, int> _generatePurposeBreakdown(
    List<DataProcessingRecord> records,
  ) {
    final breakdown = <String, int>{};

    for (final record in records) {
      final purpose = record.purpose.value;
      breakdown[purpose] = (breakdown[purpose] ?? 0) + 1;
    }

    return breakdown;
  }

  /// Generate legal basis breakdown for reports
  Map<String, int> _generateLegalBasisBreakdown(
    List<DataProcessingRecord> records,
  ) {
    final breakdown = <String, int>{};

    for (final record in records) {
      final basis = record.legalBasis.value;
      breakdown[basis] = (breakdown[basis] ?? 0) + 1;
    }

    return breakdown;
  }

  /// Perform cleanup for a specific record
  Future<void> _performRecordCleanup(DataProcessingRecord record) async {
    // TODO: Implement actual data cleanup based on the processing record
    // This would involve:
    // - Deleting the actual data referenced by the record
    // - Anonymizing data that cannot be deleted
    // - Updating related systems

    log('DataProcessingAuditLogger: Cleaning up data for record: ${record.id}');

    // Remove the processing record itself
    _processingCache.remove(record.id);
    await _saveProcessingRecords();
  }

  /// Start periodic cleanup task
  void _startPeriodicCleanup() {
    // Run cleanup daily
    Timer.periodic(const Duration(days: 1), (timer) async {
      try {
        await performDataCleanup();
      } catch (e) {
        log('DataProcessingAuditLogger: Periodic cleanup failed: $e');
      }
    });
  }

  /// Load processing records from storage
  Future<void> _loadProcessingRecords() async {
    try {
      final storedData = _prefs!.getString(_auditLogStorageKey);
      if (storedData != null) {
        final Map<String, dynamic> data = jsonDecode(storedData);

        _processingCache.clear();
        data.forEach((recordId, recordJson) {
          final record = DataProcessingRecord.fromJson(
            recordJson as Map<String, dynamic>,
          );
          _processingCache[recordId] = record;
        });

        log(
          'DataProcessingAuditLogger: Loaded ${_processingCache.length} processing records',
        );
      }
    } catch (e) {
      log('DataProcessingAuditLogger: Error loading processing records: $e');
      _processingCache.clear();
    }
  }

  /// Save processing records to storage
  Future<void> _saveProcessingRecords() async {
    try {
      final Map<String, dynamic> data = {};
      _processingCache.forEach((recordId, record) {
        data[recordId] = record.toJson();
      });

      await _prefs!.setString(_auditLogStorageKey, jsonEncode(data));
    } catch (e) {
      log('DataProcessingAuditLogger: Error saving processing records: $e');
      throw GDPRComplianceException('Failed to save processing records: $e');
    }
  }

  /// Load retention policies from storage
  Future<void> _loadRetentionPolicies() async {
    try {
      final storedData = _prefs!.getString(_retentionPoliciesKey);
      if (storedData != null) {
        final Map<String, dynamic> data = jsonDecode(storedData);

        data.forEach((categoryStr, periodStr) {
          final category = DataCategory.fromString(categoryStr);
          final period = RetentionPeriod.fromString(periodStr);
          _defaultRetentionPolicies[category] = period;
        });

        log(
          'DataProcessingAuditLogger: Loaded ${_defaultRetentionPolicies.length} retention policies',
        );
      }
    } catch (e) {
      log('DataProcessingAuditLogger: Error loading retention policies: $e');
      // Use default policies if loading fails
    }
  }

  /// Save retention policies to storage
  Future<void> _saveRetentionPolicies() async {
    try {
      final Map<String, String> data = {};
      _defaultRetentionPolicies.forEach((category, period) {
        data[category.value] = period.value;
      });

      await _prefs!.setString(_retentionPoliciesKey, jsonEncode(data));
    } catch (e) {
      log('DataProcessingAuditLogger: Error saving retention policies: $e');
      throw GDPRComplianceException('Failed to save retention policies: $e');
    }
  }

  /// Store a processing record
  Future<void> _storeProcessingRecord(DataProcessingRecord record) async {
    try {
      _processingCache[record.id] = record;
      await _saveProcessingRecords();
    } catch (e) {
      log('DataProcessingAuditLogger: Error storing processing record: $e');
      throw GDPRComplianceException('Failed to store processing record: $e');
    }
  }

  /// Generate unique processing ID
  String _generateProcessingId(
    String userId,
    DataCategory category,
    ProcessingPurpose purpose,
  ) {
    return 'proc_${userId}_${category.value}_${purpose.value}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Ensure logger is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw GDPRComplianceException(
        'Data processing audit logger not initialized',
      );
    }
  }
}

/// Processing activity report
class ProcessingActivityReport {
  final String reportId;
  final DateTime generatedAt;
  final Map<String, dynamic> filters;
  final int totalRecords;
  final int ongoingActivities;
  final int completedActivities;
  final int highRiskActivities;
  final int overdueRetention;
  final List<DataProcessingRecord> records;
  final Map<String, int> categoryBreakdown;
  final Map<String, int> purposeBreakdown;
  final Map<String, int> legalBasisBreakdown;

  const ProcessingActivityReport({
    required this.reportId,
    required this.generatedAt,
    required this.filters,
    required this.totalRecords,
    required this.ongoingActivities,
    required this.completedActivities,
    required this.highRiskActivities,
    required this.overdueRetention,
    required this.records,
    required this.categoryBreakdown,
    required this.purposeBreakdown,
    required this.legalBasisBreakdown,
  });

  /// Get completion rate as percentage
  double get completionRate {
    if (totalRecords == 0) return 0.0;
    return (completedActivities / totalRecords) * 100;
  }

  /// Get high risk percentage
  double get highRiskPercentage {
    if (totalRecords == 0) return 0.0;
    return (highRiskActivities / totalRecords) * 100;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'reportId': reportId,
      'generatedAt': generatedAt.toIso8601String(),
      'filters': filters,
      'totalRecords': totalRecords,
      'ongoingActivities': ongoingActivities,
      'completedActivities': completedActivities,
      'highRiskActivities': highRiskActivities,
      'overdueRetention': overdueRetention,
      'completionRate': completionRate,
      'highRiskPercentage': highRiskPercentage,
      'categoryBreakdown': categoryBreakdown,
      'purposeBreakdown': purposeBreakdown,
      'legalBasisBreakdown': legalBasisBreakdown,
    };
  }
}

/// Processing audit event for notifications
class ProcessingAuditEvent {
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  const ProcessingAuditEvent({
    required this.type,
    required this.timestamp,
    this.data = const {},
  });

  factory ProcessingAuditEvent.processingStarted(DataProcessingRecord record) {
    return ProcessingAuditEvent(
      type: 'processing_started',
      timestamp: DateTime.now(),
      data: {
        'recordId': record.id,
        'userId': record.userId,
        'category': record.dataCategory.value,
        'purpose': record.purpose.value,
      },
    );
  }

  factory ProcessingAuditEvent.processingCompleted(
    DataProcessingRecord record,
  ) {
    return ProcessingAuditEvent(
      type: 'processing_completed',
      timestamp: DateTime.now(),
      data: {
        'recordId': record.id,
        'userId': record.userId,
        'duration': record.processingDuration.inMinutes,
      },
    );
  }

  factory ProcessingAuditEvent.recordUpdated(DataProcessingRecord record) {
    return ProcessingAuditEvent(
      type: 'record_updated',
      timestamp: DateTime.now(),
      data: {'recordId': record.id, 'userId': record.userId},
    );
  }

  factory ProcessingAuditEvent.dataCleanedUp(DataProcessingRecord record) {
    return ProcessingAuditEvent(
      type: 'data_cleaned_up',
      timestamp: DateTime.now(),
      data: {
        'recordId': record.id,
        'userId': record.userId,
        'category': record.dataCategory.value,
      },
    );
  }

  factory ProcessingAuditEvent.retentionPolicyUpdated(
    DataCategory category,
    RetentionPeriod period,
  ) {
    return ProcessingAuditEvent(
      type: 'retention_policy_updated',
      timestamp: DateTime.now(),
      data: {'category': category.value, 'retentionPeriod': period.value},
    );
  }
}
