import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../../models/cloud_sync/cloud_provider.dart';
import '../../interfaces/cloud_sync_interface.dart';
import 'cloud_provider_interface.dart';

/// OneDrive provider implementation using Microsoft Graph API
class OneDriveProvider implements CloudProviderInterface {
  @override
  CloudProvider get provider => CloudProvider.oneDrive;

  static const String _graphBaseUrl = 'https://graph.microsoft.com/v1.0';
  static const String _authBaseUrl = 'https://login.microsoftonline.com';
  static const String _commonTenant = 'common';
  static const String _consumerTenant = '9188040d-6c67-4c5b-b112-36a304b66dad';
  
  // Maximum file size for simple upload (4MB)
  static const int _simpleUploadLimit = 4 * 1024 * 1024;
  
  // Chunk size for resumable uploads (10MB)
  static const int _uploadChunkSize = 10 * 1024 * 1024;

  Map<String, String> _credentials = {};
  bool _isConnected = false;
  String? _lastError;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  http.Client? _httpClient;
  String? _accountType; // 'personal' or 'work'
  String? _userId;
  final Map<String, String> _uploadSessions = {}; // For resumable uploads
  String? _deltaToken; // For delta sync

  @override
  Future<void> initialize(Map<String, String> credentials) async {
    _credentials = Map.from(credentials);

    // Validate required credentials
    if (!_credentials.containsKey('client_id')) {
      throw ArgumentError(
        'OneDrive requires client_id credential',
      );
    }

    // Initialize token information if provided
    if (_credentials.containsKey('access_token')) {
      _accessToken = _credentials['access_token'];
      
      // Parse token expiry if provided
      if (_credentials.containsKey('expires_at')) {
        try {
          _tokenExpiry = DateTime.parse(_credentials['expires_at']!);
        } catch (e) {
          log('OneDriveProvider: Invalid expires_at format: $e');
        }
      }
    }
    
    if (_credentials.containsKey('refresh_token')) {
      _refreshToken = _credentials['refresh_token'];
    }
    
    if (_credentials.containsKey('account_type')) {
      _accountType = _credentials['account_type'];
    }

    _httpClient = http.Client();

    log('OneDriveProvider: Initialized with Microsoft Graph API');
  }

