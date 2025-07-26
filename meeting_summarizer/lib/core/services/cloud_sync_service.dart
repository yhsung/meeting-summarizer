import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../interfaces/cloud_sync_interface.dart';
import '../models/cloud_sync/cloud_provider.dart';
import '../models/cloud_sync/sync_status.dart';
import '../models/cloud_sync/sync_conflict.dart' as conflict_models;
import '../models/cloud_sync/sync_operation.dart';
import '../models/cloud_sync/file_change.dart' as file_change_models;
import 'encryption_service.dart';
import 'cloud_encryption_service.dart';
import 'cloud_providers/cloud_provider_factory.dart';
import 'cloud_providers/cloud_provider_interface.dart';
import 'conflict_detection_service.dart';
import 'conflict_resolution_service.dart' as conflict_resolution_service;
import 'version_management_service.dart';
import 'incremental_transfer_manager.dart';
import 'change_tracking_service.dart';
import 'delta_sync_service.dart' as delta_sync;
import 'offline_queue_service.dart';
import 'network_connectivity_service.dart';
import 'retry_manager.dart';

/// Main cloud synchronization service that coordinates multiple providers
class CloudSyncService implements CloudSyncInterface {
  static CloudSyncService? _instance;
  static CloudSyncService get instance => _instance ??= CloudSyncService._();
  CloudSyncService._();

  final CloudProviderFactory _providerFactory = CloudProviderFactory.instance;
  final ConflictDetectionService _conflictDetection =
      ConflictDetectionService.instance;
  final conflict_resolution_service.ConflictResolutionService
      _conflictResolution =
      conflict_resolution_service.ConflictResolutionService.instance;
  final VersionManagementService _versionManagement =
      VersionManagementService.instance;
  final IncrementalTransferManager _incrementalTransfer =
      IncrementalTransferManager.instance;
  final ChangeTrackingService _changeTracking = ChangeTrackingService.instance;
  final CloudEncryptionService _cloudEncryption =
      CloudEncryptionService.instance;
  final OfflineQueueService _offlineQueue = OfflineQueueService.instance;
  final NetworkConnectivityService _networkConnectivity =
      NetworkConnectivityService.instance;
  final RetryManager _retryManager = RetryManager.instance;
  final Map<CloudProvider, CloudProviderInterface> _connectedProviders = {};
  final Map<String, SyncOperation> _activeOperations = {};
  final Map<String, conflict_models.SyncConflict> _pendingConflicts = {};

  bool _isInitialized = false;
  bool _autoSyncEnabled = true;
  bool _syncPaused = false;
  Duration _syncInterval = const Duration(minutes: 15);
  Timer? _autoSyncTimer;

  // Background queue processing
  bool _backgroundProcessingEnabled = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  final StreamController<SyncStatus> _syncStatusController =
      StreamController<SyncStatus>.broadcast();
  final StreamController<SyncOperation> _operationController =
      StreamController<SyncOperation>.broadcast();
  final StreamController<conflict_models.SyncConflict> _conflictController =
      StreamController<conflict_models.SyncConflict>.broadcast();

  /// Stream of sync status updates
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  /// Stream of operation updates
  Stream<SyncOperation> get operationStream => _operationController.stream;

  /// Stream of conflict notifications
  Stream<conflict_models.SyncConflict> get conflictStream =>
      _conflictController.stream;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log('CloudSyncService: Initializing...');

      // Initialize encryption services
      await EncryptionService.initialize();
      await CloudEncryptionService.initialize();

      // Initialize provider factory
      await _providerFactory.initialize();

      // Initialize conflict resolution services
      await _versionManagement.initialize();

      // Initialize incremental sync services
      await _incrementalTransfer.initialize();
      await _changeTracking.initialize();

      // Initialize offline queue and connectivity services
      await _offlineQueue.initialize();
      await _networkConnectivity.initialize();

      // Start background queue processing
      if (_backgroundProcessingEnabled) {
        _startBackgroundQueueProcessing();
      }

      // Start auto-sync timer if enabled
      if (_autoSyncEnabled && !_syncPaused) {
        _startAutoSyncTimer();
      }

