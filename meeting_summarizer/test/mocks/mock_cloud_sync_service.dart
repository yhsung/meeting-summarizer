import 'dart:async';
import 'dart:math' as math;
import 'dart:developer';

import 'package:meeting_summarizer/core/interfaces/cloud_sync_interface.dart';
import 'package:meeting_summarizer/core/models/cloud_sync/cloud_provider.dart';
import 'package:meeting_summarizer/core/models/cloud_sync/sync_status.dart';
import 'package:meeting_summarizer/core/models/cloud_sync/sync_operation.dart';
import 'package:meeting_summarizer/core/models/cloud_sync/sync_conflict.dart'
    as conflict_models;

/// Comprehensive mock cloud sync service for testing
///
/// Provides simulation of cloud synchronization operations including
/// uploads, downloads, conflict resolution, and multi-provider management.
class MockCloudSyncService implements CloudSyncInterface {
  // Mock behavior configuration
  bool _shouldFailOperations = false;
  bool _shouldFailInitialization = false;
  bool _shouldSimulateConflicts = false;
  bool _shouldSimulateNetworkIssues = false;
  Duration _mockOperationDelay = const Duration(milliseconds: 200);
  double _mockUploadProgress = 0.0;
  double _mockDownloadProgress = 0.0;
  bool _isInitialized = false;

  // Mock state
  final Set<CloudProvider> _enabledProviders = {};
  final Map<String, SyncOperation> _activeSyncOperations = {};
  final List<conflict_models.SyncConflict> _pendingConflicts = [];
  SyncStatus _globalSyncStatus = SyncStatus.idle;
  int _operationCounter = 0;

  // Mock statistics
  int _totalUploads = 0;
  int _totalDownloads = 0;
  int _successfulOperations = 0;
  int _failedOperations = 0;
  int _conflictsResolved = 0;

  // Streams
  final StreamController<SyncStatus> _syncStatusController =
      StreamController<SyncStatus>.broadcast();
  final StreamController<SyncOperation> _operationController =
      StreamController<SyncOperation>.broadcast();
  final StreamController<conflict_models.SyncConflict> _conflictController =
      StreamController<conflict_models.SyncConflict>.broadcast();

  @override
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  @override
  Stream<SyncOperation> get operationStream => _operationController.stream;

  @override
  Stream<conflict_models.SyncConflict> get conflictStream =>
      _conflictController.stream;

  // Mock configuration methods

  /// Configure mock to simulate operation failures
  void setMockOperationFailure(bool shouldFail) {
    _shouldFailOperations = shouldFail;
  }

  /// Configure mock to simulate initialization failures
  void setMockInitializationFailure(bool shouldFail) {
    _shouldFailInitialization = shouldFail;
  }

  /// Configure mock to simulate sync conflicts
  void setMockConflictSimulation(bool shouldSimulate) {
    _shouldSimulateConflicts = shouldSimulate;
  }

  /// Configure mock to simulate network issues
  void setMockNetworkIssues(bool shouldSimulate) {
    _shouldSimulateNetworkIssues = shouldSimulate;
  }

  /// Set mock operation delay for testing timing scenarios
  void setMockOperationDelay(Duration delay) {
    _mockOperationDelay = delay;
  }

  /// Set mock progress values for testing progress tracking
  void setMockProgress({double? upload, double? download}) {
    if (upload != null)
      _mockUploadProgress = math.max(0.0, math.min(1.0, upload));
    if (download != null)
      _mockDownloadProgress = math.max(0.0, math.min(1.0, download));
  }

  /// Reset all mock state to defaults
  void resetMockState() {
    _shouldFailOperations = false;
    _shouldFailInitialization = false;
    _shouldSimulateConflicts = false;
    _shouldSimulateNetworkIssues = false;
    _mockOperationDelay = const Duration(milliseconds: 200);
    _mockUploadProgress = 0.0;
    _mockDownloadProgress = 0.0;
    _enabledProviders.clear();
    _activeSyncOperations.clear();
    _pendingConflicts.clear();
    _globalSyncStatus = SyncStatus.idle;
    _operationCounter = 0;
    _totalUploads = 0;
    _totalDownloads = 0;
    _successfulOperations = 0;
    _failedOperations = 0;
    _conflictsResolved = 0;
  }

