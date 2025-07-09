/// Summary controls widget for managing summary operations
library;

import 'package:flutter/material.dart';

import '../../../../core/models/database/summary.dart';

/// Widget for controlling summary operations like generation, editing, etc.
class SummaryControls extends StatefulWidget {
  /// Whether summary generation is in progress
  final bool isGenerating;

  /// Current generation progress (0.0 to 1.0)
  final double generationProgress;

  /// Status message to display
  final String statusMessage;

  /// Selected summary type
  final SummaryType selectedType;

  /// Callback when generate button is pressed
  final VoidCallback? onGenerate;

  /// Callback when summary type is changed
  final ValueChanged<SummaryType>? onTypeChanged;

  /// Callback when settings button is pressed
  final VoidCallback? onSettings;

  /// Whether controls are enabled
  final bool enabled;

  const SummaryControls({
    super.key,
    required this.isGenerating,
    required this.generationProgress,
    required this.statusMessage,
    required this.selectedType,
    this.onGenerate,
    this.onTypeChanged,
    this.onSettings,
    this.enabled = true,
  });

  @override
  State<SummaryControls> createState() => _SummaryControlsState();
}

class _SummaryControlsState extends State<SummaryControls>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isGenerating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SummaryControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isGenerating && !oldWidget.isGenerating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isGenerating && oldWidget.isGenerating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            if (widget.isGenerating) _buildGenerationProgress(),
            _buildTypeSelector(),
            const SizedBox(height: 16),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.auto_awesome, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(
          'Summary Generation',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: widget.enabled ? widget.onSettings : null,
          tooltip: 'Summary Settings',
        ),
      ],
    );
  }

  Widget _buildGenerationProgress() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: widget.generationProgress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.statusMessage,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Summary Type',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<SummaryType>(
          value: widget.selectedType,
          onChanged: widget.enabled && !widget.isGenerating
              ? (value) => widget.onTypeChanged?.call(value!)
              : null,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
          ),
          items: SummaryType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Row(
                children: [
                  Icon(
                    _getIconForSummaryType(type),
                    size: 18,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.displayName,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          _getDescriptionForType(type),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isGenerating ? _pulseAnimation.value : 1.0,
                child: ElevatedButton.icon(
                  onPressed: widget.enabled && !widget.isGenerating
                      ? widget.onGenerate
                      : null,
                  icon: widget.isGenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    widget.isGenerating ? 'Generating...' : 'Generate Summary',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: widget.enabled && !widget.isGenerating
              ? () => _showAdvancedOptions(context)
              : null,
          child: const Text('Advanced'),
        ),
      ],
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
        return 'Concise overview of main points';
      case SummaryType.detailed:
        return 'Comprehensive summary with context';
      case SummaryType.bulletPoints:
        return 'Key points in bullet format';
      case SummaryType.actionItems:
        return 'Focus on tasks and action items';
    }
  }

  void _showAdvancedOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Advanced Summary Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Custom Prompt'),
              subtitle: const Text('Use a custom prompt for generation'),
              onTap: () {
                Navigator.of(context).pop();
                _showCustomPromptDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language Settings'),
              subtitle: const Text('Configure summary language'),
              onTap: () {
                Navigator.of(context).pop();
                _showLanguageSettings(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.psychology),
              title: const Text('AI Model Selection'),
              subtitle: const Text('Choose AI model for generation'),
              onTap: () {
                Navigator.of(context).pop();
                _showModelSelection(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCustomPromptDialog(BuildContext context) {
    // TODO: Implement custom prompt dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Custom prompt feature coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showLanguageSettings(BuildContext context) {
    // TODO: Implement language settings dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Language settings feature coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showModelSelection(BuildContext context) {
    // TODO: Implement model selection dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Model selection feature coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
