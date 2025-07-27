/// Widget for displaying speaker timeline and conversation flow
library;

import 'package:flutter/material.dart';

import '../../../../core/models/transcription_result.dart';

/// Timeline widget showing speaker conversation flow
class SpeakerTimeline extends StatelessWidget {
  final TranscriptionResult result;
  final bool showTimestamps;
  final bool showConfidence;

  const SpeakerTimeline({
    super.key,
    required this.result,
    this.showTimestamps = true,
    this.showConfidence = false,
  });

  /// Format timestamp for display
  String _formatTimestamp(double seconds) {
    final minutes = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Get speaker color based on speaker ID
  Color _getSpeakerColor(String speakerId, BuildContext context) {
    final theme = Theme.of(context);
    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
    ];

    final hash = speakerId.hashCode;
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeline = result.getSpeakerTimeline();

    if (timeline.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No Speaker Data Available',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enable speaker diarization to see conversation flow',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'Speaker Timeline',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Timeline
        Expanded(
          child: ListView.builder(
            itemCount: timeline.length,
            itemBuilder: (context, index) {
              final entry = timeline[index];
              final speakerColor = _getSpeakerColor(entry.speakerId, context);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Speaker indicator
                    Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: speakerColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: speakerColor, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              entry.speakerId,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: speakerColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        // Timeline connector
                        if (index < timeline.length - 1)
                          Container(
                            width: 2,
                            height: 40,
                            color: speakerColor.withValues(alpha: 0.3),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                          ),
                      ],
                    ),

                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: speakerColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with timestamp
                            Row(
                              children: [
                                Text(
                                  'Speaker ${entry.speakerId}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: speakerColor,
                                  ),
                                ),
                                const Spacer(),
                                if (showTimestamps)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.outline
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${_formatTimestamp(entry.start)} - ${_formatTimestamp(entry.end)}',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Speaker text
                            Text(
                              entry.text,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.4,
                              ),
                            ),

                            // Duration info
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: theme.colorScheme.outline,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${entry.duration.inSeconds}s',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
