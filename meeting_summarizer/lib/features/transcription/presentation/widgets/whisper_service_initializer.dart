/// Widget for initializing LocalWhisperService with progress display
library;

import 'package:flutter/material.dart';
import '../../../../core/services/local_whisper_service.dart'
    if (dart.library.html) '../../../../core/services/local_whisper_service_stub.dart';
import 'model_download_progress.dart';

/// Widget that handles LocalWhisperService initialization with progress display
class WhisperServiceInitializer extends StatefulWidget {
  /// Callback when initialization is complete
  final VoidCallback? onInitialized;

  /// Callback when initialization fails
  final Function(String error)? onError;

  /// Whether to show progress in a dialog
  final bool showInDialog;

  const WhisperServiceInitializer({
    super.key,
    this.onInitialized,
    this.onError,
    this.showInDialog = false,
  });

  @override
  State<WhisperServiceInitializer> createState() =>
      _WhisperServiceInitializerState();
}

class _WhisperServiceInitializerState extends State<WhisperServiceInitializer> {
  final LocalWhisperService _whisperService = LocalWhisperService.getInstance();
  double _progress = 0.0;
  String _status = 'Starting initialization...';
  bool _isInitializing = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    setState(() {
      _isInitializing = true;
      _hasError = false;
      _progress = 0.0;
    });

    try {
      await _whisperService.initialize(
        onProgress: (progress, status) {
          setState(() {
            _progress = progress;
            _status = status;
          });
        },
      );

      setState(() {
        _isInitializing = false;
        _status = 'Initialization complete';
      });

      widget.onInitialized?.call();
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _hasError = true;
        _errorMessage = e.toString();
      });

      widget.onError?.call(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showInDialog) {
      return _buildDialog(context);
    }

    return _buildInlineProgress();
  }

  Widget _buildDialog(BuildContext context) {
    return AlertDialog(
      title: const Text('Initializing Whisper Service'),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildProgressContent(),
      ),
      actions: _hasError
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _initializeService();
                },
                child: const Text('Retry'),
              ),
            ]
          : _isInitializing
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
    );
  }

  Widget _buildInlineProgress() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildProgressContent(),
      ),
    );
  }

  Widget _buildProgressContent() {
    if (_hasError) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              const Text('Initialization Failed'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error occurred',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeService,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    if (!_isInitializing && _progress >= 1.0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Service Ready'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Local Whisper service is ready for transcription.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      );
    }

    return ModelDownloadProgress(
      progress: _progress,
      status: _status,
      modelName: 'Whisper Base',
      isDownloading: _isInitializing,
    );
  }
}

/// Utility function to show initialization dialog
Future<void> showWhisperInitializationDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => WhisperServiceInitializer(
      showInDialog: true,
      onInitialized: () {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Whisper service initialized successfully'),
          ),
        );
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Initialization failed: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      },
    ),
  );
}

/// Utility function to show compact progress notification
void showCompactDownloadProgress(
  BuildContext context,
  String modelName,
  double progress,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: CompactModelDownloadProgress(
        progress: progress,
        modelName: modelName,
      ),
      duration: const Duration(seconds: 2),
    ),
  );
}
