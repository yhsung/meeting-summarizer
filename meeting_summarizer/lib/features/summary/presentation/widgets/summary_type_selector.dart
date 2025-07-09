/// Summary type selector widget for choosing summary types
library;

import 'package:flutter/material.dart';

import '../../../../core/models/database/summary.dart';

/// Widget for selecting summary type (brief, detailed, bullet points, etc.)
class SummaryTypeSelector extends StatelessWidget {
  /// Currently selected summary type
  final SummaryType selectedType;

  /// Callback when summary type is changed
  final ValueChanged<SummaryType> onTypeChanged;

  /// Whether the selector is enabled
  final bool enabled;

  const SummaryTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary Type',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SummaryType.values.map((type) {
                final isSelected = type == selectedType;
                return FilterChip(
                  selected: isSelected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getIconForSummaryType(type),
                        size: 16,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 4),
                      Text(type.displayName),
                    ],
                  ),
                  onSelected: enabled
                      ? (selected) {
                          if (selected) {
                            onTypeChanged(type);
                          }
                        }
                      : null,
                  backgroundColor: isSelected
                      ? Theme.of(context).primaryColor
                      : null,
                  selectedColor: Theme.of(context).primaryColor,
                  checkmarkColor: Theme.of(context).colorScheme.onPrimary,
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              _getDescriptionForType(selectedType),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
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

  String _getDescriptionForType(SummaryType type) {
    switch (type) {
      case SummaryType.brief:
        return 'A concise overview of the main points discussed in the meeting.';
      case SummaryType.detailed:
        return 'A comprehensive summary with detailed explanations and context.';
      case SummaryType.bulletPoints:
        return 'Key points organized in an easy-to-scan bullet format.';
      case SummaryType.actionItems:
        return 'Focus on specific tasks and action items identified during the meeting.';
    }
  }
}
