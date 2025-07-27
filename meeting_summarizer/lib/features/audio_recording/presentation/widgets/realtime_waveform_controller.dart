import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';

import '../../../../core/models/recording_session.dart';
import '../../data/audio_recording_service.dart';
import 'circular_waveform_visualizer.dart';
import 'waveform_visualizer.dart';

enum WaveformType { linear, circular }

class RealtimeWaveformController extends StatefulWidget {
  final AudioRecordingService recordingService;
  final WaveformType waveformType;
  final Color waveColor;
  final Color backgroundColor;
  final double? height;
  final double? width;
  final double? radius;
  final bool autoStart;
  final Duration updateInterval;

  const RealtimeWaveformController({
    super.key,
    required this.recordingService,
    this.waveformType = WaveformType.linear,
    this.waveColor = Colors.blue,
    this.backgroundColor = Colors.transparent,
    this.height,
    this.width,
    this.radius,
    this.autoStart = true,
    this.updateInterval = const Duration(milliseconds: 50),
  });

  @override
  State<RealtimeWaveformController> createState() =>
      _RealtimeWaveformControllerState();
}

class _RealtimeWaveformControllerState
    extends State<RealtimeWaveformController> {
  StreamSubscription<RecordingSession>? _sessionSubscription;
  RecordingSession? _currentSession;
  Timer? _updateTimer;
  List<double> _waveformData = [];
  double _currentAmplitude = 0.0;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _initializeWaveformTracking();
    if (widget.autoStart) {
      _startWaveformUpdates();
    }
  }

  void _initializeWaveformTracking() {
    _sessionSubscription = widget.recordingService.sessionStream.listen(
      (session) {
        if (mounted) {
          setState(() {
            _currentSession = session;
            _updateWaveformData(session);
            _isActive = session.isActive;
          });
        }
      },
      onError: (error) {
        log('RealtimeWaveformController: Session stream error: $error');
      },
    );

    // Get current session if available
    final currentSession = widget.recordingService.currentSession;
    if (currentSession != null) {
      _currentSession = currentSession;
      _updateWaveformData(currentSession);
      _isActive = currentSession.isActive;
    }
  }

  void _updateWaveformData(RecordingSession session) {
    _waveformData = List<double>.from(session.waveformData);
    _currentAmplitude = session.currentAmplitude;
  }

  void _startWaveformUpdates() {
    _updateTimer = Timer.periodic(widget.updateInterval, (timer) {
      if (_isActive && _currentSession != null) {
        // Trigger rebuild for smooth animation
        if (mounted) {
          setState(() {
            // The data is updated via the stream, this just triggers rebuild
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }

  Widget _buildWaveformVisualizer() {
    switch (widget.waveformType) {
      case WaveformType.linear:
        return WaveformVisualizer(
          waveformData: _waveformData,
          currentAmplitude: _currentAmplitude,
          waveColor: widget.waveColor,
          backgroundColor: widget.backgroundColor,
          height: widget.height ?? 100.0,
          width: widget.width ?? 300.0,
          showCurrentAmplitude: _isActive,
          animationDuration: const Duration(milliseconds: 100),
        );
      case WaveformType.circular:
        return CircularWaveformVisualizer(
          waveformData: _waveformData,
          currentAmplitude: _currentAmplitude,
          waveColor: widget.waveColor,
          backgroundColor: widget.backgroundColor,
          radius: widget.radius ?? 80.0,
          showCurrentAmplitude: _isActive,
          animationDuration: const Duration(milliseconds: 150),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildWaveformVisualizer(),
        if (_currentSession != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isActive ? Icons.mic : Icons.mic_off,
                size: 16,
                color: _isActive ? Colors.red : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                _isActive ? 'Recording...' : 'Not recording',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _isActive ? Colors.red : Colors.grey,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(_currentSession!.duration),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class WaveformVisualizerDemo extends StatefulWidget {
  final AudioRecordingService recordingService;

  const WaveformVisualizerDemo({super.key, required this.recordingService});

  @override
  State<WaveformVisualizerDemo> createState() => _WaveformVisualizerDemoState();
}

class _WaveformVisualizerDemoState extends State<WaveformVisualizerDemo> {
  WaveformType _selectedType = WaveformType.linear;
  Color _selectedColor = Colors.blue;

  final List<Color> _availableColors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.purple,
    Colors.orange,
    Colors.teal,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waveform Visualizer Demo'),
        actions: [
          PopupMenuButton<WaveformType>(
            onSelected: (type) {
              setState(() {
                _selectedType = type;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: WaveformType.linear,
                child: Text('Linear Waveform'),
              ),
              const PopupMenuItem(
                value: WaveformType.circular,
                child: Text('Circular Waveform'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _availableColors.map((color) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: _selectedColor == color
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: Center(
              child: RealtimeWaveformController(
                recordingService: widget.recordingService,
                waveformType: _selectedType,
                waveColor: _selectedColor,
                backgroundColor: Colors.grey.withValues(alpha: 0.1),
                height: 120,
                width: 350,
                radius: 100,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
