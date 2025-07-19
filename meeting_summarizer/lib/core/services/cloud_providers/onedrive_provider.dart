import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../models/cloud_sync/cloud_provider.dart';
import '../../interfaces/cloud_sync_interface.dart';
import 'cloud_provider_interface.dart';

/// OneDrive provider implementation using Microsoft Graph API
class OneDriveProvider implements CloudProviderInterface {
  @override
  CloudProvider get provider => CloudProvider.oneDrive;

  static const String _graphBaseUrl = 'https://graph.microsoft.com/v1.0';

  Map<String, String> _credentials = {};
  bool _isConnected = false;
  String? _lastError;
  String? _accessToken;
  http.Client? _httpClient;

  @override
  Future<void> initialize(Map<String, String> credentials) async {
    _credentials = Map.from(credentials);

    // Validate required credentials
    if (!_credentials.containsKey('client_id') ||
        !_credentials.containsKey('access_token')) {
      throw ArgumentError(
        'OneDrive requires client_id and access_token credentials',
      );
    }

    _accessToken = _credentials['access_token'];
    _httpClient = http.Client();

    log('OneDriveProvider: Initialized with Microsoft Graph API');
  }

  @override
  Future<bool> connect() async {
    try {
      if (_accessToken == null || _httpClient == null) {
        throw StateError('OneDrive provider not properly initialized');
      }

      log('OneDriveProvider: Connecting to Microsoft Graph API...');

      // Test connection by getting user profile
      final response = await _httpClient!.get(
        Uri.parse('$_graphBaseUrl/me'),
        headers: _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final userInfo = json.decode(response.body);
        log(
          'OneDriveProvider: Connected as ${userInfo['displayName'] ?? "unknown user"}',
        );
        _isConnected = true;
        return true;
      } else {
        throw Exception(
          'Failed to connect to OneDrive: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      _lastError = e.toString();
      _isConnected = false;
      log('OneDriveProvider: Connection failed: $e');
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      _httpClient?.close();
      _httpClient = null;
      _accessToken = null;
      _isConnected = false;
      log('OneDriveProvider: Disconnected from OneDrive');
    } catch (e) {
      log('OneDriveProvider: Error during disconnect: $e');
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
      if (!_isConnected || _httpClient == null) {
        throw StateError('Not connected to OneDrive');
      }

      log('OneDriveProvider: Uploading $localFilePath to $remoteFilePath');

      final localFile = File(localFilePath);
      if (!await localFile.exists()) {
        throw FileSystemException('Local file does not exist', localFilePath);
      }

      // Ensure parent directory exists
      final parentPath = _getParentPath(remoteFilePath);
      final fileName = _getFileName(remoteFilePath);

      String? parentId;
      if (parentPath.isEmpty) {
        final rootItem = await _getItemByPath('');
        parentId = rootItem?['id'];
      } else {
        parentId = await _ensureDirectoryExists(parentPath);
      }

      if (parentId == null) {
        throw Exception('Failed to create or find parent directory');
      }

      // Read file content
      final fileContent = await localFile.readAsBytes();

      // For small files (<4MB), use simple upload
      if (fileContent.length < 4 * 1024 * 1024) {
        final response = await _httpClient!.put(
          Uri.parse(
            '$_graphBaseUrl/me/drive/items/$parentId:/$fileName:/content',
          ),
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/octet-stream',
          },
          body: fileContent,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          log('OneDriveProvider: Successfully uploaded $fileName');
          if (onProgress != null) onProgress(1.0);
          return true;
        } else {
          throw Exception(
            'Upload failed: ${response.statusCode} ${response.body}',
          );
        }
      } else {
        // For larger files, we would need to implement upload sessions
        // For now, throw an error for large files
        throw Exception('Large file uploads (>4MB) not yet implemented');
      }
    } catch (e) {
      _lastError = e.toString();
      log('OneDriveProvider: Upload failed: $e');
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
      if (!_isConnected || _httpClient == null) {
        throw StateError('Not connected to OneDrive');
      }

      log('OneDriveProvider: Downloading $remoteFilePath to $localFilePath');

      final item = await _getItemByPath(remoteFilePath);
      if (item == null) {
        throw FileSystemException('File not found on OneDrive', remoteFilePath);
      }

      final downloadUrl = item['@microsoft.graph.downloadUrl'];
      if (downloadUrl == null) {
        throw Exception('No download URL available for file');
      }

      final response = await _httpClient!.get(Uri.parse(downloadUrl));
      if (response.statusCode == 200) {
        final localFile = File(localFilePath);
        await localFile.parent.create(recursive: true);
        await localFile.writeAsBytes(response.bodyBytes);

        if (onProgress != null) onProgress(1.0);
        log('OneDriveProvider: Successfully downloaded $remoteFilePath');
        return true;
      } else {
        throw Exception('Download failed: ${response.statusCode}');
      }
    } catch (e) {
      _lastError = e.toString();
      log('OneDriveProvider: Download failed: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteFile(String remoteFilePath) async {
    try {
      if (!_isConnected || _httpClient == null) {
        throw StateError('Not connected to OneDrive');
      }

      final item = await _getItemByPath(remoteFilePath);
      if (item == null) return false;

      final response = await _httpClient!.delete(
        Uri.parse('$_graphBaseUrl/me/drive/items/${item['id']}'),
        headers: _getAuthHeaders(),
      );

      if (response.statusCode == 204) {
        log('OneDriveProvider: Successfully deleted $remoteFilePath');
        return true;
      }
      return false;
    } catch (e) {
      _lastError = e.toString();
      log('OneDriveProvider: Delete failed: $e');
      return false;
    }
  }

  @override
  Future<bool> fileExists(String remoteFilePath) async {
    try {
      final item = await _getItemByPath(remoteFilePath);
      return item != null && item['file'] != null;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getFileMetadata(String remoteFilePath) async {
    try {
      final item = await _getItemByPath(remoteFilePath);
      if (item == null) return null;

      return {
        'id': item['id'],
        'name': item['name'],
        'size': item['size'] ?? 0,
        'createdAt': item['createdDateTime'],
        'modifiedAt': item['lastModifiedDateTime'],
        'mimeType': item['file']?['mimeType'],
        'webUrl': item['webUrl'],
        'downloadUrl': item['@microsoft.graph.downloadUrl'],
      };
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? directoryPath,
    bool recursive = false,
  }) async {
    try {
      if (!_isConnected || _httpClient == null) {
        return [];
      }

      final path = directoryPath ?? '';
      final item = await _getItemByPath(path);
      if (item == null) return [];

      final response = await _httpClient!.get(
        Uri.parse('$_graphBaseUrl/me/drive/items/${item['id']}/children'),
        headers: _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['value'] as List;

        final result = <CloudFileInfo>[];
        for (final item in items) {
          final filePath = path.isEmpty
              ? item['name']
              : '$path/${item['name']}';
          final isDirectory = item['folder'] != null;

          result.add(
            CloudFileInfo(
              path: filePath,
              name: item['name'],
              size: item['size'] ?? 0,
              modifiedAt: DateTime.parse(item['lastModifiedDateTime']),
              isDirectory: isDirectory,
              metadata: {'oneDriveItem': item},
            ),
          );

          // Recursively list subdirectories if requested
          if (recursive && isDirectory) {
            final subItems = await listFiles(
              directoryPath: filePath,
              recursive: true,
            );
            result.addAll(subItems);
          }
        }

        return result;
      }
      return [];
    } catch (e) {
      _lastError = e.toString();
      log('OneDriveProvider: Error listing files: $e');
      return [];
    }
  }

  @override
  Future<CloudStorageQuota> getStorageQuota() async {
    try {
      if (!_isConnected || _httpClient == null) {
        return CloudStorageQuota(
          totalBytes: 5 * 1024 * 1024 * 1024, // Default 5GB
          usedBytes: 0,
          availableBytes: 5 * 1024 * 1024 * 1024,
          provider: provider,
        );
      }

      final response = await _httpClient!.get(
        Uri.parse('$_graphBaseUrl/me/drive'),
        headers: _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final quota = data['quota'];

        final total = quota['total'] ?? 5 * 1024 * 1024 * 1024;
        final used = quota['used'] ?? 0;

        return CloudStorageQuota(
          totalBytes: total,
          usedBytes: used,
          availableBytes: total - used,
          provider: provider,
        );
      }
    } catch (e) {
      _lastError = e.toString();
    }

    return CloudStorageQuota(
      totalBytes: 5 * 1024 * 1024 * 1024,
      usedBytes: 0,
      availableBytes: 5 * 1024 * 1024 * 1024,
      provider: provider,
    );
  }

  @override
  Future<DateTime?> getFileModificationTime(String remoteFilePath) async {
    final metadata = await getFileMetadata(remoteFilePath);
    if (metadata?['modifiedAt'] != null) {
      return DateTime.parse(metadata!['modifiedAt']);
    }
    return null;
  }

  @override
  Future<int?> getFileSize(String remoteFilePath) async {
    final metadata = await getFileMetadata(remoteFilePath);
    return metadata?['size'] as int?;
  }

  @override
  Future<bool> createDirectory(String directoryPath) async {
    try {
      final directoryId = await _ensureDirectoryExists(directoryPath);
      return directoryId != null;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  @override
  Future<bool> deleteDirectory(String directoryPath) async {
    return await deleteFile(directoryPath); // Same API endpoint
  }

  @override
  Future<bool> moveFile({
    required String fromPath,
    required String toPath,
  }) async {
    try {
      if (!_isConnected || _httpClient == null) return false;

      final item = await _getItemByPath(fromPath);
      if (item == null) return false;

      final newName = _getFileName(toPath);
      final updateData = {'name': newName};

      final response = await _httpClient!.patch(
        Uri.parse('$_graphBaseUrl/me/drive/items/${item['id']}'),
        headers: _getAuthHeaders(),
        body: json.encode(updateData),
      );

      return response.statusCode == 200;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  @override
  Future<bool> copyFile({
    required String fromPath,
    required String toPath,
  }) async {
    try {
      if (!_isConnected || _httpClient == null) return false;

      final item = await _getItemByPath(fromPath);
      if (item == null) return false;

      final parentPath = _getParentPath(toPath);
      final newName = _getFileName(toPath);

      String? parentId;
      if (parentPath.isEmpty) {
        final rootItem = await _getItemByPath('');
        parentId = rootItem?['id'];
      } else {
        parentId = await _ensureDirectoryExists(parentPath);
      }

      if (parentId == null) return false;

      final copyData = {
        'parentReference': {'id': parentId},
        'name': newName,
      };

      final response = await _httpClient!.post(
        Uri.parse('$_graphBaseUrl/me/drive/items/${item['id']}/copy'),
        headers: _getAuthHeaders(),
        body: json.encode(copyData),
      );

      return response.statusCode == 202; // Accepted
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  @override
  Future<String?> getShareableLink(String remoteFilePath) async {
    try {
      final metadata = await getFileMetadata(remoteFilePath);
      return metadata?['webUrl'] as String?;
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }

  @override
  Future<List<CloudFileChange>> getRemoteChanges({
    DateTime? since,
    String? directoryPath,
  }) async {
    // OneDrive Delta API would be needed for change tracking
    // For now, return empty list
    return [];
  }

  @override
  Map<String, dynamic> getConfiguration() => Map.from(_credentials);

  @override
  Future<void> updateConfiguration(Map<String, dynamic> config) async {
    _credentials = Map<String, String>.from(config);
    _accessToken = _credentials['access_token'];
  }

  @override
  Future<bool> testConnection() async {
    return connect();
  }

  @override
  String? getLastError() => _lastError;

  // Helper methods

  /// Get authorization headers for Microsoft Graph API
  Map<String, String> _getAuthHeaders() {
    return {
      'Authorization': 'Bearer $_accessToken',
      'Content-Type': 'application/json',
    };
  }

  /// Get OneDrive item by path
  Future<Map<String, dynamic>?> _getItemByPath(String path) async {
    try {
      if (path.isEmpty || path == '/') {
        // Get root folder
        final response = await _httpClient!.get(
          Uri.parse('$_graphBaseUrl/me/drive/root'),
          headers: _getAuthHeaders(),
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        }
        return null;
      }

      // Clean path (remove leading slash if present)
      final cleanPath = path.startsWith('/') ? path.substring(1) : path;

      final response = await _httpClient!.get(
        Uri.parse('$_graphBaseUrl/me/drive/root:/$cleanPath'),
        headers: _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      log('OneDriveProvider: Error getting item by path: $e');
      return null;
    }
  }

  /// Get parent directory path
  String _getParentPath(String filePath) {
    final lastSlash = filePath.lastIndexOf('/');
    if (lastSlash == -1) return '';
    return filePath.substring(0, lastSlash);
  }

  /// Get filename from path
  String _getFileName(String filePath) {
    final lastSlash = filePath.lastIndexOf('/');
    if (lastSlash == -1) return filePath;
    return filePath.substring(lastSlash + 1);
  }

  /// Ensure directory exists and return its ID
  Future<String?> _ensureDirectoryExists(String dirPath) async {
    try {
      if (dirPath.isEmpty) {
        // Get root directory ID
        final rootItem = await _getItemByPath('');
        return rootItem?['id'];
      }

      // Check if directory already exists
      final existingItem = await _getItemByPath(dirPath);
      if (existingItem != null && existingItem['folder'] != null) {
        return existingItem['id'];
      }

      // Create directory
      final parentPath = _getParentPath(dirPath);
      final dirName = _getFileName(dirPath);

      String? parentId;
      if (parentPath.isEmpty) {
        final rootItem = await _getItemByPath('');
        parentId = rootItem?['id'];
      } else {
        parentId = await _ensureDirectoryExists(parentPath);
      }

      if (parentId == null) return null;

      final createData = {
        'name': dirName,
        'folder': {},
        '@microsoft.graph.conflictBehavior': 'replace',
      };

      final response = await _httpClient!.post(
        Uri.parse('$_graphBaseUrl/me/drive/items/$parentId/children'),
        headers: _getAuthHeaders(),
        body: json.encode(createData),
      );

      if (response.statusCode == 201) {
        final createdItem = json.decode(response.body);
        return createdItem['id'];
      }

      return null;
    } catch (e) {
      log('OneDriveProvider: Error ensuring directory exists: $e');
      return null;
    }
  }
}
