/// Consent management service for GDPR compliance
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/gdpr/consent_record.dart';
import '../enums/gdpr_consent_type.dart';
import '../enums/legal_basis.dart';
import 'gdpr_compliance_service.dart';

/// Service for managing user consent records and consent-related operations
class ConsentManager {
  static const String _consentStorageKey = 'gdpr_consent_records';
  static const String _consentVersionKey = 'consent_policy_version';
  static const String _currentPolicyVersion = '1.0.0';

  bool _isInitialized = false;
  SharedPreferences? _prefs;

  /// In-memory cache of consent records
  final Map<String, List<ConsentRecord>> _consentCache = {};

  /// Stream controller for consent events
  final StreamController<ConsentEvent> _eventController =
      StreamController<ConsentEvent>.broadcast();

  /// Initialize the consent manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log('ConsentManager: Initializing...');

      _prefs = await SharedPreferences.getInstance();
      await _loadConsentRecords();

      _isInitialized = true;
      log('ConsentManager: Initialization completed');
    } catch (e) {
      log('ConsentManager: Initialization failed: $e');
      throw GDPRComplianceException('Failed to initialize consent manager: $e');
    }
  }

  /// Dispose of the consent manager
  Future<void> dispose() async {
    try {
      await _eventController.close();
      _consentCache.clear();
      _isInitialized = false;
      log('ConsentManager: Disposed');
    } catch (e) {
      log('ConsentManager: Error during disposal: $e');
    }
  }

  /// Stream of consent events
  Stream<ConsentEvent> get events => _eventController.stream;

  /// Request consent from user for a specific type
  Future<ConsentRecord> requestConsent({
    required String userId,
    required GDPRConsentType consentType,
    LegalBasis legalBasis = LegalBasis.consent,
    String? policyVersion,
    String? ipAddress,
    String? userAgent,
    String? consentMethod,
    bool isExplicit = true,
    Map<String, dynamic> metadata = const {},
  }) async {
    _ensureInitialized();

    try {
      // Check if consent already exists
      final existingConsent = await getConsentRecord(userId, consentType);
      if (existingConsent != null && existingConsent.isValid) {
        log('ConsentManager: Consent already exists for ${consentType.value}');
        return existingConsent;
      }

      // Create new consent request (initially pending)
      final consentRecord = ConsentRecord(
        id: _generateConsentId(userId, consentType),
        userId: userId,
        consentType: consentType,
        status: ConsentStatus.pending,
        legalBasis: legalBasis,
        policyVersion: policyVersion ?? _currentPolicyVersion,
        ipAddress: ipAddress,
        userAgent: userAgent,
        consentMethod: consentMethod ?? 'app_request',
        isExplicit: isExplicit,
        metadata: metadata,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _storeConsentRecord(consentRecord);

      _eventController.add(ConsentEvent.consentRequested(consentRecord));

      log('ConsentManager: Consent requested for ${consentType.value}');
      return consentRecord;
    } catch (e) {
      log('ConsentManager: Error requesting consent: $e');
      throw GDPRComplianceException('Failed to request consent: $e');
    }
  }

  /// Grant consent for a specific type
  Future<ConsentRecord> grantConsent({
    required String userId,
    required GDPRConsentType consentType,
    Duration? validity,
    String? ipAddress,
    String? userAgent,
    Map<String, dynamic> metadata = const {},
  }) async {
    _ensureInitialized();

    try {
      final now = DateTime.now();

      // Check if there's a pending consent request
      var consentRecord = await getConsentRecord(userId, consentType);

      if (consentRecord == null) {
        // Create new consent record if none exists
        consentRecord = ConsentRecord(
          id: _generateConsentId(userId, consentType),
          userId: userId,
          consentType: consentType,
          status: ConsentStatus.granted,
          legalBasis: LegalBasis.consent,
          grantedAt: now,
          expiresAt: validity != null ? now.add(validity) : null,
          policyVersion: _currentPolicyVersion,
          ipAddress: ipAddress,
          userAgent: userAgent,
          consentMethod: 'app_grant',
          isExplicit: true,
          metadata: metadata,
          createdAt: now,
          updatedAt: now,
        );
      } else {
        // Update existing consent record
        consentRecord = consentRecord.copyWith(
          status: ConsentStatus.granted,
          grantedAt: now,
          expiresAt: validity != null ? now.add(validity) : null,
          ipAddress: ipAddress ?? consentRecord.ipAddress,
          userAgent: userAgent ?? consentRecord.userAgent,
          metadata: {...consentRecord.metadata, ...metadata},
          updatedAt: now,
        );
      }

      await _storeConsentRecord(consentRecord);

      _eventController.add(ConsentEvent.consentGranted(consentRecord));

      log('ConsentManager: Consent granted for ${consentType.value}');
      return consentRecord;
    } catch (e) {
      log('ConsentManager: Error granting consent: $e');
      throw GDPRComplianceException('Failed to grant consent: $e');
    }
  }

  /// Withdraw consent for a specific type
  Future<ConsentRecord> withdrawConsent({
    required String userId,
    required GDPRConsentType consentType,
    String? reason,
    String? ipAddress,
    String? userAgent,
    Map<String, dynamic> metadata = const {},
  }) async {
    _ensureInitialized();

    try {
      final consentRecord = await getConsentRecord(userId, consentType);
      if (consentRecord == null) {
        throw GDPRComplianceException('No consent record found to withdraw');
      }

      final now = DateTime.now();
      final withdrawnRecord = consentRecord.copyWith(
        status: ConsentStatus.withdrawn,
        withdrawnAt: now,
        ipAddress: ipAddress ?? consentRecord.ipAddress,
        userAgent: userAgent ?? consentRecord.userAgent,
        metadata: {
          ...consentRecord.metadata,
          ...metadata,
          if (reason != null) 'withdrawal_reason': reason,
        },
        updatedAt: now,
      );

      await _storeConsentRecord(withdrawnRecord);

      _eventController.add(ConsentEvent.consentWithdrawn(withdrawnRecord));

      log('ConsentManager: Consent withdrawn for ${consentType.value}');
      return withdrawnRecord;
    } catch (e) {
      log('ConsentManager: Error withdrawing consent: $e');
      throw GDPRComplianceException('Failed to withdraw consent: $e');
    }
  }

  /// Check if user has granted consent for a specific type
  Future<bool> hasConsent(String userId, GDPRConsentType consentType) async {
    _ensureInitialized();

    try {
      final consentRecord = await getConsentRecord(userId, consentType);
      return consentRecord?.isValid ?? false;
    } catch (e) {
      log('ConsentManager: Error checking consent: $e');
      return false;
    }
  }

  /// Get consent record for a specific user and type
  Future<ConsentRecord?> getConsentRecord(
    String userId,
    GDPRConsentType consentType,
  ) async {
    _ensureInitialized();

    try {
      final userConsents = _consentCache[userId] ?? [];

      // Find the most recent consent record for this type
      final consents = userConsents
          .where((record) => record.consentType == consentType)
          .toList();

      if (consents.isEmpty) return null;

      // Sort by creation date and return the most recent
      consents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return consents.first;
    } catch (e) {
      log('ConsentManager: Error getting consent record: $e');
      return null;
    }
  }

  /// Get consent summary for a user
  Future<ConsentSummary> getConsentSummary(String userId) async {
    _ensureInitialized();

    try {
      final userConsents = _consentCache[userId] ?? [];

      // Get the most recent consent record for each type
      final Map<GDPRConsentType, ConsentRecord> latestConsents = {};
      for (final consent in userConsents) {
        final existing = latestConsents[consent.consentType];
        if (existing == null || consent.createdAt.isAfter(existing.createdAt)) {
          latestConsents[consent.consentType] = consent;
        }
      }

      return ConsentSummary(
        userId: userId,
        records: latestConsents.values.toList(),
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      log('ConsentManager: Error getting consent summary: $e');
      throw GDPRComplianceException('Failed to get consent summary: $e');
    }
  }

  /// Get all consent records for all users
  Future<List<ConsentRecord>> getAllConsentRecords() async {
    _ensureInitialized();

    try {
      final allRecords = <ConsentRecord>[];
      for (final userRecords in _consentCache.values) {
        allRecords.addAll(userRecords);
      }
      return allRecords;
    } catch (e) {
      log('ConsentManager: Error getting all consent records: $e');
      throw GDPRComplianceException('Failed to get all consent records: $e');
    }
  }

  /// Get consents expiring within specified days
  Future<List<ConsentRecord>> getExpiringConsents(int days) async {
    _ensureInitialized();

    try {
      final allRecords = await getAllConsentRecords();
      final now = DateTime.now();

      return allRecords.where((record) {
        if (record.expiresAt == null || !record.isValid) return false;
        final daysUntilExpiry = record.expiresAt!.difference(now).inDays;
        return daysUntilExpiry > 0 && daysUntilExpiry <= days;
      }).toList();
    } catch (e) {
      log('ConsentManager: Error getting expiring consents: $e');
      return [];
    }
  }

  /// Refresh expired consents by requesting new consent
  Future<void> refreshExpiredConsents(String userId) async {
    _ensureInitialized();

    try {
      final summary = await getConsentSummary(userId);

      for (final record in summary.expiredConsents) {
        await requestConsent(
          userId: userId,
          consentType: record.consentType,
          legalBasis: record.legalBasis,
          metadata: {'refresh_reason': 'consent_expired'},
        );
      }
    } catch (e) {
      log('ConsentManager: Error refreshing expired consents: $e');
      throw GDPRComplianceException('Failed to refresh expired consents: $e');
    }
  }

  /// Update consent policy version and mark consents for renewal
  Future<void> updatePolicyVersion(
    String newVersion, {
    bool requireReConsent = true,
  }) async {
    _ensureInitialized();

    try {
      await _prefs!.setString(_consentVersionKey, newVersion);

      if (requireReConsent) {
        // Mark all active consents as requiring renewal
        final allRecords = await getAllConsentRecords();

        for (final record in allRecords) {
          if (record.isValid) {
            final updatedRecord = record.copyWith(
              status: ConsentStatus.expired,
              metadata: {
                ...record.metadata,
                'policy_update_required': true,
                'previous_policy_version': record.policyVersion,
                'new_policy_version': newVersion,
              },
              updatedAt: DateTime.now(),
            );

            await _storeConsentRecord(updatedRecord);
          }
        }
      }

      log('ConsentManager: Policy version updated to $newVersion');
    } catch (e) {
      log('ConsentManager: Error updating policy version: $e');
      throw GDPRComplianceException('Failed to update policy version: $e');
    }
  }

  /// Clear all consent data for a user (for account deletion)
  Future<void> clearUserConsents(String userId) async {
    _ensureInitialized();

    try {
      _consentCache.remove(userId);
      await _saveConsentRecords();

      log('ConsentManager: Cleared all consents for user $userId');
    } catch (e) {
      log('ConsentManager: Error clearing user consents: $e');
      throw GDPRComplianceException('Failed to clear user consents: $e');
    }
  }

  /// Load consent records from storage
  Future<void> _loadConsentRecords() async {
    try {
      final storedData = _prefs!.getString(_consentStorageKey);
      if (storedData != null) {
        final Map<String, dynamic> data = jsonDecode(storedData);

        _consentCache.clear();
        data.forEach((userId, recordsJson) {
          final records = (recordsJson as List<dynamic>)
              .map(
                (recordJson) =>
                    ConsentRecord.fromJson(recordJson as Map<String, dynamic>),
              )
              .toList();
          _consentCache[userId] = records;
        });

        log(
          'ConsentManager: Loaded ${_consentCache.length} users with consent records',
        );
      }
    } catch (e) {
      log('ConsentManager: Error loading consent records: $e');
      _consentCache.clear();
    }
  }

  /// Save consent records to storage
  Future<void> _saveConsentRecords() async {
    try {
      final Map<String, dynamic> data = {};
      _consentCache.forEach((userId, records) {
        data[userId] = records.map((record) => record.toJson()).toList();
      });

      await _prefs!.setString(_consentStorageKey, jsonEncode(data));
    } catch (e) {
      log('ConsentManager: Error saving consent records: $e');
      throw GDPRComplianceException('Failed to save consent records: $e');
    }
  }

  /// Store a consent record
  Future<void> _storeConsentRecord(ConsentRecord record) async {
    try {
      final userConsents = _consentCache[record.userId] ?? <ConsentRecord>[];

      // Remove existing record with same ID
      userConsents.removeWhere((existing) => existing.id == record.id);

      // Add new/updated record
      userConsents.add(record);

      _consentCache[record.userId] = userConsents;

      await _saveConsentRecords();
    } catch (e) {
      log('ConsentManager: Error storing consent record: $e');
      throw GDPRComplianceException('Failed to store consent record: $e');
    }
  }

  /// Generate unique consent ID
  String _generateConsentId(String userId, GDPRConsentType consentType) {
    return 'consent_${userId}_${consentType.value}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Ensure manager is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw GDPRComplianceException('Consent manager not initialized');
    }
  }
}

/// Consent event for notifications
class ConsentEvent {
  final String type;
  final ConsentRecord record;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  const ConsentEvent({
    required this.type,
    required this.record,
    required this.timestamp,
    this.data = const {},
  });

  factory ConsentEvent.consentRequested(ConsentRecord record) {
    return ConsentEvent(
      type: 'consent_requested',
      record: record,
      timestamp: DateTime.now(),
      data: {'consentType': record.consentType.value},
    );
  }

  factory ConsentEvent.consentGranted(ConsentRecord record) {
    return ConsentEvent(
      type: 'consent_granted',
      record: record,
      timestamp: DateTime.now(),
      data: {'consentType': record.consentType.value},
    );
  }

  factory ConsentEvent.consentWithdrawn(ConsentRecord record) {
    return ConsentEvent(
      type: 'consent_withdrawn',
      record: record,
      timestamp: DateTime.now(),
      data: {'consentType': record.consentType.value},
    );
  }

  factory ConsentEvent.consentExpired(ConsentRecord record) {
    return ConsentEvent(
      type: 'consent_expired',
      record: record,
      timestamp: DateTime.now(),
      data: {'consentType': record.consentType.value},
    );
  }
}
