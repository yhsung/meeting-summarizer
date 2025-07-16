/// Factory for creating transcription service instances
library;

import 'package:flutter/foundation.dart';

import 'transcription_service_interface.dart';
import 'openai_whisper_service.dart';
import 'local_whisper_service.dart';
import 'google_speech_service.dart';
import 'anthropic_transcription_service.dart';
import 'api_key_service.dart';

/// Available transcription service providers
enum TranscriptionProvider {
  openaiWhisper,
  localWhisper,
  googleSpeechToText,
  anthropicTranscription,
  // Future providers can be added here:
  // azureSpeech,
  // awsTranscribe,
}

/// Factory for creating transcription service instances
class TranscriptionServiceFactory {
  static final Map<TranscriptionProvider, TranscriptionServiceInterface>
  _instances = {};
  static final ApiKeyService _apiKeyService = ApiKeyService();

  /// Get a transcription service instance
  ///
  /// [provider] - The transcription service provider to use
  /// [forceNew] - Whether to create a new instance (default: false, uses singleton)
  ///
  /// Returns the transcription service instance
  static TranscriptionServiceInterface getService(
    TranscriptionProvider provider, {
    bool forceNew = false,
  }) {
    if (forceNew || !_instances.containsKey(provider)) {
      _instances[provider] = _createService(provider);
    }

    return _instances[provider]!;
  }

  /// Get the default transcription service
  ///
  /// Returns the OpenAI Whisper service as the default implementation
  static TranscriptionServiceInterface getDefaultService() {
    return getService(TranscriptionProvider.openaiWhisper);
  }

  /// Get an available transcription service
  ///
  /// Checks which services are configured and returns the first available one
  ///
  /// Returns the first available service or throws if none are available
  static Future<TranscriptionServiceInterface> getAvailableService() async {
    // Check OpenAI Whisper first (primary provider)
    final whisperService = getService(TranscriptionProvider.openaiWhisper);
    if (await whisperService.isServiceAvailable()) {
      debugPrint('TranscriptionServiceFactory: Using OpenAI Whisper service');
      return whisperService;
    }

    // Fallback to local Whisper if API is unavailable
    final localService = getService(TranscriptionProvider.localWhisper);
    if (await localService.isServiceAvailable()) {
      debugPrint(
        'TranscriptionServiceFactory: Using Local Whisper service as fallback',
      );
      return localService;
    }

    throw StateError('No transcription services are available or configured');
  }

  /// Get the best available service based on requirements
  ///
  /// [requiresHighQuality] - Whether high quality transcription is required
  /// [requiresTimestamps] - Whether timestamp support is required
  /// [requiresSpeakerDiarization] - Whether speaker identification is required
  /// [preferredLanguage] - Preferred language for transcription
  ///
  /// Returns the best matching service
  static Future<TranscriptionServiceInterface> getBestAvailableService({
    bool requiresHighQuality = false,
    bool requiresTimestamps = false,
    bool requiresSpeakerDiarization = false,
    String? preferredLanguage,
  }) async {
    debugPrint(
      'TranscriptionServiceFactory: Finding best service for requirements',
    );

    // For now, only OpenAI Whisper is available
    // In the future, this could rank services based on capabilities
    final whisperService = getService(TranscriptionProvider.openaiWhisper);

    if (await whisperService.isServiceAvailable()) {
      debugPrint(
        'TranscriptionServiceFactory: Selected OpenAI Whisper service',
      );
      return whisperService;
    }

    throw StateError(
      'No suitable transcription service available for requirements',
    );
  }

  /// Check which services are configured
  ///
  /// Returns a map of providers to their availability status
  static Future<Map<TranscriptionProvider, bool>>
  checkServiceAvailability() async {
    final availability = <TranscriptionProvider, bool>{};

    for (final provider in TranscriptionProvider.values) {
      try {
        final service = getService(provider);
        availability[provider] = await service.isServiceAvailable();
      } catch (e) {
        debugPrint('TranscriptionServiceFactory: Error checking $provider: $e');
        availability[provider] = false;
      }
    }

    return availability;
  }

