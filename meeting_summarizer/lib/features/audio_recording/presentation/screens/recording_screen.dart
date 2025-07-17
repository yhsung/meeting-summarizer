/// Recording screen for the meeting summarizer application
library;

import 'dart:async';
import 'dart:math' as math hide log;
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/audio_recording_service.dart';
import '../widgets/circular_waveform_visualizer.dart';
import '../widgets/realtime_waveform_controller.dart';
import '../widgets/waveform_settings.dart';
import '../widgets/waveform_stats.dart';
import '../widgets/transcription_settings_dialog.dart';
import '../../../../core/enums/recording_state.dart';
import '../../../../core/enums/audio_quality.dart';
import '../../../../core/enums/audio_format.dart';
import '../../../../core/models/audio_configuration.dart';
import '../../../../core/models/transcription_request.dart';
import '../../../../core/services/transcription_service_factory.dart';
import '../../../../core/services/transcription_settings_service.dart';
import '../../utils/audio_file_analyzer.dart';

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
  AudioFormat _selectedFormat = AudioFormat.aac;
  WaveformType _waveformType = WaveformType.circular;
  bool _showAdvancedWaveform = true;
  bool _showWaveformSettings = false;
  bool _showWaveformStats = false;
  Color _waveformColor = Colors.blue;
  double _averageAmplitude = 0.0;
  double _peakAmplitude = 0.0;

  // Transcription settings
  TranscriptionSettings _transcriptionSettings = TranscriptionSettings(
    provider: TranscriptionProvider.openaiWhisper,
    quality: TranscriptionQuality.balanced,
    enableTimestamps: true,
    enableSpeakerDiarization: false,
  );

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
    _audioService
        .initialize()
        .then((_) {
          setState(() {});
        })
        .catchError((error) {
          _showErrorSnackBar('Failed to initialize audio service: $error');
        });

    // Initialize transcription settings service
    _initializeTranscriptionSettings();
  }

  /// Initialize transcription settings
  void _initializeTranscriptionSettings() {
    TranscriptionSettingsService.instance.initialize().then((_) {
      TranscriptionSettingsService.instance.loadSettings().then((settings) {
        setState(() {
          _transcriptionSettings = settings;
        });
      });
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

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  /// Start recording audio
  Future<void> _startRecording() async {
    try {
      await HapticFeedback.mediumImpact();

      final configuration = AudioConfiguration(
        quality: _selectedQuality,
        format: _selectedFormat,
      );

      await _audioService.startRecording(configuration: configuration);

      setState(() {
        _recordingState = RecordingState.recording;
        _recordingDuration = Duration.zero;
        _waveformData.clear();
        _averageAmplitude = 0.0;
        _peakAmplitude = 0.0;
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
        // Analyze the recorded file to check if it contains audio
        final analysisResult = await AudioFileAnalyzer.analyzeAudioFile(
          filePath,
        );

        if (analysisResult.hasAudio) {
          _showSuccessSnackBar(
            'Recording saved successfully! '
            'File size: ${(analysisResult.fileSize / 1024).toStringAsFixed(1)}KB, '
            'Audio data: ${analysisResult.nonZeroPercentage.toStringAsFixed(1)}% active',
          );
        } else {
          _showErrorSnackBar(
            'Recording file is silent! '
            'File size: ${(analysisResult.fileSize / 1024).toStringAsFixed(1)}KB. '
            'Please check microphone permissions and try again.',
          );
          log('AudioAnalysis: $analysisResult');
        }
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

            // Update statistics
            _updateWaveformStatistics(amplitude);

            // Keep only recent data points
            if (_waveformData.length > _maxWaveformDataPoints) {
              _waveformData.removeRange(
                0,
                _waveformData.length - _maxWaveformDataPoints,
              );
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

  /// Update waveform statistics
  void _updateWaveformStatistics(double amplitude) {
    // Update peak amplitude
    if (amplitude > _peakAmplitude) {
      _peakAmplitude = amplitude;
    }

    // Update average amplitude using exponential moving average
    const alpha = 0.1; // Smoothing factor
    _averageAmplitude = alpha * amplitude + (1 - alpha) * _averageAmplitude;
  }

  /// Handle waveform color changes
  void _handleWaveformColorChange(Color color) {
    setState(() {
      _waveformColor = color;
    });
  }

  /// Handle waveform type changes
  void _handleWaveformTypeChange(WaveformType type) {
    setState(() {
      _waveformType = type;
    });
  }

  /// Handle real-time mode toggle
  void _handleRealtimeToggle(bool enabled) {
    setState(() {
      _showAdvancedWaveform = enabled;
    });
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

  /// Show dialog to select audio quality
  Future<void> _showQualityDialog() async {
    final selected = await showDialog<AudioQuality>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Audio Quality'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: AudioQuality.values.map((quality) {
              return RadioListTile<AudioQuality>(
                title: Text(_getQualityDisplayName(quality)),
                subtitle: Text(_getQualityDescription(quality)),
                value: quality,
                groupValue: _selectedQuality,
                onChanged: (value) {
                  Navigator.of(context).pop(value);
                },
              );
            }).toList(),
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedQuality = selected;
      });
    }
  }

  /// Show dialog to select audio format
  Future<void> _showFormatDialog() async {
    final selected = await showDialog<AudioFormat>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Audio Format'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: AudioFormat.values
                .where((f) => f.isSupportedOnCurrentPlatform)
                .map((format) {
                  return RadioListTile<AudioFormat>(
                    title: Text(format.displayName),
                    subtitle: Text(format.detailedDescription),
                    value: format,
                    groupValue: _selectedFormat,
                    onChanged: (value) {
                      Navigator.of(context).pop(value);
                    },
                  );
                })
                .toList(),
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedFormat = selected;
      });
    }
  }

  /// Show transcription settings dialog
  Future<void> _showTranscriptionSettingsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return TranscriptionSettingsDialog(
          currentProvider: _transcriptionSettings.provider,
          currentQuality: _transcriptionSettings.quality,
          currentLanguage: _transcriptionSettings.language,
          enableTimestamps: _transcriptionSettings.enableTimestamps,
          enableSpeakerDiarization:
              _transcriptionSettings.enableSpeakerDiarization,
          customPrompt: _transcriptionSettings.customPrompt,
          onSaved: (settings) {
            setState(() {
              _transcriptionSettings = settings;
            });
            // Save settings to persistent storage
            TranscriptionSettingsService.instance.saveSettings(settings);
            _showSuccessSnackBar('Transcription settings saved');
          },
        );
      },
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
          PopupMenuButton<int>(
            onSelected: (value) async {
              if (value == 0) {
                setState(() {
                  _showWaveformStats = !_showWaveformStats;
                });
              } else if (value == 1) {
                setState(() {
                  _showWaveformSettings = !_showWaveformSettings;
                });
              } else if (value == 2) {
                await _showQualityDialog();
              } else if (value == 3) {
                await _showFormatDialog();
              } else if (value == 4) {
                await _showTranscriptionSettingsDialog();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 0,
                child: ListTile(
                  leading: Icon(
                    _showWaveformStats
                        ? Icons.analytics
                        : Icons.analytics_outlined,
                  ),
                  title: Text(
                    _showWaveformStats ? 'Hide Statistics' : 'Show Statistics',
                  ),
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: ListTile(
                  leading: Icon(
                    _showWaveformSettings ? Icons.tune : Icons.tune_outlined,
                  ),
                  title: Text(
                    _showWaveformSettings ? 'Hide Settings' : 'Show Settings',
                  ),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 2,
                child: ListTile(
                  leading: const Icon(Icons.high_quality),
                  title: const Text('Audio Quality'),
                  subtitle: Text(_getQualityDisplayName(_selectedQuality)),
                ),
              ),
              PopupMenuItem(
                value: 3,
                child: ListTile(
                  leading: const Icon(Icons.music_note),
                  title: const Text('Audio Format'),
                  subtitle: Text(_selectedFormat.displayName),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 4,
                child: ListTile(
                  leading: const Icon(Icons.transcribe),
                  title: const Text('Transcription Settings'),
                  subtitle: Text(
                    '${TranscriptionServiceFactory.getProviderDisplayName(_transcriptionSettings.provider)} • ${_transcriptionSettings.quality.displayName}',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(child: _buildResponsiveLayout(theme, screenSize)),
    );
  }

  /// Build responsive layout that adapts to different screen sizes
  Widget _buildResponsiveLayout(ThemeData theme, Size screenSize) {
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Calculate responsive spacing and padding
    final EdgeInsets padding;
    final double verticalSpacing;
    final double majorSpacing;

    if (screenWidth > 1200) {
      // Large desktop screens
      padding = const EdgeInsets.symmetric(horizontal: 60.0, vertical: 24.0);
      verticalSpacing = 30.0;
      majorSpacing = 50.0;
    } else if (screenWidth > 800) {
      // Medium desktop/tablet screens
      padding = const EdgeInsets.symmetric(horizontal: 45.0, vertical: 20.0);
      verticalSpacing = 24.0;
      majorSpacing = 40.0;
    } else if (screenWidth > 600) {
      // Small desktop/large tablet
      padding = const EdgeInsets.symmetric(horizontal: 30.0, vertical: 16.0);
      verticalSpacing = 20.0;
      majorSpacing = 32.0;
    } else {
      // Mobile screens
      padding = const EdgeInsets.all(16.0);
      verticalSpacing = 16.0;
      majorSpacing = 24.0;
    }

    // Determine if we should use a wide layout (side-by-side) or narrow layout (stacked)
    final bool useWideLayout = screenWidth > 800 && screenHeight > 600;

    if (useWideLayout) {
      return _buildWideLayout(
        theme,
        screenSize,
        padding,
        verticalSpacing,
        majorSpacing,
      );
    } else {
      return _buildNarrowLayout(
        theme,
        screenSize,
        padding,
        verticalSpacing,
        majorSpacing,
      );
    }
  }

  /// Build layout for wide screens (desktop/tablet landscape)
  Widget _buildWideLayout(
    ThemeData theme,
    Size screenSize,
    EdgeInsets padding,
    double verticalSpacing,
    double majorSpacing,
  ) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          // Left column - Recording status and controls
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildRecordingStatus(theme),
                SizedBox(height: majorSpacing),
                _buildRecordingControls(theme),
                SizedBox(height: verticalSpacing),
              ],
            ),
          ),

          SizedBox(width: majorSpacing),

          // Right column - Waveform visualizer and tips
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildWaveformVisualizer(screenSize),
                  SizedBox(height: verticalSpacing),

                  // Waveform Settings (if enabled)
                  if (_showWaveformSettings)
                    WaveformSettings(
                      waveformType: _waveformType,
                      enableRealtime: _showAdvancedWaveform,
                      waveformColor: _waveformColor,
                      onWaveformTypeChanged: _handleWaveformTypeChange,
                      onRealtimeChanged: _handleRealtimeToggle,
                      onColorChanged: _handleWaveformColorChange,
                      isExpanded: _showWaveformSettings,
                      onExpansionChanged: (expanded) {
                        setState(() {
                          _showWaveformSettings = expanded;
                        });
                      },
                    ),

                  if (_showWaveformSettings) SizedBox(height: verticalSpacing),

                  // Waveform Statistics (if enabled)
                  if (_showWaveformStats)
                    WaveformStats(
                      currentAmplitude: _currentAmplitude,
                      averageAmplitude: _averageAmplitude,
                      peakAmplitude: _peakAmplitude,
                      totalDataPoints: _waveformData.length,
                      recordingDuration: _recordingDuration,
                      isRecording: _recordingState == RecordingState.recording,
                      audioFormat: _selectedFormat.name.toUpperCase(),
                    ),

                  if (_showWaveformStats) SizedBox(height: verticalSpacing),

                  SizedBox(height: majorSpacing),
                  _buildRecordingTips(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build layout for narrow screens (mobile/tablet portrait)
  Widget _buildNarrowLayout(
    ThemeData theme,
    Size screenSize,
    EdgeInsets padding,
    double verticalSpacing,
    double majorSpacing,
  ) {
    return Padding(
      padding: padding,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Recording Status
            _buildRecordingStatus(theme),

            SizedBox(height: verticalSpacing),

            // Waveform Visualizer
            _buildWaveformVisualizer(screenSize),

            SizedBox(height: verticalSpacing),

            // Waveform Settings (if enabled)
            if (_showWaveformSettings)
              WaveformSettings(
                waveformType: _waveformType,
                enableRealtime: _showAdvancedWaveform,
                waveformColor: _waveformColor,
                onWaveformTypeChanged: _handleWaveformTypeChange,
                onRealtimeChanged: _handleRealtimeToggle,
                onColorChanged: _handleWaveformColorChange,
                isExpanded: _showWaveformSettings,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _showWaveformSettings = expanded;
                  });
                },
              ),

            if (_showWaveformSettings) SizedBox(height: verticalSpacing),

            // Waveform Statistics (if enabled)
            if (_showWaveformStats)
              WaveformStats(
                currentAmplitude: _currentAmplitude,
                averageAmplitude: _averageAmplitude,
                peakAmplitude: _peakAmplitude,
                totalDataPoints: _waveformData.length,
                recordingDuration: _recordingDuration,
                isRecording: _recordingState == RecordingState.recording,
                audioFormat: _selectedFormat.name.toUpperCase(),
              ),

            if (_showWaveformStats) SizedBox(height: verticalSpacing),

            SizedBox(height: majorSpacing),

            // Recording Controls
            _buildRecordingControls(theme),

            SizedBox(height: majorSpacing),

            // Recording Tips
            _buildRecordingTips(theme),

            // Add bottom padding for safe area
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  /// Build recording status display with responsive text sizing
  Widget _buildRecordingStatus(ThemeData theme) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive text scaling
    final double textScale;
    final EdgeInsets containerPadding;
    final double borderRadius;

    if (screenWidth > 1200) {
      textScale = 1.1;
      containerPadding = const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 12,
      );
      borderRadius = 18;
    } else if (screenWidth > 800) {
      textScale = 1.0;
      containerPadding = const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 10,
      );
      borderRadius = 16;
    } else if (screenWidth > 600) {
      textScale = 0.95;
      containerPadding = const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      );
      borderRadius = 14;
    } else {
      textScale = 0.85;
      containerPadding = const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      );
      borderRadius = 12;
    }

    return Column(
      children: [
        // Recording Duration
        Container(
          padding: containerPadding,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(borderRadius),
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
              fontSize:
                  (theme.textTheme.headlineMedium?.fontSize ?? 28) * textScale,
            ),
          ),
        ),

        SizedBox(height: 16 * textScale),

        // Recording State Text
        Text(
          _getStatusText(),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: (theme.textTheme.titleMedium?.fontSize ?? 16) * textScale,
          ),
          textAlign: TextAlign.center,
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

  /// Build waveform visualizer with responsive sizing and real-time integration
  Widget _buildWaveformVisualizer(Size screenSize) {
    final theme = Theme.of(context);

    // Responsive dimensions calculation
    final double baseRadius;
    final double waveformWidth;
    final double waveformHeight;

    if (screenSize.width > 1200) {
      baseRadius = math.min(screenSize.width, screenSize.height) * 0.2;
      waveformWidth = 400;
      waveformHeight = 150;
    } else if (screenSize.width > 800) {
      baseRadius = math.min(screenSize.width, screenSize.height) * 0.22;
      waveformWidth = 350;
      waveformHeight = 120;
    } else if (screenSize.width > 600) {
      baseRadius = math.min(screenSize.width, screenSize.height) * 0.25;
      waveformWidth = 300;
      waveformHeight = 100;
    } else {
      baseRadius = math.min(screenSize.width, screenSize.height) * 0.3;
      waveformWidth = 280;
      waveformHeight = 80;
    }

    // Ensure minimum and maximum radius
    final radius = math.max(80.0, math.min(200.0, baseRadius));

    return Column(
      children: [
        // Waveform Type Toggle
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.graphic_eq, color: theme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Waveform',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                SegmentedButton<WaveformType>(
                  segments: const [
                    ButtonSegment(
                      value: WaveformType.circular,
                      icon: Icon(Icons.circle, size: 16),
                      label: Text('Circle'),
                    ),
                    ButtonSegment(
                      value: WaveformType.linear,
                      icon: Icon(Icons.show_chart, size: 16),
                      label: Text('Linear'),
                    ),
                  ],
                  selected: {_waveformType},
                  onSelectionChanged: (Set<WaveformType> selection) {
                    setState(() {
                      _waveformType = selection.first;
                    });
                  },
                ),
                const SizedBox(width: 16),
                Switch(
                  value: _showAdvancedWaveform,
                  onChanged: (value) {
                    setState(() {
                      _showAdvancedWaveform = value;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Text('Real-time', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Waveform Visualizer
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _showAdvancedWaveform
              ? _buildRealtimeWaveform(radius, waveformWidth, waveformHeight)
              : _buildBasicWaveform(radius),
        ),
      ],
    );
  }

  /// Build real-time waveform using RealtimeWaveformController
  Widget _buildRealtimeWaveform(double radius, double width, double height) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: RealtimeWaveformController(
          recordingService: _audioService,
          waveformType: _waveformType,
          waveColor: _waveformColor,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          height: height,
          width: width,
          radius: radius,
          autoStart: true,
          updateInterval: const Duration(milliseconds: 50),
        ),
      ),
    );
  }

  /// Build basic waveform using CircularWaveformVisualizer
  Widget _buildBasicWaveform(double radius) {
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
            waveColor: _waveformColor,
            showCurrentAmplitude: _recordingState == RecordingState.recording,
          ),
        );
      },
    );
  }

  /// Build recording controls with responsive sizing
  Widget _buildRecordingControls(ThemeData theme) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive button sizing
    final double buttonSize;
    final double iconSize;
    final double borderRadius;

    if (screenWidth > 1200) {
      // Large desktop screens
      buttonSize = 80;
      iconSize = 40;
      borderRadius = 40;
    } else if (screenWidth > 800) {
      // Medium desktop/tablet screens
      buttonSize = 70;
      iconSize = 35;
      borderRadius = 35;
    } else if (screenWidth > 600) {
      // Small desktop/large tablet
      buttonSize = 60;
      iconSize = 30;
      borderRadius = 30;
    } else {
      // Mobile screens
      buttonSize = 56;
      iconSize = 28;
      borderRadius = 28;
    }

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
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getRecordButtonColor(),
                  boxShadow: [
                    BoxShadow(
                      color: _getRecordButtonColor().withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: _recordingState == RecordingState.recording
                          ? 5
                          : 0,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(borderRadius),
                    onTap: _handleRecordButton,
                    child: Icon(
                      _getRecordButtonIcon(),
                      size: iconSize,
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

  /// Build recording tips with responsive design
  Widget _buildRecordingTips(ThemeData theme) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive sizing for tips section
    final double textScale;
    final EdgeInsets padding;
    final double borderRadius;
    final double iconSize;

    if (screenWidth > 1200) {
      textScale = 1.1;
      padding = const EdgeInsets.all(20);
      borderRadius = 16;
      iconSize = 24;
    } else if (screenWidth > 800) {
      textScale = 1.05;
      padding = const EdgeInsets.all(18);
      borderRadius = 14;
      iconSize = 22;
    } else if (screenWidth > 600) {
      textScale = 1.0;
      padding = const EdgeInsets.all(16);
      borderRadius = 12;
      iconSize = 20;
    } else {
      textScale = 0.95;
      padding = const EdgeInsets.all(14);
      borderRadius = 10;
      iconSize = 18;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: screenWidth > 800 ? 500 : double.infinity,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: iconSize,
                  color: theme.colorScheme.primary,
                ),
                SizedBox(width: 8 * textScale),
                Text(
                  'Recording Tips',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                    fontSize:
                        (theme.textTheme.titleSmall?.fontSize ?? 14) *
                        textScale,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8 * textScale),
            Text(
              '• Keep device close to speakers for best quality\n'
              '• Ensure quiet environment for optimal transcription\n'
              '• Higher quality settings provide better accuracy',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize:
                    (theme.textTheme.bodySmall?.fontSize ?? 12) * textScale,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
