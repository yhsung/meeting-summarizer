/// Widget for displaying transcription progress
library;

import 'package:flutter/material.dart';

/// Progress indicator for transcription operations
class TranscriptionProgress extends StatelessWidget {
  final double progress;
  final String statusMessage;
  final bool showPercentage;

  const TranscriptionProgress({
    super.key,
    required this.progress,
    required this.statusMessage,
    this.showPercentage = true,
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
              Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Transcription Progress',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (showPercentage)
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),

          const SizedBox(height: 12),

          // Status message
          Text(
            statusMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
