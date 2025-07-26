import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../models/cloud_sync/cloud_provider.dart';
import '../../interfaces/cloud_sync_interface.dart';
import 'cloud_provider_interface.dart';

/// Dropbox provider implementation using Dropbox API v2
/// Supports OAuth2 authentication, chunked uploads, rate limiting,
/// shared links, and Paper integration
class DropboxProvider implements CloudProviderInterface {
  @override
  CloudProvider get provider => CloudProvider.dropbox;

  static const String _apiBaseUrl = 'https://api.dropboxapi.com/2';
  static const String _contentBaseUrl = 'https://content.dropboxapi.com/2';
  static const String _oauthBaseUrl = 'https://www.dropbox.com/oauth2';
  
  // Rate limiting constants
  static const int _burstRequestLimit = 100;
  static const Duration _rateLimitWindow = Duration(seconds: 1);
  
  // Chunked upload constants
  static const int _chunkSize = 8 * 1024 * 1024; // 8MB chunks
  static const int _maxRetries = 3;
  
  Map<String, String> _credentials = {};
  bool _isConnected = false;
  String? _lastError;
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiryTime;
  http.Client? _httpClient;
  
  // OAuth2 configuration
  String? _clientId;
  String? _clientSecret;
  String? _redirectUri;
  
  // Rate limiting state
  final List<DateTime> _requestTimes = [];
  
  // Paper integration constants
  static const String _paperBaseUrl = 'https://api.dropboxapi.com/2/paper';

  @override
  Future<void> initialize(Map<String, String> credentials) async {
    _credentials = Map.from(credentials);

    // Support both OAuth2 flow and direct access token
    if (credentials.containsKey('client_id') && credentials.containsKey('client_secret')) {
      // OAuth2 flow setup
      _clientId = credentials['client_id'];
      _clientSecret = credentials['client_secret'];
      _redirectUri = credentials['redirect_uri'] ?? 'http://localhost:8080/auth/callback';
      
      // Check for existing tokens
      _accessToken = credentials['access_token'];
      _refreshToken = credentials['refresh_token'];
      
      if (credentials.containsKey('token_expiry')) {
        _tokenExpiryTime = DateTime.parse(credentials['token_expiry']!);
      }
    } else if (credentials.containsKey('access_token')) {
      // Direct access token
      _accessToken = credentials['access_token'];
    } else {
      throw ArgumentError(
        'Dropbox requires either (client_id + client_secret) for OAuth2 or access_token for direct access'
      );
    }

    _httpClient = http.Client();
    log('DropboxProvider: Initialized with Dropbox API v2');
  }

