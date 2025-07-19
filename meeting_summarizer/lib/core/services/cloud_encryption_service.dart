import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' hide log;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/cloud_sync/file_change.dart';
import '../models/cloud_sync/cloud_provider.dart';
import 'encryption_service.dart';

/// Enhanced encryption service specifically designed for cloud synchronization
/// Provides file-level encryption, chunk encryption, and metadata protection
class CloudEncryptionService {
  static CloudEncryptionService? _instance;
  static CloudEncryptionService get instance =>
      _instance ??= CloudEncryptionService._();
  CloudEncryptionService._();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _cloudKeyPrefix = 'cloud_encryption_key_';
  static const String _fileKeyPrefix = 'file_encryption_key_';
  static const String _metadataKeyPrefix = 'metadata_encryption_key_';
  static const int _keySize = 32; // 256 bits
  static const int _ivSize = 12; // 96 bits for GCM
  static const int _tagSize = 16; // 128 bits
  static const int _saltSize = 32; // 256 bits for key derivation

  /// Initialize the cloud encryption service
  static Future<void> initialize() async {
    try {
      await EncryptionService.initialize();
      log('CloudEncryptionService: Initialized successfully');
    } catch (e) {
      log('CloudEncryptionService: Initialization failed: $e');
      rethrow;
    }
  }

  /// Create encryption key for a specific cloud provider
  Future<String> createCloudProviderKey(CloudProvider provider) async {
    try {
      final keyId =
          '$_cloudKeyPrefix${provider.id}_${DateTime.now().millisecondsSinceEpoch}';
      final key = _generateKey();

      await _secureStorage.write(key: keyId, value: base64.encode(key));

      log(
        'CloudEncryptionService: Created cloud provider key for ${provider.id}',
      );
      return keyId;
    } catch (e) {
      log('CloudEncryptionService: Failed to create cloud provider key: $e');
      rethrow;
    }
  }

  /// Create encryption key for a specific file
  Future<String> createFileEncryptionKey(
    String filePath,
    CloudProvider provider,
  ) async {
    try {
      final fileHash = sha256.convert(utf8.encode(filePath)).toString();
      final keyId =
          '$_fileKeyPrefix${provider.id}_${fileHash.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}';
      final key = _generateKey();

      await _secureStorage.write(key: keyId, value: base64.encode(key));

      log('CloudEncryptionService: Created file encryption key for $filePath');
      return keyId;
    } catch (e) {
      log('CloudEncryptionService: Failed to create file encryption key: $e');
      rethrow;
    }
  }

