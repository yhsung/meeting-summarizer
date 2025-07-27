import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/services/cloud_providers/onedrive_provider.dart';
import 'package:meeting_summarizer/core/services/cloud_providers/cloud_provider_interface.dart';
import 'package:meeting_summarizer/core/models/cloud_sync/cloud_provider.dart';
import 'package:meeting_summarizer/core/interfaces/cloud_sync_interface.dart';

void main() {
  group('OneDriveProvider Tests', () {
    late OneDriveProvider provider;

    setUp(() {
      provider = OneDriveProvider();
    });

    tearDown(() {
      provider.disconnect();
    });

    group('Initialization', () {
      test('should initialize with required credentials', () async {
        final testProvider = OneDriveProvider();

        await testProvider.initialize({
          'client_id': 'test_client_id',
          'access_token': 'test_access_token',
        });

        expect(testProvider.provider, equals(CloudProvider.oneDrive));
      });

      test('should throw ArgumentError when client_id is missing', () async {
        final testProvider = OneDriveProvider();

        expect(
          () => testProvider.initialize({'access_token': 'test_token'}),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should handle optional credentials correctly', () async {
        final testProvider = OneDriveProvider();

        await testProvider.initialize({
          'client_id': 'test_client_id',
          'access_token': 'test_access_token',
          'refresh_token': 'test_refresh_token',
          'account_type': 'work',
          'expires_at':
              DateTime.now().add(Duration(hours: 1)).toIso8601String(),
        });

        expect(testProvider.accountType, equals('work'));
      });
    });

    group('Authentication Methods', () {
      test('should generate OAuth2 authorization URL correctly', () async {
        await provider.initialize({
          'client_id': 'test_client_id',
        });

        final authUrl = provider.generateAuthUrl(
          redirectUri: 'http://localhost:8080/callback',
          scopes: ['Files.ReadWrite.All', 'offline_access'],
        );

        expect(authUrl, contains('login.microsoftonline.com'));
        expect(authUrl, contains('client_id=test_client_id'));
        expect(authUrl, contains('response_type=code'));
        expect(authUrl,
            contains('redirect_uri=http%3A%2F%2Flocalhost%3A8080%2Fcallback'));
      });

      test(
          'should generate different tenant URLs for personal vs work accounts',
          () async {
        // Test personal account
        await provider.initialize({
          'client_id': 'test_client_id',
          'account_type': 'personal',
        });
        final personalUrl = provider.generateAuthUrl();
        expect(personalUrl, contains('9188040d-6c67-4c5b-b112-36a304b66dad'));

        // Test work account
        await provider.updateConfiguration({
          'client_id': 'test_client_id',
          'account_type': 'work',
        });
        final workUrl = provider.generateAuthUrl();
        expect(workUrl, contains('common'));
      });
    });

    group('File Operations', () {
      test('should handle file operations when not connected', () async {
        // Without proper authentication, file operations should fail gracefully
        final exists = await provider.fileExists('test_file.txt');
        expect(exists, isFalse);

        final metadata = await provider.getFileMetadata('test_file.txt');
        expect(metadata, isNull);

        final files = await provider.listFiles();
        expect(files, isEmpty);
      });
    });

    group('Storage Quota', () {
      test('should return default quota when not connected', () async {
        final quota = await provider.getStorageQuota();
        // Should return default quota when not connected
        expect(quota.totalBytes, equals(5 * 1024 * 1024 * 1024));
        expect(quota.provider, equals(CloudProvider.oneDrive));
      });
    });

    group('Delta Sync', () {
      test('should return empty changes when not connected', () async {
        final changes = await provider.getRemoteChanges();
        expect(changes, isEmpty);
      });

      test('should handle delta token correctly', () {
        expect(provider.deltaToken, isNull);

        provider.deltaToken = 'test_token_123';
        expect(provider.deltaToken, equals('test_token_123'));

        provider.resetDeltaToken();
        expect(provider.deltaToken, isNull);
      });
    });

    group('Account Type Detection', () {
      test('should detect personal account correctly', () async {
        provider.updateConfiguration({
          'client_id': 'test_client_id',
          'account_type': 'personal',
        });

        expect(provider.isPersonalAccount, isTrue);
        expect(provider.isBusinessAccount, isFalse);
        expect(provider.accountType, equals('personal'));
      });

      test('should detect business account correctly', () async {
        provider.updateConfiguration({
          'client_id': 'test_client_id',
          'account_type': 'work',
        });

        expect(provider.isPersonalAccount, isFalse);
        expect(provider.isBusinessAccount, isTrue);
        expect(provider.accountType, equals('work'));
      });
    });

    group('Error Handling', () {
      test('should initialize last error as null', () {
        expect(provider.getLastError(), isNull);
      });

      test('should handle connection test gracefully when not initialized',
          () async {
        final connected = await provider.testConnection();
        expect(connected, isFalse);
      });
    });

    group('Configuration Management', () {
      test('should update configuration correctly', () async {
        await provider.updateConfiguration({
          'client_id': 'new_client_id',
          'access_token': 'new_access_token',
          'refresh_token': 'new_refresh_token',
          'account_type': 'work',
          'expires_at': '2023-12-31T23:59:59Z',
        });

        final config = provider.getConfiguration();
        expect(config['client_id'], equals('new_client_id'));
        expect(config['access_token'], equals('new_access_token'));
        expect(config['account_type'], equals('work'));
      });

      test('should get configuration correctly', () async {
        await provider.initialize({
          'client_id': 'test_client_id',
        });

        final config = provider.getConfiguration();
        expect(config, isA<Map<String, dynamic>>());
        expect(config.containsKey('client_id'), isTrue);
      });
    });
  });
}