  @override
  Future<bool> connect() async {
    try {
      if (_httpClient == null) {
        throw StateError('Dropbox provider not properly initialized');
      }

      // Check if we need to refresh the token
      if (_shouldRefreshToken()) {
        final refreshed = await _refreshAccessToken();
        if (!refreshed) {
          log('DropboxProvider: Failed to refresh access token');
          return false;
        }
      }

      if (_accessToken == null) {
        throw StateError('No valid access token available');
      }

      log('DropboxProvider: Connecting to Dropbox API...');

      final response = await _makeRateLimitedRequest(() async {
        return await _httpClient!.post(
          Uri.parse('$_apiBaseUrl/users/get_current_account'),
          headers: _getAuthHeaders(),
        );
      });

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
      // Revoke the access token if possible
      if (_accessToken != null && _httpClient != null) {
        try {
          await _httpClient!.post(
            Uri.parse('$_apiBaseUrl/auth/token/revoke'),
            headers: _getAuthHeaders(),
          );
        } catch (e) {
          log('DropboxProvider: Failed to revoke token: $e');
        }
      }
      
      _httpClient?.close();
      _httpClient = null;
      _accessToken = null;
      _refreshToken = null;
      _tokenExpiryTime = null;
      _isConnected = false;
      _requestTimes.clear();
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

      final fileSize = await localFile.length();
      final cleanPath = remoteFilePath.startsWith('/')
          ? remoteFilePath
          : '/$remoteFilePath';

      // Use chunked upload for large files (>8MB)
      if (fileSize > _chunkSize) {
        return await _uploadFileChunked(
          localFile,
          cleanPath,
          metadata,
          onProgress,
        );
      } else {
        return await _uploadFileSimple(
          localFile,
          cleanPath,
          metadata,
          onProgress,
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

      log('DropboxProvider: Downloading $remoteFilePath to $localFilePath');

      // Get file metadata first to show progress for large files
      final metadata = await getFileMetadata(cleanPath);
      final fileSize = metadata?['size'] as int? ?? 0;

      final response = await _makeRateLimitedRequest(() async {
        return await _httpClient!.post(
          Uri.parse('$_contentBaseUrl/files/download'),
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Dropbox-API-Arg': json.encode({'path': cleanPath}),
          },
        );
      });

      if (response.statusCode == 200) {
        final localFile = File(localFilePath);
        await localFile.parent.create(recursive: true);
        
        // For large files, write in chunks to show progress
        if (fileSize > _chunkSize && onProgress != null) {
          final bytes = response.bodyBytes;
          final sink = localFile.openWrite();
          
          try {
            const chunkSize = 64 * 1024; // 64KB write chunks
            int written = 0;
            
            for (int i = 0; i < bytes.length; i += chunkSize) {
              final end = math.min(i + chunkSize, bytes.length);
              sink.add(bytes.sublist(i, end));
              written += (end - i);
              onProgress(written / fileSize);
            }
          } finally {
            await sink.close();
          }
        } else {
          await localFile.writeAsBytes(response.bodyBytes);
          if (onProgress != null) onProgress(1.0);
        }

        log('DropboxProvider: Successfully downloaded $remoteFilePath');
        return true;
      } else {
        throw Exception('Download failed: ${response.statusCode} ${response.body}');
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

      log('DropboxProvider: Deleting $remoteFilePath');

      final response = await _makeRateLimitedRequest(() async {
        return await _httpClient!.post(
          Uri.parse('$_apiBaseUrl/files/delete_v2'),
          headers: _getAuthHeaders(),
          body: json.encode({'path': cleanPath}),
        );
      });

      if (response.statusCode == 200) {
        log('DropboxProvider: Successfully deleted $remoteFilePath');
        return true;
      } else {
        log('DropboxProvider: Delete failed: ${response.statusCode} ${response.body}');
        return false;
      }
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

      final response = await _makeRateLimitedRequest(() async {
        return await _httpClient!.post(
          Uri.parse('$_apiBaseUrl/files/get_metadata'),
          headers: _getAuthHeaders(),
          body: json.encode({
            'path': cleanPath,
            'include_media_info': true,
            'include_deleted': false,
            'include_has_explicit_shared_members': true,
          }),
        );
      });

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
          'content_hash': data['content_hash'],
          'file_lock_info': data['file_lock_info'],
          'sharing_info': data['sharing_info'],
          'property_groups': data['property_groups'],
          'media_info': data['media_info'],
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

      log('DropboxProvider: Listing files in $cleanPath (recursive: $recursive)');

      final result = <CloudFileInfo>[];
      String? cursor;
      bool hasMore = true;

      while (hasMore) {
        final response = await _makeRateLimitedRequest(() async {
          if (cursor == null) {
            return await _httpClient!.post(
              Uri.parse('$_apiBaseUrl/files/list_folder'),
              headers: _getAuthHeaders(),
              body: json.encode({
                'path': cleanPath,
                'recursive': recursive,
                'include_media_info': true,
                'include_deleted': false,
                'include_has_explicit_shared_members': true,
                'include_mounted_folders': true,
                'limit': 2000, // Max allowed by Dropbox
              }),
            );
          } else {
            return await _httpClient!.post(
              Uri.parse('$_apiBaseUrl/files/list_folder/continue'),
              headers: _getAuthHeaders(),
              body: json.encode({'cursor': cursor}),
            );
          }
        });

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final entries = data['entries'] as List;
          hasMore = data['has_more'] ?? false;
          cursor = data['cursor'] as String?;

          for (final entry in entries) {
            final isDirectory = entry['.tag'] == 'folder';
            final pathDisplay = entry['path_display'] as String;
            final mimeType = _getMimeTypeFromExtension(entry['name']);

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
                mimeType: mimeType,
                checksum: entry['content_hash'],
                metadata: {
                  'dropboxEntry': entry,
                  'rev': entry['rev'],
                  'id': entry['id'],
                  'sharing_info': entry['sharing_info'],
                },
              ),
            );
          }
        } else {
          hasMore = false;
          log('DropboxProvider: List files failed: ${response.statusCode} ${response.body}');
        }
      }

      log('DropboxProvider: Listed ${result.length} files/folders');
      return result;
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

      final response = await _makeRateLimitedRequest(() async {
        return await _httpClient!.post(
          Uri.parse('$_apiBaseUrl/users/get_space_usage'),
          headers: _getAuthHeaders(),
        );
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final used = data['used'] ?? 0;
        final allocation = data['allocation'];
        
        int total;
        if (allocation['.tag'] == 'individual') {
          total = allocation['allocated'] ?? 2 * 1024 * 1024 * 1024;
        } else if (allocation['.tag'] == 'team') {
          total = allocation['used'] + (allocation['allocated'] ?? 0);
        } else {
          total = 2 * 1024 * 1024 * 1024; // Fallback
        }

        return CloudStorageQuota(
          totalBytes: total,
          usedBytes: used,
          availableBytes: math.max(0, total - used).toInt(),
          provider: provider,
        );
      }
    } catch (e) {
      _lastError = e.toString();
      log('DropboxProvider: Error getting storage quota: $e');
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

      log('DropboxProvider: Creating directory $cleanPath');

      final response = await _makeRateLimitedRequest(() async {
        return await _httpClient!.post(
          Uri.parse('$_apiBaseUrl/files/create_folder_v2'),
          headers: _getAuthHeaders(),
          body: json.encode({
            'path': cleanPath,
            'autorename': false,
          }),
        );
      });

      if (response.statusCode == 200) {
        log('DropboxProvider: Successfully created directory $cleanPath');
        return true;
      } else {
        log('DropboxProvider: Create directory failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      log('DropboxProvider: Create directory failed: $e');
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

      log('DropboxProvider: Moving $cleanFromPath to $cleanToPath');

      final response = await _makeRateLimitedRequest(() async {
        return await _httpClient!.post(
          Uri.parse('$_apiBaseUrl/files/move_v2'),
          headers: _getAuthHeaders(),
          body: json.encode({
            'from_path': cleanFromPath,
            'to_path': cleanToPath,
            'allow_shared_folder': true,
            'autorename': false,
            'allow_ownership_transfer': false,
          }),
        );
      });

      if (response.statusCode == 200) {
        log('DropboxProvider: Successfully moved $cleanFromPath to $cleanToPath');
        return true;
      } else {
        log('DropboxProvider: Move failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      log('DropboxProvider: Move failed: $e');
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

      log('DropboxProvider: Copying $cleanFromPath to $cleanToPath');

      final response = await _makeRateLimitedRequest(() async {
        return await _httpClient!.post(
          Uri.parse('$_apiBaseUrl/files/copy_v2'),
          headers: _getAuthHeaders(),
          body: json.encode({
            'from_path': cleanFromPath,
            'to_path': cleanToPath,
            'allow_shared_folder': true,
            'autorename': false,
            'allow_ownership_transfer': false,
          }),
        );
      });

      if (response.statusCode == 200) {
        log('DropboxProvider: Successfully copied $cleanFromPath to $cleanToPath');
        return true;
      } else {
        log('DropboxProvider: Copy failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      log('DropboxProvider: Copy failed: $e');
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

      log('DropboxProvider: Creating shareable link for $cleanPath');

      // First try to get existing shared links
      final existingLinksResponse = await _makeRateLimitedRequest(() async {
        return await _httpClient!.post(
          Uri.parse('$_apiBaseUrl/sharing/list_shared_links'),
          headers: _getAuthHeaders(),
          body: json.encode({
            'path': cleanPath,
            'direct_only': true,
          }),
        );
      });

      if (existingLinksResponse.statusCode == 200) {
        final existingData = json.decode(existingLinksResponse.body);
        final links = existingData['links'] as List;
        if (links.isNotEmpty) {
          final link = links.first['url'] as String;
          log('DropboxProvider: Found existing shared link for $cleanPath');
          return link;
        }
      }

      // Create new shared link with settings
      final response = await _makeRateLimitedRequest(() async {
        return await _httpClient!.post(
          Uri.parse('$_apiBaseUrl/sharing/create_shared_link_with_settings'),
          headers: _getAuthHeaders(),
          body: json.encode({
            'path': cleanPath,
            'settings': {
              'requested_visibility': 'public',
              'audience': 'public',
              'access': 'viewer',
              'allow_download': true,
            },
          }),
        );
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final link = data['url'] as String;
        log('DropboxProvider: Created shareable link for $cleanPath');
        return link;
      } else {
        log('DropboxProvider: Failed to create shareable link: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      _lastError = e.toString();
      log('DropboxProvider: Error creating shareable link: $e');
      return null;
    }
  }

  @override
  Future<List<CloudFileChange>> getRemoteChanges({
    DateTime? since,
    String? directoryPath,
  }) async {
    try {
      if (!_isConnected || _httpClient == null) return [];

      // Dropbox doesn't have a direct delta API, but we can use list_folder
      // with revision comparison for basic change detection
      log('DropboxProvider: Getting remote changes since ${since?.toIso8601String() ?? "beginning"}');

      final files = await listFiles(
        directoryPath: directoryPath,
        recursive: true,
      );

      final changes = <CloudFileChange>[];
      
      for (final file in files) {
        // If we have a since date, only include files modified after that date
        if (since == null || file.modifiedAt.isAfter(since)) {
          changes.add(
            CloudFileChange(
              path: file.path,
              type: CloudChangeType.modified, // We can't distinguish between created/modified without more context
              timestamp: file.modifiedAt,
              fileInfo: file,
            ),
          );
        }
      }

      log('DropboxProvider: Found ${changes.length} changes');
      return changes;
    } catch (e) {
      _lastError = e.toString();
      log('DropboxProvider: Error getting remote changes: $e');
      return [];
    }
  }

  @override
  Map<String, dynamic> getConfiguration() {
    final config = Map<String, dynamic>.from(_credentials);
    
    // Add current token information
    if (_accessToken != null) {
      config['access_token'] = _accessToken;
    }
    if (_refreshToken != null) {
      config['refresh_token'] = _refreshToken;
    }
    if (_tokenExpiryTime != null) {
      config['token_expiry'] = _tokenExpiryTime!.toIso8601String();
    }
    
    return config;
  }

  @override
  Future<void> updateConfiguration(Map<String, dynamic> config) async {
    _credentials = Map<String, String>.from(config);
    
    _accessToken = _credentials['access_token'];
    _refreshToken = _credentials['refresh_token'];
    _clientId = _credentials['client_id'];
    _clientSecret = _credentials['client_secret'];
    _redirectUri = _credentials['redirect_uri'];
    
    if (_credentials.containsKey('token_expiry')) {
      _tokenExpiryTime = DateTime.parse(_credentials['token_expiry']!);
    }
    
    log('DropboxProvider: Configuration updated');
  }

  @override
  Future<bool> testConnection() async {
    return connect();
  }

  @override
  String? getLastError() => _lastError;

  // OAuth2 Methods
  
  /// Generate OAuth2 authorization URL for user consent
  String getAuthorizationUrl({List<String>? scopes}) {
    if (_clientId == null || _redirectUri == null) {
      throw StateError('OAuth2 not properly configured');
    }
    
    final scopeString = scopes?.join(' ') ?? '';
    final state = _generateRandomString(32);
    
    final params = {
      'client_id': _clientId!,
      'response_type': 'code',
      'redirect_uri': _redirectUri!,
      'state': state,
      if (scopeString.isNotEmpty) 'scope': scopeString,
    };
    
    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    
    return '$_oauthBaseUrl/authorize?$query';
  }
  
  /// Exchange authorization code for access token
  Future<bool> exchangeAuthorizationCode(String code) async {
    try {
      if (_clientId == null || _clientSecret == null || _redirectUri == null) {
        throw StateError('OAuth2 not properly configured');
      }
      
      log('DropboxProvider: Exchanging authorization code for tokens');
      
      final response = await _httpClient!.post(
        Uri.parse('$_oauthBaseUrl/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'code': code,
          'grant_type': 'authorization_code',
          'client_id': _clientId!,
          'client_secret': _clientSecret!,
          'redirect_uri': _redirectUri!,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        
        if (data.containsKey('expires_in')) {
          final expiresIn = data['expires_in'] as int;
          _tokenExpiryTime = DateTime.now().add(Duration(seconds: expiresIn));
        }
        
        // Update credentials
        _credentials['access_token'] = _accessToken!;
        if (_refreshToken != null) {
          _credentials['refresh_token'] = _refreshToken!;
        }
        if (_tokenExpiryTime != null) {
          _credentials['token_expiry'] = _tokenExpiryTime!.toIso8601String();
        }
        
        log('DropboxProvider: Successfully obtained access token');
        return true;
      } else {
        throw Exception('Token exchange failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      _lastError = e.toString();
      log('DropboxProvider: Token exchange failed: $e');
      return false;
    }
  }
  
  /// Check if token should be refreshed
  bool _shouldRefreshToken() {
    if (_tokenExpiryTime == null || _refreshToken == null) {
      return false;
    }
    
    // Refresh if token expires within 5 minutes
    return DateTime.now().add(Duration(minutes: 5)).isAfter(_tokenExpiryTime!);
  }
  
  /// Refresh access token using refresh token
  Future<bool> _refreshAccessToken() async {
    try {
      if (_refreshToken == null || _clientId == null || _clientSecret == null) {
        return false;
      }
      
      log('DropboxProvider: Refreshing access token');
      
      final response = await _httpClient!.post(
        Uri.parse('$_oauthBaseUrl/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken!,
          'client_id': _clientId!,
          'client_secret': _clientSecret!,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        
        if (data.containsKey('refresh_token')) {
          _refreshToken = data['refresh_token'];
        }
        
        if (data.containsKey('expires_in')) {
          final expiresIn = data['expires_in'] as int;
          _tokenExpiryTime = DateTime.now().add(Duration(seconds: expiresIn));
        }
        
        // Update credentials
        _credentials['access_token'] = _accessToken!;
        if (_refreshToken != null) {
          _credentials['refresh_token'] = _refreshToken!;
        }
        if (_tokenExpiryTime != null) {
          _credentials['token_expiry'] = _tokenExpiryTime!.toIso8601String();
        }
        
        log('DropboxProvider: Successfully refreshed access token');
        return true;
      } else {
        log('DropboxProvider: Token refresh failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      log('DropboxProvider: Token refresh failed: $e');
      return false;
    }
  }
  
  // Rate Limiting Methods
  
  /// Make a rate-limited HTTP request
  Future<http.Response> _makeRateLimitedRequest(
    Future<http.Response> Function() requestFunction
  ) async {
    await _waitForRateLimit();
    
    final response = await requestFunction();
    _recordRequest();
    
    // Handle rate limit response
    if (response.statusCode == 429) {
      final retryAfter = response.headers['retry-after'];
      if (retryAfter != null) {
        final waitSeconds = int.tryParse(retryAfter) ?? 1;
        log('DropboxProvider: Rate limited, waiting ${waitSeconds}s');
        await Future.delayed(Duration(seconds: waitSeconds));
        return await _makeRateLimitedRequest(requestFunction);
      }
    }
    
    return response;
  }
  
  /// Wait if we're approaching rate limits
  Future<void> _waitForRateLimit() async {
    final now = DateTime.now();
    
    // Remove old requests outside the window
    _requestTimes.removeWhere(
      (time) => now.difference(time) > _rateLimitWindow
    );
    
    // Check if we need to wait
    if (_requestTimes.length >= _burstRequestLimit) {
      final oldestRequest = _requestTimes.first;
      final waitTime = _rateLimitWindow - now.difference(oldestRequest);
      
      if (waitTime.inMilliseconds > 0) {
        log('DropboxProvider: Rate limit approaching, waiting ${waitTime.inMilliseconds}ms');
        await Future.delayed(waitTime);
      }
    }
  }
  
  /// Record a request for rate limiting
  void _recordRequest() {
    _requestTimes.add(DateTime.now());
    
    // Keep only recent requests
    final cutoff = DateTime.now().subtract(_rateLimitWindow);
    _requestTimes.removeWhere((time) => time.isBefore(cutoff));
  }
  
  // Chunked Upload Methods
  
  /// Upload file using simple upload (for small files)
  Future<bool> _uploadFileSimple(
    File localFile,
    String remotePath,
    Map<String, dynamic> metadata,
    Function(double progress)? onProgress,
  ) async {
    final fileContent = await localFile.readAsBytes();
    
    final uploadArgs = {
      'path': remotePath,
      'mode': 'overwrite',
      'autorename': false,
      'mute': false,
      'strict_conflict': false,
    };
    
    // Add custom metadata if provided
    if (metadata.isNotEmpty) {
      uploadArgs['property_groups'] = [
        {
          'template_id': 'meeting_summarizer_metadata',
          'fields': metadata.entries.map((e) => {
            'name': e.key,
            'value': e.value.toString(),
          }).toList(),
        }
      ];
    }
    
    final response = await _makeRateLimitedRequest(() async {
      return await _httpClient!.post(
        Uri.parse('$_contentBaseUrl/files/upload'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/octet-stream',
          'Dropbox-API-Arg': json.encode(uploadArgs),
        },
        body: fileContent,
      );
    });
    
    if (response.statusCode == 200) {
      if (onProgress != null) onProgress(1.0);
      log('DropboxProvider: Successfully uploaded $remotePath');
      return true;
    } else {
      throw Exception(
        'Upload failed: ${response.statusCode} ${response.body}',
      );
    }
  }
  
  /// Upload file using chunked upload (for large files)
  Future<bool> _uploadFileChunked(
    File localFile,
    String remotePath,
    Map<String, dynamic> metadata,
    Function(double progress)? onProgress,
  ) async {
    try {
      final fileSize = await localFile.length();
      log('DropboxProvider: Starting chunked upload for $remotePath ($fileSize bytes)');
      
      String? sessionId;
      int offset = 0;
      int retries = 0;
      
      while (offset < fileSize && retries < _maxRetries) {
        try {
          final chunkEnd = math.min(offset + _chunkSize, fileSize);
          final chunkSize = chunkEnd - offset;
          
          final chunk = await _readFileChunk(localFile, offset, chunkSize);
          
          if (offset == 0) {
            // Start session
            sessionId = await _startUploadSession(chunk);
            if (sessionId == null) {
              throw Exception('Failed to start upload session');
            }
          } else if (chunkEnd < fileSize) {
            // Append chunk
            final success = await _appendToUploadSession(sessionId!, chunk, offset);
            if (!success) {
              throw Exception('Failed to append chunk at offset $offset');
            }
          } else {
            // Finish upload
            final success = await _finishUploadSession(
              sessionId!,
              chunk,
              offset,
              remotePath,
              metadata,
            );
            if (!success) {
              throw Exception('Failed to finish upload session');
            }
          }
          
          offset = chunkEnd;
          retries = 0; // Reset retries on success
          
          if (onProgress != null) {
            onProgress(offset / fileSize);
          }
          
          log('DropboxProvider: Uploaded chunk $offset/$fileSize bytes');
        } catch (e) {
          retries++;
          log('DropboxProvider: Chunk upload failed (retry $retries/$_maxRetries): $e');
          
          if (retries >= _maxRetries) {
            rethrow;
          }
          
          // Exponential backoff
          await Future.delayed(Duration(seconds: math.pow(2, retries).toInt()));
        }
      }
      
      log('DropboxProvider: Successfully completed chunked upload for $remotePath');
      return true;
    } catch (e) {
      log('DropboxProvider: Chunked upload failed: $e');
      return false;
    }
  }
  
  /// Read a chunk of file data
  Future<Uint8List> _readFileChunk(File file, int offset, int length) async {
    final randomAccessFile = await file.open();
    try {
      await randomAccessFile.setPosition(offset);
      return Uint8List.fromList(await randomAccessFile.read(length));
    } finally {
      await randomAccessFile.close();
    }
  }
  
  /// Start an upload session
  Future<String?> _startUploadSession(Uint8List chunk) async {
    final response = await _makeRateLimitedRequest(() async {
      return await _httpClient!.post(
        Uri.parse('$_contentBaseUrl/files/upload_session/start'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/octet-stream',
          'Dropbox-API-Arg': json.encode({'close': false}),
        },
        body: chunk,
      );
    });
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['session_id'];
    }
    
    return null;
  }
  
  /// Append data to an upload session
  Future<bool> _appendToUploadSession(
    String sessionId,
    Uint8List chunk,
    int offset,
  ) async {
    final response = await _makeRateLimitedRequest(() async {
      return await _httpClient!.post(
        Uri.parse('$_contentBaseUrl/files/upload_session/append_v2'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/octet-stream',
          'Dropbox-API-Arg': json.encode({
            'cursor': {
              'session_id': sessionId,
              'offset': offset,
            },
            'close': false,
          }),
        },
        body: chunk,
      );
    });
    
    return response.statusCode == 200;
  }
  
  /// Finish an upload session
  Future<bool> _finishUploadSession(
    String sessionId,
    Uint8List chunk,
    int offset,
    String remotePath,
    Map<String, dynamic> metadata,
  ) async {
    final commitArgs = {
      'cursor': {
        'session_id': sessionId,
        'offset': offset,
      },
      'commit': {
        'path': remotePath,
        'mode': 'overwrite',
        'autorename': false,
        'mute': false,
        'strict_conflict': false,
      },
    };
    
    // Add custom metadata if provided
    if (metadata.isNotEmpty) {
      final commit = commitArgs['commit'] as Map<String, dynamic>;
      commit['property_groups'] = [
        {
          'template_id': 'meeting_summarizer_metadata',
          'fields': metadata.entries.map((e) => {
            'name': e.key,
            'value': e.value.toString(),
          }).toList(),
        }
      ];
    }
    
    final response = await _makeRateLimitedRequest(() async {
      return await _httpClient!.post(
        Uri.parse('$_contentBaseUrl/files/upload_session/finish'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/octet-stream',
          'Dropbox-API-Arg': json.encode(commitArgs),
        },
        body: chunk,
      );
    });
    
    return response.statusCode == 200;
  }
  
  // Paper Integration Methods
  
  /// Create a Paper document from transcript
  Future<String?> createPaperDocument({
    required String title,
    required String content,
    String? parentFolderId,
  }) async {
    try {
      if (!_isConnected || _httpClient == null) return null;
      
      log('DropboxProvider: Creating Paper document: $title');
      
      final paperContent = _formatContentForPaper(content);
      
      final response = await _makeRateLimitedRequest(() async {
        return await _httpClient!.post(
          Uri.parse('$_paperBaseUrl/docs/create'),
          headers: _getAuthHeaders(),
          body: json.encode({
            'import_format': 'markdown',
            'parent_folder_id': parentFolderId,
          }),
        );
      });
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final docId = data['doc_id'];
        
        // Update the document with content
        final updated = await _updatePaperDocument(docId, title, paperContent);
        if (updated) {
          log('DropboxProvider: Successfully created Paper document: $docId');
          return docId;
        }
      }
      
      return null;
    } catch (e) {
      _lastError = e.toString();
      log('DropboxProvider: Failed to create Paper document: $e');
      return null;
    }
  }
  
  /// Update a Paper document
  Future<bool> _updatePaperDocument(
    String docId,
    String title,
    String content,
  ) async {
    try {
      final response = await _makeRateLimitedRequest(() async {
        return await _httpClient!.post(
          Uri.parse('$_paperBaseUrl/docs/update'),
          headers: _getAuthHeaders(),
          body: json.encode({
            'doc_id': docId,
            'doc_update_policy': 'overwrite_all',
            'revision': 1,
            'import_format': 'markdown',
          }),
        );
      });
      
      return response.statusCode == 200;
    } catch (e) {
      log('DropboxProvider: Failed to update Paper document: $e');
      return false;
    }
  }
  
  /// Get Paper document content
  Future<String?> getPaperDocumentContent(String docId) async {
    try {
      if (!_isConnected || _httpClient == null) return null;
      
      final response = await _makeRateLimitedRequest(() async {
        return await _httpClient!.post(
          Uri.parse('$_paperBaseUrl/docs/download'),
          headers: _getAuthHeaders(),
          body: json.encode({
            'doc_id': docId,
            'export_format': 'markdown',
          }),
        );
      });
      
      if (response.statusCode == 200) {
        return response.body;
      }
      
      return null;
    } catch (e) {
      _lastError = e.toString();
      log('DropboxProvider: Failed to get Paper document content: $e');
      return null;
    }
  }
  
  /// List Paper documents
  Future<List<Map<String, dynamic>>> listPaperDocuments({
    String? folderId,
    int limit = 100,
  }) async {
    try {
      if (!_isConnected || _httpClient == null) return [];
      
      final response = await _makeRateLimitedRequest(() async {
        return await _httpClient!.post(
          Uri.parse('$_paperBaseUrl/docs/list'),
          headers: _getAuthHeaders(),
          body: json.encode({
            'filter_by': folderId != null ? 'docs_created' : 'docs_accessed',
            'sort_by': 'modified',
            'sort_order': 'descending',
            'limit': limit,
          }),
        );
      });
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['doc_ids'] ?? []);
      }
      
      return [];
    } catch (e) {
      _lastError = e.toString();
      log('DropboxProvider: Failed to list Paper documents: $e');
      return [];
    }
  }
  
  /// Format content for Paper (Markdown)
  String _formatContentForPaper(String content) {
    // Basic formatting for Paper documents
    final lines = content.split('\n');
    final formatted = StringBuffer();
    
    for (final line in lines) {
      if (line.trim().isEmpty) {
        formatted.writeln();
        continue;
      }
      
      // Convert timestamps to bold
      if (RegExp(r'^\d{2}:\d{2}').hasMatch(line.trim())) {
        formatted.writeln('**${line.trim()}**');
      } else {
        formatted.writeln(line);
      }
    }
    
    return formatted.toString();
  }
  
  // Helper Methods
  
  Map<String, String> _getAuthHeaders() {
    return {
      'Authorization': 'Bearer $_accessToken',
      'Content-Type': 'application/json',
    };
  }
  
  /// Generate a random string for OAuth2 state parameter
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = math.Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }
  
  /// Get MIME type from file extension
  String? _getMimeTypeFromExtension(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    final mimeTypes = {
      'txt': 'text/plain',
      'md': 'text/markdown',
      'json': 'application/json',
      'wav': 'audio/wav',
      'mp3': 'audio/mpeg',
      'mp4': 'video/mp4',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
    };
    
    return mimeTypes[extension];
  }
  
  // Public methods for external OAuth2 management
  
  /// Check if OAuth2 is configured
  bool get isOAuth2Configured => _clientId != null && _clientSecret != null;
  
  /// Get current access token
  String? get accessToken => _accessToken;
  
  /// Get current refresh token
  String? get refreshToken => _refreshToken;
  
  /// Get token expiry time
  DateTime? get tokenExpiryTime => _tokenExpiryTime;
  
  /// Check if token is expired
  bool get isTokenExpired {
    if (_tokenExpiryTime == null) return false;
    return DateTime.now().isAfter(_tokenExpiryTime!);
  }
  
  /// Manually refresh token (public method)
  Future<bool> refreshAccessToken() => _refreshAccessToken();
}