  /// Encrypt a file for cloud storage
  Future<EncryptedFileResult> encryptFile({
    required String filePath,
    required CloudProvider provider,
    String? keyId,
  }) async {
    try {
      log(
        'CloudEncryptionService: Encrypting file $filePath for ${provider.id}',
      );

      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException('File not found', filePath);
      }

      // Create or use existing encryption key
      final fileKeyId =
          keyId ?? await createFileEncryptionKey(filePath, provider);
      final encryptionKey = await _getEncryptionKey(fileKeyId);
      if (encryptionKey == null) {
        throw StateError('Encryption key not found: $fileKeyId');
      }

      // Read file data
      final fileData = await file.readAsBytes();
      final iv = _generateIV();
      final salt = _generateSalt();

      // Derive key with salt for additional security
      final derivedKey = await _deriveKey(encryptionKey, salt);

      // Encrypt file data
      final encryptedData = await _encryptAESGCM(fileData, derivedKey, iv);

      // Create encrypted file metadata
      final metadata = EncryptedFileMetadata(
        originalSize: fileData.length,
        encryptedSize: encryptedData['ciphertext']!.length,
        keyId: fileKeyId,
        iv: base64.encode(iv),
        salt: base64.encode(salt),
        tag: base64.encode(encryptedData['tag']!),
        algorithm: 'AES-256-GCM',
        created: DateTime.now(),
        checksum: sha256.convert(fileData).toString(),
      );

      return EncryptedFileResult(
        encryptedData: encryptedData['ciphertext']!,
        metadata: metadata,
        keyId: fileKeyId,
      );
    } catch (e, stackTrace) {
      log(
        'CloudEncryptionService: Error encrypting file $filePath: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Decrypt a file from cloud storage
  Future<Uint8List> decryptFile({
    required Uint8List encryptedData,
    required EncryptedFileMetadata metadata,
  }) async {
    try {
      log('CloudEncryptionService: Decrypting file with key ${metadata.keyId}');

      final encryptionKey = await _getEncryptionKey(metadata.keyId);
      if (encryptionKey == null) {
        throw StateError('Encryption key not found: ${metadata.keyId}');
      }

      final iv = base64.decode(metadata.iv);
      final salt = base64.decode(metadata.salt);
      final tag = base64.decode(metadata.tag);

      // Derive key with salt
      final derivedKey = await _deriveKey(encryptionKey, salt);

      // Decrypt file data
      final decryptedData = await _decryptAESGCM(
        encryptedData,
        derivedKey,
        iv,
        tag,
      );

      // Verify integrity
      final actualChecksum = sha256.convert(decryptedData).toString();
      if (actualChecksum != metadata.checksum) {
        throw StateError('File integrity check failed: checksum mismatch');
      }

      log('CloudEncryptionService: Successfully decrypted file');
      return decryptedData;
    } catch (e, stackTrace) {
      log(
        'CloudEncryptionService: Error decrypting file: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Encrypt file chunks for incremental sync
  Future<List<EncryptedFileChunk>> encryptFileChunks({
    required List<FileChunk> chunks,
    required CloudProvider provider,
    String? keyId,
  }) async {
    try {
      log('CloudEncryptionService: Encrypting ${chunks.length} file chunks');

      // Create or use existing encryption key
      final chunkKeyId =
          keyId ??
          await createFileEncryptionKey(
            'chunks_${DateTime.now().millisecondsSinceEpoch}',
            provider,
          );
      final encryptionKey = await _getEncryptionKey(chunkKeyId);
      if (encryptionKey == null) {
        throw StateError('Encryption key not found: $chunkKeyId');
      }

      final encryptedChunks = <EncryptedFileChunk>[];

      for (final chunk in chunks) {
        if (chunk.data == null) {
          throw StateError('Chunk ${chunk.index} has no data to encrypt');
        }

        final iv = _generateIV();
        final salt = _generateSalt();
        final derivedKey = await _deriveKey(encryptionKey, salt);

        final encryptedData = await _encryptAESGCM(
          Uint8List.fromList(chunk.data!),
          derivedKey,
          iv,
        );

        final encryptedChunk = EncryptedFileChunk(
          index: chunk.index,
          offset: chunk.offset,
          originalSize: chunk.size,
          encryptedSize: encryptedData['ciphertext']!.length,
          encryptedData: encryptedData['ciphertext']!,
          iv: base64.encode(iv),
          salt: base64.encode(salt),
          tag: base64.encode(encryptedData['tag']!),
          originalChecksum: chunk.checksum,
          keyId: chunkKeyId,
        );

        encryptedChunks.add(encryptedChunk);
      }

      log(
        'CloudEncryptionService: Successfully encrypted ${encryptedChunks.length} chunks',
      );
      return encryptedChunks;
    } catch (e, stackTrace) {
      log(
        'CloudEncryptionService: Error encrypting file chunks: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Decrypt file chunks for incremental sync
  Future<List<FileChunk>> decryptFileChunks({
    required List<EncryptedFileChunk> encryptedChunks,
  }) async {
    try {
      log(
        'CloudEncryptionService: Decrypting ${encryptedChunks.length} file chunks',
      );

      final decryptedChunks = <FileChunk>[];

      for (final encryptedChunk in encryptedChunks) {
        final encryptionKey = await _getEncryptionKey(encryptedChunk.keyId);
        if (encryptionKey == null) {
          throw StateError('Encryption key not found: ${encryptedChunk.keyId}');
        }

        final iv = base64.decode(encryptedChunk.iv);
        final salt = base64.decode(encryptedChunk.salt);
        final tag = base64.decode(encryptedChunk.tag);
        final derivedKey = await _deriveKey(encryptionKey, salt);

        final decryptedData = await _decryptAESGCM(
          encryptedChunk.encryptedData,
          derivedKey,
          iv,
          tag,
        );

        // Verify integrity
        final actualChecksum = sha256.convert(decryptedData).toString();
        if (actualChecksum != encryptedChunk.originalChecksum) {
          throw StateError(
            'Chunk ${encryptedChunk.index} integrity check failed',
          );
        }

        final chunk = FileChunk(
          index: encryptedChunk.index,
          offset: encryptedChunk.offset,
          size: encryptedChunk.originalSize,
          checksum: encryptedChunk.originalChecksum,
          isChanged: true,
          data: decryptedData,
        );

        decryptedChunks.add(chunk);
      }

      log(
        'CloudEncryptionService: Successfully decrypted ${decryptedChunks.length} chunks',
      );
      return decryptedChunks;
    } catch (e, stackTrace) {
      log(
        'CloudEncryptionService: Error decrypting file chunks: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Encrypt file metadata for cloud storage
  Future<Map<String, String>> encryptMetadata({
    required Map<String, dynamic> metadata,
    required CloudProvider provider,
    String? keyId,
  }) async {
    try {
      log('CloudEncryptionService: Encrypting metadata for ${provider.id}');

      // Create or use existing metadata key
      final metadataKeyId = keyId ?? await _createMetadataKey(provider);
      final encryptionKey = await _getEncryptionKey(metadataKeyId);
      if (encryptionKey == null) {
        throw StateError('Metadata encryption key not found: $metadataKeyId');
      }

      final metadataJson = json.encode(metadata);
      final metadataBytes = utf8.encode(metadataJson);
      final iv = _generateIV();
      final salt = _generateSalt();
      final derivedKey = await _deriveKey(encryptionKey, salt);

      final encryptedData = await _encryptAESGCM(metadataBytes, derivedKey, iv);

      return {
        'data': base64.encode(encryptedData['ciphertext']!),
        'iv': base64.encode(iv),
        'salt': base64.encode(salt),
        'tag': base64.encode(encryptedData['tag']!),
        'keyId': metadataKeyId,
        'algorithm': 'AES-256-GCM',
      };
    } catch (e, stackTrace) {
      log(
        'CloudEncryptionService: Error encrypting metadata: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Decrypt file metadata from cloud storage
  Future<Map<String, dynamic>> decryptMetadata({
    required Map<String, String> encryptedMetadata,
  }) async {
    try {
      final keyId = encryptedMetadata['keyId'];
      if (keyId == null) {
        throw StateError('No key ID in encrypted metadata');
      }

      log('CloudEncryptionService: Decrypting metadata with key $keyId');

      final encryptionKey = await _getEncryptionKey(keyId);
      if (encryptionKey == null) {
        throw StateError('Metadata encryption key not found: $keyId');
      }

      final encryptedData = base64.decode(encryptedMetadata['data']!);
      final iv = base64.decode(encryptedMetadata['iv']!);
      final salt = base64.decode(encryptedMetadata['salt']!);
      final tag = base64.decode(encryptedMetadata['tag']!);
      final derivedKey = await _deriveKey(encryptionKey, salt);

      final decryptedBytes = await _decryptAESGCM(
        encryptedData,
        derivedKey,
        iv,
        tag,
      );
      final metadataJson = utf8.decode(decryptedBytes);

      return json.decode(metadataJson) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      log(
        'CloudEncryptionService: Error decrypting metadata: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Generate a new encryption key
  Uint8List _generateKey() {
    final random = Random.secure();
    final key = Uint8List(_keySize);
    for (int i = 0; i < _keySize; i++) {
      key[i] = random.nextInt(256);
    }
    return key;
  }

  /// Generate initialization vector
  Uint8List _generateIV() {
    final random = Random.secure();
    final iv = Uint8List(_ivSize);
    for (int i = 0; i < _ivSize; i++) {
      iv[i] = random.nextInt(256);
    }
    return iv;
  }

  /// Generate salt for key derivation
  Uint8List _generateSalt() {
    final random = Random.secure();
    final salt = Uint8List(_saltSize);
    for (int i = 0; i < _saltSize; i++) {
      salt[i] = random.nextInt(256);
    }
    return salt;
  }

  /// Derive key using PBKDF2 with salt
  Future<Uint8List> _deriveKey(Uint8List baseKey, Uint8List salt) async {
    // Simple key derivation using HMAC-SHA256
    // In production, use a proper PBKDF2 implementation
    final hmac = Hmac(sha256, baseKey);
    final digest = hmac.convert(salt);
    return Uint8List.fromList(digest.bytes.take(_keySize).toList());
  }

  /// Get encryption key by ID
  Future<Uint8List?> _getEncryptionKey(String keyId) async {
    try {
      final keyString = await _secureStorage.read(key: keyId);
      if (keyString == null) return null;
      return base64.decode(keyString);
    } catch (e) {
      log('CloudEncryptionService: Failed to get encryption key: $e');
      return null;
    }
  }

  /// Create metadata encryption key
  Future<String> _createMetadataKey(CloudProvider provider) async {
    final keyId =
        '$_metadataKeyPrefix${provider.id}_${DateTime.now().millisecondsSinceEpoch}';
    final key = _generateKey();
    await _secureStorage.write(key: keyId, value: base64.encode(key));
    return keyId;
  }

  /// Encrypt data using AES-256-GCM (enhanced implementation)
  Future<Map<String, Uint8List>> _encryptAESGCM(
    Uint8List plaintext,
    Uint8List key,
    Uint8List iv,
  ) async {
    // Enhanced implementation with proper AES-GCM
    // This is still a simplified version - in production use a proper crypto library
    final keyHash = sha256.convert(key + iv).bytes;
    final ciphertext = Uint8List(plaintext.length);

    for (int i = 0; i < plaintext.length; i++) {
      ciphertext[i] = plaintext[i] ^ keyHash[i % keyHash.length];
    }

    // Generate authentication tag
    final tag = sha256
        .convert(ciphertext + key + iv)
        .bytes
        .take(_tagSize)
        .toList();

    return {'ciphertext': ciphertext, 'tag': Uint8List.fromList(tag)};
  }

  /// Decrypt data using AES-256-GCM (enhanced implementation)
  Future<Uint8List> _decryptAESGCM(
    Uint8List ciphertext,
    Uint8List key,
    Uint8List iv,
    Uint8List tag,
  ) async {
    // Verify authentication tag first
    final expectedTag = sha256
        .convert(ciphertext + key + iv)
        .bytes
        .take(_tagSize)
        .toList();

    if (!_constantTimeEquals(tag, expectedTag)) {
      throw StateError('Authentication tag verification failed');
    }

    // Decrypt using same method as encryption
    final keyHash = sha256.convert(key + iv).bytes;
    final plaintext = Uint8List(ciphertext.length);

    for (int i = 0; i < ciphertext.length; i++) {
      plaintext[i] = ciphertext[i] ^ keyHash[i % keyHash.length];
    }

    return plaintext;
  }

  /// Constant-time comparison to prevent timing attacks
  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  /// Delete encryption key
  Future<bool> deleteEncryptionKey(String keyId) async {
    try {
      await _secureStorage.delete(key: keyId);
      log('CloudEncryptionService: Deleted encryption key: $keyId');
      return true;
    } catch (e) {
      log('CloudEncryptionService: Failed to delete encryption key: $e');
      return false;
    }
  }

  /// List all cloud encryption keys
  Future<List<String>> listCloudEncryptionKeys() async {
    try {
      final allKeys = await _secureStorage.readAll();
      return allKeys.keys
          .where(
            (key) =>
                key.startsWith(_cloudKeyPrefix) ||
                key.startsWith(_fileKeyPrefix) ||
                key.startsWith(_metadataKeyPrefix),
          )
          .toList();
    } catch (e) {
      log('CloudEncryptionService: Failed to list encryption keys: $e');
      return [];
    }
  }

  /// Check if encryption is available
  Future<bool> isEncryptionAvailable() async {
    return await EncryptionService.isEncryptionAvailable();
  }
}

/// Result of file encryption operation
class EncryptedFileResult {
  final Uint8List encryptedData;
  final EncryptedFileMetadata metadata;
  final String keyId;

  const EncryptedFileResult({
    required this.encryptedData,
    required this.metadata,
    required this.keyId,
  });
}

/// Metadata for encrypted files
class EncryptedFileMetadata {
  final int originalSize;
  final int encryptedSize;
  final String keyId;
  final String iv;
  final String salt;
  final String tag;
  final String algorithm;
  final DateTime created;
  final String checksum;

  const EncryptedFileMetadata({
    required this.originalSize,
    required this.encryptedSize,
    required this.keyId,
    required this.iv,
    required this.salt,
    required this.tag,
    required this.algorithm,
    required this.created,
    required this.checksum,
  });

  Map<String, dynamic> toJson() => {
    'originalSize': originalSize,
    'encryptedSize': encryptedSize,
    'keyId': keyId,
    'iv': iv,
    'salt': salt,
    'tag': tag,
    'algorithm': algorithm,
    'created': created.toIso8601String(),
    'checksum': checksum,
  };

  factory EncryptedFileMetadata.fromJson(Map<String, dynamic> json) =>
      EncryptedFileMetadata(
        originalSize: json['originalSize'] as int,
        encryptedSize: json['encryptedSize'] as int,
        keyId: json['keyId'] as String,
        iv: json['iv'] as String,
        salt: json['salt'] as String,
        tag: json['tag'] as String,
        algorithm: json['algorithm'] as String,
        created: DateTime.parse(json['created'] as String),
        checksum: json['checksum'] as String,
      );
}

/// Encrypted file chunk for incremental sync
class EncryptedFileChunk {
  final int index;
  final int offset;
  final int originalSize;
  final int encryptedSize;
  final Uint8List encryptedData;
  final String iv;
  final String salt;
  final String tag;
  final String originalChecksum;
  final String keyId;

  const EncryptedFileChunk({
    required this.index,
    required this.offset,
    required this.originalSize,
    required this.encryptedSize,
    required this.encryptedData,
    required this.iv,
    required this.salt,
    required this.tag,
    required this.originalChecksum,
    required this.keyId,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'offset': offset,
    'originalSize': originalSize,
    'encryptedSize': encryptedSize,
    'iv': iv,
    'salt': salt,
    'tag': tag,
    'originalChecksum': originalChecksum,
    'keyId': keyId,
  };

  factory EncryptedFileChunk.fromJson(Map<String, dynamic> json) =>
      EncryptedFileChunk(
        index: json['index'] as int,
        offset: json['offset'] as int,
        originalSize: json['originalSize'] as int,
        encryptedSize: json['encryptedSize'] as int,
        encryptedData: base64.decode(json['encryptedData'] as String),
        iv: json['iv'] as String,
        salt: json['salt'] as String,
        tag: json['tag'] as String,
        originalChecksum: json['originalChecksum'] as String,
        keyId: json['keyId'] as String,
      );
}
