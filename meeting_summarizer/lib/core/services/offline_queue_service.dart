import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/cloud_sync/sync_operation.dart';
import 'network_connectivity_service.dart';

/// Service for managing offline operations queue with persistent storage
class OfflineQueueService {
  static OfflineQueueService? _instance;
  static OfflineQueueService get instance =>
      _instance ??= OfflineQueueService._();
  OfflineQueueService._();

  Database? _database;
  bool _isInitialized = false;
  final StreamController<QueueStatusUpdate> _statusController =
      StreamController<QueueStatusUpdate>.broadcast();
  Timer? _processingTimer;

  /// Stream of queue status updates
  Stream<QueueStatusUpdate> get statusStream => _statusController.stream;

  /// Initialize the offline queue service and database
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log('OfflineQueueService: Initializing...');

      await _initializeDatabase();
      await _cleanupExpiredOperations();
      _startBackgroundProcessing();

      _isInitialized = true;
      log('OfflineQueueService: Initialization completed');
    } catch (e, stackTrace) {
      log(
        'OfflineQueueService: Initialization failed: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Initialize the SQLite database for queue persistence
  Future<void> _initializeDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databasePath = path.join(documentsDirectory.path, 'offline_queue.db');

    _database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE queue_operations (
            id TEXT PRIMARY KEY,
            operation_type TEXT NOT NULL,
            provider_id TEXT NOT NULL,
            local_file_path TEXT NOT NULL,
            remote_file_path TEXT NOT NULL,
            priority INTEGER NOT NULL DEFAULT 0,
            retry_count INTEGER NOT NULL DEFAULT 0,
            max_retries INTEGER NOT NULL DEFAULT 3,
            created_at INTEGER NOT NULL,
            scheduled_at INTEGER NOT NULL,
            last_attempted_at INTEGER,
            error_message TEXT,
            metadata TEXT,
            status TEXT NOT NULL DEFAULT 'pending'
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_queue_status ON queue_operations(status);
        ''');

        await db.execute('''
          CREATE INDEX idx_queue_priority ON queue_operations(priority DESC, created_at ASC);
        ''');

        await db.execute('''
          CREATE INDEX idx_queue_scheduled ON queue_operations(scheduled_at);
        ''');

        log('OfflineQueueService: Database tables created');
      },
    );

    log('OfflineQueueService: Database initialized at $databasePath');
  }

  /// Add a sync operation to the offline queue
  Future<bool> enqueueOperation({
    required SyncOperation operation,
    int priority = 0,
    int maxRetries = 3,
    Duration? delay,
  }) async {
    if (!_isInitialized) {
      throw StateError('OfflineQueueService not initialized');
    }

    try {
      final now = DateTime.now();
      final scheduledAt = delay != null ? now.add(delay) : now;

      final queuedOperation = QueuedOperation(
        id: operation.id,
        operationType: operation.type,
        providerId: operation.provider.id,
        localFilePath: operation.localFilePath,
        remoteFilePath: operation.remoteFilePath,
        priority: priority,
        retryCount: 0,
        maxRetries: maxRetries,
        createdAt: now,
        scheduledAt: scheduledAt,
        metadata: operation.toJson(),
        status: QueueOperationStatus.pending,
      );

      await _database!.insert(
        'queue_operations',
        queuedOperation.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      log(
        'OfflineQueueService: Enqueued operation ${operation.id} (priority: $priority)',
      );

      _statusController.add(
        QueueStatusUpdate(
          operationId: operation.id,
          status: QueueOperationStatus.pending,
          message: 'Operation queued for offline processing',
        ),
      );

      return true;
    } catch (e, stackTrace) {
      log(
        'OfflineQueueService: Failed to enqueue operation: $e',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Remove an operation from the queue
  Future<bool> dequeueOperation(String operationId) async {
    if (!_isInitialized) return false;

    try {
      final result = await _database!.delete(
        'queue_operations',
        where: 'id = ?',
        whereArgs: [operationId],
      );

      if (result > 0) {
        log('OfflineQueueService: Dequeued operation $operationId');
        _statusController.add(
          QueueStatusUpdate(
            operationId: operationId,
            status: QueueOperationStatus.completed,
            message: 'Operation completed and removed from queue',
          ),
        );
        return true;
      }

      return false;
    } catch (e) {
      log('OfflineQueueService: Failed to dequeue operation $operationId: $e');
      return false;
    }
  }

  /// Get all pending operations sorted by priority and creation time
  Future<List<QueuedOperation>> getPendingOperations() async {
    if (!_isInitialized) return [];

    try {
      final result = await _database!.query(
        'queue_operations',
        where: 'status = ? AND scheduled_at <= ?',
        whereArgs: [
          QueueOperationStatus.pending.name,
          DateTime.now().millisecondsSinceEpoch,
        ],
        orderBy: 'priority DESC, created_at ASC',
      );

      return result.map((row) => QueuedOperation.fromJson(row)).toList();
    } catch (e) {
      log('OfflineQueueService: Failed to get pending operations: $e');
      return [];
    }
  }

  /// Get operations by status
  Future<List<QueuedOperation>> getOperationsByStatus(
    QueueOperationStatus status,
  ) async {
    if (!_isInitialized) return [];

    try {
      final result = await _database!.query(
        'queue_operations',
        where: 'status = ?',
        whereArgs: [status.name],
        orderBy: 'priority DESC, created_at ASC',
      );

      return result.map((row) => QueuedOperation.fromJson(row)).toList();
    } catch (e) {
      log(
        'OfflineQueueService: Failed to get operations by status $status: $e',
      );
      return [];
    }
  }

  /// Update operation status and retry information
  Future<void> updateOperationStatus({
    required String operationId,
    required QueueOperationStatus status,
    String? errorMessage,
    bool incrementRetry = false,
  }) async {
    if (!_isInitialized) return;

    try {
      final updates = <String, dynamic>{
        'status': status.name,
        'last_attempted_at': DateTime.now().millisecondsSinceEpoch,
      };

      if (errorMessage != null) {
        updates['error_message'] = errorMessage;
      }

      if (incrementRetry) {
        final current = await _database!.query(
          'queue_operations',
          columns: ['retry_count'],
          where: 'id = ?',
          whereArgs: [operationId],
        );

        if (current.isNotEmpty) {
          final retryCount = (current.first['retry_count'] as int) + 1;
          updates['retry_count'] = retryCount;
        }
      }

      await _database!.update(
        'queue_operations',
        updates,
        where: 'id = ?',
        whereArgs: [operationId],
      );

      _statusController.add(
        QueueStatusUpdate(
          operationId: operationId,
          status: status,
          message: errorMessage ?? 'Status updated to ${status.name}',
        ),
      );

      log(
        'OfflineQueueService: Updated operation $operationId status to ${status.name}',
      );
    } catch (e) {
      log('OfflineQueueService: Failed to update operation status: $e');
    }
  }

  /// Get queue statistics
  Future<QueueStatistics> getQueueStatistics() async {
    if (!_isInitialized) {
      return const QueueStatistics(
        totalOperations: 0,
        pendingOperations: 0,
        processingOperations: 0,
        failedOperations: 0,
        completedOperations: 0,
        retryingOperations: 0,
      );
    }

    try {
      final results = await Future.wait([
        _getCountByStatus(QueueOperationStatus.pending),
        _getCountByStatus(QueueOperationStatus.processing),
        _getCountByStatus(QueueOperationStatus.failed),
        _getCountByStatus(QueueOperationStatus.completed),
        _getCountByStatus(QueueOperationStatus.retrying),
      ]);

      final total = results.fold<int>(0, (sum, count) => sum + count);

      return QueueStatistics(
        totalOperations: total,
        pendingOperations: results[0],
        processingOperations: results[1],
        failedOperations: results[2],
        completedOperations: results[3],
        retryingOperations: results[4],
      );
    } catch (e) {
      log('OfflineQueueService: Failed to get queue statistics: $e');
      return const QueueStatistics(
        totalOperations: 0,
        pendingOperations: 0,
        processingOperations: 0,
        failedOperations: 0,
        completedOperations: 0,
        retryingOperations: 0,
      );
    }
  }

  /// Get count of operations by status
  Future<int> _getCountByStatus(QueueOperationStatus status) async {
    final result = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM queue_operations WHERE status = ?',
      [status.name],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clean up expired and old completed operations
  Future<void> _cleanupExpiredOperations() async {
    if (!_isInitialized) return;

    try {
      final now = DateTime.now();
      final expiredThreshold = now.subtract(const Duration(days: 7));

      // Remove completed operations older than 7 days
      await _database!.delete(
        'queue_operations',
        where: 'status = ? AND last_attempted_at < ?',
        whereArgs: [
          QueueOperationStatus.completed.name,
          expiredThreshold.millisecondsSinceEpoch,
        ],
      );

      // Remove failed operations older than 30 days
      final failedThreshold = now.subtract(const Duration(days: 30));
      await _database!.delete(
        'queue_operations',
        where: 'status = ? AND last_attempted_at < ?',
        whereArgs: [
          QueueOperationStatus.failed.name,
          failedThreshold.millisecondsSinceEpoch,
        ],
      );

      log('OfflineQueueService: Cleanup completed');
    } catch (e) {
      log('OfflineQueueService: Cleanup failed: $e');
    }
  }

  /// Start background processing of queued operations
  void _startBackgroundProcessing() {
    _processingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _processQueuedOperations(),
    );
    log('OfflineQueueService: Background processing started');
  }

  /// Process queued operations when connectivity is available
  Future<void> _processQueuedOperations() async {
    try {
      // Check if we have internet connectivity
      final connectivityService = NetworkConnectivityService.instance;
      if (!await connectivityService.isConnected) {
        return;
      }

      final pendingOperations = await getPendingOperations();
      if (pendingOperations.isEmpty) {
        return;
      }

      log(
        'OfflineQueueService: Processing ${pendingOperations.length} pending operations',
      );

      for (final operation in pendingOperations.take(5)) {
        // Process max 5 at a time
        await _processOperation(operation);
      }
    } catch (e) {
      log('OfflineQueueService: Error processing queued operations: $e');
    }
  }

  /// Process a single queued operation
  Future<void> _processOperation(QueuedOperation queuedOp) async {
    try {
      await updateOperationStatus(
        operationId: queuedOp.id,
        status: QueueOperationStatus.processing,
      );

      // TODO: Process the operation through the appropriate service
      // This would integrate with CloudSyncService or DeltaSyncService
      // For now, we reconstruct the operation from metadata and simulate processing

      // For now, simulate processing
      await Future.delayed(const Duration(milliseconds: 500));

      // Simulate success for demonstration
      await updateOperationStatus(
        operationId: queuedOp.id,
        status: QueueOperationStatus.completed,
      );

      // Remove completed operation from queue
      await dequeueOperation(queuedOp.id);

      log(
        'OfflineQueueService: Successfully processed operation ${queuedOp.id}',
      );
    } catch (e) {
      log(
        'OfflineQueueService: Failed to process operation ${queuedOp.id}: $e',
      );

      // Check if we should retry
      if (queuedOp.retryCount < queuedOp.maxRetries) {
        await updateOperationStatus(
          operationId: queuedOp.id,
          status: QueueOperationStatus.retrying,
          errorMessage: e.toString(),
          incrementRetry: true,
        );

        // Schedule retry with exponential backoff
        final retryDelay = Duration(
          milliseconds:
              (1000 * (queuedOp.retryCount + 1) * (queuedOp.retryCount + 1))
                  .toInt(),
        );

        await _database!.update(
          'queue_operations',
          {
            'scheduled_at': DateTime.now()
                .add(retryDelay)
                .millisecondsSinceEpoch,
            'status': QueueOperationStatus.pending.name,
          },
          where: 'id = ?',
          whereArgs: [queuedOp.id],
        );
      } else {
        await updateOperationStatus(
          operationId: queuedOp.id,
          status: QueueOperationStatus.failed,
          errorMessage: 'Max retries exceeded: ${e.toString()}',
        );
      }
    }
  }

  /// Get operations by priority level
  Future<List<QueuedOperation>> getOperationsByPriority(int priority) async {
    if (!_isInitialized) return [];

    try {
      final result = await _database!.query(
        'queue_operations',
        where: 'priority = ?',
        whereArgs: [priority],
        orderBy: 'created_at ASC',
      );

      return result.map((row) => QueuedOperation.fromJson(row)).toList();
    } catch (e) {
      log(
        'OfflineQueueService: Failed to get operations by priority $priority: $e',
      );
      return [];
    }
  }

  /// Get high priority operations (priority >= 2)
  Future<List<QueuedOperation>> getHighPriorityOperations() async {
    if (!_isInitialized) return [];

    try {
      final result = await _database!.query(
        'queue_operations',
        where: 'priority >= ? AND status = ?',
        whereArgs: [2, QueueOperationStatus.pending.name],
        orderBy: 'priority DESC, created_at ASC',
      );

      return result.map((row) => QueuedOperation.fromJson(row)).toList();
    } catch (e) {
      log('OfflineQueueService: Failed to get high priority operations: $e');
      return [];
    }
  }

  /// Update operation priority
  Future<bool> updateOperationPriority({
    required String operationId,
    required int newPriority,
  }) async {
    if (!_isInitialized) return false;

    try {
      final result = await _database!.update(
        'queue_operations',
        {'priority': newPriority},
        where: 'id = ?',
        whereArgs: [operationId],
      );

      if (result > 0) {
        log(
          'OfflineQueueService: Updated operation $operationId priority to $newPriority',
        );

        _statusController.add(
          QueueStatusUpdate(
            operationId: operationId,
            status: QueueOperationStatus.pending, // Assuming it's still pending
            message: 'Priority updated to $newPriority',
          ),
        );

        return true;
      }
      return false;
    } catch (e) {
      log('OfflineQueueService: Failed to update operation priority: $e');
      return false;
    }
  }

  /// Promote operation to high priority
  Future<bool> promoteToHighPriority(String operationId) async {
    return await updateOperationPriority(
      operationId: operationId,
      newPriority: 3, // Critical priority
    );
  }

  /// Demote operation to low priority
  Future<bool> demoteToLowPriority(String operationId) async {
    return await updateOperationPriority(
      operationId: operationId,
      newPriority: 0, // Low priority
    );
  }

  /// Get priority statistics
  Future<PriorityStatistics> getPriorityStatistics() async {
    if (!_isInitialized) {
      return const PriorityStatistics(
        criticalCount: 0,
        highCount: 0,
        normalCount: 0,
        lowCount: 0,
      );
    }

    try {
      final results = await Future.wait([
        _getCountByPriority(3), // Critical
        _getCountByPriority(2), // High
        _getCountByPriority(1), // Normal
        _getCountByPriority(0), // Low
      ]);

      return PriorityStatistics(
        criticalCount: results[0],
        highCount: results[1],
        normalCount: results[2],
        lowCount: results[3],
      );
    } catch (e) {
      log('OfflineQueueService: Failed to get priority statistics: $e');
      return const PriorityStatistics(
        criticalCount: 0,
        highCount: 0,
        normalCount: 0,
        lowCount: 0,
      );
    }
  }

  /// Get count of operations by priority
  Future<int> _getCountByPriority(int priority) async {
    final result = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM queue_operations WHERE priority = ? AND status = ?',
      [priority, QueueOperationStatus.pending.name],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Process operations by priority order (critical first)
  Future<List<QueuedOperation>> getPendingOperationsByPriorityOrder() async {
    if (!_isInitialized) return [];

    try {
      // Get operations in strict priority order with time-based tiebreaker
      final result = await _database!.query(
        'queue_operations',
        where: 'status = ? AND scheduled_at <= ?',
        whereArgs: [
          QueueOperationStatus.pending.name,
          DateTime.now().millisecondsSinceEpoch,
        ],
        orderBy: 'priority DESC, created_at ASC',
      );

      return result.map((row) => QueuedOperation.fromJson(row)).toList();
    } catch (e) {
      log(
        'OfflineQueueService: Failed to get operations by priority order: $e',
      );
      return [];
    }
  }

  /// Clear all operations from the queue
  Future<void> clearQueue() async {
    if (!_isInitialized) return;

    try {
      await _database!.delete('queue_operations');
      log('OfflineQueueService: Queue cleared');
    } catch (e) {
      log('OfflineQueueService: Failed to clear queue: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _processingTimer?.cancel();
    await _statusController.close();
    await _database?.close();
    _isInitialized = false;
    log('OfflineQueueService: Disposed');
  }
}

/// Represents a queued operation with persistence metadata
class QueuedOperation {
  final String id;
  final SyncOperationType operationType;
  final String providerId;
  final String localFilePath;
  final String remoteFilePath;
  final int priority;
  final int retryCount;
  final int maxRetries;
  final DateTime createdAt;
  final DateTime scheduledAt;
  final DateTime? lastAttemptedAt;
  final String? errorMessage;
  final Map<String, dynamic> metadata;
  final QueueOperationStatus status;

  const QueuedOperation({
    required this.id,
    required this.operationType,
    required this.providerId,
    required this.localFilePath,
    required this.remoteFilePath,
    required this.priority,
    required this.retryCount,
    required this.maxRetries,
    required this.createdAt,
    required this.scheduledAt,
    this.lastAttemptedAt,
    this.errorMessage,
    required this.metadata,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operation_type': operationType.name,
      'provider_id': providerId,
      'local_file_path': localFilePath,
      'remote_file_path': remoteFilePath,
      'priority': priority,
      'retry_count': retryCount,
      'max_retries': maxRetries,
      'created_at': createdAt.millisecondsSinceEpoch,
      'scheduled_at': scheduledAt.millisecondsSinceEpoch,
      'last_attempted_at': lastAttemptedAt?.millisecondsSinceEpoch,
      'error_message': errorMessage,
      'metadata': jsonEncode(metadata),
      'status': status.name,
    };
  }

  factory QueuedOperation.fromJson(Map<String, dynamic> json) {
    return QueuedOperation(
      id: json['id'] as String,
      operationType: SyncOperationType.values.firstWhere(
        (type) => type.name == json['operation_type'],
      ),
      providerId: json['provider_id'] as String,
      localFilePath: json['local_file_path'] as String,
      remoteFilePath: json['remote_file_path'] as String,
      priority: json['priority'] as int,
      retryCount: json['retry_count'] as int,
      maxRetries: json['max_retries'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      scheduledAt: DateTime.fromMillisecondsSinceEpoch(
        json['scheduled_at'] as int,
      ),
      lastAttemptedAt: json['last_attempted_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              json['last_attempted_at'] as int,
            )
          : null,
      errorMessage: json['error_message'] as String?,
      metadata: jsonDecode(json['metadata'] as String) as Map<String, dynamic>,
      status: QueueOperationStatus.values.firstWhere(
        (status) => status.name == json['status'],
      ),
    );
  }

  @override
  String toString() {
    return 'QueuedOperation(id: $id, type: $operationType, status: $status, '
        'priority: $priority, retries: $retryCount/$maxRetries)';
  }
}

/// Status of a queued operation
enum QueueOperationStatus { pending, processing, completed, failed, retrying }

/// Update about queue operation status
class QueueStatusUpdate {
  final String operationId;
  final QueueOperationStatus status;
  final String message;
  final DateTime timestamp;

  QueueStatusUpdate({
    required this.operationId,
    required this.status,
    required this.message,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return 'QueueStatusUpdate(id: $operationId, status: $status, message: $message)';
  }
}

/// Statistics about the offline queue
class QueueStatistics {
  final int totalOperations;
  final int pendingOperations;
  final int processingOperations;
  final int failedOperations;
  final int completedOperations;
  final int retryingOperations;

  const QueueStatistics({
    required this.totalOperations,
    required this.pendingOperations,
    required this.processingOperations,
    required this.failedOperations,
    required this.completedOperations,
    required this.retryingOperations,
  });

  /// Get the percentage of operations that are pending
  double get pendingPercentage {
    if (totalOperations == 0) return 0.0;
    return (pendingOperations / totalOperations) * 100;
  }

  /// Get the percentage of operations that have failed
  double get failureRate {
    if (totalOperations == 0) return 0.0;
    return (failedOperations / totalOperations) * 100;
  }

  /// Get the percentage of operations that completed successfully
  double get successRate {
    if (totalOperations == 0) return 0.0;
    return (completedOperations / totalOperations) * 100;
  }

  @override
  String toString() {
    return 'QueueStatistics(total: $totalOperations, pending: $pendingOperations, '
        'processing: $processingOperations, failed: $failedOperations, '
        'completed: $completedOperations, retrying: $retryingOperations)';
  }
}

/// Statistics about operation priorities in the queue
class PriorityStatistics {
  final int criticalCount; // Priority 3
  final int highCount; // Priority 2
  final int normalCount; // Priority 1
  final int lowCount; // Priority 0

  const PriorityStatistics({
    required this.criticalCount,
    required this.highCount,
    required this.normalCount,
    required this.lowCount,
  });

  /// Get total number of operations across all priorities
  int get totalOperations => criticalCount + highCount + normalCount + lowCount;

  /// Get the percentage of high priority operations (critical + high)
  double get highPriorityPercentage {
    if (totalOperations == 0) return 0.0;
    return ((criticalCount + highCount) / totalOperations) * 100;
  }

  /// Get the distribution as a map
  Map<String, int> get distributionMap => {
    'Critical': criticalCount,
    'High': highCount,
    'Normal': normalCount,
    'Low': lowCount,
  };

  @override
  String toString() {
    return 'PriorityStatistics(critical: $criticalCount, high: $highCount, '
        'normal: $normalCount, low: $lowCount)';
  }
}