  @override
  Future<void> initialize() async {
    if (_shouldFailInitialization) {
      throw Exception('Mock cloud sync initialization failure');
    }

    await Future.delayed(_mockOperationDelay);
    _isInitialized = true;
    _updateSyncStatus(SyncStatus.idle);
    log('MockCloudSyncService: Initialized successfully');
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    await _syncStatusController.close();
    await _operationController.close();
    await _conflictController.close();
    log('MockCloudSyncService: Disposed');
  }

  @override
  Future<void> enableProvider(CloudProvider provider) async {
    await _simulateOperation();

    _enabledProviders.add(provider);
    log('MockCloudSyncService: Enabled provider $provider');
  }

  @override
  Future<void> disableProvider(CloudProvider provider) async {
    await _simulateOperation();

    _enabledProviders.remove(provider);
    log('MockCloudSyncService: Disabled provider $provider');
  }

  @override
  Future<List<CloudProvider>> getEnabledProviders() async {
    await _simulateOperation();
    return _enabledProviders.toList();
  }

  @override
  Future<bool> isProviderConnected(CloudProvider provider) async {
    await _simulateOperation();
    // Mock: providers are connected if they're enabled and not failing
    return _enabledProviders.contains(provider) && !_shouldFailOperations;
  }

  @override
  Future<SyncOperation> uploadFile({
    required String localPath,
    required String remotePath,
    CloudProvider? preferredProvider,
  }) async {
    await _simulateOperation();

    _totalUploads++;
    final operationId = 'upload_${_operationCounter++}';

    final operation = SyncOperation(
      id: operationId,
      type: SyncOperationType.upload,
      localPath: localPath,
      remotePath: remotePath,
      provider: preferredProvider ?? _enabledProviders.first,
      status: SyncOperationStatus.inProgress,
      progress: 0.0,
      startTime: DateTime.now(),
    );

    _activeSyncOperations[operationId] = operation;
    _operationController.add(operation);
    _updateSyncStatus(SyncStatus.syncing);

    // Simulate upload progress
    _simulateProgressUpdate(operation, _mockUploadProgress);

    log(
      'MockCloudSyncService: Started upload $operationId: $localPath -> $remotePath',
    );
    return operation;
  }

  @override
  Future<SyncOperation> downloadFile({
    required String remotePath,
    required String localPath,
    CloudProvider? provider,
  }) async {
    await _simulateOperation();

    _totalDownloads++;
    final operationId = 'download_${_operationCounter++}';

    final operation = SyncOperation(
      id: operationId,
      type: SyncOperationType.download,
      localPath: localPath,
      remotePath: remotePath,
      provider: provider ?? _enabledProviders.first,
      status: SyncOperationStatus.inProgress,
      progress: 0.0,
      startTime: DateTime.now(),
    );

    _activeSyncOperations[operationId] = operation;
    _operationController.add(operation);
    _updateSyncStatus(SyncStatus.syncing);

    // Simulate download progress
    _simulateProgressUpdate(operation, _mockDownloadProgress);

    log(
      'MockCloudSyncService: Started download $operationId: $remotePath -> $localPath',
    );
    return operation;
  }

  @override
  Future<void> syncAll() async {
    await _simulateOperation();

    _updateSyncStatus(SyncStatus.syncing);

    // Simulate syncing multiple files
    for (int i = 0; i < 3; i++) {
      await uploadFile(
        localPath: '/mock/local/file_$i.txt',
        remotePath: '/mock/remote/file_$i.txt',
      );

      await Future.delayed(Duration(milliseconds: 100));
    }

    _updateSyncStatus(SyncStatus.completed);
    log('MockCloudSyncService: Completed sync all');
  }

  @override
  Future<void> pauseSync() async {
    await _simulateOperation();

    _updateSyncStatus(SyncStatus.paused);

    // Pause all active operations
    for (final operation in _activeSyncOperations.values) {
      if (operation.status == SyncOperationStatus.inProgress) {
        final pausedOperation = operation.copyWith(
          status: SyncOperationStatus.paused,
        );
        _activeSyncOperations[operation.id] = pausedOperation;
        _operationController.add(pausedOperation);
      }
    }

    log('MockCloudSyncService: Paused sync');
  }

  @override
  Future<void> resumeSync() async {
    await _simulateOperation();

    _updateSyncStatus(SyncStatus.syncing);

    // Resume all paused operations
    for (final operation in _activeSyncOperations.values) {
      if (operation.status == SyncOperationStatus.paused) {
        final resumedOperation = operation.copyWith(
          status: SyncOperationStatus.inProgress,
        );
        _activeSyncOperations[operation.id] = resumedOperation;
        _operationController.add(resumedOperation);
      }
    }

    log('MockCloudSyncService: Resumed sync');
  }

