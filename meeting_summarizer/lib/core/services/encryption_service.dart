import 'dart:convert';
import 'dart:math' hide log;
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

/// Service for handling data encryption and decryption
///
/// This service provides secure encryption for sensitive data using AES-256-GCM
/// with secure key management through Flutter Secure Storage.
class EncryptionService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _masterKeyId = 'master_encryption_key';
  static const String _keyPrefix = 'encryption_key_';
  static const int _keySize = 32; // 256 bits
  static const int _ivSize = 12; // 96 bits for GCM
  static const int _tagSize = 16; // 128 bits
  static const int _saltSize = 32; // 256 bits for key derivation
  static const int _pbkdf2Iterations = 100000; // OWASP recommended minimum

  /// Initialize the encryption service
  static Future<void> initialize() async {
    try {
      await _ensureMasterKey();
      log('EncryptionService: Initialized successfully');
    } catch (e) {
      log('EncryptionService: Initialization failed: $e');
      rethrow;
    }
  }

  /// Ensure master key exists, create if needed
  static Future<void> _ensureMasterKey() async {
    final existingKey = await _secureStorage.read(key: _masterKeyId);
    if (existingKey == null) {
      final masterKey = _generateKey();
      await _secureStorage.write(
        key: _masterKeyId,
        value: base64.encode(masterKey),
      );
      log('EncryptionService: Master key created');
    }
  }

  /// Generate a new encryption key
  static Uint8List _generateKey() {
    final random = Random.secure();
    final key = Uint8List(_keySize);
    for (int i = 0; i < _keySize; i++) {
      key[i] = random.nextInt(256);
    }
    return key;
  }

  /// Create a new encryption key for a specific purpose
  static Future<String> createEncryptionKey(String purpose) async {
    try {
      final key = _generateKey();
      final keyId =
          '$_keyPrefix${purpose}_${DateTime.now().millisecondsSinceEpoch}';

      await _secureStorage.write(key: keyId, value: base64.encode(key));

      log('EncryptionService: Created encryption key for $purpose');
      return keyId;
    } catch (e) {
      log('EncryptionService: Failed to create encryption key: $e');
      rethrow;
    }
  }

  /// Get encryption key by ID
  static Future<Uint8List?> _getEncryptionKey(String keyId) async {
    try {
      final keyString = await _secureStorage.read(key: keyId);
      if (keyString == null) return null;

      return base64.decode(keyString);
    } catch (e) {
      log('EncryptionService: Failed to get encryption key: $e');
      return null;
    }
  }

  /// Encrypt data with a specific key
  static Future<Map<String, String>?> encryptData(
    String data,
    String keyId,
  ) async {
    try {
      final key = await _getEncryptionKey(keyId);
      if (key == null) {
        log('EncryptionService: Encryption key not found: $keyId');
        return null;
      }

      final plaintext = utf8.encode(data);
      final iv = _generateIV();

      // Use AES-256-GCM for encryption
      final encrypted = await _encryptAESGCM(plaintext, key, iv);

      return {
        'data': base64.encode(encrypted['ciphertext']!),
        'iv': base64.encode(iv),
        'tag': base64.encode(encrypted['tag']!),
        'keyId': keyId,
      };
    } catch (e) {
      log('EncryptionService: Encryption failed: $e');
      return null;
    }
  }

  /// Decrypt data with a specific key
  static Future<String?> decryptData(Map<String, String> encryptedData) async {
    try {
      final keyId = encryptedData['keyId'];
      if (keyId == null) {
        log('EncryptionService: No key ID in encrypted data');
        return null;
      }

      final key = await _getEncryptionKey(keyId);
      if (key == null) {
        log('EncryptionService: Decryption key not found: $keyId');
        return null;
      }

      final ciphertext = base64.decode(encryptedData['data']!);
      final iv = base64.decode(encryptedData['iv']!);
      final tag = base64.decode(encryptedData['tag']!);

      final plaintext = await _decryptAESGCM(ciphertext, key, iv, tag);
      return utf8.decode(plaintext);
    } catch (e) {
      log('EncryptionService: Decryption failed: $e');
      return null;
    }
  }

  /// Generate initialization vector
  static Uint8List _generateIV() {
    final random = Random.secure();
    final iv = Uint8List(_ivSize);
    for (int i = 0; i < _ivSize; i++) {
      iv[i] = random.nextInt(256);
    }
    return iv;
  }

  /// Generate salt for key derivation
  static Uint8List _generateSalt() {
    final random = Random.secure();
    final salt = Uint8List(_saltSize);
    for (int i = 0; i < _saltSize; i++) {
      salt[i] = random.nextInt(256);
    }
    return salt;
  }

  /// Derive key using PBKDF2
  static Uint8List _deriveKeyPBKDF2(
    String password,
    Uint8List salt, {
    int iterations = _pbkdf2Iterations,
    int keyLength = _keySize,
  }) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(salt, iterations, keyLength));
    return pbkdf2.process(Uint8List.fromList(password.codeUnits));
  }

  /// Encrypt data using AES-256-GCM
  static Future<Map<String, Uint8List>> _encryptAESGCM(
    Uint8List plaintext,
    Uint8List key,
    Uint8List iv,
  ) async {
    try {
      // Create AES-GCM cipher
      final cipher = GCMBlockCipher(AESEngine());
      
      // Set up parameters
      final params = AEADParameters(
        KeyParameter(key),
        _tagSize * 8, // Convert bytes to bits
        iv,
        Uint8List(0), // Additional authenticated data (AAD) - empty
      );
      
      // Initialize cipher for encryption
      cipher.init(true, params);
      
      // Encrypt the data
      final ciphertext = cipher.process(plaintext);
      
      // Extract the authentication tag from the end
      final encryptedData = Uint8List.view(
        ciphertext.buffer,
        0,
        ciphertext.length - _tagSize,
      );
      final tag = Uint8List.view(
        ciphertext.buffer,
        ciphertext.length - _tagSize,
        _tagSize,
      );
      
      return {
        'ciphertext': encryptedData,
        'tag': tag,
      };
    } catch (e) {
      log('EncryptionService: AES-GCM encryption failed: $e');
      rethrow;
    }
  }

  /// Decrypt data using AES-256-GCM
  static Future<Uint8List> _decryptAESGCM(
    Uint8List ciphertext,
    Uint8List key,
    Uint8List iv,
    Uint8List tag,
  ) async {
    try {
      // Create AES-GCM cipher
      final cipher = GCMBlockCipher(AESEngine());
      
      // Set up parameters
      final params = AEADParameters(
        KeyParameter(key),
        _tagSize * 8, // Convert bytes to bits
        iv,
        Uint8List(0), // Additional authenticated data (AAD) - empty
      );
      
      // Initialize cipher for decryption
      cipher.init(false, params);
      
      // Combine ciphertext and tag for decryption
      final encryptedDataWithTag = Uint8List(ciphertext.length + tag.length);
      encryptedDataWithTag.setRange(0, ciphertext.length, ciphertext);
      encryptedDataWithTag.setRange(ciphertext.length, encryptedDataWithTag.length, tag);
      
      // Decrypt and verify
      final plaintext = cipher.process(encryptedDataWithTag);
      
      return plaintext;
    } catch (e) {
      log('EncryptionService: AES-GCM decryption failed: $e');
      throw Exception('Decryption failed: Authentication tag verification failed');
    }
  }


  /// Delete encryption key
  static Future<bool> deleteEncryptionKey(String keyId) async {
    try {
      await _secureStorage.delete(key: keyId);
      log('EncryptionService: Deleted encryption key: $keyId');
      return true;
    } catch (e) {
      log('EncryptionService: Failed to delete encryption key: $e');
      return false;
    }
  }

  /// List all encryption keys
  static Future<List<String>> listEncryptionKeys() async {
    try {
      final allKeys = await _secureStorage.readAll();
      return allKeys.keys.where((key) => key.startsWith(_keyPrefix)).toList();
    } catch (e) {
      log('EncryptionService: Failed to list encryption keys: $e');
      return [];
    }
  }

  /// Clear all encryption keys (use with caution)
  static Future<void> clearAllKeys() async {
    try {
      await _secureStorage.deleteAll();
      log('EncryptionService: Cleared all encryption keys');
    } catch (e) {
      log('EncryptionService: Failed to clear keys: $e');
      rethrow;
    }
  }

  /// Encrypt data with password-based encryption
  static Future<Map<String, String>?> encryptWithPassword(
    String data,
    String password,
  ) async {
    try {
      final plaintext = utf8.encode(data);
      final salt = _generateSalt();
      final iv = _generateIV();
      final key = _deriveKeyPBKDF2(password, salt);

      final encrypted = await _encryptAESGCM(plaintext, key, iv);

      return {
        'data': base64.encode(encrypted['ciphertext']!),
        'iv': base64.encode(iv),
        'salt': base64.encode(salt),
        'tag': base64.encode(encrypted['tag']!),
        'iterations': _pbkdf2Iterations.toString(),
      };
    } catch (e) {
      log('EncryptionService: Password-based encryption failed: $e');
      return null;
    }
  }

  /// Decrypt data with password-based encryption
  static Future<String?> decryptWithPassword(
    Map<String, String> encryptedData,
    String password,
  ) async {
    try {
      final ciphertext = base64.decode(encryptedData['data']!);
      final iv = base64.decode(encryptedData['iv']!);
      final salt = base64.decode(encryptedData['salt']!);
      final tag = base64.decode(encryptedData['tag']!);
      final iterations = int.parse(encryptedData['iterations'] ?? _pbkdf2Iterations.toString());

      final key = _deriveKeyPBKDF2(password, salt, iterations: iterations);
      final plaintext = await _decryptAESGCM(ciphertext, key, iv, tag);

      return utf8.decode(plaintext);
    } catch (e) {
      log('EncryptionService: Password-based decryption failed: $e');
      return null;
    }
  }

  /// Check if encryption is available on this device
  static Future<bool> isEncryptionAvailable() async {
    try {
      // Test by writing and reading a test value
      const testKey = 'encryption_test_key';
      const testValue = 'test_value';

      await _secureStorage.write(key: testKey, value: testValue);
      final readValue = await _secureStorage.read(key: testKey);
      await _secureStorage.delete(key: testKey);

      return readValue == testValue;
    } catch (e) {
      log('EncryptionService: Encryption not available: $e');
      return false;
    }
  }
}

