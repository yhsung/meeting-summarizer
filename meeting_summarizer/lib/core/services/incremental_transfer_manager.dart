import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';

import '../models/cloud_sync/cloud_provider.dart';
import '../models/cloud_sync/file_change.dart';
import 'change_tracking_service.dart';
import 'cloud_providers/cloud_provider_interface.dart';
import 'delta_sync_service.dart';

/// Manages incremental file transfers with bandwidth optimization and resumption
class IncrementalTransferManager {
  static IncrementalTransferManager? _instance;
  static IncrementalTransferManager get instance =>
      _instance ??= IncrementalTransferManager._();
  IncrementalTransferManager._();

  static const int _maxConcurrentTransfers = 3;
  static const int _maxRetryAttempts = 3;
  static const Duration _retryBackoffDuration = Duration(seconds: 5);

  final Map<String, TransferOperation> _activeTransfers = {};
  final StreamController<TransferProgress> _progressController =
      StreamController<TransferProgress>.broadcast();
  final StreamController<TransferEvent> _eventController =
      StreamController<TransferEvent>.broadcast();

  bool _isPaused = false;
  int _maxBandwidthBytesPerSecond = 0; // 0 = unlimited

  /// Stream of transfer progress updates
  Stream<TransferProgress> get progressStream => _progressController.stream;

  /// Stream of transfer events (start, complete, error, etc.)
  Stream<TransferEvent> get eventStream => _eventController.stream;

