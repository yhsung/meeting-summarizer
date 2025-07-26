/// Consent record models for GDPR compliance
library;

import '../../enums/gdpr_consent_type.dart';
import '../../enums/legal_basis.dart';

/// Record of user consent for a specific purpose
class ConsentRecord {
  /// Unique identifier for this consent record
  final String id;

  /// User identifier this consent belongs to
  final String userId;

  /// Type of consent being tracked
  final GDPRConsentType consentType;

  /// Current status of the consent
  final ConsentStatus status;

  /// Legal basis for processing under GDPR
  final LegalBasis legalBasis;

  /// Timestamp when consent was granted
  final DateTime? grantedAt;

  /// Timestamp when consent was withdrawn (if applicable)
  final DateTime? withdrawnAt;

  /// Timestamp when consent expires (if applicable)
  final DateTime? expiresAt;

  /// Version of privacy policy/terms when consent was given
  final String? policyVersion;

  /// IP address where consent was given (for audit trail)
  final String? ipAddress;

  /// User agent/device info where consent was given
  final String? userAgent;

  /// Method used to obtain consent (checkbox, dialog, etc.)
  final String? consentMethod;

  /// Whether consent was given explicitly or implicitly
  final bool isExplicit;

  /// Additional metadata about the consent
  final Map<String, dynamic> metadata;

  /// Timestamp when record was created
  final DateTime createdAt;

  /// Timestamp when record was last updated
  final DateTime updatedAt;

  const ConsentRecord({
    required this.id,
    required this.userId,
    required this.consentType,
    required this.status,
    required this.legalBasis,
    this.grantedAt,
    this.withdrawnAt,
    this.expiresAt,
    this.policyVersion,
    this.ipAddress,
    this.userAgent,
    this.consentMethod,
    this.isExplicit = false,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create consent record from JSON
  factory ConsentRecord.fromJson(Map<String, dynamic> json) {
    return ConsentRecord(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      consentType: GDPRConsentType.fromString(json['consentType'] ?? ''),
      status: ConsentStatus.fromString(json['status'] ?? ''),
      legalBasis: LegalBasis.fromString(json['legalBasis'] ?? ''),
      grantedAt: json['grantedAt'] != null
          ? DateTime.tryParse(json['grantedAt'])
          : null,
      withdrawnAt: json['withdrawnAt'] != null
          ? DateTime.tryParse(json['withdrawnAt'])
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'])
          : null,
      policyVersion: json['policyVersion'],
      ipAddress: json['ipAddress'],
      userAgent: json['userAgent'],
      consentMethod: json['consentMethod'],
      isExplicit: json['isExplicit'] ?? false,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  /// Convert consent record to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'consentType': consentType.value,
      'status': status.value,
      'legalBasis': legalBasis.value,
      'grantedAt': grantedAt?.toIso8601String(),
      'withdrawnAt': withdrawnAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'policyVersion': policyVersion,
      'ipAddress': ipAddress,
      'userAgent': userAgent,
      'consentMethod': consentMethod,
      'isExplicit': isExplicit,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  ConsentRecord copyWith({
    String? id,
    String? userId,
    GDPRConsentType? consentType,
    ConsentStatus? status,
    LegalBasis? legalBasis,
    DateTime? grantedAt,
    DateTime? withdrawnAt,
    DateTime? expiresAt,
    String? policyVersion,
    String? ipAddress,
    String? userAgent,
    String? consentMethod,
    bool? isExplicit,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ConsentRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      consentType: consentType ?? this.consentType,
      status: status ?? this.status,
      legalBasis: legalBasis ?? this.legalBasis,
      grantedAt: grantedAt ?? this.grantedAt,
      withdrawnAt: withdrawnAt ?? this.withdrawnAt,
      expiresAt: expiresAt ?? this.expiresAt,
      policyVersion: policyVersion ?? this.policyVersion,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      consentMethod: consentMethod ?? this.consentMethod,
      isExplicit: isExplicit ?? this.isExplicit,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if consent is currently valid
  bool get isValid {
    if (!status.isActive) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    return true;
  }

  /// Check if consent has expired
  bool get isExpired {
    return expiresAt != null && DateTime.now().isAfter(expiresAt!);
  }

  /// Get days until expiration (null if no expiration)
  int? get daysUntilExpiration {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) return 0;
    return expiresAt!.difference(now).inDays;
  }

  /// Get duration consent has been active
  Duration? get activeDuration {
    if (grantedAt == null) return null;
    final endTime = withdrawnAt ?? DateTime.now();
    return endTime.difference(grantedAt!);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConsentRecord && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ConsentRecord(id: $id, type: ${consentType.value}, status: ${status.value})';
  }
}

/// Summary of all consent records for a user
class ConsentSummary {
  /// User identifier
  final String userId;

  /// All consent records for the user
  final List<ConsentRecord> records;

  /// Timestamp when summary was generated
  final DateTime generatedAt;

  const ConsentSummary({
    required this.userId,
    required this.records,
    required this.generatedAt,
  });

  /// Get consent record for a specific type
  ConsentRecord? getConsentRecord(GDPRConsentType type) {
    try {
      return records.firstWhere((record) => record.consentType == type);
    } catch (e) {
      return null;
    }
  }

  /// Check if user has granted consent for a specific type
  bool hasConsent(GDPRConsentType type) {
    final record = getConsentRecord(type);
    return record?.isValid ?? false;
  }

  /// Get all active consents
  List<ConsentRecord> get activeConsents {
    return records.where((record) => record.isValid).toList();
  }

  /// Get all expired consents
  List<ConsentRecord> get expiredConsents {
    return records.where((record) => record.isExpired).toList();
  }

  /// Get all withdrawn consents
  List<ConsentRecord> get withdrawnConsents {
    return records
        .where((record) => record.status == ConsentStatus.withdrawn)
        .toList();
  }

  /// Get consents that expire soon (within specified days)
  List<ConsentRecord> getConsentsExpiringSoon(int days) {
    final now = DateTime.now();
    return records.where((record) {
      if (record.expiresAt == null) return false;
      final daysUntilExpiry = record.expiresAt!.difference(now).inDays;
      return daysUntilExpiry > 0 && daysUntilExpiry <= days;
    }).toList();
  }

  /// Get overall consent compliance score (0.0 to 1.0)
  double get complianceScore {
    if (records.isEmpty) return 0.0;

    final requiredConsents = GDPRConsentType.requiredTypes;
    final grantedRequired =
        requiredConsents.where((type) => hasConsent(type)).length;

    return grantedRequired / requiredConsents.length;
  }

  /// Check if user is fully compliant with required consents
  bool get isCompliant {
    return complianceScore == 1.0;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'records': records.map((record) => record.toJson()).toList(),
      'generatedAt': generatedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory ConsentSummary.fromJson(Map<String, dynamic> json) {
    return ConsentSummary(
      userId: json['userId'] ?? '',
      records: (json['records'] as List<dynamic>? ?? [])
          .map(
            (recordJson) =>
                ConsentRecord.fromJson(recordJson as Map<String, dynamic>),
          )
          .toList(),
      generatedAt:
          DateTime.tryParse(json['generatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'ConsentSummary(userId: $userId, records: ${records.length}, compliance: ${(complianceScore * 100).toStringAsFixed(1)}%)';
  }
}
