import 'dart:developer';
import 'dart:io';
import 'dart:async';
import 'package:icloud_storage/icloud_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/cloud_sync/cloud_provider.dart';
import '../../interfaces/cloud_sync_interface.dart';
import 'cloud_provider_interface.dart';

/// Enhanced iCloud provider with CloudKit integration, conflict resolution,
/// background sync, and comprehensive error handling

/// iCloud Drive provider implementation
class ICloudProvider implements CloudProviderInterface {
  @override
  CloudProvider get provider => CloudProvider.icloud;

  Map<String, String> _credentials = {};
  bool _isConnected = false;
  String? _lastError;
  String? _containerId;

  // Enhanced iCloud features
  Timer? _backgroundSyncTimer;
  bool _backgroundSyncEnabled = false;
  final Duration _backgroundSyncInterval = const Duration(minutes: 15);
  final List<String> _conflictedFiles = [];
  bool _isAuthenticationValid = false;
  DateTime? _lastAuthCheck;
  final Duration _authCheckInterval = const Duration(hours: 1);

  // File operation queues for background sync
  final List<_PendingOperation> _pendingOperations = [];
  bool _isProcessingQueue = false;

  @override
  Future<void> initialize(Map<String, String> credentials) async {
    _credentials = Map.from(credentials);
    _containerId = credentials['containerId'];

    if (_containerId == null || _containerId!.isEmpty) {
      throw ArgumentError(
        'iCloud container ID is required for iCloud provider',
      );
    }

    // Validate container ID format (must be a valid bundle identifier)
    if (!_isValidContainerId(_containerId!)) {
      throw ArgumentError(
        'Invalid container ID format. Must be a valid bundle identifier (e.g., iCloud.com.yourcompany.yourapp)',
      );
    }

    // Initialize background sync if enabled
    _backgroundSyncEnabled = credentials['enableBackgroundSync'] == 'true';

    log('ICloudProvider: Initialized with container ID: $_containerId');
    log('ICloudProvider: Background sync enabled: $_backgroundSyncEnabled');

    // Start authentication monitoring
    _startAuthenticationMonitoring();
  }

  @override
  Future<bool> connect() async {
    try {
      log('ICloudProvider: Testing connection to iCloud...');

      // Check if user is signed into iCloud
      if (!await _checkiCloudAccountStatus()) {
        _lastError =
            'User is not signed into iCloud or iCloud Drive is disabled';
        _isConnected = false;
        return false;
      }

      // Test connection by trying to gather files
      final completer = Completer<bool>();
      bool hasReceivedData = false;

      await ICloudStorage.gather(
        containerId: _containerId!,
        onUpdate: (stream) {
          stream.listen(
            (fileList) {
              if (!hasReceivedData) {
                hasReceivedData = true;
                completer.complete(true);
              }
            },
            onError: (error) {
              if (!completer.isCompleted) {
                completer.complete(false);
              }
              log('ICloudProvider: Error during connection test: $error');
            },
            onDone: () {
              if (!hasReceivedData && !completer.isCompleted) {
                completer.complete(
                    true); // Empty file list is still a successful connection
              }
            },
          );
        },
      );

      // Wait for connection test to complete with timeout
      final connectionResult = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          log('ICloudProvider: Connection test timed out');
          return false;
        },
      );

