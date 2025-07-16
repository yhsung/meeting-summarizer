/// Example of LocalWhisperService with Enhanced BSD Logging
///
/// This demonstrates how to migrate from debugPrint to structured BSD logging
/// while maintaining the same functionality but with better observability.
library;

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import 'transcription_service_interface.dart';
import '../models/transcription_request.dart';
import '../models/transcription_result.dart';
import '../models/transcription_usage_stats.dart';
import '../enums/transcription_language.dart';
import 'transcription_error_handler.dart';
import 'transcription_usage_monitor.dart';
import 'bsd_logger_service.dart';
import 'logger_extensions.dart';

/// Enhanced LocalWhisperService with structured logging
class LocalWhisperServiceWithLogging
    with LoggerMixin
    implements TranscriptionServiceInterface {
  static const String _modelDirectory = 'whisper_models';
  static const String _defaultModel = 'whisper-base';

  // Singleton pattern
  static LocalWhisperServiceWithLogging? _instance;
  static LocalWhisperServiceWithLogging getInstance() {
    _instance ??= LocalWhisperServiceWithLogging._internal();
    return _instance!;
  }

  LocalWhisperServiceWithLogging._internal();

  String _currentModel = _defaultModel;
  bool _isInitialized = false;
  Directory? _modelStorageDirectory;
  Whisper? _whisperInstance;

  final TranscriptionUsageMonitor _usageMonitor =
      TranscriptionUsageMonitor.getInstance();

  @override
  Future<void> initialize({
    Function(double progress, String status)? onProgress,
  }) async {
    logEntry(
      'initialize',
      parameters: {'hasProgressCallback': onProgress != null},
    );

    onProgress?.call(0.0, 'Initializing service...');

    if (_isInitialized) {
      logger.info('Service already initialized', facility: LogFacility.daemon);
      onProgress?.call(1.0, 'Service ready');
      return;
    }

    final stopwatch = Stopwatch()..start();

    try {
      // Setup model storage directory
      await _setupModelStorageDirectory();

      if (!await _modelStorageDirectory!.exists()) {
        await _modelStorageDirectory!.create(recursive: true);
        logger.info(
          'Created model storage directory',
          facility: LogFacility.daemon,
          data: {'path': _modelStorageDirectory!.path},
        );
      }

      // Initialize usage monitor
      await _usageMonitor.initialize();

      // Mark as initialized
      _isInitialized = true;

      // Initialize Whisper instance
      _whisperInstance = Whisper(
        model: _getWhisperModel(_currentModel),
        downloadHost:
            'https://huggingface.co/ggerganov/whisper.cpp/resolve/main',
      );

      // Check for default model
      final hasDefaultModel = await _isModelAvailable(_defaultModel);
      if (!hasDefaultModel) {
        logger.warning(
          'Default model not found, downloading automatically',
          facility: LogFacility.daemon,
          data: {'model': _defaultModel},
        );

        onProgress?.call(0.1, 'Downloading default model...');

        try {
          await _downloadModelWithLogging(_defaultModel, onProgress);
          logger.info(
            'Default model downloaded successfully',
            facility: LogFacility.daemon,
            data: {'model': _defaultModel},
          );
          onProgress?.call(0.9, 'Model download completed');
        } catch (e) {
          logger.error(
            'Failed to download default model',
            facility: LogFacility.daemon,
            data: {
              'model': _defaultModel,
              'error': e.toString(),
              'continued': true,
            },
          );
          onProgress?.call(0.9, 'Model download failed, continuing...');
        }
      } else {
        logger.info(
          'Default model already available',
          facility: LogFacility.daemon,
          data: {'model': _defaultModel},
        );
        onProgress?.call(0.9, 'Model already available');
      }

      stopwatch.stop();
      onProgress?.call(1.0, 'Service ready');

      logExit('initialize', result: 'success', duration: stopwatch.elapsed);
    } catch (e) {
      stopwatch.stop();
      _isInitialized = false;

      logError(
        'Initialization failed',
        e,
        methodName: 'initialize',
        stackTrace: StackTrace.current,
      );

      throw TranscriptionError(
        type: TranscriptionErrorType.configurationError,
        message: 'Failed to initialize local Whisper service: $e',
        originalError: e,
        isRetryable: false,
      );
    }
  }

  @override
  Future<bool> isServiceAvailable() async {
    logEntry('isServiceAvailable');

    logger.debug(
      'Checking service availability',
      data: {'isInitialized': _isInitialized},
    );

    if (!_isInitialized) {
      logger.debug('Service not initialized, checking if models exist');

      await _setupModelStorageDirectory();

      for (final modelName in [
        'whisper-tiny',
        'whisper-base',
        'whisper-small',
      ]) {
        final isAvailable = await _isModelAvailable(modelName);
        logger.debug(
          'Model availability check',
          data: {'model': modelName, 'available': isAvailable},
        );

        if (isAvailable) {
          logger.warning(
            'Model found but service not initialized',
            data: {'model': modelName},
          );
          logExit('isServiceAvailable', result: false);
          return false;
        }
      }

      logger.info('Service not initialized and no models available');
      logExit('isServiceAvailable', result: false);
      return false;
    }

    // Check if at least one model is available
    for (final modelName in ['whisper-tiny', 'whisper-base', 'whisper-small']) {
      final isAvailable = await _isModelAvailable(modelName);
      if (isAvailable) {
        logger.info('Service is available', data: {'model': modelName});
        logExit('isServiceAvailable', result: true);
        return true;
      }
    }

    logger.warning('Service initialized but no models available');
    logExit('isServiceAvailable', result: false);
    return false;
  }

  @override
  Future<TranscriptionResult> transcribeAudioFile(
    File audioFile,
    TranscriptionRequest request,
  ) async {
    return timeMethod('transcribeAudioFile', () async {
      logger.info(
        'Starting local transcription',
        facility: LogFacility.daemon,
        data: {
          'audioFile': audioFile.path,
          'language': request.language?.displayName,
          'model': _currentModel,
        },
      );

      if (!_isInitialized) {
        throw TranscriptionError(
          type: TranscriptionErrorType.configurationError,
          message: 'Local Whisper service not initialized',
          isRetryable: false,
        );
      }

      final startTime = DateTime.now();

      try {
        // Validate file
        await _validateAudioFile(audioFile);

        // Read file bytes
        final audioBytes = await audioFile.readAsBytes();

        // Get audio duration
        final audioDurationMs = await _estimateAudioDuration(audioFile);

        // Log file information
        logger.info(
          'Audio file prepared for transcription',
          facility: LogFacility.daemon,
          data: {
            'fileSize': audioBytes.length,
            'estimatedDuration': audioDurationMs,
            'format': audioFile.path.split('.').last,
          },
        );

        // Process transcription
        final result = await _processLocalTranscription(
          audioBytes,
          audioFile.path,
          request,
        );

        final processingTime = DateTime.now().difference(startTime);

        // Record usage statistics
        await _usageMonitor.recordTranscriptionRequest(
          success: true,
          processingTime: processingTime,
          audioDurationMs: audioDurationMs,
          provider: 'local_whisper',
          additionalMetrics: {
            'model': _currentModel,
            'audio_file_size_bytes': audioBytes.length,
            'audio_format': audioFile.path.split('.').last,
          },
        );

        logger.info(
          'Local transcription completed successfully',
          facility: LogFacility.daemon,
          data: {
            'processingTime': processingTime.inMilliseconds,
            'textLength': result.text.length,
            'confidence': result.confidence,
            'segmentCount': result.segments?.length,
          },
        );

        return result;
      } catch (e) {
        final processingTime = DateTime.now().difference(startTime);

        // Record failed request
        String? errorType;
        if (e is TranscriptionError) {
          errorType = e.type.name;
        }

        await _usageMonitor.recordTranscriptionRequest(
          success: false,
          processingTime: processingTime,
          audioDurationMs: 0,
          provider: 'local_whisper',
          errorType: errorType,
          additionalMetrics: {
            'model': _currentModel,
            'error_message': e.toString(),
          },
        );

        logger.error(
          'Local transcription failed',
          facility: LogFacility.daemon,
          data: {
            'processingTime': processingTime.inMilliseconds,
            'errorType': errorType,
            'audioFile': audioFile.path,
          },
        );

        rethrow;
      }
    });
  }

  /// Enhanced model download with structured logging
  Future<void> _downloadModelWithLogging(
    String modelName,
    Function(double progress, String status)? onProgress,
  ) async {
    logger.info(
      'Starting model download',
      facility: LogFacility.daemon,
      data: {'model': modelName},
    );

    return timeMethod('_downloadModelWithLogging', () async {
      // Implementation would go here with structured logging
      // for download progress, network errors, file I/O, etc.

      logger.info(
        'Model download completed',
        facility: LogFacility.daemon,
        data: {'model': modelName},
      );
    });
  }

  /// Example of how to log validation with context
  Future<void> _validateAudioFile(File audioFile) async {
    logEntry('_validateAudioFile', parameters: {'file': audioFile.path});

    try {
      if (!await audioFile.exists()) {
        throw TranscriptionError.audioFormatError(
          'Audio file does not exist: ${audioFile.path}',
        );
      }

      final fileSize = await audioFile.length();
      if (fileSize == 0) {
        throw TranscriptionError.audioFormatError(
          'Audio file is empty: ${audioFile.path}',
        );
      }

      const maxFileSizeBytes = 100 * 1024 * 1024; // 100MB
      if (fileSize > maxFileSizeBytes) {
        throw TranscriptionError.fileSizeError(
          'Audio file too large: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB',
          fileSize: fileSize,
          maxSize: maxFileSizeBytes,
        );
      }

      final extension = audioFile.path.split('.').last.toLowerCase();
      const supportedFormats = ['mp3', 'wav', 'm4a', 'flac', 'ogg'];
      if (!supportedFormats.contains(extension)) {
        throw TranscriptionError.audioFormatError(
          'Unsupported audio format: $extension',
          format: extension,
        );
      }

      logger.debug(
        'Audio file validation passed',
        data: {'file': audioFile.path, 'size': fileSize, 'format': extension},
      );

      logExit('_validateAudioFile', result: 'valid');
    } catch (e) {
      logError(
        'Audio file validation failed',
        e,
        methodName: '_validateAudioFile',
      );
      rethrow;
    }
  }

  // Simplified implementations for demo purposes
  Future<void> _setupModelStorageDirectory() async {
    if (_modelStorageDirectory == null) {
      final appSupportDir = await getApplicationSupportDirectory();
      _modelStorageDirectory = Directory(
        path.join(appSupportDir.path, _modelDirectory),
      );
    }
  }

  WhisperModel _getWhisperModel(String modelName) {
    switch (modelName) {
      case 'whisper-tiny':
        return WhisperModel.tiny;
      case 'whisper-base':
        return WhisperModel.base;
      case 'whisper-small':
        return WhisperModel.small;
      default:
        return WhisperModel.base;
    }
  }

  Future<bool> _isModelAvailable(String modelName) async {
    // Simplified implementation
    return false;
  }

  Future<int> _estimateAudioDuration(File audioFile) async {
    // Simplified implementation
    return 0;
  }

  Future<TranscriptionResult> _processLocalTranscription(
    List<int> audioBytes,
    String audioPath,
    TranscriptionRequest request,
  ) async {
    // Simplified implementation
    return TranscriptionResult(
      text: 'Demo transcription',
      confidence: 0.95,
      processingTimeMs: 1000,
      audioDurationMs: 5000,
      provider: 'local_whisper',
      model: _currentModel,
      createdAt: DateTime.now(),
    );
  }

  // Implement other required methods...
  @override
  Future<TranscriptionResult> transcribeAudioBytes(
    List<int> audioBytes,
    TranscriptionRequest request,
  ) async {
    // Implementation with logging...
    throw UnimplementedError();
  }

  @override
  Future<List<TranscriptionLanguage>> getSupportedLanguages() async {
    // Implementation with logging...
    throw UnimplementedError();
  }

  @override
  Future<TranscriptionLanguage?> detectLanguage(File audioFile) async {
    // Implementation with logging...
    throw UnimplementedError();
  }

  @override
  Future<TranscriptionUsageStats> getUsageStats() async {
    return _usageMonitor.getCurrentStats();
  }

  @override
  Future<void> dispose() async {
    logger.info('Disposing local service');
    _isInitialized = false;
  }
}