  /// Initialize the transfer manager
  Future<void> initialize() async {
    try {
      dev.log('IncrementalTransferManager: Initializing...');

      // Initialize dependent services
      await ChangeTrackingService.instance.initialize();

      dev.log('IncrementalTransferManager: Initialization complete');
    } catch (e, stackTrace) {
      dev.log(
        'IncrementalTransferManager: Initialization failed: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Start incremental sync for a specific file
  Future<TransferResult> syncFile({
    required String filePath,
    required CloudProvider provider,
    required CloudProviderInterface providerInterface,
    required SyncDirection direction,
    bool forceFullSync = false,
    Function(TransferProgress progress)? onProgress,
  }) async {
    final transferId = _generateTransferId(filePath, provider, direction);

    try {
      dev.log(
        'IncrementalTransferManager: Starting sync for $filePath '
        '(${direction.name})',
      );

      // Check if transfer is already active
      if (_activeTransfers.containsKey(transferId)) {
        return TransferResult(
          success: false,
          error: 'Transfer already in progress',
          transferId: transferId,
        );
      }

      // Check concurrent transfer limit
      if (_activeTransfers.length >= _maxConcurrentTransfers) {
        return TransferResult(
          success: false,
          error: 'Maximum concurrent transfers reached',
          transferId: transferId,
        );
      }

      // Detect file changes
      final fileChange = await ChangeTrackingService.instance.detectFileChange(
        filePath: filePath,
        provider: provider,
        providerInterface: providerInterface,
      );

      if (fileChange == null && !forceFullSync) {
        dev.log(
          'IncrementalTransferManager: No changes detected for $filePath',
        );
        return TransferResult(
          success: true,
          message: 'No changes detected',
          transferId: transferId,
          bytesTransferred: 0,
        );
      }

      // Create transfer operation
      final transferOp = TransferOperation(
        id: transferId,
        filePath: filePath,
        provider: provider,
        direction: direction,
        fileChange: fileChange,
        status: TransferStatus.queued,
        createdAt: DateTime.now(),
      );

      _activeTransfers[transferId] = transferOp;

      // Emit transfer started event
      _eventController.add(
        TransferEvent(
          type: TransferEventType.started,
          transferId: transferId,
          filePath: filePath,
          provider: provider,
        ),
      );

      // Perform the actual transfer
      final result = await _performTransfer(
        transferOp,
        providerInterface,
        onProgress,
      );

      // Clean up
      _activeTransfers.remove(transferId);

      // Emit completion event
      _eventController.add(
        TransferEvent(
          type: result.success
              ? TransferEventType.completed
              : TransferEventType.failed,
          transferId: transferId,
          filePath: filePath,
          provider: provider,
          error: result.error,
        ),
      );

      return result;
    } catch (e, stackTrace) {
      dev.log(
        'IncrementalTransferManager: Error syncing file $filePath: $e',
        stackTrace: stackTrace,
      );

      _activeTransfers.remove(transferId);

      _eventController.add(
        TransferEvent(
          type: TransferEventType.failed,
          transferId: transferId,
          filePath: filePath,
          provider: provider,
          error: e.toString(),
        ),
      );

      return TransferResult(
        success: false,
        error: e.toString(),
        transferId: transferId,
      );
    }
  }

  /// Sync multiple files in batch
  Future<List<TransferResult>> syncFiles({
    required List<String> filePaths,
    required CloudProvider provider,
    required CloudProviderInterface providerInterface,
    required SyncDirection direction,
    bool forceFullSync = false,
    Function(String filePath, TransferProgress progress)? onProgress,
  }) async {
    final results = <TransferResult>[];

    try {
      dev.log(
        'IncrementalTransferManager: Starting batch sync for '
        '${filePaths.length} files',
      );

      // Process files in chunks to respect concurrent transfer limit
      final chunks = <List<String>>[];
      for (int i = 0; i < filePaths.length; i += _maxConcurrentTransfers) {
        chunks.add(
          filePaths.sublist(
            i,
            min(i + _maxConcurrentTransfers, filePaths.length),
          ),
        );
      }

      for (final chunk in chunks) {
        final futures = chunk.map(
          (filePath) => syncFile(
            filePath: filePath,
            provider: provider,
            providerInterface: providerInterface,
            direction: direction,
            forceFullSync: forceFullSync,
            onProgress: onProgress != null
                ? (progress) => onProgress(filePath, progress)
                : null,
          ),
        );

        final chunkResults = await Future.wait(futures);
        results.addAll(chunkResults);

        // Brief pause between chunks to prevent overwhelming the system
        if (chunks.indexOf(chunk) < chunks.length - 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      dev.log(
        'IncrementalTransferManager: Batch sync completed. '
        'Success: ${results.where((r) => r.success).length}/${results.length}',
      );

      return results;
    } catch (e, stackTrace) {
      dev.log(
        'IncrementalTransferManager: Error in batch sync: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Resume a paused transfer
  Future<TransferResult> resumeTransfer(String transferId) async {
    final transferOp = _activeTransfers[transferId];
    if (transferOp == null) {
      return TransferResult(
        success: false,
        error: 'Transfer not found',
        transferId: transferId,
      );
    }

    if (transferOp.status != TransferStatus.paused) {
      return TransferResult(
        success: false,
        error: 'Transfer is not paused',
        transferId: transferId,
      );
    }

    dev.log('IncrementalTransferManager: Resuming transfer $transferId');

    // Update status and continue
    _activeTransfers[transferId] = transferOp.copyWith(
      status: TransferStatus.running,
      resumedAt: DateTime.now(),
    );

    return TransferResult(
      success: true,
      message: 'Transfer resumed',
      transferId: transferId,
    );
  }

  /// Pause a running transfer
  Future<bool> pauseTransfer(String transferId) async {
    final transferOp = _activeTransfers[transferId];
    if (transferOp == null || transferOp.status != TransferStatus.running) {
      return false;
    }

    dev.log('IncrementalTransferManager: Pausing transfer $transferId');

    _activeTransfers[transferId] = transferOp.copyWith(
      status: TransferStatus.paused,
      pausedAt: DateTime.now(),
    );

    return true;
  }

  /// Cancel a transfer
  Future<bool> cancelTransfer(String transferId) async {
    final transferOp = _activeTransfers[transferId];
    if (transferOp == null) {
      return false;
    }

    dev.log('IncrementalTransferManager: Cancelling transfer $transferId');

    _activeTransfers.remove(transferId);

    _eventController.add(
      TransferEvent(
        type: TransferEventType.cancelled,
        transferId: transferId,
        filePath: transferOp.filePath,
        provider: transferOp.provider,
      ),
    );

    return true;
  }

  /// Set bandwidth limit in bytes per second (0 = unlimited)
  void setBandwidthLimit(int bytesPerSecond) {
    _maxBandwidthBytesPerSecond = bytesPerSecond;
    dev.log(
      'IncrementalTransferManager: Bandwidth limit set to '
      '${bytesPerSecond == 0 ? 'unlimited' : '${bytesPerSecond ~/ 1024} KB/s'}',
    );
  }

  /// Pause all transfers
  Future<void> pauseAll() async {
    _isPaused = true;
    dev.log('IncrementalTransferManager: All transfers paused');
  }

  /// Resume all transfers
  Future<void> resumeAll() async {
    _isPaused = false;
    dev.log('IncrementalTransferManager: All transfers resumed');
  }

  /// Get active transfer operations
  List<TransferOperation> getActiveTransfers() {
    return _activeTransfers.values.toList();
  }

  /// Get transfer statistics
  TransferStats getStats() {
    final active = _activeTransfers.values.toList();
    final totalBytes = active.fold<int>(
      0,
      (sum, op) => sum + (op.fileChange?.fileSize ?? 0),
    );
    final transferredBytes = active.fold<int>(
      0,
      (sum, op) => sum + op.bytesTransferred,
    );

    return TransferStats(
      activeTransfers: active.length,
      totalBytes: totalBytes,
      transferredBytes: transferredBytes,
      averageSpeed: _calculateAverageSpeed(active),
      estimatedTimeRemaining: _calculateETA(active),
    );
  }

  /// Perform the actual file transfer with retry dev.logic
  Future<TransferResult> _performTransfer(
    TransferOperation transferOp,
    CloudProviderInterface providerInterface,
    Function(TransferProgress progress)? onProgress,
  ) async {
    final stopwatch = Stopwatch()..start();
    int retryCount = 0;

    while (retryCount <= _maxRetryAttempts) {
      try {
        // Update status
        _activeTransfers[transferOp.id] = transferOp.copyWith(
          status: TransferStatus.running,
          startedAt: DateTime.now(),
          retryCount: retryCount,
        );

        // Check if paused
        while (_isPaused) {
          await Future.delayed(const Duration(milliseconds: 500));
        }

        // Perform delta sync
        final deltaResult = await DeltaSyncService.instance.performDeltaSync(
          fileChange: transferOp.fileChange!,
          providerInterface: providerInterface,
          direction: transferOp.direction,
          onProgress: (progress) {
            final transferProgress = TransferProgress(
              transferId: transferOp.id,
              filePath: transferOp.filePath,
              provider: transferOp.provider,
              direction: transferOp.direction,
              progressPercentage: progress * 100,
              bytesTransferred: (transferOp.fileChange!.changeSize * progress)
                  .round(),
              totalBytes: transferOp.fileChange!.changeSize,
              transferSpeed: _calculateTransferSpeed(transferOp),
              estimatedTimeRemaining: _calculateETA([transferOp]),
            );

            _progressController.add(transferProgress);
            onProgress?.call(transferProgress);

            // Update operation with progress
            _activeTransfers[transferOp.id] = transferOp.copyWith(
              bytesTransferred: transferProgress.bytesTransferred,
              progressPercentage: progress * 100,
            );

            // Apply bandwidth limiting
            _applyBandwidthLimit();
          },
        );

        if (deltaResult.success) {
          // Record successful sync in change tracking
          await ChangeTrackingService.instance.recordFileState(
            filePath: transferOp.filePath,
            provider: transferOp.provider,
            modificationTime: transferOp.fileChange!.lastModified,
            checksum: transferOp.fileChange!.checksum ?? '',
            fileSize: transferOp.fileChange!.fileSize,
          );

          return TransferResult(
            success: true,
            transferId: transferOp.id,
            bytesTransferred: deltaResult.bytesTransferred,
            transferTime: stopwatch.elapsed,
            syncedChunks: deltaResult.syncedChunks,
          );
        } else {
          throw Exception(deltaResult.error ?? 'Delta sync failed');
        }
      } catch (e) {
        retryCount++;
        dev.log(
          'IncrementalTransferManager: Transfer attempt $retryCount failed: $e',
        );

        if (retryCount <= _maxRetryAttempts) {
          await Future.delayed(_retryBackoffDuration * retryCount);
        } else {
          return TransferResult(
            success: false,
            error: e.toString(),
            transferId: transferOp.id,
            transferTime: stopwatch.elapsed,
          );
        }
      }
    }

    return TransferResult(
      success: false,
      error: 'Max retry attempts exceeded',
      transferId: transferOp.id,
      transferTime: stopwatch.elapsed,
    );
  }

  /// Apply bandwidth limiting by adding delays
  Future<void> _applyBandwidthLimit() async {
    if (_maxBandwidthBytesPerSecond <= 0) return;

    // Simple bandwidth limiting - more sophisticated implementations
    // would track actual transfer rates over time
    final delayMs = 1000 ~/ (_maxBandwidthBytesPerSecond / 1024);
    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }
  }

  /// Calculate average transfer speed across active operations
  double _calculateAverageSpeed(List<TransferOperation> operations) {
    if (operations.isEmpty) return 0.0;

    final totalSpeed = operations.fold<double>(
      0.0,
      (sum, op) => sum + _calculateTransferSpeed(op),
    );

    return totalSpeed / operations.length;
  }

  /// Calculate transfer speed for a single operation
  double _calculateTransferSpeed(TransferOperation operation) {
    if (operation.startedAt == null) return 0.0;

    final duration = DateTime.now().difference(operation.startedAt!);
    if (duration.inMilliseconds == 0) return 0.0;

    return operation.bytesTransferred / (duration.inMilliseconds / 1000.0);
  }

  /// Calculate estimated time remaining for operations
  Duration? _calculateETA(List<TransferOperation> operations) {
    if (operations.isEmpty) return null;

    final totalRemainingBytes = operations.fold<int>(
      0,
      (sum, op) =>
          sum + ((op.fileChange?.changeSize ?? 0) - op.bytesTransferred),
    );

    final avgSpeed = _calculateAverageSpeed(operations);
    if (avgSpeed <= 0) return null;

    final etaSeconds = totalRemainingBytes / avgSpeed;
    return Duration(seconds: etaSeconds.round());
  }

  /// Generate unique transfer ID
  String _generateTransferId(
    String filePath,
    CloudProvider provider,
    SyncDirection direction,
  ) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final hash =
        '${filePath}_${provider.id}_${direction.name}_$timestamp'.hashCode;
    return 'transfer_${hash.abs()}';
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _progressController.close();
    await _eventController.close();
    _activeTransfers.clear();
  }
}

/// Represents an active transfer operation
class TransferOperation {
  final String id;
  final String filePath;
  final CloudProvider provider;
  final SyncDirection direction;
  final FileChange? fileChange;
  final TransferStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? pausedAt;
  final DateTime? resumedAt;
  final double progressPercentage;
  final int bytesTransferred;
  final int retryCount;

  const TransferOperation({
    required this.id,
    required this.filePath,
    required this.provider,
    required this.direction,
    this.fileChange,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.pausedAt,
    this.resumedAt,
    this.progressPercentage = 0.0,
    this.bytesTransferred = 0,
    this.retryCount = 0,
  });

  TransferOperation copyWith({
    String? id,
    String? filePath,
    CloudProvider? provider,
    SyncDirection? direction,
    FileChange? fileChange,
    TransferStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? pausedAt,
    DateTime? resumedAt,
    double? progressPercentage,
    int? bytesTransferred,
    int? retryCount,
  }) {
    return TransferOperation(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      provider: provider ?? this.provider,
      direction: direction ?? this.direction,
      fileChange: fileChange ?? this.fileChange,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      pausedAt: pausedAt ?? this.pausedAt,
      resumedAt: resumedAt ?? this.resumedAt,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  @override
  String toString() {
    return 'TransferOperation(id: $id, filePath: $filePath, status: $status)';
  }
}

/// Status of a transfer operation
enum TransferStatus { queued, running, paused, completed, failed, cancelled }

/// Progress information for a transfer
class TransferProgress {
  final String transferId;
  final String filePath;
  final CloudProvider provider;
  final SyncDirection direction;
  final double progressPercentage;
  final int bytesTransferred;
  final int totalBytes;
  final double transferSpeed;
  final Duration? estimatedTimeRemaining;

  const TransferProgress({
    required this.transferId,
    required this.filePath,
    required this.provider,
    required this.direction,
    required this.progressPercentage,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.transferSpeed,
    this.estimatedTimeRemaining,
  });

  String get formattedSpeed {
    if (transferSpeed < 1024) return '${transferSpeed.toStringAsFixed(0)} B/s';
    if (transferSpeed < 1024 * 1024) {
      return '${(transferSpeed / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(transferSpeed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String get formattedETA {
    if (estimatedTimeRemaining == null) return 'Unknown';
    final eta = estimatedTimeRemaining!;
    if (eta.inMinutes < 1) return '${eta.inSeconds}s';
    if (eta.inHours < 1) return '${eta.inMinutes}m ${eta.inSeconds % 60}s';
    return '${eta.inHours}h ${eta.inMinutes % 60}m';
  }

  @override
  String toString() {
    return 'TransferProgress(${progressPercentage.toStringAsFixed(1)}% - $formattedSpeed)';
  }
}

/// Transfer event information
class TransferEvent {
  final TransferEventType type;
  final String transferId;
  final String filePath;
  final CloudProvider provider;
  final String? error;
  final DateTime timestamp;

  TransferEvent({
    required this.type,
    required this.transferId,
    required this.filePath,
    required this.provider,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'TransferEvent(type: $type, transferId: $transferId, filePath: $filePath)';
  }
}

/// Types of transfer events
enum TransferEventType {
  started,
  completed,
  failed,
  cancelled,
  paused,
  resumed,
}

/// Result of a transfer operation
class TransferResult {
  final bool success;
  final String? error;
  final String? message;
  final String transferId;
  final int bytesTransferred;
  final Duration? transferTime;
  final int syncedChunks;

  const TransferResult({
    required this.success,
    this.error,
    this.message,
    required this.transferId,
    this.bytesTransferred = 0,
    this.transferTime,
    this.syncedChunks = 0,
  });

  @override
  String toString() {
    return 'TransferResult(success: $success, transferId: $transferId, '
        'bytes: $bytesTransferred)';
  }
}

/// Transfer statistics
class TransferStats {
  final int activeTransfers;
  final int totalBytes;
  final int transferredBytes;
  final double averageSpeed;
  final Duration? estimatedTimeRemaining;

  const TransferStats({
    required this.activeTransfers,
    required this.totalBytes,
    required this.transferredBytes,
    required this.averageSpeed,
    this.estimatedTimeRemaining,
  });

  double get progressPercentage {
    if (totalBytes == 0) return 0.0;
    return (transferredBytes / totalBytes) * 100;
  }

  String get formattedAverageSpeed {
    if (averageSpeed < 1024) return '${averageSpeed.toStringAsFixed(0)} B/s';
    if (averageSpeed < 1024 * 1024) {
      return '${(averageSpeed / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(averageSpeed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  @override
  String toString() {
    return 'TransferStats(active: $activeTransfers, progress: '
        '${progressPercentage.toStringAsFixed(1)}%, speed: $formattedAverageSpeed)';
  }
}
