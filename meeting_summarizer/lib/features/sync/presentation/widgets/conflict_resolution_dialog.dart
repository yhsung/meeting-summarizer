import 'package:flutter/material.dart';

import '../../../../core/models/cloud_sync/sync_conflict.dart';

/// Dialog for resolving synchronization conflicts
class ConflictResolutionDialog extends StatefulWidget {
  final SyncConflict conflict;
  final Function(ConflictResolution resolution, String? userInput) onResolve;
  final VoidCallback? onCancel;

  const ConflictResolutionDialog({
    super.key,
    required this.conflict,
    required this.onResolve,
    this.onCancel,
  });

  @override
  State<ConflictResolutionDialog> createState() =>
      _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  ConflictResolution? _selectedResolution;
  final TextEditingController _userInputController = TextEditingController();
  bool _showMergeInput = false;

  @override
  void initState() {
    super.initState();
    // Pre-select suggested resolution if available
    if (widget.conflict.canAutoResolve) {
      _selectedResolution = widget.conflict.suggestedResolution;
    }
  }

  @override
  void dispose() {
    _userInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildConflictInfo(),
            const SizedBox(height: 24),
            _buildVersionComparison(),
            const SizedBox(height: 24),
            _buildResolutionOptions(),
            if (_showMergeInput) ...[
              const SizedBox(height: 16),
              _buildMergeInput(),
            ],
            const SizedBox(height: 24),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(_getConflictIcon(), color: _getConflictColor(), size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Synchronization Conflict',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.conflict.provider.displayName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: widget.onCancel,
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
        ),
      ],
    );
  }

  Widget _buildConflictInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.folder,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.conflict.filePath,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.conflict.humanReadableDescription,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSeverityChip(),
                const SizedBox(width: 8),
                Text(
                  'Detected ${_formatTimeSince(widget.conflict.timeSinceDetected)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionComparison() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version Comparison',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _buildVersionCard(
                      'Local',
                      widget.conflict.localVersion,
                    ),
                  ),
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: Theme.of(context).dividerColor,
                  ),
                  Expanded(
                    child: _buildVersionCard(
                      'Remote',
                      widget.conflict.remoteVersion,
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

  Widget _buildVersionCard(String label, FileVersion version) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        if (version.exists) ...[
          _buildVersionProperty('Size', version.formattedSize),
          _buildVersionProperty(
            'Modified',
            _formatDateTime(version.modifiedAt),
          ),
          if (version.mimeType != null)
            _buildVersionProperty('Type', version.mimeType!),
          if (version.checksum != null)
            _buildVersionProperty(
              'Checksum',
              '${version.checksum!.substring(0, 8)}...',
            ),
        ] else
          Text(
            'File does not exist',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildVersionProperty(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionOptions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resolution Options',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...ConflictResolution.values.map((resolution) {
              return _buildResolutionOption(resolution);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildResolutionOption(ConflictResolution resolution) {
    final isRecommended = resolution == widget.conflict.suggestedResolution;
    final isAvailable = _isResolutionAvailable(resolution);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: RadioListTile<ConflictResolution>(
        value: resolution,
        groupValue: _selectedResolution,
        onChanged: isAvailable
            ? (value) {
                setState(() {
                  _selectedResolution = value;
                  _showMergeInput = value == ConflictResolution.merge;
                });
              }
            : null,
        title: Row(
          children: [
            Text(_getResolutionTitle(resolution)),
            if (isRecommended) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Recommended',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(_getResolutionDescription(resolution)),
        dense: true,
      ),
    );
  }

  Widget _buildMergeInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manual Merge Content',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the merged content or leave empty for automatic merge.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _userInputController,
              maxLines: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter merged content here...',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _selectedResolution != null ? _handleResolve : null,
          child: const Text('Resolve'),
        ),
      ],
    );
  }

  Widget _buildSeverityChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getSeverityColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getSeverityColor().withValues(alpha: 0.3)),
      ),
      child: Text(
        widget.conflict.severity.name.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _getSeverityColor(),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _handleResolve() {
    if (_selectedResolution != null) {
      final userInput = _showMergeInput && _userInputController.text.isNotEmpty
          ? _userInputController.text
          : null;
      widget.onResolve(_selectedResolution!, userInput);
    }
  }

  IconData _getConflictIcon() {
    switch (widget.conflict.type) {
      case ConflictType.modifiedBoth:
        return Icons.merge_type;
      case ConflictType.deletedLocal:
      case ConflictType.deletedRemote:
        return Icons.delete_outline;
      case ConflictType.typeChanged:
        return Icons.transform;
      case ConflictType.sizeMismatch:
        return Icons.photo_size_select_large;
      default:
        return Icons.warning_outlined;
    }
  }

  Color _getConflictColor() {
    return _getSeverityColor();
  }

  Color _getSeverityColor() {
    switch (widget.conflict.severity) {
      case ConflictSeverity.low:
        return Colors.green;
      case ConflictSeverity.medium:
        return Colors.orange;
      case ConflictSeverity.high:
        return Colors.red;
      case ConflictSeverity.critical:
        return Colors.purple;
    }
  }

  String _getResolutionTitle(ConflictResolution resolution) {
    switch (resolution) {
      case ConflictResolution.keepLocal:
        return 'Keep Local Version';
      case ConflictResolution.keepRemote:
        return 'Keep Remote Version';
      case ConflictResolution.keepBoth:
        return 'Keep Both Versions';
      case ConflictResolution.merge:
        return 'Merge Files';
      case ConflictResolution.manual:
        return 'Manual Resolution';
    }
  }

  String _getResolutionDescription(ConflictResolution resolution) {
    switch (resolution) {
      case ConflictResolution.keepLocal:
        return 'Replace remote file with local version';
      case ConflictResolution.keepRemote:
        return 'Replace local file with remote version';
      case ConflictResolution.keepBoth:
        return 'Save both versions with different names';
      case ConflictResolution.merge:
        return 'Combine both versions into one file';
      case ConflictResolution.manual:
        return 'Resolve manually later';
    }
  }

  bool _isResolutionAvailable(ConflictResolution resolution) {
    switch (resolution) {
      case ConflictResolution.keepLocal:
        return widget.conflict.localVersion.exists;
      case ConflictResolution.keepRemote:
        return widget.conflict.remoteVersion.exists;
      case ConflictResolution.merge:
        return widget.conflict.localVersion.exists &&
            widget.conflict.remoteVersion.exists &&
            _canMergeFiles();
      case ConflictResolution.keepBoth:
      case ConflictResolution.manual:
        return true;
    }
  }

  bool _canMergeFiles() {
    final textExtensions = {'.txt', '.md', '.json', '.xml', '.csv', '.log'};
    final extension = widget.conflict.filePath.split('.').last.toLowerCase();
    return textExtensions.contains('.$extension');
  }

  String _formatTimeSince(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays == 1 ? '' : 's'} ago';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours == 1 ? '' : 's'} ago';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} minute${duration.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
