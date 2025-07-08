/// Local Whisper service implementation for offline transcription
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'transcription_service_interface.dart';
import '../models/transcription_request.dart';
import '../models/transcription_result.dart';
import '../models/transcription_usage_stats.dart';
import '../enums/transcription_language.dart';
import 'transcription_error_handler.dart';
import 'transcription_usage_monitor.dart';

/// Local Whisper service implementation for offline transcription
class LocalWhisperService implements TranscriptionServiceInterface {
  static const String _modelDirectory = 'whisper_models';
  static const String _defaultModel = 'whisper-base';

  // Available local models with their capabilities
  static const Map<String, LocalWhisperModel> _availableModels = {
    'whisper-tiny': LocalWhisperModel(
      name: 'whisper-tiny',
      size: 39, // MB
      qualityLevel: WhisperQuality.low,
      languages: 25,
      downloadUrl:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin',
    ),
    'whisper-base': LocalWhisperModel(
      name: 'whisper-base',
      size: 142, // MB
      qualityLevel: WhisperQuality.medium,
      languages: 50,
      downloadUrl:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin',
    ),
    'whisper-small': LocalWhisperModel(
      name: 'whisper-small',
      size: 466, // MB
      qualityLevel: WhisperQuality.high,
      languages: 95,
      downloadUrl:
          'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin',
    ),
  };

  String _currentModel = _defaultModel;
  bool _isInitialized = false;
  Directory? _modelStorageDirectory;

  // Usage monitoring
  final TranscriptionUsageMonitor _usageMonitor =
      TranscriptionUsageMonitor.getInstance();

