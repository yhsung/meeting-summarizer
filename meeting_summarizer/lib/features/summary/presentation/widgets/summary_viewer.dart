/// Summary viewer widget for displaying summary content
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/database/summary.dart';

/// Widget for displaying summary content with rich formatting
class SummaryViewer extends StatefulWidget {
  /// The summary to display
  final Summary summary;

  /// Callback when summary deletion is requested
  final VoidCallback? onDelete;

  /// Whether to show actions (edit, delete, etc.)
  final bool showActions;

  /// Whether to show metadata (confidence, word count, etc.)
  final bool showMetadata;

  const SummaryViewer({
    super.key,
    required this.summary,
    this.onDelete,
    this.showActions = true,
    this.showMetadata = true,
  });

  @override
  State<SummaryViewer> createState() => _SummaryViewerState();
}

class _SummaryViewerState extends State<SummaryViewer> {
  bool _isExpanded = true;
  bool _isCopied = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (_isExpanded) ..._buildContent(),
          if (_isExpanded && widget.showMetadata) _buildMetadata(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
      child: Row(
        children: [
          Icon(
            _getIconForSummaryType(widget.summary.type),
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.summary.type.displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Generated on ${_formatDate(widget.summary.createdAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (widget.showActions) _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
          onPressed: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          tooltip: _isExpanded ? 'Collapse' : 'Expand',
        ),
        IconButton(
          icon: Icon(
            _isCopied ? Icons.check : Icons.copy,
            color: _isCopied ? Colors.green : null,
          ),
          onPressed: _copyToClipboard,
          tooltip: 'Copy to Clipboard',
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editSummary();
                break;
              case 'delete':
                _confirmDelete();
                break;
              case 'export':
                _exportSummary();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit Summary'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: ListTile(
                leading: Icon(Icons.download),
                title: Text('Export Summary'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text(
                  'Delete Summary',
                  style: TextStyle(color: Colors.red),
                ),
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildContent() {
    return [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryContent(),
            const SizedBox(height: 16),
            if (widget.summary.keyPoints?.isNotEmpty ?? false)
              _buildKeyPoints(),
            if (widget.summary.sentiment != SentimentType.neutral)
              _buildSentimentIndicator(),
          ],
        ),
      ),
    ];
  }

  Widget _buildSummaryContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Summary',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300] ?? Colors.grey),
          ),
          child: SelectableText(
            widget.summary.content,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildKeyPoints() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Key Points',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200] ?? Colors.blue),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: (widget.summary.keyPoints ?? [])
                .map(
                  (point) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          size: 8,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            point,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSentimentIndicator() {
    Color sentimentColor;
    IconData sentimentIcon;
    String sentimentText;

    switch (widget.summary.sentiment) {
      case SentimentType.positive:
        sentimentColor = Colors.green;
        sentimentIcon = Icons.sentiment_very_satisfied;
        sentimentText = 'Positive';
        break;
      case SentimentType.negative:
        sentimentColor = Colors.red;
        sentimentIcon = Icons.sentiment_very_dissatisfied;
        sentimentText = 'Negative';
        break;
      case SentimentType.neutral:
        sentimentColor = Colors.grey;
        sentimentIcon = Icons.sentiment_neutral;
        sentimentText = 'Neutral';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Icon(sentimentIcon, color: sentimentColor, size: 20),
          const SizedBox(width: 8),
          Text(
            'Sentiment: $sentimentText',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: sentimentColor,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildMetadataItem(
                'Confidence',
                widget.summary.formattedConfidence,
                Icons.verified,
                Colors.green,
              ),
              const SizedBox(width: 24),
              _buildMetadataItem(
                'Words',
                widget.summary.wordCount.toString(),
                Icons.text_fields,
                Colors.blue,
              ),
              const SizedBox(width: 24),
              _buildMetadataItem(
                'Length',
                widget.summary.lengthCategory,
                Icons.straighten,
                Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetadataItem(
                'Provider',
                widget.summary.provider,
                Icons.smart_toy,
                Colors.purple,
              ),
              const SizedBox(width: 24),
              _buildMetadataItem(
                'Reading Time',
                '${widget.summary.estimatedReadingTime} min',
                Icons.schedule,
                Colors.teal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForSummaryType(SummaryType type) {
    switch (type) {
      case SummaryType.brief:
        return Icons.short_text;
      case SummaryType.detailed:
        return Icons.article;
      case SummaryType.bulletPoints:
        return Icons.format_list_bulleted;
      case SummaryType.actionItems:
        return Icons.task_alt;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.summary.content));
    setState(() {
      _isCopied = true;
    });

    // Reset the copy indicator after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  void _editSummary() {
    // TODO: Implement edit functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit feature coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Summary'),
        content: const Text(
          'Are you sure you want to delete this summary? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDelete?.call();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _exportSummary() {
    // TODO: Implement export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export feature coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