/// Secure key management service for advanced key operations
class SecureKeyManager {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _keyRotationPrefix = 'key_rotation_';
  static const String _keyBackupPrefix = 'key_backup_';
  static const String _keyMetadataPrefix = 'key_metadata_';

  /// Rotate an encryption key
  static Future<String?> rotateKey(String oldKeyId) async {
    try {
      // Get the old key
      final oldKeyData = await _storage.read(key: oldKeyId);
      if (oldKeyData == null) {
        log('SecureKeyManager: Old key not found for rotation: $oldKeyId');
        return null;
      }

      // Create new key
      final newKeyId = '${EncryptionService._keyPrefix}rotated_${DateTime.now().millisecondsSinceEpoch}';
      final newKey = EncryptionService._generateKey();
      
      // Store new key
      await _storage.write(key: newKeyId, value: base64.encode(newKey));
      
      // Create backup of old key
      final backupId = '$_keyBackupPrefix${oldKeyId}_${DateTime.now().millisecondsSinceEpoch}';
      await _storage.write(key: backupId, value: oldKeyData);
      
      // Store rotation metadata
      final rotationMetadata = {
        'oldKeyId': oldKeyId,
        'newKeyId': newKeyId,
        'rotatedAt': DateTime.now().toIso8601String(),
        'backupId': backupId,
      };
      await _storage.write(
        key: '$_keyRotationPrefix$newKeyId',
        value: base64.encode(utf8.encode(json.encode(rotationMetadata))),
      );

      log('SecureKeyManager: Key rotated from $oldKeyId to $newKeyId');
      return newKeyId;
    } catch (e) {
      log('SecureKeyManager: Key rotation failed: $e');
      return null;
    }
  }

