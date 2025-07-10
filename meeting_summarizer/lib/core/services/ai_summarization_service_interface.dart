/// Interface for AI summarization services
library;

import '../models/summarization_configuration.dart';
import '../models/summarization_result.dart';

/// Abstract interface for AI-powered summarization services
abstract class AISummarizationServiceInterface {
  /// Initialize the summarization service
  Future<void> initialize();

  /// Dispose of service resources
  Future<void> dispose();

  /// Generate a summary from transcribed text
  Future<SummarizationResult> generateSummary({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
    String? sessionId,
  });

  /// Generate a summary with streaming support
  Stream<SummarizationResult> generateSummaryStream({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
    String? sessionId,
  });

  /// Extract action items from text
  Future<List<ActionItem>> extractActionItems({
    required String text,
    String? context,
  });

  /// Identify key decisions from text
  Future<List<KeyDecision>> identifyKeyDecisions({
    required String text,
    String? context,
  });

  /// Extract topics and themes from text
  Future<List<TopicExtract>> extractTopics({
    required String text,
    int maxTopics = 10,
  });

  /// Generate multiple summary types in a single request
  Future<Map<String, SummarizationResult>> generateMultipleSummaries({
    required String transcriptionText,
    required List<SummarizationConfiguration> configurations,
    String? sessionId,
  });

  /// Validate configuration before processing
  Future<ConfigurationValidationResult> validateConfiguration(
    SummarizationConfiguration configuration,
  );

  /// Get service capabilities and limitations
  ServiceCapabilities get capabilities;

  /// Check if service is ready for processing
  Future<bool> isReady();

  /// Get service health status
  Future<ServiceHealthStatus> getHealthStatus();
}

/// Result of configuration validation
class ConfigurationValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final SummarizationConfiguration? suggestedConfiguration;

  const ConfigurationValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.suggestedConfiguration,
  });

  factory ConfigurationValidationResult.valid() {
    return const ConfigurationValidationResult(isValid: true);
  }

  factory ConfigurationValidationResult.invalid({
    required List<String> errors,
    List<String> warnings = const [],
    SummarizationConfiguration? suggestedConfiguration,
  }) {
    return ConfigurationValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings,
      suggestedConfiguration: suggestedConfiguration,
    );
  }

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;
}

/// Service capabilities and limitations
class ServiceCapabilities {
  final List<String> supportedLanguages;
  final List<String> supportedSummaryTypes;
  final int maxInputTokens;
  final int maxOutputTokens;
  final bool supportsStreaming;
  final bool supportsActionItems;
  final bool supportsDecisionExtraction;
  final bool supportsTopicExtraction;
  final bool supportsBatchProcessing;
  final Map<String, dynamic> modelLimitations;

  const ServiceCapabilities({
    required this.supportedLanguages,
    required this.supportedSummaryTypes,
    required this.maxInputTokens,
    required this.maxOutputTokens,
    this.supportsStreaming = false,
    this.supportsActionItems = true,
    this.supportsDecisionExtraction = true,
    this.supportsTopicExtraction = true,
    this.supportsBatchProcessing = false,
    this.modelLimitations = const {},
  });

  bool supportsLanguage(String languageCode) {
    return supportedLanguages.contains(languageCode);
  }

  bool supportsSummaryType(String summaryType) {
    return supportedSummaryTypes.contains(summaryType);
  }
}

/// Service health status
class ServiceHealthStatus {
  final bool isHealthy;
  final String status;
  final Map<String, dynamic> metrics;
  final DateTime lastChecked;
  final List<String> issues;

  const ServiceHealthStatus({
    required this.isHealthy,
    required this.status,
    required this.metrics,
    required this.lastChecked,
    this.issues = const [],
  });

  factory ServiceHealthStatus.healthy() {
    return ServiceHealthStatus(
      isHealthy: true,
      status: 'healthy',
      metrics: {},
      lastChecked: DateTime.now(),
    );
  }

  factory ServiceHealthStatus.unhealthy({
    required String status,
    required List<String> issues,
    Map<String, dynamic> metrics = const {},
  }) {
    return ServiceHealthStatus(
      isHealthy: false,
      status: status,
      metrics: metrics,
      lastChecked: DateTime.now(),
      issues: issues,
    );
  }
}
