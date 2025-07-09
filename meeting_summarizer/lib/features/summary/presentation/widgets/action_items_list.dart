/// Action items list widget for displaying and managing action items
library;

import 'package:flutter/material.dart';

import '../../../../core/models/database/summary.dart';

/// Widget for displaying and managing action items from summaries
class ActionItemsList extends StatefulWidget {
  /// List of action items to display
  final List<ActionItem> actionItems;

  /// Callback when an action item is updated
  final ValueChanged<ActionItem>? onActionItemUpdated;

  /// Whether the list is read-only
  final bool readOnly;

  const ActionItemsList({
    super.key,
    required this.actionItems,
    this.onActionItemUpdated,
    this.readOnly = false,
  });

  @override
  State<ActionItemsList> createState() => _ActionItemsListState();
}

class _ActionItemsListState extends State<ActionItemsList> {
  @override
  Widget build(BuildContext context) {
    if (widget.actionItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.task_alt, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Action Items (${widget.actionItems.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.actionItems.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final actionItem = widget.actionItems[index];
                return _buildActionItemTile(actionItem);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItemTile(ActionItem actionItem) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getStatusColor(actionItem.status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getStatusColor(actionItem.status).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  actionItem.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    decoration: actionItem.status == ActionItemStatus.completed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              if (!widget.readOnly) _buildStatusButton(actionItem),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPriorityChip(actionItem.priority),
              const SizedBox(width: 8),
              _buildStatusChip(actionItem.status),
              if (actionItem.assignee != null) ...[
                const SizedBox(width: 8),
                _buildAssigneeChip(actionItem.assignee!),
              ],
              if (actionItem.dueDate != null) ...[
                const SizedBox(width: 8),
                _buildDueDateChip(actionItem.dueDate!),
              ],
            ],
          ),
          if (actionItem.isOverdue) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Overdue',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusButton(ActionItem actionItem) {
    return PopupMenuButton<ActionItemStatus>(
      onSelected: (status) {
        final updatedItem = actionItem.copyWith(status: status);
        widget.onActionItemUpdated?.call(updatedItem);
      },
      itemBuilder: (context) => ActionItemStatus.values.map((status) {
        return PopupMenuItem(
          value: status,
          child: Row(
            children: [
              Icon(
                _getStatusIcon(status),
                color: _getStatusColor(status),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(_getStatusDisplayName(status)),
            ],
          ),
        );
      }).toList(),
      child: Icon(Icons.more_vert, color: Colors.grey[600]),
    );
  }

  Widget _buildPriorityChip(ActionItemPriority priority) {
    return Chip(
      label: Text(
        priority.toString().toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
      backgroundColor: _getPriorityColor(priority),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildStatusChip(ActionItemStatus status) {
    return Chip(
      label: Text(
        _getStatusDisplayName(status),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
      backgroundColor: _getStatusColor(status),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildAssigneeChip(String assignee) {
    return Chip(
      label: Text(
        assignee,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.blue[100],
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      avatar: const CircleAvatar(
        backgroundColor: Colors.blue,
        child: Icon(Icons.person, size: 14, color: Colors.white),
      ),
    );
  }

  Widget _buildDueDateChip(DateTime dueDate) {
    final isOverdue = DateTime.now().isAfter(dueDate);
    final color = isOverdue ? Colors.red : Colors.orange;

    return Chip(
      label: Text(
        _formatDate(dueDate),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color[100],
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Icon(
          isOverdue ? Icons.warning : Icons.schedule,
          size: 14,
          color: Colors.white,
        ),
      ),
    );
  }

  Color _getPriorityColor(ActionItemPriority priority) {
    switch (priority) {
      case ActionItemPriority.urgent:
        return Colors.red[100]!;
      case ActionItemPriority.high:
        return Colors.orange[100]!;
      case ActionItemPriority.medium:
        return Colors.yellow[100]!;
      case ActionItemPriority.low:
        return Colors.green[100]!;
    }
  }

  Color _getStatusColor(ActionItemStatus status) {
    switch (status) {
      case ActionItemStatus.pending:
        return Colors.grey;
      case ActionItemStatus.inProgress:
        return Colors.blue;
      case ActionItemStatus.completed:
        return Colors.green;
      case ActionItemStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(ActionItemStatus status) {
    switch (status) {
      case ActionItemStatus.pending:
        return Icons.pending;
      case ActionItemStatus.inProgress:
        return Icons.play_arrow;
      case ActionItemStatus.completed:
        return Icons.check_circle;
      case ActionItemStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _getStatusDisplayName(ActionItemStatus status) {
    switch (status) {
      case ActionItemStatus.pending:
        return 'Pending';
      case ActionItemStatus.inProgress:
        return 'In Progress';
      case ActionItemStatus.completed:
        return 'Completed';
      case ActionItemStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