  /// Get service capabilities
  ///
  /// [provider] - The provider to get capabilities for
  ///
  /// Returns the capabilities of the specified service
  static ServiceCapabilities getServiceCapabilities(
    TranscriptionProvider provider,
  ) {
    switch (provider) {
      case TranscriptionProvider.openaiWhisper:
        return ServiceCapabilities(
          supportsTimestamps: true,
          supportsWordLevelTimestamps: true,
          supportsSpeakerDiarization:
              false, // OpenAI Whisper doesn't support this natively
          supportsCustomVocabulary: true,
          supportsLanguageDetection: true,
          maxFileSizeMB: 25,
          supportedFormats: ['mp3', 'mp4', 'm4a', 'wav', 'webm', 'flac'],
          supportedLanguages: 95, // Whisper supports 95+ languages
          qualityLevels: ['fast', 'balanced', 'high'],
          averageProcessingSpeed: 1.5, // Roughly 1.5x real-time
          costPerMinute: 0.006, // $0.006 per minute as of 2024
        );
      case TranscriptionProvider.localWhisper:
        return ServiceCapabilities(
          supportsTimestamps: true,
          supportsWordLevelTimestamps: false, // Local implementation limitation
          supportsSpeakerDiarization: false,
          supportsCustomVocabulary: false, // Local implementation limitation
          supportsLanguageDetection: true,
          maxFileSizeMB: 100, // More generous for local processing
          supportedFormats: ['mp3', 'wav', 'm4a', 'flac', 'ogg'],
          supportedLanguages: 50, // Depends on model
          qualityLevels: ['tiny', 'base', 'small'],
          averageProcessingSpeed: 2.0, // Varies by model and hardware
          costPerMinute: 0.0, // Free local processing
        );
      case TranscriptionProvider.googleSpeechToText:
        return ServiceCapabilities(
          supportsTimestamps: true,
          supportsWordLevelTimestamps: true,
          supportsSpeakerDiarization:
              true, // Google supports speaker diarization
          supportsCustomVocabulary: true,
          supportsLanguageDetection: true,
          maxFileSizeMB: 1000, // Large file support
          supportedFormats: ['wav', 'flac', 'mp3', 'ogg', 'webm'],
          supportedLanguages: 125, // Google supports 125+ languages
          qualityLevels: ['standard', 'enhanced', 'premium'],
          averageProcessingSpeed: 1.2, // Very fast processing
          costPerMinute: 0.016, // $0.016 per minute for standard model
        );
      case TranscriptionProvider.anthropicTranscription:
        return ServiceCapabilities(
          supportsTimestamps: true,
          supportsWordLevelTimestamps: false, // Conceptual implementation
          supportsSpeakerDiarization: false,
          supportsCustomVocabulary: true,
          supportsLanguageDetection: true,
          maxFileSizeMB: 100,
          supportedFormats: ['wav', 'mp3', 'm4a', 'flac'],
          supportedLanguages: 50, // Claude supports many languages
          qualityLevels: ['standard', 'enhanced'],
          averageProcessingSpeed: 1.8, // Good processing speed
          costPerMinute: 0.003, // Estimated competitive pricing
        );
    }
  }

  /// Dispose all service instances
  static Future<void> disposeAll() async {
    debugPrint('TranscriptionServiceFactory: Disposing all service instances');

    for (final service in _instances.values) {
      try {
        await service.dispose();
      } catch (e) {
        debugPrint('TranscriptionServiceFactory: Error disposing service: $e');
      }
    }

    _instances.clear();
  }

  /// Create a service instance for the specified provider
  static TranscriptionServiceInterface _createService(
    TranscriptionProvider provider,
  ) {
    debugPrint('TranscriptionServiceFactory: Creating service for $provider');

    switch (provider) {
      case TranscriptionProvider.openaiWhisper:
        return OpenAIWhisperService(apiKeyService: _apiKeyService);
      case TranscriptionProvider.localWhisper:
        return LocalWhisperService.getInstance();
      case TranscriptionProvider.googleSpeechToText:
        return GoogleSpeechService(apiKeyService: _apiKeyService);
      case TranscriptionProvider.anthropicTranscription:
        return AnthropicTranscriptionService(apiKeyService: _apiKeyService);
    }
  }

