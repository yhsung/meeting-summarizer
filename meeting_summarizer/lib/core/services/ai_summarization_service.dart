/// Main AI summarization service implementation
library;

import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import 'ai_summarization_service_interface.dart';
import 'ai_provider_factory.dart';
import 'mock_ai_summarization_service.dart';
import 'openai_summarization_service.dart';
import 'api_key_service.dart';
import '../models/summarization_configuration.dart';
import '../models/summarization_result.dart';
import '../exceptions/summarization_exceptions.dart';

/// Main AI summarization service that manages providers and configurations
class AISummarizationService implements AISummarizationServiceInterface {
  static AISummarizationService? _instance;
  AISummarizationServiceInterface? _activeService;
  AIProviderConfig? _currentConfig;
  bool _isInitialized = false;

  /// Private constructor for singleton
  AISummarizationService._();

  /// Get singleton instance
  static AISummarizationService get instance {
    _instance ??= AISummarizationService._();
    return _instance!;
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Register providers
      _registerProviders();

      // Try to initialize with a real provider if API keys are available
      final initialized = await _tryInitializeWithRealProvider();

      if (!initialized) {
        // Fall back to mock provider in development
        if (kDebugMode) {
          await _initializeWithMockProvider();
        } else {
          // In production, require real provider
          throw SummarizationExceptions.initializationFailed(
            'No AI provider configured with valid API key',
          );
        }
      }

      _isInitialized = true;
      log('AISummarizationService: Initialized successfully');
    } catch (e, stackTrace) {
      throw SummarizationExceptions.initializationFailed(
        'Service initialization failed: $e',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      await _activeService?.dispose();
      _activeService = null;
      _currentConfig = null;
      _isInitialized = false;
      log('AISummarizationService: Disposed successfully');
    } catch (e) {
      log('AISummarizationService: Error during disposal: $e');
    }
  }

