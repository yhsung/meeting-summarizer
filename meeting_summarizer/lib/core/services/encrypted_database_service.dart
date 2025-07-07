import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/database/recording.dart';
import '../models/database/transcription.dart';
import '../models/database/summary.dart' as models;
import '../models/database/app_settings.dart';
import 'encryption_service.dart';

/// Service for handling encrypted database operations
///
/// This service extends the DatabaseHelper with encryption capabilities
/// for sensitive data fields while maintaining compatibility with existing code.
class EncryptedDatabaseService {
  static EncryptedDatabaseService? _instance;
  static DatabaseHelper? _databaseHelper;
  static bool _encryptionEnabled = false;
  static String? _defaultEncryptionKeyId;

  EncryptedDatabaseService._internal();

  /// Get singleton instance of EncryptedDatabaseService
  factory EncryptedDatabaseService() {
    _instance ??= EncryptedDatabaseService._internal();
    return _instance!;
  }

  /// Initialize the encrypted database service
  static Future<void> initialize() async {
    try {
      _databaseHelper = DatabaseHelper();
      await EncryptionService.initialize();

      // Check if encryption is enabled in settings
      final encryptionSetting = await _databaseHelper!.getSetting(
        'encryption_enabled',
      );
      _encryptionEnabled = encryptionSetting == 'true';

      if (_encryptionEnabled) {
        // Get or create default encryption key
        _defaultEncryptionKeyId = await _getOrCreateDefaultEncryptionKey();
        debugPrint('EncryptedDatabaseService: Encryption enabled');
      } else {
        debugPrint('EncryptedDatabaseService: Encryption disabled');
      }

      debugPrint('EncryptedDatabaseService: Initialized successfully');
    } catch (e) {
      debugPrint('EncryptedDatabaseService: Initialization failed: $e');
      rethrow;
    }
  }

  /// Get or create the default encryption key
  static Future<String> _getOrCreateDefaultEncryptionKey() async {
    final keyIdSetting = await _databaseHelper!.getSetting(
      'default_encryption_key_id',
    );

    if (keyIdSetting != null && keyIdSetting.isNotEmpty) {
      return keyIdSetting;
    }

    // Create new default encryption key
    final keyId = await EncryptionService.createEncryptionKey('default');
    await _databaseHelper!.setSetting('default_encryption_key_id', keyId);
    return keyId;
  }

  /// Enable or disable encryption
  static Future<void> setEncryptionEnabled(bool enabled) async {
    _encryptionEnabled = enabled;
    await _databaseHelper!.setSetting('encryption_enabled', enabled.toString());

    if (enabled && _defaultEncryptionKeyId == null) {
      _defaultEncryptionKeyId = await _getOrCreateDefaultEncryptionKey();
    }

    debugPrint(
      'EncryptedDatabaseService: Encryption ${enabled ? 'enabled' : 'disabled'}',
    );
  }

  /// Check if encryption is currently enabled
  static bool get isEncryptionEnabled => _encryptionEnabled;

  /// Get the database helper instance
  DatabaseHelper get databaseHelper => _databaseHelper!;

  // Encrypted Recording Operations

  /// Insert recording with encryption for sensitive fields
  Future<String> insertRecording(Recording recording) async {
    try {
      Recording processedRecording = recording;

      if (_encryptionEnabled && _defaultEncryptionKeyId != null) {
        processedRecording = await _encryptRecordingFields(recording);
      }

      final result = await _databaseHelper!.insertRecording(processedRecording);
      debugPrint(
        'EncryptedDatabaseService: Inserted recording ${recording.id} with encryption: $_encryptionEnabled',
      );
      return result;
    } catch (e) {
      debugPrint('EncryptedDatabaseService: Failed to insert recording: $e');
      rethrow;
    }
  }

  /// Get recording with automatic decryption
  Future<Recording?> getRecording(String id) async {
    try {
      final recording = await _databaseHelper!.getRecording(id);
      if (recording == null) return null;

      if (_encryptionEnabled) {
        return await _decryptRecordingFields(recording);
      }

      return recording;
    } catch (e) {
      debugPrint('EncryptedDatabaseService: Failed to get recording: $e');
      return null;
    }
  }

  /// Update recording with encryption for sensitive fields
  Future<bool> updateRecording(Recording recording) async {
    try {
      Recording processedRecording = recording;

      if (_encryptionEnabled && _defaultEncryptionKeyId != null) {
        processedRecording = await _encryptRecordingFields(recording);
      }

      final result = await _databaseHelper!.updateRecording(processedRecording);
      debugPrint(
        'EncryptedDatabaseService: Updated recording ${recording.id} with encryption: $_encryptionEnabled',
      );
      return result;
    } catch (e) {
      debugPrint('EncryptedDatabaseService: Failed to update recording: $e');
      return false;
    }
  }

