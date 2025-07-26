import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

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

  late AnimationController _volumeAnimationController;
  late AnimationController _pulseAnimationController;

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
            ? Colors.red.withOpacity(0.05)
            : Colors.grey.withOpacity(0.05),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimationController,
            builder: (context, child) {
              return Container(
                width:
                    80 +
                    (_isRecording ? _pulseAnimationController.value * 20 : 0),
                height:
                    80 +
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

    setState(() {
      _isRecording = !_isRecording;
    });

    if (_isRecording) {
      _startVolumeSimulation();
    } else {
      _stopVolumeSimulation();
      setState(() {
        _hasRecording = true;
        _audioQuality = _calculateAudioQuality();
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (!_hasRecording) return;

    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      // Simulate playback duration
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _testComplete = true;
        });
      }
    }
  }

  void _startVolumeSimulation() {
    // Simulate volume level changes during recording
    _simulateVolumeChanges();
  }

  void _stopVolumeSimulation() {
    // Reset volume level
    setState(() {
      _volumeLevel = 0.0;
    });
  }

  void _simulateVolumeChanges() {
    if (!_isRecording) return;

    // Simulate random volume changes
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_isRecording && mounted) {
        setState(() {
          _volumeLevel =
              0.3 +
              (0.7 * (DateTime.now().millisecondsSinceEpoch % 1000) / 1000);
        });
        _volumeAnimationController.forward(from: 0);
        _simulateVolumeChanges();
      }
    });
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
