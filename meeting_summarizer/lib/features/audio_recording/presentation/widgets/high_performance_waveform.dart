import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'waveform_visualizer.dart';

class HighPerformanceWaveform extends StatefulWidget {
  final List<double> waveformData;
  final double currentAmplitude;
  final Color waveColor;
  final Color backgroundColor;
  final double height;
  final double width;
  final bool showCurrentAmplitude;
  final Duration animationDuration;
  final int maxDataPoints;
  final double strokeWidth;
  final bool enableGlow;
  final bool enableSmoothing;

  const HighPerformanceWaveform({
    super.key,
    required this.waveformData,
    required this.currentAmplitude,
    this.waveColor = Colors.blue,
    this.backgroundColor = Colors.transparent,
    this.height = 100.0,
    this.width = 300.0,
    this.showCurrentAmplitude = true,
    this.animationDuration = const Duration(milliseconds: 50),
    this.maxDataPoints = 150,
    this.strokeWidth = 2.0,
    this.enableGlow = true,
    this.enableSmoothing = true,
  });

  @override
  State<HighPerformanceWaveform> createState() =>
      _HighPerformanceWaveformState();
}

class _HighPerformanceWaveformState extends State<HighPerformanceWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  Float32List _displayData = Float32List(0);
  Float32List _smoothedData = Float32List(0);
  bool _needsUpdate = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _updateDisplayData();
  }

  @override
  void didUpdateWidget(HighPerformanceWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.waveformData != widget.waveformData ||
        oldWidget.currentAmplitude != widget.currentAmplitude) {
      _updateDisplayData();
      if (!_animationController.isAnimating) {
        _animationController.forward(from: 0.0);
      }
    }
  }

  void _updateDisplayData() {
    final data = widget.waveformData;

    // Create optimized data array
    final targetLength = math.min(data.length, widget.maxDataPoints);
    _displayData = Float32List(targetLength);

    if (data.isNotEmpty) {
      // Downsample data if needed for performance
      if (data.length > widget.maxDataPoints) {
        final step = data.length / widget.maxDataPoints;
        for (int i = 0; i < targetLength; i++) {
          final sourceIndex = (i * step).floor();
          _displayData[i] = data[sourceIndex].clamp(0.0, 1.0);
        }
      } else {
        for (int i = 0; i < targetLength; i++) {
          _displayData[i] = data[i].clamp(0.0, 1.0);
        }
      }

      // Add current amplitude if showing real-time data
      if (widget.showCurrentAmplitude && widget.currentAmplitude > 0) {
        if (targetLength > 0) {
          _displayData[targetLength - 1] = widget.currentAmplitude.clamp(
            0.0,
            1.0,
          );
        }
      }

      // Apply smoothing if enabled
      if (widget.enableSmoothing) {
        _applySmoothingFilter();
      }
    }

    _needsUpdate = true;
  }

  void _applySmoothingFilter() {
    if (_displayData.length < 3) return;

    _smoothedData = Float32List.fromList(_displayData);

    // Apply simple moving average smoothing
    for (int i = 1; i < _smoothedData.length - 1; i++) {
      _smoothedData[i] =
          (_displayData[i - 1] + _displayData[i] + _displayData[i + 1]) / 3;
    }

    _displayData = _smoothedData;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            painter: HighPerformanceWaveformPainter(
              waveformData: _displayData,
              waveColor: widget.waveColor,
              strokeWidth: widget.strokeWidth,
              animationProgress: _animation.value,
              showCurrentAmplitude: widget.showCurrentAmplitude,
              enableGlow: widget.enableGlow,
              needsUpdate: _needsUpdate,
            ),
            size: Size(widget.width, widget.height),
          );
        },
      ),
    );
  }
}

class HighPerformanceWaveformPainter extends CustomPainter {
  final Float32List waveformData;
  final Color waveColor;
  final double strokeWidth;
  final double animationProgress;
  final bool showCurrentAmplitude;
  final bool enableGlow;
  final bool needsUpdate;

