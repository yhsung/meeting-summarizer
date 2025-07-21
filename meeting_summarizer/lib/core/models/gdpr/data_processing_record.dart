/// Data processing record models for GDPR compliance
library;

import '../../enums/data_category.dart';
import '../../enums/legal_basis.dart';

/// Record of data processing activity for GDPR compliance
class DataProcessingRecord {
  /// Unique identifier for this processing record
  final String id;

  /// User identifier whose data is being processed
  final String userId;

  /// Category of data being processed
  final DataCategory dataCategory;

  /// Purpose of the data processing
  final ProcessingPurpose purpose;

  /// Legal basis for processing under GDPR
  final LegalBasis legalBasis;

  /// Timestamp when processing started
  final DateTime startedAt;

  /// Timestamp when processing completed (null if ongoing)
  final DateTime? completedAt;

  /// Description of the processing activity
  final String description;

  /// Data source (where the data came from)
  final String? dataSource;

  /// Data recipient (who received the processed data)
  final String? dataRecipient;

  /// Whether data was shared with third parties
  final bool sharedWithThirdParty;

  /// Third party details if data was shared
  final String? thirdPartyDetails;

  /// Retention period for this data
  final RetentionPeriod retentionPeriod;

  /// Expected deletion date based on retention period
  final DateTime? expectedDeletionDate;

  /// Whether processing involved automated decision making
  final bool involvedAutomatedDecision;

  /// Details of automated decision making process
  final String? automatedDecisionDetails;

  /// Whether data was transferred outside EU/EEA
  final bool transferredOutsideEU;

  /// Details of international transfer
  final String? internationalTransferDetails;

  /// Security measures applied during processing
  final List<String> securityMeasures;

  /// Additional metadata about the processing
  final Map<String, dynamic> metadata;

  /// Timestamp when record was created
  final DateTime createdAt;

  /// Timestamp when record was last updated
  final DateTime updatedAt;