  /// Encrypt sensitive fields in recording
  Future<Recording> _encryptRecordingFields(Recording recording) async {
    try {
      String? encryptedDescription;
      List<String>? encryptedTags;
      String? encryptedLocation;
      Map<String, dynamic>? encryptedMetadata;

      // Encrypt description if present
      if (recording.description != null && recording.description!.isNotEmpty) {
        final encrypted = await EncryptionService.encryptData(
          recording.description!,
          _defaultEncryptionKeyId!,
        );
        if (encrypted != null) {
          encryptedDescription = base64.encode(
            utf8.encode(jsonEncode(encrypted)),
          );
        }
      }

      // Encrypt tags if present
      if (recording.tags != null && recording.tags!.isNotEmpty) {
        final tagsJson = jsonEncode(recording.tags);
        final encrypted = await EncryptionService.encryptData(
          tagsJson,
          _defaultEncryptionKeyId!,
        );
        if (encrypted != null) {
          final encryptedJson = base64.encode(
            utf8.encode(jsonEncode(encrypted)),
          );
          encryptedTags = [
            encryptedJson,
          ]; // Store as single encrypted string in list
        }
      }

      // Encrypt location if present
      if (recording.location != null && recording.location!.isNotEmpty) {
        final encrypted = await EncryptionService.encryptData(
          recording.location!,
          _defaultEncryptionKeyId!,
        );
        if (encrypted != null) {
          encryptedLocation = base64.encode(utf8.encode(jsonEncode(encrypted)));
        }
      }

      // Encrypt metadata if present
      if (recording.metadata != null && recording.metadata!.isNotEmpty) {
        final metadataJson = jsonEncode(recording.metadata);
        final encrypted = await EncryptionService.encryptData(
          metadataJson,
          _defaultEncryptionKeyId!,
        );
        if (encrypted != null) {
          final encryptedJson = base64.encode(
            utf8.encode(jsonEncode(encrypted)),
          );
          encryptedMetadata = {
            'encrypted': encryptedJson,
          }; // Store as single encrypted value
        }
      }

      return recording.copyWith(
        description: encryptedDescription,
        tags: encryptedTags ?? recording.tags,
        location: encryptedLocation,
        metadata: encryptedMetadata ?? recording.metadata,
      );
    } catch (e) {
      debugPrint(
        'EncryptedDatabaseService: Encryption failed for recording: $e',
      );
      return recording; // Return unencrypted on failure
    }
  }

  /// Decrypt sensitive fields in recording
  Future<Recording> _decryptRecordingFields(Recording recording) async {
    try {
      String? decryptedDescription = recording.description;
      List<String>? decryptedTags = recording.tags;
      String? decryptedLocation = recording.location;
      Map<String, dynamic>? decryptedMetadata = recording.metadata;

      // Decrypt description if encrypted
      if (recording.description != null && recording.description!.isNotEmpty) {
        try {
          final encryptedJson = jsonDecode(
            utf8.decode(base64.decode(recording.description!)),
          );
          final decrypted = await EncryptionService.decryptData(
            Map<String, String>.from(encryptedJson),
          );
          if (decrypted != null) {
            decryptedDescription = decrypted;
          }
        } catch (e) {
          // If decryption fails, assume it's not encrypted
          decryptedDescription = recording.description;
        }
      }

      // Decrypt tags if encrypted
      if (recording.tags != null &&
          recording.tags!.isNotEmpty &&
          recording.tags!.length == 1) {
        try {
          // Check if it's an encrypted tags list (single encrypted string)
          final encryptedJson = jsonDecode(
            utf8.decode(base64.decode(recording.tags!.first)),
          );
          final decrypted = await EncryptionService.decryptData(
            Map<String, String>.from(encryptedJson),
          );
          if (decrypted != null) {
            decryptedTags = List<String>.from(jsonDecode(decrypted));
          }
        } catch (e) {
          // If decryption fails, assume it's not encrypted
          decryptedTags = recording.tags;
        }
      }

      // Decrypt location if encrypted
      if (recording.location != null && recording.location!.isNotEmpty) {
        try {
          final encryptedJson = jsonDecode(
            utf8.decode(base64.decode(recording.location!)),
          );
          final decrypted = await EncryptionService.decryptData(
            Map<String, String>.from(encryptedJson),
          );
          if (decrypted != null) {
            decryptedLocation = decrypted;
          }
        } catch (e) {
          decryptedLocation = recording.location;
        }
      }

      // Decrypt metadata if encrypted
      if (recording.metadata != null &&
          recording.metadata!.containsKey('encrypted')) {
        try {
          final encryptedData = recording.metadata!['encrypted'] as String;
          final encryptedJson = jsonDecode(
            utf8.decode(base64.decode(encryptedData)),
          );
          final decrypted = await EncryptionService.decryptData(
            Map<String, String>.from(encryptedJson),
          );
          if (decrypted != null) {
            decryptedMetadata = Map<String, dynamic>.from(
              jsonDecode(decrypted),
            );
          }
        } catch (e) {
          decryptedMetadata = recording.metadata;
        }
      }

      return recording.copyWith(
        description: decryptedDescription,
        tags: decryptedTags,
        location: decryptedLocation,
        metadata: decryptedMetadata,
      );
    } catch (e) {
      debugPrint(
        'EncryptedDatabaseService: Decryption failed for recording: $e',
      );
      return recording; // Return as-is on failure
    }
  }

