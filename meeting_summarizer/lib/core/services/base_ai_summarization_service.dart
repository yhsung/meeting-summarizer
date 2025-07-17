/// Base implementation for AI summarization services
library;

import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import 'ai_summarization_service_interface.dart';
import '../models/summarization_configuration.dart';
import '../models/summarization_result.dart';
import '../enums/summary_type.dart';
import '../exceptions/summarization_exceptions.dart';
import 'ai_provider_factory.dart';

/// Abstract base class for AI summarization service implementations
abstract class BaseAISummarizationService
    implements AISummarizationServiceInterface {
  final AIProviderConfig config;
  bool _isInitialized = false;
  bool _isDisposed = false;

  BaseAISummarizationService(this.config);

  /// Provider-specific initialization logic
  @protected
  Future<void> initializeProvider();

  /// Provider-specific disposal logic
  @protected
  Future<void> disposeProvider();

  /// Provider-specific summary generation
  @protected
  Future<SummarizationResult> generateSummaryInternal({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
    String? sessionId,
  });

  /// Provider-specific streaming summary generation (optional)
  @protected
  Stream<SummarizationResult> generateSummaryStreamInternal({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
    String? sessionId,
  }) async* {
    // Default implementation: just yield the regular result
    yield await generateSummaryInternal(
      transcriptionText: transcriptionText,
      configuration: configuration,
      sessionId: sessionId,
    );
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_isDisposed) {
      throw SummarizationExceptions.initializationFailed(
        'Cannot initialize disposed service',
      );
    }

    try {
      await initializeProvider();
      _isInitialized = true;
      log(
        'BaseAISummarizationService: Initialized ${config.provider.id}',
      );
    } catch (e, stackTrace) {
      throw SummarizationExceptions.initializationFailed(
        'Provider initialization failed',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;

    try {
      await disposeProvider();
      _isDisposed = true;
      _isInitialized = false;
      log('BaseAISummarizationService: Disposed ${config.provider.id}');
    } catch (e) {
      log('BaseAISummarizationService: Error during disposal: $e');
    }
  }

  @override
  Future<SummarizationResult> generateSummary({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
    String? sessionId,
  }) async {
    _ensureInitialized();

    // Validate inputs
    final validationResult = await validateConfiguration(configuration);
    if (!validationResult.isValid) {
      throw SummarizationExceptions.invalidConfiguration(
        validationResult.errors,
      );
    }

    // Validate text length
    await _validateTextLength(transcriptionText);

    try {
      final startTime = DateTime.now();

      final result = await generateSummaryInternal(
        transcriptionText: transcriptionText,
        configuration: configuration,
        sessionId: sessionId,
      );

      final processingTime = DateTime.now().difference(startTime);
      log(
        'BaseAISummarizationService: Generated summary in ${processingTime.inMilliseconds}ms',
      );

      return result;
    } catch (e) {
      if (e is SummarizationException) {
        rethrow;
      }
      throw SummarizationExceptions.processingFailed(
        'Summary generation failed: $e',
      );
    }
  }

  @override
  Stream<SummarizationResult> generateSummaryStream({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
    String? sessionId,
  }) async* {
    _ensureInitialized();

    if (!capabilities.supportsStreaming) {
      // Fallback to regular generation for providers that don't support streaming
      yield await generateSummary(
        transcriptionText: transcriptionText,
        configuration: configuration,
        sessionId: sessionId,
      );
      return;
    }

    // Validate inputs
    final validationResult = await validateConfiguration(configuration);
    if (!validationResult.isValid) {
      throw SummarizationExceptions.invalidConfiguration(
        validationResult.errors,
      );
    }

    await _validateTextLength(transcriptionText);

    yield* generateSummaryStreamInternal(
      transcriptionText: transcriptionText,
      configuration: configuration,
      sessionId: sessionId,
    );
  }

  @override
  Future<List<ActionItem>> extractActionItems({
    required String text,
    String? context,
  }) async {
    _ensureInitialized();

    if (!capabilities.supportsActionItems) {
      return [];
    }

    // Create a configuration for action item extraction
    final config = SummarizationConfiguration.actionItemsDefault();

    final result = await generateSummary(
      transcriptionText: text,
      configuration: config,
    );

    return result.actionItems;
  }

  @override
  Future<List<KeyDecision>> identifyKeyDecisions({
    required String text,
    String? context,
  }) async {
    _ensureInitialized();

    if (!capabilities.supportsDecisionExtraction) {
      return [];
    }

    // Create a configuration focused on decisions
    const config = SummarizationConfiguration(
      summaryType: SummaryType.brief,
      summaryFocus: SummaryFocus.decisions,
      identifyDecisions: true,
    );

    final result = await generateSummary(
      transcriptionText: text,
      configuration: config,
    );

    return result.keyDecisions;
  }

  @override
  Future<List<TopicExtract>> extractTopics({
    required String text,
    int maxTopics = 10,
  }) async {
    _ensureInitialized();

    if (!capabilities.supportsTopicExtraction) {
      return [];
    }

    // Create a configuration focused on topics
    const config = SummarizationConfiguration(
      summaryType: SummaryType.topical,
      extractTopics: true,
    );

    final result = await generateSummary(
      transcriptionText: text,
      configuration: config,
    );

    // Limit to requested number of topics
    final topics = result.topics;
    if (topics.length <= maxTopics) {
      return topics;
    }

    // Sort by relevance and take top topics
    topics.sort((a, b) => b.relevance.compareTo(a.relevance));
    return topics.take(maxTopics).toList();
  }

  @override
  Future<Map<String, SummarizationResult>> generateMultipleSummaries({
    required String transcriptionText,
    required List<SummarizationConfiguration> configurations,
    String? sessionId,
  }) async {
    _ensureInitialized();

    if (configurations.isEmpty) {
      throw SummarizationExceptions.invalidConfiguration([
        'At least one configuration is required',
      ]);
    }

    final results = <String, SummarizationResult>{};

    // Process configurations sequentially for now
    // TODO: Implement batch processing for providers that support it
    for (int i = 0; i < configurations.length; i++) {
      final config = configurations[i];
      final key = '${config.summaryType.value}_$i';

      try {
        final result = await generateSummary(
          transcriptionText: transcriptionText,
          configuration: config,
          sessionId: sessionId,
        );
        results[key] = result;
      } catch (e) {
        log(
          'BaseAISummarizationService: Failed to generate summary for config $i: $e',
        );
        // Continue with other configurations
      }
    }

    return results;
  }

  @override
  Future<ConfigurationValidationResult> validateConfiguration(
    SummarizationConfiguration configuration,
  ) async {
    final errors = <String>[];
    final warnings = <String>[];

    // Check if summary type is supported
    if (!capabilities.supportsSummaryType(configuration.summaryType.value)) {
      errors.add(
        'Summary type ${configuration.summaryType.value} is not supported by this provider',
      );
    }

    // Check language support
    if (!capabilities.supportsLanguage(configuration.language)) {
      errors.add(
        'Language ${configuration.language} is not supported by this provider',
      );
    }

    // Check feature support
    if (configuration.extractActionItems && !capabilities.supportsActionItems) {
      warnings.add('Action item extraction is not supported by this provider');
    }

    if (configuration.identifyDecisions &&
        !capabilities.supportsDecisionExtraction) {
      warnings.add('Decision extraction is not supported by this provider');
    }

    if (configuration.extractTopics && !capabilities.supportsTopicExtraction) {
      warnings.add('Topic extraction is not supported by this provider');
    }

    if (configuration.enableStreaming && !capabilities.supportsStreaming) {
      warnings.add('Streaming is not supported by this provider');
    }

    // Check token limits
    final estimatedTokens = _estimateTokenCount(configuration.toString());
    if (estimatedTokens > capabilities.maxOutputTokens) {
      errors.add(
        'Estimated output tokens ($estimatedTokens) exceed provider limit (${capabilities.maxOutputTokens})',
      );
    }

    // Validate temperature range
    if (configuration.temperature < 0.0 || configuration.temperature > 1.0) {
      errors.add('Temperature must be between 0.0 and 1.0');
    }

    return ConfigurationValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  @override
  Future<bool> isReady() async {
    if (!_isInitialized || _isDisposed) {
      return false;
    }

    try {
      final healthStatus = await getHealthStatus();
      return healthStatus.isHealthy;
    } catch (e) {
      log('BaseAISummarizationService: Health check failed: $e');
      return false;
    }
  }

  @override
  Future<ServiceHealthStatus> getHealthStatus() async {
    if (!_isInitialized) {
      return ServiceHealthStatus.unhealthy(
        status: 'not_initialized',
        issues: ['Service not initialized'],
      );
    }

    if (_isDisposed) {
      return ServiceHealthStatus.unhealthy(
        status: 'disposed',
        issues: ['Service has been disposed'],
      );
    }

    // Provider-specific health check would go here
    // For now, return healthy if initialized
    return ServiceHealthStatus.healthy();
  }

  /// Ensure service is initialized
  void _ensureInitialized() {
    if (_isDisposed) {
      throw SummarizationExceptions.serviceUnavailable(
        'Service has been disposed',
      );
    }
    if (!_isInitialized) {
      throw SummarizationExceptions.serviceUnavailable(
        'Service not initialized',
      );
    }
  }

  /// Validate input text length
  Future<void> _validateTextLength(String text) async {
    final estimatedTokens = _estimateTokenCount(text);
    if (estimatedTokens > capabilities.maxInputTokens) {
      throw SummarizationExceptions.tokenLimitExceeded(
        estimatedTokens,
        capabilities.maxInputTokens,
      );
    }
  }

  /// Rough estimation of token count (4 characters ≈ 1 token)
  int _estimateTokenCount(String text) {
    return (text.length / 4).ceil();
  }

  /// Get provider-specific error handling
  @protected
  SummarizationException handleProviderError(dynamic error) {
    if (error is SummarizationException) {
      return error;
    }

    // Default error handling
    return SummarizationExceptions.processingFailed('Provider error: $error');
  }
}
