/// Data category enumerations for GDPR compliance
library;

/// Categories of personal data processed by the application
enum DataCategory {
  /// Personal identification information
  personalInfo(
    'personal_info',
    'Personal Information',
    'Name, email, user preferences, and account details',
  ),

  /// Audio recordings and voice data
  audioData(
    'audio_data',
    'Audio Recordings',
    'Voice recordings, meeting audio, and related metadata',
  ),

  /// Transcribed text content
  transcriptionData(
    'transcription_data',
    'Transcription Data',
    'Text transcriptions, meeting notes, and processed content',
  ),

  /// AI-generated summaries and insights
  summaryData(
    'summary_data',
    'Summary Data',
    'AI-generated summaries, key points, and meeting insights',
  ),

  /// Device and technical information
  deviceData(
    'device_data',
    'Device Information',
    'Device identifiers, OS version, app version, and technical specs',
  ),

  /// Usage patterns and analytics
  usageData(
    'usage_data',
    'Usage Analytics',
    'App usage patterns, feature interactions, and performance metrics',
  ),

  /// Location and context data
  locationData(
    'location_data',
    'Location Data',
    'GPS coordinates, timezone information, and location context',
  ),

  /// File system and storage data
  fileSystemData(
    'file_system_data',
    'File System Data',
    'File paths, storage locations, and organization metadata',
  ),

  /// Crash reports and error logs
  diagnosticData(
    'diagnostic_data',
    'Diagnostic Data',
    'Crash reports, error logs, and debugging information',
  ),

  /// Communication and sharing data
  communicationData(
    'communication_data',
    'Communication Data',
    'Shared content, export history, and collaboration metadata',
  ),

  /// Third-party service data
  thirdPartyData(
    'third_party_data',
    'Third-party Data',
    'Data from integrated services and external APIs',
  ),

  /// Biometric authentication data
  biometricData(
    'biometric_data',
    'Biometric Data',
    'Fingerprint, face recognition, and other biometric identifiers',
  );

  const DataCategory(this.value, this.displayName, this.description);

  /// String value for database storage
  final String value;

  /// Human-readable display name
  final String displayName;

  /// Description of what data this category includes
  final String description;

  /// Create DataCategory from string value
  static DataCategory fromString(String value) {
    return DataCategory.values.firstWhere(
      (category) => category.value == value,
      orElse: () => DataCategory.personalInfo,
    );
  }

  /// Get all data categories
  static List<DataCategory> get allCategories => DataCategory.values;

  /// Get categories that are considered sensitive under GDPR
  static List<DataCategory> get sensitiveCategories => [
    DataCategory.audioData,
    DataCategory.biometricData,
    DataCategory.locationData,
    DataCategory.personalInfo,
  ];

  /// Get categories that are technical/operational
  static List<DataCategory> get technicalCategories => [
    DataCategory.deviceData,
    DataCategory.diagnosticData,
    DataCategory.fileSystemData,
  ];

  /// Get categories related to content processing
  static List<DataCategory> get contentCategories => [
    DataCategory.audioData,
    DataCategory.transcriptionData,
    DataCategory.summaryData,
    DataCategory.communicationData,
  ];

  /// Check if this category contains sensitive personal data
  bool get isSensitive => sensitiveCategories.contains(this);

  /// Check if this category is technical/operational data
  bool get isTechnical => technicalCategories.contains(this);

  /// Check if this category relates to content processing
  bool get isContent => contentCategories.contains(this);

  @override
  String toString() => value;
}

/// Purpose for data processing under GDPR
enum ProcessingPurpose {
  /// Core app functionality
  coreService(
    'core_service',
    'Core Service Delivery',
    'Essential functions required for app operation',
  ),

  /// Performance improvement and optimization
  performance(
    'performance',
    'Performance Optimization',
    'Improve app performance and user experience',
  ),

  /// Analytics and usage insights
  analytics(
    'analytics',
    'Analytics & Insights',
    'Understand usage patterns and improve features',
  ),

  /// Marketing and communications
  marketing(
    'marketing',
    'Marketing Communications',
    'Send relevant updates and promotional content',
  ),

  /// Legal compliance and obligations
  legalCompliance(
    'legal_compliance',
    'Legal Compliance',
    'Meet legal requirements and regulatory obligations',
  ),

  /// Security and fraud prevention
  security(
    'security',
    'Security & Fraud Prevention',
    'Protect against security threats and fraudulent activity',
  ),

  /// Customer support and assistance
  support(
    'support',
    'Customer Support',
    'Provide technical support and customer assistance',
  ),

  /// Research and development
  research(
    'research',
    'Research & Development',
    'Improve products and develop new features',
  ),

  /// Data backup and recovery
  backup(
    'backup',
    'Backup & Recovery',
    'Ensure data safety and enable recovery capabilities',
  ),

  /// Third-party integrations
  thirdPartyIntegration(
    'third_party_integration',
    'Third-party Integration',
    'Enable functionality through external service partnerships',
  );

  const ProcessingPurpose(this.value, this.displayName, this.description);

  /// String value for database storage
  final String value;

  /// Human-readable display name
  final String displayName;

  /// Description of the processing purpose
  final String description;

  /// Create ProcessingPurpose from string value
  static ProcessingPurpose fromString(String value) {
    return ProcessingPurpose.values.firstWhere(
      (purpose) => purpose.value == value,
      orElse: () => ProcessingPurpose.coreService,
    );
  }

  /// Get all processing purposes
  static List<ProcessingPurpose> get allPurposes => ProcessingPurpose.values;

  /// Get purposes that are essential for app functionality
  static List<ProcessingPurpose> get essentialPurposes => [
    ProcessingPurpose.coreService,
    ProcessingPurpose.security,
    ProcessingPurpose.legalCompliance,
  ];

  /// Get purposes that are optional/enhancement-related
  static List<ProcessingPurpose> get optionalPurposes => [
    ProcessingPurpose.analytics,
    ProcessingPurpose.marketing,
    ProcessingPurpose.performance,
    ProcessingPurpose.research,
  ];

  /// Check if this purpose is essential for app functionality
  bool get isEssential => essentialPurposes.contains(this);

  /// Check if this purpose is optional
  bool get isOptional => !isEssential;

  @override
  String toString() => value;
}
