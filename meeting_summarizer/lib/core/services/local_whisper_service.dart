/// Local Whisper service implementation for offline transcription
///
/// Usage with progress tracking:
/// ```dart
/// final service = LocalWhisperService.getInstance();
/// await service.initialize(
///   onProgress: (progress, status) {
///     print('Progress: ${(progress * 100).toStringAsFixed(1)}% - $status');
///   },
/// );
/// ```
///
/// Available models:
/// - whisper-tiny (39 MB) - Fast, lower quality
/// - whisper-base (142 MB) - Balanced speed/quality (default)
/// - whisper-small (466 MB) - High quality, slower
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

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

  // Singleton pattern
  static LocalWhisperService? _instance;
  static LocalWhisperService getInstance() {
    _instance ??= LocalWhisperService._internal();
    return _instance!;
  }

  // Private constructor
  LocalWhisperService._internal();

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
  Whisper? _whisperInstance;

  // Usage monitoring
  final TranscriptionUsageMonitor _usageMonitor =
      TranscriptionUsageMonitor.getInstance();

  @override
  Future<void> initialize({
    Function(double progress, String status)? onProgress,
  }) async {
    debugPrint('LocalWhisperService: Initializing local Whisper service');
    onProgress?.call(0.0, 'Initializing service...');

    // Check if already initialized
    if (_isInitialized) {
      debugPrint('LocalWhisperService: Service already initialized');
      onProgress?.call(1.0, 'Service ready');
      return;
    }

    try {
      // Setup model storage directory
      await _setupModelStorageDirectory();

      if (!await _modelStorageDirectory!.exists()) {
        await _modelStorageDirectory!.create(recursive: true);
        debugPrint(
          'LocalWhisperService: Created model storage directory: ${_modelStorageDirectory!.path}',
        );
      }

      // Initialize usage monitor first
      await _usageMonitor.initialize();

      // Mark as initialized so downloadModel can be called
      _isInitialized = true;

      // Initialize Whisper instance
      _whisperInstance = Whisper(
        model: _getWhisperModel(_currentModel),
        downloadHost:
            'https://huggingface.co/ggerganov/whisper.cpp/resolve/main',
      );

      // Check if default model is available, download if not
      final hasDefaultModel = await _isModelAvailable(_defaultModel);
      if (!hasDefaultModel) {
        debugPrint(
          'LocalWhisperService: Default model not found, downloading automatically...',
        );

        onProgress?.call(0.1, 'Downloading default model...');

        try {
          await downloadModel(
            _defaultModel,
            onProgress:
                (
                  progress, {
                  String? status,
                  int? downloadedBytes,
                  int? totalBytes,
                }) {
                  // Convert download progress to overall initialization progress
                  // Download takes 80% of initialization (0.1 to 0.9)
                  final overallProgress = 0.1 + (progress * 0.8);
                  onProgress?.call(
                    overallProgress,
                    status ??
                        'Downloading model: ${(progress * 100).toStringAsFixed(1)}%',
                  );
                },
          );
          debugPrint(
            'LocalWhisperService: Default model downloaded successfully',
          );
          onProgress?.call(0.9, 'Model download completed');
        } catch (e) {
          debugPrint(
            'LocalWhisperService: Failed to download default model: $e. Service will be limited until model is manually downloaded.',
          );
          onProgress?.call(0.9, 'Model download failed, continuing...');
          // Continue initialization - service can still be used for other operations
        }
      } else {
        onProgress?.call(0.9, 'Model already available');
      }

      onProgress?.call(1.0, 'Service ready');
      debugPrint('LocalWhisperService: Initialization complete');
    } catch (e) {
      debugPrint('LocalWhisperService: Initialization failed: $e');
      _isInitialized = false; // Reset initialization flag on error
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
    debugPrint('LocalWhisperService: Checking service availability');
    debugPrint('LocalWhisperService: _isInitialized = $_isInitialized');

    if (!_isInitialized) {
      debugPrint(
        'LocalWhisperService: Service not initialized, checking if models exist...',
      );

      // Even if not initialized, check if models exist (they might have been downloaded before)
      await _setupModelStorageDirectory();

      for (final modelName in _availableModels.keys) {
        final isAvailable = await _isModelAvailable(modelName);
        debugPrint(
          'LocalWhisperService: Model $modelName available: $isAvailable',
        );
        if (isAvailable) {
          debugPrint(
            'LocalWhisperService: Model found but service not initialized',
          );
          return false; // Models exist but service needs initialization
        }
      }

      debugPrint(
        'LocalWhisperService: Service not initialized and no models available',
      );
      return false;
    }

    // Check if at least one model is available
    for (final modelName in _availableModels.keys) {
      final isAvailable = await _isModelAvailable(modelName);
      debugPrint(
        'LocalWhisperService: Model $modelName available: $isAvailable',
      );
      if (isAvailable) {
        debugPrint(
          'LocalWhisperService: Service is available (model $modelName found)',
        );
        return true;
      }
    }

    debugPrint(
      'LocalWhisperService: Service initialized but no models available',
    );
    return false;
  }

  /// Setup model storage directory (helper method)
  Future<void> _setupModelStorageDirectory() async {
    if (_modelStorageDirectory == null) {
      final appSupportDir = await getApplicationSupportDirectory();
      _modelStorageDirectory = Directory(
        path.join(appSupportDir.path, _modelDirectory),
      );
    }
  }

  /// Map our model names to WhisperModel enum
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

  /// Convert audio file to WAV format (required by Whisper)
  Future<File> _prepareAudioForWhisper(File audioFile) async {
    final extension = audioFile.path.split('.').last.toLowerCase();

    // Check if the whisper_flutter_new library supports the format directly
    const supportedFormats = ['wav', 'mp3', 'flac', 'm4a', 'ogg'];

    if (!supportedFormats.contains(extension)) {
      throw TranscriptionError(
        type: TranscriptionErrorType.audioFormatError,
        message:
            'Unsupported audio format: $extension. Supported formats: ${supportedFormats.join(', ')}',
        isRetryable: false,
      );
    }

    // For sandboxed environments, we might need to copy the file to a temporary location
    // that the native library can access
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      path.join(
        tempDir.path,
        'whisper_audio_${DateTime.now().millisecondsSinceEpoch}.$extension',
      ),
    );

    // Copy the file to temporary directory to ensure the native library can access it
    try {
      await audioFile.copy(tempFile.path);

      // Verify the copy was successful
      if (!await tempFile.exists()) {
        throw TranscriptionError(
          type: TranscriptionErrorType.audioFormatError,
          message: 'Failed to copy audio file to temporary location',
          isRetryable: true,
        );
      }

      final copiedFileSize = await tempFile.length();
      final originalFileSize = await audioFile.length();

      debugPrint(
        'LocalWhisperService: Original file: ${audioFile.path} ($originalFileSize bytes)',
      );
      debugPrint(
        'LocalWhisperService: Copied to: ${tempFile.path} ($copiedFileSize bytes)',
      );

      if (copiedFileSize != originalFileSize) {
        throw TranscriptionError(
          type: TranscriptionErrorType.audioFormatError,
          message:
              'File copy incomplete: original $originalFileSize bytes, copied $copiedFileSize bytes',
          isRetryable: true,
        );
      }
    } catch (e) {
      debugPrint('LocalWhisperService: Failed to copy audio file: $e');
      throw TranscriptionError(
        type: TranscriptionErrorType.audioFormatError,
        message: 'Failed to prepare audio file for Whisper: $e',
        originalError: e,
        isRetryable: true,
      );
    }

    return tempFile;
  }

  /// Parse transcription segments from Whisper output
  List<TranscriptionSegment> _parseTranscriptionSegments(
    String transcriptionText,
  ) {
    // Whisper output format with timestamps typically looks like:
    // [00:00.000 --> 00:05.000] Hello world
    // This is a simplified parser - in practice, you'd need more robust parsing

    final segments = <TranscriptionSegment>[];
    final lines = transcriptionText.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Simple regex to match timestamp format
      final timestampRegex = RegExp(
        r'\[(\d{2}):(\d{2})\.(\d{3})\s*-->\s*(\d{2}):(\d{2})\.(\d{3})\](.*)',
      );
      final match = timestampRegex.firstMatch(line);

      if (match != null) {
        final startMin = int.parse(match.group(1)!);
        final startSec = int.parse(match.group(2)!);
        final startMs = int.parse(match.group(3)!);
        final endMin = int.parse(match.group(4)!);
        final endSec = int.parse(match.group(5)!);
        final endMs = int.parse(match.group(6)!);
        final text = match.group(7)!.trim();

        final startTime = (startMin * 60 + startSec) + (startMs / 1000.0);
        final endTime = (endMin * 60 + endSec) + (endMs / 1000.0);

        segments.add(
          TranscriptionSegment(
            text: text,
            start: startTime,
            end: endTime,
            confidence: 0.95,
          ),
        );
      } else {
        // If no timestamp, treat as single segment
        segments.add(
          TranscriptionSegment(
            text: line,
            start: 0.0,
            end: 5.0,
            confidence: 0.95,
          ),
        );
      }
    }

    return segments.isNotEmpty
        ? segments
        : [
            TranscriptionSegment(
              text: transcriptionText,
              start: 0.0,
              end: 5.0,
              confidence: 0.95,
            ),
          ];
  }

  /// Detect language from transcription
  TranscriptionLanguage _detectLanguageFromTranscription(
    String transcriptionText,
    TranscriptionLanguage? requestedLanguage,
  ) {
    // If specific language was requested, return it
    if (requestedLanguage != null &&
        requestedLanguage != TranscriptionLanguage.auto) {
      return requestedLanguage;
    }

    // Simple language detection based on common patterns
    // In practice, you'd use a proper language detection library
    final text = transcriptionText.toLowerCase();

    // Common English patterns
    if (text.contains(
      RegExp(r'\b(the|and|or|but|in|on|at|to|for|of|with|by)\b'),
    )) {
      return TranscriptionLanguage.english;
    }

    // Common Spanish patterns
    if (text.contains(
      RegExp(r'\b(el|la|los|las|y|o|pero|en|con|para|de|por)\b'),
    )) {
      return TranscriptionLanguage.spanish;
    }

    // Common French patterns
    if (text.contains(
      RegExp(r'\b(le|la|les|et|ou|mais|dans|sur|pour|de|avec)\b'),
    )) {
      return TranscriptionLanguage.french;
    }

    // Default to English if can't detect
    return TranscriptionLanguage.english;
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
      debugPrint(
        'LocalWhisperService: Transcription attempted on uninitialized service for file: ${audioFile.path}',
      );
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
      debugPrint(
        'LocalWhisperService: Transcription attempted on uninitialized service for audio bytes',
      );
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
    if (_modelStorageDirectory == null) {
      debugPrint('LocalWhisperService: Model storage directory is null');
      return false;
    }

    final modelFile = File(
      path.join(_modelStorageDirectory!.path, '$modelName.bin'),
    );
    final exists = await modelFile.exists();
    debugPrint(
      'LocalWhisperService: Checking model file ${modelFile.path}: exists = $exists',
    );

    if (exists) {
      final fileSize = await modelFile.length();
      debugPrint(
        'LocalWhisperService: Model file size: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB',
      );
    }

    return exists;
  }

  /// Download a Whisper model for local use
  Future<void> downloadModel(
    String modelName, {
    Function(
      double progress, {
      String? status,
      int? downloadedBytes,
      int? totalBytes,
    })?
    onProgress,
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

    final modelFile = File(
      path.join(_modelStorageDirectory!.path, '$modelName.bin'),
    );

    // Check if model already exists
    if (await modelFile.exists()) {
      debugPrint('LocalWhisperService: Model $modelName already exists');
      return;
    }

    try {
      onProgress?.call(0.0, status: 'Starting download...');

      // Use streaming download for progress tracking
      final request = http.Request('GET', Uri.parse(model.downloadUrl));
      request.headers['User-Agent'] = 'MeetingSummarizer/1.0';

      final response = await request.send();

      if (response.statusCode != 200) {
        throw TranscriptionError(
          type: TranscriptionErrorType.networkError,
          message: 'Failed to download model: HTTP ${response.statusCode}',
          isRetryable: true,
        );
      }

      final totalBytes = response.contentLength ?? model.size * 1024 * 1024;
      final downloadedBytes = <int>[];
      var receivedBytes = 0;

      onProgress?.call(
        0.0,
        status:
            'Downloading ${model.name} (${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB)...',
        downloadedBytes: 0,
        totalBytes: totalBytes,
      );

      // Stream download with progress updates
      await for (final chunk in response.stream) {
        downloadedBytes.addAll(chunk);
        receivedBytes += chunk.length;

        final progress = receivedBytes / totalBytes;
        final downloadedMB = receivedBytes / (1024 * 1024);
        final totalMB = totalBytes / (1024 * 1024);

        onProgress?.call(
          progress,
          status:
              'Downloading ${(downloadedMB).toStringAsFixed(1)}/${totalMB.toStringAsFixed(1)} MB',
          downloadedBytes: receivedBytes,
          totalBytes: totalBytes,
        );
      }

      onProgress?.call(0.9, status: 'Writing model file...');

      // Write the complete file
      await modelFile.writeAsBytes(downloadedBytes);

      onProgress?.call(0.95, status: 'Verifying download...');

      // Verify downloaded file
      final downloadedSize = await modelFile.length();
      if (downloadedSize != receivedBytes) {
        await modelFile.delete();
        throw TranscriptionError(
          type: TranscriptionErrorType.configurationError,
          message: 'Model download verification failed',
          isRetryable: true,
        );
      }

      onProgress?.call(1.0, status: 'Download completed');

      debugPrint(
        'LocalWhisperService: Model $modelName downloaded successfully (${(downloadedSize / (1024 * 1024)).toStringAsFixed(1)} MB)',
      );
    } catch (e) {
      debugPrint(
        'LocalWhisperService: Failed to download model $modelName: $e',
      );

      // Clean up partial download
      if (await modelFile.exists()) {
        await modelFile.delete();
      }

      if (e is TranscriptionError) {
        rethrow;
      }

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

    final startTime = DateTime.now();

    try {
      // Create temporary audio file for processing
      final tempFile = await _createTemporaryAudioFile(
        audioBytes,
        request.audioFormat,
      );

      try {
        // Process audio with local Whisper implementation
        final transcriptionResult = await _runLocalWhisperInference(
          tempFile,
          request,
        );

        final processingTime = DateTime.now().difference(startTime);

        // Return the result with updated processing time
        return TranscriptionResult(
          text: transcriptionResult.text,
          confidence: transcriptionResult.confidence,
          language: transcriptionResult.language,
          processingTimeMs: processingTime.inMilliseconds,
          audioDurationMs: transcriptionResult.audioDurationMs,
          segments: transcriptionResult.segments,
          words: transcriptionResult.words,
          speakers: transcriptionResult.speakers,
          alternatives: transcriptionResult.alternatives,
          provider: transcriptionResult.provider,
          model: transcriptionResult.model,
          metadata: transcriptionResult.metadata,
          createdAt: startTime,
          qualityMetrics: transcriptionResult.qualityMetrics,
        );
      } finally {
        // Clean up temporary file
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (e) {
      debugPrint('LocalWhisperService: Transcription processing failed: $e');

      if (e is TranscriptionError) {
        rethrow;
      }

      throw TranscriptionError(
        type: TranscriptionErrorType.unknownError,
        message: 'Local Whisper processing failed: $e',
        originalError: e,
        isRetryable: false,
      );
    }
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

  /// Create temporary audio file for processing
  Future<File> _createTemporaryAudioFile(
    List<int> audioBytes,
    String? audioFormat,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final extension = audioFormat?.toLowerCase() ?? 'wav';
    final tempFile = File(
      path.join(
        tempDir.path,
        'temp_audio_${DateTime.now().millisecondsSinceEpoch}.$extension',
      ),
    );

    await tempFile.writeAsBytes(audioBytes);
    return tempFile;
  }

  /// Run local Whisper inference on audio file
  Future<TranscriptionResult> _runLocalWhisperInference(
    File audioFile,
    TranscriptionRequest request,
  ) async {
    debugPrint(
      'LocalWhisperService: Running inference with local Whisper model',
    );

    if (_whisperInstance == null) {
      throw TranscriptionError(
        type: TranscriptionErrorType.configurationError,
        message: 'Whisper instance not initialized',
        isRetryable: false,
      );
    }

    // Prepare audio file for Whisper (convert to WAV if needed)
    final wavFile = await _prepareAudioForWhisper(audioFile);

    try {
      // Debug: Check if the audio file exists and is readable
      if (!await wavFile.exists()) {
        throw TranscriptionError(
          type: TranscriptionErrorType.audioFormatError,
          message: 'Audio file does not exist at path: ${wavFile.path}',
          isRetryable: false,
        );
      }

      final fileSize = await wavFile.length();
      debugPrint('LocalWhisperService: Audio file path: ${wavFile.path}');
      debugPrint('LocalWhisperService: Audio file size: $fileSize bytes');
      debugPrint(
        'LocalWhisperService: Audio file exists: ${await wavFile.exists()}',
      );

      // Create transcription request
      final transcribeRequest = TranscribeRequest(
        audio: wavFile.path,
        isTranslate: request.language == TranscriptionLanguage.auto,
        isNoTimestamps: false,
        splitOnWord: true,
      );

      // Perform transcription
      debugPrint('LocalWhisperService: Starting Whisper transcription...');
      debugPrint('LocalWhisperService: Using model: $_currentModel');
      debugPrint(
        'LocalWhisperService: Audio path for Whisper: ${wavFile.path}',
      );
      debugPrint('LocalWhisperService: File size: $fileSize bytes');

      final startTime = DateTime.now();

      final dynamic transcriptionResponse;
      try {
        transcriptionResponse = await _whisperInstance!.transcribe(
          transcribeRequest: transcribeRequest,
        );

        debugPrint('LocalWhisperService: Whisper transcription successful');
      } catch (whisperError) {
        debugPrint(
          'LocalWhisperService: Whisper transcription failed with error: $whisperError',
        );
        debugPrint(
          'LocalWhisperService: Error type: ${whisperError.runtimeType}',
        );

        // Provide more specific error message based on common Whisper errors
        String errorMessage = 'Whisper transcription failed: $whisperError';
        if (whisperError.toString().contains('failed to open')) {
          errorMessage =
              'Failed to open audio file for Whisper processing. The file may be corrupted or in an unsupported format.';
        } else if (whisperError.toString().contains('model')) {
          errorMessage =
              'Whisper model error. Please ensure the model is properly downloaded and accessible.';
        }

        throw TranscriptionError(
          type: TranscriptionErrorType.processingError,
          message: errorMessage,
          originalError: whisperError,
          isRetryable: true,
        );
      }

      final String transcriptionText = transcriptionResponse.text;
      final processingTime = DateTime.now().difference(startTime);

      debugPrint(
        'LocalWhisperService: Transcription completed in ${processingTime.inMilliseconds}ms',
      );
      debugPrint(
        'LocalWhisperService: Transcription text length: ${transcriptionText.length}',
      );

      if (transcriptionText.isEmpty) {
        throw TranscriptionError(
          type: TranscriptionErrorType.processingError,
          message: 'Whisper transcription returned empty text',
          isRetryable: true,
        );
      }

      // Clean up temporary file (always created now)
      try {
        if (await wavFile.exists()) {
          await wavFile.delete();
        }
      } catch (e) {
        debugPrint(
          'LocalWhisperService: Failed to clean up temporary file: $e',
        );
      }

      // Parse the transcription result
      final segments = _parseTranscriptionSegments(transcriptionText);
      final detectedLanguage = _detectLanguageFromTranscription(
        transcriptionText,
        request.language,
      );

      return TranscriptionResult(
        text: transcriptionText,
        confidence: 0.95, // Whisper doesn't provide confidence scores directly
        language: detectedLanguage,
        processingTimeMs: processingTime.inMilliseconds,
        audioDurationMs: await _estimateAudioDuration(audioFile),
        segments: segments,
        provider: 'local_whisper',
        model: _currentModel,
        createdAt: startTime,
        metadata: {
          'service': 'local_whisper',
          'model': _currentModel,
          'audio_file': audioFile.path,
          'implementation': 'whisper_flutter_new',
          'processing_time_ms': processingTime.inMilliseconds,
        },
      );
    } catch (e) {
      debugPrint('LocalWhisperService: Transcription failed: $e');

      // Clean up temporary file in case of error
      try {
        if (await wavFile.exists()) {
          await wavFile.delete();
        }
      } catch (cleanupError) {
        debugPrint(
          'LocalWhisperService: Failed to clean up temporary file after error: $cleanupError',
        );
      }

      if (e is TranscriptionError) {
        rethrow;
      }

      throw TranscriptionError(
        type: TranscriptionErrorType.processingError,
        message: 'Whisper transcription failed: $e',
        originalError: e,
        isRetryable: true,
      );
    }
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
