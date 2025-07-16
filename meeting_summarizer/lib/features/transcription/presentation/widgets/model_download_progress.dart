/// Model download progress widget
library;

import 'package:flutter/material.dart';

/// Widget that displays download progress for Whisper models
class ModelDownloadProgress extends StatelessWidget {
  /// Current download progress (0.0 to 1.0)
  final double progress;

  /// Status message to display
  final String status;

  /// Number of bytes downloaded (optional)
  final int? downloadedBytes;

  /// Total number of bytes to download (optional)
  final int? totalBytes;

  /// Model name being downloaded
  final String modelName;

  /// Whether download is in progress
  final bool isDownloading;

  /// Callback when user cancels download
  final VoidCallback? onCancel;

  const ModelDownloadProgress({
    super.key,
    required this.progress,
    required this.status,
    required this.modelName,
    this.downloadedBytes,
    this.totalBytes,
    this.isDownloading = true,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with model name and cancel button
          Row(
            children: [
              Icon(Icons.download, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Downloading $modelName',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (onCancel != null && isDownloading)
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  onPressed: onCancel,
                  tooltip: 'Cancel download',
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            minHeight: 6,
          ),

          const SizedBox(height: 8),

          // Status and progress info
          Row(
            children: [
              Expanded(
                child: Text(
                  status,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Byte progress (if available)
          if (downloadedBytes != null && totalBytes != null) ...[
            const SizedBox(height: 4),
            Text(
              '${_formatBytes(downloadedBytes!)} / ${_formatBytes(totalBytes!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Format bytes into human-readable string
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Compact version of download progress for notifications
class CompactModelDownloadProgress extends StatelessWidget {
  final double progress;
  final String modelName;
  final bool isDownloading;

  const CompactModelDownloadProgress({
    super.key,
    required this.progress,
    required this.modelName,
    this.isDownloading = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Downloading $modelName',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${(progress * 100).toStringAsFixed(0)}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