  // Encrypted Transcription Operations

  /// Insert transcription with encryption for sensitive content
  Future<String> insertTranscription(Transcription transcription) async {
    try {
      Transcription processedTranscription = transcription;

      if (_encryptionEnabled && _defaultEncryptionKeyId != null) {
        processedTranscription = await _encryptTranscriptionFields(
          transcription,
        );
      }

      final result = await _databaseHelper!.insertTranscription(
        processedTranscription,
      );
      debugPrint(
        'EncryptedDatabaseService: Inserted transcription ${transcription.id} with encryption: $_encryptionEnabled',
      );
      return result;
    } catch (e) {
      debugPrint(
        'EncryptedDatabaseService: Failed to insert transcription: $e',
      );
      rethrow;
    }
  }

  /// Get transcription with automatic decryption
  Future<Transcription?> getTranscription(String id) async {
    try {
      final transcription = await _databaseHelper!.getTranscription(id);
      if (transcription == null) return null;

      if (_encryptionEnabled) {
        return await _decryptTranscriptionFields(transcription);
      }

      return transcription;
    } catch (e) {
      debugPrint('EncryptedDatabaseService: Failed to get transcription: $e');
      return null;
    }
  }

  /// Encrypt sensitive fields in transcription
  Future<Transcription> _encryptTranscriptionFields(
    Transcription transcription,
  ) async {
    try {
      String? encryptedText;

      // Encrypt transcription text
      if (transcription.text.isNotEmpty) {
        final encrypted = await EncryptionService.encryptData(
          transcription.text,
          _defaultEncryptionKeyId!,
        );
        if (encrypted != null) {
          encryptedText = base64.encode(utf8.encode(jsonEncode(encrypted)));
        }
      }

      return transcription.copyWith(text: encryptedText ?? transcription.text);
    } catch (e) {
      debugPrint(
        'EncryptedDatabaseService: Encryption failed for transcription: $e',
      );
      return transcription;
    }
  }

  /// Decrypt sensitive fields in transcription
  Future<Transcription> _decryptTranscriptionFields(
    Transcription transcription,
  ) async {
    try {
      String decryptedText = transcription.text;

      // Decrypt transcription text if encrypted
      if (transcription.text.isNotEmpty) {
        try {
          final encryptedJson = jsonDecode(
            utf8.decode(base64.decode(transcription.text)),
          );
          final decrypted = await EncryptionService.decryptData(
            Map<String, String>.from(encryptedJson),
          );
          if (decrypted != null) {
            decryptedText = decrypted;
          }
        } catch (e) {
          // If decryption fails, assume it's not encrypted
          decryptedText = transcription.text;
        }
      }

      return transcription.copyWith(text: decryptedText);
    } catch (e) {
      debugPrint(
        'EncryptedDatabaseService: Decryption failed for transcription: $e',
      );
      return transcription;
    }
  }

  // Pass-through methods for non-encrypted operations

  /// Get recordings with optional filters (decrypted automatically)
  Future<List<Recording>> getRecordings({
    int? limit,
    int? offset,
    String? searchQuery,
    String? format,
    DateTime? startDate,
    DateTime? endDate,
    String orderBy = 'created_at DESC',
  }) async {
    final recordings = await _databaseHelper!.getRecordings(
      limit: limit,
      offset: offset,
      searchQuery: searchQuery,
      format: format,
      startDate: startDate,
      endDate: endDate,
      orderBy: orderBy,
    );

    if (!_encryptionEnabled) return recordings;

    // Decrypt all recordings
    final decryptedRecordings = <Recording>[];
    for (final recording in recordings) {
      decryptedRecordings.add(await _decryptRecordingFields(recording));
    }

    return decryptedRecordings;
  }

