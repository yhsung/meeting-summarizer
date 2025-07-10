/// Waveform settings widget for customizing visualization options
library;

import 'package:flutter/material.dart';

import 'realtime_waveform_controller.dart';

/// Settings widget for waveform visualization customization
class WaveformSettings extends StatefulWidget {
  /// Current waveform type
  final WaveformType waveformType;

  /// Whether real-time mode is enabled
  final bool enableRealtime;

  /// Current waveform color
  final Color waveformColor;

  /// Available color options
  final List<Color> colorOptions;

  /// Callback when waveform type changes
  final ValueChanged<WaveformType>? onWaveformTypeChanged;

  /// Callback when real-time mode changes
  final ValueChanged<bool>? onRealtimeChanged;

  /// Callback when color changes
  final ValueChanged<Color>? onColorChanged;

  /// Whether the settings are expanded
  final bool isExpanded;

  /// Callback when expansion state changes
  final ValueChanged<bool>? onExpansionChanged;

  const WaveformSettings({
    super.key,
    required this.waveformType,
    required this.enableRealtime,
    required this.waveformColor,
    this.colorOptions = const [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ],
    this.onWaveformTypeChanged,
    this.onRealtimeChanged,
    this.onColorChanged,
    this.isExpanded = false,
    this.onExpansionChanged,
  });

  @override
  State<WaveformSettings> createState() => _WaveformSettingsState();
}

class _WaveformSettingsState extends State<WaveformSettings>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    if (widget.isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(WaveformSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Column(
        children: [
          // Header
          ListTile(
            leading: Icon(Icons.tune, color: theme.primaryColor),
            title: Text(
              'Waveform Settings',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: IconButton(
              icon: AnimatedRotation(
                turns: widget.isExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: const Icon(Icons.expand_more),
              ),
              onPressed: () {
                widget.onExpansionChanged?.call(!widget.isExpanded);
              },
            ),
            onTap: () {
              widget.onExpansionChanged?.call(!widget.isExpanded);
            },
          ),

          // Expandable content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Waveform Type Selection
                  Text(
                    'Visualization Type',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<WaveformType>(
                    segments: [
                      ButtonSegment(
                        value: WaveformType.circular,
                        icon: const Icon(Icons.circle_outlined, size: 18),
                        label: const Text('Circular'),
                      ),
                      ButtonSegment(
                        value: WaveformType.linear,
                        icon: const Icon(Icons.show_chart, size: 18),
                        label: const Text('Linear'),
                      ),
                    ],
                    selected: {widget.waveformType},
                    onSelectionChanged: (Set<WaveformType> selection) {
                      widget.onWaveformTypeChanged?.call(selection.first);
                    },
                  ),

                  const SizedBox(height: 20),

                  // Real-time Mode Toggle
                  SwitchListTile(
                    title: Text(
                      'Real-time Mode',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Enable advanced real-time audio visualization',
                    ),
                    value: widget.enableRealtime,
                    onChanged: widget.onRealtimeChanged,
                    secondary: const Icon(Icons.speed),
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 12),

                  // Color Selection
                  Text(
                    'Waveform Color',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.colorOptions.map((color) {
                      final isSelected = color == widget.waveformColor;
                      return GestureDetector(
                        onTap: () {
                          widget.onColorChanged?.call(color);
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.onSurface
                                  : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? Icon(Icons.check, color: Colors.white, size: 20)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),

                  // Performance Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.enableRealtime
                                ? 'Real-time mode provides enhanced visualization with live audio feedback'
                                : 'Basic mode offers optimized performance for longer recordings',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
