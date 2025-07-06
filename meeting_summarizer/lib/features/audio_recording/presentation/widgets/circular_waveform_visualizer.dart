import 'dart:math' as math;

import 'package:flutter/material.dart';

class CircularWaveformVisualizer extends StatefulWidget {
  final List<double> waveformData;
  final double currentAmplitude;
  final Color waveColor;
  final Color backgroundColor;
  final double radius;
  final double strokeWidth;
  final bool showCurrentAmplitude;
  final Duration animationDuration;
  final int maxDataPoints;

  const CircularWaveformVisualizer({
    super.key,
    required this.waveformData,
    required this.currentAmplitude,
    this.waveColor = Colors.blue,
    this.backgroundColor = Colors.transparent,
    this.radius = 80.0,
    this.strokeWidth = 3.0,
    this.showCurrentAmplitude = true,
    this.animationDuration = const Duration(milliseconds: 150),
    this.maxDataPoints = 60,
  });

  @override
  State<CircularWaveformVisualizer> createState() =>
      _CircularWaveformVisualizerState();
}

class _CircularWaveformVisualizerState extends State<CircularWaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  List<double> _displayData = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _updateDisplayData();
  }

  @override
  void didUpdateWidget(CircularWaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.waveformData != widget.waveformData ||
        oldWidget.currentAmplitude != widget.currentAmplitude) {
      _updateDisplayData();
      _animationController.forward(from: 0.0);
    }
  }

  void _updateDisplayData() {
    final data = List<double>.from(widget.waveformData);

    // Add current amplitude to the end if showing real-time data
    if (widget.showCurrentAmplitude && widget.currentAmplitude > 0) {
      data.add(widget.currentAmplitude);
    }

    // Limit data points for performance
    if (data.length > widget.maxDataPoints) {
      _displayData = data.sublist(data.length - widget.maxDataPoints);
    } else {
      _displayData = data;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.radius * 2;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        shape: BoxShape.circle,
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            painter: CircularWaveformPainter(
              waveformData: _displayData,
              waveColor: widget.waveColor,
              strokeWidth: widget.strokeWidth,
              animationProgress: _animation.value,
              showCurrentAmplitude: widget.showCurrentAmplitude,
            ),
            size: Size(size, size),
          );
        },
      ),
    );
  }
}

class CircularWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Color waveColor;
  final double strokeWidth;
  final double animationProgress;
  final bool showCurrentAmplitude;

  CircularWaveformPainter({
    required this.waveformData,
    required this.waveColor,
    required this.strokeWidth,
    required this.animationProgress,
    required this.showCurrentAmplitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 3;
    final maxAmplitude = size.width / 6;

    final paint = Paint()
      ..color = waveColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw base circle
    paint.color = waveColor.withValues(alpha: 0.2);
    canvas.drawCircle(center, baseRadius, paint);

    // Draw waveform around the circle
    final angleStep = (2 * math.pi) / waveformData.length;

    for (int i = 0; i < waveformData.length; i++) {
      final amplitude = waveformData[i];
      final normalizedAmplitude = amplitude.clamp(0.0, 1.0);
      final radiusOffset =
          normalizedAmplitude * maxAmplitude * animationProgress;
      final currentRadius = baseRadius + radiusOffset;

      final angle = i * angleStep - math.pi / 2; // Start from top
      final x = center.dx + currentRadius * math.cos(angle);
      final y = center.dy + currentRadius * math.sin(angle);

      final isCurrentAmplitude =
          showCurrentAmplitude && i == waveformData.length - 1;

      // Use different style for current amplitude
      if (isCurrentAmplitude) {
        paint.color = waveColor.withValues(alpha: 0.9);
        paint.strokeWidth = strokeWidth + 1;
      } else {
        // Fade older data points
        final fadeFactor = (i / waveformData.length.toDouble()).clamp(0.3, 1.0);
        paint.color = waveColor.withValues(alpha: fadeFactor * 0.7);
        paint.strokeWidth = strokeWidth;
      }

      // Draw radial line
      final innerX = center.dx + baseRadius * math.cos(angle);
      final innerY = center.dy + baseRadius * math.sin(angle);

      canvas.drawLine(Offset(innerX, innerY), Offset(x, y), paint);
    }
  }

  @override
  bool shouldRepaint(CircularWaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData ||
        oldDelegate.animationProgress != animationProgress ||
        oldDelegate.waveColor != waveColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.showCurrentAmplitude != showCurrentAmplitude;
  }
}