  // Cache for optimization
  static Path? _cachedPath;
  static Paint? _cachedPaint;
  static Paint? _cachedGlowPaint;

  HighPerformanceWaveformPainter({
    required this.waveformData,
    required this.waveColor,
    required this.strokeWidth,
    required this.animationProgress,
    required this.showCurrentAmplitude,
    required this.enableGlow,
    required this.needsUpdate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    // Initialize cached objects if needed
    _cachedPath ??= Path();
    _cachedPaint ??= Paint();
    _cachedGlowPaint ??= Paint();

    // Configure paint objects
    _cachedPaint!
      ..color = waveColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (enableGlow) {
      _cachedGlowPaint!
        ..color = waveColor.withValues(alpha: 0.3)
        ..strokeWidth = strokeWidth + 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    }

    final centerY = size.height / 2;
    final barWidth = size.width / waveformData.length;
    final maxHeight = size.height * 0.8;

    // Reset path
    _cachedPath!.reset();

    // Build path for smooth waveform
    bool firstPoint = true;
    for (int i = 0; i < waveformData.length; i++) {
      final amplitude = waveformData[i];
      final barHeight = amplitude * maxHeight * animationProgress;
      final x = i * barWidth + barWidth / 2;
      final y = centerY - barHeight / 2;

      if (firstPoint) {
        _cachedPath!.moveTo(x, y);
        firstPoint = false;
      } else {
        _cachedPath!.lineTo(x, y);
      }
    }

    // Draw glow effect if enabled
    if (enableGlow) {
      canvas.drawPath(_cachedPath!, _cachedGlowPaint!);
    }

    // Draw main waveform
    canvas.drawPath(_cachedPath!, _cachedPaint!);

    // Draw current amplitude indicator
    if (showCurrentAmplitude && waveformData.isNotEmpty) {
      final currentAmplitude = waveformData[waveformData.length - 1];
      final currentX = size.width - barWidth / 2;

      // Draw current amplitude as a pulsing circle
      final pulsePaint = Paint()
        ..color = waveColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      final pulseRadius = 3.0 + currentAmplitude * 2.0;
      canvas.drawCircle(Offset(currentX, centerY), pulseRadius, pulsePaint);
    }
  }

  @override
  bool shouldRepaint(HighPerformanceWaveformPainter oldDelegate) {
    return needsUpdate ||
        oldDelegate.waveformData != waveformData ||
        oldDelegate.animationProgress != animationProgress ||
        oldDelegate.waveColor != waveColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.showCurrentAmplitude != showCurrentAmplitude ||
        oldDelegate.enableGlow != enableGlow;
  }
}

class AdaptiveWaveformWidget extends StatelessWidget {
  final List<double> waveformData;
  final double currentAmplitude;
  final Color waveColor;
  final Color backgroundColor;
  final double height;
  final double width;
  final bool showCurrentAmplitude;
  final bool highPerformanceMode;

  const AdaptiveWaveformWidget({
    super.key,
    required this.waveformData,
    required this.currentAmplitude,
    this.waveColor = Colors.blue,
    this.backgroundColor = Colors.transparent,
    this.height = 100.0,
    this.width = 300.0,
    this.showCurrentAmplitude = true,
    this.highPerformanceMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // Choose appropriate widget based on performance requirements
    if (highPerformanceMode || waveformData.length > 100) {
      return HighPerformanceWaveform(
        waveformData: waveformData,
        currentAmplitude: currentAmplitude,
        waveColor: waveColor,
        backgroundColor: backgroundColor,
        height: height,
        width: width,
        showCurrentAmplitude: showCurrentAmplitude,
        enableGlow: true,
        enableSmoothing: true,
      );
    } else {
      return WaveformVisualizer(
        waveformData: waveformData,
        currentAmplitude: currentAmplitude,
        waveColor: waveColor,
        backgroundColor: backgroundColor,
        height: height,
        width: width,
        showCurrentAmplitude: showCurrentAmplitude,
      );
    }
  }
}