  /// Create key backup with master password protection
  static Future<bool> createKeyBackup(String keyId, String masterPassword) async {
    try {
      final keyData = await _storage.read(key: keyId);
      if (keyData == null) {
        log('SecureKeyManager: Key not found for backup: $keyId');
        return false;
      }

      // Encrypt the key with master password
      final backupData = await EncryptionService.encryptWithPassword(keyData, masterPassword);
      if (backupData == null) {
        log('SecureKeyManager: Failed to encrypt key backup');
        return false;
      }

      final backupId = '$_keyBackupPrefix${keyId}_${DateTime.now().millisecondsSinceEpoch}';
      await _storage.write(key: backupId, value: json.encode(backupData));

      // Store backup metadata
      final metadata = {
        'originalKeyId': keyId,
        'backupId': backupId,
        'createdAt': DateTime.now().toIso8601String(),
        'isPasswordProtected': true,
      };
      await _storage.write(
        key: '$_keyMetadataPrefix$backupId',
        value: json.encode(metadata),
      );

      log('SecureKeyManager: Key backup created: $backupId');
      return true;
    } catch (e) {
      log('SecureKeyManager: Key backup failed: $e');
      return false;
    }
  }

  /// Restore key from backup
  static Future<String?> restoreKeyFromBackup(
    String backupId,
    String masterPassword,
  ) async {
    try {
      final backupData = await _storage.read(key: backupId);
      if (backupData == null) {
        log('SecureKeyManager: Backup not found: $backupId');
        return null;
      }

      final encryptedBackup = json.decode(backupData) as Map<String, dynamic>;
      final decryptedKey = await EncryptionService.decryptWithPassword(
        Map<String, String>.from(encryptedBackup),
        masterPassword,
      );

      if (decryptedKey == null) {
        log('SecureKeyManager: Failed to decrypt backup - invalid password');
        return null;
      }

      // Create new key ID for restored key
      final restoredKeyId = '${EncryptionService._keyPrefix}restored_${DateTime.now().millisecondsSinceEpoch}';
      await _storage.write(key: restoredKeyId, value: decryptedKey);

      log('SecureKeyManager: Key restored from backup: $restoredKeyId');
      return restoredKeyId;
    } catch (e) {
      log('SecureKeyManager: Key restoration failed: $e');
      return null;
    }
  }

