/// Service for managing selected transcription provider
library;

import 'dart:developer';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'transcription_service_factory.dart';

/// Service for managing the selected transcription provider
class TranscriptionProviderService {
  static const String _providerKey = 'selected_transcription_provider';
  static const TranscriptionProvider _defaultProvider =
      TranscriptionProvider.openaiWhisper;

  final FlutterSecureStorage _secureStorage;

  TranscriptionProviderService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Get the currently selected transcription provider
  Future<TranscriptionProvider> getSelectedProvider() async {
    try {
      final providerString = await _secureStorage.read(key: _providerKey);

      if (providerString == null) {
        log(
          'TranscriptionProviderService: No provider selected, using default',
        );
        return _defaultProvider;
      }

      final provider = TranscriptionProvider.values.firstWhere(
        (p) => p.name == providerString,
        orElse: () => _defaultProvider,
      );

      log('TranscriptionProviderService: Selected provider: $provider');
      return provider;
    } catch (e) {
      log('TranscriptionProviderService: Error getting provider: $e');
      return _defaultProvider;
    }
  }

  /// Set the selected transcription provider
  Future<void> setSelectedProvider(TranscriptionProvider provider) async {
    try {
      await _secureStorage.write(key: _providerKey, value: provider.name);
      log('TranscriptionProviderService: Provider set to: $provider');
    } catch (e) {
      log('TranscriptionProviderService: Error setting provider: $e');
      rethrow;
    }
  }

  /// Get the default provider
  TranscriptionProvider getDefaultProvider() => _defaultProvider;

  /// Check if a provider is available (has required configuration)
  Future<bool> isProviderAvailable(TranscriptionProvider provider) async {
    try {
      final service = TranscriptionServiceFactory.getService(provider);
      return await service.isServiceAvailable();
    } catch (e) {
      log(
        'TranscriptionProviderService: Error checking provider availability: $e',
      );
      return false;
    }
  }

  /// Get all available providers with their status
  Future<Map<TranscriptionProvider, bool>> getAvailableProviders() async {
    final providers = <TranscriptionProvider, bool>{};

    for (final provider in TranscriptionProvider.values) {
      providers[provider] = await isProviderAvailable(provider);
    }

    return providers;
  }

  /// Get the best available provider based on user selection and availability
  Future<TranscriptionProvider> getBestAvailableProvider() async {
    final selectedProvider = await getSelectedProvider();

    // Check if selected provider is available
    if (await isProviderAvailable(selectedProvider)) {
      log(
        'TranscriptionProviderService: Using selected provider: $selectedProvider',
      );
      return selectedProvider;
    }

    // Fallback to any available provider
    final availableProviders = await getAvailableProviders();
    final availableProvider = availableProviders.entries
        .firstWhere(
          (entry) => entry.value,
          orElse: () => MapEntry(selectedProvider, false),
        )
        .key;

    if (availableProvider != selectedProvider) {
      log(
        'TranscriptionProviderService: Selected provider unavailable, using fallback: $availableProvider',
      );
    }

    return availableProvider;
  }

  /// Clear selected provider (reset to default)
  Future<void> clearSelectedProvider() async {
    try {
      await _secureStorage.delete(key: _providerKey);
      log('TranscriptionProviderService: Provider selection cleared');
    } catch (e) {
      log('TranscriptionProviderService: Error clearing provider: $e');
      rethrow;
    }
  }