  /// Configure service with specific provider
  Future<void> configureProvider(AIProviderConfig config) async {
    try {
      // Dispose current service if any
      await _activeService?.dispose();

      // Create new service with config
      _activeService = AIProviderFactory.createService(config);
      await _activeService!.initialize();

      _currentConfig = config;
      log('AISummarizationService: Configured with ${config.provider.id}');
    } catch (e, stackTrace) {
      throw SummarizationExceptions.initializationFailed(
        'Provider configuration failed: $e',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<SummarizationResult> generateSummary({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
    String? sessionId,
  }) async {
    _ensureInitialized();

    return await _activeService!.generateSummary(
      transcriptionText: transcriptionText,
      configuration: configuration,
      sessionId: sessionId,
    );
  }

  @override
  Stream<SummarizationResult> generateSummaryStream({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
    String? sessionId,
  }) async* {
    _ensureInitialized();

    yield* _activeService!.generateSummaryStream(
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

    return await _activeService!.extractActionItems(
      text: text,
      context: context,
    );
  }

  @override
  Future<List<KeyDecision>> identifyKeyDecisions({
    required String text,
    String? context,
  }) async {
    _ensureInitialized();

    return await _activeService!.identifyKeyDecisions(
      text: text,
      context: context,
    );
  }

  @override
  Future<List<TopicExtract>> extractTopics({
    required String text,
    int maxTopics = 10,
  }) async {
    _ensureInitialized();

    return await _activeService!.extractTopics(
      text: text,
      maxTopics: maxTopics,
    );
  }

  @override
  Future<Map<String, SummarizationResult>> generateMultipleSummaries({
    required String transcriptionText,
    required List<SummarizationConfiguration> configurations,
    String? sessionId,
  }) async {
    _ensureInitialized();

    return await _activeService!.generateMultipleSummaries(
      transcriptionText: transcriptionText,
      configurations: configurations,
      sessionId: sessionId,
    );
  }

  @override
  Future<ConfigurationValidationResult> validateConfiguration(
    SummarizationConfiguration configuration,
  ) async {
    _ensureInitialized();

    return await _activeService!.validateConfiguration(configuration);
  }

  @override
  ServiceCapabilities get capabilities {
    if (!_isInitialized || _activeService == null) {
      // Return minimal capabilities if not initialized
      return const ServiceCapabilities(
        supportedLanguages: [],
        supportedSummaryTypes: [],
        maxInputTokens: 0,
        maxOutputTokens: 0,
      );
    }

    return _activeService!.capabilities;
  }

  @override
  Future<bool> isReady() async {
    if (!_isInitialized || _activeService == null) {
      return false;
    }

    return await _activeService!.isReady();
  }

  @override
  Future<ServiceHealthStatus> getHealthStatus() async {
    if (!_isInitialized || _activeService == null) {
      return ServiceHealthStatus.unhealthy(
        status: 'not_initialized',
        issues: ['Service not initialized'],
      );
    }

    return await _activeService!.getHealthStatus();
  }

  /// Get current provider configuration
  AIProviderConfig? get currentConfig => _currentConfig;

  /// Get available providers
  List<AIProvider> get availableProviders =>
      AIProviderFactory.availableProviders;

  /// Check if provider is available
  bool isProviderAvailable(AIProvider provider) {
    return AIProviderFactory.isProviderAvailable(provider);
  }

  /// Get provider capabilities
  ServiceCapabilities? getProviderCapabilities(AIProvider provider) {
    return AIProviderFactory.getProviderCapabilities(provider);
  }

  /// Register providers
  void _registerProviders() {
    // Register mock provider for development
    AIProviderFactory.registerProvider(
      AIProvider.mock,
      (config) => MockAISummarizationService(config),
    );

    // Register OpenAI provider
    AIProviderFactory.registerProvider(
      AIProvider.openai,
      (config) => OpenAISummarizationService(config),
    );
  }

  /// Try to initialize with a real provider using available API keys
  Future<bool> _tryInitializeWithRealProvider() async {
    final apiKeyService = ApiKeyService();

    // Try OpenAI first
    try {
      final openaiKey = await apiKeyService.getApiKey('openai');
      if (openaiKey != null && openaiKey.isNotEmpty) {
        final config = AIProviderConfig.openai(apiKey: openaiKey);
        await configureProvider(config);
        log('AISummarizationService: Initialized with OpenAI provider');
        return true;
      }
    } catch (e) {
      log('AISummarizationService: Failed to initialize OpenAI provider: $e');
    }

    // Try Anthropic
    try {
      final anthropicKey = await apiKeyService.getApiKey('anthropic');
      if (anthropicKey != null && anthropicKey.isNotEmpty) {
        final config = AIProviderConfig.anthropic(apiKey: anthropicKey);
        await configureProvider(config);
        log('AISummarizationService: Initialized with Anthropic provider');
        return true;
      }
    } catch (e) {
      log(
        'AISummarizationService: Failed to initialize Anthropic provider: $e',
      );
    }

    // Try Google
    try {
      final googleKey = await apiKeyService.getApiKey('google');
      if (googleKey != null && googleKey.isNotEmpty) {
        final config = AIProviderConfig.google(apiKey: googleKey);
        await configureProvider(config);
        log('AISummarizationService: Initialized with Google provider');
        return true;
      }
    } catch (e) {
      log('AISummarizationService: Failed to initialize Google provider: $e');
    }

    return false;
  }

  /// Initialize with mock provider for development
  Future<void> _initializeWithMockProvider() async {
    final config = AIProviderConfig.mock();
    await configureProvider(config);
  }

  /// Ensure service is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw SummarizationExceptions.serviceUnavailable(
        'Service not initialized. Call initialize() first.',
      );
    }

    if (_activeService == null) {
      throw SummarizationExceptions.serviceUnavailable(
        'No active AI provider configured.',
      );
    }
  }

  /// Create service instance with specific configuration (for testing)
  static Future<AISummarizationService> createWithConfig(
    AIProviderConfig config,
  ) async {
    final service = AISummarizationService._();
    await service.initialize();
    await service.configureProvider(config);
    return service;
  }

  /// Reset singleton instance (for testing)
  static void resetInstance() {
    _instance?.dispose();
    _instance = null;
  }
}
