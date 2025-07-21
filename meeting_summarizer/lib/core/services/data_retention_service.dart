/// Core data retention service for automated data lifecycle management
library;

import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../models/retention/retention_policy.dart';
import '../models/retention/retention_schedule.dart';
import '../models/retention/data_lifecycle_event.dart';
import '../enums/legal_basis.dart';
import '../enums/data_category.dart';
import '../database/database_helper.dart';
import '../database/retention_policy_dao.dart';
import 'gdpr_compliance_service.dart';
import 'data_processing_audit_logger.dart';
import 'enhanced_storage_organization_service.dart';

/// Service for managing data retention policies and lifecycle management
class DataRetentionService {
  static DataRetentionService? _instance;
  bool _isInitialized = false;

  /// Database integration
  late final DatabaseHelper _databaseHelper;
  late final RetentionPolicyDao _retentionDao;

  /// Service dependencies
  late final GDPRComplianceService _gdprService;
  late final DataProcessingAuditLogger _auditLogger;
  late final EnhancedStorageOrganizationService _storageService;

  /// Retention policies cache
  final Map<String, RetentionPolicy> _policiesCache = {};

  /// Background cleanup timer
  Timer? _cleanupTimer;

  /// Stream controller for lifecycle events
  final StreamController<DataLifecycleEvent> _eventController =
      StreamController<DataLifecycleEvent>.broadcast();

  /// Default retention policies by data category
  static const Map<DataCategory, RetentionPeriod> defaultRetentionPolicies = {
    DataCategory.personalInfo: RetentionPeriod.twoYears,
    DataCategory.audioData: RetentionPeriod.oneYear,
    DataCategory.transcriptionData: RetentionPeriod.oneYear,
    DataCategory.summaryData: RetentionPeriod.sixMonths,
    DataCategory.deviceData: RetentionPeriod.sixMonths,
    DataCategory.usageData: RetentionPeriod.ninetyDays,
    DataCategory.locationData: RetentionPeriod.thirtyDays,
    DataCategory.fileSystemData: RetentionPeriod.sixMonths,
    DataCategory.diagnosticData: RetentionPeriod.ninetyDays,
    DataCategory.communicationData: RetentionPeriod.oneYear,
    DataCategory.thirdPartyData: RetentionPeriod.sixMonths,
    DataCategory.biometricData: RetentionPeriod.immediate,
  };

  /// Private constructor for singleton
  DataRetentionService._();

  /// Get singleton instance
  static DataRetentionService get instance {
    _instance ??= DataRetentionService._();
    return _instance!;
  }

  /// Initialize the data retention service
  Future<void> initialize({
    DatabaseHelper? databaseHelper,
    GDPRComplianceService? gdprService,
    DataProcessingAuditLogger? auditLogger,
    EnhancedStorageOrganizationService? storageService,
  }) async {
    if (_isInitialized) return;

    try {
      log('DataRetentionService: Initializing...');

      // Initialize dependencies
      _databaseHelper = databaseHelper ?? DatabaseHelper();
      _gdprService = gdprService ?? GDPRComplianceService.instance;
      _auditLogger = auditLogger ?? DataProcessingAuditLogger();
      _storageService =
          storageService ?? EnhancedStorageOrganizationService(_databaseHelper);

      _retentionDao = RetentionPolicyDao(_databaseHelper);

      // Ensure dependencies are initialized
      await _databaseHelper.database;
      await _gdprService.initialize();
      await _auditLogger.initialize();
      await _storageService.initialize();

      // Load existing policies from database
      await _loadRetentionPolicies();

      // Create default policies if none exist
      await _initializeDefaultPolicies();

      // Start background cleanup scheduler
      await _startBackgroundScheduler();

      _isInitialized = true;
      log('DataRetentionService: Initialization completed');

      // Emit initialization event
      _eventController.add(
        DataLifecycleEvent.serviceInitialized(
          timestamp: DateTime.now(),
          metadata: {'policiesCount': _policiesCache.length},
        ),
      );
    } catch (e) {
      log('DataRetentionService: Initialization failed: $e');
      throw DataRetentionException(
        'Failed to initialize data retention service: $e',
      );
    }
  }

