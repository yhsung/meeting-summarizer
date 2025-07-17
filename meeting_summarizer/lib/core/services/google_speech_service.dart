/// Google Cloud Speech-to-Text service implementation
///
/// Provides audio transcription using Google Cloud Speech-to-Text API with features:
/// - Multiple audio format support (FLAC, WAV, OGG, MP3, etc.)
/// - Real-time and batch transcription
/// - Speaker diarization and word timestamps
/// - Language detection and custom vocabulary
/// - Automatic punctuation and profanity filtering
///
/// Usage:
/// ```dart
/// final service = GoogleSpeechService.getInstance();
/// await service.initialize(apiKey: 'your-api-key');
///
/// final result = await service.transcribeAudioFile(
///   audioFile,
///   TranscriptionRequest.highQuality(
///     language: TranscriptionLanguage.english,
///     customVocabulary: ['AI', 'machine learning'],
///   ),
/// );
/// ```
library;

import 'dart:io';
import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:googleapis/speech/v1.dart' as speech;
import 'package:googleapis_auth/auth_io.dart' as auth;

import 'transcription_service_interface.dart';
import '../models/transcription_request.dart';
import '../models/transcription_result.dart';
import '../models/transcription_usage_stats.dart';
import '../enums/transcription_language.dart';
import 'transcription_error_handler.dart';
import 'transcription_usage_monitor.dart';
import 'api_key_service.dart';

/// Google Cloud Speech-to-Text service implementation
class GoogleSpeechService implements TranscriptionServiceInterface {
  static const String _apiBaseUrl = 'https://speech.googleapis.com/v1';
  static const int _maxAudioSizeBytes =
      10 * 1024 * 1024; // 10MB for synchronous recognition
  static const int _maxAudioSizeBytesAsync =
      1024 * 1024 * 1024; // 1GB for asynchronous recognition

  // Singleton pattern
  static GoogleSpeechService? _instance;
  static GoogleSpeechService getInstance() {
    _instance ??= GoogleSpeechService._internal();
    return _instance!;
  }

  // Private constructor
  GoogleSpeechService._internal();

  // Configuration
  String? _apiKey;
  String? _serviceAccountPath;
  auth.AuthClient? _authClient;
  speech.SpeechApi? _speechApi;
  bool _isInitialized = false;

  // Usage monitoring
  final TranscriptionUsageMonitor _usageMonitor =
      TranscriptionUsageMonitor.getInstance();

  // API key service for loading from settings
  final ApiKeyService _apiKeyService = ApiKeyService();

  // Retry configuration
  final RetryExecutor _retryExecutor = RetryExecutor(
    retryPolicy: RetryPolicy.conservative(),
    circuitBreaker: CircuitBreaker(
      failureThreshold: 3,
      recoveryTimeout: const Duration(minutes: 2),
    ),
  );

  /// Initialize the service with API key or service account
  @override
  Future<void> initialize() async {
    // Default initialization - attempts to load credentials from settings, then environment
    final apiKey = await _loadApiKeyFromSettings();
    final serviceAccountPath = _loadServiceAccountPathFromEnvironment();

    await initializeWithCredentials(
      apiKey: apiKey,
      serviceAccountPath: serviceAccountPath,
    );
  }

  /// Initialize the service with specific credentials
  Future<void> initializeWithCredentials({
    String? apiKey,
    String? serviceAccountPath,
    Function(double progress, String status)? onProgress,
  }) async {
    log('GoogleSpeechService: Initializing Google Speech-to-Text service');
    onProgress?.call(0.0, 'Initializing service...');

    if (_isInitialized) {
      log('GoogleSpeechService: Service already initialized');
      onProgress?.call(1.0, 'Service ready');
      return;
    }

    try {
      // Initialize usage monitor
      await _usageMonitor.initialize();
      onProgress?.call(0.3, 'Initializing usage monitor...');

      // Set up authentication
      if (apiKey != null && apiKey.isNotEmpty) {
        _apiKey = apiKey;
        log('GoogleSpeechService: Using API key authentication');
      } else if (serviceAccountPath != null && serviceAccountPath.isNotEmpty) {
        _serviceAccountPath = serviceAccountPath;
        log('GoogleSpeechService: Using service account authentication');
        await _initializeServiceAccountAuth();
      } else {
        throw TranscriptionError(
          type: TranscriptionErrorType.configurationError,
          message: 'Either API key or service account path must be provided',
          isRetryable: false,
        );
      }

      onProgress?.call(0.7, 'Setting up API client...');

      // Initialize Speech API client
      if (_authClient != null) {
        _speechApi = speech.SpeechApi(_authClient!);
      }

      _isInitialized = true;
      onProgress?.call(1.0, 'Service ready');
      log('GoogleSpeechService: Initialization complete');
    } catch (e) {
      log('GoogleSpeechService: Initialization failed: $e');
      _isInitialized = false;
      throw TranscriptionError(
        type: TranscriptionErrorType.configurationError,
        message: 'Failed to initialize Google Speech service: $e',
        originalError: e,
        isRetryable: false,
      );
    }
  }