  /// Delete recording
  Future<bool> deleteRecording(String id) async {
    return await _databaseHelper!.deleteRecording(id);
  }

  /// Permanently delete recording
  Future<bool> permanentlyDeleteRecording(String id) async {
    return await _databaseHelper!.permanentlyDeleteRecording(id);
  }

  /// Get transcriptions by recording ID (decrypted automatically)
  Future<List<Transcription>> getTranscriptionsByRecording(
    String recordingId,
  ) async {
    final transcriptions = await _databaseHelper!.getTranscriptionsByRecording(
      recordingId,
    );

    if (!_encryptionEnabled) return transcriptions;

    // Decrypt all transcriptions
    final decryptedTranscriptions = <Transcription>[];
    for (final transcription in transcriptions) {
      decryptedTranscriptions.add(
        await _decryptTranscriptionFields(transcription),
      );
    }

    return decryptedTranscriptions;
  }

  /// Update transcription with encryption
  Future<bool> updateTranscription(Transcription transcription) async {
    try {
      Transcription processedTranscription = transcription;

      if (_encryptionEnabled && _defaultEncryptionKeyId != null) {
        processedTranscription = await _encryptTranscriptionFields(
          transcription,
        );
      }

      return await _databaseHelper!.updateTranscription(processedTranscription);
    } catch (e) {
      debugPrint(
        'EncryptedDatabaseService: Failed to update transcription: $e',
      );
      return false;
    }
  }

  /// Delete transcription
  Future<bool> deleteTranscription(String id) async {
    return await _databaseHelper!.deleteTranscription(id);
  }

  // Summary operations (pass-through for now)
  Future<String> insertSummary(models.Summary summary) async {
    return await _databaseHelper!.insertSummary(summary);
  }

  Future<models.Summary?> getSummary(String id) async {
    return await _databaseHelper!.getSummary(id);
  }

  Future<List<models.Summary>> getSummariesByTranscription(
    String transcriptionId,
  ) async {
    return await _databaseHelper!.getSummariesByTranscription(transcriptionId);
  }

  Future<bool> updateSummary(models.Summary summary) async {
    return await _databaseHelper!.updateSummary(summary);
  }

  Future<bool> deleteSummary(String id) async {
    return await _databaseHelper!.deleteSummary(id);
  }

  // Settings operations (pass-through)
  Future<String?> getSetting(String key) async {
    return await _databaseHelper!.getSetting(key);
  }

  Future<AppSettings?> getAppSetting(String key) async {
    return await _databaseHelper!.getAppSetting(key);
  }

  Future<bool> setSetting(String key, String value) async {
    return await _databaseHelper!.setSetting(key, value);
  }

  Future<bool> upsertSetting(AppSettings setting) async {
    return await _databaseHelper!.upsertSetting(setting);
  }

  // Utility operations (pass-through)
  Future<Map<String, int>> getDatabaseStats() async {
    return await _databaseHelper!.getDatabaseStats();
  }

  Future<void> close() async {
    await _databaseHelper!.close();
  }

  /// Migrate existing data to encrypted format
  Future<void> migrateToEncryption() async {
    if (!_encryptionEnabled || _defaultEncryptionKeyId == null) {
      throw Exception('Encryption not enabled');
    }

    debugPrint('EncryptedDatabaseService: Starting encryption migration');

    try {
      // Get all recordings and re-encrypt them
      final recordings = await _databaseHelper!.getRecordings();
      for (final recording in recordings) {
        final encryptedRecording = await _encryptRecordingFields(recording);
        await _databaseHelper!.updateRecording(encryptedRecording);
      }

      // Get all transcriptions and re-encrypt them
      final transcriptions = await _databaseHelper!.transaction((txn) async {
        final result = await txn.query('transcriptions');
        return result.map((row) => Transcription.fromDatabase(row)).toList();
      });

      for (final transcription in transcriptions) {
        final encryptedTranscription = await _encryptTranscriptionFields(
          transcription,
        );
        await _databaseHelper!.updateTranscription(encryptedTranscription);
      }

      debugPrint('EncryptedDatabaseService: Encryption migration completed');
    } catch (e) {
      debugPrint('EncryptedDatabaseService: Encryption migration failed: $e');
      rethrow;
    }
  }
}
