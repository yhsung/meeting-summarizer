import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/services/encryption_service.dart';

void main() {
  group('EncryptionService Tests', () {
    // Mock storage for testing
    final Map<String, String> mockStorage = {};

    setUpAll(() async {
      // Initialize Flutter test framework
      TestWidgetsFlutterBinding.ensureInitialized();

      // Mock the secure storage since it won't work in tests
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'read':
              final key = methodCall.arguments['key'] as String;
              return mockStorage[key];
            case 'write':
              final key = methodCall.arguments['key'] as String;
              final value = methodCall.arguments['value'] as String;
              mockStorage[key] = value;
              return null;
            case 'delete':
              final key = methodCall.arguments['key'] as String;
              mockStorage.remove(key);
              return null;
            case 'readAll':
              return Map<String, String>.from(mockStorage);
            case 'deleteAll':
              mockStorage.clear();
              return null;
            default:
              return null;
          }
        },
      );

      // Initialize encryption service for testing
      await EncryptionService.initialize();
    });

    tearDown(() async {
      // Clean up test keys after each test
      final keys = await EncryptionService.listEncryptionKeys();
      for (final key in keys) {
        if (key.contains('test')) {
          await EncryptionService.deleteEncryptionKey(key);
        }
      }
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        // Initialization is done in setUpAll, so we just verify it works
        expect(() => EncryptionService.initialize(), returnsNormally);
      });

      test('should check if encryption is available', () async {
        final isAvailable = await EncryptionService.isEncryptionAvailable();
        expect(isAvailable, isA<bool>());
      });
    });

    group('Key Management', () {
      test('should create encryption key for specific purpose', () async {
        final keyId = await EncryptionService.createEncryptionKey(
          'test_purpose',
        );

        expect(keyId, isNotNull);
        expect(keyId, contains('test_purpose'));
        expect(keyId, contains('encryption_key_'));
      });

      test('should list encryption keys', () async {
        // Create a test key
        final keyId = await EncryptionService.createEncryptionKey('test_list');

        final keys = await EncryptionService.listEncryptionKeys();
        expect(keys, contains(keyId));
      });

      test('should delete encryption key', () async {
        // Create a test key
        final keyId = await EncryptionService.createEncryptionKey(
          'test_delete',
        );

        // Verify it exists
        final keysBeforeDelete = await EncryptionService.listEncryptionKeys();
        expect(keysBeforeDelete, contains(keyId));

        // Delete the key
        final deleted = await EncryptionService.deleteEncryptionKey(keyId);
        expect(deleted, isTrue);

        // Verify it's gone
        final keysAfterDelete = await EncryptionService.listEncryptionKeys();
        expect(keysAfterDelete, isNot(contains(keyId)));
      });
    });

    group('Data Encryption and Decryption', () {
      late String testKeyId;

      setUp(() async {
        testKeyId = await EncryptionService.createEncryptionKey('test_data');
      });

      test('should encrypt and decrypt simple text', () async {
        const testData = 'Hello, World! This is a test string.';

        // Encrypt the data
        final encrypted = await EncryptionService.encryptData(
          testData,
          testKeyId,
        );
        expect(encrypted, isNotNull);
        expect(encrypted!['data'], isNotNull);
        expect(encrypted['iv'], isNotNull);
        expect(encrypted['tag'], isNotNull);
        expect(encrypted['keyId'], equals(testKeyId));

        // Decrypt the data
        final decrypted = await EncryptionService.decryptData(encrypted);
        expect(decrypted, equals(testData));
      });

      test('should encrypt and decrypt JSON data', () async {
        const testData =
            '{"name": "Test User", "email": "test@example.com", "sensitive": "secret info"}';

        final encrypted = await EncryptionService.encryptData(
          testData,
          testKeyId,
        );
        expect(encrypted, isNotNull);

        final decrypted = await EncryptionService.decryptData(encrypted!);
        expect(decrypted, equals(testData));
      });

      test('should encrypt and decrypt empty string', () async {
        const testData = '';

        final encrypted = await EncryptionService.encryptData(
          testData,
          testKeyId,
        );
        expect(encrypted, isNotNull);

        final decrypted = await EncryptionService.decryptData(encrypted!);
        expect(decrypted, equals(testData));
      });

      test('should encrypt and decrypt large text', () async {
        final testData = 'A' * 10000; // 10KB of 'A' characters

        final encrypted = await EncryptionService.encryptData(
          testData,
          testKeyId,
        );
        expect(encrypted, isNotNull);

        final decrypted = await EncryptionService.decryptData(encrypted!);
        expect(decrypted, equals(testData));
      });

      test('should encrypt and decrypt special characters', () async {
        const testData = 'Special chars: àáâãäåæçèéêë 中文 🔒🎵📝';

        final encrypted = await EncryptionService.encryptData(
          testData,
          testKeyId,
        );
        expect(encrypted, isNotNull);

        final decrypted = await EncryptionService.decryptData(encrypted!);
        expect(decrypted, equals(testData));
      });

      test('should produce different ciphertext for same plaintext', () async {
        const testData = 'Same plaintext';

        final encrypted1 = await EncryptionService.encryptData(
          testData,
          testKeyId,
        );
        final encrypted2 = await EncryptionService.encryptData(
          testData,
          testKeyId,
        );

        expect(encrypted1, isNotNull);
        expect(encrypted2, isNotNull);

        // Different IVs should produce different ciphertext
        expect(encrypted1!['data'], isNot(equals(encrypted2!['data'])));
        expect(encrypted1['iv'], isNot(equals(encrypted2['iv'])));

        // But both should decrypt to the same plaintext
        final decrypted1 = await EncryptionService.decryptData(encrypted1);
        final decrypted2 = await EncryptionService.decryptData(encrypted2);

        expect(decrypted1, equals(testData));
        expect(decrypted2, equals(testData));
      });
    });

    group('Error Handling', () {
      test('should handle encryption with invalid key ID', () async {
        const testData = 'Test data';
        const invalidKeyId = 'invalid_key_id';

        final encrypted = await EncryptionService.encryptData(
          testData,
          invalidKeyId,
        );
        expect(encrypted, isNull);
      });

      test('should handle decryption with missing key ID', () async {
        final encryptedData = {
          'data': 'dGVzdA==', // base64 encoded 'test'
          'iv': 'aXY=', // base64 encoded 'iv'
          'tag': 'dGFn', // base64 encoded 'tag'
          // Missing keyId
        };

        final decrypted = await EncryptionService.decryptData(
          Map<String, String>.from(encryptedData),
        );
        expect(decrypted, isNull);
      });

      test('should handle decryption with invalid encrypted data', () async {
        final encryptedData = {
          'data': 'invalid_base64!@#',
          'iv': 'aXY=',
          'tag': 'dGFn',
          'keyId': 'some_key',
        };

        final decrypted = await EncryptionService.decryptData(encryptedData);
        expect(decrypted, isNull);
      });

      test('should handle decryption with tampered data', () async {
        final testKeyId = await EncryptionService.createEncryptionKey(
          'test_tamper',
        );
        const testData = 'Original data';

        final encrypted = await EncryptionService.encryptData(
          testData,
          testKeyId,
        );
        expect(encrypted, isNotNull);

        // Tamper with the encrypted data
        final tamperedData = Map<String, String>.from(encrypted!);
        tamperedData['data'] = 'dGFtcGVyZWQ='; // base64 encoded 'tampered'

        final decrypted = await EncryptionService.decryptData(tamperedData);
        expect(
          decrypted,
          isNull,
        ); // Should fail due to authentication tag mismatch
      });
    });

    group('Key Lifecycle', () {
      test('should handle multiple keys for different purposes', () async {
        final keyId1 = await EncryptionService.createEncryptionKey(
          'test_purpose1',
        );
        final keyId2 = await EncryptionService.createEncryptionKey(
          'test_purpose2',
        );

        expect(keyId1, isNot(equals(keyId2)));

        const testData = 'Test data for multiple keys';

        // Encrypt with different keys
        final encrypted1 = await EncryptionService.encryptData(
          testData,
          keyId1,
        );
        final encrypted2 = await EncryptionService.encryptData(
          testData,
          keyId2,
        );

        expect(encrypted1, isNotNull);
        expect(encrypted2, isNotNull);
        expect(encrypted1!['keyId'], equals(keyId1));
        expect(encrypted2!['keyId'], equals(keyId2));

        // Decrypt with correct keys
        final decrypted1 = await EncryptionService.decryptData(encrypted1);
        final decrypted2 = await EncryptionService.decryptData(encrypted2);

        expect(decrypted1, equals(testData));
        expect(decrypted2, equals(testData));
      });

      test(
        'should fail to decrypt with wrong key after key deletion',
        () async {
          final keyId = await EncryptionService.createEncryptionKey(
            'test_deletion',
          );
          const testData = 'Data that will become inaccessible';

          // Encrypt data
          final encrypted = await EncryptionService.encryptData(
            testData,
            keyId,
          );
          expect(encrypted, isNotNull);

          // Verify decryption works
          final decrypted = await EncryptionService.decryptData(encrypted!);
          expect(decrypted, equals(testData));

          // Delete the key
          await EncryptionService.deleteEncryptionKey(keyId);

          // Try to decrypt again - should fail
          final decryptedAfterDeletion = await EncryptionService.decryptData(
            encrypted,
          );
          expect(decryptedAfterDeletion, isNull);
        },
      );
    });

    group('Performance and Security', () {
      test('should handle concurrent encryption operations', () async {
        final keyId = await EncryptionService.createEncryptionKey(
          'test_concurrent',
        );
        const testData = 'Concurrent test data';

        // Perform multiple encryptions concurrently
        final futures = List.generate(
          10,
          (index) => EncryptionService.encryptData('$testData $index', keyId),
        );

        final results = await Future.wait(futures);

        // All encryptions should succeed
        for (final result in results) {
          expect(result, isNotNull);
        }

        // All decryptions should succeed and return correct data
        for (int i = 0; i < results.length; i++) {
          final decrypted = await EncryptionService.decryptData(results[i]!);
          expect(decrypted, equals('$testData $i'));
        }
      });

      test(
        'should have reasonable performance for typical data sizes',
        () async {
          final keyId = await EncryptionService.createEncryptionKey(
            'test_performance',
          );
          final testData = 'A' * 1000; // 1KB of data

          final stopwatch = Stopwatch()..start();

          // Perform encryption and decryption
          final encrypted = await EncryptionService.encryptData(
            testData,
            keyId,
          );
          final decrypted = await EncryptionService.decryptData(encrypted!);

          stopwatch.stop();

          expect(decrypted, equals(testData));

          // Should complete in reasonable time (less than 1 second for 1KB)
          expect(stopwatch.elapsedMilliseconds, lessThan(1000));
        },
      );
    });

    group('Password-Based Encryption', () {
      test('should encrypt and decrypt with password', () async {
        const testData = 'password protected data';
        const password = 'secure_password_123';

        final encrypted = await EncryptionService.encryptWithPassword(
          testData,
          password,
        );
        expect(encrypted, isNotNull);
        expect(encrypted!['data'], isNotEmpty);
        expect(encrypted['salt'], isNotEmpty);
        expect(encrypted['iv'], isNotEmpty);
        expect(encrypted['tag'], isNotEmpty);
        expect(encrypted['iterations'], isNotEmpty);

        final decrypted = await EncryptionService.decryptWithPassword(
          encrypted,
          password,
        );
        expect(decrypted, equals(testData));
      });

      test('should fail with wrong password', () async {
        const testData = 'password protected data';
        const password = 'correct_password';
        const wrongPassword = 'wrong_password';

        final encrypted = await EncryptionService.encryptWithPassword(
          testData,
          password,
        );
        expect(encrypted, isNotNull);

        final decrypted = await EncryptionService.decryptWithPassword(
          encrypted!,
          wrongPassword,
        );
        expect(decrypted, isNull);
      });

      test('should handle empty password and data', () async {
        const testData = '';
        const password = 'password';

        final encrypted = await EncryptionService.encryptWithPassword(
          testData,
          password,
        );
        expect(encrypted, isNotNull);

        final decrypted = await EncryptionService.decryptWithPassword(
          encrypted!,
          password,
        );
        expect(decrypted, equals(testData));
      });

      test(
        'should produce different results with same password and data',
        () async {
          const testData = 'same data';
          const password = 'same password';

          final encrypted1 = await EncryptionService.encryptWithPassword(
            testData,
            password,
          );
          final encrypted2 = await EncryptionService.encryptWithPassword(
            testData,
            password,
          );

          expect(encrypted1, isNotNull);
          expect(encrypted2, isNotNull);
          expect(encrypted1!['data'], isNot(equals(encrypted2!['data'])));
          expect(encrypted1['salt'], isNot(equals(encrypted2['salt'])));
          expect(encrypted1['iv'], isNot(equals(encrypted2['iv'])));
        },
      );
    });
  });

  group('SecureKeyManager Tests', () {
    group('Key Rotation', () {
      test('should rotate key successfully', () async {
        final originalKeyId = await EncryptionService.createEncryptionKey(
          'test_rotation',
        );

        final newKeyId = await SecureKeyManager.rotateKey(originalKeyId);
        expect(newKeyId, isNotNull);
        expect(newKeyId, isNot(equals(originalKeyId)));
        expect(newKeyId!, contains('rotated'));

        // Original key should still exist (for backward compatibility)
        final keys = await EncryptionService.listEncryptionKeys();
        expect(keys, contains(originalKeyId));
        expect(keys, contains(newKeyId));
      });

      test('should handle rotation of non-existent key', () async {
        const nonExistentKeyId = 'non_existent_key';

        final newKeyId = await SecureKeyManager.rotateKey(nonExistentKeyId);
        expect(newKeyId, isNull);
      });
    });

    group('Key Backup and Recovery', () {
      test('should create and restore key backup', () async {
        final originalKeyId = await EncryptionService.createEncryptionKey(
          'test_backup',
        );
        const masterPassword = 'backup_password_123';

        // Create backup
        final backupSuccess = await SecureKeyManager.createKeyBackup(
          originalKeyId,
          masterPassword,
        );
        expect(backupSuccess, isTrue);

        // List backups
        final backups = await SecureKeyManager.listKeyBackups();
        expect(backups, isNotEmpty);
        expect(backups.first['originalKeyId'], equals(originalKeyId));
        expect(backups.first['isPasswordProtected'], isTrue);

        // Restore from backup
        final backupId = backups.first['backupId'] as String;
        final restoredKeyId = await SecureKeyManager.restoreKeyFromBackup(
          backupId,
          masterPassword,
        );
        expect(restoredKeyId, isNotNull);
        expect(restoredKeyId!, contains('restored'));

        // Test that restored key works
        const testData = 'test data for restored key';
        final encrypted = await EncryptionService.encryptData(
          testData,
          restoredKeyId,
        );
        expect(encrypted, isNotNull);

        final decrypted = await EncryptionService.decryptData(encrypted!);
        expect(decrypted, equals(testData));
      });

      test('should fail backup restoration with wrong password', () async {
        final originalKeyId = await EncryptionService.createEncryptionKey(
          'test_wrong_password',
        );
        const masterPassword = 'correct_password';
        const wrongPassword = 'wrong_password';

        final backupSuccess = await SecureKeyManager.createKeyBackup(
          originalKeyId,
          masterPassword,
        );
        expect(backupSuccess, isTrue);

        final backups = await SecureKeyManager.listKeyBackups();
        final backupId = backups.last['backupId'] as String;

        final restoredKeyId = await SecureKeyManager.restoreKeyFromBackup(
          backupId,
          wrongPassword,
        );
        expect(restoredKeyId, isNull);
      });

      test('should handle backup of non-existent key', () async {
        const nonExistentKeyId = 'non_existent_key';
        const masterPassword = 'password';

        final backupSuccess = await SecureKeyManager.createKeyBackup(
          nonExistentKeyId,
          masterPassword,
        );
        expect(backupSuccess, isFalse);
      });
    });

    group('Secure Key Deletion', () {
      test('should securely delete key', () async {
        final keyId = await EncryptionService.createEncryptionKey(
          'test_secure_delete',
        );

        // Verify key exists
        final keysBefore = await EncryptionService.listEncryptionKeys();
        expect(keysBefore, contains(keyId));

        // Securely delete key
        final deleteSuccess = await SecureKeyManager.secureDeleteKey(keyId);
        expect(deleteSuccess, isTrue);

        // Verify key is deleted
        final keysAfter = await EncryptionService.listEncryptionKeys();
        expect(keysAfter, isNot(contains(keyId)));
      });

      test('should handle deletion of non-existent key', () async {
        const nonExistentKeyId = 'non_existent_key';

        final deleteSuccess = await SecureKeyManager.secureDeleteKey(
          nonExistentKeyId,
        );
        expect(deleteSuccess, isTrue); // Should not throw, just return true
      });
    });

    group('Key Backup Listing', () {
      test('should list all key backups', () async {
        // Create multiple keys and backups
        final keyId1 = await EncryptionService.createEncryptionKey(
          'test_list_1',
        );
        final keyId2 = await EncryptionService.createEncryptionKey(
          'test_list_2',
        );

        await SecureKeyManager.createKeyBackup(keyId1, 'password1');
        await SecureKeyManager.createKeyBackup(keyId2, 'password2');

        final backups = await SecureKeyManager.listKeyBackups();
        expect(backups.length, greaterThanOrEqualTo(2));

        // Check that backups contain required metadata
        for (final backup in backups) {
          expect(backup, containsPair('backupId', isA<String>()));
          expect(backup, containsPair('originalKeyId', isA<String>()));
          expect(backup, containsPair('createdAt', isA<String>()));
          expect(backup, containsPair('isPasswordProtected', isTrue));
        }
      });
    });
  });
}