  @override
  Future<void> initialize() async {
    debugPrint('LocalWhisperService: Initializing local Whisper service');

    try {
      // Setup model storage directory
      final appSupportDir = await getApplicationSupportDirectory();
      _modelStorageDirectory = Directory(
        path.join(appSupportDir.path, _modelDirectory),
      );

      if (!await _modelStorageDirectory!.exists()) {
        await _modelStorageDirectory!.create(recursive: true);
        debugPrint(
          'LocalWhisperService: Created model storage directory: ${_modelStorageDirectory!.path}',
        );
      }

      // Check if default model is available
      final hasDefaultModel = await _isModelAvailable(_defaultModel);
      if (!hasDefaultModel) {
        debugPrint(
          'LocalWhisperService: Default model not found, service will be limited until model is downloaded',
        );
      }

      // Initialize usage monitor
      await _usageMonitor.initialize();

      _isInitialized = true;
      debugPrint('LocalWhisperService: Initialization complete');
    } catch (e) {
      debugPrint('LocalWhisperService: Initialization failed: $e');
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
    if (!_isInitialized) {
      return false;
    }

    // Check if at least one model is available
    for (final modelName in _availableModels.keys) {
      if (await _isModelAvailable(modelName)) {
        return true;
      }
    }

    return false;
  }

  @override
  Future<TranscriptionResult> transcribeAudioFile(
    File audioFile,
    TranscriptionRequest request,
  ) async {
    debugPrint(
      'LocalWhisperService: Starting local transcription for file: ${audioFile.path}',
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

      // Get audio duration (approximate)
      final audioDurationMs = await _estimateAudioDuration(audioFile);

      // Process transcription locally
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

      debugPrint(
        'LocalWhisperService: Local transcription completed successfully',
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

      debugPrint('LocalWhisperService: Local transcription failed: $e');
      rethrow;
    }
  }

  @override
  Future<TranscriptionResult> transcribeAudioBytes(
    List<int> audioBytes,
    TranscriptionRequest request,
  ) async {
    debugPrint(
      'LocalWhisperService: Starting local transcription for audio bytes',
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
      // Validate audio data
      _validateAudioBytes(audioBytes);

      // Estimate duration (rough estimate based on file size)
      final audioDurationMs = _estimateAudioDurationFromBytes(
        audioBytes,
        request.audioFormat,
      );

      // Process transcription locally
      final result = await _processLocalTranscription(
        audioBytes,
        'audio_data',
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
          'audio_data_size_bytes': audioBytes.length,
          'audio_format': request.audioFormat ?? 'unknown',
        },
      );

      debugPrint(
        'LocalWhisperService: Local transcription completed successfully',
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

      debugPrint('LocalWhisperService: Local transcription failed: $e');
      rethrow;
    }
  }

  @override
  Future<List<TranscriptionLanguage>> getSupportedLanguages() async {
    // Local Whisper supports fewer languages than the API version
    // Return based on current model capabilities
    final model = _availableModels[_currentModel];
    if (model == null) {
      return TranscriptionLanguage.commonLanguages;
    }

    // Return appropriate language subset based on model
    switch (model.languages) {
      case 25:
        return TranscriptionLanguage.commonLanguages.take(25).toList();
      case 50:
        return TranscriptionLanguage.commonLanguages;
      case 95:
        return TranscriptionLanguage.values;
      default:
        return TranscriptionLanguage.commonLanguages;
    }
  }

  @override
  Future<TranscriptionLanguage?> detectLanguage(File audioFile) async {
    debugPrint(
      'LocalWhisperService: Detecting language for file: ${audioFile.path}',
    );

    try {
      // Create a request with auto language detection
      final request = TranscriptionRequest(
        language: TranscriptionLanguage.auto,
        responseFormat: 'json',
      );

      // Transcribe with language detection (using smaller sample for efficiency)
      final result = await transcribeAudioFile(audioFile, request);

      debugPrint(
        'LocalWhisperService: Detected language: ${result.language?.displayName}',
      );
      return result.language;
    } catch (e) {
      debugPrint('LocalWhisperService: Language detection failed: $e');
      return null;
    }
  }

  @override
  Future<TranscriptionUsageStats> getUsageStats() async {
    return _usageMonitor.getCurrentStats();
  }

  @override
  Future<void> dispose() async {
    debugPrint('LocalWhisperService: Disposing local service');
    _isInitialized = false;
  }

  /// Check if a specific model is available locally
  Future<bool> _isModelAvailable(String modelName) async {
    if (_modelStorageDirectory == null) return false;

    final modelFile = File(
      path.join(_modelStorageDirectory!.path, '$modelName.bin'),
    );
    return await modelFile.exists();
  }

  /// Download a Whisper model for local use
  Future<void> downloadModel(
    String modelName, {
    Function(double)? onProgress,
  }) async {
    if (!_isInitialized) {
      throw TranscriptionError(
        type: TranscriptionErrorType.configurationError,
        message: 'Service not initialized',
        isRetryable: false,
      );
    }

    final model = _availableModels[modelName];
    if (model == null) {
      throw TranscriptionError(
        type: TranscriptionErrorType.configurationError,
        message: 'Unknown model: $modelName',
        isRetryable: false,
      );
    }

    debugPrint('LocalWhisperService: Starting download for model: $modelName');

    // This is a placeholder implementation
    // In a real implementation, this would download the actual model files
    // For now, we'll create a placeholder file to simulate model availability
    final modelFile = File(
      path.join(_modelStorageDirectory!.path, '$modelName.bin'),
    );

    try {
      // Simulate download progress
      for (int i = 0; i <= 100; i += 10) {
        onProgress?.call(i / 100.0);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Create placeholder model file
      await modelFile.writeAsString(
        jsonEncode({
          'model_name': modelName,
          'model_type': 'whisper',
          'downloaded_at': DateTime.now().toIso8601String(),
          'size_mb': model.size,
          'quality': model.qualityLevel.name,
          'languages': model.languages,
          'note':
              'This is a placeholder file. In production, this would be the actual Whisper model binary.',
        }),
      );

      debugPrint(
        'LocalWhisperService: Model $modelName downloaded successfully',
      );
    } catch (e) {
      debugPrint(
        'LocalWhisperService: Failed to download model $modelName: $e',
      );
      throw TranscriptionError(
        type: TranscriptionErrorType.networkError,
        message: 'Failed to download model $modelName: $e',
        originalError: e,
        isRetryable: true,
      );
    }
  }

  /// Get available models for download
  List<LocalWhisperModel> getAvailableModels() {
    return _availableModels.values.toList();
  }

  /// Get currently active model
  String getCurrentModel() {
    return _currentModel;
  }

  /// Set the active model for transcription
  Future<void> setActiveModel(String modelName) async {
    if (!_availableModels.containsKey(modelName)) {
      throw TranscriptionError(
        type: TranscriptionErrorType.configurationError,
        message: 'Unknown model: $modelName',
        isRetryable: false,
      );
    }

    if (!await _isModelAvailable(modelName)) {
      throw TranscriptionError(
        type: TranscriptionErrorType.configurationError,
        message: 'Model not downloaded: $modelName',
        isRetryable: false,
      );
    }

    _currentModel = modelName;
    debugPrint('LocalWhisperService: Active model set to: $modelName');
  }

  /// Validate audio file before processing
  Future<void> _validateAudioFile(File audioFile) async {
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

    // Local processing has more generous file size limits than API
    const maxFileSizeBytes = 100 * 1024 * 1024; // 100MB
    if (fileSize > maxFileSizeBytes) {
      throw TranscriptionError.fileSizeError(
        'Audio file too large: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB. Maximum allowed: 100 MB',
        fileSize: fileSize,
        maxSize: maxFileSizeBytes,
      );
    }

    // Check file extension
    final extension = audioFile.path.split('.').last.toLowerCase();
    const supportedFormats = ['mp3', 'wav', 'm4a', 'flac', 'ogg'];
    if (!supportedFormats.contains(extension)) {
      throw TranscriptionError.audioFormatError(
        'Unsupported audio format: $extension. Supported formats: ${supportedFormats.join(', ')}',
        format: extension,
      );
    }
  }

  /// Validate audio bytes
  void _validateAudioBytes(List<int> audioBytes) {
    if (audioBytes.isEmpty) {
      throw TranscriptionError.audioFormatError('Audio data is empty');
    }

    // Check size limit
    const maxFileSizeBytes = 100 * 1024 * 1024; // 100MB
    if (audioBytes.length > maxFileSizeBytes) {
      throw TranscriptionError.fileSizeError(
        'Audio data too large: ${(audioBytes.length / (1024 * 1024)).toStringAsFixed(1)} MB. Maximum allowed: 100 MB',
        fileSize: audioBytes.length,
        maxSize: maxFileSizeBytes,
      );
    }
  }

  /// Process transcription using local Whisper model
  Future<TranscriptionResult> _processLocalTranscription(
    List<int> audioBytes,
    String audioPath,
    TranscriptionRequest request,
  ) async {
    debugPrint(
      'LocalWhisperService: Processing transcription with model: $_currentModel',
    );

    // Check if model is available
    if (!await _isModelAvailable(_currentModel)) {
      throw TranscriptionError(
        type: TranscriptionErrorType.configurationError,
        message: 'Model not available: $_currentModel',
        isRetryable: false,
      );
    }

    // In a real implementation, this would use a local Whisper engine
    // For now, we'll simulate local processing with a placeholder result
    await Future.delayed(
      const Duration(seconds: 2),
    ); // Simulate processing time

    // Create a simulated transcription result
    final now = DateTime.now();

    // Simulate different confidence levels based on model quality
    final model = _availableModels[_currentModel]!;
    final baseConfidence = switch (model.qualityLevel) {
      WhisperQuality.low => 0.75,
      WhisperQuality.medium => 0.85,
      WhisperQuality.high => 0.92,
    };

    return TranscriptionResult(
      text:
          'This is a simulated transcription result from the local Whisper model $_currentModel. '
          'In a production implementation, this would contain the actual transcribed text from the audio file.',
      confidence: baseConfidence,
      language: request.language != TranscriptionLanguage.auto
          ? request.language
          : TranscriptionLanguage.english,
      processingTimeMs: 2000, // Simulated processing time
      audioDurationMs: _estimateAudioDurationFromBytes(
        audioBytes,
        request.audioFormat,
      ),
      segments: [
        TranscriptionSegment(
          text:
              'This is a simulated transcription result from the local Whisper model $_currentModel.',
          start: 0.0,
          end: 3.5,
          confidence: baseConfidence,
        ),
        TranscriptionSegment(
          text:
              'In a production implementation, this would contain the actual transcribed text from the audio file.',
          start: 3.5,
          end: 7.0,
          confidence: baseConfidence - 0.05,
        ),
      ],
      provider: 'local_whisper',
      model: _currentModel,
      metadata: {
        'local_processing': true,
        'model_path': path.join(
          _modelStorageDirectory!.path,
          '$_currentModel.bin',
        ),
        'processing_mode': 'offline',
      },
      createdAt: now,
      qualityMetrics: TranscriptionQualityMetrics(
        averageConfidence: baseConfidence,
        confidenceVariance: 0.02,
        lowConfidenceSegments: 0,
        totalSegments: 2,
        speechRate: 120.0, // words per minute
        silencePeriods: 1,
      ),
    );
  }

  /// Estimate audio duration from file (rough estimate)
  Future<int> _estimateAudioDuration(File audioFile) async {
    try {
      final fileSize = await audioFile.length();
      final extension = audioFile.path.split('.').last.toLowerCase();

      // Rough estimates based on typical bitrates
      int estimatedBitrate;
      switch (extension) {
        case 'mp3':
          estimatedBitrate = 128000; // 128 kbps
          break;
        case 'wav':
          estimatedBitrate = 1411200; // 16-bit, 44.1kHz stereo
          break;
        case 'm4a':
          estimatedBitrate = 256000; // 256 kbps
          break;
        case 'flac':
          estimatedBitrate = 1000000; // ~1 Mbps average
          break;
        case 'ogg':
          estimatedBitrate = 192000; // 192 kbps
          break;
        default:
          estimatedBitrate = 320000; // 320 kbps default
      }

      // Calculate duration: (file size in bits) / (bitrate) * 1000 for milliseconds
      final durationMs = (fileSize * 8 / estimatedBitrate * 1000).round();
      return durationMs;
    } catch (e) {
      debugPrint('LocalWhisperService: Could not estimate audio duration: $e');
      return 0;
    }
  }

  /// Estimate audio duration from bytes
  int _estimateAudioDurationFromBytes(List<int> audioBytes, String? format) {
    final fileSize = audioBytes.length;

    // Rough estimates based on typical bitrates
    int estimatedBitrate;
    switch (format?.toLowerCase()) {
      case 'mp3':
        estimatedBitrate = 128000; // 128 kbps
        break;
      case 'wav':
        estimatedBitrate = 1411200; // 16-bit, 44.1kHz stereo
        break;
      case 'm4a':
        estimatedBitrate = 256000; // 256 kbps
        break;
      case 'flac':
        estimatedBitrate = 1000000; // ~1 Mbps average
        break;
      case 'ogg':
        estimatedBitrate = 192000; // 192 kbps
        break;
      default:
        estimatedBitrate = 320000; // 320 kbps default
    }

    // Calculate duration: (file size in bits) / (bitrate) * 1000 for milliseconds
    final durationMs = (fileSize * 8 / estimatedBitrate * 1000).round();
    return durationMs;
  }
}

/// Model information for local Whisper models
class LocalWhisperModel {
  final String name;
  final int size; // Size in MB
  final WhisperQuality qualityLevel;
  final int languages; // Number of supported languages
  final String downloadUrl;

  const LocalWhisperModel({
    required this.name,
    required this.size,
    required this.qualityLevel,
    required this.languages,
    required this.downloadUrl,
  });

  /// Get estimated processing speed multiplier (relative to real-time)
  double get processingSpeedMultiplier {
    switch (qualityLevel) {
      case WhisperQuality.low:
        return 4.0; // 4x faster than real-time
      case WhisperQuality.medium:
        return 2.0; // 2x faster than real-time
      case WhisperQuality.high:
        return 1.0; // Real-time processing
    }
  }

  /// Get estimated accuracy percentage
  double get estimatedAccuracy {
    switch (qualityLevel) {
      case WhisperQuality.low:
        return 0.85; // 85% accuracy
      case WhisperQuality.medium:
        return 0.92; // 92% accuracy
      case WhisperQuality.high:
        return 0.96; // 96% accuracy
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'size_mb': size,
      'quality_level': qualityLevel.name,
      'supported_languages': languages,
      'download_url': downloadUrl,
      'processing_speed_multiplier': processingSpeedMultiplier,
      'estimated_accuracy': estimatedAccuracy,
    };
  }

  @override
  String toString() =>
      'LocalWhisperModel($name, ${size}MB, ${qualityLevel.name})';
}

/// Quality levels for local Whisper models
enum WhisperQuality { low, medium, high }