  /// List all key backups
  static Future<List<Map<String, dynamic>>> listKeyBackups() async {
    try {
      final allKeys = await _storage.readAll();
      final backups = <Map<String, dynamic>>[];

      for (final entry in allKeys.entries) {
        if (entry.key.startsWith(_keyMetadataPrefix)) {
          try {
            final metadata = json.decode(entry.value) as Map<String, dynamic>;
            backups.add(metadata);
          } catch (e) {
            log('SecureKeyManager: Failed to parse backup metadata: ${entry.key}');
          }
        }
      }

      return backups;
    } catch (e) {
      log('SecureKeyManager: Failed to list key backups: $e');
      return [];
    }
  }

  /// Secure key deletion with overwrite
  static Future<bool> secureDeleteKey(String keyId) async {
    try {
      // Read the key first to overwrite its memory location
      final keyData = await _storage.read(key: keyId);
      if (keyData != null) {
        // Overwrite the memory by creating random data
        final random = Random.secure();
        final overwriteData = String.fromCharCodes(
          List.generate(keyData.length, (_) => random.nextInt(256)),
        );
        
        // Overwrite multiple times
        for (int i = 0; i < 3; i++) {
          await _storage.write(key: keyId, value: overwriteData);
        }
      }

      // Finally delete the key
      await _storage.delete(key: keyId);
      
      log('SecureKeyManager: Securely deleted key: $keyId');
      return true;
    } catch (e) {
      log('SecureKeyManager: Secure key deletion failed: $e');
      return false;
    }
  }
}
