import 'package:flutter/material.dart';

class WaveformVisualizer extends StatefulWidget {
  final List<double> waveformData;
  final double currentAmplitude;
  final Color waveColor;
  final Color backgroundColor;
  final double height;
  final double width;
  final bool showCurrentAmplitude;
  final Duration animationDuration;
  final int maxDataPoints;

  const WaveformVisualizer({
    super.key,
    required this.waveformData,
    required this.currentAmplitude,
    this.waveColor = Colors.blue,
    this.backgroundColor = Colors.transparent,
    this.height = 100.0,
    this.width = 300.0,
    this.showCurrentAmplitude = true,
    this.animationDuration = const Duration(milliseconds: 100),
    this.maxDataPoints = 100,
  });

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer>
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
  void didUpdateWidget(WaveformVisualizer oldWidget) {
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
            painter: WaveformPainter(
              waveformData: _displayData,
              waveColor: widget.waveColor,
              animationProgress: _animation.value,
              showCurrentAmplitude: widget.showCurrentAmplitude,
            ),
            size: Size(widget.width, widget.height),
          );
        },
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Color waveColor;
  final double animationProgress;
  final bool showCurrentAmplitude;

  WaveformPainter({
    required this.waveformData,
    required this.waveColor,
    required this.animationProgress,
    required this.showCurrentAmplitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final paint = Paint()
      ..color = waveColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final barWidth = size.width / waveformData.length;
    final maxHeight = size.height * 0.8;

    for (int i = 0; i < waveformData.length; i++) {
      final amplitude = waveformData[i];
      final normalizedAmplitude = amplitude.clamp(0.0, 1.0);
      final barHeight = normalizedAmplitude * maxHeight * animationProgress;

      final x = i * barWidth + barWidth / 2;
      final isCurrentAmplitude =
          showCurrentAmplitude && i == waveformData.length - 1;

      // Use different color for current amplitude
      if (isCurrentAmplitude) {
        paint.color = waveColor.withValues(alpha: 0.8);
        paint.strokeWidth = 3.0;
      } else {
        paint.color = waveColor.withValues(alpha: 0.6);
        paint.strokeWidth = 2.0;
      }

      // Draw waveform bar
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData ||
        oldDelegate.animationProgress != animationProgress ||
        oldDelegate.waveColor != waveColor ||
        oldDelegate.showCurrentAmplitude != showCurrentAmplitude;
  }
}
