import 'package:flutter/material.dart';
import 'dart:developer' as dev;

import '../../../../core/models/help/contextual_help.dart';
import '../../../../core/services/help_service.dart';

/// Widget that shows contextual help tooltips
class ContextualHelpTooltip extends StatefulWidget {
  final Widget child;
  final String context;
  final String trigger;
  final bool enabled;

  const ContextualHelpTooltip({
    super.key,
    required this.child,
    required this.context,
    required this.trigger,
    this.enabled = true,
  });

  @override
  State<ContextualHelpTooltip> createState() => _ContextualHelpTooltipState();
}

class _ContextualHelpTooltipState extends State<ContextualHelpTooltip> {
  final HelpService _helpService = HelpService.instance;
  OverlayEntry? _overlayEntry;
  final GlobalKey _targetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _checkAndShowHelp();
    }
  }

  @override
  void dispose() {
    _hideHelp();
    super.dispose();
  }

  Future<void> _checkAndShowHelp() async {
    try {
      final contextualHelp = await _helpService.getContextualHelp(
        widget.context,
      );
      final relevantHelp = contextualHelp
          .where((help) => help.trigger == widget.trigger)
          .toList();

      for (final help in relevantHelp) {
        final shouldShow = await _helpService.shouldShowContextualHelp(help.id);
        if (shouldShow && mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            _showHelp(help);
            break; // Show only one help at a time
          }
        }
      }
    } catch (e) {
      dev.log(
        'Error checking contextual help: $e',
        name: 'ContextualHelpTooltip',
        level: 900,
      );
    }
  }

  void _showHelp(ContextualHelp help) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => _HelpTooltipOverlay(
        targetKey: _targetKey,
        help: help,
        onDismiss: () => _dismissHelp(help),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    // Auto-dismiss after duration if specified
    if (help.displayDuration != null) {
      Future.delayed(help.displayDuration!, () {
        if (mounted) {
          _dismissHelp(help);
        }
      });
    }
  }

  void _hideHelp() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _dismissHelp(ContextualHelp help) async {
    _hideHelp();
    await _helpService.markContextualHelpShown(help.id);
  }

  @override
  Widget build(BuildContext context) {
    return Container(key: _targetKey, child: widget.child);
  }
}

class _HelpTooltipOverlay extends StatefulWidget {
  final GlobalKey targetKey;
  final ContextualHelp help;
  final VoidCallback onDismiss;

  const _HelpTooltipOverlay({
    required this.targetKey,
    required this.help,
    required this.onDismiss,
  });

  @override
  State<_HelpTooltipOverlay> createState() => _HelpTooltipOverlayState();
}

class _HelpTooltipOverlayState extends State<_HelpTooltipOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background overlay
        if (widget.help.type == HelpTooltipType.overlay ||
            widget.help.type == HelpTooltipType.spotlight)
          GestureDetector(
            onTap: widget.help.isDismissible ? widget.onDismiss : null,
            child: Container(color: Colors.black.withValues(alpha: 0.5)),
          ),

        // Tooltip content
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: _buildTooltipContent(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTooltipContent() {
    final targetRenderBox =
        widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetRenderBox == null) {
      return const SizedBox.shrink();
    }

    final targetPosition = targetRenderBox.localToGlobal(Offset.zero);
    final targetSize = targetRenderBox.size;
    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      child: _buildTooltipByType(targetPosition, targetSize, screenSize),
    );
  }

  Widget _buildTooltipByType(
    Offset targetPosition,
    Size targetSize,
    Size screenSize,
  ) {
    switch (widget.help.type) {
      case HelpTooltipType.tooltip:
        return _buildTooltip(targetPosition, targetSize, screenSize);
      case HelpTooltipType.overlay:
        return _buildOverlay(screenSize);
      case HelpTooltipType.popover:
        return _buildPopover(targetPosition, targetSize, screenSize);
      case HelpTooltipType.coach:
        return _buildCoach(targetPosition, targetSize, screenSize);
      case HelpTooltipType.spotlight:
        return _buildSpotlight(targetPosition, targetSize, screenSize);
    }
  }

  Widget _buildTooltip(
    Offset targetPosition,
    Size targetSize,
    Size screenSize,
  ) {
    const tooltipWidth = 280.0;
    const arrowSize = 12.0;

    double left = targetPosition.dx + targetSize.width / 2 - tooltipWidth / 2;
    double top = targetPosition.dy - 80 - arrowSize;

    // Adjust position to keep tooltip on screen
    left = left.clamp(16.0, screenSize.width - tooltipWidth - 16);
    if (top < 50) {
      top = targetPosition.dy + targetSize.height + arrowSize;
    }

    return Positioned(
      left: left,
      top: top,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: tooltipWidth,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.help.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (widget.help.isDismissible)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: widget.onDismiss,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.help.content,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(Size screenSize) {
    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      bottom: 0,
      child: Container(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: Material(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: screenSize.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.help.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.help.content,
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (widget.help.isDismissible)
                    ElevatedButton(
                      onPressed: widget.onDismiss,
                      child: const Text('Got it!'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopover(
    Offset targetPosition,
    Size targetSize,
    Size screenSize,
  ) {
    return _buildTooltip(targetPosition, targetSize, screenSize);
  }

  Widget _buildCoach(Offset targetPosition, Size targetSize, Size screenSize) {
    return _buildOverlay(screenSize);
  }

  Widget _buildSpotlight(
    Offset targetPosition,
    Size targetSize,
    Size screenSize,
  ) {
    return Stack(
      children: [
        // Dark background with hole
        CustomPaint(
          size: screenSize,
          painter: _SpotlightPainter(
            spotlightRect: Rect.fromLTWH(
              targetPosition.dx - 8,
              targetPosition.dy - 8,
              targetSize.width + 16,
              targetSize.height + 16,
            ),
          ),
        ),
        // Tooltip content
        _buildTooltip(targetPosition, targetSize, screenSize),
      ],
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect spotlightRect;

  _SpotlightPainter({required this.spotlightRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(spotlightRect, const Radius.circular(8)),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw spotlight border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlightRect, const Radius.circular(8)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Helper widget to easily add contextual help to any widget
class HelpWrapper extends StatelessWidget {
  final Widget child;
  final String helpId;
  final String context;
  final String trigger;
  final bool enabled;

  const HelpWrapper({
    super.key,
    required this.child,
    required this.helpId,
    required this.context,
    required this.trigger,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ContextualHelpTooltip(
      context: this.context,
      trigger: trigger,
      enabled: enabled,
      child: child,
    );
  }
}