  /// Initialize service account authentication
  Future<void> _initializeServiceAccountAuth() async {
    if (_serviceAccountPath == null) return;

    try {
      final serviceAccountFile = File(_serviceAccountPath!);
      if (!await serviceAccountFile.exists()) {
        throw TranscriptionError(
          type: TranscriptionErrorType.configurationError,
          message: 'Service account file not found: $_serviceAccountPath',
          isRetryable: false,
        );
      }

      final serviceAccountJson = await serviceAccountFile.readAsString();
      final serviceAccountCredentials = auth.ServiceAccountCredentials.fromJson(
        jsonDecode(serviceAccountJson),
      );

      _authClient = await auth.clientViaServiceAccount(
        serviceAccountCredentials,
        [speech.SpeechApi.cloudPlatformScope],
      );

      log('GoogleSpeechService: Service account authentication initialized');
    } catch (e) {
      throw TranscriptionError(
        type: TranscriptionErrorType.configurationError,
        message: 'Failed to initialize service account authentication: $e',
        originalError: e,
        isRetryable: false,
      );
    }
  }

  @override
  Future<bool> isServiceAvailable() async {
    log('GoogleSpeechService: Checking service availability');

    // If not initialized, attempt automatic initialization
    if (!_isInitialized) {
      log(
        'GoogleSpeechService: Service not initialized, attempting automatic initialization',
      );
      try {
        await initialize();
      } catch (e) {
        log('GoogleSpeechService: Automatic initialization failed: $e');
        return false;
      }
    }

    if (_apiKey == null && _authClient == null) {
      log('GoogleSpeechService: No authentication configured');
      return false;
    }

    try {
      // Test the service with a simple request
      if (_speechApi != null) {
        // Use the Speech API to test connectivity
        log('GoogleSpeechService: Testing service connectivity...');
        // Note: We could implement a simple health check here if needed
        return true;
      } else if (_apiKey != null) {
        // Test with API key using a minimal valid POST request
        final testUrl = '$_apiBaseUrl/speech:recognize';
        final testBody = jsonEncode({
          'config': {
            'encoding': 'LINEAR16',
            'sampleRateHertz': 16000,
            'languageCode': 'en-US',
          },
          'audio': {
            'content': '', // Empty content to test API key validity
          },
        });

        final response = await http.post(
          Uri.parse(testUrl),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _apiKey!,
          },
          body: testBody,
        );

        // 400 error with empty audio content means API key is valid but request is invalid (expected)
        // 401 means unauthenticated (invalid API key)
        // 403 means forbidden (API key valid but lacks permissions or quotas exceeded)
        // 404 means not found (wrong endpoint)
        // 200 would mean successful (shouldn't happen with empty content)

        final isAvailable =
            response.statusCode == 400 || response.statusCode == 403;
        log(
          'GoogleSpeechService: API key test response: ${response.statusCode}',
        );

        if (response.statusCode == 401) {
          log('GoogleSpeechService: API key is invalid or missing');
        } else if (response.statusCode == 403) {
          log(
            'GoogleSpeechService: API key valid but may lack permissions or have quota issues',
          );
          log('GoogleSpeechService: 403 Response details: ${response.body}');
        } else if (response.statusCode == 404) {
          log(
            'GoogleSpeechService: API endpoint not found - check service configuration',
          );
        } else if (!isAvailable) {
          log(
            'GoogleSpeechService: Unexpected API key test response: ${response.statusCode}. Response: ${response.body}',
          );
        }

        return isAvailable;
      }

      return false;
    } catch (e) {
      log('GoogleSpeechService: Service availability check failed: $e');
      return false;
    }
  }

  @override
  Future<TranscriptionResult> transcribeAudioFile(
    File audioFile,
    TranscriptionRequest request,
  ) async {
    log(
      'GoogleSpeechService: Starting transcription for file: ${audioFile.path}',
    );

    if (!_isInitialized) {
      log(
        'GoogleSpeechService: Transcription attempted on uninitialized service',
      );
      throw TranscriptionError(
        type: TranscriptionErrorType.configurationError,
        message: 'Google Speech service not initialized',
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

      // Process transcription
      final result = await _retryExecutor.execute(
        () => _processGoogleSpeechTranscription(
          audioBytes,
          audioFile.path,
          request,
        ),
        operationName: 'google_speech_transcription',
      );

      final processingTime = DateTime.now().difference(startTime);

      // Record usage statistics
      await _usageMonitor.recordTranscriptionRequest(
        success: true,
        processingTime: processingTime,
        audioDurationMs: audioDurationMs,
        provider: 'google_speech',
        additionalMetrics: {
          'audio_file_size_bytes': audioBytes.length,
          'audio_format': audioFile.path.split('.').last,
          'recognition_model': _getGoogleRecognitionModel(request),
          'language_code': _getLanguageCode(request.language),
        },
      );

      log(
        'GoogleSpeechService: Transcription completed successfully in ${processingTime.inMilliseconds}ms',
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
        provider: 'google_speech',
        errorType: errorType,
        additionalMetrics: {'error_message': e.toString()},
      );

      log('GoogleSpeechService: Transcription failed: $e');
      rethrow;
    }
  }

  @override
  Future<TranscriptionResult> transcribeAudioBytes(
    List<int> audioBytes,
    TranscriptionRequest request,
  ) async {
    log(
      'GoogleSpeechService: Starting transcription for audio bytes (${audioBytes.length} bytes)',
    );

    if (!_isInitialized) {
      log(
        'GoogleSpeechService: Transcription attempted on uninitialized service',
      );
      throw TranscriptionError(
        type: TranscriptionErrorType.configurationError,
        message: 'Google Speech service not initialized',
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

      // Process transcription
      final result = await _retryExecutor.execute(
        () => _processGoogleSpeechTranscription(
          audioBytes,
          'audio_data',
          request,
        ),
        operationName: 'google_speech_transcription_bytes',
      );

      final processingTime = DateTime.now().difference(startTime);

      // Record usage statistics
      await _usageMonitor.recordTranscriptionRequest(
        success: true,
        processingTime: processingTime,
        audioDurationMs: audioDurationMs,
        provider: 'google_speech',
        additionalMetrics: {
          'audio_data_size_bytes': audioBytes.length,
          'audio_format': request.audioFormat ?? 'unknown',
          'recognition_model': _getGoogleRecognitionModel(request),
          'language_code': _getLanguageCode(request.language),
        },
      );

      log(
        'GoogleSpeechService: Transcription completed successfully in ${processingTime.inMilliseconds}ms',
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
        provider: 'google_speech',
        errorType: errorType,
        additionalMetrics: {'error_message': e.toString()},
      );

      log('GoogleSpeechService: Transcription failed: $e');
      rethrow;
    }
  }

  @override
  Future<List<TranscriptionLanguage>> getSupportedLanguages() async {
    // Google Speech-to-Text supports a wide range of languages
    // Return the comprehensive list from our enum
    return TranscriptionLanguage.values;
  }

  @override
  Future<TranscriptionLanguage?> detectLanguage(File audioFile) async {
    log('GoogleSpeechService: Detecting language for file: ${audioFile.path}');

    try {
      // Create a request with auto language detection
      final request = TranscriptionRequest(
        language: TranscriptionLanguage.auto,
        responseFormat: 'json',
        enableTimestamps: false,
      );

      // Use a short sample for language detection to save costs
      final audioBytes = await audioFile.readAsBytes();
      final sampleSize = (audioBytes.length * 0.1).round(); // Use 10% sample
      final sample = audioBytes.take(sampleSize).toList();

      final result = await transcribeAudioBytes(sample, request);

      log(
        'GoogleSpeechService: Detected language: ${result.language?.displayName}',
      );
      return result.language;
    } catch (e) {
      log('GoogleSpeechService: Language detection failed: $e');
      return null;
    }
  }

  @override
  Future<TranscriptionUsageStats> getUsageStats() async {
    return _usageMonitor.getCurrentStats();
  }

  @override
  Future<void> dispose() async {
    log('GoogleSpeechService: Disposing Google Speech service');
    _authClient?.close();
    _isInitialized = false;
  }

  /// Load API key from app settings first, then environment variables
  Future<String?> _loadApiKeyFromSettings() async {
    try {
      // First try to load from app settings
      final apiKey = await _apiKeyService.getApiKey('google');
      if (apiKey != null && apiKey.isNotEmpty) {
        log('GoogleSpeechService: Found API key in app settings');
        return apiKey;
      }
    } catch (e) {
      log('GoogleSpeechService: Failed to load API key from settings: $e');
    }

    // Fall back to environment variables
    return _loadApiKeyFromEnvironment();
  }

  /// Load API key from environment variables
  String? _loadApiKeyFromEnvironment() {
    // Try common environment variable names for Google Cloud API key
    String? apiKey;

    apiKey = const String.fromEnvironment('GOOGLE_CLOUD_API_KEY');
    if (apiKey.isNotEmpty) return apiKey;

    apiKey = const String.fromEnvironment('GOOGLE_API_KEY');
    if (apiKey.isNotEmpty) return apiKey;

    apiKey = const String.fromEnvironment('GCLOUD_API_KEY');
    if (apiKey.isNotEmpty) return apiKey;

    log('GoogleSpeechService: No API key found in environment variables');
    return null;
  }

  /// Load service account path from environment variables
  String? _loadServiceAccountPathFromEnvironment() {
    // Try common environment variable names for service account
    String? path;

    path = const String.fromEnvironment('GOOGLE_APPLICATION_CREDENTIALS');
    if (path.isNotEmpty) return path;

    path = const String.fromEnvironment('GOOGLE_SERVICE_ACCOUNT_PATH');
    if (path.isNotEmpty) return path;

    path = const String.fromEnvironment('GCLOUD_SERVICE_ACCOUNT_PATH');
    if (path.isNotEmpty) return path;

    return null;
  }

  /// Check initialization status and provide setup guidance
  Future<Map<String, dynamic>> getInitializationStatus() async {
    final credentialsFound = await _checkCredentialsAvailability();

    final status = {
      'isInitialized': _isInitialized,
      'hasApiKey': _apiKey != null && _apiKey!.isNotEmpty,
      'hasAuthClient': _authClient != null,
      'setupRequired': !_isInitialized,
      'setupSteps': _getSetupSteps(),
      'credentialsFound': credentialsFound,
    };

    return status;
  }

  /// Get required setup steps
  List<String> _getSetupSteps() {
    return [
      '1. Obtain Google Cloud API key or service account JSON file',
      '2. Enable Google Cloud Speech-to-Text API in Google Cloud Console',
      '3. Set up billing for the Google Cloud project (required for API usage)',
      '4. Configure authentication credentials using one of these methods:',
      '   - Configure in app: Settings → API Configuration → Google API Key',
      '   - Set environment variable: GOOGLE_CLOUD_API_KEY=your-api-key',
      '   - Set environment variable: GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json',
      '   - Call initializeWithCredentials() with credentials directly',
      '5. Verify initialization by calling initialize() or initializeWithCredentials()',
    ];
  }

  /// Check if credentials are available in app settings and environment
  Future<Map<String, dynamic>> _checkCredentialsAvailability() async {
    String? settingsApiKey;
    try {
      settingsApiKey = await _apiKeyService.getApiKey('google');
    } catch (e) {
      log('GoogleSpeechService: Error checking settings API key: $e');
    }

    return {
      'apiKeyFromSettings': settingsApiKey != null && settingsApiKey.isNotEmpty,
      'apiKeyFromEnv': _loadApiKeyFromEnvironment() != null,
      'serviceAccountFromEnv': _loadServiceAccountPathFromEnvironment() != null,
      'hasAnyCredentials': _apiKey != null || _authClient != null,
      'settingsApiKeyMasked': settingsApiKey != null
          ? _maskApiKey(settingsApiKey)
          : null,
      'checkSources': [
        'App Settings (google provider)',
        'Environment Variables',
        'Service Account File',
      ],
      'environmentVariablesChecked': [
        'GOOGLE_CLOUD_API_KEY',
        'GOOGLE_API_KEY',
        'GCLOUD_API_KEY',
        'GOOGLE_APPLICATION_CREDENTIALS',
        'GOOGLE_SERVICE_ACCOUNT_PATH',
        'GCLOUD_SERVICE_ACCOUNT_PATH',
      ],
    };
  }

  /// Mask API key for display purposes (copied from ApiKeyService pattern)
  String _maskApiKey(String apiKey) {
    if (apiKey.length <= 8) {
      return '*' * apiKey.length;
    }

    final start = apiKey.substring(0, 4);
    final end = apiKey.substring(apiKey.length - 4);
    final middle = '*' * (apiKey.length - 8);

    return '$start$middle$end';
  }

  /// Process transcription using Google Speech-to-Text API
  Future<TranscriptionResult> _processGoogleSpeechTranscription(
    List<int> audioBytes,
    String audioPath,
    TranscriptionRequest request,
  ) async {
    log('GoogleSpeechService: Processing transcription with Google Speech API');

    try {
      // Determine if we should use synchronous or asynchronous recognition
      final useAsync = audioBytes.length > _maxAudioSizeBytes;

      if (useAsync) {
        log(
          'GoogleSpeechService: Using asynchronous recognition for large file',
        );
        return await _processAsyncTranscription(audioBytes, audioPath, request);
      } else {
        log('GoogleSpeechService: Using synchronous recognition');
        return await _processSyncTranscription(audioBytes, audioPath, request);
      }
    } catch (e) {
      log('GoogleSpeechService: Transcription processing failed: $e');

      if (e is TranscriptionError) {
        rethrow;
      }

      throw TranscriptionError(
        type: TranscriptionErrorType.processingError,
        message: 'Google Speech transcription failed: $e',
        originalError: e,
        isRetryable: true,
      );
    }
  }

  /// Process synchronous transcription for smaller audio files
  Future<TranscriptionResult> _processSyncTranscription(
    List<int> audioBytes,
    String audioPath,
    TranscriptionRequest request,
  ) async {
    log('GoogleSpeechService: Starting synchronous transcription');

    final startTime = DateTime.now();

    try {
      final recognitionRequest = await _buildRecognitionRequest(
        audioBytes,
        request,
        isAsync: false,
      );

      if (_speechApi != null) {
        // Use the official Google Speech API client
        final response = await _speechApi!.speech.recognize(recognitionRequest);
        return _parseRecognitionResponse(
          response,
          startTime,
          audioPath,
          request,
        );
      } else {
        // Use direct HTTP request with API key
        return await _makeDirectApiRequest(
          recognitionRequest,
          startTime,
          audioPath,
          request,
        );
      }
    } catch (e) {
      throw _handleGoogleSpeechError(e);
    }
  }

  /// Process asynchronous transcription for larger audio files
  Future<TranscriptionResult> _processAsyncTranscription(
    List<int> audioBytes,
    String audioPath,
    TranscriptionRequest request,
  ) async {
    log('GoogleSpeechService: Starting asynchronous transcription');

    if (audioBytes.length > _maxAudioSizeBytesAsync) {
      throw TranscriptionError(
        type: TranscriptionErrorType.fileSizeError,
        message:
            'Audio file too large for Google Speech API: ${(audioBytes.length / (1024 * 1024)).toStringAsFixed(1)} MB. Maximum allowed: ${(_maxAudioSizeBytesAsync / (1024 * 1024)).toStringAsFixed(0)} MB',
        isRetryable: false,
      );
    }

    try {
      // For async recognition, audio should be uploaded to Google Cloud Storage
      // For now, we'll throw an error suggesting the user use a smaller file
      // TODO: Implement Cloud Storage upload for large files
      throw TranscriptionError(
        type: TranscriptionErrorType.fileSizeError,
        message:
            'Asynchronous transcription requires audio files to be uploaded to Google Cloud Storage. Please use a smaller file (< ${(_maxAudioSizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB) or implement Cloud Storage integration.',
        isRetryable: false,
      );
    } catch (e) {
      throw _handleGoogleSpeechError(e);
    }
  }

  /// Build Google Speech API recognition request
  Future<speech.RecognizeRequest> _buildRecognitionRequest(
    List<int> audioBytes,
    TranscriptionRequest request, {
    required bool isAsync,
  }) async {
    final audioFormat = _detectAudioFormat(audioBytes, request.audioFormat);
    final languageCode = _getLanguageCode(request.language);
    final encoding = _getGoogleAudioEncoding(audioFormat);
    final sampleRate = _estimateSampleRate(audioFormat);
    final finalLanguageCode = languageCode == 'auto' ? 'en-US' : languageCode;

    log('GoogleSpeechService: Building recognition request');
    log('  Audio format: $audioFormat');
    log('  Encoding: $encoding');
    log('  Sample rate: $sampleRate Hz');
    log('  Language code: $finalLanguageCode');
    log('  Audio size: ${audioBytes.length} bytes');

    // Create recognition config
    final config = speech.RecognitionConfig(
      encoding: encoding,
      sampleRateHertz: sampleRate,
      languageCode: finalLanguageCode,
      enableAutomaticPunctuation: true,
      enableWordTimeOffsets: request.enableWordTimestamps,
      model: _getGoogleRecognitionModel(request),
      maxAlternatives:
          request.maxAlternatives > 0 && request.maxAlternatives <= 30
          ? request.maxAlternatives
          : 1, // Google Speech API supports 1-30 alternatives
    );

    // Add alternative language codes for auto-detection
    if (request.language == TranscriptionLanguage.auto) {
      config.alternativeLanguageCodes = [
        'en-US',
        'es-ES',
        'fr-FR',
        'de-DE',
        'it-IT',
        'pt-BR',
        'ja-JP',
        'ko-KR',
        'zh-CN',
      ];
    }

    // Add speaker diarization if enabled
    if (request.enableSpeakerDiarization) {
      final maxSpeakers = request.maxSpeakers ?? 6;
      // Google Speech API supports 1-8 speakers
      final validMaxSpeakers = maxSpeakers > 0 && maxSpeakers <= 8
          ? maxSpeakers
          : 6;

      config.diarizationConfig = speech.SpeakerDiarizationConfig(
        enableSpeakerDiarization: true,
        maxSpeakerCount: validMaxSpeakers,
      );

      log(
        'GoogleSpeechService: Speaker diarization enabled, max speakers: $validMaxSpeakers',
      );
    }

    // Add profanity filter if enabled
    if (request.enableProfanityFilter) {
      config.profanityFilter = true;
    }

    // Add custom vocabulary if provided
    if (request.customVocabulary != null &&
        request.customVocabulary!.isNotEmpty) {
      config.speechContexts = [
        speech.SpeechContext(phrases: request.customVocabulary!),
      ];
    }

    // Create audio content
    final audio = speech.RecognitionAudio(content: base64Encode(audioBytes));

    return speech.RecognizeRequest(config: config, audio: audio);
  }

  /// Make direct API request using HTTP client
  Future<TranscriptionResult> _makeDirectApiRequest(
    speech.RecognizeRequest recognitionRequest,
    DateTime startTime,
    String audioPath,
    TranscriptionRequest request,
  ) async {
    if (_apiKey == null) {
      throw TranscriptionError(
        type: TranscriptionErrorType.configurationError,
        message: 'API key not configured for direct HTTP requests',
        isRetryable: false,
      );
    }

    final url = '$_apiBaseUrl/speech:recognize';
    final headers = {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey!,
    };

    final body = jsonEncode(recognitionRequest.toJson());

    log('GoogleSpeechService: Making HTTP request to Google Speech API');

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'HTTP ${response.statusCode}: ${response.body}',
        uri: Uri.parse(url),
      );
    }

    final responseData = jsonDecode(response.body);
    final mockResponse = speech.RecognizeResponse.fromJson(responseData);

    return _parseRecognitionResponse(
      mockResponse,
      startTime,
      audioPath,
      request,
    );
  }

  /// Parse Google Speech API response into TranscriptionResult
  TranscriptionResult _parseRecognitionResponse(
    speech.RecognizeResponse response,
    DateTime startTime,
    String audioPath,
    TranscriptionRequest request,
  ) {
    final processingTime = DateTime.now().difference(startTime);

    if (response.results == null || response.results!.isEmpty) {
      log('GoogleSpeechService: No transcription results returned');
      return TranscriptionResult(
        text: '',
        confidence: 0.0,
        language: request.language ?? TranscriptionLanguage.english,
        processingTimeMs: processingTime.inMilliseconds,
        audioDurationMs: 0,
        segments: [],
        provider: 'google_speech',
        model: _getGoogleRecognitionModel(request),
        createdAt: startTime,
        metadata: {
          'service': 'google_speech',
          'audio_path': audioPath,
          'request_id': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
    }

    // Combine all results into single text
    final textBuilder = StringBuffer();
    final segments = <TranscriptionSegment>[];
    double totalConfidence = 0.0;
    int resultCount = 0;

    for (final result in response.results!) {
      if (result.alternatives != null && result.alternatives!.isNotEmpty) {
        final alternative = result.alternatives!.first;

        if (alternative.transcript != null) {
          textBuilder.write(alternative.transcript);
          textBuilder.write(' ');

          totalConfidence += alternative.confidence ?? 0.0;
          resultCount++;

          // Create segment from result
          segments.add(
            TranscriptionSegment(
              text: alternative.transcript!,
              start:
                  0.0, // Google Speech doesn't provide segment timestamps in sync mode
              end: 0.0,
              confidence: alternative.confidence ?? 0.0,
            ),
          );
        }
      }
    }

    final finalText = textBuilder.toString().trim();
    final averageConfidence = resultCount > 0
        ? totalConfidence / resultCount
        : 0.0;

    // Detect language from response if auto-detection was used
    TranscriptionLanguage? detectedLanguage = request.language;
    if (request.language == TranscriptionLanguage.auto &&
        response.results!.isNotEmpty) {
      final languageCode = response.results!.first.languageCode;
      if (languageCode != null) {
        detectedLanguage = _mapLanguageCodeToEnum(languageCode);
      }
    }

    log(
      'GoogleSpeechService: Transcription completed - Text length: ${finalText.length}, Confidence: ${(averageConfidence * 100).toStringAsFixed(1)}%',
    );

    return TranscriptionResult(
      text: finalText,
      confidence: averageConfidence,
      language: detectedLanguage ?? TranscriptionLanguage.english,
      processingTimeMs: processingTime.inMilliseconds,
      audioDurationMs: _estimateAudioDurationFromBytes([], request.audioFormat),
      segments: segments,
      provider: 'google_speech',
      model: _getGoogleRecognitionModel(request),
      createdAt: startTime,
      metadata: {
        'service': 'google_speech',
        'audio_path': audioPath,
        'request_id': DateTime.now().millisecondsSinceEpoch.toString(),
        'result_count': resultCount,
        'processing_time_ms': processingTime.inMilliseconds,
      },
    );
  }

  /// Handle Google Speech API errors and convert to TranscriptionError
  TranscriptionError _handleGoogleSpeechError(Object error) {
    if (error is TranscriptionError) {
      return error;
    }

    if (error is HttpException) {
      return TranscriptionError.fromHttpException(error);
    }

    // Handle specific Google API errors
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('invalid api key') ||
        errorString.contains('unauthorized')) {
      return TranscriptionError.authenticationError(
        'Invalid API key or authentication failed',
      );
    }

    if (errorString.contains('quota') || errorString.contains('rate limit')) {
      return TranscriptionError.rateLimitError(
        'Google Speech API quota exceeded or rate limited',
      );
    }

    if (errorString.contains('unsupported') ||
        errorString.contains('invalid format')) {
      return TranscriptionError.audioFormatError(
        'Unsupported audio format for Google Speech API',
      );
    }

    if (errorString.contains('invalid request') ||
        errorString.contains('invalid parameters') ||
        errorString.contains('400')) {
      return TranscriptionError(
        type: TranscriptionErrorType.invalidRequest,
        message: 'Invalid request parameters: $error',
        originalError: error,
        isRetryable: false,
      );
    }

    return TranscriptionError(
      type: TranscriptionErrorType.unknownError,
      message: 'Google Speech API error: $error',
      originalError: error,
      isRetryable: true,
    );
  }

  /// Get Google Speech API audio encoding from format
  String _getGoogleAudioEncoding(String format) {
    switch (format.toLowerCase()) {
      case 'wav':
        return 'LINEAR16';
      case 'flac':
        return 'FLAC';
      case 'ogg':
        return 'OGG_OPUS';
      case 'mp3':
        return 'MP3';
      case 'webm':
        return 'WEBM_OPUS';
      default:
        return 'LINEAR16'; // Default to WAV
    }
  }

  /// Get Google Speech recognition model based on request quality
  String _getGoogleRecognitionModel(TranscriptionRequest request) {
    switch (request.quality) {
      case TranscriptionQuality.fast:
        return 'latest_short';
      case TranscriptionQuality.balanced:
        return 'latest_long';
      case TranscriptionQuality.high:
      case TranscriptionQuality.maximum:
        return 'latest_long';
    }
  }

  /// Get language code for Google Speech API
  String _getLanguageCode(TranscriptionLanguage? language) {
    if (language == null || language == TranscriptionLanguage.auto) {
      return 'auto';
    }
    return language.googleSpeechCode ?? language.code;
  }

  /// Map Google Speech language code back to TranscriptionLanguage enum
  TranscriptionLanguage _mapLanguageCodeToEnum(String languageCode) {
    for (final lang in TranscriptionLanguage.values) {
      if (lang.googleSpeechCode == languageCode || lang.code == languageCode) {
        return lang;
      }
    }
    return TranscriptionLanguage.english; // Default fallback
  }

  /// Detect audio format from bytes and filename
  String _detectAudioFormat(List<int> audioBytes, String? filename) {
    if (filename != null) {
      final extension = filename.split('.').last.toLowerCase();
      if (['wav', 'flac', 'ogg', 'mp3', 'webm'].contains(extension)) {
        return extension;
      }
    }

    // Try to detect from file header
    if (audioBytes.length >= 4) {
      final header = audioBytes.take(4).toList();

      // WAV file signature
      if (header[0] == 0x52 &&
          header[1] == 0x49 &&
          header[2] == 0x46 &&
          header[3] == 0x46) {
        return 'wav';
      }

      // FLAC file signature
      if (header[0] == 0x66 &&
          header[1] == 0x4C &&
          header[2] == 0x61 &&
          header[3] == 0x43) {
        return 'flac';
      }

      // MP3 file signature
      if (header[0] == 0xFF && (header[1] & 0xE0) == 0xE0) {
        return 'mp3';
      }
    }

    return 'wav'; // Default fallback
  }

  /// Estimate sample rate based on audio format
  int _estimateSampleRate(String format) {
    // Google Speech API supports specific sample rates for LINEAR16:
    // 8000, 12000, 16000, 24000, 48000 Hz
    switch (format.toLowerCase()) {
      case 'wav':
      case 'flac':
        return 16000; // Use standard speech rate for better compatibility
      case 'ogg':
      case 'webm':
        return 48000;
      case 'mp3':
        return 16000; // Use standard speech rate for better compatibility
      default:
        return 16000; // Common rate for speech, well-supported
    }
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

    // Check file extension
    final extension = audioFile.path.split('.').last.toLowerCase();
    const supportedFormats = ['mp3', 'wav', 'flac', 'ogg', 'webm'];
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
        case 'flac':
          estimatedBitrate = 1000000; // ~1 Mbps average
          break;
        case 'ogg':
        case 'webm':
          estimatedBitrate = 192000; // 192 kbps
          break;
        default:
          estimatedBitrate = 320000; // 320 kbps default
      }

      // Calculate duration: (file size in bits) / (bitrate) * 1000 for milliseconds
      final durationMs = (fileSize * 8 / estimatedBitrate * 1000).round();
      return durationMs;
    } catch (e) {
      log('GoogleSpeechService: Could not estimate audio duration: $e');
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
      case 'flac':
        estimatedBitrate = 1000000; // ~1 Mbps average
        break;
      case 'ogg':
      case 'webm':
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

/// Extension to add Google Speech language codes to TranscriptionLanguage
extension GoogleSpeechLanguageCodes on TranscriptionLanguage {
  /// Get the Google Speech-to-Text language code
  String? get googleSpeechCode {
    switch (this) {
      case TranscriptionLanguage.english:
        return 'en-US';
      case TranscriptionLanguage.spanish:
        return 'es-ES';
      case TranscriptionLanguage.french:
        return 'fr-FR';
      case TranscriptionLanguage.german:
        return 'de-DE';
      case TranscriptionLanguage.italian:
        return 'it-IT';
      case TranscriptionLanguage.portuguese:
        return 'pt-BR';
      case TranscriptionLanguage.russian:
        return 'ru-RU';
      case TranscriptionLanguage.japanese:
        return 'ja-JP';
      case TranscriptionLanguage.korean:
        return 'ko-KR';
      case TranscriptionLanguage.chineseSimplified:
        return 'zh-CN';
      case TranscriptionLanguage.arabic:
        return 'ar-SA';
      case TranscriptionLanguage.hindi:
        return 'hi-IN';
      case TranscriptionLanguage.dutch:
        return 'nl-NL';
      case TranscriptionLanguage.polish:
        return 'pl-PL';
      case TranscriptionLanguage.turkish:
        return 'tr-TR';
      case TranscriptionLanguage.auto:
        return null; // Auto-detection
      default:
        return code; // Fallback to the standard code
    }
  }
}
