import 'dart:developer';
import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import '../../models/cloud_sync/cloud_provider.dart';
import '../../interfaces/cloud_sync_interface.dart';
import 'cloud_provider_interface.dart';

/// Google Drive cloud provider implementation
class GoogleDriveProvider implements CloudProviderInterface {
  @override
  CloudProvider get provider => CloudProvider.googleDrive;

  Map<String, String> _credentials = {};
  bool _isConnected = false;
  String? _lastError;
  drive.DriveApi? _driveApi;
  http.Client? _httpClient;

  @override
  Future<void> initialize(Map<String, String> credentials) async {
    _credentials = Map.from(credentials);

    // Validate required credentials
    if (!_credentials.containsKey('client_id') ||
        !_credentials.containsKey('client_secret')) {
      throw ArgumentError(
        'Google Drive requires client_id and client_secret credentials',
      );
    }

    log('GoogleDriveProvider: Initialized with OAuth credentials');
  }

  @override
  Future<bool> connect() async {
    try {
      log('GoogleDriveProvider: Connecting to Google Drive...');

      // Create OAuth2 client identifier
      final clientId = ClientId(
        _credentials['client_id']!,
        _credentials['client_secret']!,
      );

      // Define scopes for Google Drive access
      const scopes = [drive.DriveApi.driveFileScope];

      // Get user consent (this would typically open a browser for OAuth flow)
      // For now, we'll use a refresh token if provided, or simulate the flow
      if (_credentials.containsKey('refresh_token')) {
        // Use existing refresh token
        final accessCredentials = AccessCredentials(
          AccessToken(
            'Bearer',
            'dummy-token',
            DateTime.now().add(Duration(hours: 1)),
          ),
          _credentials['refresh_token'],
          scopes,
        );

        _httpClient = autoRefreshingClient(
          clientId,
          accessCredentials,
          http.Client(),
        );
      } else {
        // For development/testing purposes, create a mock client
        // In production, this would use clientViaUserConsent
        _httpClient = http.Client();
        log('GoogleDriveProvider: Using mock client for development');
      }

      // Initialize Drive API client
      _driveApi = drive.DriveApi(_httpClient!);

      // Test the connection by getting user info
      await _testApiConnection();

      _isConnected = true;
      log('GoogleDriveProvider: Successfully connected to Google Drive');
      return true;
    } catch (e) {
      _lastError = e.toString();
      _isConnected = false;
      log('GoogleDriveProvider: Connection failed: $e');
      return false;
    }
  }

