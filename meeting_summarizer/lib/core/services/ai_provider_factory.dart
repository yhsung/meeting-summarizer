/// Factory for creating AI provider implementations
library;

import 'package:flutter/foundation.dart';

import 'ai_summarization_service_interface.dart';
import '../exceptions/summarization_exceptions.dart';

/// Supported AI providers for summarization
enum AIProvider {
  openai('openai', 'OpenAI'),
  anthropic('anthropic', 'Anthropic Claude'),
  google('google', 'Google Gemini'),
  azure('azure', 'Azure OpenAI'),
  local('local', 'Local Model'),
  mock('mock', 'Mock Provider');

  const AIProvider(this.id, this.displayName);

  final String id;
  final String displayName;

  static AIProvider fromString(String value) {
    return AIProvider.values.firstWhere(
      (provider) => provider.id == value.toLowerCase(),
      orElse: () => AIProvider.openai,
    );
  }
}

/// Configuration for AI provider instances
class AIProviderConfig {
  final AIProvider provider;
  final String? apiKey;
  final String? baseUrl;
  final String? model;
  final Map<String, dynamic> parameters;
  final Duration timeout;
  final int maxRetries;

  const AIProviderConfig({
    required this.provider,
    this.apiKey,
    this.baseUrl,
    this.model,
    this.parameters = const {},
    this.timeout = const Duration(seconds: 60),
    this.maxRetries = 3,
  });

  /// Create configuration for OpenAI
  factory AIProviderConfig.openai({
    required String apiKey,
    String model = 'gpt-3.5-turbo',
    String? baseUrl,
    Map<String, dynamic> parameters = const {},
    Duration timeout = const Duration(seconds: 60),
    int maxRetries = 3,
  }) {
    return AIProviderConfig(
      provider: AIProvider.openai,
      apiKey: apiKey,
      model: model,
      baseUrl: baseUrl ?? 'https://api.openai.com/v1',
      parameters: parameters,
      timeout: timeout,
      maxRetries: maxRetries,
    );
  }

  /// Create configuration for Anthropic Claude
  factory AIProviderConfig.anthropic({
    required String apiKey,
    String model = 'claude-3-sonnet-20240229',
    String? baseUrl,
    Map<String, dynamic> parameters = const {},
    Duration timeout = const Duration(seconds: 60),
    int maxRetries = 3,
  }) {
    return AIProviderConfig(
      provider: AIProvider.anthropic,
      apiKey: apiKey,
      model: model,
      baseUrl: baseUrl ?? 'https://api.anthropic.com',
      parameters: parameters,
      timeout: timeout,
      maxRetries: maxRetries,
    );
  }

  /// Create configuration for Google Gemini
  factory AIProviderConfig.google({
    required String apiKey,
    String model = 'gemini-pro',
    String? baseUrl,
    Map<String, dynamic> parameters = const {},
    Duration timeout = const Duration(seconds: 60),
    int maxRetries = 3,
  }) {
    return AIProviderConfig(
      provider: AIProvider.google,
      apiKey: apiKey,
      model: model,
      baseUrl: baseUrl ?? 'https://generativelanguage.googleapis.com/v1',
      parameters: parameters,
      timeout: timeout,
      maxRetries: maxRetries,
    );
  }

  /// Create configuration for Azure OpenAI
  factory AIProviderConfig.azure({
    required String apiKey,
    required String baseUrl,
    required String model,
    Map<String, dynamic> parameters = const {},
    Duration timeout = const Duration(seconds: 60),
    int maxRetries = 3,
  }) {
    return AIProviderConfig(
      provider: AIProvider.azure,
      apiKey: apiKey,
      model: model,
      baseUrl: baseUrl,
      parameters: parameters,
      timeout: timeout,
      maxRetries: maxRetries,
    );
  }

  /// Create configuration for local model
  factory AIProviderConfig.local({
    required String baseUrl,
    String model = 'local-model',
    Map<String, dynamic> parameters = const {},
    Duration timeout = const Duration(seconds: 120),
    int maxRetries = 2,
  }) {
    return AIProviderConfig(
      provider: AIProvider.local,
      model: model,
      baseUrl: baseUrl,
      parameters: parameters,
      timeout: timeout,
      maxRetries: maxRetries,
    );
  }

