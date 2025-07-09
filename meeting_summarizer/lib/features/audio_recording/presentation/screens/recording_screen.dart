/// Recording screen for the meeting summarizer application
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/audio_recording_service.dart';
import '../widgets/circular_waveform_visualizer.dart';
import '../../../../core/enums/recording_state.dart';
import '../../../../core/enums/audio_quality.dart';
import '../../../../core/models/audio_configuration.dart';

/// Main recording screen with audio controls and visualization
class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin {
  // Services
  late final AudioRecordingService _audioService;
  
  // State management
  RecordingState _recordingState = RecordingState.idle;
  Duration _recordingDuration = Duration.zero;
  double _currentAmplitude = 0.0;
  final List<double> _waveformData = [];
  AudioQuality _selectedQuality = AudioQuality.high;
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  
  // Timers
  Timer? _recordingTimer;
  Timer? _amplitudeTimer;
  
  // Constants
  static const Duration _timerInterval = Duration(milliseconds: 100);
  static const Duration _amplitudeInterval = Duration(milliseconds: 50);
  static const int _maxWaveformDataPoints = 100;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeAnimations();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _amplitudeTimer?.cancel();
    _pulseController.dispose();
    _scaleController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  /// Initialize audio recording service
  void _initializeServices() {
    _audioService = AudioRecordingService();
    _audioService.initialize().then((_) {
      setState(() {});
    }).catchError((error) {
      _showErrorSnackBar('Failed to initialize audio service: $error');
    });
  }