  /// Get provider display name
  static String getProviderDisplayName(TranscriptionProvider provider) {
    switch (provider) {
      case TranscriptionProvider.openaiWhisper:
        return 'OpenAI Whisper';
      case TranscriptionProvider.localWhisper:
        return 'Local Whisper';
      case TranscriptionProvider.googleSpeechToText:
        return 'Google Speech-to-Text';
      case TranscriptionProvider.anthropicTranscription:
        return 'Anthropic Claude';
    }
  }

  /// Get provider description
  static String getProviderDescription(TranscriptionProvider provider) {
    switch (provider) {
      case TranscriptionProvider.openaiWhisper:
        return 'High-quality speech recognition using OpenAI\'s Whisper model. '
            'Supports 95+ languages with excellent accuracy.';
      case TranscriptionProvider.localWhisper:
        return 'Offline speech recognition using local Whisper models. '
            'No internet required, free processing with configurable quality levels.';
      case TranscriptionProvider.googleSpeechToText:
        return 'Enterprise-grade speech recognition from Google Cloud. '
            'Supports 125+ languages with advanced features like speaker diarization.';
      case TranscriptionProvider.anthropicTranscription:
        return 'AI-powered transcription using Anthropic\'s Claude models. '
            'Focuses on contextual understanding and intelligent processing.';
    }
  }

  /// Create a transcription service instance using the default provider
  static TranscriptionServiceInterface create() {
    return getDefaultService();
  }

  /// Get the API key service instance
  static ApiKeyService get apiKeyService => _apiKeyService;
}

/// Capabilities of a transcription service
class ServiceCapabilities {
  final bool supportsTimestamps;
  final bool supportsWordLevelTimestamps;
  final bool supportsSpeakerDiarization;
  final bool supportsCustomVocabulary;
  final bool supportsLanguageDetection;
  final int maxFileSizeMB;
  final List<String> supportedFormats;
  final int supportedLanguages;
  final List<String> qualityLevels;
  final double
  averageProcessingSpeed; // Multiplier of real-time (1.0 = real-time)
  final double costPerMinute; // Cost in USD per minute

  const ServiceCapabilities({
    required this.supportsTimestamps,
    required this.supportsWordLevelTimestamps,
    required this.supportsSpeakerDiarization,
    required this.supportsCustomVocabulary,
    required this.supportsLanguageDetection,
    required this.maxFileSizeMB,
    required this.supportedFormats,
    required this.supportedLanguages,
    required this.qualityLevels,
    required this.averageProcessingSpeed,
    required this.costPerMinute,
  });

  /// Get estimated processing time for audio duration
  Duration getEstimatedProcessingTime(Duration audioDuration) {
    final processingSeconds = audioDuration.inSeconds / averageProcessingSpeed;
    return Duration(seconds: processingSeconds.round());
  }

  /// Get estimated cost for audio duration
  double getEstimatedCost(Duration audioDuration) {
    final minutes = audioDuration.inMinutes;
    return minutes * costPerMinute;
  }

  /// Check if file format is supported
  bool isFormatSupported(String format) {
    return supportedFormats.contains(format.toLowerCase());
  }

  /// Check if file size is within limits
  bool isFileSizeSupported(int fileSizeBytes) {
    final fileSizeMB = fileSizeBytes / (1024 * 1024);
    return fileSizeMB <= maxFileSizeMB;
  }

  Map<String, dynamic> toJson() {
    return {
      'supports_timestamps': supportsTimestamps,
      'supports_word_level_timestamps': supportsWordLevelTimestamps,
      'supports_speaker_diarization': supportsSpeakerDiarization,
      'supports_custom_vocabulary': supportsCustomVocabulary,
      'supports_language_detection': supportsLanguageDetection,
      'max_file_size_mb': maxFileSizeMB,
      'supported_formats': supportedFormats,
      'supported_languages': supportedLanguages,
      'quality_levels': qualityLevels,
      'average_processing_speed': averageProcessingSpeed,
      'cost_per_minute': costPerMinute,
    };
  }

  @override
  String toString() {
    return 'ServiceCapabilities('
        'timestamps: $supportsTimestamps, '
        'speaker_diarization: $supportsSpeakerDiarization, '
        'languages: $supportedLanguages, '
        'max_size: ${maxFileSizeMB}MB'
        ')';
  }
}