  @override
  Future<void> cancelOperation(String operationId) async {
    await _simulateOperation();

    final operation = _activeSyncOperations[operationId];
    if (operation != null) {
      final cancelledOperation = operation.copyWith(
        status: SyncOperationStatus.cancelled,
        endTime: DateTime.now(),
      );
      _activeSyncOperations[operationId] = cancelledOperation;
      _operationController.add(cancelledOperation);

      log('MockCloudSyncService: Cancelled operation $operationId');
    }
  }

  @override
  Future<SyncStatus> getSyncStatus() async {
    await _simulateOperation();
    return _globalSyncStatus;
  }

  @override
  Future<List<SyncOperation>> getActiveSyncOperations() async {
    await _simulateOperation();
    return _activeSyncOperations.values
        .where((op) => op.status == SyncOperationStatus.inProgress)
        .toList();
  }

  @override
  Future<List<conflict_models.SyncConflict>> getPendingConflicts() async {
    await _simulateOperation();
    return _pendingConflicts.toList();
  }

  @override
  Future<void> resolveConflict(
    String conflictId,
    conflict_models.ConflictResolution resolution,
  ) async {
    await _simulateOperation();

    _pendingConflicts.removeWhere((conflict) => conflict.id == conflictId);
    _conflictsResolved++;

    log('MockCloudSyncService: Resolved conflict $conflictId with $resolution');
  }

  @override
  Future<bool> checkConnectivity() async {
    await _simulateOperation();
    // Mock connectivity - fails if network issues are simulated
    return !_shouldSimulateNetworkIssues;
  }

  @override
  Future<Map<String, dynamic>> getSyncStatistics() async {
    await _simulateOperation();

    return {
      'totalUploads': _totalUploads,
      'totalDownloads': _totalDownloads,
      'successfulOperations': _successfulOperations,
      'failedOperations': _failedOperations,
      'conflictsResolved': _conflictsResolved,
      'enabledProviders': _enabledProviders.length,
      'activeOperations': _activeSyncOperations.length,
      'pendingConflicts': _pendingConflicts.length,
      'currentStatus': _globalSyncStatus.toString(),
    };
  }

  // Private helper methods

  Future<void> _simulateOperation() async {
    if (!_isInitialized) {
      throw StateError('Service not initialized');
    }

    if (_shouldFailOperations) {
      _failedOperations++;
      throw Exception('Mock cloud sync operation failure');
    }

    if (_shouldSimulateNetworkIssues) {
      throw Exception('Network connectivity issue');
    }

    await Future.delayed(_mockOperationDelay);
    _successfulOperations++;
  }

  void _updateSyncStatus(SyncStatus status) {
    _globalSyncStatus = status;
    _syncStatusController.add(status);
  }

