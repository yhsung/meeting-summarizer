/// Transcription screen for the meeting summarizer application
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/transcription_result.dart';
import '../../../../core/models/transcription_request.dart';
import '../../../../core/services/transcription_service_interface.dart';
import '../../../../core/services/transcription_service_factory.dart';
import '../../../../core/services/transcription_provider_service.dart';
import '../../../../core/enums/transcription_language.dart';
import '../widgets/transcription_viewer.dart';
import '../widgets/transcription_controls.dart';
import '../widgets/transcription_progress.dart';
import '../widgets/speaker_timeline.dart';
import '../widgets/transcription_settings.dart';

/// Main transcription screen with audio transcription and analysis
class TranscriptionScreen extends StatefulWidget {
  /// Optional audio file to transcribe immediately
  final File? audioFile;

  /// Optional initial transcription result to display
  final TranscriptionResult? initialResult;

  const TranscriptionScreen({super.key, this.audioFile, this.initialResult});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen>
    with TickerProviderStateMixin {
  // Services
  late final TranscriptionServiceInterface _transcriptionService;
  final TranscriptionProviderService _providerService =
      TranscriptionProviderService();

  // State management
  TranscriptionResult? _currentResult;
  File? _currentAudioFile;
  bool _isTranscribing = false;
  bool _isServiceAvailable = false;
  double _transcriptionProgress = 0.0;
  String _statusMessage = 'Ready to transcribe';

  // Settings
  TranscriptionLanguage _selectedLanguage = TranscriptionLanguage.english;
  bool _enableTimestamps = true;
  bool _enableSpeakerDiarization = false;
  bool _enableWordLevelTimestamps = false;

  // UI State
  bool _showSettings = false;
  int _selectedTabIndex = 0;

  // Animation controllers
  late AnimationController _progressController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Constants
  static const Duration _animationDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initializeAnimations();
    _initializeWithProvidedData();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _fadeController.dispose();
    _transcriptionService.dispose();
    super.dispose();
  }

  /// Initialize transcription service
  void _initializeServices() {
    _initializeServicesAsync();
  }

  /// Initialize transcription service asynchronously
  Future<void> _initializeServicesAsync() async {
    try {
      // Get the selected provider
      final selectedProvider = await _providerService
          .getBestAvailableProvider();

      // Provider selected and ready to use

      // Create service instance for selected provider
      _transcriptionService = TranscriptionServiceFactory.getService(
        selectedProvider,
      );

      // Initialize the service
      await _transcriptionService.initialize();

      // Check availability
      await _checkServiceAvailability();
    } catch (error) {
      _showErrorSnackBar('Failed to initialize transcription service: $error');
    }
  }

