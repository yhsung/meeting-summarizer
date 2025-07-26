import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';

import '../../data/services/background_audio_service.dart';
import '../../data/services/background_recording_manager.dart';

class BackgroundRecordingController extends StatefulWidget {
  final BackgroundAudioService audioService;
  final bool showCapabilities;
  final bool autoEnableBackground;
  final VoidCallback? onBackgroundEnabled;
  final VoidCallback? onBackgroundDisabled;
  final Function(BackgroundRecordingEvent)? onBackgroundEvent;

  const BackgroundRecordingController({
    super.key,
    required this.audioService,
    this.showCapabilities = true,
    this.autoEnableBackground = false,
    this.onBackgroundEnabled,
    this.onBackgroundDisabled,
    this.onBackgroundEvent,
  });

  @override
  State<BackgroundRecordingController> createState() =>
      _BackgroundRecordingControllerState();
}

class _BackgroundRecordingControllerState
    extends State<BackgroundRecordingController> {
  StreamSubscription<BackgroundRecordingEvent>? _eventSubscription;
  BackgroundRecordingStatus? _status;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeBackgroundController();
  }

  void _initializeBackgroundController() {
    // Listen to background events
    _eventSubscription = widget.audioService.backgroundEventStream.listen(
      _handleBackgroundEvent,
      onError: (error) {
        log('BackgroundRecordingController: Event error: $error');
      },
    );

    // Get initial status
    _updateStatus();

    // Auto-enable if requested
    if (widget.autoEnableBackground) {
      _enableBackgroundMode();
    }
  }

  void _updateStatus() {
    if (mounted) {
      setState(() {
        _status = widget.audioService.getBackgroundStatus();
      });
    }
  }

  void _handleBackgroundEvent(BackgroundRecordingEvent event) {
    widget.onBackgroundEvent?.call(event);
    _updateStatus();

    // Handle specific events
    switch (event) {
      case BackgroundRecordingEvent.enabled:
        widget.onBackgroundEnabled?.call();
        break;
      case BackgroundRecordingEvent.disabled:
        widget.onBackgroundDisabled?.call();
        break;
      case BackgroundRecordingEvent.backgroundRecordingStarted:
        _showSnackBar('Recording continues in background', Icons.play_arrow);
        break;
      case BackgroundRecordingEvent.backgroundRecordingStopped:
        _showSnackBar(
          'Returned to foreground recording',
          Icons.mobile_friendly,
        );
        break;
      case BackgroundRecordingEvent.recordingPausedForBackground:
        _showSnackBar('Recording paused - background not enabled', Icons.pause);
        break;
      case BackgroundRecordingEvent.recordingResumedFromBackground:
        _showSnackBar('Recording resumed', Icons.play_arrow);
        break;
      case BackgroundRecordingEvent.recordingStoppedForTermination:
        _showSnackBar('Recording saved before app close', Icons.save);
        break;
      case BackgroundRecordingEvent.permissionRequired:
        _showPermissionDialog();
        break;
      case BackgroundRecordingEvent.permissionDenied:
        _showSnackBar('Background permission denied', Icons.error);
        break;
    }
  }

  Future<void> _enableBackgroundMode() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final hasPermissions =
          await widget.audioService.requestBackgroundPermissions();
      if (!hasPermissions) {
        _showSnackBar('Background permissions required', Icons.error);
        return;
      }

      final success = await widget.audioService.enableBackgroundMode();
      if (success) {
        _showSnackBar('Background recording enabled', Icons.check);
      } else {
        _showSnackBar('Failed to enable background recording', Icons.error);
      }
    } catch (e) {
      _showSnackBar('Error enabling background mode', Icons.error);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _disableBackgroundMode() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await widget.audioService.disableBackgroundMode();
      _showSnackBar('Background recording disabled', Icons.check);
    } catch (e) {
      _showSnackBar('Error disabling background mode', Icons.error);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, IconData icon) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(message),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showPermissionDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Background Recording Permission'),
        content: const Text(
          'This app needs permission to continue recording when in the background. '
          'This allows you to minimize the app while recording continues.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _enableBackgroundMode();
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundToggle() {
    final isEnabled = _status?.isBackgroundModeEnabled ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isEnabled ? Icons.play_circle : Icons.pause_circle,
                  color: isEnabled ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Background Recording',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(
                    value: isEnabled,
                    onChanged: (value) {
                      if (value) {
                        _enableBackgroundMode();
                      } else {
                        _disableBackgroundMode();
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isEnabled
                  ? 'Recording will continue when app is minimized'
                  : 'Recording will pause when app is minimized',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundStatus() {
    if (_status == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Background Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            _buildStatusRow(
              'App State',
              _status!.isInBackground ? 'Background' : 'Foreground',
              _status!.isInBackground ? Colors.orange : Colors.green,
            ),
            _buildStatusRow(
              'Background Mode',
              _status!.isBackgroundModeEnabled ? 'Enabled' : 'Disabled',
              _status!.isBackgroundModeEnabled ? Colors.green : Colors.grey,
            ),
            _buildStatusRow(
              'Recording Status',
              _getRecordingStatusText(),
              _getRecordingStatusColor(),
            ),
            if (_status!.isRecordingInBackground) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.record_voice_over,
                      color: Colors.orange,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Currently recording in background',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label:', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRecordingStatusText() {
    if (_status!.isRecordingInBackground) return 'Recording (Background)';
    if (_status!.currentSession?.isActive == true) {
      return 'Recording (Foreground)';
    }
    if (_status!.currentSession?.isPaused == true) return 'Paused';
    return 'Not Recording';
  }

  Color _getRecordingStatusColor() {
    if (_status!.isRecordingInBackground) return Colors.orange;
    if (_status!.currentSession?.isActive == true) return Colors.green;
    if (_status!.currentSession?.isPaused == true) return Colors.amber;
    return Colors.grey;
  }

  Widget _buildCapabilities() {
    if (!widget.showCapabilities || _status == null) {
      return const SizedBox.shrink();
    }

    final capabilities = _status!.capabilities;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platform Capabilities (${capabilities.platformName})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            _buildCapabilityRow(
              'Background Support',
              capabilities.supportsBackground,
            ),
            _buildCapabilityRow(
              'Requires Permission',
              capabilities.requiresPermission,
            ),
            _buildCapabilityRow(
              'Supports Notification',
              capabilities.supportsNotification,
            ),
            if (capabilities.maxBackgroundDuration != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  'Max Background Time: ${_formatDuration(capabilities.maxBackgroundDuration!)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityRow(String label, bool supported) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            supported ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: supported ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}m ${seconds}s';
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBackgroundToggle(),
        const SizedBox(height: 8),
        _buildBackgroundStatus(),
        const SizedBox(height: 8),
        _buildCapabilities(),
      ],
    );
  }
}
