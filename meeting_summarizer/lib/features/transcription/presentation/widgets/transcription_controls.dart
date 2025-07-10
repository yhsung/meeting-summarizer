/// Widget for transcription controls and actions
library;

import 'package:flutter/material.dart';

/// Control panel for transcription operations
class TranscriptionControls extends StatelessWidget {
  final bool isTranscribing;
  final bool isServiceAvailable;
  final bool hasResult;
  final VoidCallback onSelectFile;
  final VoidCallback onStartTranscription;
  final VoidCallback onCopyToClipboard;
  final VoidCallback onExportTranscription;

  const TranscriptionControls({
    super.key,
    required this.isTranscribing,
    required this.isServiceAvailable,
    required this.hasResult,
    required this.onSelectFile,
    required this.onStartTranscription,
    required this.onCopyToClipboard,
    required this.onExportTranscription,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Controls',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Primary action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isTranscribing
                  ? null
                  : (isServiceAvailable ? onSelectFile : null),
              icon: Icon(
                isTranscribing ? Icons.hourglass_empty : Icons.audio_file,
              ),
              label: Text(
                isTranscribing ? 'Transcribing...' : 'Select Audio File',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Secondary actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasResult ? onCopyToClipboard : null,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasResult ? onExportTranscription : null,
                  icon: const Icon(Icons.download),
                  label: const Text('Export'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Service status
          Row(
            children: [
              Icon(
                isServiceAvailable ? Icons.check_circle : Icons.error,
                color: isServiceAvailable ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                isServiceAvailable
                    ? 'Service Available'
                    : 'Service Unavailable',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isServiceAvailable ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