  /// Create configuration for mock provider (testing)
  factory AIProviderConfig.mock({Map<String, dynamic> parameters = const {}}) {
    return const AIProviderConfig(
      provider: AIProvider.mock,
      model: 'mock-model',
      timeout: Duration(seconds: 1),
      maxRetries: 1,
    );
  }

  /// Validate configuration
  bool get isValid {
    switch (provider) {
      case AIProvider.openai:
      case AIProvider.anthropic:
      case AIProvider.google:
        return apiKey != null && apiKey!.isNotEmpty;
      case AIProvider.azure:
        return apiKey != null &&
            apiKey!.isNotEmpty &&
            baseUrl != null &&
            baseUrl!.isNotEmpty;
      case AIProvider.local:
        return baseUrl != null && baseUrl!.isNotEmpty;
      case AIProvider.mock:
        return true;
    }
  }

  /// Get validation errors
  List<String> get validationErrors {
    final errors = <String>[];

    switch (provider) {
      case AIProvider.openai:
      case AIProvider.anthropic:
      case AIProvider.google:
        if (apiKey == null || apiKey!.isEmpty) {
          errors.add('API key is required for ${provider.displayName}');
        }
        break;
      case AIProvider.azure:
        if (apiKey == null || apiKey!.isEmpty) {
          errors.add('API key is required for Azure OpenAI');
        }
        if (baseUrl == null || baseUrl!.isEmpty) {
          errors.add('Base URL is required for Azure OpenAI');
        }
        break;
      case AIProvider.local:
        if (baseUrl == null || baseUrl!.isEmpty) {
          errors.add('Base URL is required for local model');
        }
        break;
      case AIProvider.mock:
        break;
    }

    if (timeout.inSeconds <= 0) {
      errors.add('Timeout must be greater than 0');
    }

    if (maxRetries < 0) {
      errors.add('Max retries cannot be negative');
    }

    return errors;
  }

  @override
  String toString() {
    return 'AIProviderConfig(provider: ${provider.id}, model: $model)';
  }
}

/// Factory for creating AI summarization service instances
class AIProviderFactory {
  static final Map<
    AIProvider,
    AISummarizationServiceInterface Function(AIProviderConfig)
  >
  _providers = {};

  /// Register a provider implementation
  static void registerProvider(
    AIProvider provider,
    AISummarizationServiceInterface Function(AIProviderConfig) factory,
  ) {
    _providers[provider] = factory;
    debugPrint('AIProviderFactory: Registered provider ${provider.id}');
  }