  /// Test API connection by making a simple API call
  Future<void> _testApiConnection() async {
    try {
      // Try to get information about the user's Google Drive
      final about = await _driveApi!.about.get($fields: 'user,storageQuota');
      log(
        'GoogleDriveProvider: Connected as ${about.user?.displayName ?? "unknown user"}',
      );
    } catch (e) {
      // If we can't get user info, we may still be able to access files
      // So we'll try a simple file list instead
      try {
        await _driveApi!.files.list(pageSize: 1);
        log('GoogleDriveProvider: API connection verified via file list');
      } catch (listError) {
        throw Exception(
          'Failed to verify Google Drive API connection: $e, $listError',
        );
      }
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      _httpClient?.close();
      _httpClient = null;
      _driveApi = null;
      _isConnected = false;
      log('GoogleDriveProvider: Disconnected from Google Drive');
    } catch (e) {
      log('GoogleDriveProvider: Error during disconnect: $e');
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
      if (!_isConnected || _driveApi == null) {
        throw StateError('Not connected to Google Drive');
      }

      log('GoogleDriveProvider: Uploading $localFilePath to $remoteFilePath');

      final localFile = File(localFilePath);
      if (!await localFile.exists()) {
        throw FileSystemException('Local file does not exist', localFilePath);
      }

      // Create parent directories if needed
      final parentPath = _getParentPath(remoteFilePath);
      String? parentId;
      if (parentPath.isNotEmpty) {
        parentId = await _ensureDirectoryExists(parentPath);
      }

      // Prepare file metadata
      final fileName = _getFileName(remoteFilePath);
      final fileMetadata = drive.File()
        ..name = fileName
        ..parents = parentId != null ? [parentId] : null;

      // Add custom metadata if provided
      if (metadata.isNotEmpty) {
        fileMetadata.properties = metadata.map(
          (k, v) => MapEntry(k, v.toString()),
        );
      }

      // Read file content
      final fileContent = await localFile.readAsBytes();
      final media = drive.Media(Stream.value(fileContent), fileContent.length);

      // Upload the file
      final uploadedFile = await _driveApi!.files.create(
        fileMetadata,
        uploadMedia: media,
      );

      if (uploadedFile.id != null) {
        log(
          'GoogleDriveProvider: Successfully uploaded ${uploadedFile.name} (ID: ${uploadedFile.id})',
        );
        return true;
      } else {
        throw Exception('Upload failed: No file ID returned');
      }
    } catch (e) {
      _lastError = e.toString();
      log('GoogleDriveProvider: Upload failed: $e');
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
      if (!_isConnected || _driveApi == null) {
        throw StateError('Not connected to Google Drive');
      }

      log('GoogleDriveProvider: Downloading $remoteFilePath to $localFilePath');

      // Find the file by path
      final fileId = await _findFileIdByPath(remoteFilePath);
      if (fileId == null) {
        throw FileSystemException(
          'File not found in Google Drive',
          remoteFilePath,
        );
      }

      // Download the file content
      final media = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      // Ensure local directory exists
      final localFile = File(localFilePath);
      await localFile.parent.create(recursive: true);

      // Write content to local file
      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);

        // Report progress if callback provided
        if (onProgress != null) {
          // We don't have total size here, so we can't calculate exact progress
          // This is a limitation of the Google Drive API for downloads
          onProgress(0.5); // Report 50% progress as a placeholder
        }
      }

      await localFile.writeAsBytes(bytes);

      if (onProgress != null) {
        onProgress(1.0); // Report completion
      }