  void _simulateProgressUpdate(SyncOperation operation, double targetProgress) {
    // Simulate gradual progress updates
    Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (_activeSyncOperations[operation.id]?.status !=
          SyncOperationStatus.inProgress) {
        timer.cancel();
        return;
      }

      final currentProgress =
          _activeSyncOperations[operation.id]?.progress ?? 0.0;
      final newProgress = math.min(targetProgress, currentProgress + 0.1);

      final updatedOperation = operation.copyWith(progress: newProgress);
      _activeSyncOperations[operation.id] = updatedOperation;
      _operationController.add(updatedOperation);

      // Complete operation when progress reaches target
      if (newProgress >= targetProgress) {
        timer.cancel();
        _completeOperation(operation.id);
      }
    });
  }

  void _completeOperation(String operationId) {
    final operation = _activeSyncOperations[operationId];
    if (operation != null) {
      final completedOperation = operation.copyWith(
        status: SyncOperationStatus.completed,
        progress: 1.0,
        endTime: DateTime.now(),
      );
      _activeSyncOperations[operationId] = completedOperation;
      _operationController.add(completedOperation);

      // Check if this was the last active operation
      final hasActiveOperations = _activeSyncOperations.values.any(
        (op) => op.status == SyncOperationStatus.inProgress,
      );

      if (!hasActiveOperations) {
        _updateSyncStatus(SyncStatus.completed);
      }

      // Simulate conflict generation if enabled
      if (_shouldSimulateConflicts && math.Random().nextBool()) {
        _generateMockConflict(operation);
      }
    }
  }

  void _generateMockConflict(SyncOperation operation) {
    final conflict = conflict_models.SyncConflict(
      id: 'conflict_${DateTime.now().millisecondsSinceEpoch}',
      localPath: operation.localPath,
      remotePath: operation.remotePath,
      provider: operation.provider,
      conflictType: conflict_models.ConflictType.modificationConflict,
      description: 'Mock conflict: File modified on both local and remote',
      localModified: DateTime.now().subtract(Duration(hours: 1)),
      remoteModified: DateTime.now(),
      localFileSize: 1024,
      remoteFileSize: 1150,
      detectedAt: DateTime.now(),
    );

    _pendingConflicts.add(conflict);
    _conflictController.add(conflict);

    log('MockCloudSyncService: Generated mock conflict ${conflict.id}');
  }

  /// Generate mock sync operation for testing
  SyncOperation generateMockSyncOperation({
    String? id,
    SyncOperationType? type,
    String? localPath,
    String? remotePath,
    CloudProvider? provider,
    SyncOperationStatus? status,
    double? progress,
  }) {
    final random = math.Random();

    return SyncOperation(
      id: id ?? 'mock_op_${random.nextInt(10000)}',
      type: type ?? SyncOperationType.upload,
      localPath: localPath ?? '/mock/local/file.txt',
      remotePath: remotePath ?? '/mock/remote/file.txt',
      provider: provider ?? CloudProvider.googleDrive,
      status: status ?? SyncOperationStatus.completed,
      progress: progress ?? 1.0,
      startTime: DateTime.now().subtract(Duration(minutes: random.nextInt(60))),
      endTime: status == SyncOperationStatus.completed
          ? DateTime.now().subtract(Duration(minutes: random.nextInt(30)))
          : null,
    );
  }

  /// Generate mock conflict for testing
  conflict_models.SyncConflict generateMockConflict({
    String? id,
    String? localPath,
    String? remotePath,
    CloudProvider? provider,
    conflict_models.ConflictType? conflictType,
  }) {
    final random = math.Random();

    return conflict_models.SyncConflict(
      id: id ?? 'mock_conflict_${random.nextInt(10000)}',
      localPath: localPath ?? '/mock/local/conflict_file.txt',
      remotePath: remotePath ?? '/mock/remote/conflict_file.txt',
      provider: provider ?? CloudProvider.iCloud,
      conflictType:
          conflictType ?? conflict_models.ConflictType.modificationConflict,
      description: 'Mock conflict for testing',
      localModified: DateTime.now().subtract(
        Duration(hours: random.nextInt(24)),
      ),
      remoteModified: DateTime.now().subtract(
        Duration(hours: random.nextInt(24)),
      ),
      localFileSize: random.nextInt(10000) + 1000,
      remoteFileSize: random.nextInt(10000) + 1000,
      detectedAt: DateTime.now(),
    );
  }

  /// Simulate provider connection test
  Future<bool> testProviderConnection(CloudProvider provider) async {
    await _simulateOperation();

    // Mock connection test - succeeds if provider is enabled and not failing
    final isConnected =
        _enabledProviders.contains(provider) &&
        !_shouldFailOperations &&
        !_shouldSimulateNetworkIssues;

    log(
      'MockCloudSyncService: Provider $provider connection test: ${isConnected ? 'success' : 'failed'}',
    );
    return isConnected;
  }

  /// Get current mock state for debugging
  Map<String, dynamic> getMockState() {
    return {
      'isInitialized': _isInitialized,
      'shouldFailOperations': _shouldFailOperations,
      'shouldFailInitialization': _shouldFailInitialization,
      'shouldSimulateConflicts': _shouldSimulateConflicts,
      'shouldSimulateNetworkIssues': _shouldSimulateNetworkIssues,
      'mockOperationDelay': _mockOperationDelay.inMilliseconds,
      'mockUploadProgress': _mockUploadProgress,
      'mockDownloadProgress': _mockDownloadProgress,
      'enabledProviders': _enabledProviders.map((p) => p.toString()).toList(),
      'activeSyncOperations': _activeSyncOperations.length,
      'pendingConflicts': _pendingConflicts.length,
      'globalSyncStatus': _globalSyncStatus.toString(),
      'operationCounter': _operationCounter,
      'totalUploads': _totalUploads,
      'totalDownloads': _totalDownloads,
      'successfulOperations': _successfulOperations,
      'failedOperations': _failedOperations,
      'conflictsResolved': _conflictsResolved,
    };
  }
}
