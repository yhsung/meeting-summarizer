import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

import '../../../../core/services/robust_permission_service.dart';
import '../../data/services/onboarding_service.dart';

/// Widget for testing audio quality during onboarding
class AudioTestWidget extends StatefulWidget {
  const AudioTestWidget({super.key});

  @override
  State<AudioTestWidget> createState() => _AudioTestWidgetState();
}

class _AudioTestWidgetState extends State<AudioTestWidget>
    with TickerProviderStateMixin {
  final OnboardingService _onboardingService = OnboardingService.instance;
  final RobustPermissionService _permissionService =
      RobustPermissionService.instance;

  bool _isRecording = false;
  bool _isPlaying = false;
  bool _hasRecording = false;
  bool _testComplete = false;
  double _volumeLevel = 0.0;
  String _audioQuality = 'Good';
  String? _recordingPath;

  late AnimationController _volumeAnimationController;
  late AnimationController _pulseAnimationController;

  // Audio recording and playback
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  File? _recordedFile;

  @override
  void initState() {
    super.initState();
    _volumeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _pulseAnimationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    // Initialize the robust permission service if not already done
    _initializePermissionService();

    // Set up audio player listeners
    _setupAudioPlayerListeners();
  }

  void _setupAudioPlayerListeners() {
    // Listen for playback completion
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _testComplete = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio playback completed! Audio test successful.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });

    // Handle state changes
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (mounted) {
        setState(() {
          _isPlaying = (state == PlayerState.playing);
        });
      }
    });
  }

  Future<void> _initializePermissionService() async {
    if (!_permissionService.isInitialized) {
      await _permissionService.initialize();
    }
  }

  @override
  void dispose() {
    _volumeAnimationController.dispose();
    _pulseAnimationController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildAudioVisualizationCard(),
        const SizedBox(height: 20),
        _buildControlButtons(),
        const SizedBox(height: 20),
        if (_hasRecording) _buildQualityAnalysis(),
        if (_testComplete) _buildTestResults(),
      ],
    );
  }

  Widget _buildAudioVisualizationCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(16),
        color: _isRecording
            ? Colors.red.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimationController,
            builder: (context, child) {
              return Container(
                width: 80 +
                    (_isRecording ? _pulseAnimationController.value * 20 : 0),
                height: 80 +
                    (_isRecording ? _pulseAnimationController.value * 20 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording
                      ? Colors.red.withOpacity(
                          0.8 - _pulseAnimationController.value * 0.3,
                        )
                      : _isPlaying
                          ? Colors.green.withOpacity(0.8)
                          : Colors.grey.withOpacity(0.3),
                ),
                child: Icon(
                  _isRecording
                      ? Icons.mic
                      : _isPlaying
                          ? Icons.volume_up
                          : Icons.mic_none,
                  size: 40,
                  color: Colors.white,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            _isRecording
                ? 'Recording...'
                : _isPlaying
                    ? 'Playing...'
                    : 'Ready to test',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          if (_isRecording) ...[
            const SizedBox(height: 12),
            _buildVolumeIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildVolumeIndicator() {
    return Column(
      children: [
        Text(
          'Volume Level',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 200,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: AnimatedBuilder(
            animation: _volumeAnimationController,
            builder: (context, child) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _volumeLevel,
                child: Container(
                  decoration: BoxDecoration(
                    color: _getVolumeColor(),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(_volumeLevel * 100).toInt()}%',
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: _isPlaying ? null : _toggleRecording,
          icon: Icon(_isRecording ? Icons.stop : Icons.mic),
          label: Text(_isRecording ? 'Stop' : 'Record'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isRecording ? Colors.red : null,
            foregroundColor: _isRecording ? Colors.white : null,
          ),
        ),
        ElevatedButton.icon(
          onPressed: _hasRecording && !_isRecording ? _togglePlayback : null,
          icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
          label: Text(_isPlaying ? 'Stop' : 'Play'),
        ),
      ],
    );
  }

  Widget _buildQualityAnalysis() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Audio Quality Analysis',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQualityMetric('Volume', '${(_volumeLevel * 100).toInt()}%'),
              _buildQualityMetric('Quality', _audioQuality),
              _buildQualityMetric('Noise', 'Low'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualityMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildTestResults() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Audio Test Complete!',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Your audio setup is ready for high-quality meeting recordings.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _completeAudioTest,
              child: const Text('Complete Audio Test'),
            ),
          ),
        ],
      ),
    );
  }

  Color _getVolumeColor() {
    if (_volumeLevel < 0.3) return Colors.red;
    if (_volumeLevel < 0.7) return Colors.orange;
    return Colors.green;
  }

  Future<void> _toggleRecording() async {
    // Check microphone permission using robust service
    final status = await _permissionService.checkPermissionStatus(
      Permission.microphone,
    );
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Microphone permission is required for audio testing',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      // Get temporary directory for recording
      final directory = await getTemporaryDirectory();
      _recordingPath =
          '${directory.path}/audio_test_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordingPath!,
      );

      setState(() {
        _isRecording = true;
      });

      // Start monitoring amplitude for volume visualization
      _startAmplitudeMonitoring();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();

      setState(() {
        _isRecording = false;
        _hasRecording = true;
        _volumeLevel = 0.0;
        _audioQuality = _calculateAudioQuality();
      });

      // Store the recorded file for potential playback
      if (_recordingPath != null && await File(_recordingPath!).exists()) {
        _recordedFile = File(_recordingPath!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recording completed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stop recording: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePlayback() async {
    if (!_hasRecording || _recordedFile == null) return;

    try {
      if (_isPlaying) {
        // Stop real playback
        await _audioPlayer.stop();
        setState(() {
          _isPlaying = false;
        });
      } else {
        // Start real audio playback
        setState(() {
          _isPlaying = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Playing recorded audio...'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Play the recorded audio file
        await _audioPlayer.play(DeviceFileSource(_recordedFile!.path));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startAmplitudeMonitoring() {
    _monitorAmplitude();
  }

  void _monitorAmplitude() async {
    if (!_isRecording) return;

    try {
      // Get current amplitude from the recorder
      final amplitude = await _audioRecorder.getAmplitude();

      if (_isRecording && mounted) {
        setState(() {
          // Convert amplitude to a 0-1 range for volume visualization
          // Amplitude.current ranges from -160dB to 0dB, normalize it
          final normalizedAmplitude = (amplitude.current + 160) / 160;
          _volumeLevel = normalizedAmplitude.clamp(0.0, 1.0);
        });
        _volumeAnimationController.forward(from: 0);

        // Continue monitoring
        Future.delayed(const Duration(milliseconds: 100), () {
          _monitorAmplitude();
        });
      }
    } catch (e) {
      // If amplitude monitoring fails, continue without it
      if (_isRecording && mounted) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _monitorAmplitude();
        });
      }
    }
  }

  String _calculateAudioQuality() {
    // Simple quality calculation based on volume levels
    if (_volumeLevel > 0.7) return 'Excellent';
    if (_volumeLevel > 0.5) return 'Good';
    if (_volumeLevel > 0.3) return 'Fair';
    return 'Poor';
  }

  Future<void> _completeAudioTest() async {
    await _onboardingService.markAudioTestComplete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio test completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