  @override
  Future<bool> connect() async {
    try {
      if (_httpClient == null) {
        throw StateError('OneDrive provider not properly initialized');
      }

      log('OneDriveProvider: Connecting to Microsoft Graph API...');

      // Check if we need to refresh the access token
      if (!await _ensureValidToken()) {
        throw StateError('Unable to obtain valid access token');
      }

      // Test connection by getting user profile
      final response = await _httpClient!.get(
        Uri.parse('$_graphBaseUrl/me'),
        headers: _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final userInfo = json.decode(response.body);
        _userId = userInfo['id'];
        
        // Determine account type based on user principal name or other indicators
        final userPrincipalName = userInfo['userPrincipalName'] as String?;
        if (userPrincipalName != null) {
          if (userPrincipalName.contains('@outlook.com') || 
              userPrincipalName.contains('@hotmail.com') ||
              userPrincipalName.contains('@live.com')) {
            _accountType = 'personal';
          } else {
            _accountType = 'work';
          }
        }
        
        log(
          'OneDriveProvider: Connected as ${userInfo['displayName'] ?? "unknown user"} ($_accountType account)',
        );
        _isConnected = true;
        return true;
      } else if (response.statusCode == 401) {
        // Token might be expired, try to refresh
        if (await _refreshAccessToken()) {
          return connect(); // Retry connection
        }
        throw Exception('Authentication failed - invalid or expired token');
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
      // Cancel any ongoing upload sessions
      for (final sessionUrl in _uploadSessions.values) {
        try {
          await _httpClient?.delete(
            Uri.parse(sessionUrl),
            headers: _getAuthHeaders(),
          );
        } catch (e) {
          log('OneDriveProvider: Error canceling upload session: $e');
        }
      }
      _uploadSessions.clear();
      
      _httpClient?.close();
      _httpClient = null;
      _accessToken = null;
      _refreshToken = null;
      _tokenExpiry = null;
      _deltaToken = null;
      _userId = null;
      _accountType = null;
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
      if (fileContent.length < _simpleUploadLimit) {
        final success = await _simpleUpload(
          parentId: parentId,
          fileName: fileName,
          fileContent: fileContent,
          onProgress: onProgress,
        );
        
        if (success) {
          log('OneDriveProvider: Successfully uploaded $fileName');
          return true;
        } else {
          throw Exception('Simple upload failed');
        }
      } else {
        // For larger files, use resumable upload sessions
        final success = await _resumableUpload(
          parentId: parentId,
          fileName: fileName,
          fileContent: fileContent,
          onProgress: onProgress,
        );
        
        if (success) {
          log('OneDriveProvider: Successfully uploaded large file $fileName');
          return true;
        } else {
          throw Exception('Resumable upload failed');
        }
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
    try {
      if (!_isConnected || _httpClient == null) {
        return [];
      }

      return await _getDeltaChanges(since: since, directoryPath: directoryPath);
    } catch (e) {
      _lastError = e.toString();
      log('OneDriveProvider: Error getting remote changes: $e');
      return [];
    }
  }

  @override
  Map<String, dynamic> getConfiguration() => Map.from(_credentials);

  @override
  Future<void> updateConfiguration(Map<String, dynamic> config) async {
    _credentials = Map<String, String>.from(config);
    _accessToken = _credentials['access_token'];
    _refreshToken = _credentials['refresh_token'];
    _accountType = _credentials['account_type'];
    
    if (_credentials.containsKey('expires_at')) {
      try {
        _tokenExpiry = DateTime.parse(_credentials['expires_at']!);
      } catch (e) {
        log('OneDriveProvider: Invalid expires_at format in config: $e');
      }
    }
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

  // OAuth2 Authentication Methods (Subtask 2.1)

  /// Ensure we have a valid access token, refreshing if necessary
  Future<bool> _ensureValidToken() async {
    if (_accessToken == null) {
      if (_refreshToken != null) {
        return await _refreshAccessToken();
      }
      return false;
    }

    // Check if token is expired (with 5 minute buffer)
    if (_tokenExpiry != null) {
      final now = DateTime.now();
      final bufferTime = Duration(minutes: 5);
      if (now.add(bufferTime).isAfter(_tokenExpiry!)) {
        if (_refreshToken != null) {
          return await _refreshAccessToken();
        }
        return false;
      }
    }

    return true;
  }

  /// Refresh the access token using the refresh token
  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null || _credentials['client_id'] == null) {
      log('OneDriveProvider: Cannot refresh token - missing refresh_token or client_id');
      return false;
    }

    try {
      log('OneDriveProvider: Refreshing access token...');
      
      // Determine the correct tenant based on account type
      final tenant = _accountType == 'personal' ? _consumerTenant : _commonTenant;
      
      final response = await _httpClient!.post(
        Uri.parse('$_authBaseUrl/$tenant/oauth2/v2.0/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': _credentials['client_id']!,
          'refresh_token': _refreshToken!,
          'grant_type': 'refresh_token',
          'scope': 'https://graph.microsoft.com/Files.ReadWrite.All offline_access',
        },
      );

      if (response.statusCode == 200) {
        final tokenData = json.decode(response.body);
        _accessToken = tokenData['access_token'];
        
        if (tokenData.containsKey('refresh_token')) {
          _refreshToken = tokenData['refresh_token'];
        }
        
        if (tokenData.containsKey('expires_in')) {
          final expiresIn = tokenData['expires_in'] as int;
          _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
        }
        
        // Update credentials for persistence
        _credentials['access_token'] = _accessToken!;
        if (_refreshToken != null) {
          _credentials['refresh_token'] = _refreshToken!;
        }
        if (_tokenExpiry != null) {
          _credentials['expires_at'] = _tokenExpiry!.toIso8601String();
        }
        
        log('OneDriveProvider: Access token refreshed successfully');
        return true;
      } else {
        log('OneDriveProvider: Token refresh failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      log('OneDriveProvider: Error refreshing token: $e');
      return false;
    }
  }

  /// Generate OAuth2 authorization URL for manual authentication
  String generateAuthUrl({String? redirectUri, List<String>? scopes}) {
    final clientId = _credentials['client_id'];
    if (clientId == null) {
      throw StateError('Client ID not configured');
    }

    final defaultRedirectUri = redirectUri ?? 'http://localhost:8080/auth/callback';
    final defaultScopes = scopes ?? [
      'https://graph.microsoft.com/Files.ReadWrite.All',
      'offline_access'
    ];
    
    // Determine tenant based on account type preference
    final tenant = _accountType == 'personal' ? _consumerTenant : _commonTenant;
    
    // Generate a random state parameter for security
    final state = _generateRandomString(32);
    
    final authUrl = Uri.parse('$_authBaseUrl/$tenant/oauth2/v2.0/authorize').replace(
      queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': defaultRedirectUri,
        'scope': defaultScopes.join(' '),
        'state': state,
        'response_mode': 'query',
      },
    );

    return authUrl.toString();
  }

  /// Exchange authorization code for access token
  Future<bool> exchangeCodeForToken({
    required String code,
    required String redirectUri,
    String? clientSecret,
  }) async {
    final clientId = _credentials['client_id'];
    if (clientId == null) {
      throw StateError('Client ID not configured');
    }

    try {
      log('OneDriveProvider: Exchanging authorization code for token...');
      
      // Determine tenant based on account type
      final tenant = _accountType == 'personal' ? _consumerTenant : _commonTenant;
      
      final body = <String, String>{
        'client_id': clientId,
        'code': code,
        'redirect_uri': redirectUri,
        'grant_type': 'authorization_code',
        'scope': 'https://graph.microsoft.com/Files.ReadWrite.All offline_access',
      };
      
      // Add client secret for confidential clients (work accounts typically)
      if (clientSecret != null) {
        body['client_secret'] = clientSecret;
      }

      final response = await _httpClient!.post(
        Uri.parse('$_authBaseUrl/$tenant/oauth2/v2.0/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final tokenData = json.decode(response.body);
        
        _accessToken = tokenData['access_token'];
        _refreshToken = tokenData['refresh_token'];
        
        if (tokenData.containsKey('expires_in')) {
          final expiresIn = tokenData['expires_in'] as int;
          _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
        }
        
        // Update credentials
        _credentials['access_token'] = _accessToken!;
        if (_refreshToken != null) {
          _credentials['refresh_token'] = _refreshToken!;
        }
        if (_tokenExpiry != null) {
          _credentials['expires_at'] = _tokenExpiry!.toIso8601String();
        }
        
        log('OneDriveProvider: Successfully obtained access token');
        return true;
      } else {
        log('OneDriveProvider: Token exchange failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      log('OneDriveProvider: Error exchanging code for token: $e');
      return false;
    }
  }

  // Resumable File Transfer Methods (Subtask 2.3)

  /// Simple upload for small files
  Future<bool> _simpleUpload({
    required String parentId,
    required String fileName,
    required List<int> fileContent,
    Function(double progress)? onProgress,
  }) async {
    try {
      if (onProgress != null) onProgress(0.0);
      
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
        if (onProgress != null) onProgress(1.0);
        return true;
      } else {
        log('OneDriveProvider: Simple upload failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      log('OneDriveProvider: Simple upload error: $e');
      return false;
    }
  }

  /// Resumable upload for large files
  Future<bool> _resumableUpload({
    required String parentId,
    required String fileName,
    required List<int> fileContent,
    Function(double progress)? onProgress,
  }) async {
    try {
      // Create upload session
      final sessionUrl = await _createUploadSession(
        parentId: parentId,
        fileName: fileName,
        fileSize: fileContent.length,
      );
      
      if (sessionUrl == null) {
        log('OneDriveProvider: Failed to create upload session');
        return false;
      }
      
      // Store session for potential cancellation
      _uploadSessions[fileName] = sessionUrl;
      
      try {
        // Upload file in chunks
        final totalSize = fileContent.length;
        int uploadedBytes = 0;
        
        while (uploadedBytes < totalSize) {
          final chunkStart = uploadedBytes;
          final chunkEnd = math.min(uploadedBytes + _uploadChunkSize, totalSize) - 1;
          final chunkSize = chunkEnd - chunkStart + 1;
          
          final chunk = fileContent.sublist(chunkStart, chunkEnd + 1);
          
          final success = await _uploadChunk(
            sessionUrl: sessionUrl,
            chunk: chunk,
            rangeStart: chunkStart,
            rangeEnd: chunkEnd,
            totalSize: totalSize,
          );
          
          if (!success) {
            log('OneDriveProvider: Chunk upload failed at range $chunkStart-$chunkEnd');
            await _cancelUploadSession(sessionUrl);
            return false;
          }
          
          uploadedBytes += chunkSize;
          
          // Report progress
          if (onProgress != null) {
            final progress = uploadedBytes / totalSize;
            onProgress(progress);
          }
        }
        
        // Remove session from tracking
        _uploadSessions.remove(fileName);
        
        log('OneDriveProvider: Resumable upload completed successfully');
        return true;
        
      } catch (e) {
        log('OneDriveProvider: Error during chunk upload: $e');
        await _cancelUploadSession(sessionUrl);
        _uploadSessions.remove(fileName);
        return false;
      }
      
    } catch (e) {
      log('OneDriveProvider: Resumable upload error: $e');
      return false;
    }
  }

  /// Create an upload session for large files
  Future<String?> _createUploadSession({
    required String parentId,
    required String fileName,
    required int fileSize,
  }) async {
    try {
      final sessionData = {
        'item': {
          '@microsoft.graph.conflictBehavior': 'replace',
          'name': fileName,
        },
      };
      
      final response = await _httpClient!.post(
        Uri.parse(
          '$_graphBaseUrl/me/drive/items/$parentId:/$fileName:/createUploadSession',
        ),
        headers: _getAuthHeaders(),
        body: json.encode(sessionData),
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['uploadUrl'] as String?;
      } else {
        log('OneDriveProvider: Failed to create upload session: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      log('OneDriveProvider: Error creating upload session: $e');
      return null;
    }
  }

  /// Upload a chunk to the upload session
  Future<bool> _uploadChunk({
    required String sessionUrl,
    required List<int> chunk,
    required int rangeStart,
    required int rangeEnd,
    required int totalSize,
  }) async {
    try {
      final response = await _httpClient!.put(
        Uri.parse(sessionUrl),
        headers: {
          'Content-Range': 'bytes $rangeStart-$rangeEnd/$totalSize',
          'Content-Length': chunk.length.toString(),
        },
        body: chunk,
      );
      
      // 202 Accepted means more chunks expected
      // 201 Created means upload complete
      // 200 OK means upload complete
      if (response.statusCode == 202 || 
          response.statusCode == 201 || 
          response.statusCode == 200) {
        return true;
      } else {
        log('OneDriveProvider: Chunk upload failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      log('OneDriveProvider: Error uploading chunk: $e');
      return false;
    }
  }

  /// Cancel an upload session
  Future<void> _cancelUploadSession(String sessionUrl) async {
    try {
      await _httpClient!.delete(
        Uri.parse(sessionUrl),
        headers: _getAuthHeaders(),
      );
      log('OneDriveProvider: Upload session canceled');
    } catch (e) {
      log('OneDriveProvider: Error canceling upload session: $e');
    }
  }

  // Delta Sync Methods (Subtask 2.4)

  /// Get delta changes from OneDrive
  Future<List<CloudFileChange>> _getDeltaChanges({
    DateTime? since,
    String? directoryPath,
  }) async {
    try {
      final changes = <CloudFileChange>[];
      
      // Build delta URL
      String deltaUrl;
      if (_deltaToken != null) {
        // Continue from previous delta token
        deltaUrl = '$_graphBaseUrl/me/drive/root/delta?token=$_deltaToken';
      } else {
        // Start new delta query
        deltaUrl = '$_graphBaseUrl/me/drive/root/delta';
      }
      
      // Apply directory filter if specified
      if (directoryPath != null && directoryPath.isNotEmpty) {
        // For directory-specific deltas, we need to use the item path
        final cleanPath = directoryPath.startsWith('/') ? directoryPath.substring(1) : directoryPath;
        deltaUrl = '$_graphBaseUrl/me/drive/root:/$cleanPath:/delta';
      }
      
      String? nextLink = deltaUrl;
      
      while (nextLink != null) {
        final response = await _httpClient!.get(
          Uri.parse(nextLink),
          headers: _getAuthHeaders(),
        );
        
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          final items = responseData['value'] as List;
          
          for (final item in items) {
            final change = _parseItemToChange(item, directoryPath);
            if (change != null) {
              // Filter by timestamp if specified
              if (since == null || change.timestamp.isAfter(since)) {
                changes.add(change);
              }
            }
          }
          
          // Check for pagination
          nextLink = responseData['@odata.nextLink'] as String?;
          
          // Update delta token if this is the final page
          if (nextLink == null && responseData.containsKey('@odata.deltaLink')) {
            final deltaLink = responseData['@odata.deltaLink'] as String;
            final uri = Uri.parse(deltaLink);
            _deltaToken = uri.queryParameters['token'];
          }
        } else {
          log('OneDriveProvider: Delta query failed: ${response.statusCode} ${response.body}');
          break;
        }
      }
      
      log('OneDriveProvider: Retrieved ${changes.length} delta changes');
      return changes;
    } catch (e) {
      log('OneDriveProvider: Error getting delta changes: $e');
      return [];
    }
  }

  /// Parse OneDrive item to CloudFileChange
  CloudFileChange? _parseItemToChange(Map<String, dynamic> item, String? basePath) {
    try {
      final itemName = item['name'] as String?;
      if (itemName == null) return null;
      
      final itemPath = basePath != null && basePath.isNotEmpty 
          ? '$basePath/$itemName'
          : itemName;
      
      // Determine change type
      CloudChangeType changeType;
      if (item.containsKey('deleted')) {
        changeType = CloudChangeType.deleted;
      } else if (item.containsKey('file') || item.containsKey('folder')) {
        // Check if this is a new item or modified
        final createdDateTime = DateTime.parse(item['createdDateTime']);
        final lastModifiedDateTime = DateTime.parse(item['lastModifiedDateTime']);
        
        // If created and modified times are very close, it's likely a new file
        final timeDiff = lastModifiedDateTime.difference(createdDateTime).inMinutes;
        changeType = timeDiff < 1 ? CloudChangeType.created : CloudChangeType.modified;
      } else {
        return null; // Unknown item type
      }
      
      // Create file info if not deleted
      CloudFileInfo? fileInfo;
      if (changeType != CloudChangeType.deleted) {
        fileInfo = CloudFileInfo(
          path: itemPath,
          name: itemName,
          size: item['size'] ?? 0,
          modifiedAt: DateTime.parse(item['lastModifiedDateTime']),
          isDirectory: item['folder'] != null,
          mimeType: item['file']?['mimeType'],
          checksum: item['file']?['hashes']?['sha1Hash'],
          metadata: {'oneDriveItem': item},
        );
      }
      
      return CloudFileChange(
        path: itemPath,
        type: changeType,
        timestamp: DateTime.parse(item['lastModifiedDateTime']),
        fileInfo: fileInfo,
      );
    } catch (e) {
      log('OneDriveProvider: Error parsing item to change: $e');
      return null;
    }
  }

  /// Reset delta token to force full sync on next delta call
  void resetDeltaToken() {
    _deltaToken = null;
    log('OneDriveProvider: Delta token reset');
  }

  // Utility Methods

  /// Generate a random string for OAuth state parameter
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = math.Random.secure();
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }


  /// Check if the current account supports business features
  bool get isBusinessAccount => _accountType == 'work';

  /// Check if the current account is a personal account
  bool get isPersonalAccount => _accountType == 'personal';

  /// Get current account type
  String? get accountType => _accountType;

  /// Get current user ID
  String? get userId => _userId;

  /// Get delta token for external storage
  String? get deltaToken => _deltaToken;

  /// Set delta token from external storage
  set deltaToken(String? token) => _deltaToken = token;
}