  /// Initialize animation controllers
  void _initializeAnimations() {
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  /// Initialize with provided data
  void _initializeWithProvidedData() {
    if (widget.initialResult != null) {
      setState(() {
        _currentResult = widget.initialResult;
        _statusMessage = 'Transcription loaded';
      });
      _fadeController.forward();
    } else if (widget.audioFile != null) {
      _currentAudioFile = widget.audioFile;
      _startTranscription();
    }
  }

  /// Check if transcription service is available
  Future<void> _checkServiceAvailability() async {
    try {
      final available = await _transcriptionService.isServiceAvailable();
      setState(() {
        _isServiceAvailable = available;
        _statusMessage = available
            ? 'Ready to transcribe'
            : 'Transcription service unavailable';
      });
    } catch (e) {
      setState(() {
        _isServiceAvailable = false;
        _statusMessage = 'Service check failed';
      });
    }
  }

  /// Start transcription process
  Future<void> _startTranscription() async {
    if (_currentAudioFile == null) {
      _showErrorSnackBar('No audio file selected');
      return;
    }

    if (!_isServiceAvailable) {
      _showErrorSnackBar('Transcription service is not available');
      return;
    }

    setState(() {
      _isTranscribing = true;
      _transcriptionProgress = 0.0;
      _statusMessage = 'Preparing transcription...';
      _currentResult = null;
    });

    _progressController.forward();

    try {
      // Create transcription request
      final request = TranscriptionRequest(
        language: _selectedLanguage,
        enableTimestamps: _enableTimestamps,
        enableSpeakerDiarization: _enableSpeakerDiarization,
        enableWordTimestamps: _enableWordLevelTimestamps,
        audioFormat: _getAudioFormat(_currentAudioFile!),
      );

      // Simulate progress updates
      _startProgressSimulation();

      // Perform transcription
      final result = await _transcriptionService.transcribeAudioFile(
        _currentAudioFile!,
        request,
      );

      // Update UI with result
      setState(() {
        _currentResult = result;
        _isTranscribing = false;
        _transcriptionProgress = 1.0;
        _statusMessage = 'Transcription completed';
      });

      _progressController.stop();
      _fadeController.forward();

      _showSuccessSnackBar('Transcription completed successfully!');
    } catch (e) {
      setState(() {
        _isTranscribing = false;
        _transcriptionProgress = 0.0;
        _statusMessage = 'Transcription failed';
      });

      _progressController.stop();
      _progressController.reset();

      _showErrorSnackBar('Transcription failed: $e');
    }
  }

  /// Simulate progress updates during transcription
  void _startProgressSimulation() {
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isTranscribing) {
        timer.cancel();
        return;
      }

      setState(() {
        _transcriptionProgress = math.min(_transcriptionProgress + 0.05, 0.9);

        if (_transcriptionProgress < 0.3) {
          _statusMessage = 'Analyzing audio...';
        } else if (_transcriptionProgress < 0.6) {
          _statusMessage = 'Processing speech...';
        } else if (_transcriptionProgress < 0.9) {
          _statusMessage = 'Generating transcript...';
        } else {
          _statusMessage = 'Finalizing...';
        }
      });
    });
  }

  /// Get audio format from file extension
  String _getAudioFormat(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    switch (extension) {
      case 'mp3':
        return 'mp3';
      case 'wav':
        return 'wav';
      case 'm4a':
        return 'm4a';
      case 'aac':
        return 'aac';
      default:
        return 'wav';
    }
  }

  /// Handle file selection
  Future<void> _selectAudioFile() async {
    // TODO: Implement file picker
    // For now, show placeholder
    _showInfoSnackBar('File selection will be implemented in next iteration');
  }

  /// Copy transcription to clipboard
  Future<void> _copyToClipboard() async {
    if (_currentResult == null) return;

    await Clipboard.setData(ClipboardData(text: _currentResult!.text));
    _showSuccessSnackBar('Transcription copied to clipboard');
  }

  /// Export transcription
  Future<void> _exportTranscription() async {
    if (_currentResult == null) return;

    // TODO: Implement export functionality
    _showInfoSnackBar(
      'Export functionality will be implemented in next iteration',
    );
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

  /// Show info snackbar
  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
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
        title: const Text('Transcription'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _currentResult != null ? _copyToClipboard : null,
            icon: const Icon(Icons.copy),
            tooltip: 'Copy to Clipboard',
          ),
          IconButton(
            onPressed: _currentResult != null ? _exportTranscription : null,
            icon: const Icon(Icons.download),
            tooltip: 'Export Transcription',
          ),
          PopupMenuButton<int>(
            onSelected: (value) {
              if (value == 0) {
                setState(() {
                  _showSettings = !_showSettings;
                });
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 0,
                child: ListTile(
                  leading: const Icon(Icons.settings),
                  title: Text(
                    _showSettings ? 'Hide Settings' : 'Show Settings',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(child: _buildResponsiveLayout(theme, screenSize)),
      floatingActionButton: _currentResult == null && !_isTranscribing
          ? FloatingActionButton(
              onPressed: _isServiceAvailable ? _selectAudioFile : null,
              tooltip: 'Select Audio File',
              child: const Icon(Icons.audio_file),
            )
          : null,
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
      verticalSpacing = 20.0;
      majorSpacing = 30.0;
    } else if (screenWidth > 800) {
      // Medium desktop/tablet screens
      padding = const EdgeInsets.symmetric(horizontal: 45.0, vertical: 20.0);
      verticalSpacing = 18.0;
      majorSpacing = 26.0;
    } else if (screenWidth > 600) {
      // Small desktop/large tablet
      padding = const EdgeInsets.symmetric(horizontal: 30.0, vertical: 16.0);
      verticalSpacing = 15.0;
      majorSpacing = 22.0;
    } else {
      // Mobile screens
      padding = const EdgeInsets.all(16.0);
      verticalSpacing = 12.0;
      majorSpacing = 16.0;
    }

    // Determine if we should use a wide layout
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column - Controls and settings
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_showSettings) ...[
                  TranscriptionSettings(
                    selectedLanguage: _selectedLanguage,
                    enableTimestamps: _enableTimestamps,
                    enableSpeakerDiarization: _enableSpeakerDiarization,
                    enableWordLevelTimestamps: _enableWordLevelTimestamps,
                    onLanguageChanged: (language) {
                      setState(() {
                        _selectedLanguage = language;
                      });
                    },
                    onTimestampsChanged: (enabled) {
                      setState(() {
                        _enableTimestamps = enabled;
                      });
                    },
                    onSpeakerDiarizationChanged: (enabled) {
                      setState(() {
                        _enableSpeakerDiarization = enabled;
                      });
                    },
                    onWordLevelTimestampsChanged: (enabled) {
                      setState(() {
                        _enableWordLevelTimestamps = enabled;
                      });
                    },
                  ),
                  SizedBox(height: majorSpacing),
                ],

                TranscriptionControls(
                  isTranscribing: _isTranscribing,
                  isServiceAvailable: _isServiceAvailable,
                  hasResult: _currentResult != null,
                  onSelectFile: _selectAudioFile,
                  onStartTranscription: _startTranscription,
                  onCopyToClipboard: _copyToClipboard,
                  onExportTranscription: _exportTranscription,
                ),

                SizedBox(height: majorSpacing),

                if (_isTranscribing) ...[
                  TranscriptionProgress(
                    progress: _transcriptionProgress,
                    statusMessage: _statusMessage,
                  ),
                  SizedBox(height: majorSpacing),
                ],
              ],
            ),
          ),

          SizedBox(width: majorSpacing),

          // Right column - Transcription results
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_currentResult != null) ...[
                  // Tab bar for different views
                  _buildTabBar(theme),
                  SizedBox(height: verticalSpacing),

                  // Tab content
                  Expanded(child: _buildTabContent(theme, screenSize)),
                ] else ...[
                  _buildEmptyState(theme, screenSize),
                ],
              ],
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Settings (collapsible)
            if (_showSettings) ...[
              TranscriptionSettings(
                selectedLanguage: _selectedLanguage,
                enableTimestamps: _enableTimestamps,
                enableSpeakerDiarization: _enableSpeakerDiarization,
                enableWordLevelTimestamps: _enableWordLevelTimestamps,
                onLanguageChanged: (language) {
                  setState(() {
                    _selectedLanguage = language;
                  });
                },
                onTimestampsChanged: (enabled) {
                  setState(() {
                    _enableTimestamps = enabled;
                  });
                },
                onSpeakerDiarizationChanged: (enabled) {
                  setState(() {
                    _enableSpeakerDiarization = enabled;
                  });
                },
                onWordLevelTimestampsChanged: (enabled) {
                  setState(() {
                    _enableWordLevelTimestamps = enabled;
                  });
                },
              ),
              SizedBox(height: majorSpacing),
            ],

            // Controls
            TranscriptionControls(
              isTranscribing: _isTranscribing,
              isServiceAvailable: _isServiceAvailable,
              hasResult: _currentResult != null,
              onSelectFile: _selectAudioFile,
              onStartTranscription: _startTranscription,
              onCopyToClipboard: _copyToClipboard,
              onExportTranscription: _exportTranscription,
            ),

            SizedBox(height: majorSpacing),

            // Progress
            if (_isTranscribing) ...[
              TranscriptionProgress(
                progress: _transcriptionProgress,
                statusMessage: _statusMessage,
              ),
              SizedBox(height: majorSpacing),
            ],

            // Results
            if (_currentResult != null) ...[
              _buildTabBar(theme),
              SizedBox(height: verticalSpacing),

              SizedBox(
                height: screenSize.height * 0.6,
                child: _buildTabContent(theme, screenSize),
              ),
            ] else ...[
              _buildEmptyState(theme, screenSize),
            ],

            // Add bottom padding for safe area
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  /// Build tab bar for different views
  Widget _buildTabBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: null,
        isScrollable: true,
        tabs: [
          Tab(text: 'Transcript'),
          if (_currentResult!.segments.isNotEmpty) Tab(text: 'Timeline'),
          if (_currentResult!.speakers.isNotEmpty) Tab(text: 'Speakers'),
          Tab(text: 'Details'),
        ],
        onTap: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
      ),
    );
  }

  /// Build tab content based on selected tab
  Widget _buildTabContent(ThemeData theme, Size screenSize) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: IndexedStack(
        index: _selectedTabIndex,
        children: [
          // Transcript tab
          TranscriptionViewer(
            result: _currentResult!,
            showTimestamps: _enableTimestamps,
            showSpeakers: _enableSpeakerDiarization,
          ),

          // Timeline tab
          if (_currentResult!.segments.isNotEmpty)
            SpeakerTimeline(result: _currentResult!),

          // Speakers tab
          if (_currentResult!.speakers.isNotEmpty) _buildSpeakersTab(theme),

          // Details tab
          _buildDetailsTab(theme),
        ],
      ),
    );
  }

  /// Build speakers tab content
  Widget _buildSpeakersTab(ThemeData theme) {
    return ListView.builder(
      itemCount: _currentResult!.speakers.length,
      itemBuilder: (context, index) {
        final speaker = _currentResult!.speakers[index];
        return ListTile(
          leading: CircleAvatar(child: Text('${index + 1}')),
          title: Text(speaker.name ?? 'Speaker ${speaker.id}'),
          subtitle: Text(
            'Confidence: ${(speaker.confidence * 100).toStringAsFixed(1)}%',
          ),
        );
      },
    );
  }

  /// Build details tab content
  Widget _buildDetailsTab(ThemeData theme) {
    final result = _currentResult!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailItem(
            theme,
            'Language',
            result.language?.name ?? 'Unknown',
          ),
          _buildDetailItem(
            theme,
            'Confidence',
            '${(result.confidence * 100).toStringAsFixed(1)}%',
          ),
          _buildDetailItem(
            theme,
            'Duration',
            '${(result.audioDurationMs / 1000).toStringAsFixed(1)}s',
          ),
          _buildDetailItem(
            theme,
            'Processing Time',
            '${(result.processingTimeMs / 1000).toStringAsFixed(1)}s',
          ),
          _buildDetailItem(theme, 'Provider', result.provider),
          _buildDetailItem(theme, 'Model', result.model),
          _buildDetailItem(
            theme,
            'Segments',
            result.segments.length.toString(),
          ),
          _buildDetailItem(theme, 'Words', result.words.length.toString()),
          if (result.qualityMetrics != null) ...[
            const Divider(),
            Text('Quality Metrics', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildDetailItem(
              theme,
              'Quality Score',
              result.qualityMetrics!.qualityRating,
            ),
            _buildDetailItem(
              theme,
              'Speech Rate',
              '${result.qualityMetrics!.speechRate.toStringAsFixed(1)} WPM',
            ),
            _buildDetailItem(
              theme,
              'Low Confidence Segments',
              result.qualityMetrics!.lowConfidenceSegments.toString(),
            ),
          ],
        ],
      ),
    );
  }

  /// Build detail item
  Widget _buildDetailItem(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState(ThemeData theme, Size screenSize) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.audio_file_outlined,
            size: 80,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No Transcription Yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select an audio file to start transcription',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
