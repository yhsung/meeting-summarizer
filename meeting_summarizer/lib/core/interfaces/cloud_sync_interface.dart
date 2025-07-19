import '../models/cloud_sync/cloud_provider.dart';
import '../models/cloud_sync/sync_status.dart';
import '../models/cloud_sync/sync_conflict.dart';
import '../models/cloud_sync/sync_operation.dart';

/// Interface for cloud synchronization operations
abstract class CloudSyncInterface {
  /// Initialize the cloud sync service
  Future<void> initialize();

  /// Get available cloud providers on the current platform
  Future<List<CloudProvider>> getAvailableProviders();

  /// Connect to a specific cloud provider
  Future<bool> connectProvider(
    CloudProvider provider,
    Map<String, String> credentials,
  );

  /// Disconnect from a cloud provider
  Future<void> disconnectProvider(CloudProvider provider);

  /// Check if a provider is connected and authenticated
  Future<bool> isProviderConnected(CloudProvider provider);

  /// Upload a file to the cloud
  Future<SyncOperation> uploadFile({
    required String localFilePath,
    required String remoteFilePath,
    required CloudProvider provider,
    bool encryptBeforeUpload = true,
    Map<String, dynamic> metadata = const {},
  });

  /// Download a file from the cloud
  Future<SyncOperation> downloadFile({
    required String remoteFilePath,
    required String localFilePath,
    required CloudProvider provider,
    bool decryptAfterDownload = true,
  });

  /// Synchronize all files with the cloud
  Future<List<SyncOperation>> syncAll({
    CloudProvider? provider,
    SyncDirection direction = SyncDirection.bidirectional,
  });

  /// Get sync status for a specific file
  Future<SyncStatus?> getFileSyncStatus(String filePath);

  /// Get overall sync status
  Future<Map<CloudProvider, SyncStatus>> getSyncStatus();

  /// Resolve sync conflicts
  Future<bool> resolveConflict(
    SyncConflict conflict,
    ConflictResolution resolution,
  );

  /// Get pending sync conflicts
  Future<List<SyncConflict>> getPendingConflicts();

  /// Cancel an ongoing sync operation
  Future<void> cancelOperation(String operationId);

  /// Get sync history
  Future<List<SyncOperation>> getSyncHistory({
    CloudProvider? provider,
    DateTime? since,
    int limit = 100,
  });

  /// Check for conflicts before sync
  Future<List<SyncConflict>> checkForConflicts({
    CloudProvider? provider,
    String? filePath,
  });

  /// Get storage quota information
  Future<CloudStorageQuota> getStorageQuota(CloudProvider provider);

  /// Clean up local cache and temporary files
  Future<void> cleanupCache();

  /// Enable/disable auto-sync
  Future<void> setAutoSyncEnabled(bool enabled);

  /// Check if auto-sync is enabled
  Future<bool> isAutoSyncEnabled();

  /// Set sync interval for auto-sync
  Future<void> setSyncInterval(Duration interval);

  /// Get current sync interval
  Future<Duration> getSyncInterval();

  /// Pause sync operations
  Future<void> pauseSync();

  /// Resume sync operations
  Future<void> resumeSync();

  /// Check if sync is currently paused
  Future<bool> isSyncPaused();
}

/// Direction for synchronization operations
enum SyncDirection {
  /// Upload local changes to cloud only
  upload,

  /// Download cloud changes to local only
  download,

  /// Synchronize in both directions
  bidirectional,
}

/// Conflict resolution strategies
enum ConflictResolution {
  /// Keep local version
  keepLocal,

  /// Keep remote version
  keepRemote,

  /// Create both versions with suffix
  keepBoth,

  /// Merge if possible (for text files)
  merge,

  /// Manual resolution required
  manual,
}

/// Cloud storage quota information
class CloudStorageQuota {
  final int totalBytes;
  final int usedBytes;
  final int availableBytes;
  final CloudProvider provider;

  const CloudStorageQuota({
    required this.totalBytes,
    required this.usedBytes,
    required this.availableBytes,
    required this.provider,
  });

  /// Get usage percentage
  double get usagePercentage => usedBytes / totalBytes * 100;

  /// Check if storage is nearly full (>90%)
  bool get isNearlyFull => usagePercentage > 90;

  /// Get formatted total size
  String get formattedTotal => _formatBytes(totalBytes);

  /// Get formatted used size
  String get formattedUsed => _formatBytes(usedBytes);

  /// Get formatted available size
  String get formattedAvailable => _formatBytes(availableBytes);

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