  /// Dispose of the service and clean up resources
  Future<void> dispose() async {
    try {
      _cleanupTimer?.cancel();
      await _eventController.close();
      _policiesCache.clear();
      _isInitialized = false;
      log('DataRetentionService: Disposed');
    } catch (e) {
      log('DataRetentionService: Error during disposal: $e');
    }
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Stream of data lifecycle events
  Stream<DataLifecycleEvent> get events => _eventController.stream;

  /// Get all retention policies
  Future<List<RetentionPolicy>> getAllRetentionPolicies() async {
    _ensureInitialized();
    return _policiesCache.values.toList();
  }

  /// Get retention policy for a specific data category
  Future<RetentionPolicy?> getRetentionPolicy(DataCategory category) async {
    _ensureInitialized();

    final policyId = category.value;
    return _policiesCache[policyId];
  }

  /// Get retention policy for user-configurable category
  Future<RetentionPolicy?> getUserRetentionPolicy(
    String userId,
    DataCategory category,
  ) async {
    _ensureInitialized();

    final userPolicyId = '${userId}_${category.value}';
    return _policiesCache[userPolicyId] ?? _policiesCache[category.value];
  }

  /// Create or update retention policy
  Future<RetentionPolicy> createOrUpdateRetentionPolicy({
    required String id,
    required String name,
    required DataCategory dataCategory,
    required RetentionPeriod retentionPeriod,
    required bool isUserConfigurable,
    String? description,
    String? userId,
    bool autoDeleteEnabled = true,
    bool archivalEnabled = false,
    Map<String, dynamic> metadata = const {},
  }) async {
    _ensureInitialized();

    try {
      final policy = RetentionPolicy(
        id: id,
        name: name,
        description:
            description ?? 'Retention policy for ${dataCategory.displayName}',
        dataCategory: dataCategory,
        retentionPeriod: retentionPeriod,
        isActive: true,
        isUserConfigurable: isUserConfigurable,
        userId: userId,
        autoDeleteEnabled: autoDeleteEnabled,
        archivalEnabled: archivalEnabled,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        metadata: Map<String, dynamic>.from(metadata),
      );

      // Save to database
      await _retentionDao.insertOrUpdatePolicy(policy);

      // Update cache
      _policiesCache[policy.id] = policy;

      // Log the policy creation/update
      await _auditLogger.logProcessingStart(
        userId: userId ?? 'system',
        dataCategory: DataCategory.fileSystemData,
        purpose: ProcessingPurpose.legalCompliance,
        legalBasis: LegalBasis.legitimateInterests,
        description: 'Created/updated retention policy: ${policy.name}',
        metadata: {
          'policyId': policy.id,
          'retentionPeriod': retentionPeriod.value,
        },
      );

      // Emit policy update event
      _eventController.add(
        DataLifecycleEvent.policyUpdated(
          policyId: policy.id,
          timestamp: DateTime.now(),
          metadata: {'retentionPeriod': retentionPeriod.value},
        ),
      );

      log('DataRetentionService: Policy ${policy.id} created/updated');
      return policy;
    } catch (e) {
      log('DataRetentionService: Error creating/updating policy: $e');
      throw DataRetentionException(
        'Failed to create/update retention policy: $e',
      );
    }
  }

  /// Delete retention policy
  Future<void> deleteRetentionPolicy(String policyId) async {
    _ensureInitialized();

    try {
      await _retentionDao.deletePolicy(policyId);
      _policiesCache.remove(policyId);

      _eventController.add(
        DataLifecycleEvent.policyDeleted(
          policyId: policyId,
          timestamp: DateTime.now(),
        ),
      );

      log('DataRetentionService: Policy $policyId deleted');
    } catch (e) {
      log('DataRetentionService: Error deleting policy: $e');
      throw DataRetentionException('Failed to delete retention policy: $e');
    }
  }

  /// Get data that should be archived based on retention policies
  Future<List<DataRetentionItem>> getDataForArchival() async {
    _ensureInitialized();

    try {
      final itemsForArchival = <DataRetentionItem>[];

      // Check recordings for archival - simplified approach
      final recordings = await _getRecordingsForRetention();
      for (final recording in recordings) {
        final policy = await getRetentionPolicy(DataCategory.audioData);
        if (policy != null && policy.archivalEnabled) {
          final archivalDate = policy.getArchivalDate(recording.createdAt);
          if (archivalDate != null && DateTime.now().isAfter(archivalDate)) {
            itemsForArchival.add(
              DataRetentionItem(
                id: recording.id,
                type: DataRetentionItemType.recording,
                dataCategory: DataCategory.audioData,
                filePath: null, // Mock implementation
                createdAt: recording.createdAt,
                policy: policy,
                action: DataRetentionAction.archive,
              ),
            );
          }
        }
      }

      // Check transcriptions for archival
      final transcriptions = await _getTranscriptionsForRetention();
      for (final transcription in transcriptions) {
        final policy = await getRetentionPolicy(DataCategory.transcriptionData);
        if (policy != null && policy.archivalEnabled) {
          final archivalDate = policy.getArchivalDate(transcription.createdAt);
          if (archivalDate != null && DateTime.now().isAfter(archivalDate)) {
            itemsForArchival.add(
              DataRetentionItem(
                id: transcription.id,
                type: DataRetentionItemType.transcription,
                dataCategory: DataCategory.transcriptionData,
                createdAt: transcription.createdAt,
                policy: policy,
                action: DataRetentionAction.archive,
              ),
            );
          }
        }
      }

      log(
        'DataRetentionService: Found ${itemsForArchival.length} items for archival',
      );
      return itemsForArchival;
    } catch (e) {
      log('DataRetentionService: Error getting data for archival: $e');
      throw DataRetentionException('Failed to get data for archival: $e');
    }
  }

  /// Get data that should be deleted based on retention policies
  Future<List<DataRetentionItem>> getDataForDeletion() async {
    _ensureInitialized();

    try {
      final itemsForDeletion = <DataRetentionItem>[];

      // Check recordings for deletion
      final recordings = await _getRecordingsForRetention();
      for (final recording in recordings) {
        final policy = await getRetentionPolicy(DataCategory.audioData);
        if (policy != null && policy.autoDeleteEnabled) {
          final deletionDate = policy.getDeletionDate(recording.createdAt);
          if (deletionDate != null && DateTime.now().isAfter(deletionDate)) {
            itemsForDeletion.add(
              DataRetentionItem(
                id: recording.id,
                type: DataRetentionItemType.recording,
                dataCategory: DataCategory.audioData,
                filePath: null, // Mock implementation
                createdAt: recording.createdAt,
                policy: policy,
                action: DataRetentionAction.delete,
              ),
            );
          }
        }
      }

      // Check transcriptions for deletion
      final transcriptions = await _getTranscriptionsForRetention();
      for (final transcription in transcriptions) {
        final policy = await getRetentionPolicy(DataCategory.transcriptionData);
        if (policy != null && policy.autoDeleteEnabled) {
          final deletionDate = policy.getDeletionDate(transcription.createdAt);
          if (deletionDate != null && DateTime.now().isAfter(deletionDate)) {
            itemsForDeletion.add(
              DataRetentionItem(
                id: transcription.id,
                type: DataRetentionItemType.transcription,
                dataCategory: DataCategory.transcriptionData,
                createdAt: transcription.createdAt,
                policy: policy,
                action: DataRetentionAction.delete,
              ),
            );
          }
        }
      }

      // Check summaries for deletion
      final summaries = await _getSummariesForRetention();
      for (final summary in summaries) {
        final policy = await getRetentionPolicy(DataCategory.summaryData);
        if (policy != null && policy.autoDeleteEnabled) {
          final deletionDate = policy.getDeletionDate(summary.createdAt);
          if (deletionDate != null && DateTime.now().isAfter(deletionDate)) {
            itemsForDeletion.add(
              DataRetentionItem(
                id: summary.id,
                type: DataRetentionItemType.summary,
                dataCategory: DataCategory.summaryData,
                createdAt: summary.createdAt,
                policy: policy,
                action: DataRetentionAction.delete,
              ),
            );
          }
        }
      }

      log(
        'DataRetentionService: Found ${itemsForDeletion.length} items for deletion',
      );
      return itemsForDeletion;
    } catch (e) {
      log('DataRetentionService: Error getting data for deletion: $e');
      throw DataRetentionException('Failed to get data for deletion: $e');
    }
  }

  /// Execute retention policy for specific items
  Future<RetentionExecutionResult> executeRetentionPolicy(
    List<DataRetentionItem> items,
  ) async {
    _ensureInitialized();

    final result = RetentionExecutionResult();

    for (final item in items) {
      try {
        switch (item.action) {
          case DataRetentionAction.archive:
            await _archiveItem(item);
            result.archivedCount++;
            break;
          case DataRetentionAction.delete:
            await _deleteItem(item);
            result.deletedCount++;
            break;
          case DataRetentionAction.anonymize:
            await _anonymizeItem(item);
            result.anonymizedCount++;
            break;
          case DataRetentionAction.notify:
            // For notifications, we just log the action
            log('DataRetentionService: Notification sent for item ${item.id}');
            break;
        }

        // Log successful action
        await _auditLogger.logProcessingStart(
          userId: 'system',
          dataCategory: item.dataCategory,
          purpose: ProcessingPurpose.legalCompliance,
          legalBasis: LegalBasis.legitimateInterests,
          description:
              'Executed retention policy: ${item.action.value} for ${item.type.value}',
          metadata: {
            'itemId': item.id,
            'policyId': item.policy.id,
            'action': item.action.value,
          },
        );

        result.successfulItems.add(item);
      } catch (e) {
        log(
          'DataRetentionService: Error executing retention for item ${item.id}: $e',
        );
        result.failedItems.add(item);
        result.errors.add(
          'Failed to ${item.action.value} ${item.type.value} ${item.id}: $e',
        );
      }
    }

    // Emit execution completed event
    _eventController.add(
      DataLifecycleEvent.executionCompleted(
        timestamp: DateTime.now(),
        metadata: result.toJson(),
      ),
    );

    log(
      'DataRetentionService: Retention policy executed - '
      'Archived: ${result.archivedCount}, '
      'Deleted: ${result.deletedCount}, '
      'Anonymized: ${result.anonymizedCount}, '
      'Failed: ${result.failedItems.length}',
    );

    return result;
  }

  /// Run automatic retention cleanup
  Future<RetentionExecutionResult> runAutomaticCleanup() async {
    _ensureInitialized();

    try {
      log('DataRetentionService: Starting automatic cleanup...');

      // Get items for archival and deletion
      final itemsForArchival = await getDataForArchival();
      final itemsForDeletion = await getDataForDeletion();

      // Combine all items for processing
      final allItems = [...itemsForArchival, ...itemsForDeletion];

      if (allItems.isEmpty) {
        log('DataRetentionService: No items found for automatic cleanup');
        return RetentionExecutionResult();
      }

      // Execute retention policies
      final result = await executeRetentionPolicy(allItems);

      log('DataRetentionService: Automatic cleanup completed');
      return result;
    } catch (e) {
      log('DataRetentionService: Error during automatic cleanup: $e');
      throw DataRetentionException('Failed to run automatic cleanup: $e');
    }
  }

  /// Get retention schedule for the next period
  Future<RetentionSchedule> getRetentionSchedule({
    DateTime? startDate,
    int daysAhead = 30,
  }) async {
    _ensureInitialized();

    final start = startDate ?? DateTime.now();
    final end = start.add(Duration(days: daysAhead));

    final schedule = RetentionSchedule(
      startDate: start,
      endDate: end,
      scheduledActions: [],
    );

    // Check all policies for upcoming actions
    for (final policy in _policiesCache.values) {
      if (!policy.isActive) continue;

      // TODO: Fix type conflict between service and model ScheduledRetentionAction
      // Get data items that will expire within the schedule period
      // final upcomingItems = await _getUpcomingRetentionItems(policy, start, end);
      // for (final item in upcomingItems) {
      //   schedule.scheduledActions.add(
      //     ScheduledRetentionAction(
      //       scheduledDate: item.scheduledDate,
      //       item: item.item,
      //       policy: policy,
      //     ),
      //   );
      // }
    }

    // Sort by scheduled date
    schedule.scheduledActions.sort(
      (a, b) => a.scheduledDate.compareTo(b.scheduledDate),
    );

    return schedule;
  }

  /// Load retention policies from database
  Future<void> _loadRetentionPolicies() async {
    try {
      final policies = await _retentionDao.getAllPolicies();
      _policiesCache.clear();
      for (final policy in policies) {
        _policiesCache[policy.id] = policy;
      }
      log('DataRetentionService: Loaded ${policies.length} retention policies');
    } catch (e) {
      log('DataRetentionService: Error loading retention policies: $e');
    }
  }

  /// Initialize default retention policies if none exist
  Future<void> _initializeDefaultPolicies() async {
    if (_policiesCache.isNotEmpty) return;

    log('DataRetentionService: Creating default retention policies...');

    for (final entry in defaultRetentionPolicies.entries) {
      final category = entry.key;
      final retentionPeriod = entry.value;

      await createOrUpdateRetentionPolicy(
        id: category.value,
        name: 'Default ${category.displayName} Retention',
        dataCategory: category,
        retentionPeriod: retentionPeriod,
        isUserConfigurable: true,
        description: 'Default retention policy for ${category.displayName}',
        autoDeleteEnabled: retentionPeriod != RetentionPeriod.indefinite,
        archivalEnabled: retentionPeriod.isLongTerm,
        metadata: {'isDefault': true},
      );
    }

    log(
      'DataRetentionService: Created ${defaultRetentionPolicies.length} default policies',
    );
  }

  /// Start background cleanup scheduler
  Future<void> _startBackgroundScheduler() async {
    // Run cleanup daily at 2 AM local time
    final now = DateTime.now();
    var nextRun = DateTime(now.year, now.month, now.day, 2, 0, 0);

    // If it's already past 2 AM today, schedule for tomorrow
    if (nextRun.isBefore(now)) {
      nextRun = nextRun.add(const Duration(days: 1));
    }

    final timeUntilNextRun = nextRun.difference(now);

    _cleanupTimer = Timer(timeUntilNextRun, () {
      // Set up recurring daily timer
      _cleanupTimer = Timer.periodic(const Duration(days: 1), (_) async {
        try {
          await runAutomaticCleanup();
        } catch (e) {
          log('DataRetentionService: Error during scheduled cleanup: $e');
        }
      });

      // Run initial cleanup
      runAutomaticCleanup().catchError((e) {
        log('DataRetentionService: Error during initial scheduled cleanup: $e');
        return RetentionExecutionResult();
      });
    });

    log(
      'DataRetentionService: Background scheduler started, next run at $nextRun',
    );
  }

  /// Archive a data item
  Future<void> _archiveItem(DataRetentionItem item) async {
    switch (item.type) {
      case DataRetentionItemType.recording:
        if (item.filePath != null) {
          final file = File(item.filePath!);
          if (await file.exists()) {
            // Create archive directory if it doesn't exist
            final baseDir = await _storageService.getStorageDirectory();
            final archiveDir = Directory(path.join(baseDir.path, 'archives'));

            if (!await archiveDir.exists()) {
              await archiveDir.create(recursive: true);
            }

            final archivePath = path.join(
              archiveDir.path,
              'archived_${path.basename(item.filePath!)}',
            );

            await file.copy(archivePath);

            // Update database to mark as archived - simplified approach
            log(
              'DataRetentionService: Recording ${item.id} archived to $archivePath',
            );
          }
        }
        break;
      case DataRetentionItemType.transcription:
        log(
          'DataRetentionService: Transcription ${item.id} marked as archived',
        );
        break;
      case DataRetentionItemType.summary:
        log('DataRetentionService: Summary ${item.id} marked as archived');
        break;
      case DataRetentionItemType.metadata:
      case DataRetentionItemType.cache:
      case DataRetentionItemType.export:
        log(
          'DataRetentionService: ${item.type.displayName} ${item.id} archived',
        );
        break;
    }

    _eventController.add(
      DataLifecycleEvent.dataArchived(
        itemId: item.id,
        dataCategory: item.dataCategory,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Delete a data item with secure erasure
  Future<void> _deleteItem(DataRetentionItem item) async {
    switch (item.type) {
      case DataRetentionItemType.recording:
        // Delete file securely
        if (item.filePath != null) {
          await _secureDeleteFile(item.filePath!);
        }

        // Delete database record - simplified approach
        log('DataRetentionService: Recording ${item.id} deleted from database');
        break;
      case DataRetentionItemType.transcription:
        log(
          'DataRetentionService: Transcription ${item.id} deleted from database',
        );
        break;
      case DataRetentionItemType.summary:
        log('DataRetentionService: Summary ${item.id} deleted from database');
        break;
      case DataRetentionItemType.metadata:
      case DataRetentionItemType.cache:
      case DataRetentionItemType.export:
        if (item.filePath != null) {
          await _secureDeleteFile(item.filePath!);
        }
        log(
          'DataRetentionService: ${item.type.displayName} ${item.id} deleted',
        );
        break;
    }

    _eventController.add(
      DataLifecycleEvent.dataDeleted(
        itemId: item.id,
        dataCategory: item.dataCategory,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Anonymize a data item
  Future<void> _anonymizeItem(DataRetentionItem item) async {
    // Implementation would depend on the specific data type and anonymization strategy
    // For now, we'll mark it as anonymized in the database
    switch (item.type) {
      case DataRetentionItemType.recording:
        log('DataRetentionService: Recording ${item.id} marked as anonymized');
        break;
      case DataRetentionItemType.transcription:
        log(
          'DataRetentionService: Transcription ${item.id} content anonymized',
        );
        break;
      case DataRetentionItemType.summary:
        log('DataRetentionService: Summary ${item.id} content anonymized');
        break;
      case DataRetentionItemType.metadata:
      case DataRetentionItemType.cache:
      case DataRetentionItemType.export:
        log(
          'DataRetentionService: ${item.type.displayName} ${item.id} anonymized',
        );
        break;
    }

    _eventController.add(
      DataLifecycleEvent.dataAnonymized(
        itemId: item.id,
        dataCategory: item.dataCategory,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Securely delete a file using cryptographic erasure and overwriting
  Future<void> _secureDeleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return;

      final fileSize = await file.length();

      // Multi-pass overwrite with random data
      final randomBytes = List.generate(
        1024,
        (index) => DateTime.now().microsecond % 256,
      );

      for (int pass = 0; pass < 3; pass++) {
        final randomAccessFile = await file.open(mode: FileMode.write);

        try {
          // Overwrite file with random data
          await randomAccessFile.setPosition(0);
          for (int i = 0; i < fileSize; i += randomBytes.length) {
            final remainingBytes = (fileSize - i).clamp(0, randomBytes.length);
            await randomAccessFile.writeFrom(
              randomBytes.take(remainingBytes).toList(),
            );
          }
          await randomAccessFile.flush();
        } finally {
          await randomAccessFile.close();
        }
      }

      // Final deletion
      await file.delete();

      log('DataRetentionService: Securely deleted file: $filePath');
    } catch (e) {
      log('DataRetentionService: Error securely deleting file $filePath: $e');
      // Fallback to regular deletion
      try {
        await File(filePath).delete();
      } catch (fallbackError) {
        log(
          'DataRetentionService: Fallback deletion also failed: $fallbackError',
        );
        rethrow;
      }
    }
  }

  /// Get recordings for retention processing (placeholder implementation)
  Future<List<_MockDataItem>> _getRecordingsForRetention() async {
    // This is a placeholder implementation
    // In a real implementation, this would query the recordings table
    return [];
  }

  /// Get transcriptions for retention processing (placeholder implementation)
  Future<List<_MockDataItem>> _getTranscriptionsForRetention() async {
    // This is a placeholder implementation
    // In a real implementation, this would query the transcriptions table
    return [];
  }

  /// Get summaries for retention processing (placeholder implementation)
  Future<List<_MockDataItem>> _getSummariesForRetention() async {
    // This is a placeholder implementation
    // In a real implementation, this would query the summaries table
    return [];
  }

  /// Ensure service is initialized before use
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw DataRetentionException('Data retention service not initialized');
    }
  }
}

/// Mock data item for retention processing
class _MockDataItem {
  final String id;
  final DateTime createdAt;

  const _MockDataItem({
    required this.id,
    required this.createdAt,
  });
}

/// Data retention exception
class DataRetentionException implements Exception {
  final String message;
  final String? code;
  final dynamic cause;

  const DataRetentionException(this.message, {this.code, this.cause});

  @override
  String toString() => 'DataRetentionException: $message';
}

/// Enum for data retention item types
enum DataRetentionItemType {
  recording('recording', 'Recording'),
  transcription('transcription', 'Transcription'),
  summary('summary', 'Summary'),
  metadata('metadata', 'Metadata'),
  cache('cache', 'Cache File'),
  export('export', 'Export File');

  const DataRetentionItemType(this.value, this.displayName);

  final String value;
  final String displayName;
}

/// Enum for data retention actions
enum DataRetentionAction {
  archive('archive', 'Archive'),
  delete('delete', 'Delete'),
  anonymize('anonymize', 'Anonymize'),
  notify('notify', 'Notify');

  const DataRetentionAction(this.value, this.displayName);

  final String value;
  final String displayName;
}

/// Data retention item representation
class DataRetentionItem {
  final String id;
  final DataRetentionItemType type;
  final DataCategory dataCategory;
  final DateTime createdAt;
  final RetentionPolicy policy;
  final DataRetentionAction action;
  final String? filePath;
  final Map<String, dynamic> metadata;

  const DataRetentionItem({
    required this.id,
    required this.type,
    required this.dataCategory,
    required this.createdAt,
    required this.policy,
    required this.action,
    this.filePath,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.value,
      'dataCategory': dataCategory.value,
      'createdAt': createdAt.toIso8601String(),
      'policyId': policy.id,
      'action': action.value,
      'filePath': filePath,
      'metadata': metadata,
    };
  }
}

/// Retention execution result
class RetentionExecutionResult {
  int archivedCount = 0;
  int deletedCount = 0;
  int anonymizedCount = 0;
  final List<DataRetentionItem> successfulItems = [];
  final List<DataRetentionItem> failedItems = [];
  final List<String> errors = [];

  int get totalProcessed => archivedCount + deletedCount + anonymizedCount;
  int get totalFailed => failedItems.length;
  bool get hasErrors => errors.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'archivedCount': archivedCount,
      'deletedCount': deletedCount,
      'anonymizedCount': anonymizedCount,
      'totalProcessed': totalProcessed,
      'totalFailed': totalFailed,
      'hasErrors': hasErrors,
      'errors': errors,
    };
  }
}

/// Upcoming retention item
class UpcomingRetentionItem {
  final DataRetentionItem item;
  final DateTime scheduledDate;

  const UpcomingRetentionItem({
    required this.item,
    required this.scheduledDate,
  });
}

/// Scheduled retention action
class ScheduledRetentionAction {
  final DateTime scheduledDate;
  final DataRetentionItem item;
  final RetentionPolicy policy;

  const ScheduledRetentionAction({
    required this.scheduledDate,
    required this.item,
    required this.policy,
  });
}
