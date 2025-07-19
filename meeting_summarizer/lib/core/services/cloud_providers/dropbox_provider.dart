import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../models/cloud_sync/cloud_provider.dart';
import '../../interfaces/cloud_sync_interface.dart';
import 'cloud_provider_interface.dart';

/// Dropbox provider implementation using Dropbox API v2
class DropboxProvider implements CloudProviderInterface {
  @override
  CloudProvider get provider => CloudProvider.dropbox;

  static const String _apiBaseUrl = 'https://api.dropboxapi.com/2';
  static const String _contentBaseUrl = 'https://content.dropboxapi.com/2';

  Map<String, String> _credentials = {};
  bool _isConnected = false;
  String? _lastError;
  String? _accessToken;
  http.Client? _httpClient;

  @override
  Future<void> initialize(Map<String, String> credentials) async {
    _credentials = Map.from(credentials);

    if (!_credentials.containsKey('access_token')) {
      throw ArgumentError('Dropbox requires access_token credential');
    }

    _accessToken = _credentials['access_token'];
    _httpClient = http.Client();

    log('DropboxProvider: Initialized with Dropbox API v2');
  }

  @override
  Future<bool> connect() async {
    try {
      if (_accessToken == null || _httpClient == null) {
        throw StateError('Dropbox provider not properly initialized');
      }

      log('DropboxProvider: Connecting to Dropbox API...');

      final response = await _httpClient!.post(
        Uri.parse('$_apiBaseUrl/users/get_current_account'),
        headers: _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final userInfo = json.decode(response.body);
        log(
          'DropboxProvider: Connected as ${userInfo['name']['display_name'] ?? "unknown user"}',
        );
        _isConnected = true;
        return true;
      } else {
        throw Exception(
          'Failed to connect to Dropbox: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      _lastError = e.toString();
      _isConnected = false;
      log('DropboxProvider: Connection failed: $e');
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
      log('DropboxProvider: Disconnected from Dropbox');
    } catch (e) {
      log('DropboxProvider: Error during disconnect: $e');
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
        throw StateError('Not connected to Dropbox');
      }

      log('DropboxProvider: Uploading $localFilePath to $remoteFilePath');

      final localFile = File(localFilePath);
      if (!await localFile.exists()) {
        throw FileSystemException('Local file does not exist', localFilePath);
      }

      final fileContent = await localFile.readAsBytes();
      final cleanPath = remoteFilePath.startsWith('/')
          ? remoteFilePath
          : '/$remoteFilePath';

      final response = await _httpClient!.post(
        Uri.parse('$_contentBaseUrl/files/upload'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/octet-stream',
          'Dropbox-API-Arg': json.encode({
            'path': cleanPath,
            'mode': 'overwrite',
          }),
        },
        body: fileContent,
      );

      if (response.statusCode == 200) {
        if (onProgress != null) onProgress(1.0);
        log('DropboxProvider: Successfully uploaded $remoteFilePath');
        return true;
      } else {
        throw Exception(
          'Upload failed: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      _lastError = e.toString();
      log('DropboxProvider: Upload failed: $e');
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
        throw StateError('Not connected to Dropbox');
      }

      final cleanPath = remoteFilePath.startsWith('/')
          ? remoteFilePath
          : '/$remoteFilePath';

      final response = await _httpClient!.post(
        Uri.parse('$_contentBaseUrl/files/download'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Dropbox-API-Arg': json.encode({'path': cleanPath}),
        },
      );

      if (response.statusCode == 200) {
        final localFile = File(localFilePath);
        await localFile.parent.create(recursive: true);
        await localFile.writeAsBytes(response.bodyBytes);

        if (onProgress != null) onProgress(1.0);
        log('DropboxProvider: Successfully downloaded $remoteFilePath');
        return true;
      } else {
        throw Exception('Download failed: ${response.statusCode}');
      }
    } catch (e) {
      _lastError = e.toString();
      log('DropboxProvider: Download failed: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteFile(String remoteFilePath) async {
    try {
      if (!_isConnected || _httpClient == null) {
        throw StateError('Not connected to Dropbox');
      }

      final cleanPath = remoteFilePath.startsWith('/')
          ? remoteFilePath
          : '/$remoteFilePath';

      final response = await _httpClient!.post(
        Uri.parse('$_apiBaseUrl/files/delete_v2'),
        headers: _getAuthHeaders(),
        body: json.encode({'path': cleanPath}),
      );

      if (response.statusCode == 200) {
        log('DropboxProvider: Successfully deleted $remoteFilePath');
        return true;
      }
      return false;
    } catch (e) {
      _lastError = e.toString();
      log('DropboxProvider: Delete failed: $e');
      return false;
    }
  }

  @override
  Future<bool> fileExists(String remoteFilePath) async {
    final metadata = await getFileMetadata(remoteFilePath);
    return metadata != null;
  }

  @override
  Future<Map<String, dynamic>?> getFileMetadata(String remoteFilePath) async {
    try {
      if (!_isConnected || _httpClient == null) return null;

      final cleanPath = remoteFilePath.startsWith('/')
          ? remoteFilePath
          : '/$remoteFilePath';

      final response = await _httpClient!.post(
        Uri.parse('$_apiBaseUrl/files/get_metadata'),
        headers: _getAuthHeaders(),
        body: json.encode({'path': cleanPath}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'name': data['name'],
          'size': data['size'] ?? 0,
          'path_lower': data['path_lower'],
          'path_display': data['path_display'],
          'server_modified': data['server_modified'],
          'client_modified': data['client_modified'],
          'rev': data['rev'],
          'id': data['id'],
        };
      }
      return null;
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
      if (!_isConnected || _httpClient == null) return [];

      final path = directoryPath ?? '';
      final cleanPath = path.isEmpty
          ? ''
          : (path.startsWith('/') ? path : '/$path');

      final response = await _httpClient!.post(
        Uri.parse('$_apiBaseUrl/files/list_folder'),
        headers: _getAuthHeaders(),
        body: json.encode({'path': cleanPath, 'recursive': recursive}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final entries = data['entries'] as List;

        final result = <CloudFileInfo>[];
        for (final entry in entries) {
          final isDirectory = entry['.tag'] == 'folder';
          final pathDisplay = entry['path_display'] as String;

          result.add(
            CloudFileInfo(
              path: pathDisplay.startsWith('/')
                  ? pathDisplay.substring(1)
                  : pathDisplay,
              name: entry['name'],
              size: entry['size'] ?? 0,
              modifiedAt: entry['server_modified'] != null
                  ? DateTime.parse(entry['server_modified'])
                  : DateTime.now(),
              isDirectory: isDirectory,
              metadata: {'dropboxEntry': entry},
            ),
          );
        }

        return result;
      }
      return [];
    } catch (e) {
      _lastError = e.toString();
      log('DropboxProvider: Error listing files: $e');
      return [];
    }
  }

  @override
  Future<CloudStorageQuota> getStorageQuota() async {
    try {
      if (!_isConnected || _httpClient == null) {
        return CloudStorageQuota(
          totalBytes: 2 * 1024 * 1024 * 1024, // Default 2GB
          usedBytes: 0,
          availableBytes: 2 * 1024 * 1024 * 1024,
          provider: provider,
        );
      }

      final response = await _httpClient!.post(
        Uri.parse('$_apiBaseUrl/users/get_space_usage'),
        headers: _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final used = data['used'] ?? 0;
        final allocation = data['allocation'];
        final total = allocation['allocated'] ?? 2 * 1024 * 1024 * 1024;

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
      totalBytes: 2 * 1024 * 1024 * 1024,
      usedBytes: 0,
      availableBytes: 2 * 1024 * 1024 * 1024,
      provider: provider,
    );
  }

  @override
  Future<DateTime?> getFileModificationTime(String remoteFilePath) async {
    final metadata = await getFileMetadata(remoteFilePath);
    if (metadata?['server_modified'] != null) {
      return DateTime.parse(metadata!['server_modified']);
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
      if (!_isConnected || _httpClient == null) return false;

      final cleanPath = directoryPath.startsWith('/')
          ? directoryPath
          : '/$directoryPath';

      final response = await _httpClient!.post(
        Uri.parse('$_apiBaseUrl/files/create_folder_v2'),
        headers: _getAuthHeaders(),
        body: json.encode({'path': cleanPath}),
      );

      return response.statusCode == 200;
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

      final cleanFromPath = fromPath.startsWith('/') ? fromPath : '/$fromPath';
      final cleanToPath = toPath.startsWith('/') ? toPath : '/$toPath';

      final response = await _httpClient!.post(
        Uri.parse('$_apiBaseUrl/files/move_v2'),
        headers: _getAuthHeaders(),
        body: json.encode({'from_path': cleanFromPath, 'to_path': cleanToPath}),
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

      final cleanFromPath = fromPath.startsWith('/') ? fromPath : '/$fromPath';
      final cleanToPath = toPath.startsWith('/') ? toPath : '/$toPath';

      final response = await _httpClient!.post(
        Uri.parse('$_apiBaseUrl/files/copy_v2'),
        headers: _getAuthHeaders(),
        body: json.encode({'from_path': cleanFromPath, 'to_path': cleanToPath}),
      );

      return response.statusCode == 200;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  @override
  Future<String?> getShareableLink(String remoteFilePath) async {
    try {
      if (!_isConnected || _httpClient == null) return null;

      final cleanPath = remoteFilePath.startsWith('/')
          ? remoteFilePath
          : '/$remoteFilePath';

      final response = await _httpClient!.post(
        Uri.parse('$_apiBaseUrl/sharing/create_shared_link_with_settings'),
        headers: _getAuthHeaders(),
        body: json.encode({'path': cleanPath}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['url'];
      }
      return null;
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
    // Dropbox webhooks and delta API would be needed for change tracking
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

  Map<String, String> _getAuthHeaders() {
    return {
      'Authorization': 'Bearer $_accessToken',
      'Content-Type': 'application/json',
    };
  }
}