      log(
        'GoogleDriveProvider: Successfully downloaded $remoteFilePath (${bytes.length} bytes)',
      );
      return true;
    } catch (e) {
      _lastError = e.toString();
      log('GoogleDriveProvider: Download failed: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteFile(String remoteFilePath) async {
    try {
      if (!_isConnected || _driveApi == null) {
        throw StateError('Not connected to Google Drive');
      }

      log('GoogleDriveProvider: Deleting $remoteFilePath');

      // Find the file by path
      final fileId = await _findFileIdByPath(remoteFilePath);
      if (fileId == null) {
        log(
          'GoogleDriveProvider: File not found for deletion: $remoteFilePath',
        );
        return false;
      }

      // Delete the file
      await _driveApi!.files.delete(fileId);

      log('GoogleDriveProvider: Successfully deleted $remoteFilePath');
      return true;
    } catch (e) {
      _lastError = e.toString();
      log('GoogleDriveProvider: Delete failed: $e');
      return false;
    }
  }

  @override
  Future<bool> fileExists(String remoteFilePath) async {
    try {
      if (!_isConnected || _driveApi == null) {
        return false;
      }

      final fileId = await _findFileIdByPath(remoteFilePath);
      return fileId != null;
    } catch (e) {
      _lastError = e.toString();
      log('GoogleDriveProvider: Error checking file existence: $e');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getFileMetadata(String remoteFilePath) async {
    try {
      if (!_isConnected || _driveApi == null) {
        return null;
      }

      final fileId = await _findFileIdByPath(remoteFilePath);
      if (fileId == null) {
        return null;
      }

      final fileResponse = await _driveApi!.files.get(
        fileId,
        $fields:
            'id,name,size,createdTime,modifiedTime,mimeType,parents,properties,webViewLink,webContentLink',
      );

      final file = fileResponse as drive.File;

      return {
        'id': file.id,
        'name': file.name,
        'size': file.size != null ? int.parse(file.size!) : 0,
        'createdTime': file.createdTime?.toIso8601String(),
        'modifiedTime': file.modifiedTime?.toIso8601String(),
        'mimeType': file.mimeType,
        'parents': file.parents,
        'properties': file.properties ?? {},
        'webViewLink': file.webViewLink,
        'webContentLink': file.webContentLink,
      };
    } catch (e) {
      _lastError = e.toString();
      log('GoogleDriveProvider: Error getting file metadata: $e');
      return null;
    }
  }

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? directoryPath,
    bool recursive = false,
  }) async {
    try {
      if (!_isConnected || _driveApi == null) {
        return [];
      }

      // Get parent directory ID
      String? parentId = 'root';
      if (directoryPath != null && directoryPath.isNotEmpty) {
        parentId = await _findFileIdByPath(directoryPath);
        if (parentId == null) {
          return []; // Directory not found
        }
      }

      final result = <CloudFileInfo>[];

      if (recursive) {
        await _listFilesRecursive(parentId, directoryPath ?? '', result);
      } else {
        await _listFilesInDirectory(parentId, directoryPath ?? '', result);
      }

      return result;
    } catch (e) {
      _lastError = e.toString();
      log('GoogleDriveProvider: Error listing files: $e');
      return [];
    }
  }

  /// List files in a specific directory (non-recursive)
  Future<void> _listFilesInDirectory(
    String parentId,
    String basePath,
    List<CloudFileInfo> result,
  ) async {
    String? pageToken;

    do {
      final fileList = await _driveApi!.files.list(
        q: "'$parentId' in parents and trashed=false",
        pageSize: 100,
        pageToken: pageToken,
        $fields:
            'nextPageToken,files(id,name,size,createdTime,modifiedTime,mimeType)',
      );

      if (fileList.files != null) {
        for (final file in fileList.files!) {
          final filePath =
              basePath.isEmpty ? file.name! : '$basePath/${file.name!}';
          final isDirectory =
              file.mimeType == 'application/vnd.google-apps.folder';

          result.add(
            CloudFileInfo(
              path: filePath,
              name: file.name!,
              size: file.size != null ? int.parse(file.size!) : 0,
              modifiedAt: file.modifiedTime ?? DateTime.now(),
              isDirectory: isDirectory,
              mimeType: file.mimeType,
              metadata: {
                'googleDriveFile': {
                  'id': file.id,
                  'mimeType': file.mimeType,
                  'createdTime': file.createdTime?.toIso8601String(),
                  'modifiedTime': file.modifiedTime?.toIso8601String(),
                },
              },
            ),
          );
        }
      }

      pageToken = fileList.nextPageToken;
    } while (pageToken != null);
  }

  /// List files recursively
  Future<void> _listFilesRecursive(
    String parentId,
    String basePath,
    List<CloudFileInfo> result,
  ) async {
    await _listFilesInDirectory(parentId, basePath, result);

    // Find all directories in the current level and recurse into them
    final directories = result
        .where(
          (file) =>
              file.isDirectory &&
              file.path.startsWith(basePath) &&
              file.path.split('/').length ==
                  (basePath.isEmpty ? 1 : basePath.split('/').length + 1),
        )
        .toList();

    for (final directory in directories) {
      final dirId = await _findFileIdByPath(directory.path);
      if (dirId != null) {
        await _listFilesRecursive(dirId, directory.path, result);
      }
    }
  }

  @override
  Future<CloudStorageQuota> getStorageQuota() async {
    try {
      if (!_isConnected || _driveApi == null) {
        return CloudStorageQuota(
          totalBytes: 15 * 1024 * 1024 * 1024, // Default 15GB
          usedBytes: 0,
          availableBytes: 15 * 1024 * 1024 * 1024,
          provider: provider,
        );
      }

      final about = await _driveApi!.about.get($fields: 'storageQuota');
      final quota = about.storageQuota;

      if (quota != null) {
        final total = quota.limit != null
            ? int.parse(quota.limit!)
            : 15 * 1024 * 1024 * 1024;
        final used = quota.usage != null ? int.parse(quota.usage!) : 0;

        return CloudStorageQuota(
          totalBytes: total,
          usedBytes: used,
          availableBytes: total - used,
          provider: provider,
        );
      } else {
        // Fallback to default values
        return CloudStorageQuota(
          totalBytes: 15 * 1024 * 1024 * 1024, // 15GB
          usedBytes: 0,
          availableBytes: 15 * 1024 * 1024 * 1024,
          provider: provider,
        );
      }
    } catch (e) {
      _lastError = e.toString();
      log('GoogleDriveProvider: Error getting storage quota: $e');
      return CloudStorageQuota(
        totalBytes: 15 * 1024 * 1024 * 1024, // Default 15GB
        usedBytes: 0,
        availableBytes: 15 * 1024 * 1024 * 1024,
        provider: provider,
      );
    }
  }

  @override
  Future<DateTime?> getFileModificationTime(String remoteFilePath) async {
    try {
      final metadata = await getFileMetadata(remoteFilePath);
      if (metadata != null && metadata['modifiedTime'] != null) {
        return DateTime.parse(metadata['modifiedTime'] as String);
      }
      return null;
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }

  @override
  Future<int?> getFileSize(String remoteFilePath) async {
    try {
      final metadata = await getFileMetadata(remoteFilePath);
      if (metadata != null && metadata['size'] != null) {
        return metadata['size'] as int;
      }
      return null;
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }

  @override
  Future<bool> createDirectory(String directoryPath) async {
    try {
      if (!_isConnected || _driveApi == null) {
        return false;
      }

      final directoryId = await _ensureDirectoryExists(directoryPath);
      return directoryId != null;
    } catch (e) {
      _lastError = e.toString();
      log('GoogleDriveProvider: Error creating directory: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteDirectory(String directoryPath) async {
    try {
      if (!_isConnected || _driveApi == null) {
        return false;
      }

      final directoryId = await _findFileIdByPath(directoryPath);
      if (directoryId == null) {
        return false; // Directory doesn't exist
      }

      await _driveApi!.files.delete(directoryId);
      log('GoogleDriveProvider: Successfully deleted directory $directoryPath');
      return true;
    } catch (e) {
      _lastError = e.toString();
      log('GoogleDriveProvider: Error deleting directory: $e');
      return false;
    }
  }

  @override
  Future<bool> moveFile({
    required String fromPath,
    required String toPath,
  }) async {
    try {
      if (!_isConnected || _driveApi == null) {
        return false;
      }

      final fileId = await _findFileIdByPath(fromPath);
      if (fileId == null) {
        return false;
      }

      // Handle renaming vs moving to different directory
      final newFileName = _getFileName(toPath);
      final newParentPath = _getParentPath(toPath);

      final updates = drive.File()..name = newFileName;

      // If moving to a different directory, update parent
      if (newParentPath != _getParentPath(fromPath)) {
        final newParentId = await _ensureDirectoryExists(newParentPath);
        if (newParentId != null) {
          updates.parents = [newParentId];
        }
      }

      await _driveApi!.files.update(updates, fileId);
      log('GoogleDriveProvider: Successfully moved $fromPath to $toPath');
      return true;
    } catch (e) {
      _lastError = e.toString();
      log('GoogleDriveProvider: Error moving file: $e');
      return false;
    }
  }

  @override
  Future<bool> copyFile({
    required String fromPath,
    required String toPath,
  }) async {
    try {
      if (!_isConnected || _driveApi == null) {
        return false;
      }

      final fileId = await _findFileIdByPath(fromPath);
      if (fileId == null) {
        return false;
      }

      final newFileName = _getFileName(toPath);
      final newParentPath = _getParentPath(toPath);

      final copyMetadata = drive.File()..name = newFileName;

      if (newParentPath.isNotEmpty) {
        final newParentId = await _ensureDirectoryExists(newParentPath);
        if (newParentId != null) {
          copyMetadata.parents = [newParentId];
        }
      }

      await _driveApi!.files.copy(copyMetadata, fileId);
      log('GoogleDriveProvider: Successfully copied $fromPath to $toPath');
      return true;
    } catch (e) {
      _lastError = e.toString();
      log('GoogleDriveProvider: Error copying file: $e');
      return false;
    }
  }

  @override
  Future<String?> getShareableLink(String remoteFilePath) async {
    try {
      if (!_isConnected || _driveApi == null) {
        return null;
      }

      final fileId = await _findFileIdByPath(remoteFilePath);
      if (fileId == null) {
        return null;
      }

      // Make the file publicly readable
      final permission = drive.Permission()
        ..role = 'reader'
        ..type = 'anyone';

      await _driveApi!.permissions.create(permission, fileId);

      // Get the shareable link
      final metadata = await getFileMetadata(remoteFilePath);
      return metadata?['webViewLink'] as String?;
    } catch (e) {
      _lastError = e.toString();
      log('GoogleDriveProvider: Error creating shareable link: $e');
      return null;
    }
  }

  @override
  Future<List<CloudFileChange>> getRemoteChanges({
    DateTime? since,
    String? directoryPath,
  }) async {
    try {
      if (!_isConnected || _driveApi == null) {
        return [];
      }

      // Google Drive doesn't provide a direct "changes since" API for files by path
      // We would need to implement change tracking using the Changes API
      // For now, return an empty list as this is a complex feature
      log('GoogleDriveProvider: Change detection not yet implemented');
      return [];
    } catch (e) {
      _lastError = e.toString();
      log('GoogleDriveProvider: Error getting remote changes: $e');
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
  }

  @override
  Future<bool> testConnection() async {
    try {
      if (!_isConnected || _driveApi == null) {
        return false;
      }

      // Test connection by making a simple API call
      await _testApiConnection();
      return true;
    } catch (e) {
      _lastError = e.toString();
      log('GoogleDriveProvider: Connection test failed: $e');
      return false;
    }
  }

  @override
  String? getLastError() => _lastError;

  // Helper methods

  /// Get parent directory path from a file path
  String _getParentPath(String filePath) {
    final lastSlash = filePath.lastIndexOf('/');
    if (lastSlash == -1) return '';
    return filePath.substring(0, lastSlash);
  }

  /// Get filename from a file path
  String _getFileName(String filePath) {
    final lastSlash = filePath.lastIndexOf('/');
    if (lastSlash == -1) return filePath;
    return filePath.substring(lastSlash + 1);
  }

  /// Find file ID by path
  Future<String?> _findFileIdByPath(String path) async {
    try {
      if (path.isEmpty) return null;

      final pathParts =
          path.split('/').where((part) => part.isNotEmpty).toList();
      if (pathParts.isEmpty) return null;

      String? currentParentId = 'root';

      // Traverse the path to find the file
      for (int i = 0; i < pathParts.length; i++) {
        final partName = pathParts[i];
        final isLastPart = i == pathParts.length - 1;

        // Build query to find files/folders with this name in the current parent
        String query =
            "name='$partName' and '$currentParentId' in parents and trashed=false";
        if (!isLastPart) {
          query += " and mimeType='application/vnd.google-apps.folder'";
        }

        final fileList = await _driveApi!.files.list(
          q: query,
          pageSize: 10,
          $fields: 'files(id,name,mimeType)',
        );

        if (fileList.files == null || fileList.files!.isEmpty) {
          return null; // Path not found
        }

        // Use the first match
        final file = fileList.files!.first;
        currentParentId = file.id;

        if (isLastPart) {
          return file.id; // Found the target file
        }
      }

      return null;
    } catch (e) {
      log('GoogleDriveProvider: Error finding file by path: $e');
      return null;
    }
  }

  /// Ensure directory exists and return its ID
  Future<String?> _ensureDirectoryExists(String dirPath) async {
    try {
      final pathParts =
          dirPath.split('/').where((part) => part.isNotEmpty).toList();
      if (pathParts.isEmpty) return 'root';

      String? currentParentId = 'root';

      for (final partName in pathParts) {
        // Check if directory already exists
        final query =
            "name='$partName' and '$currentParentId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false";
        final fileList = await _driveApi!.files.list(
          q: query,
          pageSize: 1,
          $fields: 'files(id)',
        );

        if (fileList.files != null && fileList.files!.isNotEmpty) {
          // Directory exists
          currentParentId = fileList.files!.first.id;
        } else {
          // Create directory
          final folderMetadata = drive.File()
            ..name = partName
            ..mimeType = 'application/vnd.google-apps.folder'
            ..parents = [currentParentId!];

          final createdFolder = await _driveApi!.files.create(folderMetadata);
          currentParentId = createdFolder.id;
        }
      }

      return currentParentId;
    } catch (e) {
      log('GoogleDriveProvider: Error ensuring directory exists: $e');
      return null;
    }
  }
}
