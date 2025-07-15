/// Transcription service configuration dialog
library;

import 'package:flutter/material.dart';
import '../../../../core/services/transcription_service_factory.dart';
import '../../../../core/models/transcription_request.dart';
import '../../../../core/enums/transcription_language.dart';

/// Dialog for configuring transcription service settings
class TranscriptionSettingsDialog extends StatefulWidget {
  /// Current transcription provider
  final TranscriptionProvider? currentProvider;

  /// Current transcription quality
  final TranscriptionQuality currentQuality;

  /// Current transcription language
  final TranscriptionLanguage? currentLanguage;

  /// Whether to enable timestamps
  final bool enableTimestamps;

  /// Whether to enable speaker diarization
  final bool enableSpeakerDiarization;

  /// Custom prompt for transcription
  final String? customPrompt;

  /// Callback when settings are saved
  final Function(TranscriptionSettings) onSaved;

  const TranscriptionSettingsDialog({
    super.key,
    this.currentProvider,
    required this.currentQuality,
    this.currentLanguage,
    required this.enableTimestamps,
    required this.enableSpeakerDiarization,
    this.customPrompt,
    required this.onSaved,
  });

  @override
  State<TranscriptionSettingsDialog> createState() =>
      _TranscriptionSettingsDialogState();
}

