import 'dart:async';
import 'dart:math' as math;
import 'dart:developer';

import 'package:meeting_summarizer/core/interfaces/cloud_sync_interface.dart';
import 'package:meeting_summarizer/core/models/cloud_sync/cloud_provider.dart';
import 'package:meeting_summarizer/core/models/cloud_sync/sync_status.dart';
import 'package:meeting_summarizer/core/models/cloud_sync/sync_operation.dart';
import 'package:meeting_summarizer/core/models/cloud_sync/sync_conflict.dart'
    as models;

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
  final List<models.SyncConflict> _pendingConflicts = [];
  final Map<CloudProvider, SyncStatus> _providerSyncStatus = {};
  bool _isAutoSyncEnabled = true;
  Duration _syncInterval = const Duration(minutes: 15);
  bool _isSyncPaused = false;
  int _operationCounter = 0;

  // Mock statistics
  int _totalUploads = 0;
  int _totalDownloads = 0;
  int _successfulOperations = 0;
  int _failedOperations = 0;
  int _conflictsResolved = 0;

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
    if (upload != null) {
      _mockUploadProgress = math.max(0.0, math.min(1.0, upload));
    }
    if (download != null) {
      _mockDownloadProgress = math.max(0.0, math.min(1.0, download));
    }
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
    _providerSyncStatus.clear();
    _operationCounter = 0;
    _totalUploads = 0;
    _totalDownloads = 0;
    _successfulOperations = 0;
    _failedOperations = 0;
    _conflictsResolved = 0;
    _isAutoSyncEnabled = true;
    _syncInterval = const Duration(minutes: 15);
    _isSyncPaused = false;
  }

  @override
  Future<void> initialize() async {
    if (_shouldFailInitialization) {
      throw Exception('Mock cloud sync initialization failure');
    }

    await Future.delayed(_mockOperationDelay);
    _isInitialized = true;
    log('MockCloudSyncService: Initialized successfully');
  }

  // Dispose method is not part of the interface
  Future<void> dispose() async {
    _isInitialized = false;
    log('MockCloudSyncService: Disposed');
  }

  @override
  Future<List<CloudProvider>> getAvailableProviders() async {
    await _simulateOperation();
    return CloudProvider.values;
  }

  @override
  Future<bool> connectProvider(
    CloudProvider provider,
    Map<String, String> credentials,
  ) async {
    await _simulateOperation();
    _enabledProviders.add(provider);
    _providerSyncStatus[provider] = SyncStatus(
      id: 'status_${provider.id}',
      state: SyncState.idle,
      provider: provider,
      lastSync: DateTime.now(),
    );
    log('MockCloudSyncService: Connected to provider $provider');
    return true;
  }

  @override
  Future<void> disconnectProvider(CloudProvider provider) async {
    await _simulateOperation();
    _enabledProviders.remove(provider);
    _providerSyncStatus.remove(provider);
    log('MockCloudSyncService: Disconnected from provider $provider');
  }

  @override
  Future<bool> isProviderConnected(CloudProvider provider) async {
    await _simulateOperation();
    // Mock: providers are connected if they're enabled and not failing
    return _enabledProviders.contains(provider) && !_shouldFailOperations;
  }

  @override
  Future<SyncOperation> uploadFile({
    required String localFilePath,
    required String remoteFilePath,
    required CloudProvider provider,
    bool encryptBeforeUpload = true,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _simulateOperation();

    _totalUploads++;
    final operationId = 'upload_${_operationCounter++}';

    final operation = SyncOperation(
      id: operationId,
      type: SyncOperationType.upload,
      localFilePath: localFilePath,
      remoteFilePath: remoteFilePath,
      provider: provider,
      status: SyncOperationStatus.running,
      createdAt: DateTime.now(),
      progressPercentage: 0.0,
      metadata: metadata,
    );

    _activeSyncOperations[operationId] = operation;
    _updateProviderSyncStatus(provider, SyncState.syncing);

    // Simulate upload progress
    _simulateProgressUpdate(operation, _mockUploadProgress);

    log(
      'MockCloudSyncService: Started upload $operationId: $localFilePath -> $remoteFilePath',
    );
    return operation;
  }

  @override
  Future<SyncOperation> downloadFile({
    required String remoteFilePath,
    required String localFilePath,
    required CloudProvider provider,
    bool decryptAfterDownload = true,
  }) async {
    await _simulateOperation();

    _totalDownloads++;
    final operationId = 'download_${_operationCounter++}';

    final operation = SyncOperation(
      id: operationId,
      type: SyncOperationType.download,
      localFilePath: localFilePath,
      remoteFilePath: remoteFilePath,
      provider: provider,
      status: SyncOperationStatus.running,
      createdAt: DateTime.now(),
      progressPercentage: 0.0,
    );

    _activeSyncOperations[operationId] = operation;
    _updateProviderSyncStatus(provider, SyncState.syncing);

    // Simulate download progress
    _simulateProgressUpdate(operation, _mockDownloadProgress);

    log(
      'MockCloudSyncService: Started download $operationId: $remoteFilePath -> $localFilePath',
    );
    return operation;
  }

  @override
  Future<List<SyncOperation>> syncAll({
    CloudProvider? provider,
    SyncDirection direction = SyncDirection.bidirectional,
  }) async {
    await _simulateOperation();

    final List<SyncOperation> operations = [];
    final providersToSync =
        provider != null ? [provider] : _enabledProviders.toList();

    for (final syncProvider in providersToSync) {
      _updateProviderSyncStatus(syncProvider, SyncState.syncing);

      // Simulate syncing multiple files
      for (int i = 0; i < 3; i++) {
        final operation = await uploadFile(
          localFilePath: '/mock/local/file_$i.txt',
          remoteFilePath: '/mock/remote/file_$i.txt',
          provider: syncProvider,
        );
        operations.add(operation);

        await Future.delayed(Duration(milliseconds: 100));
      }

      _updateProviderSyncStatus(syncProvider, SyncState.completed);
    }

    log('MockCloudSyncService: Completed sync all');
    return operations;
  }

  @override
  Future<SyncStatus?> getFileSyncStatus(String filePath) async {
    await _simulateOperation();
    // Mock implementation - return a status for the file if it exists in operations
    final operation = _activeSyncOperations.values
        .where(
          (op) => op.localFilePath == filePath || op.remoteFilePath == filePath,
        )
        .firstOrNull;

    if (operation != null) {
      return SyncStatus(
        id: 'file_${filePath.hashCode}',
        state: _mapOperationStatusToSyncState(operation.status),
        provider: operation.provider,
        lastSync: operation.startedAt ?? operation.createdAt,
        progressPercentage: operation.progressPercentage,
      );
    }
    return null;
  }

  @override
  Future<Map<CloudProvider, SyncStatus>> getSyncStatus() async {
    await _simulateOperation();
    return Map.from(_providerSyncStatus);
  }

  @override
  Future<bool> resolveConflict(
    models.SyncConflict conflict,
    ConflictResolution resolution,
  ) async {
    await _simulateOperation();

    final index = _pendingConflicts.indexWhere((c) => c.id == conflict.id);
    if (index != -1) {
      final resolvedConflict = _pendingConflicts[index].copyWith(
        isResolved: true,
        resolution: models.ConflictResolution.values.firstWhere(
          (r) => r.name == resolution.name,
        ),
        resolvedAt: DateTime.now(),
      );
      _pendingConflicts[index] = resolvedConflict;
      _conflictsResolved++;
      log(
        'MockCloudSyncService: Resolved conflict ${conflict.id} with $resolution',
      );
      return true;
    }
    return false;
  }

  @override
  Future<List<models.SyncConflict>> getPendingConflicts() async {
    await _simulateOperation();
    return _pendingConflicts.where((conflict) => !conflict.isResolved).toList();
  }

  @override
  Future<void> cancelOperation(String operationId) async {
    await _simulateOperation();

    final operation = _activeSyncOperations[operationId];
    if (operation != null) {
      final cancelledOperation = operation.copyWith(
        status: SyncOperationStatus.cancelled,
        completedAt: DateTime.now(),
      );
      _activeSyncOperations[operationId] = cancelledOperation;

      log('MockCloudSyncService: Cancelled operation $operationId');
    }
  }

  @override
  Future<List<SyncOperation>> getSyncHistory({
    CloudProvider? provider,
    DateTime? since,
    int limit = 100,
  }) async {
    await _simulateOperation();
    var operations = _activeSyncOperations.values.toList();

    if (provider != null) {
      operations = operations.where((op) => op.provider == provider).toList();
    }

    if (since != null) {
      operations =
          operations.where((op) => op.createdAt.isAfter(since)).toList();
    }

    operations.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return operations.take(limit).toList();
  }

  @override
  Future<List<models.SyncConflict>> checkForConflicts({
    CloudProvider? provider,
    String? filePath,
  }) async {
    await _simulateOperation();
    var conflicts = _pendingConflicts.where((conflict) => !conflict.isResolved);

    if (provider != null) {
      conflicts = conflicts.where((conflict) => conflict.provider == provider);
    }

    if (filePath != null) {
      conflicts = conflicts.where((conflict) => conflict.filePath == filePath);
    }

    return conflicts.toList();
  }

  @override
  Future<CloudStorageQuota> getStorageQuota(CloudProvider provider) async {
    await _simulateOperation();

    // Mock storage quota data
    final limits = provider.getStorageLimits();
    final random = math.Random();
    final totalBytes = limits.freeStorageGB * 1024 * 1024 * 1024;
    final usedBytes =
        (totalBytes * (0.3 + random.nextDouble() * 0.4)).round(); // 30-70% used

    return CloudStorageQuota(
      totalBytes: totalBytes,
      usedBytes: usedBytes,
      availableBytes: totalBytes - usedBytes,
      provider: provider,
    );
  }

  @override
  Future<void> cleanupCache() async {
    await _simulateOperation();
    log('MockCloudSyncService: Cache cleaned up');
  }

  @override
  Future<void> setAutoSyncEnabled(bool enabled) async {
    await _simulateOperation();
    _isAutoSyncEnabled = enabled;
    log('MockCloudSyncService: Auto-sync ${enabled ? "enabled" : "disabled"}');
  }

  @override
  Future<bool> isAutoSyncEnabled() async {
    await _simulateOperation();
    return _isAutoSyncEnabled;
  }

  @override
  Future<void> setSyncInterval(Duration interval) async {
    await _simulateOperation();
    _syncInterval = interval;
    log(
      'MockCloudSyncService: Sync interval set to ${interval.inMinutes} minutes',
    );
  }

  @override
  Future<Duration> getSyncInterval() async {
    await _simulateOperation();
    return _syncInterval;
  }

  @override
  Future<void> pauseSync() async {
    await _simulateOperation();
    _isSyncPaused = true;

    // Update all provider statuses to paused
    for (final provider in _enabledProviders) {
      _updateProviderSyncStatus(provider, SyncState.paused);
    }

    // Pause all active operations
    for (final operation in _activeSyncOperations.values) {
      if (operation.status == SyncOperationStatus.running) {
        final pausedOperation = operation.copyWith(
          status: SyncOperationStatus.paused,
        );
        _activeSyncOperations[operation.id] = pausedOperation;
      }
    }

    log('MockCloudSyncService: Paused sync');
  }

  @override
  Future<void> resumeSync() async {
    await _simulateOperation();
    _isSyncPaused = false;

    // Update all provider statuses to syncing if they have active operations
    for (final provider in _enabledProviders) {
      final hasActiveOperations = _activeSyncOperations.values.any(
        (op) =>
            op.provider == provider && op.status == SyncOperationStatus.paused,
      );
      if (hasActiveOperations) {
        _updateProviderSyncStatus(provider, SyncState.syncing);
      } else {
        _updateProviderSyncStatus(provider, SyncState.idle);
      }
    }

    // Resume all paused operations
    for (final operation in _activeSyncOperations.values) {
      if (operation.status == SyncOperationStatus.paused) {
        final resumedOperation = operation.copyWith(
          status: SyncOperationStatus.running,
        );
        _activeSyncOperations[operation.id] = resumedOperation;
      }
    }

    log('MockCloudSyncService: Resumed sync');
  }

  @override
  Future<bool> isSyncPaused() async {
    await _simulateOperation();
    return _isSyncPaused;
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

  void _updateProviderSyncStatus(CloudProvider provider, SyncState state) {
    final currentStatus = _providerSyncStatus[provider];
    final updatedStatus = currentStatus?.copyWith(
          state: state,
          lastSync: state == SyncState.completed
              ? DateTime.now()
              : currentStatus.lastSync,
        ) ??
        SyncStatus(
          id: 'status_${provider.id}',
          state: state,
          provider: provider,
          lastSync: DateTime.now(),
        );

    _providerSyncStatus[provider] = updatedStatus;
  }

  SyncState _mapOperationStatusToSyncState(SyncOperationStatus status) {
    switch (status) {
      case SyncOperationStatus.queued:
        return SyncState.preparing;
      case SyncOperationStatus.running:
        return SyncState.syncing;
      case SyncOperationStatus.completed:
        return SyncState.completed;
      case SyncOperationStatus.failed:
        return SyncState.error;
      case SyncOperationStatus.cancelled:
        return SyncState.cancelled;
      case SyncOperationStatus.paused:
        return SyncState.paused;
    }
  }

  void _simulateProgressUpdate(SyncOperation operation, double targetProgress) {
    // Simulate gradual progress updates
    Timer.periodic(Duration(milliseconds: 100), (timer) {
      final currentOp = _activeSyncOperations[operation.id];
      if (currentOp?.status != SyncOperationStatus.running) {
        timer.cancel();
        return;
      }

      final currentProgress = currentOp?.progressPercentage ?? 0.0;
      final newProgress = math.min(targetProgress, currentProgress + 0.1);

      final updatedOperation = currentOp!.copyWith(
        progressPercentage: newProgress,
      );
      _activeSyncOperations[operation.id] = updatedOperation;

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
        progressPercentage: 1.0,
        completedAt: DateTime.now(),
      );
      _activeSyncOperations[operationId] = completedOperation;

      // Check if this was the last active operation for this provider
      final hasActiveOperations = _activeSyncOperations.values.any(
        (op) =>
            op.provider == operation.provider &&
            op.status == SyncOperationStatus.running,
      );

      if (!hasActiveOperations) {
        _updateProviderSyncStatus(operation.provider, SyncState.completed);
      }

      // Simulate conflict generation if enabled
      if (_shouldSimulateConflicts && math.Random().nextBool()) {
        _generateMockConflict(operation);
      }
    }
  }

  void _generateMockConflict(SyncOperation operation) {
    final localVersion = models.FileVersion(
      path: operation.localFilePath,
      size: 1024,
      modifiedAt: DateTime.now().subtract(Duration(hours: 1)),
      checksum: 'mock_local_checksum',
    );

    final remoteVersion = models.FileVersion(
      path: operation.remoteFilePath,
      size: 1150,
      modifiedAt: DateTime.now(),
      checksum: 'mock_remote_checksum',
    );

    final conflict = models.SyncConflict(
      id: 'conflict_${DateTime.now().millisecondsSinceEpoch}',
      filePath: operation.localFilePath,
      provider: operation.provider,
      type: models.ConflictType.modifiedBoth,
      localVersion: localVersion,
      remoteVersion: remoteVersion,
      detectedAt: DateTime.now(),
      severity: models.ConflictSeverity.medium,
      description: 'Mock conflict: File modified on both local and remote',
    );

    _pendingConflicts.add(conflict);

    log('MockCloudSyncService: Generated mock conflict ${conflict.id}');
  }

  /// Generate mock sync operation for testing
  SyncOperation generateMockSyncOperation({
    String? id,
    SyncOperationType? type,
    String? localFilePath,
    String? remoteFilePath,
    CloudProvider? provider,
    SyncOperationStatus? status,
    double? progressPercentage,
  }) {
    final random = math.Random();
    final now = DateTime.now();

    return SyncOperation(
      id: id ?? 'mock_op_${random.nextInt(10000)}',
      type: type ?? SyncOperationType.upload,
      localFilePath: localFilePath ?? '/mock/local/file.txt',
      remoteFilePath: remoteFilePath ?? '/mock/remote/file.txt',
      provider: provider ?? CloudProvider.googleDrive,
      status: status ?? SyncOperationStatus.completed,
      createdAt: now.subtract(Duration(minutes: random.nextInt(60))),
      progressPercentage: progressPercentage ?? 1.0,
      startedAt: now.subtract(Duration(minutes: random.nextInt(45))),
      completedAt: status == SyncOperationStatus.completed
          ? now.subtract(Duration(minutes: random.nextInt(30)))
          : null,
    );
  }

  /// Generate mock conflict for testing
  models.SyncConflict generateMockConflict({
    String? id,
    String? filePath,
    CloudProvider? provider,
    models.ConflictType? conflictType,
  }) {
    final random = math.Random();
    final now = DateTime.now();

    final localVersion = models.FileVersion(
      path: filePath ?? '/mock/local/conflict_file.txt',
      size: random.nextInt(10000) + 1000,
      modifiedAt: now.subtract(Duration(hours: random.nextInt(24))),
      checksum: 'local_checksum_${random.nextInt(1000)}',
    );

    final remoteVersion = models.FileVersion(
      path: filePath ?? '/mock/remote/conflict_file.txt',
      size: random.nextInt(10000) + 1000,
      modifiedAt: now.subtract(Duration(hours: random.nextInt(24))),
      checksum: 'remote_checksum_${random.nextInt(1000)}',
    );

    return models.SyncConflict(
      id: id ?? 'mock_conflict_${random.nextInt(10000)}',
      filePath: filePath ?? '/mock/conflict_file.txt',
      provider: provider ?? CloudProvider.googleDrive,
      type: conflictType ?? models.ConflictType.modifiedBoth,
      localVersion: localVersion,
      remoteVersion: remoteVersion,
      detectedAt: now,
      severity: models.ConflictSeverity.medium,
      description: 'Mock conflict for testing',
    );
  }

  /// Simulate provider connection test
  Future<bool> testProviderConnection(CloudProvider provider) async {
    await _simulateOperation();

    // Mock connection test - succeeds if provider is enabled and not failing
    final isConnected = _enabledProviders.contains(provider) &&
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
      'isAutoSyncEnabled': _isAutoSyncEnabled,
      'syncInterval': _syncInterval.inMinutes,
      'isSyncPaused': _isSyncPaused,
      'operationCounter': _operationCounter,
      'totalUploads': _totalUploads,
      'totalDownloads': _totalDownloads,
      'successfulOperations': _successfulOperations,
      'failedOperations': _failedOperations,
      'conflictsResolved': _conflictsResolved,
    };
  }
}
