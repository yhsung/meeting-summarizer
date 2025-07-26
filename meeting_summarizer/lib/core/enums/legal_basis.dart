/// Legal basis enumerations for GDPR compliance
library;

/// Legal basis for data processing under GDPR Article 6
enum LegalBasis {
  /// Consent - the individual has given clear consent
  consent(
    'consent',
    'Consent',
    'The data subject has given consent to the processing of their personal data',
  ),

  /// Contract - processing is necessary for a contract
  contract(
    'contract',
    'Contract Performance',
    'Processing is necessary for the performance of a contract',
  ),

  /// Legal obligation - compliance with a legal obligation
  legalObligation(
    'legal_obligation',
    'Legal Obligation',
    'Processing is necessary for compliance with a legal obligation',
  ),

  /// Vital interests - protect someone's life
  vitalInterests(
    'vital_interests',
    'Vital Interests',
    'Processing is necessary to protect the vital interests of the data subject',
  ),

  /// Public task - performance of a task in the public interest
  publicTask(
    'public_task',
    'Public Task',
    'Processing is necessary for the performance of a task carried out in the public interest',
  ),

  /// Legitimate interests - legitimate interests of the controller
  legitimateInterests(
    'legitimate_interests',
    'Legitimate Interests',
    'Processing is necessary for the purposes of legitimate interests pursued by the controller',
  );

  const LegalBasis(this.value, this.displayName, this.description);

  /// String value for database storage
  final String value;

  /// Human-readable display name
  final String displayName;

  /// GDPR Article 6 description
  final String description;

  /// Create LegalBasis from string value
  static LegalBasis fromString(String value) {
    return LegalBasis.values.firstWhere(
      (basis) => basis.value == value,
      orElse: () => LegalBasis.consent,
    );
  }

  /// Get all legal bases
  static List<LegalBasis> get allBases => LegalBasis.values;

  /// Get legal bases that require explicit user consent
  static List<LegalBasis> get consentBasedBases => [LegalBasis.consent];

  /// Get legal bases that don't require explicit consent
  static List<LegalBasis> get nonConsentBases => [
        LegalBasis.contract,
        LegalBasis.legalObligation,
        LegalBasis.vitalInterests,
        LegalBasis.publicTask,
        LegalBasis.legitimateInterests,
      ];

  /// Check if this legal basis requires explicit user consent
  bool get requiresConsent => consentBasedBases.contains(this);

  /// Check if this legal basis allows processing without explicit consent
  bool get allowsProcessingWithoutConsent => !requiresConsent;

  @override
  String toString() => value;
}

/// Special categories of personal data under GDPR Article 9
enum SpecialCategoryData {
  /// Racial or ethnic origin
  racialOrigin('racial_origin', 'Racial or Ethnic Origin'),

  /// Political opinions
  politicalOpinions('political_opinions', 'Political Opinions'),

  /// Religious or philosophical beliefs
  religiousBeliefs('religious_beliefs', 'Religious or Philosophical Beliefs'),

  /// Trade union membership
  tradeUnion('trade_union', 'Trade Union Membership'),

  /// Genetic data
  geneticData('genetic_data', 'Genetic Data'),

  /// Biometric data for unique identification
  biometricData('biometric_data', 'Biometric Data'),

  /// Health data
  healthData('health_data', 'Health Data'),

  /// Sex life or sexual orientation
  sexualOrientation('sexual_orientation', 'Sex Life or Sexual Orientation');

  const SpecialCategoryData(this.value, this.displayName);

  /// String value for database storage
  final String value;

  /// Human-readable display name
  final String displayName;

  /// Create SpecialCategoryData from string value
  static SpecialCategoryData fromString(String value) {
    return SpecialCategoryData.values.firstWhere(
      (category) => category.value == value,
      orElse: () => SpecialCategoryData.biometricData,
    );
  }

  /// Get all special categories
  static List<SpecialCategoryData> get allCategories =>
      SpecialCategoryData.values;

  @override
  String toString() => value;
}

/// Data retention periods for GDPR compliance
enum RetentionPeriod {
  /// Immediate deletion (0 days)
  immediate('immediate', 'Immediate', 0),

  /// 30 days retention
  thirtyDays('thirty_days', '30 Days', 30),

  /// 90 days retention
  ninetyDays('ninety_days', '90 Days', 90),

  /// 6 months retention
  sixMonths('six_months', '6 Months', 180),

  /// 1 year retention
  oneYear('one_year', '1 Year', 365),

  /// 2 years retention
  twoYears('two_years', '2 Years', 730),

  /// 5 years retention (legal requirement)
  fiveYears('five_years', '5 Years', 1825),

  /// 7 years retention (legal requirement)
  sevenYears('seven_years', '7 Years', 2555),

  /// Indefinite retention (until user deletion)
  indefinite('indefinite', 'Indefinite', -1);

  const RetentionPeriod(this.value, this.displayName, this.days);

  /// String value for database storage
  final String value;

  /// Human-readable display name
  final String displayName;

  /// Number of days to retain data (-1 for indefinite)
  final int days;

  /// Create RetentionPeriod from string value
  static RetentionPeriod fromString(String value) {
    return RetentionPeriod.values.firstWhere(
      (period) => period.value == value,
      orElse: () => RetentionPeriod.oneYear,
    );
  }

  /// Get all retention periods
  static List<RetentionPeriod> get allPeriods => RetentionPeriod.values;

  /// Get retention periods suitable for different data types
  static List<RetentionPeriod> get shortTermPeriods => [
        RetentionPeriod.immediate,
        RetentionPeriod.thirtyDays,
        RetentionPeriod.ninetyDays,
        RetentionPeriod.sixMonths,
      ];

  static List<RetentionPeriod> get longTermPeriods => [
        RetentionPeriod.oneYear,
        RetentionPeriod.twoYears,
        RetentionPeriod.fiveYears,
        RetentionPeriod.sevenYears,
        RetentionPeriod.indefinite,
      ];

  /// Check if this is a short-term retention period
  bool get isShortTerm => shortTermPeriods.contains(this);

  /// Check if this is a long-term retention period
  bool get isLongTerm => longTermPeriods.contains(this);

  /// Check if this is indefinite retention
  bool get isIndefinite => this == RetentionPeriod.indefinite;

  /// Get the retention date from a given start date
  DateTime? getRetentionDate(DateTime startDate) {
    if (isIndefinite) return null;
    return startDate.add(Duration(days: days));
  }

  @override
  String toString() => value;
}
