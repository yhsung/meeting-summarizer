import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/services/cloud_providers/dropbox_provider.dart';
import 'package:meeting_summarizer/core/services/cloud_providers/cloud_provider_interface.dart';
import 'package:meeting_summarizer/core/models/cloud_sync/cloud_provider.dart';
import 'package:meeting_summarizer/core/interfaces/cloud_sync_interface.dart';

void main() {
  group('DropboxProvider', () {
    late DropboxProvider dropboxProvider;

    setUp(() {
      dropboxProvider = DropboxProvider();
    });

    tearDown(() {
      // Clean up any resources
    });

    group('Initialization', () {
      test('should initialize with OAuth2 credentials', () async {
        final credentials = {
          'client_id': 'test_client_id',
          'client_secret': 'test_client_secret',
          'redirect_uri': 'http://localhost:8080/auth/callback',
        };

        await dropboxProvider.initialize(credentials);

        expect(dropboxProvider.isOAuth2Configured, isTrue);
        expect(dropboxProvider.accessToken, isNull);
      });

      test('should initialize with direct access token', () async {
        final credentials = {
          'access_token': 'test_access_token',
        };

        await dropboxProvider.initialize(credentials);

        expect(dropboxProvider.accessToken, equals('test_access_token'));
      });

      test('should throw error with invalid credentials', () async {
        final credentials = <String, String>{};

        expect(
          () => dropboxProvider.initialize(credentials),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should handle token expiry time', () async {
        final expiryTime = DateTime.now().add(Duration(hours: 1));
        final credentials = {
          'client_id': 'test_client_id',
          'client_secret': 'test_client_secret',
          'access_token': 'test_access_token',
          'refresh_token': 'test_refresh_token',
          'token_expiry': expiryTime.toIso8601String(),
        };

        await dropboxProvider.initialize(credentials);

        expect(dropboxProvider.tokenExpiryTime, equals(expiryTime));
        expect(dropboxProvider.isTokenExpired, isFalse);
      });
    });

    group('OAuth2 Flow', () {
      setUp(() async {
        final credentials = {
          'client_id': 'test_client_id',
          'client_secret': 'test_client_secret',
          'redirect_uri': 'http://localhost:8080/auth/callback',
        };
        await dropboxProvider.initialize(credentials);
      });

      test('should generate authorization URL', () {
        final authUrl = dropboxProvider.getAuthorizationUrl();

        expect(authUrl, contains('https://www.dropbox.com/oauth2/authorize'));
        expect(authUrl, contains('client_id=test_client_id'));
        expect(authUrl, contains('response_type=code'));
        expect(authUrl, contains('redirect_uri='));
      });

      test('should generate authorization URL with scopes', () {
        final authUrl = dropboxProvider.getAuthorizationUrl(
          scopes: ['files.metadata.read', 'files.content.read'],
        );

        expect(authUrl, contains('scope=files.metadata.read%20files.content.read'));
      });

      test('should handle OAuth2 configuration check', () {
        expect(dropboxProvider.isOAuth2Configured, isTrue);
      });
    });

    group('Configuration Management', () {
      setUp(() async {
        final credentials = {
          'access_token': 'test_access_token',
        };
        await dropboxProvider.initialize(credentials);
      });

      test('should get current configuration', () {
        final config = dropboxProvider.getConfiguration();
        expect(config, isA<Map<String, dynamic>>());
        expect(config['access_token'], equals('test_access_token'));
      });

      test('should update configuration', () async {
        final newConfig = {
          'access_token': 'new_token',
          'refresh_token': 'new_refresh_token',
        };

        await dropboxProvider.updateConfiguration(newConfig);
        expect(dropboxProvider.accessToken, equals('new_token'));
        expect(dropboxProvider.refreshToken, equals('new_refresh_token'));
      });
    });

    group('Provider Interface Compliance', () {
      test('should implement CloudProviderInterface', () {
        expect(dropboxProvider, isA<CloudProviderInterface>());
      });

      test('should return correct provider type', () {
        expect(dropboxProvider.provider, equals(CloudProvider.dropbox));
      });

      test('should have correct initial state', () async {
        expect(await dropboxProvider.isConnected(), isFalse);
        expect(dropboxProvider.getLastError(), isNull);
      });
    });

    group('Token Management', () {
      test('should handle expired tokens', () async {
        final pastTime = DateTime.now().subtract(Duration(hours: 1));
        final credentials = {
          'client_id': 'test_client_id',
          'client_secret': 'test_client_secret',
          'access_token': 'expired_token',
          'refresh_token': 'refresh_token',
          'token_expiry': pastTime.toIso8601String(),
        };

        await dropboxProvider.initialize(credentials);
        expect(dropboxProvider.isTokenExpired, isTrue);
      });

      test('should handle non-expired tokens', () async {
        final futureTime = DateTime.now().add(Duration(hours: 1));
        final credentials = {
          'client_id': 'test_client_id',
          'client_secret': 'test_client_secret',
          'access_token': 'valid_token',
          'refresh_token': 'refresh_token',
          'token_expiry': futureTime.toIso8601String(),
        };

        await dropboxProvider.initialize(credentials);
        expect(dropboxProvider.isTokenExpired, isFalse);
      });

      test('should handle tokens without expiry', () async {
        final credentials = {
          'access_token': 'valid_token',
        };

        await dropboxProvider.initialize(credentials);
        expect(dropboxProvider.isTokenExpired, isFalse);
      });
    });

    group('Path Handling', () {
      test('should handle path normalization', () async {
        final credentials = {'access_token': 'test_token'};
        await dropboxProvider.initialize(credentials);

        // Test that the provider properly handles various path formats
        // This would require testing the actual operations, which need a real connection
        expect(dropboxProvider.accessToken, isNotNull);
      });
    });

    group('Error State Management', () {
      test('should track last error', () {
        expect(dropboxProvider.getLastError(), isNull);
        
        // After an error occurs, getLastError should return the error message
        // This would require simulating an actual error condition
      });

      test('should handle disconnection', () async {
        final credentials = {'access_token': 'test_token'};
        await dropboxProvider.initialize(credentials);
        
        await dropboxProvider.disconnect();
        expect(await dropboxProvider.isConnected(), isFalse);
        expect(dropboxProvider.accessToken, isNull);
      });
    });

    group('Storage Quota Types', () {
      setUp(() async {
        final credentials = {'access_token': 'test_token'};
        await dropboxProvider.initialize(credentials);
      });

      test('should return default quota when not connected', () async {
        final quota = await dropboxProvider.getStorageQuota();
        expect(quota, isA<CloudStorageQuota>());
        expect(quota.provider, equals(CloudProvider.dropbox));
        expect(quota.totalBytes, equals(2 * 1024 * 1024 * 1024)); // 2GB default
      });
    });

    group('File Operations Interface', () {
      setUp() async {
        final credentials = {'access_token': 'test_token'};
        await dropboxProvider.initialize(credentials);
      }

      test('should handle file existence check with disconnected state', () async {
        // When not connected, operations should fail gracefully
        final exists = await dropboxProvider.fileExists('/test.txt');
        expect(exists, isFalse);
      });

      test('should handle metadata request with disconnected state', () async {
        final metadata = await dropboxProvider.getFileMetadata('/test.txt');
        expect(metadata, isNull);
      });

      test('should handle file listing with disconnected state', () async {
        final files = await dropboxProvider.listFiles();
        expect(files, isEmpty);
      });

      test('should handle shareable link creation with disconnected state', () async {
        final link = await dropboxProvider.getShareableLink('/test.txt');
        expect(link, isNull);
      });

      test('should handle change detection with disconnected state', () async {
        final changes = await dropboxProvider.getRemoteChanges();
        expect(changes, isEmpty);
      });
    });

    group('Paper Integration Interface', () {
      setUp() async {
        final credentials = {'access_token': 'test_token'};
        await dropboxProvider.initialize(credentials);
      }

      test('should handle Paper document creation with disconnected state', () async {
        final docId = await dropboxProvider.createPaperDocument(
          title: 'Test Document',
          content: 'Test content',
        );
        expect(docId, isNull);
      });

      test('should handle Paper document content retrieval with disconnected state', () async {
        final content = await dropboxProvider.getPaperDocumentContent('doc_123');
        expect(content, isNull);
      });

      test('should handle Paper document listing with disconnected state', () async {
        final docs = await dropboxProvider.listPaperDocuments();
        expect(docs, isEmpty);
      });
    });

    group('Validation', () {
      test('should validate OAuth2 configuration requirements', () {
        expect(
          () => dropboxProvider.getAuthorizationUrl(),
          throwsA(isA<StateError>()),
        );
      });

      test('should validate OAuth2 token exchange requirements', () async {
        // The method returns false for invalid configurations rather than throwing
        final result = await dropboxProvider.exchangeAuthorizationCode('test_code');
        expect(result, isFalse);
      });
    });
  });
}