class _TranscriptionSettingsDialogState
    extends State<TranscriptionSettingsDialog> {
  late TranscriptionProvider? _selectedProvider;
  late TranscriptionQuality _selectedQuality;
  late TranscriptionLanguage? _selectedLanguage;
  late bool _enableTimestamps;
  late bool _enableSpeakerDiarization;
  late TextEditingController _promptController;
  late TextEditingController _apiKeyController;

  Map<TranscriptionProvider, bool> _providerAvailability = {};
  final Map<TranscriptionProvider, ServiceCapabilities> _serviceCapabilities =
      {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedProvider = widget.currentProvider;
    _selectedQuality = widget.currentQuality;
    _selectedLanguage = widget.currentLanguage;
    _enableTimestamps = widget.enableTimestamps;
    _enableSpeakerDiarization = widget.enableSpeakerDiarization;
    _promptController = TextEditingController(text: widget.customPrompt ?? '');
    _apiKeyController = TextEditingController();

    _initializeSettings();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  /// Initialize transcription service settings
  Future<void> _initializeSettings() async {
    try {
      // Check service availability
      _providerAvailability =
          await TranscriptionServiceFactory.checkServiceAvailability();

      // Get service capabilities
      for (final provider in TranscriptionProvider.values) {
        _serviceCapabilities[provider] =
            TranscriptionServiceFactory.getServiceCapabilities(provider);
      }

      // Set default provider if none selected
      _selectedProvider ??= _providerAvailability.entries
          .firstWhere(
            (entry) => entry.value,
            orElse: () => MapEntry(TranscriptionProvider.openaiWhisper, false),
          )
          .key;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load transcription services: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Save transcription settings
  void _saveSettings() {
    if (_selectedProvider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a transcription provider'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final settings = TranscriptionSettings(
      provider: _selectedProvider!,
      quality: _selectedQuality,
      language: _selectedLanguage,
      enableTimestamps: _enableTimestamps,
      enableSpeakerDiarization: _enableSpeakerDiarization,
      customPrompt: _promptController.text.trim().isNotEmpty
          ? _promptController.text.trim()
          : null,
    );

    widget.onSaved(settings);
    Navigator.of(context).pop();
  }

  /// Show API key configuration dialog
  Future<void> _showApiKeyDialog(TranscriptionProvider provider) async {
    final apiKeyService = TranscriptionServiceFactory.apiKeyService;
    final currentKey = await apiKeyService.getApiKey(_getApiKeyName(provider));

    _apiKeyController.text = currentKey ?? '';

    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Configure ${_getProviderDisplayName(provider)} API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your ${_getProviderDisplayName(provider)} API key:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'Enter your API key...',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              maxLines: 1,
            ),
            const SizedBox(height: 16),
            Text(
              'This key will be stored securely on your device.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(_apiKeyController.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (mounted && result != null && result.isNotEmpty) {
      try {
        await apiKeyService.setApiKey(_getApiKeyName(provider), result);
        // Refresh availability
        _initializeSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'API key saved for ${_getProviderDisplayName(provider)}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save API key: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Get API key name for provider
  String _getApiKeyName(TranscriptionProvider provider) {
    switch (provider) {
      case TranscriptionProvider.openaiWhisper:
        return 'openai';
      case TranscriptionProvider.localWhisper:
        return 'local'; // Local doesn't need API key
      case TranscriptionProvider.googleSpeechToText:
        return 'google';
      case TranscriptionProvider.anthropicTranscription:
        return 'anthropic';
    }
  }

  /// Get provider display name
  String _getProviderDisplayName(TranscriptionProvider provider) {
    return TranscriptionServiceFactory.getProviderDisplayName(provider);
  }

  /// Get provider description
  String _getProviderDescription(TranscriptionProvider provider) {
    return TranscriptionServiceFactory.getProviderDescription(provider);
  }

  /// Check if provider requires API key
  bool _requiresApiKey(TranscriptionProvider provider) {
    switch (provider) {
      case TranscriptionProvider.openaiWhisper:
        return true;
      case TranscriptionProvider.localWhisper:
        return false;
      case TranscriptionProvider.googleSpeechToText:
        return true;
      case TranscriptionProvider.anthropicTranscription:
        return true;
    }
  }

  /// Build provider selection section
  Widget _buildProviderSelection() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transcription Provider',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...TranscriptionProvider.values.map((provider) {
          final isAvailable = _providerAvailability[provider] ?? false;
          final capabilities = _serviceCapabilities[provider];
          final requiresKey = _requiresApiKey(provider);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: RadioListTile<TranscriptionProvider>(
              title: Row(
                children: [
                  Text(_getProviderDisplayName(provider)),
                  const SizedBox(width: 8),
                  if (isAvailable)
                    Icon(Icons.check_circle, color: Colors.green, size: 16)
                  else
                    Icon(Icons.warning, color: Colors.orange, size: 16),
                  const Spacer(),
                  if (requiresKey)
                    IconButton(
                      icon: const Icon(Icons.key, size: 16),
                      onPressed: () => _showApiKeyDialog(provider),
                      tooltip: 'Configure API Key',
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_getProviderDescription(provider)),
                  if (capabilities != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Languages: ${capabilities.supportedLanguages}, '
                      'Max size: ${capabilities.maxFileSizeMB}MB, '
                      'Cost: \$${capabilities.costPerMinute.toStringAsFixed(3)}/min',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
              value: provider,
              groupValue: _selectedProvider,
              onChanged: isAvailable
                  ? (value) {
                      setState(() {
                        _selectedProvider = value;
                      });
                    }
                  : null,
            ),
          );
        }),
      ],
    );
  }

  /// Build quality selection section
  Widget _buildQualitySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transcription Quality',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...TranscriptionQuality.values.map((quality) {
          return RadioListTile<TranscriptionQuality>(
            title: Text(quality.displayName),
            subtitle: Text(quality.description),
            value: quality,
            groupValue: _selectedQuality,
            onChanged: (value) {
              setState(() {
                _selectedQuality = value!;
              });
            },
          );
        }),
      ],
    );
  }

  /// Build language selection section
  Widget _buildLanguageSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transcription Language',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<TranscriptionLanguage?>(
          value: _selectedLanguage,
          decoration: const InputDecoration(
            labelText: 'Language',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<TranscriptionLanguage?>(
              value: null,
              child: Text('Auto-detect'),
            ),
            ...TranscriptionLanguage.values
                .where((lang) => lang != TranscriptionLanguage.auto)
                .map((language) {
                  return DropdownMenuItem<TranscriptionLanguage?>(
                    value: language,
                    child: Text(language.displayName),
                  );
                }),
          ],
          onChanged: (value) {
            setState(() {
              _selectedLanguage = value;
            });
          },
        ),
      ],
    );
  }

  /// Build advanced options section
  Widget _buildAdvancedOptions() {
    final capabilities = _selectedProvider != null
        ? _serviceCapabilities[_selectedProvider]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advanced Options',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Enable Timestamps'),
          subtitle: const Text('Include timing information in transcription'),
          value: _enableTimestamps,
          onChanged: capabilities?.supportsTimestamps == true
              ? (value) {
                  setState(() {
                    _enableTimestamps = value;
                  });
                }
              : null,
        ),
        SwitchListTile(
          title: const Text('Speaker Diarization'),
          subtitle: const Text('Identify different speakers in the recording'),
          value: _enableSpeakerDiarization,
          onChanged: capabilities?.supportsSpeakerDiarization == true
              ? (value) {
                  setState(() {
                    _enableSpeakerDiarization = value;
                  });
                }
              : null,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _promptController,
          decoration: const InputDecoration(
            labelText: 'Custom Prompt (Optional)',
            hintText: 'Enter custom instructions for the transcription...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          enabled: capabilities?.supportsCustomVocabulary == true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.transcribe),
                  const SizedBox(width: 12),
                  Text(
                    'Transcription Settings',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProviderSelection(),
                    const SizedBox(height: 24),
                    _buildQualitySelection(),
                    const SizedBox(height: 24),
                    _buildLanguageSelection(),
                    const SizedBox(height: 24),
                    _buildAdvancedOptions(),
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text('Save Settings'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Transcription settings configuration
class TranscriptionSettings {
  final TranscriptionProvider provider;
  final TranscriptionQuality quality;
  final TranscriptionLanguage? language;
  final bool enableTimestamps;
  final bool enableSpeakerDiarization;
  final String? customPrompt;

  const TranscriptionSettings({
    required this.provider,
    required this.quality,
    this.language,
    required this.enableTimestamps,
    required this.enableSpeakerDiarization,
    this.customPrompt,
  });

  /// Convert to TranscriptionRequest
  TranscriptionRequest toRequest() {
    return TranscriptionRequest(
      language: language,
      prompt: customPrompt,
      quality: quality,
      enableTimestamps: enableTimestamps,
      enableSpeakerDiarization: enableSpeakerDiarization,
    );
  }

  /// Create a copy with modified values
  TranscriptionSettings copyWith({
    TranscriptionProvider? provider,
    TranscriptionQuality? quality,
    TranscriptionLanguage? language,
    bool? enableTimestamps,
    bool? enableSpeakerDiarization,
    String? customPrompt,
  }) {
    return TranscriptionSettings(
      provider: provider ?? this.provider,
      quality: quality ?? this.quality,
      language: language ?? this.language,
      enableTimestamps: enableTimestamps ?? this.enableTimestamps,
      enableSpeakerDiarization:
          enableSpeakerDiarization ?? this.enableSpeakerDiarization,
      customPrompt: customPrompt ?? this.customPrompt,
    );
  }

  @override
  String toString() {
    return 'TranscriptionSettings('
        'provider: $provider, '
        'quality: $quality, '
        'language: ${language?.displayName ?? 'auto'}, '
        'timestamps: $enableTimestamps, '
        'speakers: $enableSpeakerDiarization'
        ')';
  }
}
