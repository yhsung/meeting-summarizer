import 'dart:developer';
import 'dart:io';
import 'package:icloud_storage/icloud_storage.dart';
import '../../models/cloud_sync/cloud_provider.dart';
import '../../interfaces/cloud_sync_interface.dart';
import 'cloud_provider_interface.dart';

/// iCloud Drive provider implementation
class ICloudProvider implements CloudProviderInterface {
  @override
  CloudProvider get provider => CloudProvider.icloud;

  Map<String, String> _credentials = {};
  bool _isConnected = false;
  String? _lastError;
  String? _containerId;

  @override
  Future<void> initialize(Map<String, String> credentials) async {
    _credentials = Map.from(credentials);
    _containerId = credentials['containerId'];
    if (_containerId == null || _containerId!.isEmpty) {
      throw ArgumentError(
        'iCloud container ID is required for iCloud provider',
      );
    }
    log('ICloudProvider: Initialized with container ID: $_containerId');
  }

  @override
  Future<bool> connect() async {
    try {
      log('ICloudProvider: Testing connection to iCloud...');

      // Test connection by trying to gather files
      await ICloudStorage.gather(
        containerId: _containerId!,
        onUpdate: (stream) {
          // Simple connection test, we don't need to process the stream
        },
      );

      _isConnected = true;
      log('ICloudProvider: Successfully connected to iCloud');
      return true;
    } catch (e) {
      _lastError = e.toString();
      _isConnected = false;
      log('ICloudProvider: Connection failed: $e');
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    log('ICloudProvider: Disconnected');
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

      log('ICloudProvider: Uploading $localFilePath to $remoteFilePath');

      await ICloudStorage.upload(
        containerId: _containerId!,
        filePath: localFilePath,
        destinationRelativePath: remoteFilePath,
        onProgress: (stream) {
          if (onProgress != null) {
            stream.listen((progress) {
              onProgress(progress);
            });
          }
        },
      );

      log('ICloudProvider: Successfully uploaded $localFilePath');
      return true;
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

      log('ICloudProvider: Downloading $remoteFilePath to $localFilePath');

      await ICloudStorage.download(
        containerId: _containerId!,
        relativePath: remoteFilePath,
        destinationFilePath: localFilePath,
        onProgress: (stream) {
          if (onProgress != null) {
            stream.listen((progress) {
              onProgress(progress);
            });
          }
        },
      );

      log('ICloudProvider: Successfully downloaded $remoteFilePath');
      return true;
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
      final file = files
          .where((f) => f.relativePath == remoteFilePath)
          .firstOrNull;

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
      final file = files
          .where((f) => f.relativePath == remoteFilePath)
          .firstOrNull;

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
      final file = files
          .where((f) => f.relativePath == remoteFilePath)
          .firstOrNull;

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

  /// Helper method to gather files from iCloud
  Future<List<ICloudFile>> _gatherFiles() async {
    final files = <ICloudFile>[];

    await ICloudStorage.gather(
      containerId: _containerId!,
      onUpdate: (stream) {
        stream.listen((fileList) {
          files.clear();
          files.addAll(fileList);
        });
      },
    );

    return files;
  }
}
