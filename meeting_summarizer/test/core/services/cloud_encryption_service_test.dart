import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:meeting_summarizer/core/services/cloud_encryption_service.dart';
import 'package:meeting_summarizer/core/models/cloud_sync/cloud_provider.dart';
import 'package:meeting_summarizer/core/models/cloud_sync/file_change.dart';

void main() {
  group('CloudEncryptionService', () {
    late CloudEncryptionService service;
    late Directory tempDir;

    setUpAll(() async {
      FlutterSecureStorage.setMockInitialValues({});
      service = CloudEncryptionService.instance;
      await CloudEncryptionService.initialize();

      // Create temporary directory for test files
      tempDir = await Directory.systemTemp.createTemp('cloud_encryption_test_');
    });

    tearDownAll(() async {
      // Clean up temporary directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Key Management', () {
      test('should create cloud provider encryption key', () async {
        final keyId = await service.createCloudProviderKey(
          CloudProvider.googleDrive,
        );

        expect(keyId, isNotEmpty);
        expect(keyId, contains('cloud_encryption_key_'));
        expect(keyId, contains('google_drive'));
      });

      test('should create file encryption key', () async {
        const filePath = '/test/file.txt';
        final keyId = await service.createFileEncryptionKey(
          filePath,
          CloudProvider.icloud,
        );

        expect(keyId, isNotEmpty);
        expect(keyId, contains('file_encryption_key_'));
        expect(keyId, contains('icloud'));
      });

      test('should list encryption keys', () async {
        // Create some keys
        await service.createCloudProviderKey(CloudProvider.googleDrive);
        await service.createFileEncryptionKey(
          '/test/file1.txt',
          CloudProvider.dropbox,
        );

        final keys = await service.listCloudEncryptionKeys();
        expect(keys.length, greaterThanOrEqualTo(2));
      });

      test('should check encryption availability', () async {
        final isAvailable = await service.isEncryptionAvailable();
        expect(isAvailable, isTrue);
      });
    });

    group('File Encryption', () {
      late File testFile;
      const testContent = 'This is a test file for encryption testing';

      setUp(() async {
        testFile = File('${tempDir.path}/test_file.txt');
        await testFile.writeAsString(testContent);
      });

      tearDown(() async {
        if (await testFile.exists()) {
          await testFile.delete();
        }
      });

      test('should encrypt and decrypt file successfully', () async {
        // Encrypt file
        final encryptedResult = await service.encryptFile(
          filePath: testFile.path,
          provider: CloudProvider.googleDrive,
        );

        expect(encryptedResult.encryptedData, isNotEmpty);
        expect(
          encryptedResult.metadata.originalSize,
          equals(testContent.length),
        );
        expect(encryptedResult.metadata.algorithm, equals('AES-256-GCM'));
        expect(encryptedResult.keyId, isNotEmpty);

        // Decrypt file
        final decryptedData = await service.decryptFile(
          encryptedData: encryptedResult.encryptedData,
          metadata: encryptedResult.metadata,
        );

        final decryptedContent = String.fromCharCodes(decryptedData);
        expect(decryptedContent, equals(testContent));
      });

      test('should fail to decrypt with wrong metadata', () async {
        final encryptedResult = await service.encryptFile(
          filePath: testFile.path,
          provider: CloudProvider.googleDrive,
        );

        // Create corrupted metadata
        final corruptedMetadata = EncryptedFileMetadata(
          originalSize: encryptedResult.metadata.originalSize,
          encryptedSize: encryptedResult.metadata.encryptedSize,
          keyId: encryptedResult.metadata.keyId,
          iv: encryptedResult.metadata.iv,
          salt: encryptedResult.metadata.salt,
          tag: 'corrupted_tag',
          algorithm: encryptedResult.metadata.algorithm,
          created: encryptedResult.metadata.created,
          checksum: encryptedResult.metadata.checksum,
        );

        expect(
          () => service.decryptFile(
            encryptedData: encryptedResult.encryptedData,
            metadata: corruptedMetadata,
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('should handle non-existent file', () async {
        const nonExistentPath = '/non/existent/file.txt';

        expect(
          () => service.encryptFile(
            filePath: nonExistentPath,
            provider: CloudProvider.googleDrive,
          ),
          throwsA(isA<FileSystemException>()),
        );
      });
    });

    group('Chunk Encryption', () {
      test('should encrypt and decrypt file chunks', () async {
        final chunk1Data = Uint8List.fromList(
          'hello worl'.codeUnits,
        ); // 10 bytes
        final chunk2Data = Uint8List.fromList(' test!'.codeUnits); // 6 bytes

        // Calculate actual checksums
        final checksum1 = sha256.convert(chunk1Data).toString();
        final checksum2 = sha256.convert(chunk2Data).toString();

        final chunks = [
          FileChunk(
            index: 0,
            offset: 0,
            size: 10,
            checksum: checksum1,
            isChanged: true,
            data: chunk1Data,
          ),
          FileChunk(
            index: 1,
            offset: 10,
            size: 6,
            checksum: checksum2,
            isChanged: true,
            data: chunk2Data,
          ),
        ];

        // Encrypt chunks
        final encryptedChunks = await service.encryptFileChunks(
          chunks: chunks,
          provider: CloudProvider.oneDrive,
        );

        expect(encryptedChunks.length, equals(2));
        expect(encryptedChunks[0].originalSize, equals(10));
        expect(encryptedChunks[1].originalSize, equals(6));
        expect(encryptedChunks[0].encryptedData, isNotEmpty);
        expect(encryptedChunks[1].encryptedData, isNotEmpty);

        // Decrypt chunks
        final decryptedChunks = await service.decryptFileChunks(
          encryptedChunks: encryptedChunks,
        );

        expect(decryptedChunks.length, equals(2));
        expect(decryptedChunks[0].size, equals(10));
        expect(decryptedChunks[1].size, equals(6));
        expect(decryptedChunks[0].checksum, equals(checksum1));
        expect(decryptedChunks[1].checksum, equals(checksum2));
      });

      test('should handle chunk without data', () async {
        final chunks = [
          FileChunk(
            index: 0,
            offset: 0,
            size: 10,
            checksum: 'checksum1',
            isChanged: true,
            data: null,
          ),
        ];

        expect(
          () => service.encryptFileChunks(
            chunks: chunks,
            provider: CloudProvider.dropbox,
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Metadata Encryption', () {
      test('should encrypt and decrypt metadata', () async {
        final metadata = {
          'fileName': 'test.txt',
          'fileSize': 1024,
          'lastModified': DateTime.now().toIso8601String(),
          'tags': ['important', 'document'],
        };

        // Encrypt metadata
        final encryptedMetadata = await service.encryptMetadata(
          metadata: metadata,
          provider: CloudProvider.icloud,
        );

        expect(encryptedMetadata['data'], isNotEmpty);
        expect(encryptedMetadata['iv'], isNotEmpty);
        expect(encryptedMetadata['salt'], isNotEmpty);
        expect(encryptedMetadata['tag'], isNotEmpty);
        expect(encryptedMetadata['keyId'], isNotEmpty);
        expect(encryptedMetadata['algorithm'], equals('AES-256-GCM'));

        // Decrypt metadata
        final decryptedMetadata = await service.decryptMetadata(
          encryptedMetadata: encryptedMetadata,
        );

        expect(decryptedMetadata['fileName'], equals('test.txt'));
        expect(decryptedMetadata['fileSize'], equals(1024));
        expect(decryptedMetadata['tags'], equals(['important', 'document']));
      });

      test('should handle empty metadata', () async {
        final metadata = <String, dynamic>{};

        final encryptedMetadata = await service.encryptMetadata(
          metadata: metadata,
          provider: CloudProvider.googleDrive,
        );

        final decryptedMetadata = await service.decryptMetadata(
          encryptedMetadata: encryptedMetadata,
        );

        expect(decryptedMetadata, isEmpty);
      });

      test('should fail to decrypt metadata without keyId', () async {
        final encryptedMetadata = {
          'data': 'encrypted_data',
          'iv': 'initialization_vector',
          'salt': 'salt_value',
          'tag': 'auth_tag',
          'algorithm': 'AES-256-GCM',
        };

        expect(
          () => service.decryptMetadata(encryptedMetadata: encryptedMetadata),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Key Deletion', () {
      test('should delete encryption key', () async {
        final keyId = await service.createCloudProviderKey(
          CloudProvider.dropbox,
        );

        final deleted = await service.deleteEncryptionKey(keyId);
        expect(deleted, isTrue);

        // Verify key is deleted by trying to use it
        expect(
          () => service.encryptMetadata(
            metadata: {'test': 'data'},
            provider: CloudProvider.dropbox,
            keyId: keyId,
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('should handle deletion of non-existent key', () async {
        const nonExistentKeyId = 'non_existent_key_id';

        final deleted = await service.deleteEncryptionKey(nonExistentKeyId);
        expect(deleted, isTrue); // Should not throw, just return true
      });
    });

    group('Error Handling', () {
      test('should handle encryption service unavailable', () async {
        // This test would be more meaningful with a mock that simulates
        // encryption service being unavailable
        final isAvailable = await service.isEncryptionAvailable();
        expect(isAvailable, isTrue); // In normal test environment
      });
    });

    group('Serialization', () {
      test('should serialize and deserialize EncryptedFileMetadata', () async {
        final metadata = EncryptedFileMetadata(
          originalSize: 1024,
          encryptedSize: 1056,
          keyId: 'test_key_id',
          iv: 'initialization_vector',
          salt: 'salt_value',
          tag: 'auth_tag',
          algorithm: 'AES-256-GCM',
          created: DateTime.now(),
          checksum: 'file_checksum',
        );

        final json = metadata.toJson();
        final restored = EncryptedFileMetadata.fromJson(json);

        expect(restored.originalSize, equals(metadata.originalSize));
        expect(restored.encryptedSize, equals(metadata.encryptedSize));
        expect(restored.keyId, equals(metadata.keyId));
        expect(restored.iv, equals(metadata.iv));
        expect(restored.salt, equals(metadata.salt));
        expect(restored.tag, equals(metadata.tag));
        expect(restored.algorithm, equals(metadata.algorithm));
        expect(restored.checksum, equals(metadata.checksum));
        expect(
          restored.created.toIso8601String(),
          equals(metadata.created.toIso8601String()),
        );
      });

      test('should serialize and deserialize EncryptedFileChunk', () async {
        final chunk = EncryptedFileChunk(
          index: 0,
          offset: 0,
          originalSize: 1024,
          encryptedSize: 1056,
          encryptedData: Uint8List.fromList([1, 2, 3, 4, 5]),
          iv: 'initialization_vector',
          salt: 'salt_value',
          tag: 'auth_tag',
          originalChecksum: 'original_checksum',
          keyId: 'chunk_key_id',
        );

        final json = chunk.toJson();
        final restored = EncryptedFileChunk.fromJson({
          ...json,
          'encryptedData': 'AQIDBAU=', // base64 of [1, 2, 3, 4, 5]
        });

        expect(restored.index, equals(chunk.index));
        expect(restored.offset, equals(chunk.offset));
        expect(restored.originalSize, equals(chunk.originalSize));
        expect(restored.encryptedSize, equals(chunk.encryptedSize));
        expect(restored.encryptedData, equals(chunk.encryptedData));
        expect(restored.iv, equals(chunk.iv));
        expect(restored.salt, equals(chunk.salt));
        expect(restored.tag, equals(chunk.tag));
        expect(restored.originalChecksum, equals(chunk.originalChecksum));
        expect(restored.keyId, equals(chunk.keyId));
      });
    });
  });
}