      _isInitialized = true;
      log('CloudSyncService: Initialization completed');
    } catch (e, stackTrace) {
      log(
        'CloudSyncService: Initialization failed: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<List<CloudProvider>> getAvailableProviders() async {
    if (!_isInitialized) await initialize();

    final platform = _getCurrentPlatform();
    return CloudProvider.getSupportedProviders(platform);
  }

  @override
  Future<bool> connectProvider(
    CloudProvider provider,
    Map<String, String> credentials,
  ) async {
    try {
      log('CloudSyncService: Connecting to ${provider.displayName}...');

      final providerInterface = await _providerFactory.createProvider(
        provider,
        credentials,
      );

      if (providerInterface == null) {
        log(
          'CloudSyncService: Failed to create provider interface for ${provider.displayName}',
        );
        return false;
      }

      final connected = await providerInterface.connect();
      if (connected) {
        _connectedProviders[provider] = providerInterface;
        log(
          'CloudSyncService: Successfully connected to ${provider.displayName}',
        );
        return true;
      } else {
        log('CloudSyncService: Failed to connect to ${provider.displayName}');
        return false;
      }
    } catch (e, stackTrace) {
      log(
        'CloudSyncService: Error connecting to ${provider.displayName}: $e',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<void> disconnectProvider(CloudProvider provider) async {
    try {
      final providerInterface = _connectedProviders[provider];
      if (providerInterface != null) {
        await providerInterface.disconnect();
        _connectedProviders.remove(provider);
        log('CloudSyncService: Disconnected from ${provider.displayName}');
      }
    } catch (e, stackTrace) {
      log(
        'CloudSyncService: Error disconnecting from ${provider.displayName}: $e',
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<bool> isProviderConnected(CloudProvider provider) async {
    final providerInterface = _connectedProviders[provider];
    return providerInterface?.isConnected() ?? false;
  }

  @override
  Future<SyncOperation> uploadFile({
    required String localFilePath,
    required String remoteFilePath,
    required CloudProvider provider,
    bool encryptBeforeUpload = true,
    Map<String, dynamic> metadata = const {},
    int priority = 0,
    bool queueIfOffline = true,
  }) async {
    final operation = SyncOperation(
      id: _generateOperationId(),
      type: SyncOperationType.upload,
      localFilePath: localFilePath,
      remoteFilePath: remoteFilePath,
      provider: provider,
      status: SyncOperationStatus.queued,
      createdAt: DateTime.now(),
      metadata: metadata,
      priority: priority,
      isQueueable: queueIfOffline,
    );

    _activeOperations[operation.id] = operation;
    _operationController.add(operation);

    // Check connectivity and queue if offline
    if (queueIfOffline && !await _networkConnectivity.isConnected) {
      log(
        'CloudSyncService: No connectivity, queuing upload operation ${operation.id}',
      );

      await _offlineQueue.enqueueOperation(
        operation: operation,
        priority: priority,
      );

      final queuedOperation = operation.copyWith(
        status: SyncOperationStatus.queued,
        queuedAt: DateTime.now(),
      );

      _activeOperations[operation.id] = queuedOperation;
      _operationController.add(queuedOperation);

      return queuedOperation;
    }

    // Execute upload in background with retry support
    _executeUploadWithRetry(operation, encryptBeforeUpload);

    return operation;
  }

  @override
  Future<SyncOperation> downloadFile({
    required String remoteFilePath,
    required String localFilePath,
    required CloudProvider provider,
    bool decryptAfterDownload = true,
    int priority = 0,
    bool queueIfOffline = true,
  }) async {
    final operation = SyncOperation(
      id: _generateOperationId(),
      type: SyncOperationType.download,
      localFilePath: localFilePath,
      remoteFilePath: remoteFilePath,
      provider: provider,
      status: SyncOperationStatus.queued,
      createdAt: DateTime.now(),
      priority: priority,
      isQueueable: queueIfOffline,
    );

    _activeOperations[operation.id] = operation;
    _operationController.add(operation);

    // Check connectivity and queue if offline
    if (queueIfOffline && !await _networkConnectivity.isConnected) {
      log(
        'CloudSyncService: No connectivity, queuing download operation ${operation.id}',
      );

      await _offlineQueue.enqueueOperation(
        operation: operation,
        priority: priority,
      );

      final queuedOperation = operation.copyWith(
        status: SyncOperationStatus.queued,
        queuedAt: DateTime.now(),
      );

      _activeOperations[operation.id] = queuedOperation;
      _operationController.add(queuedOperation);

      return queuedOperation;
    }

    // Execute download in background with retry support
    _executeDownloadWithRetry(operation, decryptAfterDownload);

    return operation;
  }

  @override
  Future<List<SyncOperation>> syncAll({
    CloudProvider? provider,
    SyncDirection direction = SyncDirection.bidirectional,
  }) async {
    final operations = <SyncOperation>[];

    try {
      log('CloudSyncService: Starting full sync...');

      final providers =
          provider != null ? [provider] : _connectedProviders.keys.toList();

      for (final cloudProvider in providers) {
        final providerOps = await _syncProvider(cloudProvider, direction);
        operations.addAll(providerOps);
      }

      log(
        'CloudSyncService: Full sync initiated with ${operations.length} operations',
      );
      return operations;
    } catch (e, stackTrace) {
      log('CloudSyncService: Error in syncAll: $e', stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<SyncStatus?> getFileSyncStatus(String filePath) async {
    // This would typically query a database for file sync status
    // For now, return a placeholder
    return null;
  }

  @override
  Future<Map<CloudProvider, SyncStatus>> getSyncStatus() async {
    final statusMap = <CloudProvider, SyncStatus>{};

    for (final provider in _connectedProviders.keys) {
      final status = SyncStatus(
        id: '${provider.id}_status',
        state: _syncPaused ? SyncState.paused : SyncState.idle,
        provider: provider,
        lastSync: DateTime.now().subtract(const Duration(minutes: 10)),
        nextSync: _autoSyncEnabled && !_syncPaused
            ? DateTime.now().add(_syncInterval)
            : null,
      );
      statusMap[provider] = status;
    }

    return statusMap;
  }

  @override
  Future<bool> resolveConflict(
    conflict_models.SyncConflict conflict,
    ConflictResolution resolution,
  ) async {
    try {
      log(
        'CloudSyncService: Resolving conflict ${conflict.id} with $resolution',
      );

      final providerInterface = _connectedProviders[conflict.provider];
      if (providerInterface == null) {
        log(
          'CloudSyncService: Provider ${conflict.provider.displayName} not connected',
        );
        return false;
      }

      // The conflict resolution service expects the same enum from sync_conflict model
      final serviceResolution = _convertResolutionEnum(resolution);

      // Use the conflict resolution service
      final result = await _conflictResolution.resolveConflict(
        conflict: conflict,
        resolution: serviceResolution,
        providerInterface: providerInterface,
      );

      if (result.success) {
        // Record version change if resolution involved file operations
        if (result.actionTaken != null) {
          await _recordVersionChange(conflict, result);
        }

        // Mark conflict as resolved
        final resolvedConflict = conflict.copyWith(
          isResolved: true,
          resolution: conflict_models.ConflictResolution.values.firstWhere(
            (r) => r.name == resolution.name,
          ),
          resolvedAt: DateTime.now(),
        );

        _pendingConflicts.remove(conflict.id);
        _conflictController.add(resolvedConflict);

        log('CloudSyncService: Successfully resolved conflict ${conflict.id}');
        return true;
      } else {
        log('CloudSyncService: Failed to resolve conflict: ${result.message}');
        return false;
      }
    } catch (e, stackTrace) {
      log(
        'CloudSyncService: Error resolving conflict: $e',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<List<conflict_models.SyncConflict>> getPendingConflicts() async {
    return _pendingConflicts.values.toList();
  }

  @override
  Future<void> cancelOperation(String operationId) async {
    final operation = _activeOperations[operationId];
    if (operation != null && operation.status.canCancel) {
      final cancelledOperation = operation.copyWith(
        status: SyncOperationStatus.cancelled,
        completedAt: DateTime.now(),
      );

      _activeOperations[operationId] = cancelledOperation;
      _operationController.add(cancelledOperation);

      log('CloudSyncService: Cancelled operation $operationId');
    }
  }

  @override
  Future<List<SyncOperation>> getSyncHistory({
    CloudProvider? provider,
    DateTime? since,
    int limit = 100,
  }) async {
    // This would typically query a database for sync history
    // For now, return active operations
    var operations = _activeOperations.values.toList();

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
  Future<List<conflict_models.SyncConflict>> checkForConflicts({
    CloudProvider? provider,
    String? filePath,
  }) async {
    try {
      log('CloudSyncService: Checking for conflicts...');

      final providers = provider != null
          ? {provider: _connectedProviders[provider]!}
          : Map<CloudProvider, CloudProviderInterface>.from(
              _connectedProviders,
            );

      final conflicts = <conflict_models.SyncConflict>[];

      if (filePath != null) {
        // Check specific file
        final fileConflicts = await _conflictDetection.detectFileConflicts(
          filePath: filePath,
          connectedProviders: providers,
        );
        conflicts.addAll(fileConflicts);
      } else {
        // Check all files
        final allConflicts = await _conflictDetection.detectAllConflicts(
          connectedProviders: Map<CloudProvider, CloudProviderInterface>.from(
            providers,
          ),
        );
        conflicts.addAll(allConflicts);
      }

      // Store pending conflicts
      for (final conflict in conflicts) {
        _pendingConflicts[conflict.id] = conflict;
        _conflictController.add(conflict);
      }

      log('CloudSyncService: Found ${conflicts.length} conflicts');
      return conflicts;
    } catch (e, stackTrace) {
      log(
        'CloudSyncService: Error checking for conflicts: $e',
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  @override
  Future<CloudStorageQuota> getStorageQuota(CloudProvider provider) async {
    final providerInterface = _connectedProviders[provider];
    if (providerInterface == null) {
      throw StateError('Provider ${provider.displayName} is not connected');
    }

    return await providerInterface.getStorageQuota();
  }

  @override
  Future<void> cleanupCache() async {
    try {
      log('CloudSyncService: Cleaning up cache...');

      // Clean up completed operations older than 24 hours
      final cutoffTime = DateTime.now().subtract(const Duration(hours: 24));
      _activeOperations.removeWhere(
        (id, operation) =>
            operation.isCompleted &&
            operation.completedAt!.isBefore(cutoffTime),
      );

      // Clean up resolved conflicts older than 7 days
      final conflictCutoff = DateTime.now().subtract(const Duration(days: 7));
      _pendingConflicts.removeWhere(
        (id, conflict) =>
            conflict.isResolved &&
            conflict.resolvedAt!.isBefore(conflictCutoff),
      );

      log('CloudSyncService: Cache cleanup completed');
    } catch (e, stackTrace) {
      log(
        'CloudSyncService: Error during cache cleanup: $e',
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> setAutoSyncEnabled(bool enabled) async {
    _autoSyncEnabled = enabled;

    if (enabled && !_syncPaused) {
      _startAutoSyncTimer();
    } else {
      _stopAutoSyncTimer();
    }

    log('CloudSyncService: Auto-sync ${enabled ? 'enabled' : 'disabled'}');
  }

  @override
  Future<bool> isAutoSyncEnabled() async => _autoSyncEnabled;

  @override
  Future<void> setSyncInterval(Duration interval) async {
    _syncInterval = interval;

    if (_autoSyncEnabled && !_syncPaused) {
      _stopAutoSyncTimer();
      _startAutoSyncTimer();
    }

    log('CloudSyncService: Sync interval set to ${interval.inMinutes} minutes');
  }

  @override
  Future<Duration> getSyncInterval() async => _syncInterval;

  @override
  Future<void> pauseSync() async {
    _syncPaused = true;
    _stopAutoSyncTimer();
    log(
      'CloudSyncService: Sync paused (including background queue processing)',
    );
  }

  @override
  Future<void> resumeSync() async {
    _syncPaused = false;

    if (_autoSyncEnabled) {
      _startAutoSyncTimer();
    }

    log(
      'CloudSyncService: Sync resumed (including background queue processing)',
    );

    // Trigger background queue processing if connectivity is available
    if (_backgroundProcessingEnabled &&
        await _networkConnectivity.isConnected) {
      _processOfflineQueueInBackground();
    }
  }

  @override
  Future<bool> isSyncPaused() async => _syncPaused;

  // Private helper methods

  void _startAutoSyncTimer() {
    _stopAutoSyncTimer();
    _autoSyncTimer = Timer.periodic(_syncInterval, (_) {
      if (!_syncPaused) {
        syncAll();
      }
    });
  }

  void _stopAutoSyncTimer() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Start background queue processing when connectivity is restored
  void _startBackgroundQueueProcessing() {
    _stopBackgroundQueueProcessing();

    log('CloudSyncService: Starting background queue processing');

    // Listen for connectivity changes
    _connectivitySubscription = _networkConnectivity.connectivityStream.listen(
      (connectivityResults) {
        _onConnectivityChanged(connectivityResults);
      },
      onError: (error) {
        log('CloudSyncService: Connectivity stream error: $error');
      },
    );
  }

  /// Stop background queue processing
  void _stopBackgroundQueueProcessing() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Handle connectivity changes for background queue processing
  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    if (!_backgroundProcessingEnabled || _syncPaused) {
      return;
    }

    // Check if we have any connection (not just none)
    final hasConnection = results.any(
      (result) => result != ConnectivityResult.none,
    );

    if (hasConnection) {
      log(
        'CloudSyncService: Connectivity restored, checking internet and processing queue',
      );

      // Verify actual internet connectivity (not just network connection)
      if (await _networkConnectivity.isConnected) {
        log(
          'CloudSyncService: Internet connectivity confirmed, processing offline queue',
        );

        // Process the offline queue in background
        _processOfflineQueueInBackground();
      } else {
        log('CloudSyncService: Network connected but no internet access');
      }
    } else {
      log('CloudSyncService: Connectivity lost');
    }
  }

  /// Process offline queue in background without blocking
  void _processOfflineQueueInBackground() {
    // Process queue asynchronously to avoid blocking the connectivity callback
    Future.delayed(const Duration(seconds: 1), () async {
      try {
        await processOfflineQueue();
      } catch (e) {
        log('CloudSyncService: Error in background queue processing: $e');
      }
    });
  }

  String _generateOperationId() {
    return 'op_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _getCurrentPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// Execute upload with retry logic and connectivity awareness
  Future<void> _executeUploadWithRetry(
    SyncOperation operation,
    bool encrypt,
  ) async {
    try {
      await _retryManager.executeWithRetry(
        operationId: operation.id,
        operation: () => _performUpload(operation, encrypt),
        policy: const ExponentialBackoffPolicy(maxRetries: 3),
        requiresConnectivity: true,
        onRetry: (error, attemptNumber) {
          log(
            'CloudSyncService: Upload retry attempt $attemptNumber for ${operation.id}: $error',
          );

          final retryingOperation = operation.copyWith(
            status: SyncOperationStatus.running,
            retryCount: attemptNumber,
            error: error.toString(),
          );

          _activeOperations[operation.id] = retryingOperation;
          _operationController.add(retryingOperation);
        },
      );
    } catch (e) {
      log(
        'CloudSyncService: Upload failed after retries for ${operation.id}: $e',
      );

      final failedOperation = operation.copyWith(
        status: SyncOperationStatus.failed,
        completedAt: DateTime.now(),
        error: e.toString(),
      );

      _activeOperations[operation.id] = failedOperation;
      _operationController.add(failedOperation);
    }
  }

  /// Execute download with retry logic and connectivity awareness
  Future<void> _executeDownloadWithRetry(
    SyncOperation operation,
    bool decrypt,
  ) async {
    try {
      await _retryManager.executeWithRetry(
        operationId: operation.id,
        operation: () => _performDownload(operation, decrypt),
        policy: const ExponentialBackoffPolicy(maxRetries: 3),
        requiresConnectivity: true,
        onRetry: (error, attemptNumber) {
          log(
            'CloudSyncService: Download retry attempt $attemptNumber for ${operation.id}: $error',
          );

          final retryingOperation = operation.copyWith(
            status: SyncOperationStatus.running,
            retryCount: attemptNumber,
            error: error.toString(),
          );

          _activeOperations[operation.id] = retryingOperation;
          _operationController.add(retryingOperation);
        },
      );
    } catch (e) {
      log(
        'CloudSyncService: Download failed after retries for ${operation.id}: $e',
      );

      final failedOperation = operation.copyWith(
        status: SyncOperationStatus.failed,
        completedAt: DateTime.now(),
        error: e.toString(),
      );

      _activeOperations[operation.id] = failedOperation;
      _operationController.add(failedOperation);
    }
  }

  /// Perform the actual upload operation
  Future<void> _performUpload(SyncOperation operation, bool encrypt) async {
    final updatedOperation = operation.copyWith(
      status: SyncOperationStatus.running,
      startedAt: DateTime.now(),
    );
    _activeOperations[operation.id] = updatedOperation;
    _operationController.add(updatedOperation);

    final providerInterface = _connectedProviders[operation.provider];
    if (providerInterface == null) {
      throw StateError(
        'Provider ${operation.provider.displayName} not connected',
      );
    }

    // Here you would implement the actual upload logic
    // For now, simulate completion
    await Future.delayed(const Duration(seconds: 2));

    final completedOperation = updatedOperation.copyWith(
      status: SyncOperationStatus.completed,
      completedAt: DateTime.now(),
      progressPercentage: 100.0,
    );

    _activeOperations[operation.id] = completedOperation;
    _operationController.add(completedOperation);
  }

  /// Perform the actual download operation
  Future<void> _performDownload(SyncOperation operation, bool decrypt) async {
    final updatedOperation = operation.copyWith(
      status: SyncOperationStatus.running,
      startedAt: DateTime.now(),
    );
    _activeOperations[operation.id] = updatedOperation;
    _operationController.add(updatedOperation);

    final providerInterface = _connectedProviders[operation.provider];
    if (providerInterface == null) {
      throw StateError(
        'Provider ${operation.provider.displayName} not connected',
      );
    }

    // Here you would implement the actual download logic
    // For now, simulate completion
    await Future.delayed(const Duration(seconds: 2));

    final completedOperation = updatedOperation.copyWith(
      status: SyncOperationStatus.completed,
      completedAt: DateTime.now(),
      progressPercentage: 100.0,
    );

    _activeOperations[operation.id] = completedOperation;
    _operationController.add(completedOperation);
  }

  Future<List<SyncOperation>> _syncProvider(
    CloudProvider provider,
    SyncDirection direction,
  ) async {
    try {
      log('CloudSyncService: Syncing with ${provider.displayName}...');

      final operations = <SyncOperation>[];
      final providerInterface = _connectedProviders[provider];

      if (providerInterface == null) {
        log('CloudSyncService: Provider not connected');
        return operations;
      }

      // Check for conflicts before syncing
      final conflicts = await checkForConflicts(provider: provider);

      if (conflicts.isNotEmpty) {
        log(
          'CloudSyncService: Found ${conflicts.length} conflicts, attempting auto-resolution',
        );

        // Attempt auto-resolution of conflicts
        final autoResolutions = await _conflictResolution.autoResolveConflicts(
          conflicts: conflicts,
          connectedProviders: {provider: providerInterface},
          strategy:
              conflict_resolution_service.AutoResolutionStrategy.conservative,
        );

        var resolvedCount = 0;
        for (final result in autoResolutions) {
          if (result.success) {
            resolvedCount++;
          }
        }

        log(
          'CloudSyncService: Auto-resolved $resolvedCount of ${conflicts.length} conflicts',
        );
      }

      // For now, return empty list as the actual sync implementation
      // would require local file system integration
      return operations;
    } catch (e, stackTrace) {
      log(
        'CloudSyncService: Error syncing provider: $e',
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Convert interface ConflictResolution to service ConflictResolution
  conflict_models.ConflictResolution _convertResolutionEnum(
    ConflictResolution resolution,
  ) {
    switch (resolution) {
      case ConflictResolution.keepLocal:
        return conflict_models.ConflictResolution.keepLocal;
      case ConflictResolution.keepRemote:
        return conflict_models.ConflictResolution.keepRemote;
      case ConflictResolution.keepBoth:
        return conflict_models.ConflictResolution.keepBoth;
      case ConflictResolution.merge:
        return conflict_models.ConflictResolution.merge;
      case ConflictResolution.manual:
        return conflict_models.ConflictResolution.manual;
    }
  }

  /// Record version change after conflict resolution
  Future<void> _recordVersionChange(
    conflict_models.SyncConflict conflict,
    conflict_resolution_service.ConflictResolutionResult result,
  ) async {
    try {
      VersionChangeType changeType;

      switch (result.actionTaken!) {
        case conflict_resolution_service.ConflictAction.uploadedLocal:
          changeType = VersionChangeType.modified;
          break;
        case conflict_resolution_service.ConflictAction.downloadedRemote:
          changeType = VersionChangeType.modified;
          break;
        case conflict_resolution_service.ConflictAction.deletedLocal:
          changeType = VersionChangeType.deleted;
          break;
        case conflict_resolution_service.ConflictAction.deletedRemote:
          changeType = VersionChangeType.deleted;
          break;
        case conflict_resolution_service.ConflictAction.keptBoth:
          changeType = VersionChangeType.created;
          break;
        case conflict_resolution_service.ConflictAction.merged:
          changeType = VersionChangeType.contentChanged;
          break;
      }

      await _versionManagement.recordFileVersion(
        filePath: conflict.filePath,
        provider: conflict.provider,
        version: conflict.localVersion.exists
            ? conflict.localVersion
            : conflict.remoteVersion,
        changeType: changeType,
      );
    } catch (e) {
      log('CloudSyncService: Error recording version change: $e');
    }
  }

  /// Perform incremental sync for a single file
  Future<TransferResult> syncFileIncremental({
    required String filePath,
    required CloudProvider provider,
    SyncDirection direction = SyncDirection.bidirectional,
    bool forceFullSync = false,
    Function(TransferProgress progress)? onProgress,
  }) async {
    if (!_isInitialized) await initialize();

    final providerInterface = _connectedProviders[provider];
    if (providerInterface == null) {
      throw StateError('Provider ${provider.displayName} not connected');
    }

    try {
      log('CloudSyncService: Starting incremental sync for $filePath');

      // Determine sync direction based on change detection
      delta_sync.SyncDirection syncDirection;
      if (direction == SyncDirection.upload) {
        syncDirection = delta_sync.SyncDirection.upload;
      } else if (direction == SyncDirection.download) {
        syncDirection = delta_sync.SyncDirection.download;
      } else {
        // For bidirectional, detect which direction is needed
        final fileChange = await _changeTracking.detectFileChange(
          filePath: filePath,
          provider: provider,
          providerInterface: providerInterface,
        );

        if (fileChange == null) {
          return TransferResult(
            success: true,
            message: 'No changes detected',
            transferId: 'no_changes_${DateTime.now().millisecondsSinceEpoch}',
          );
        }

        // For now, default to upload for bidirectional
        syncDirection = delta_sync.SyncDirection.upload;
      }

      final result = await _incrementalTransfer.syncFile(
        filePath: filePath,
        provider: provider,
        providerInterface: providerInterface,
        direction: syncDirection,
        forceFullSync: forceFullSync,
        onProgress: onProgress,
      );

      log('CloudSyncService: Incremental sync completed for $filePath');
      return result;
    } catch (e, stackTrace) {
      log(
        'CloudSyncService: Incremental sync failed for $filePath: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Perform incremental sync for multiple files
  Future<List<TransferResult>> syncFilesIncremental({
    required List<String> filePaths,
    required CloudProvider provider,
    SyncDirection direction = SyncDirection.bidirectional,
    bool forceFullSync = false,
    Function(String filePath, TransferProgress progress)? onProgress,
  }) async {
    if (!_isInitialized) await initialize();

    final providerInterface = _connectedProviders[provider];
    if (providerInterface == null) {
      throw StateError('Provider ${provider.displayName} not connected');
    }

    try {
      log(
        'CloudSyncService: Starting batch incremental sync for ${filePaths.length} files',
      );

      // Determine sync direction
      delta_sync.SyncDirection syncDirection;
      if (direction == SyncDirection.upload) {
        syncDirection = delta_sync.SyncDirection.upload;
      } else if (direction == SyncDirection.download) {
        syncDirection = delta_sync.SyncDirection.download;
      } else {
        // For bidirectional, default to upload for now
        syncDirection = delta_sync.SyncDirection.upload;
      }

      final results = await _incrementalTransfer.syncFiles(
        filePaths: filePaths,
        provider: provider,
        providerInterface: providerInterface,
        direction: syncDirection,
        forceFullSync: forceFullSync,
        onProgress: onProgress,
      );

      log('CloudSyncService: Batch incremental sync completed');
      return results;
    } catch (e, stackTrace) {
      log(
        'CloudSyncService: Batch incremental sync failed: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Detect changes in a directory and optionally sync them
  Future<List<file_change_models.FileChange>> detectDirectoryChanges({
    required String directoryPath,
    required CloudProvider provider,
    List<String> fileExtensions = const [],
    bool recursive = true,
    bool autoSync = false,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      log('CloudSyncService: Detecting changes in $directoryPath');

      final changes = await _changeTracking.detectDirectoryChanges(
        directoryPath: directoryPath,
        provider: provider,
        fileExtensions: fileExtensions,
        recursive: recursive,
      );

      if (autoSync && changes.isNotEmpty) {
        log(
          'CloudSyncService: Auto-syncing ${changes.length} detected changes',
        );

        final filePaths = changes.map((change) => change.filePath).toList();
        await syncFilesIncremental(
          filePaths: filePaths,
          provider: provider,
          direction: SyncDirection.upload,
        );
      }

      return changes;
    } catch (e, stackTrace) {
      log(
        'CloudSyncService: Error detecting directory changes: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get transfer statistics for incremental sync
  TransferStats getIncrementalSyncStats() {
    return _incrementalTransfer.getStats();
  }

  /// Set bandwidth limit for transfers
  void setBandwidthLimit(int bytesPerSecond) {
    _incrementalTransfer.setBandwidthLimit(bytesPerSecond);
  }

  /// Pause all incremental transfers
  Future<void> pauseIncrementalSync() async {
    await _incrementalTransfer.pauseAll();
  }

  /// Resume all incremental transfers
  Future<void> resumeIncrementalSync() async {
    await _incrementalTransfer.resumeAll();
  }

  /// Get progress stream for incremental transfers
  Stream<TransferProgress> get incrementalSyncProgressStream =>
      _incrementalTransfer.progressStream;

  /// Get event stream for incremental transfers
  Stream<TransferEvent> get incrementalSyncEventStream =>
      _incrementalTransfer.eventStream;

  // ENCRYPTED SYNC OPERATIONS

  /// Upload file with encryption to cloud provider
  Future<bool> uploadFileEncrypted({
    required String filePath,
    required String remotePath,
    required CloudProvider provider,
    Map<String, dynamic>? metadata,
    Function(double progress)? onProgress,
  }) async {
    try {
      log(
        'CloudSyncService: Uploading encrypted file $filePath to ${provider.displayName}',
      );

      final providerInterface = _connectedProviders[provider];
      if (providerInterface == null) {
        throw StateError('Provider ${provider.displayName} is not connected');
      }

      // Encrypt the file
      final encryptedResult = await _cloudEncryption.encryptFile(
        filePath: filePath,
        provider: provider,
      );

      // Encrypt metadata if provided
      Map<String, String>? encryptedMetadata;
      if (metadata != null) {
        encryptedMetadata = await _cloudEncryption.encryptMetadata(
          metadata: {
            ...metadata,
            'encryptionInfo': encryptedResult.metadata.toJson(),
          },
          provider: provider,
        );
      }

      // Create temporary encrypted file
      final tempFile = File('$filePath.encrypted.tmp');
      await tempFile.writeAsBytes(encryptedResult.encryptedData);

      try {
        // Upload encrypted file data
        final uploadResult = await providerInterface.uploadFile(
          localFilePath: tempFile.path,
          remoteFilePath: remotePath,
          metadata: encryptedMetadata ?? {},
          onProgress: onProgress,
        );

        if (uploadResult) {
          log(
            'CloudSyncService: Successfully uploaded encrypted file to ${provider.displayName}',
          );
        }

        return uploadResult;
      } finally {
        // Clean up temporary file
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (e, stackTrace) {
      log(
        'CloudSyncService: Error uploading encrypted file: $e',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Download and decrypt file from cloud provider
  Future<bool> downloadFileDecrypted({
    required String remotePath,
    required String localPath,
    required CloudProvider provider,
    Function(double progress)? onProgress,
  }) async {
    try {
      log(
        'CloudSyncService: Downloading encrypted file $remotePath from ${provider.displayName}',
      );

      final providerInterface = _connectedProviders[provider];
      if (providerInterface == null) {
        throw StateError('Provider ${provider.displayName} is not connected');
      }

      // Download encrypted file
      final downloadResult = await providerInterface.downloadFile(
        remoteFilePath: remotePath,
        localFilePath: localPath,
        onProgress: onProgress,
      );

      if (!downloadResult) {
        return false;
      }

      // Get encrypted metadata from provider
      final encryptedMetadata = await providerInterface.getFileMetadata(
        remotePath,
      );
      if (encryptedMetadata == null) {
        throw StateError('No metadata found for encrypted file');
      }

      // Decrypt metadata to get encryption info
      final decryptedMetadata = await _cloudEncryption.decryptMetadata(
        encryptedMetadata: encryptedMetadata.map(
          (k, v) => MapEntry(k, v.toString()),
        ),
      );

      final encryptionInfo =
          decryptedMetadata['encryptionInfo'] as Map<String, dynamic>?;
      if (encryptionInfo == null) {
        throw StateError('No encryption info found in metadata');
      }

      // Read encrypted file data
      final encryptedData = await File(localPath).readAsBytes();

      // Decrypt file
      final fileMetadata = EncryptedFileMetadata.fromJson(encryptionInfo);
      final decryptedData = await _cloudEncryption.decryptFile(
        encryptedData: encryptedData,
        metadata: fileMetadata,
      );

      // Write decrypted data back to file
      await File(localPath).writeAsBytes(decryptedData);

      log(
        'CloudSyncService: Successfully downloaded and decrypted file from ${provider.displayName}',
      );
      return true;
    } catch (e, stackTrace) {
      log(
        'CloudSyncService: Error downloading encrypted file: $e',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Perform encrypted incremental sync
  Future<TransferResult> syncFileIncrementalEncrypted({
    required String filePath,
    required CloudProvider provider,
    delta_sync.SyncDirection direction = delta_sync.SyncDirection.bidirectional,
    bool forceFullSync = false,
    Function(TransferProgress progress)? onProgress,
  }) async {
    try {
      log(
        'CloudSyncService: Starting encrypted incremental sync for $filePath',
      );

      final providerInterface = _connectedProviders[provider];
      if (providerInterface == null) {
        throw StateError('Provider ${provider.displayName} is not connected');
      }

      // Detect file changes
      final fileChange = await _changeTracking.detectFileChange(
        filePath: filePath,
        provider: provider,
        providerInterface: providerInterface,
      );

      if (fileChange == null && !forceFullSync) {
        return TransferResult(
          success: true,
          message: 'No changes detected',
          transferId:
              'encrypted_incremental_${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      // If there are changes, encrypt the changed chunks
      if (fileChange != null && fileChange.changedChunks != null) {
        final encryptedChunks = await _cloudEncryption.encryptFileChunks(
          chunks: fileChange.changedChunks!,
          provider: provider,
        );

        // Store encrypted chunks information
        log(
          'CloudSyncService: Encrypted ${encryptedChunks.length} changed chunks',
        );
      }

      // Use the incremental transfer manager with encryption support
      return await _incrementalTransfer.syncFile(
        filePath: filePath,
        provider: provider,
        providerInterface: providerInterface,
        direction: direction,
        forceFullSync: forceFullSync,
        onProgress: onProgress,
      );
    } catch (e, stackTrace) {
      log(
        'CloudSyncService: Error in encrypted incremental sync: $e',
        stackTrace: stackTrace,
      );
      return TransferResult(
        success: false,
        message: 'Encrypted incremental sync failed: $e',
        transferId: 'error_${DateTime.now().millisecondsSinceEpoch}',
      );
    }
  }

  /// Create encrypted provider key for new connections
  Future<String> createProviderEncryptionKey(CloudProvider provider) async {
    return await _cloudEncryption.createCloudProviderKey(provider);
  }

  /// Create file-specific encryption key
  Future<String> createFileEncryptionKey(
    String filePath,
    CloudProvider provider,
  ) async {
    return await _cloudEncryption.createFileEncryptionKey(filePath, provider);
  }

  /// Check if encryption is available
  Future<bool> isEncryptionAvailable() async {
    return await _cloudEncryption.isEncryptionAvailable();
  }

  /// List all encryption keys for debugging
  Future<List<String>> listEncryptionKeys() async {
    return await _cloudEncryption.listCloudEncryptionKeys();
  }

  // OFFLINE QUEUE MANAGEMENT

  /// Get offline queue statistics
  Future<QueueStatistics> getOfflineQueueStatistics() async {
    return await _offlineQueue.getQueueStatistics();
  }

  /// Get priority statistics for offline queue
  Future<PriorityStatistics> getQueuePriorityStatistics() async {
    return await _offlineQueue.getPriorityStatistics();
  }

  /// Get pending operations in offline queue
  Future<List<QueuedOperation>> getPendingQueuedOperations() async {
    return await _offlineQueue.getPendingOperations();
  }

  /// Get queued operations by status
  Future<List<QueuedOperation>> getQueuedOperationsByStatus(
    QueueOperationStatus status,
  ) async {
    return await _offlineQueue.getOperationsByStatus(status);
  }

  /// Manually retry a failed queued operation
  Future<bool> retryQueuedOperation(String operationId) async {
    try {
      await _offlineQueue.updateOperationStatus(
        operationId: operationId,
        status: QueueOperationStatus.pending,
      );
      log('CloudSyncService: Queued operation $operationId for retry');
      return true;
    } catch (e) {
      log(
        'CloudSyncService: Failed to retry queued operation $operationId: $e',
      );
      return false;
    }
  }

  /// Remove operation from offline queue
  Future<bool> removeQueuedOperation(String operationId) async {
    try {
      final removed = await _offlineQueue.dequeueOperation(operationId);
      if (removed) {
        log('CloudSyncService: Removed operation $operationId from queue');
      }
      return removed;
    } catch (e) {
      log(
        'CloudSyncService: Failed to remove queued operation $operationId: $e',
      );
      return false;
    }
  }

  /// Update operation priority in offline queue
  Future<bool> updateQueuedOperationPriority({
    required String operationId,
    required int newPriority,
  }) async {
    try {
      final updated = await _offlineQueue.updateOperationPriority(
        operationId: operationId,
        newPriority: newPriority,
      );
      if (updated) {
        log(
          'CloudSyncService: Updated operation $operationId priority to $newPriority',
        );
      }
      return updated;
    } catch (e) {
      log('CloudSyncService: Failed to update operation priority: $e');
      return false;
    }
  }

  /// Promote operation to high priority
  Future<bool> promoteOperationToHighPriority(String operationId) async {
    try {
      final promoted = await _offlineQueue.promoteToHighPriority(operationId);
      if (promoted) {
        log(
          'CloudSyncService: Promoted operation $operationId to high priority',
        );
      }
      return promoted;
    } catch (e) {
      log('CloudSyncService: Failed to promote operation to high priority: $e');
      return false;
    }
  }

  /// Demote operation to low priority
  Future<bool> demoteOperationToLowPriority(String operationId) async {
    try {
      final demoted = await _offlineQueue.demoteToLowPriority(operationId);
      if (demoted) {
        log('CloudSyncService: Demoted operation $operationId to low priority');
      }
      return demoted;
    } catch (e) {
      log('CloudSyncService: Failed to demote operation to low priority: $e');
      return false;
    }
  }

  /// Get high priority operations from queue
  Future<List<QueuedOperation>> getHighPriorityQueuedOperations() async {
    return await _offlineQueue.getHighPriorityOperations();
  }

  /// Get operations by specific priority level
  Future<List<QueuedOperation>> getQueuedOperationsByPriority(
    int priority,
  ) async {
    return await _offlineQueue.getOperationsByPriority(priority);
  }

  /// Clear all operations from offline queue
  Future<void> clearOfflineQueue() async {
    try {
      await _offlineQueue.clearQueue();
      log('CloudSyncService: Cleared offline queue');
    } catch (e) {
      log('CloudSyncService: Failed to clear offline queue: $e');
    }
  }

  /// Process queued operations manually (for testing/debugging)
  Future<void> processOfflineQueue() async {
    try {
      if (!await _networkConnectivity.isConnected) {
        log('CloudSyncService: No connectivity available for processing queue');
        return;
      }

      final pendingOps =
          await _offlineQueue.getPendingOperationsByPriorityOrder();
      log(
        'CloudSyncService: Processing ${pendingOps.length} queued operations',
      );

      for (final queuedOp in pendingOps) {
        try {
          // Reconstruct SyncOperation from queued operation
          final syncOp = SyncOperation.fromJson(queuedOp.metadata);

          // Process the operation based on its type
          switch (queuedOp.operationType) {
            case SyncOperationType.upload:
              await _performUpload(syncOp, true);
              break;
            case SyncOperationType.download:
              await _performDownload(syncOp, true);
              break;
            case SyncOperationType.delete:
            case SyncOperationType.metadata:
              // TODO: Implement delete and metadata operations
              log(
                'CloudSyncService: ${queuedOp.operationType} operations not yet implemented',
              );
              break;
          }

          // Mark as completed and remove from queue
          await _offlineQueue.updateOperationStatus(
            operationId: queuedOp.id,
            status: QueueOperationStatus.completed,
          );
          await _offlineQueue.dequeueOperation(queuedOp.id);
        } catch (e) {
          log(
            'CloudSyncService: Failed to process queued operation ${queuedOp.id}: $e',
          );

          // Update retry count and status
          if (queuedOp.retryCount < queuedOp.maxRetries) {
            await _offlineQueue.updateOperationStatus(
              operationId: queuedOp.id,
              status: QueueOperationStatus.retrying,
              errorMessage: e.toString(),
              incrementRetry: true,
            );
          } else {
            await _offlineQueue.updateOperationStatus(
              operationId: queuedOp.id,
              status: QueueOperationStatus.failed,
              errorMessage: 'Max retries exceeded: ${e.toString()}',
            );
          }
        }
      }
    } catch (e) {
      log('CloudSyncService: Error processing offline queue: $e');
    }
  }

  /// Get stream of offline queue status updates
  Stream<QueueStatusUpdate> get offlineQueueStatusStream =>
      _offlineQueue.statusStream;

  /// Get retry manager statistics
  RetryStatistics getRetryStatistics() {
    return _retryManager.getStatistics();
  }

  /// Get active retry operations
  Map<String, RetryContext> get activeRetryOperations =>
      _retryManager.activeRetries;

  /// Cancel an active retry operation
  void cancelRetryOperation(String operationId) {
    _retryManager.cancelRetry(operationId);
  }

  /// Get stream of retry status updates
  Stream<RetryStatusUpdate> get retryStatusStream => _retryManager.statusStream;

  // BACKGROUND PROCESSING CONTROL

  /// Enable or disable background queue processing
  Future<void> setBackgroundProcessingEnabled(bool enabled) async {
    if (_backgroundProcessingEnabled == enabled) return;

    _backgroundProcessingEnabled = enabled;

    if (enabled && _isInitialized) {
      _startBackgroundQueueProcessing();
      log('CloudSyncService: Background queue processing enabled');
    } else {
      _stopBackgroundQueueProcessing();
      log('CloudSyncService: Background queue processing disabled');
    }
  }

  /// Check if background queue processing is enabled
  bool get isBackgroundProcessingEnabled => _backgroundProcessingEnabled;

  /// Manually trigger background queue processing (for testing)
  Future<void> triggerBackgroundProcessing() async {
    if (!_backgroundProcessingEnabled) {
      log('CloudSyncService: Background processing is disabled');
      return;
    }

    if (!await _networkConnectivity.isConnected) {
      log(
        'CloudSyncService: No connectivity available for background processing',
      );
      return;
    }

    log('CloudSyncService: Manually triggering background queue processing');
    await processOfflineQueue();
  }

  /// Dispose resources
  void dispose() {
    _stopAutoSyncTimer();
    _stopBackgroundQueueProcessing();
    _syncStatusController.close();
    _operationController.close();
    _conflictController.close();
    _incrementalTransfer.dispose();
    _changeTracking.dispose();
    _offlineQueue.dispose();
    _retryManager.dispose();
  }
}