  /// Initialize animation controllers
  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }

  /// Start recording audio
  Future<void> _startRecording() async {
    try {
      await HapticFeedback.mediumImpact();
      
      final configuration = AudioConfiguration(
        quality: _selectedQuality,
      );

      await _audioService.startRecording(configuration: configuration);
      
      setState(() {
        _recordingState = RecordingState.recording;
        _recordingDuration = Duration.zero;
        _waveformData.clear();
      });

      _startRecordingTimer();
      _startAmplitudeMonitoring();
      _pulseController.repeat(reverse: true);
      
    } catch (e) {
      _showErrorSnackBar('Failed to start recording: $e');
    }
  }

  /// Stop recording audio
  Future<void> _stopRecording() async {
    try {
      await HapticFeedback.lightImpact();
      
      final filePath = await _audioService.stopRecording();
      
      setState(() {
        _recordingState = RecordingState.stopped;
      });

      _stopTimers();
      _pulseController.stop();
      _pulseController.reset();
      
      if (filePath != null) {
        // Navigate to transcription screen or show success message
        _showSuccessSnackBar('Recording saved successfully');
      }
      
    } catch (e) {
      _showErrorSnackBar('Failed to stop recording: $e');
    }
  }

  /// Pause recording
  Future<void> _pauseRecording() async {
    try {
      await HapticFeedback.lightImpact();
      await _audioService.pauseRecording();
      
      setState(() {
        _recordingState = RecordingState.paused;
      });

      _stopTimers();
      _pulseController.stop();
      
    } catch (e) {
      _showErrorSnackBar('Failed to pause recording: $e');
    }
  }

  /// Resume recording
  Future<void> _resumeRecording() async {
    try {
      await HapticFeedback.mediumImpact();
      await _audioService.resumeRecording();
      
      setState(() {
        _recordingState = RecordingState.recording;
      });

      _startRecordingTimer();
      _startAmplitudeMonitoring();
      _pulseController.repeat(reverse: true);
      
    } catch (e) {
      _showErrorSnackBar('Failed to resume recording: $e');
    }
  }

  /// Start recording duration timer
  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(_timerInterval, (timer) {
      setState(() {
        _recordingDuration += _timerInterval;
      });
    });
  }

  /// Start amplitude monitoring for waveform
  void _startAmplitudeMonitoring() {
    _amplitudeTimer = Timer.periodic(_amplitudeInterval, (timer) async {
      try {
        // Get current session for amplitude data
        final session = _audioService.currentSession;
        if (session != null && session.state.isActive) {
          final amplitude = session.currentAmplitude;
          setState(() {
            _currentAmplitude = amplitude;
            _waveformData.addAll(session.waveformData);
            
            // Keep only recent data points
            if (_waveformData.length > _maxWaveformDataPoints) {
              _waveformData.removeRange(0, _waveformData.length - _maxWaveformDataPoints);
            }
          });
        }
      } catch (e) {
        // Silently handle amplitude reading errors
      }
    });
  }

  /// Stop all timers
  void _stopTimers() {
    _recordingTimer?.cancel();
    _amplitudeTimer?.cancel();
  }

  /// Handle record button press
  Future<void> _handleRecordButton() async {
    await _scaleController.forward();
    await _scaleController.reverse();

    switch (_recordingState) {
      case RecordingState.idle:
      case RecordingState.stopped:
        await _startRecording();
        break;
      case RecordingState.recording:
        await _pauseRecording();
        break;
      case RecordingState.paused:
        await _resumeRecording();
        break;
      case RecordingState.initializing:
      case RecordingState.stopping:
      case RecordingState.processing:
      case RecordingState.error:
        // Do nothing for these states
        break;
    }
  }

  /// Get record button icon based on state
  IconData _getRecordButtonIcon() {
    switch (_recordingState) {
      case RecordingState.idle:
      case RecordingState.stopped:
        return Icons.mic;
      case RecordingState.recording:
        return Icons.pause;
      case RecordingState.paused:
        return Icons.play_arrow;
      case RecordingState.initializing:
        return Icons.hourglass_empty;
      case RecordingState.stopping:
      case RecordingState.processing:
        return Icons.stop;
      case RecordingState.error:
        return Icons.error;
    }
  }

  /// Get record button color based on state
  Color _getRecordButtonColor() {
    switch (_recordingState) {
      case RecordingState.idle:
      case RecordingState.stopped:
        return Colors.red;
      case RecordingState.recording:
        return Colors.orange;
      case RecordingState.paused:
        return Colors.green;
      case RecordingState.initializing:
      case RecordingState.stopping:
      case RecordingState.processing:
        return Colors.blue;
      case RecordingState.error:
        return Colors.grey;
    }
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final centiseconds = ((duration.inMilliseconds % 1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds.$centiseconds';
  }

  /// Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show success snackbar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Meeting Recorder'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_recordingState != RecordingState.stopped)
            IconButton(
              onPressed: _stopRecording,
              icon: const Icon(Icons.stop),
              tooltip: 'Stop Recording',
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Recording Status
              _buildRecordingStatus(theme),
              
              const SizedBox(height: 40),
              
              // Waveform Visualizer
              _buildWaveformVisualizer(screenSize),
              
              const SizedBox(height: 60),
              
              // Recording Controls
              _buildRecordingControls(theme),
              
              const SizedBox(height: 40),
              
              // Audio Quality Selector
              _buildAudioQualitySelector(theme),
              
              const Spacer(),
              
              // Recording Tips
              _buildRecordingTips(theme),
            ],
          ),
        ),
      ),
    );
  }

  /// Build recording status display
  Widget _buildRecordingStatus(ThemeData theme) {
    return Column(
      children: [
        // Recording Duration
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            _formatDuration(_recordingDuration),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Recording State Text
        Text(
          _getStatusText(),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  /// Get status text based on recording state
  String _getStatusText() {
    switch (_recordingState) {
      case RecordingState.idle:
      case RecordingState.stopped:
        return 'Ready to record';
      case RecordingState.initializing:
        return 'Initializing...';
      case RecordingState.recording:
        return 'Recording in progress...';
      case RecordingState.paused:
        return 'Recording paused';
      case RecordingState.stopping:
        return 'Stopping recording...';
      case RecordingState.processing:
        return 'Processing audio...';
      case RecordingState.error:
        return 'Recording error';
    }
  }

  /// Build waveform visualizer
  Widget _buildWaveformVisualizer(Size screenSize) {
    final radius = math.min(screenSize.width, screenSize.height) * 0.25;
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _recordingState == RecordingState.recording 
              ? _pulseAnimation.value 
              : 1.0,
          child: CircularWaveformVisualizer(
            waveformData: _waveformData,
            currentAmplitude: _currentAmplitude,
            radius: radius,
            strokeWidth: 4.0,
            waveColor: _getRecordButtonColor(),
            showCurrentAmplitude: _recordingState == RecordingState.recording,
          ),
        );
      },
    );
  }

  /// Build recording controls
  Widget _buildRecordingControls(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Main Record Button
        AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getRecordButtonColor(),
                  boxShadow: [
                    BoxShadow(
                      color: _getRecordButtonColor().withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: _recordingState == RecordingState.recording ? 5 : 0,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(40),
                    onTap: _handleRecordButton,
                    child: Icon(
                      _getRecordButtonIcon(),
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Build audio quality selector
  Widget _buildAudioQualitySelector(ThemeData theme) {
    if (_recordingState != RecordingState.stopped && _recordingState != RecordingState.idle) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Audio Quality',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: AudioQuality.values.map((quality) {
              return RadioListTile<AudioQuality>(
                title: Text(_getQualityDisplayName(quality)),
                subtitle: Text(_getQualityDescription(quality)),
                value: quality,
                groupValue: _selectedQuality,
                onChanged: (value) {
                  setState(() {
                    _selectedQuality = value!;
                  });
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Get display name for audio quality
  String _getQualityDisplayName(AudioQuality quality) {
    switch (quality) {
      case AudioQuality.low:
        return 'Low Quality';
      case AudioQuality.medium:
        return 'Medium Quality';
      case AudioQuality.high:
        return 'High Quality';
      case AudioQuality.ultra:
        return 'Ultra Quality';
    }
  }

  /// Get description for audio quality
  String _getQualityDescription(AudioQuality quality) {
    switch (quality) {
      case AudioQuality.low:
        return '8 kHz, minimal storage';
      case AudioQuality.medium:
        return '22 kHz, balanced quality';
      case AudioQuality.high:
        return '44.1 kHz, high quality';
      case AudioQuality.ultra:
        return '48 kHz, professional quality';
    }
  }

  /// Build recording tips
  Widget _buildRecordingTips(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Recording Tips',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Keep device close to speakers for best quality\n'
            '• Ensure quiet environment for optimal transcription\n'
            '• Higher quality settings provide better accuracy',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}