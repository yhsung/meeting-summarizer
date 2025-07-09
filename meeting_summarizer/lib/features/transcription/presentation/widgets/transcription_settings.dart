/// Widget for transcription settings and configuration
library;

import 'package:flutter/material.dart';

import '../../../../core/enums/transcription_language.dart';

/// Settings panel for transcription configuration
class TranscriptionSettings extends StatelessWidget {
  final TranscriptionLanguage selectedLanguage;
  final bool enableTimestamps;
  final bool enableSpeakerDiarization;
  final bool enableWordLevelTimestamps;
  final Function(TranscriptionLanguage) onLanguageChanged;
  final Function(bool) onTimestampsChanged;
  final Function(bool) onSpeakerDiarizationChanged;
  final Function(bool) onWordLevelTimestampsChanged;

  const TranscriptionSettings({
    super.key,
    required this.selectedLanguage,
    required this.enableTimestamps,
    required this.enableSpeakerDiarization,
    required this.enableWordLevelTimestamps,
    required this.onLanguageChanged,
    required this.onTimestampsChanged,
    required this.onSpeakerDiarizationChanged,
    required this.onWordLevelTimestampsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.settings, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Transcription Settings',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Language selection
          Text(
            'Language',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<TranscriptionLanguage>(
            value: selectedLanguage,
            onChanged: (language) {
              if (language != null) {
                onLanguageChanged(language);
              }
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: TranscriptionLanguage.values.map((language) {
              return DropdownMenuItem(
                value: language,
                child: Text(language.name),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Feature toggles
          Text(
            'Features',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          // Timestamps toggle
          SwitchListTile(
            title: const Text('Timestamps'),
            subtitle: const Text('Include time markers in transcription'),
            value: enableTimestamps,
            onChanged: onTimestampsChanged,
            contentPadding: EdgeInsets.zero,
          ),

          // Speaker diarization toggle
          SwitchListTile(
            title: const Text('Speaker Diarization'),
            subtitle: const Text('Identify different speakers'),
            value: enableSpeakerDiarization,
            onChanged: onSpeakerDiarizationChanged,
            contentPadding: EdgeInsets.zero,
          ),

          // Word-level timestamps toggle
          SwitchListTile(
            title: const Text('Word-level Timestamps'),
            subtitle: const Text('Precise timing for each word'),
            value: enableWordLevelTimestamps,
            onChanged: onWordLevelTimestampsChanged,
            contentPadding: EdgeInsets.zero,
          ),

          const SizedBox(height: 8),

          // Info card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Advanced features may increase processing time but provide more detailed results.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
