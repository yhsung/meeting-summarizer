import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../interfaces/cloud_sync_interface.dart';
import '../models/cloud_sync/cloud_provider.dart';
import '../models/cloud_sync/sync_status.dart';
import '../models/cloud_sync/sync_conflict.dart' as conflict_models;
import '../models/cloud_sync/sync_operation.dart';
import 'encryption_service.dart';
import 'cloud_providers/cloud_provider_factory.dart';
import 'cloud_providers/cloud_provider_interface.dart';
import 'conflict_detection_service.dart';
import 'conflict_resolution_service.dart' as conflict_resolution_service;
import 'version_management_service.dart';

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
  final Map<CloudProvider, CloudProviderInterface> _connectedProviders = {};
  final Map<String, SyncOperation> _activeOperations = {};
  final Map<String, conflict_models.SyncConflict> _pendingConflicts = {};

  bool _isInitialized = false;
  bool _autoSyncEnabled = true;
  bool _syncPaused = false;
  Duration _syncInterval = const Duration(minutes: 15);
  Timer? _autoSyncTimer;

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

      // Initialize encryption service
      await EncryptionService.initialize();

      // Initialize provider factory
      await _providerFactory.initialize();

      // Initialize conflict resolution services
      await _versionManagement.initialize();

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
    );

    _activeOperations[operation.id] = operation;
    _operationController.add(operation);

    // Execute upload in background
    _executeUpload(operation, encryptBeforeUpload);

    return operation;
  }

  @override
  Future<SyncOperation> downloadFile({
    required String remoteFilePath,
    required String localFilePath,
    required CloudProvider provider,
    bool decryptAfterDownload = true,
  }) async {
    final operation = SyncOperation(
      id: _generateOperationId(),
      type: SyncOperationType.download,
      localFilePath: localFilePath,
      remoteFilePath: remoteFilePath,
      provider: provider,
      status: SyncOperationStatus.queued,
      createdAt: DateTime.now(),
    );

    _activeOperations[operation.id] = operation;
    _operationController.add(operation);

    // Execute download in background
    _executeDownload(operation, decryptAfterDownload);

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

      final providers = provider != null
          ? [provider]
          : _connectedProviders.keys.toList();

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
      operations = operations
          .where((op) => op.createdAt.isAfter(since))
          .toList();
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
    log('CloudSyncService: Sync paused');
  }

  @override
  Future<void> resumeSync() async {
    _syncPaused = false;

    if (_autoSyncEnabled) {
      _startAutoSyncTimer();
    }

    log('CloudSyncService: Sync resumed');
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

  Future<void> _executeUpload(SyncOperation operation, bool encrypt) async {
    try {
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
    } catch (e, stackTrace) {
      log('CloudSyncService: Upload failed: $e', stackTrace: stackTrace);

      final failedOperation = operation.copyWith(
        status: SyncOperationStatus.failed,
        completedAt: DateTime.now(),
        error: e.toString(),
      );

      _activeOperations[operation.id] = failedOperation;
      _operationController.add(failedOperation);
    }
  }

  Future<void> _executeDownload(SyncOperation operation, bool decrypt) async {
    try {
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
    } catch (e, stackTrace) {
      log('CloudSyncService: Download failed: $e', stackTrace: stackTrace);

      final failedOperation = operation.copyWith(
        status: SyncOperationStatus.failed,
        completedAt: DateTime.now(),
        error: e.toString(),
      );

      _activeOperations[operation.id] = failedOperation;
      _operationController.add(failedOperation);
    }
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

  /// Dispose resources
  void dispose() {
    _stopAutoSyncTimer();
    _syncStatusController.close();
    _operationController.close();
    _conflictController.close();
  }
}