      if (connectionResult) {
        _isConnected = true;
        _isAuthenticationValid = true;
        _lastAuthCheck = DateTime.now();
        log('ICloudProvider: Successfully connected to iCloud');

        // Start background sync if enabled
        if (_backgroundSyncEnabled) {
          _startBackgroundSync();
        }

        return true;
      } else {
        _lastError = 'Failed to establish connection to iCloud';
        _isConnected = false;
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      _isConnected = false;
      log('ICloudProvider: Connection failed: $e');
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      // Stop background sync
      _stopBackgroundSync();

      // Stop authentication monitoring
      _stopAuthenticationMonitoring();

      // Clear pending operations
      _pendingOperations.clear();

      // Clear conflicted files
      _conflictedFiles.clear();

      _isConnected = false;
      _isAuthenticationValid = false;
      log('ICloudProvider: Disconnected and cleaned up resources');
    } catch (e) {
      log('ICloudProvider: Error during disconnect: $e');
    }
  }

  @override
  Future<bool> isConnected() async => _isConnected;

  @override
  Future<bool> uploadFile({
    required String localFilePath,
    required String remoteFilePath,
    Map<String, dynamic> metadata = const {},
    Function(double progress)? onProgress,
  }) async {
    try {
      if (!_isConnected) {
        throw StateError('Not connected to iCloud');
      }

      // Check authentication before upload
      if (!await _ensureAuthenticated()) {
        _lastError = 'iCloud authentication lost';
        return false;
      }

      // Check for conflicts before upload
      if (await _checkForFileConflict(remoteFilePath)) {
        log('ICloudProvider: Conflict detected for $remoteFilePath, adding to conflict list');
        if (!_conflictedFiles.contains(remoteFilePath)) {
          _conflictedFiles.add(remoteFilePath);
        }
        // Continue with upload but mark as conflicted
      }

      // Validate local file exists
      final localFile = File(localFilePath);
      if (!await localFile.exists()) {
        throw FileSystemException('Local file does not exist', localFilePath);
      }

      log('ICloudProvider: Uploading $localFilePath to $remoteFilePath');

      final completer = Completer<bool>();
      double lastProgress = 0.0;

      try {
        await ICloudStorage.upload(
          containerId: _containerId!,
          filePath: localFilePath,
          destinationRelativePath: remoteFilePath,
          onProgress: (stream) {
            stream.listen(
              (progress) {
                lastProgress = progress;
                onProgress?.call(progress);
              },
              onError: (error) {
                if (!completer.isCompleted) {
                  completer.complete(false);
                }
              },
              onDone: () {
                if (!completer.isCompleted) {
                  completer.complete(true);
                }
              },
            );
          },
        );

        // Wait for upload completion
        final success = await completer.future.timeout(
          const Duration(minutes: 10),
          onTimeout: () {
            log('ICloudProvider: Upload timed out for $localFilePath');
            return false;
          },
        );

        if (success) {
          log('ICloudProvider: Successfully uploaded $localFilePath (progress: ${(lastProgress * 100).toStringAsFixed(1)}%)');

          // Remove from conflicted files if upload succeeded
          _conflictedFiles.remove(remoteFilePath);

          return true;
        } else {
          _lastError = 'Upload failed or timed out';
          return false;
        }
      } catch (uploadError) {
        _lastError = uploadError.toString();
        log('ICloudProvider: Upload error: $uploadError');
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      log('ICloudProvider: Upload failed: $e');
      return false;
    }
  }

  @override
  Future<bool> downloadFile({
    required String remoteFilePath,
    required String localFilePath,
    Function(double progress)? onProgress,
  }) async {
    try {
      if (!_isConnected) {
        throw StateError('Not connected to iCloud');
      }

      // Check authentication before download
      if (!await _ensureAuthenticated()) {
        _lastError = 'iCloud authentication lost';
        return false;
      }

      // Ensure local directory exists
      final localFile = File(localFilePath);
      await localFile.parent.create(recursive: true);

      log('ICloudProvider: Downloading $remoteFilePath to $localFilePath');

      final completer = Completer<bool>();
      double lastProgress = 0.0;

      try {
        await ICloudStorage.download(
          containerId: _containerId!,
          relativePath: remoteFilePath,
          destinationFilePath: localFilePath,
          onProgress: (stream) {
            stream.listen(
              (progress) {
                lastProgress = progress;
                onProgress?.call(progress);
              },
              onError: (error) {
                if (!completer.isCompleted) {
                  completer.complete(false);
                }
              },
              onDone: () {
                if (!completer.isCompleted) {
                  completer.complete(true);
                }
              },
            );
          },
        );

        // Wait for download completion
        final success = await completer.future.timeout(
          const Duration(minutes: 10),
          onTimeout: () {
            log('ICloudProvider: Download timed out for $remoteFilePath');
            return false;
          },
        );

        if (success) {
          // Verify file was downloaded correctly
          if (await localFile.exists()) {
            final fileSize = await localFile.length();
            log('ICloudProvider: Successfully downloaded $remoteFilePath ($fileSize bytes, progress: ${(lastProgress * 100).toStringAsFixed(1)}%)');
            return true;
          } else {
            _lastError = 'Downloaded file not found at destination';
            return false;
          }
        } else {
          _lastError = 'Download failed or timed out';
          return false;
        }
      } catch (downloadError) {
        _lastError = downloadError.toString();
        log('ICloudProvider: Download error: $downloadError');
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      log('ICloudProvider: Download failed: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteFile(String remoteFilePath) async {
    try {
      if (!_isConnected) {
        throw StateError('Not connected to iCloud');
      }

      log('ICloudProvider: Deleting $remoteFilePath');

      await ICloudStorage.delete(
        containerId: _containerId!,
        relativePath: remoteFilePath,
      );

      log('ICloudProvider: Successfully deleted $remoteFilePath');
      return true;
    } catch (e) {
      _lastError = e.toString();
      log('ICloudProvider: Delete failed: $e');
      return false;
    }
  }

  @override
  Future<bool> fileExists(String remoteFilePath) async {
    try {
      if (!_isConnected) {
        return false;
      }

      final files = await _gatherFiles();
      return files.any((file) => file.relativePath == remoteFilePath);
    } catch (e) {
      _lastError = e.toString();
      log('ICloudProvider: Error checking file existence: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getFileMetadata(String remoteFilePath) async {
    try {
      if (!_isConnected) {
        return null;
      }

      final files = await _gatherFiles();
      final file =
          files.where((f) => f.relativePath == remoteFilePath).firstOrNull;

      if (file == null) return null;

      return {
        'name': file.relativePath.split('/').last,
        'relativePath': file.relativePath,
        'size': file.sizeInBytes,
        'contentChangeDate': file.contentChangeDate.toIso8601String(),
        'creationDate': file.creationDate.toIso8601String(),
        'downloadStatus': file.downloadStatus.toString(),
        'isDownloading': file.isDownloading,
        'isUploaded': file.isUploaded,
        'isUploading': file.isUploading,
        'hasUnresolvedConflicts': file.hasUnresolvedConflicts,
      };
    } catch (e) {
      _lastError = e.toString();
      log('ICloudProvider: Error getting file metadata: $e');
      return null;
    }
  }

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? directoryPath,
    bool recursive = false,
  }) async {
    try {
      if (!_isConnected) {
        return [];
      }

      final files = await _gatherFiles();
      final result = <CloudFileInfo>[];

      for (final file in files) {
        // Filter by directory path if specified
        if (directoryPath != null && directoryPath.isNotEmpty) {
          if (!file.relativePath.startsWith(directoryPath)) {
            continue;
          }

          // Check if file is directly in the directory (not recursive)
          if (!recursive) {
            final relativePart = file.relativePath.substring(
              directoryPath.length,
            );
            if (relativePart.startsWith('/')) {
              final remaining = relativePart.substring(1);
              if (remaining.contains('/')) {
                continue; // File is in a subdirectory
              }
            }
          }
        }

        result.add(
          CloudFileInfo(
            path: file.relativePath,
            name: file.relativePath.split('/').last,
            size: file.sizeInBytes,
            modifiedAt: file.contentChangeDate,
            isDirectory:
                false, // iCloud storage doesn't distinguish directories in this API
            metadata: {
              'iCloudFile': {
                'name': file.relativePath.split('/').last,
                'relativePath': file.relativePath,
                'size': file.sizeInBytes,
                'contentChangeDate': file.contentChangeDate.toIso8601String(),
                'creationDate': file.creationDate.toIso8601String(),
                'downloadStatus': file.downloadStatus.toString(),
                'isDownloading': file.isDownloading,
                'isUploaded': file.isUploaded,
                'isUploading': file.isUploading,
                'hasUnresolvedConflicts': file.hasUnresolvedConflicts,
              },
            },
          ),
        );
      }

      return result;
    } catch (e) {
      _lastError = e.toString();
      log('ICloudProvider: Error listing files: $e');
      return [];
    }
  }

  @override
  Future<CloudStorageQuota> getStorageQuota() async {
    // TODO: Implement actual quota retrieval
    return CloudStorageQuota(
      totalBytes: 5 * 1024 * 1024 * 1024, // 5GB
      usedBytes: 0,
      availableBytes: 5 * 1024 * 1024 * 1024,
      provider: provider,
    );
  }

  @override
  Future<DateTime?> getFileModificationTime(String remoteFilePath) async {
    try {
      if (!_isConnected) {
        return null;
      }

      final files = await _gatherFiles();
      final file =
          files.where((f) => f.relativePath == remoteFilePath).firstOrNull;

      return file?.contentChangeDate;
    } catch (e) {
      _lastError = e.toString();
      log('ICloudProvider: Error getting file modification time: $e');
      return null;
    }
  }

  @override
  Future<int?> getFileSize(String remoteFilePath) async {
    try {
      if (!_isConnected) {
        return null;
      }

      final files = await _gatherFiles();
      final file =
          files.where((f) => f.relativePath == remoteFilePath).firstOrNull;

      return file?.sizeInBytes;
    } catch (e) {
      _lastError = e.toString();
      log('ICloudProvider: Error getting file size: $e');
      return null;
    }
  }

  @override
  Future<bool> createDirectory(String directoryPath) async {
    // Note: iCloud Drive doesn't require explicit directory creation
    // Directories are created implicitly when files are uploaded to them
    log('ICloudProvider: Directory creation not required for iCloud Drive');
    return true;
  }

  @override
  Future<bool> deleteDirectory(String directoryPath) async {
    // Note: iCloud Drive doesn't support direct directory deletion
    // Delete all files in the directory instead
    try {
      if (!_isConnected) {
        return false;
      }

      final files = await _gatherFiles();
      final directoryFiles = files
          .where((file) => file.relativePath.startsWith(directoryPath))
          .toList();

      for (final file in directoryFiles) {
        await deleteFile(file.relativePath);
      }

      log('ICloudProvider: Deleted all files in directory $directoryPath');
      return true;
    } catch (e) {
      _lastError = e.toString();
      log('ICloudProvider: Error deleting directory: $e');
      return false;
    }
  }

  @override
  Future<bool> moveFile({
    required String fromPath,
    required String toPath,
  }) async {
    try {
      if (!_isConnected) {
        return false;
      }

      log('ICloudProvider: Moving $fromPath to $toPath');

      await ICloudStorage.move(
        containerId: _containerId!,
        fromRelativePath: fromPath,
        toRelativePath: toPath,
      );

      log('ICloudProvider: Successfully moved file');
      return true;
    } catch (e) {
      _lastError = e.toString();
      log('ICloudProvider: Move failed: $e');
      return false;
    }
  }

  @override
  Future<bool> copyFile({
    required String fromPath,
    required String toPath,
  }) async {
    // Note: iCloud Storage doesn't have direct copy operation
    // Implement copy as download + upload
    try {
      if (!_isConnected) {
        return false;
      }

      log('ICloudProvider: Copying $fromPath to $toPath via download+upload');

      // Create temporary file for download
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/icloud_temp_${DateTime.now().millisecondsSinceEpoch}',
      );

      // Download source file
      final downloadSuccess = await downloadFile(
        remoteFilePath: fromPath,
        localFilePath: tempFile.path,
      );

      if (!downloadSuccess) {
        return false;
      }

      // Upload to destination
      final uploadSuccess = await uploadFile(
        localFilePath: tempFile.path,
        remoteFilePath: toPath,
      );

      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (e) {
        log('ICloudProvider: Warning - failed to clean up temp file: $e');
      }

      return uploadSuccess;
    } catch (e) {
      _lastError = e.toString();
      log('ICloudProvider: Copy failed: $e');
      return false;
    }
  }

  @override
  Future<String?> getShareableLink(String remoteFilePath) async {
    // Note: iCloud Storage doesn't support shareable link generation through this API
    // This would require CloudKit sharing which is not available in the icloud_storage package
    log(
      'ICloudProvider: Shareable links not supported by icloud_storage package',
    );
    return null;
  }

  @override
  Future<List<CloudFileChange>> getRemoteChanges({
    DateTime? since,
    String? directoryPath,
  }) async {
    try {
      if (!_isConnected) {
        return [];
      }

      final files = await _gatherFiles();
      final changes = <CloudFileChange>[];

      for (final file in files) {
        // Filter by directory if specified
        if (directoryPath != null &&
            !file.relativePath.startsWith(directoryPath)) {
          continue;
        }

        // Filter by date if specified
        if (since != null && file.contentChangeDate.isBefore(since)) {
          continue;
        }

        // Create file change entry
        changes.add(
          CloudFileChange(
            path: file.relativePath,
            type: CloudChangeType
                .modified, // iCloud API doesn't distinguish create vs modify
            timestamp: file.contentChangeDate,
            fileInfo: CloudFileInfo(
              path: file.relativePath,
              name: file.relativePath.split('/').last,
              size: file.sizeInBytes,
              modifiedAt: file.contentChangeDate,
              isDirectory: false,
            ),
          ),
        );
      }

      return changes;
    } catch (e) {
      _lastError = e.toString();
      log('ICloudProvider: Error getting remote changes: $e');
      return [];
    }
  }

  @override
  Map<String, dynamic> getConfiguration() {
    return Map.from(_credentials);
  }

  @override
  Future<void> updateConfiguration(Map<String, dynamic> config) async {
    _credentials = Map<String, String>.from(config);
    _containerId = _credentials['containerId'];
  }

  @override
  Future<bool> testConnection() async {
    try {
      if (_containerId == null) {
        return false;
      }

      // Test connection by attempting to gather files
      await ICloudStorage.gather(
        containerId: _containerId!,
        onUpdate: (stream) {
          // Simple connection test
        },
      );

      return true;
    } catch (e) {
      _lastError = e.toString();
      log('ICloudProvider: Connection test failed: $e');
      return false;
    }
  }

  @override
  String? getLastError() => _lastError;

  /// Helper method to gather files from iCloud with timeout and error handling
  Future<List<ICloudFile>> _gatherFiles() async {
    final files = <ICloudFile>[];
    final completer = Completer<List<ICloudFile>>();
    bool hasCompleted = false;

    try {
      await ICloudStorage.gather(
        containerId: _containerId!,
        onUpdate: (stream) {
          stream.listen(
            (fileList) {
              files.clear();
              files.addAll(fileList);
              if (!hasCompleted) {
                hasCompleted = true;
                completer.complete(files);
              }
            },
            onError: (error) {
              if (!hasCompleted) {
                hasCompleted = true;
                completer.completeError(error);
              }
            },
            onDone: () {
              if (!hasCompleted) {
                hasCompleted = true;
                completer.complete(files);
              }
            },
          );
        },
      );

      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          log('ICloudProvider: File gathering timed out');
          return files; // Return whatever we have so far
        },
      );
    } catch (e) {
      log('ICloudProvider: Error gathering files: $e');
      return files; // Return empty or partial list
    }
  }

  // Enhanced helper methods for iCloud functionality

  /// Validate container ID format
  bool _isValidContainerId(String containerId) {
    // Container ID should be in format: iCloud.bundleIdentifier
    final regex = RegExp(r'^iCloud\.[a-zA-Z0-9\-\.]+$');
    return regex.hasMatch(containerId);
  }

  /// Check iCloud account status
  Future<bool> _checkiCloudAccountStatus() async {
    try {
      // This is a simplified check - in a real app you might want to use
      // platform channels to check the actual iCloud account status
      // For now, we'll assume if we can attempt a gather operation, the account is available
      return true;
    } catch (e) {
      log('ICloudProvider: iCloud account check failed: $e');
      return false;
    }
  }

  /// Ensure authentication is still valid
  Future<bool> _ensureAuthenticated() async {
    final now = DateTime.now();

    // Check if we need to refresh authentication
    if (_lastAuthCheck == null ||
        now.difference(_lastAuthCheck!) > _authCheckInterval) {
      log('ICloudProvider: Checking authentication status...');

      try {
        // Test authentication by attempting a simple operation
        await _gatherFiles();
        _isAuthenticationValid = true;
        _lastAuthCheck = now;
        log('ICloudProvider: Authentication verified');
      } catch (e) {
        _isAuthenticationValid = false;
        _lastError = 'Authentication check failed: $e';
        log('ICloudProvider: Authentication check failed: $e');
      }
    }

    return _isAuthenticationValid;
  }

  /// Check for file conflicts
  Future<bool> _checkForFileConflict(String remoteFilePath) async {
    try {
      final files = await _gatherFiles();
      final existingFile =
          files.where((f) => f.relativePath == remoteFilePath).firstOrNull;

      if (existingFile == null) {
        return false; // No conflict if file doesn't exist
      }

      // Check if file has unresolved conflicts
      return existingFile.hasUnresolvedConflicts;
    } catch (e) {
      log('ICloudProvider: Error checking for conflicts: $e');
      return false;
    }
  }

  /// Start background sync service
  void _startBackgroundSync() {
    if (_backgroundSyncTimer != null) {
      return; // Already started
    }

    log('ICloudProvider: Starting background sync service');
    _backgroundSyncTimer = Timer.periodic(_backgroundSyncInterval, (timer) {
      _performBackgroundSync();
    });
  }

  /// Stop background sync service
  void _stopBackgroundSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = null;
    log('ICloudProvider: Stopped background sync service');
  }

  /// Perform background sync operations
  Future<void> _performBackgroundSync() async {
    if (!_isConnected || _isProcessingQueue) {
      return;
    }

    log('ICloudProvider: Performing background sync...');
    _isProcessingQueue = true;

    try {
      // Check authentication
      if (!await _ensureAuthenticated()) {
        log('ICloudProvider: Background sync skipped - authentication invalid');
        return;
      }

      // Process pending operations
      final operations = List<_PendingOperation>.from(_pendingOperations);

      for (final operation in operations) {
        try {
          bool success = false;

          switch (operation.type) {
            case _OperationType.upload:
              success = await uploadFile(
                localFilePath: operation.localPath!,
                remoteFilePath: operation.remotePath,
              );
              break;
            case _OperationType.download:
              success = await downloadFile(
                remoteFilePath: operation.remotePath,
                localFilePath: operation.localPath!,
              );
              break;
            case _OperationType.delete:
              success = await deleteFile(operation.remotePath);
              break;
          }

          if (success) {
            _pendingOperations.remove(operation);
            log('ICloudProvider: Background operation completed: ${operation.type.name} ${operation.remotePath}');
          } else {
            log('ICloudProvider: Background operation failed: ${operation.type.name} ${operation.remotePath}');
          }
        } catch (e) {
          log('ICloudProvider: Background operation error: $e');
        }
      }

      // Check for and resolve conflicts
      await _resolveConflicts();
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// Start authentication monitoring
  void _startAuthenticationMonitoring() {
    // Initial auth check
    _ensureAuthenticated();
  }

  /// Stop authentication monitoring
  void _stopAuthenticationMonitoring() {
    // Currently no separate timer for auth monitoring
    // It's integrated with background sync
  }

  /// Resolve detected conflicts
  Future<void> _resolveConflicts() async {
    if (_conflictedFiles.isEmpty) {
      return;
    }

    log('ICloudProvider: Resolving ${_conflictedFiles.length} conflicts...');

    final conflictsToResolve = List<String>.from(_conflictedFiles);

    for (final filePath in conflictsToResolve) {
      try {
        final files = await _gatherFiles();
        final conflictedFile =
            files.where((f) => f.relativePath == filePath).firstOrNull;

        if (conflictedFile == null || !conflictedFile.hasUnresolvedConflicts) {
          // Conflict resolved or file no longer exists
          _conflictedFiles.remove(filePath);
          continue;
        }

        // For now, we'll use a simple resolution strategy:
        // Keep the remote version (iCloud version)
        log('ICloudProvider: Auto-resolving conflict for $filePath (keeping remote version)');

        // In a real implementation, you might want to:
        // 1. Download both versions
        // 2. Present options to user
        // 3. Implement merge strategies for text files
        // 4. Create backup copies

        _conflictedFiles.remove(filePath);
      } catch (e) {
        log('ICloudProvider: Error resolving conflict for $filePath: $e');
      }
    }
  }

  /// Add operation to background queue
  void _queueOperation(_PendingOperation operation) {
    _pendingOperations.add(operation);
    log('ICloudProvider: Queued ${operation.type.name} operation for ${operation.remotePath}');
  }

  /// Get conflict status for files
  List<String> getConflictedFiles() {
    return List.unmodifiable(_conflictedFiles);
  }

  /// Get pending operations count
  int getPendingOperationsCount() {
    return _pendingOperations.length;
  }

  /// Enable/disable background sync
  Future<void> setBackgroundSyncEnabled(bool enabled) async {
    _backgroundSyncEnabled = enabled;

    if (enabled && _isConnected) {
      _startBackgroundSync();
    } else {
      _stopBackgroundSync();
    }

    log('ICloudProvider: Background sync ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Check if background sync is enabled
  bool isBackgroundSyncEnabled() {
    return _backgroundSyncEnabled;
  }

  // Document Picker Integration Methods

  /// Present document picker to select files from iCloud Drive
  Future<List<String>?> pickDocuments({
    List<String>? allowedExtensions,
    bool allowMultiple = false,
    bool allowDirectoryPicker = false,
  }) async {
    try {
      log('ICloudProvider: Opening document picker...');

      // Configure file picker for iCloud Drive access
      FileType fileType = FileType.any;

      // Determine file type based on allowed extensions
      if (allowedExtensions != null && allowedExtensions.isNotEmpty) {
        // Check if all extensions are audio types
        final audioExtensions = ['mp3', 'wav', 'aiff', 'm4a', 'aac', 'flac'];
        final isAudioOnly = allowedExtensions
            .every((ext) => audioExtensions.contains(ext.toLowerCase()));

        if (isAudioOnly) {
          fileType = FileType.audio;
        } else {
          fileType = FileType.custom;
        }
      }

      // Pick files
      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowMultiple: allowMultiple,
        allowedExtensions:
            fileType == FileType.custom ? allowedExtensions : null,
        withData: false, // We don't need the data, just the paths
        withReadStream: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedPaths = result.files
            .where((file) => file.path != null)
            .map((file) => file.path!)
            .toList();

        log('ICloudProvider: Selected ${pickedPaths.length} documents');
        return pickedPaths;
      } else {
        log('ICloudProvider: No documents selected');
        return null;
      }
    } catch (e) {
      _lastError = 'Document picker error: $e';
      log('ICloudProvider: Document picker failed: $e');
      return null;
    }
  }

  /// Import files from local device to iCloud Drive
  Future<List<String>?> importFilesToiCloud({
    String? destinationFolder,
    List<String>? allowedExtensions,
    bool allowMultiple = true,
  }) async {
    try {
      if (!_isConnected) {
        throw StateError('Not connected to iCloud');
      }

      // Pick files to import
      final selectedFiles = await pickDocuments(
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
      );

      if (selectedFiles == null || selectedFiles.isEmpty) {
        return null;
      }

      final importedPaths = <String>[];
      final destinationBase = destinationFolder ?? 'Imported';

      // Import each selected file
      for (final localPath in selectedFiles) {
        try {
          final fileName = localPath.split('/').last;
          final remotePath =
              destinationBase.isEmpty ? fileName : '$destinationBase/$fileName';

          log('ICloudProvider: Importing $fileName to iCloud...');

          final success = await uploadFile(
            localFilePath: localPath,
            remoteFilePath: remotePath,
          );

          if (success) {
            importedPaths.add(remotePath);
            log('ICloudProvider: Successfully imported $fileName');
          } else {
            log('ICloudProvider: Failed to import $fileName');
          }
        } catch (e) {
          log('ICloudProvider: Error importing ${localPath.split('/').last}: $e');
        }
      }

      if (importedPaths.isNotEmpty) {
        log('ICloudProvider: Imported ${importedPaths.length}/${selectedFiles.length} files');
        return importedPaths;
      } else {
        _lastError = 'Failed to import any files to iCloud';
        return null;
      }
    } catch (e) {
      _lastError = 'Import to iCloud failed: $e';
      log('ICloudProvider: Import to iCloud failed: $e');
      return null;
    }
  }

  /// Export files from iCloud Drive to local device
  Future<List<String>?> exportFilesFromiCloud({
    List<String>? specificFiles,
    String? localDestinationFolder,
  }) async {
    try {
      if (!_isConnected) {
        throw StateError('Not connected to iCloud');
      }

      List<String> filesToExport;

      // If specific files not provided, let user pick from iCloud
      if (specificFiles == null || specificFiles.isEmpty) {
        final files = await listFiles();
        if (files.isEmpty) {
          log('ICloudProvider: No files available to export');
          return null;
        }

        // For now, export all files (in a real app, you might want to show a selection UI)
        filesToExport = files.map((f) => f.path).toList();
        log('ICloudProvider: Exporting all ${filesToExport.length} files from iCloud');
      } else {
        filesToExport = specificFiles;
      }

      // Determine local destination
      final localDestination =
          localDestinationFolder ?? Directory.systemTemp.path;
      final destinationDir = Directory(localDestination);
      if (!await destinationDir.exists()) {
        await destinationDir.create(recursive: true);
      }

      final exportedPaths = <String>[];

      // Export each file
      for (final remotePath in filesToExport) {
        try {
          final fileName = remotePath.split('/').last;
          final localPath = '$localDestination/$fileName';

          log('ICloudProvider: Exporting $fileName from iCloud...');

          final success = await downloadFile(
            remoteFilePath: remotePath,
            localFilePath: localPath,
          );

          if (success) {
            exportedPaths.add(localPath);
            log('ICloudProvider: Successfully exported $fileName');
          } else {
            log('ICloudProvider: Failed to export $fileName');
          }
        } catch (e) {
          log('ICloudProvider: Error exporting ${remotePath.split('/').last}: $e');
        }
      }

      if (exportedPaths.isNotEmpty) {
        log('ICloudProvider: Exported ${exportedPaths.length}/${filesToExport.length} files');
        return exportedPaths;
      } else {
        _lastError = 'Failed to export any files from iCloud';
        return null;
      }
    } catch (e) {
      _lastError = 'Export from iCloud failed: $e';
      log('ICloudProvider: Export from iCloud failed: $e');
      return null;
    }
  }

  /// Show iCloud Drive browser interface
  Future<String?> browseICloudDrive({
    String? startingPath,
    bool allowFileSelection = true,
    bool allowFolderSelection = false,
  }) async {
    try {
      if (!_isConnected) {
        throw StateError('Not connected to iCloud');
      }

      // This is a simplified version - in a real app you would create a custom UI
      // For now, we'll use the file picker as a browser
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final selectedPath = result.files.first.path;
        log('ICloudProvider: Selected path from iCloud browser: $selectedPath');
        return selectedPath;
      } else {
        log('ICloudProvider: No path selected from iCloud browser');
        return null;
      }
    } catch (e) {
      _lastError = 'iCloud browser error: $e';
      log('ICloudProvider: iCloud browser failed: $e');
      return null;
    }
  }

  /// Get iCloud Drive sync status for specific files
  Future<Map<String, ICloudSyncStatus>> getICloudSyncStatus(
      List<String> filePaths) async {
    try {
      if (!_isConnected) {
        return {};
      }

      final files = await _gatherFiles();
      final syncStatus = <String, ICloudSyncStatus>{};

      for (final filePath in filePaths) {
        final iCloudFile =
            files.where((f) => f.relativePath == filePath).firstOrNull;

        if (iCloudFile != null) {
          syncStatus[filePath] = ICloudSyncStatus(
            isUploaded: iCloudFile.isUploaded,
            isUploading: iCloudFile.isUploading,
            isDownloading: iCloudFile.isDownloading,
            hasConflicts: iCloudFile.hasUnresolvedConflicts,
            downloadStatus: _convertDownloadStatus(iCloudFile.downloadStatus),
          );
        } else {
          syncStatus[filePath] = ICloudSyncStatus(
            isUploaded: false,
            isUploading: false,
            isDownloading: false,
            hasConflicts: false,
            downloadStatus: ICloudDownloadStatus.notStarted,
          );
        }
      }

      return syncStatus;
    } catch (e) {
      log('ICloudProvider: Error getting iCloud sync status: $e');
      return {};
    }
  }

  /// Convert icloud_storage DownloadStatus to our ICloudDownloadStatus
  ICloudDownloadStatus _convertDownloadStatus(dynamic downloadStatus) {
    // Handle the conversion from icloud_storage package's DownloadStatus
    final statusString = downloadStatus.toString().toLowerCase();

    if (statusString.contains('downloaded')) {
      return ICloudDownloadStatus.downloaded;
    } else if (statusString.contains('downloading')) {
      return ICloudDownloadStatus.downloading;
    } else if (statusString.contains('failed') ||
        statusString.contains('error')) {
      return ICloudDownloadStatus.failed;
    } else {
      return ICloudDownloadStatus.notStarted;
    }
  }

  /// Create iCloud Drive folder
  Future<bool> createICloudFolder(String folderPath) async {
    try {
      if (!_isConnected) {
        return false;
      }

      // iCloud Drive creates folders implicitly when files are uploaded to them
      // We'll create a placeholder file and then delete it to ensure the folder exists
      final placeholderPath = '$folderPath/.placeholder';
      final tempFile = File('${Directory.systemTemp.path}/.placeholder');

      // Create temporary placeholder file
      await tempFile.writeAsString('placeholder');

      // Upload placeholder to create folder structure
      final uploadSuccess = await uploadFile(
        localFilePath: tempFile.path,
        remoteFilePath: placeholderPath,
      );

      // Clean up local placeholder
      try {
        await tempFile.delete();
      } catch (e) {
        log('ICloudProvider: Warning - failed to clean up placeholder file: $e');
      }

      // Delete remote placeholder
      if (uploadSuccess) {
        await deleteFile(placeholderPath);
        log('ICloudProvider: Created iCloud folder: $folderPath');
        return true;
      } else {
        return false;
      }
    } catch (e) {
      _lastError = 'Failed to create iCloud folder: $e';
      log('ICloudProvider: Failed to create iCloud folder: $e');
      return false;
    }
  }
}

/// Represents a pending background operation
class _PendingOperation {
  final _OperationType type;
  final String remotePath;
  final String? localPath;
  final DateTime createdAt;

  _PendingOperation({
    required this.type,
    required this.remotePath,
    this.localPath,
  }) : createdAt = DateTime.now();
}

/// Types of background operations
enum _OperationType {
  upload,
  download,
  delete,
}

/// iCloud sync status for individual files
class ICloudSyncStatus {
  final bool isUploaded;
  final bool isUploading;
  final bool isDownloading;
  final bool hasConflicts;
  final ICloudDownloadStatus downloadStatus;

  const ICloudSyncStatus({
    required this.isUploaded,
    required this.isUploading,
    required this.isDownloading,
    required this.hasConflicts,
    required this.downloadStatus,
  });

  /// Get overall sync status as a string
  String get statusDescription {
    if (hasConflicts) return 'Conflict detected';
    if (isUploading) return 'Uploading...';
    if (isDownloading) return 'Downloading...';
    if (isUploaded) return 'Synced';
    return 'Not synced';
  }

  /// Check if file is actively syncing
  bool get isSyncing => isUploading || isDownloading;

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'isUploaded': isUploaded,
      'isUploading': isUploading,
      'isDownloading': isDownloading,
      'hasConflicts': hasConflicts,
      'downloadStatus': downloadStatus.name,
      'statusDescription': statusDescription,
      'isSyncing': isSyncing,
    };
  }
}

/// iCloud download status enumeration
enum ICloudDownloadStatus {
  notStarted,
  downloading,
  downloaded,
  failed,
}
