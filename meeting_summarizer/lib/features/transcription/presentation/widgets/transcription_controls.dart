/// Widget for transcription controls and actions
library;

import 'package:flutter/material.dart';

/// Control panel for transcription operations
class TranscriptionControls extends StatelessWidget {
  final bool isTranscribing;
  final bool isServiceAvailable;
  final bool hasResult;
  final bool hasAudioFile;
  final String? audioFileName;
  final String? audioFileSize;
  final VoidCallback onSelectFile;
  final VoidCallback onStartTranscription;
  final VoidCallback onCopyToClipboard;
  final VoidCallback onExportTranscription;

  const TranscriptionControls({
    super.key,
    required this.isTranscribing,
    required this.isServiceAvailable,
    required this.hasResult,
    required this.hasAudioFile,
    this.audioFileName,
    this.audioFileSize,
    required this.onSelectFile,
    required this.onStartTranscription,
    required this.onCopyToClipboard,
    required this.onExportTranscription,
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
          Text(
            'Controls',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // File selection section
          if (!hasAudioFile) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isTranscribing
                    ? null
                    : (isServiceAvailable ? onSelectFile : null),
                icon: const Icon(Icons.audio_file),
                label: const Text('Select Audio File'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else ...[
            // Show selected file info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.audio_file,
                        color: theme.colorScheme.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Selected File',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    audioFileName ?? 'Unknown file',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (audioFileSize != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      audioFileSize!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Action buttons for selected file
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isTranscribing
                        ? null
                        : (isServiceAvailable ? onStartTranscription : null),
                    icon: Icon(
                      isTranscribing ? Icons.hourglass_empty : Icons.play_arrow,
                    ),
                    label: Text(
                      isTranscribing
                          ? 'Transcribing...'
                          : 'Start Transcription',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: isTranscribing ? null : onSelectFile,
                  child: const Icon(Icons.refresh),
                ),
              ],
            ),
          ],

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

          const SizedBox(height: 16),

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
