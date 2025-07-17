/// Service for persisting transcription settings
library;

import 'dart:developer';

import '../models/transcription_request.dart';
import '../services/transcription_service_factory.dart';
import '../../features/audio_recording/presentation/widgets/transcription_settings_dialog.dart';

/// Service for managing transcription settings persistence
class TranscriptionSettingsService {
  static TranscriptionSettingsService? _instance;
  TranscriptionSettings? _cachedSettings;

  TranscriptionSettingsService._();

  /// Get singleton instance
  static TranscriptionSettingsService get instance {
    _instance ??= TranscriptionSettingsService._();
    return _instance!;
  }

  /// Initialize the service
  Future<void> initialize() async {
    // For now, we'll use in-memory storage
    // In a real app, this could be enhanced with local storage
    _cachedSettings = _getDefaultSettings();
  }

  /// Save transcription settings
  Future<void> saveSettings(TranscriptionSettings settings) async {
    _cachedSettings = settings;
    log('TranscriptionSettingsService: Settings saved - $settings');
  }

  /// Load transcription settings
  Future<TranscriptionSettings> loadSettings() async {
    return _cachedSettings ?? _getDefaultSettings();
  }

  /// Get default settings
  TranscriptionSettings _getDefaultSettings() {
    return const TranscriptionSettings(
      provider: TranscriptionProvider.openaiWhisper,
      quality: TranscriptionQuality.balanced,
      language: null, // Auto-detect
      enableTimestamps: true,
      enableSpeakerDiarization: false,
      customPrompt: null,
    );
  }

  /// Reset settings to default
  Future<void> resetSettings() async {
    _cachedSettings = _getDefaultSettings();
    log('TranscriptionSettingsService: Settings reset to defaults');
  }

  /// Check if settings exist
  Future<bool> hasSettings() async {
    return _cachedSettings != null;
  }

  /// Get current settings or default if none exist
  Future<TranscriptionSettings> getCurrentSettings() async {
    if (await hasSettings()) {
      return loadSettings();
    } else {
      return _getDefaultSettings();
    }
  }

  /// Validate settings against service availability
  Future<TranscriptionSettings> validateSettings(
    TranscriptionSettings settings,
  ) async {
    // Check if the selected provider is available
    final availability =
        await TranscriptionServiceFactory.checkServiceAvailability();
    final isProviderAvailable = availability[settings.provider] ?? false;

    if (!isProviderAvailable) {
      log(
        'TranscriptionSettingsService: Provider ${settings.provider} not available, falling back to default',
      );

      // Find first available provider
      final availableProvider = availability.entries
          .firstWhere(
            (entry) => entry.value,
            orElse: () => MapEntry(TranscriptionProvider.openaiWhisper, false),
          )
          .key;

      return settings.copyWith(provider: availableProvider);
    }

    // Validate capabilities
    final capabilities = TranscriptionServiceFactory.getServiceCapabilities(
      settings.provider,
    );

    TranscriptionSettings validatedSettings = settings;

    // Disable features not supported by provider
    if (!capabilities.supportsTimestamps && settings.enableTimestamps) {
      log(
        'TranscriptionSettingsService: Timestamps not supported by ${settings.provider}, disabling',
      );
      validatedSettings = validatedSettings.copyWith(enableTimestamps: false);
    }

    if (!capabilities.supportsSpeakerDiarization &&
        settings.enableSpeakerDiarization) {
      log(
        'TranscriptionSettingsService: Speaker diarization not supported by ${settings.provider}, disabling',
      );
      validatedSettings = validatedSettings.copyWith(
        enableSpeakerDiarization: false,
      );
    }

    if (!capabilities.supportsCustomVocabulary &&
        settings.customPrompt != null) {
      log(
        'TranscriptionSettingsService: Custom vocabulary not supported by ${settings.provider}, removing prompt',
      );
      validatedSettings = validatedSettings.copyWith(customPrompt: null);
    }

    return validatedSettings;
  }

  /// Get estimated cost for transcription based on settings
  Future<double> getEstimatedCost(
    Duration audioDuration,
    TranscriptionSettings settings,
  ) async {
    final capabilities = TranscriptionServiceFactory.getServiceCapabilities(
      settings.provider,
    );
    return capabilities.getEstimatedCost(audioDuration);
  }

  /// Get estimated processing time based on settings
  Future<Duration> getEstimatedProcessingTime(
    Duration audioDuration,
    TranscriptionSettings settings,
  ) async {
    final capabilities = TranscriptionServiceFactory.getServiceCapabilities(
      settings.provider,
    );
    return capabilities.getEstimatedProcessingTime(audioDuration);
  }
}
