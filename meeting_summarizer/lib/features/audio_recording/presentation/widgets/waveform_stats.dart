/// Widget for displaying waveform statistics and real-time audio information
library;

import 'package:flutter/material.dart';

/// Statistics widget for waveform visualization
class WaveformStats extends StatelessWidget {
  /// Current audio amplitude (0.0 to 1.0)
  final double currentAmplitude;

  /// Average amplitude over recent samples
  final double averageAmplitude;

  /// Peak amplitude reached during recording
  final double peakAmplitude;

  /// Total number of waveform data points
  final int totalDataPoints;

  /// Current recording duration
  final Duration recordingDuration;

  /// Whether recording is currently active
  final bool isRecording;

  /// Sample rate for audio capture
  final int sampleRate;

  /// Current audio format
  final String audioFormat;

  const WaveformStats({
    super.key,
    required this.currentAmplitude,
    required this.averageAmplitude,
    required this.peakAmplitude,
    required this.totalDataPoints,
    required this.recordingDuration,
    required this.isRecording,
    this.sampleRate = 44100,
    this.audioFormat = 'WAV',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.analytics, color: theme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Audio Statistics',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isRecording ? Colors.red : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isRecording ? Icons.fiber_manual_record : Icons.stop,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isRecording ? 'REC' : 'STOP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Duration and Format Info
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Duration',
                    _formatDuration(recordingDuration),
                    Icons.access_time,
                    theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoItem(
                    'Format',
                    '$audioFormat @ ${(sampleRate / 1000).toStringAsFixed(1)}kHz',
                    Icons.audiotrack,
                    theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Amplitude Information
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audio Levels',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Current Amplitude
                _buildAmplitudeBar(
                  'Current',
                  currentAmplitude,
                  _getAmplitudeColor(currentAmplitude),
                  theme,
                ),

                const SizedBox(height: 8),

                // Average Amplitude
                _buildAmplitudeBar(
                  'Average',
                  averageAmplitude,
                  Colors.blue,
                  theme,
                ),

                const SizedBox(height: 8),

                // Peak Amplitude
                _buildAmplitudeBar('Peak', peakAmplitude, Colors.orange, theme),
              ],
            ),

            const SizedBox(height: 16),

            // Data Points and Performance
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Data Points',
                    totalDataPoints.toString(),
                    Icons.data_usage,
                    theme.colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoItem(
                    'Quality',
                    _getQualityLabel(averageAmplitude),
                    Icons.high_quality,
                    _getQualityColor(averageAmplitude),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Performance indicator
            if (isRecording)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.speed,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Real-time processing active',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmplitudeBar(
    String label,
    double value,
    Color color,
    ThemeData theme,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '${(value * 100).toStringAsFixed(0)}%',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Color _getAmplitudeColor(double amplitude) {
    if (amplitude < 0.1) return Colors.grey;
    if (amplitude < 0.3) return Colors.green;
    if (amplitude < 0.6) return Colors.yellow;
    if (amplitude < 0.8) return Colors.orange;
    return Colors.red;
  }

  String _getQualityLabel(double averageAmplitude) {
    if (averageAmplitude < 0.1) return 'Too Low';
    if (averageAmplitude < 0.3) return 'Good';
    if (averageAmplitude < 0.7) return 'Excellent';
    return 'Too High';
  }

  Color _getQualityColor(double averageAmplitude) {
    if (averageAmplitude < 0.1) return Colors.red;
    if (averageAmplitude < 0.3) return Colors.green;
    if (averageAmplitude < 0.7) return Colors.blue;
    return Colors.orange;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
