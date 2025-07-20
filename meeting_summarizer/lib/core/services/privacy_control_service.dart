import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'data_anonymization_service.dart';

class PrivacyControlEvent {
  final PrivacyControlType type;
  final bool enabled;
  final DateTime timestamp;
  final String? reason;

  const PrivacyControlEvent({
    required this.type,
    required this.enabled,
    required this.timestamp,
    this.reason,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'enabled': enabled,
      'timestamp': timestamp.toIso8601String(),
      'reason': reason,
    };
  }
}

class PrivacyAuditLog {
  final String id;
  final List<PrivacyControlEvent> events;
  final DateTime createdAt;

  const PrivacyAuditLog({
    required this.id,
    required this.events,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'events': events.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class PrivacyValidationResult {
  final bool isValid;
  final List<String> violations;
  final List<String> warnings;
  final List<String> recommendations;

  const PrivacyValidationResult({
    required this.isValid,
    required this.violations,
    required this.warnings,
    required this.recommendations,
  });
}

class PrivacyControlService extends ChangeNotifier {
  final DataAnonymizationService _anonymizationService;
  final List<PrivacyControlEvent> _auditLog = [];

  PrivacyControlService._(this._anonymizationService);

  static PrivacyControlService? _instance;

  static Future<PrivacyControlService> getInstance() async {
    if (_instance != null) return _instance!;

    final anonymizationService = await DataAnonymizationService.getInstance();
    _instance = PrivacyControlService._(anonymizationService);

    return _instance!;
  }

  PrivacySettings get currentSettings => _anonymizationService.privacySettings;
  String get anonymousUserId => _anonymizationService.anonymousUserId;
  List<PrivacyControlEvent> get auditLog => List.unmodifiable(_auditLog);

  Future<bool> requestRecordingConsent({String? reason}) async {
    try {
      await _setPrivacyControl(
        PrivacyControlType.recordingConsent,
        true,
        reason: reason ?? 'User granted recording consent',
      );
      return true;
    } catch (e) {
      developer.log(
        'Error requesting recording consent: $e',
        name: 'PrivacyControlService',
      );
      return false;
    }
  }

  Future<void> revokeRecordingConsent({String? reason}) async {
    await _setPrivacyControl(
      PrivacyControlType.recordingConsent,
      false,
      reason: reason ?? 'User revoked recording consent',
    );
  }

  Future<void> setTranscriptionSharing(bool enabled, {String? reason}) async {
    await _setPrivacyControl(
      PrivacyControlType.transcriptionSharing,
      enabled,
      reason: reason,
    );
  }

  Future<void> setCloudSync(bool enabled, {String? reason}) async {
    await _setPrivacyControl(
      PrivacyControlType.cloudSync,
      enabled,
      reason: reason,
    );
  }

  Future<void> setAnalytics(bool enabled, {String? reason}) async {
    await _setPrivacyControl(
      PrivacyControlType.analytics,
      enabled,
      reason: reason,
    );
  }

  Future<void> setDataRetentionPeriod(
    DataRetentionPeriod period, {
    String? reason,
  }) async {
    final oldPeriod = currentSettings.retentionPeriod;
    await _anonymizationService.setDataRetentionPeriod(period);

    _auditLog.add(
      PrivacyControlEvent(
        type: PrivacyControlType.dataDeletion,
        enabled: true,
        timestamp: DateTime.now(),
        reason:
            reason ??
            'Data retention period changed from $oldPeriod to $period',
      ),
    );

    notifyListeners();
    developer.log(
      'Data retention period updated to $period',
      name: 'PrivacyControlService',
    );
  }

  Future<void> _setPrivacyControl(
    PrivacyControlType type,
    bool enabled, {
    String? reason,
  }) async {
    await _anonymizationService.setPrivacyControl(type, enabled);

    _auditLog.add(
      PrivacyControlEvent(
        type: type,
        enabled: enabled,
        timestamp: DateTime.now(),
        reason: reason,
      ),
    );

    notifyListeners();
    developer.log(
      'Privacy control $type set to $enabled',
      name: 'PrivacyControlService',
    );
  }

  PrivacyValidationResult validatePrivacySettings() {
    final violations = <String>[];
    final warnings = <String>[];
    final recommendations = <String>[];

    // Check essential consents
    if (!currentSettings.recordingConsent) {
      violations.add('Recording consent is required for audio processing');
    }

    // Check data retention policy
    if (currentSettings.retentionPeriod == DataRetentionPeriod.indefinite) {
      warnings.add(
        'Indefinite data retention may not comply with privacy regulations',
      );
      recommendations.add(
        'Consider setting a specific retention period (90 or 365 days)',
      );
    }

    // Check cloud sync without consent
    if (currentSettings.cloudSync && !currentSettings.transcriptionSharing) {
      warnings.add(
        'Cloud sync is enabled but transcription sharing is disabled',
      );
      recommendations.add('Review cloud sync settings for consistency');
    }

    // Check analytics without explicit consent
    if (currentSettings.analytics) {
      if (_auditLog
          .where(
            (event) =>
                event.type == PrivacyControlType.analytics &&
                event.enabled == true,
          )
          .isEmpty) {
        warnings.add('Analytics enabled without explicit audit trail');
      }
    }

    // Security recommendations
    if (currentSettings.cloudSync) {
      recommendations.add('Ensure cloud storage is encrypted');
    }

    if (currentSettings.transcriptionSharing) {
      recommendations.add('Review who has access to shared transcriptions');
    }

    return PrivacyValidationResult(
      isValid: violations.isEmpty,
      violations: violations,
      warnings: warnings,
      recommendations: recommendations,
    );
  }

  bool canPerformRecording() {
    return currentSettings.recordingConsent;
  }

  bool canShareTranscription() {
    return currentSettings.transcriptionSharing;
  }

  bool canSyncToCloud() {
    return currentSettings.cloudSync;
  }

  bool canCollectAnalytics() {
    return currentSettings.analytics;
  }

  Future<DataExportResult> requestDataExport({
    List<String>? dataTypes,
    bool includeAnonymizedData = false,
  }) async {
    final request = DataExportRequest(
      userId: anonymousUserId,
      dataTypes: dataTypes ?? ['privacySettings', 'auditLog', 'anonymizedData'],
      requestedAt: DateTime.now(),
      includeAnonymizedData: includeAnonymizedData,
    );

    _auditLog.add(
      PrivacyControlEvent(
        type: PrivacyControlType.dataExport,
        enabled: true,
        timestamp: DateTime.now(),
        reason: 'User requested data export',
      ),
    );

    final result = await _anonymizationService.exportUserData(request);

    // Add audit log to export
    final exportData = Map<String, dynamic>.from(result.userData);
    exportData['auditLog'] = PrivacyAuditLog(
      id: result.exportId,
      events: _auditLog,
      createdAt: DateTime.now(),
    ).toJson();

    developer.log(
      'Data export completed: ${result.totalRecords} records',
      name: 'PrivacyControlService',
    );
    notifyListeners();

    return DataExportResult(
      exportId: result.exportId,
      userData: exportData,
      anonymizedData: result.anonymizedData,
      exportedAt: result.exportedAt,
      totalRecords: result.totalRecords,
    );
  }

  Future<bool> requestDataDeletion({String? reason}) async {
    _auditLog.add(
      PrivacyControlEvent(
        type: PrivacyControlType.dataDeletion,
        enabled: true,
        timestamp: DateTime.now(),
        reason: reason ?? 'User requested complete data deletion',
      ),
    );

    final success = await _anonymizationService.deleteAllUserData();

    if (success) {
      _auditLog.clear();
      notifyListeners();
      developer.log(
        'All user data deleted successfully',
        name: 'PrivacyControlService',
      );
    }

    return success;
  }

  Future<void> requestSecureDataWipe({String? reason}) async {
    _auditLog.add(
      PrivacyControlEvent(
        type: PrivacyControlType.dataDeletion,
        enabled: true,
        timestamp: DateTime.now(),
        reason: reason ?? 'User requested secure data wipe',
      ),
    );

    await _anonymizationService.secureDataWipe();
    _auditLog.clear();
    notifyListeners();

    developer.log('Secure data wipe completed', name: 'PrivacyControlService');
  }

  Future<void> updateAllPrivacySettings(
    PrivacySettings newSettings, {
    String? reason,
  }) async {
    await _anonymizationService.updatePrivacySettings(newSettings);

    _auditLog.add(
      PrivacyControlEvent(
        type: PrivacyControlType.recordingConsent,
        enabled: true,
        timestamp: DateTime.now(),
        reason: reason ?? 'Bulk privacy settings update',
      ),
    );

    notifyListeners();
    developer.log(
      'All privacy settings updated',
      name: 'PrivacyControlService',
    );
  }

  Map<String, dynamic> getPrivacyDashboardData() {
    final validation = validatePrivacySettings();

    return {
      'settings': currentSettings.toJson(),
      'anonymousUserId': anonymousUserId,
      'validation': {
        'isValid': validation.isValid,
        'violations': validation.violations,
        'warnings': validation.warnings,
        'recommendations': validation.recommendations,
      },
      'auditLog': _auditLog.map((e) => e.toJson()).toList(),
      'stats': {
        'totalAuditEvents': _auditLog.length,
        'lastSettingsUpdate': currentSettings.lastUpdated.toIso8601String(),
        'retentionPeriodDays': _getRetentionDays(
          currentSettings.retentionPeriod,
        ),
      },
    };
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

  Future<void> clearAuditLog() async {
    _auditLog.clear();
    notifyListeners();
    developer.log('Audit log cleared', name: 'PrivacyControlService');
  }

  Future<bool> hasValidConsent() async {
    final validation = validatePrivacySettings();
    return validation.isValid && currentSettings.recordingConsent;
  }

  List<PrivacyControlEvent> getRecentPrivacyEvents({int limit = 10}) {
    final sortedEvents = List<PrivacyControlEvent>.from(_auditLog)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return sortedEvents.take(limit).toList();
  }
}
