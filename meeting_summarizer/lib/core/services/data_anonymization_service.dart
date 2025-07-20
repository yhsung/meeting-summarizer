import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DataRetentionPeriod { days30, days90, days365, indefinite }

enum PrivacyControlType {
  recordingConsent,
  transcriptionSharing,
  cloudSync,
  analytics,
  dataExport,
  dataDeletion,
}

class PrivacySettings {
  final bool recordingConsent;
  final bool transcriptionSharing;
  final bool cloudSync;
  final bool analytics;
  final DataRetentionPeriod retentionPeriod;
  final DateTime lastUpdated;

  const PrivacySettings({
    required this.recordingConsent,
    required this.transcriptionSharing,
    required this.cloudSync,
    required this.analytics,
    required this.retentionPeriod,
    required this.lastUpdated,
  });

  factory PrivacySettings.defaultSettings() {
    return PrivacySettings(
      recordingConsent: false,
      transcriptionSharing: false,
      cloudSync: false,
      analytics: false,
      retentionPeriod: DataRetentionPeriod.days90,
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recordingConsent': recordingConsent,
      'transcriptionSharing': transcriptionSharing,
      'cloudSync': cloudSync,
      'analytics': analytics,
      'retentionPeriod': retentionPeriod.index,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory PrivacySettings.fromJson(Map<String, dynamic> json) {
    return PrivacySettings(
      recordingConsent: json['recordingConsent'] ?? false,
      transcriptionSharing: json['transcriptionSharing'] ?? false,
      cloudSync: json['cloudSync'] ?? false,
      analytics: json['analytics'] ?? false,
      retentionPeriod: DataRetentionPeriod.values[json['retentionPeriod'] ?? 1],
      lastUpdated: DateTime.parse(
        json['lastUpdated'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  PrivacySettings copyWith({
    bool? recordingConsent,
    bool? transcriptionSharing,
    bool? cloudSync,
    bool? analytics,
    DataRetentionPeriod? retentionPeriod,
    DateTime? lastUpdated,
  }) {
    return PrivacySettings(
      recordingConsent: recordingConsent ?? this.recordingConsent,
      transcriptionSharing: transcriptionSharing ?? this.transcriptionSharing,
      cloudSync: cloudSync ?? this.cloudSync,
      analytics: analytics ?? this.analytics,
      retentionPeriod: retentionPeriod ?? this.retentionPeriod,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class AnonymizedData {
  final String anonymousId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final String? originalDataHash;

  const AnonymizedData({
    required this.anonymousId,
    required this.data,
    required this.createdAt,
    this.originalDataHash,
  });

  Map<String, dynamic> toJson() {
    return {
      'anonymousId': anonymousId,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'originalDataHash': originalDataHash,
    };
  }

  factory AnonymizedData.fromJson(Map<String, dynamic> json) {
    return AnonymizedData(
      anonymousId: json['anonymousId'],
      data: Map<String, dynamic>.from(json['data']),
      createdAt: DateTime.parse(json['createdAt']),
      originalDataHash: json['originalDataHash'],
    );
  }
}

class DataExportRequest {
  final String userId;
  final List<String> dataTypes;
  final DateTime requestedAt;
  final bool includeAnonymizedData;

  const DataExportRequest({
    required this.userId,
    required this.dataTypes,
    required this.requestedAt,
    this.includeAnonymizedData = false,
  });
}

class DataExportResult {
  final String exportId;
  final Map<String, dynamic> userData;
  final List<AnonymizedData> anonymizedData;
  final DateTime exportedAt;
  final int totalRecords;

  const DataExportResult({
    required this.exportId,
    required this.userData,
    required this.anonymizedData,
    required this.exportedAt,
    required this.totalRecords,
  });

  Map<String, dynamic> toJson() {
    return {
      'exportId': exportId,
      'userData': userData,
      'anonymizedData': anonymizedData.map((d) => d.toJson()).toList(),
      'exportedAt': exportedAt.toIso8601String(),
      'totalRecords': totalRecords,
    };
  }
}

class DataAnonymizationService {
  static const String _privacySettingsKey = 'privacy_settings';
  static const String _anonymousUserIdKey = 'anonymous_user_id';
  static const String _dataRetentionKey = 'data_retention_';

  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;
  final Uuid _uuid;

  late String _anonymousUserId;
  late PrivacySettings _privacySettings;

  DataAnonymizationService._(this._secureStorage, this._prefs, this._uuid);

  static DataAnonymizationService? _instance;

  static Future<DataAnonymizationService> getInstance() async {
    if (_instance != null) return _instance!;

    const secureStorage = FlutterSecureStorage();
    final prefs = await SharedPreferences.getInstance();
    const uuid = Uuid();

    _instance = DataAnonymizationService._(secureStorage, prefs, uuid);
    await _instance!._initialize();

    return _instance!;
  }

  Future<void> _initialize() async {
    await _initializeAnonymousUserId();
    await _loadPrivacySettings();
    await _schedulePurgeExpiredData();
  }

  Future<void> _initializeAnonymousUserId() async {
    String? existingId = await _secureStorage.read(key: _anonymousUserIdKey);
    if (existingId == null) {
      _anonymousUserId = _uuid.v4();
      await _secureStorage.write(
        key: _anonymousUserIdKey,
        value: _anonymousUserId,
      );
      developer.log(
        'Generated new anonymous user ID',
        name: 'DataAnonymizationService',
      );
    } else {
      _anonymousUserId = existingId;
      developer.log(
        'Loaded existing anonymous user ID',
        name: 'DataAnonymizationService',
      );
    }
  }

  Future<void> _loadPrivacySettings() async {
    final settingsJson = _prefs.getString(_privacySettingsKey);
    if (settingsJson != null) {
      try {
        final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
        _privacySettings = PrivacySettings.fromJson(settingsMap);
      } catch (e) {
        developer.log(
          'Error loading privacy settings, using defaults: $e',
          name: 'DataAnonymizationService',
        );
        _privacySettings = PrivacySettings.defaultSettings();
      }
    } else {
      _privacySettings = PrivacySettings.defaultSettings();
    }
  }

  Future<void> _savePrivacySettings() async {
    final settingsJson = jsonEncode(_privacySettings.toJson());
    await _prefs.setString(_privacySettingsKey, settingsJson);
  }

  String get anonymousUserId => _anonymousUserId;
  PrivacySettings get privacySettings => _privacySettings;

  Future<void> updatePrivacySettings(PrivacySettings newSettings) async {
    _privacySettings = newSettings.copyWith(lastUpdated: DateTime.now());
    await _savePrivacySettings();
    developer.log('Privacy settings updated', name: 'DataAnonymizationService');
  }

  Future<void> setPrivacyControl(
    PrivacyControlType control,
    bool enabled,
  ) async {
    switch (control) {
      case PrivacyControlType.recordingConsent:
        _privacySettings = _privacySettings.copyWith(recordingConsent: enabled);
        break;
      case PrivacyControlType.transcriptionSharing:
        _privacySettings = _privacySettings.copyWith(
          transcriptionSharing: enabled,
        );
        break;
      case PrivacyControlType.cloudSync:
        _privacySettings = _privacySettings.copyWith(cloudSync: enabled);
        break;
      case PrivacyControlType.analytics:
        _privacySettings = _privacySettings.copyWith(analytics: enabled);
        break;
      default:
        break;
    }
    await _savePrivacySettings();
  }

  Future<void> setDataRetentionPeriod(DataRetentionPeriod period) async {
    _privacySettings = _privacySettings.copyWith(retentionPeriod: period);
    await _savePrivacySettings();
    await _schedulePurgeExpiredData();
  }

  String hashData(String data, {String? salt}) {
    final saltBytes = salt != null
        ? utf8.encode(salt)
        : utf8.encode(_anonymousUserId);
    final dataBytes = utf8.encode(data);
    final combined = Uint8List.fromList([...saltBytes, ...dataBytes]);

    final digest = sha256.convert(combined);
    return digest.toString();
  }

  AnonymizedData anonymizeData(
    Map<String, dynamic> originalData, {
    List<String>? sensitiveFields,
  }) {
    final anonymizedData = Map<String, dynamic>.from(originalData);

    // Remove or hash sensitive fields
    final defaultSensitiveFields = [
      'userId',
      'email',
      'phone',
      'name',
      'address',
      'ip',
    ];
    final fieldsToAnonymize = sensitiveFields ?? defaultSensitiveFields;

    for (final field in fieldsToAnonymize) {
      if (anonymizedData.containsKey(field)) {
        final originalValue = anonymizedData[field]?.toString();
        if (originalValue != null && originalValue.isNotEmpty) {
          anonymizedData[field] = hashData(originalValue);
        }
      }
    }

    // Replace user identifiers with anonymous ID
    anonymizedData['anonymousUserId'] = _anonymousUserId;
    anonymizedData.remove('userId');

    // Add anonymization metadata
    anonymizedData['anonymizedAt'] = DateTime.now().toIso8601String();

    return AnonymizedData(
      anonymousId: _anonymousUserId,
      data: anonymizedData,
      createdAt: DateTime.now(),
      originalDataHash: hashData(jsonEncode(originalData)),
    );
  }

  AnonymizedData anonymizeForAnalytics(Map<String, dynamic> analyticsData) {
    final anonymized = Map<String, dynamic>.from(analyticsData);

    // Preserve utility while removing identifying information
    anonymized.remove('userId');
    anonymized.remove('sessionId');
    anonymized.remove('deviceId');

    // Replace with anonymized alternatives
    anonymized['anonymousUserId'] = _anonymousUserId;
    anonymized['sessionHash'] = hashData(
      analyticsData['sessionId']?.toString() ?? '',
    );

    // Keep aggregatable data
    if (analyticsData.containsKey('timestamp')) {
      final timestamp = DateTime.parse(analyticsData['timestamp']);
      // Round to hour for privacy while preserving temporal patterns
      final roundedTimestamp = DateTime(
        timestamp.year,
        timestamp.month,
        timestamp.day,
        timestamp.hour,
      );
      anonymized['timeWindow'] = roundedTimestamp.toIso8601String();
    }

    return AnonymizedData(
      anonymousId: _anonymousUserId,
      data: anonymized,
      createdAt: DateTime.now(),
      originalDataHash: hashData(jsonEncode(analyticsData)),
    );
  }

  Future<void> _schedulePurgeExpiredData() async {
    final retentionDays = _getRetentionDays(_privacySettings.retentionPeriod);
    if (retentionDays == null) return; // Indefinite retention

    final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
    await _purgeDataOlderThan(cutoffDate);
  }

  int? _getRetentionDays(DataRetentionPeriod period) {
    switch (period) {
      case DataRetentionPeriod.days30:
        return 30;
      case DataRetentionPeriod.days90:
        return 90;
      case DataRetentionPeriod.days365:
        return 365;
      case DataRetentionPeriod.indefinite:
        return null;
    }
  }

  Future<void> _purgeDataOlderThan(DateTime cutoffDate) async {
    // Get all retention keys
    final keys = _prefs.getKeys().where(
      (key) => key.startsWith(_dataRetentionKey),
    );

    for (final key in keys) {
      final dataJson = _prefs.getString(key);
      if (dataJson != null) {
        try {
          final data = jsonDecode(dataJson) as Map<String, dynamic>;
          final createdAt = DateTime.parse(data['createdAt']);

          if (createdAt.isBefore(cutoffDate)) {
            await _prefs.remove(key);
            developer.log(
              'Purged expired data: $key',
              name: 'DataAnonymizationService',
            );
          }
        } catch (e) {
          developer.log(
            'Error processing retention data for $key: $e',
            name: 'DataAnonymizationService',
          );
        }
      }
    }
  }

  Future<DataExportResult> exportUserData(DataExportRequest request) async {
    final exportId = _uuid.v4();
    final userData = <String, dynamic>{};
    final anonymizedData = <AnonymizedData>[];

    // Export privacy settings
    userData['privacySettings'] = _privacySettings.toJson();
    userData['anonymousUserId'] = _anonymousUserId;
    userData['exportRequest'] = {
      'requestedAt': request.requestedAt.toIso8601String(),
      'dataTypes': request.dataTypes,
      'includeAnonymizedData': request.includeAnonymizedData,
    };

    // Export anonymized data if requested
    if (request.includeAnonymizedData) {
      final keys = _prefs.getKeys().where(
        (key) => key.startsWith(_dataRetentionKey),
      );

      for (final key in keys) {
        final dataJson = _prefs.getString(key);
        if (dataJson != null) {
          try {
            final data = jsonDecode(dataJson) as Map<String, dynamic>;
            anonymizedData.add(AnonymizedData.fromJson(data));
          } catch (e) {
            developer.log(
              'Error exporting anonymized data from $key: $e',
              name: 'DataAnonymizationService',
            );
          }
        }
      }
    }

    developer.log(
      'Data export completed for ${request.dataTypes.length} data types',
      name: 'DataAnonymizationService',
    );

    return DataExportResult(
      exportId: exportId,
      userData: userData,
      anonymizedData: anonymizedData,
      exportedAt: DateTime.now(),
      totalRecords: userData.length + anonymizedData.length,
    );
  }

  Future<bool> deleteAllUserData() async {
    try {
      // Clear privacy settings
      await _prefs.remove(_privacySettingsKey);

      // Clear anonymous user ID
      await _secureStorage.delete(key: _anonymousUserIdKey);

      // Clear all anonymized data
      final keys = _prefs.getKeys().where(
        (key) => key.startsWith(_dataRetentionKey),
      );
      for (final key in keys) {
        await _prefs.remove(key);
      }

      // Reinitialize with new anonymous ID
      await _initializeAnonymousUserId();
      _privacySettings = PrivacySettings.defaultSettings();
      await _savePrivacySettings();

      developer.log(
        'All user data deleted and service reinitialized',
        name: 'DataAnonymizationService',
      );
      return true;
    } catch (e) {
      developer.log(
        'Error deleting user data: $e',
        name: 'DataAnonymizationService',
      );
      return false;
    }
  }

  Future<void> secureDataWipe() async {
    // Perform secure deletion by overwriting storage
    // Note: This is a best-effort approach as secure deletion on mobile devices
    // depends on the underlying storage technology and OS implementation

    try {
      // Generate random data to overwrite
      final random = List.generate(1024, (index) => _uuid.v4()).join();

      // Overwrite sensitive keys multiple times
      for (int i = 0; i < 3; i++) {
        await _secureStorage.write(key: _anonymousUserIdKey, value: random);
        await _prefs.setString(_privacySettingsKey, random);

        final keys = _prefs.getKeys().where(
          (key) => key.startsWith(_dataRetentionKey),
        );
        for (final key in keys) {
          await _prefs.setString(key, random);
        }
      }

      // Finally delete the keys
      await deleteAllUserData();

      developer.log(
        'Secure data wipe completed',
        name: 'DataAnonymizationService',
      );
    } catch (e) {
      developer.log(
        'Error during secure data wipe: $e',
        name: 'DataAnonymizationService',
      );
      rethrow;
    }
  }

  bool checkPrivacyCompliance() {
    // Verify that privacy settings are properly configured
    if (!_privacySettings.recordingConsent) {
      developer.log(
        'Recording consent not granted',
        name: 'DataAnonymizationService',
      );
      return false;
    }

    // Check if data retention period is reasonable
    final retentionDays = _getRetentionDays(_privacySettings.retentionPeriod);
    if (retentionDays != null && retentionDays > 365) {
      developer.log(
        'Data retention period exceeds recommended maximum',
        name: 'DataAnonymizationService',
      );
      return false;
    }

    return true;
  }

  Future<void> storeAnonymizedData(AnonymizedData data) async {
    final key =
        '$_dataRetentionKey${data.anonymousId}_${data.createdAt.millisecondsSinceEpoch}';
    final dataJson = jsonEncode(data.toJson());
    await _prefs.setString(key, dataJson);
  }
}
