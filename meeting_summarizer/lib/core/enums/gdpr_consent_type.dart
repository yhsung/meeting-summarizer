/// GDPR consent type enumerations for privacy compliance
library;

/// Types of consent that can be requested from users under GDPR
enum GDPRConsentType {
  /// Consent for essential app functionality
  essential(
    'essential',
    'Essential Functions',
    'Required for basic app operation and core features',
  ),

  /// Consent for analytics and performance monitoring
  analytics(
    'analytics',
    'Analytics & Performance',
    'Collect usage statistics to improve app performance',
  ),

  /// Consent for marketing communications
  marketing(
    'marketing',
    'Marketing Communications',
    'Send promotional messages and feature announcements',
  ),

  /// Consent for personalization features
  personalization(
    'personalization',
    'Personalization',
    'Customize app experience based on usage patterns',
  ),

  /// Consent for crash reporting and debugging
  crashReporting(
    'crash_reporting',
    'Crash Reporting',
    'Automatically report crashes to improve app stability',
  ),

  /// Consent for third-party integrations
  thirdPartyIntegrations(
    'third_party_integrations',
    'Third-party Services',
    'Enable integrations with external services and APIs',
  ),

  /// Consent for data sharing with partners
  dataSharing(
    'data_sharing',
    'Data Sharing',
    'Share anonymized data with trusted partners for research',
  ),

  /// Consent for AI model training
  aiTraining(
    'ai_training',
    'AI Model Training',
    'Use data to improve AI summarization and transcription models',
  ),

  /// Consent for cloud storage and sync
  cloudStorage(
    'cloud_storage',
    'Cloud Storage & Sync',
    'Store and synchronize data across devices using cloud services',
  ),

  /// Consent for location-based services
  location(
    'location',
    'Location Services',
    'Use location data for meeting context and timezone handling',
  );

  const GDPRConsentType(this.value, this.displayName, this.description);

  /// String value for database storage and API calls
  final String value;

  /// Human-readable display name
  final String displayName;

  /// Description of what this consent covers
  final String description;

  /// Create GDPRConsentType from string value
  static GDPRConsentType fromString(String value) {
    return GDPRConsentType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => GDPRConsentType.essential,
    );
  }

  /// Get all consent types
  static List<GDPRConsentType> get allTypes => GDPRConsentType.values;

  /// Get consent types that are required for basic functionality
  static List<GDPRConsentType> get requiredTypes => [GDPRConsentType.essential];

  /// Get consent types that are optional
  static List<GDPRConsentType> get optionalTypes => [
    GDPRConsentType.analytics,
    GDPRConsentType.marketing,
    GDPRConsentType.personalization,
    GDPRConsentType.crashReporting,
    GDPRConsentType.thirdPartyIntegrations,
    GDPRConsentType.dataSharing,
    GDPRConsentType.aiTraining,
    GDPRConsentType.cloudStorage,
    GDPRConsentType.location,
  ];

  /// Check if this consent type is required for app functionality
  bool get isRequired => requiredTypes.contains(this);

  /// Check if this consent type is optional
  bool get isOptional => !isRequired;

  @override
  String toString() => value;
}

/// Status of consent given by the user
enum ConsentStatus {
  /// Consent not yet requested from user
  notRequested('not_requested', 'Not Requested'),

  /// Consent requested but user hasn't responded
  pending('pending', 'Pending Response'),

  /// User has granted consent
  granted('granted', 'Granted'),

  /// User has denied consent
  denied('denied', 'Denied'),

  /// User has withdrawn previously granted consent
  withdrawn('withdrawn', 'Withdrawn'),

  /// Consent has expired and needs renewal
  expired('expired', 'Expired');

  const ConsentStatus(this.value, this.displayName);

  /// String value for storage
  final String value;

  /// Human-readable display name
  final String displayName;

  /// Create ConsentStatus from string value
  static ConsentStatus fromString(String value) {
    return ConsentStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ConsentStatus.notRequested,
    );
  }

  /// Check if consent is currently active/valid
  bool get isActive => this == ConsentStatus.granted;

  /// Check if consent needs user action
  bool get needsUserAction => [
    ConsentStatus.notRequested,
    ConsentStatus.pending,
    ConsentStatus.expired,
  ].contains(this);

  @override
  String toString() => value;
}