  /// Create a summarization service instance
  static AISummarizationServiceInterface createService(
    AIProviderConfig config,
  ) {
    // Validate configuration
    if (!config.isValid) {
      throw SummarizationExceptions.invalidConfiguration(
        config.validationErrors,
        additionalMessage: 'Invalid provider configuration',
      );
    }

    // Get provider factory
    final factory = _providers[config.provider];
    if (factory == null) {
      // Return mock service in debug mode for development
      if (kDebugMode && config.provider != AIProvider.mock) {
        debugPrint(
          'AIProviderFactory: Provider ${config.provider.id} not registered, '
          'returning mock service for development',
        );
        return _createMockService();
      }

      throw SummarizationExceptions.initializationFailed(
        'Provider ${config.provider.id} is not registered',
      );
    }

    try {
      final service = factory(config);
      debugPrint(
        'AIProviderFactory: Created service for provider ${config.provider.id}',
      );
      return service;
    } catch (e, stackTrace) {
      throw SummarizationExceptions.initializationFailed(
        'Failed to create service for provider ${config.provider.id}: $e',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Create service with fallback providers
  static AISummarizationServiceInterface createServiceWithFallback(
    List<AIProviderConfig> configs,
  ) {
    if (configs.isEmpty) {
      throw SummarizationExceptions.invalidConfiguration([
        'At least one provider configuration is required',
      ]);
    }

    final validConfigs = configs.where((config) => config.isValid).toList();
    if (validConfigs.isEmpty) {
      throw SummarizationExceptions.invalidConfiguration([
        'No valid provider configurations found',
      ]);
    }

    // For now, just use the first valid config
    // TODO: Implement proper fallback chain
    return createService(validConfigs.first);
  }

  /// Get available providers
  static List<AIProvider> get availableProviders {
    return _providers.keys.toList();
  }

  /// Check if provider is available
  static bool isProviderAvailable(AIProvider provider) {
    return _providers.containsKey(provider);
  }

  /// Get provider capabilities
  static ServiceCapabilities? getProviderCapabilities(AIProvider provider) {
    // This would be expanded to return actual capabilities
    // For now, return basic capabilities
    switch (provider) {
      case AIProvider.openai:
        return const ServiceCapabilities(
          supportedLanguages: [
            'en',
            'es',
            'fr',
            'de',
            'it',
            'pt',
            'ja',
            'ko',
            'zh',
          ],
          supportedSummaryTypes: [
            'brief',
            'detailed',
            'bullet_points',
            'action_items',
            'executive',
            'meeting_notes',
            'key_highlights',
            'topical',
          ],
          maxInputTokens: 32000,
          maxOutputTokens: 4000,
          supportsStreaming: true,
          supportsActionItems: true,
          supportsDecisionExtraction: true,
          supportsTopicExtraction: true,
          supportsBatchProcessing: false,
        );

      case AIProvider.anthropic:
        return const ServiceCapabilities(
          supportedLanguages: ['en', 'es', 'fr', 'de', 'it', 'pt', 'ja'],
          supportedSummaryTypes: [
            'brief',
            'detailed',
            'bullet_points',
            'action_items',
            'executive',
            'meeting_notes',
            'key_highlights',
            'topical',
          ],
          maxInputTokens: 100000,
          maxOutputTokens: 4000,
          supportsStreaming: true,
          supportsActionItems: true,
          supportsDecisionExtraction: true,
          supportsTopicExtraction: true,
          supportsBatchProcessing: false,
        );

      case AIProvider.google:
        return const ServiceCapabilities(
          supportedLanguages: [
            'en',
            'es',
            'fr',
            'de',
            'it',
            'pt',
            'ja',
            'ko',
            'zh',
          ],
          supportedSummaryTypes: [
            'brief',
            'detailed',
            'bullet_points',
            'action_items',
            'executive',
            'meeting_notes',
            'key_highlights',
          ],
          maxInputTokens: 30000,
          maxOutputTokens: 2000,
          supportsStreaming: false,
          supportsActionItems: true,
          supportsDecisionExtraction: true,
          supportsTopicExtraction: true,
          supportsBatchProcessing: false,
        );

      case AIProvider.azure:
        return const ServiceCapabilities(
          supportedLanguages: [
            'en',
            'es',
            'fr',
            'de',
            'it',
            'pt',
            'ja',
            'ko',
            'zh',
          ],
          supportedSummaryTypes: [
            'brief',
            'detailed',
            'bullet_points',
            'action_items',
            'executive',
            'meeting_notes',
            'key_highlights',
            'topical',
          ],
          maxInputTokens: 32000,
          maxOutputTokens: 4000,
          supportsStreaming: true,
          supportsActionItems: true,
          supportsDecisionExtraction: true,
          supportsTopicExtraction: true,
          supportsBatchProcessing: false,
        );

      case AIProvider.local:
      case AIProvider.mock:
        return const ServiceCapabilities(
          supportedLanguages: ['en'],
          supportedSummaryTypes: ['brief', 'detailed', 'bullet_points'],
          maxInputTokens: 8000,
          maxOutputTokens: 1000,
          supportsStreaming: false,
          supportsActionItems: false,
          supportsDecisionExtraction: false,
          supportsTopicExtraction: false,
          supportsBatchProcessing: false,
        );
    }
  }

  /// Create mock service for testing and development
  static AISummarizationServiceInterface _createMockService() {
    // Import will be added via a separate service registration
    throw SummarizationExceptions.initializationFailed(
      'Mock service must be registered via registerProvider first',
    );
  }

  /// Clear all registered providers (for testing)
  static void clearProviders() {
    _providers.clear();
    debugPrint('AIProviderFactory: Cleared all providers');
  }
}