  /// Get provider requirements (what's needed to use this provider)
  static Map<String, dynamic> getProviderRequirements(
    TranscriptionProvider provider,
  ) {
    switch (provider) {
      case TranscriptionProvider.openaiWhisper:
        return {
          'api_key_required': true,
          'api_key_provider': 'openai',
          'internet_required': true,
          'local_processing': false,
          'cost_per_minute': 0.006,
          'setup_complexity': 'Easy',
          'setup_instructions': 'Get API key from OpenAI platform',
        };
      case TranscriptionProvider.localWhisper:
        return {
          'api_key_required': false,
          'api_key_provider': null,
          'internet_required': false,
          'local_processing': true,
          'cost_per_minute': 0.0,
          'setup_complexity': 'Medium',
          'setup_instructions': 'Download and configure local Whisper model',
        };
      case TranscriptionProvider.googleSpeechToText:
        return {
          'api_key_required': true,
          'api_key_provider': 'google',
          'internet_required': true,
          'local_processing': false,
          'cost_per_minute': 0.016,
          'setup_complexity': 'Easy',
          'setup_instructions': 'Get API key from Google Cloud Console',
        };
      case TranscriptionProvider.anthropicTranscription:
        return {
          'api_key_required': true,
          'api_key_provider': 'anthropic',
          'internet_required': true,
          'local_processing': false,
          'cost_per_minute': 0.003,
          'setup_complexity': 'Easy',
          'setup_instructions': 'Get API key from Anthropic Console',
        };
    }
  }

  /// Get provider comparison data
  static List<Map<String, dynamic>> getProviderComparison() {
    return TranscriptionProvider.values.map((provider) {
      final capabilities = TranscriptionServiceFactory.getServiceCapabilities(
        provider,
      );
      final requirements = getProviderRequirements(provider);

      return {
        'provider': provider,
        'name': TranscriptionServiceFactory.getProviderDisplayName(provider),
        'description': TranscriptionServiceFactory.getProviderDescription(
          provider,
        ),
        'capabilities': capabilities,
        'requirements': requirements,
        'pros': _getProviderPros(provider),
        'cons': _getProviderCons(provider),
      };
    }).toList();
  }

  static List<String> _getProviderPros(TranscriptionProvider provider) {
    switch (provider) {
      case TranscriptionProvider.openaiWhisper:
        return [
          'High accuracy (95+ languages)',
          'Fast processing (1.5x real-time)',
          'Word-level timestamps',
          'Easy setup',
          'Regular updates',
          'Reliable service',
        ];
      case TranscriptionProvider.localWhisper:
        return [
          'Completely offline',
          'No usage costs',
          'Privacy-focused',
          'No file size limits',
          'No API rate limits',
          'One-time setup',
        ];
      case TranscriptionProvider.googleSpeechToText:
        return [
          'Enterprise-grade accuracy',
          'Speaker diarization support',
          'Large file support (1GB+)',
          'Fastest processing (1.2x real-time)',
          '125+ languages supported',
          'Advanced customization options',
        ];
      case TranscriptionProvider.anthropicTranscription:
        return [
          'Contextual understanding',
          'Intelligent processing',
          'Competitive pricing',
          'Multi-language support',
          'AI-powered accuracy',
          'Future-proof technology',
        ];
    }
  }

  static List<String> _getProviderCons(TranscriptionProvider provider) {
    switch (provider) {
      case TranscriptionProvider.openaiWhisper:
        return [
          'Requires API key',
          'Usage costs (\$0.006/min)',
          'Internet connection required',
          'File size limits (25MB)',
          'API rate limits',
          'Data sent to OpenAI',
        ];
      case TranscriptionProvider.localWhisper:
        return [
          'Complex setup',
          'Requires local model download',
          'Hardware dependent performance',
          'Limited word-level timestamps',
          'Manual model updates',
          'No cloud backup',
        ];
      case TranscriptionProvider.googleSpeechToText:
        return [
          'Requires API key',
          'Higher usage costs (\$0.016/min)',
          'Internet connection required',
          'Google Cloud setup required',
          'Data sent to Google',
          'Complex pricing model',
        ];
      case TranscriptionProvider.anthropicTranscription:
        return [
          'Requires API key',
          'Usage costs (\$0.003/min)',
          'Internet connection required',
          'Conceptual implementation',
          'Limited speaker diarization',
          'Data sent to Anthropic',
        ];
    }
  }
}