  const DataProcessingRecord({
    required this.id,
    required this.userId,
    required this.dataCategory,
    required this.purpose,
    required this.legalBasis,
    required this.startedAt,
    this.completedAt,
    required this.description,
    this.dataSource,
    this.dataRecipient,
    this.sharedWithThirdParty = false,
    this.thirdPartyDetails,
    this.retentionPeriod = RetentionPeriod.oneYear,
    this.expectedDeletionDate,
    this.involvedAutomatedDecision = false,
    this.automatedDecisionDetails,
    this.transferredOutsideEU = false,
    this.internationalTransferDetails,
    this.securityMeasures = const [],
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create processing record from JSON
  factory DataProcessingRecord.fromJson(Map<String, dynamic> json) {
    return DataProcessingRecord(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      dataCategory: DataCategory.fromString(json['dataCategory'] ?? ''),
      purpose: ProcessingPurpose.fromString(json['purpose'] ?? ''),
      legalBasis: LegalBasis.fromString(json['legalBasis'] ?? ''),
      startedAt: DateTime.tryParse(json['startedAt'] ?? '') ?? DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,
      description: json['description'] ?? '',
      dataSource: json['dataSource'],
      dataRecipient: json['dataRecipient'],
      sharedWithThirdParty: json['sharedWithThirdParty'] ?? false,
      thirdPartyDetails: json['thirdPartyDetails'],
      retentionPeriod: RetentionPeriod.fromString(
        json['retentionPeriod'] ?? 'one_year',
      ),
      expectedDeletionDate: json['expectedDeletionDate'] != null
          ? DateTime.tryParse(json['expectedDeletionDate'])
          : null,
      involvedAutomatedDecision: json['involvedAutomatedDecision'] ?? false,
      automatedDecisionDetails: json['automatedDecisionDetails'],
      transferredOutsideEU: json['transferredOutsideEU'] ?? false,
      internationalTransferDetails: json['internationalTransferDetails'],
      securityMeasures: (json['securityMeasures'] as List<dynamic>? ?? [])
          .map((measure) => measure.toString())
          .toList(),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  /// Convert processing record to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'dataCategory': dataCategory.value,
      'purpose': purpose.value,
      'legalBasis': legalBasis.value,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'description': description,
      'dataSource': dataSource,
      'dataRecipient': dataRecipient,
      'sharedWithThirdParty': sharedWithThirdParty,
      'thirdPartyDetails': thirdPartyDetails,
      'retentionPeriod': retentionPeriod.value,
      'expectedDeletionDate': expectedDeletionDate?.toIso8601String(),
      'involvedAutomatedDecision': involvedAutomatedDecision,
      'automatedDecisionDetails': automatedDecisionDetails,
      'transferredOutsideEU': transferredOutsideEU,
      'internationalTransferDetails': internationalTransferDetails,
      'securityMeasures': securityMeasures,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  DataProcessingRecord copyWith({
    String? id,
    String? userId,
    DataCategory? dataCategory,
    ProcessingPurpose? purpose,
    LegalBasis? legalBasis,
    DateTime? startedAt,
    DateTime? completedAt,
    String? description,
    String? dataSource,
    String? dataRecipient,
    bool? sharedWithThirdParty,
    String? thirdPartyDetails,
    RetentionPeriod? retentionPeriod,
    DateTime? expectedDeletionDate,
    bool? involvedAutomatedDecision,
    String? automatedDecisionDetails,
    bool? transferredOutsideEU,
    String? internationalTransferDetails,
    List<String>? securityMeasures,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DataProcessingRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      dataCategory: dataCategory ?? this.dataCategory,
      purpose: purpose ?? this.purpose,
      legalBasis: legalBasis ?? this.legalBasis,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      description: description ?? this.description,
      dataSource: dataSource ?? this.dataSource,
      dataRecipient: dataRecipient ?? this.dataRecipient,
      sharedWithThirdParty: sharedWithThirdParty ?? this.sharedWithThirdParty,
      thirdPartyDetails: thirdPartyDetails ?? this.thirdPartyDetails,
      retentionPeriod: retentionPeriod ?? this.retentionPeriod,
      expectedDeletionDate: expectedDeletionDate ?? this.expectedDeletionDate,
      involvedAutomatedDecision:
          involvedAutomatedDecision ?? this.involvedAutomatedDecision,
      automatedDecisionDetails:
          automatedDecisionDetails ?? this.automatedDecisionDetails,
      transferredOutsideEU: transferredOutsideEU ?? this.transferredOutsideEU,
      internationalTransferDetails:
          internationalTransferDetails ?? this.internationalTransferDetails,
      securityMeasures: securityMeasures ?? this.securityMeasures,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if processing is currently ongoing
  bool get isOngoing => completedAt == null;

  /// Check if processing has completed
  bool get isCompleted => completedAt != null;

  /// Get duration of processing
  Duration get processingDuration {
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(startedAt);
  }

  /// Check if data is due for deletion soon (within specified days)
  bool isDueSoonForDeletion(int days) {
    if (expectedDeletionDate == null) return false;
    final now = DateTime.now();
    final daysUntilDeletion = expectedDeletionDate!.difference(now).inDays;
    return daysUntilDeletion > 0 && daysUntilDeletion <= days;
  }

  /// Check if data should have been deleted already
  bool get isOverdue {
    if (expectedDeletionDate == null) return false;
    return DateTime.now().isAfter(expectedDeletionDate!);
  }

  /// Get compliance risk level (0 = low, 1 = medium, 2 = high)
  int get complianceRiskLevel {
    int risk = 0;

    // High risk factors
    if (dataCategory.isSensitive) risk++;
    if (sharedWithThirdParty) risk++;
    if (transferredOutsideEU) risk++;
    if (isOverdue) risk += 2;

    // Medium risk factors
    if (involvedAutomatedDecision) risk++;
    if (securityMeasures.isEmpty) risk++;
    if (isDueSoonForDeletion(30)) risk++;

    return risk.clamp(0, 2);
  }

  /// Get risk level description
  String get riskLevelDescription {
    switch (complianceRiskLevel) {
      case 0:
        return 'Low Risk';
      case 1:
        return 'Medium Risk';
      case 2:
      default:
        return 'High Risk';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataProcessingRecord && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'DataProcessingRecord(id: $id, category: ${dataCategory.value}, purpose: ${purpose.value})';
  }
}
