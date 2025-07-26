/// OpenAI Whisper API service implementation
library;

import 'dart:convert';
import 'dart:io';
import 'dart:developer';

import 'package:http/http.dart' as http;

import 'transcription_service_interface.dart';
import '../models/transcription_request.dart';
import '../models/transcription_result.dart';
import '../models/transcription_usage_stats.dart';
import '../enums/transcription_language.dart';
import 'api_key_service.dart';
import 'transcription_error_handler.dart';
import 'transcription_usage_monitor.dart';

/// OpenAI Whisper API service implementation
class OpenAIWhisperService implements TranscriptionServiceInterface {
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _transcriptionsEndpoint = '/audio/transcriptions';

  // Rate limiting
  static const int _maxRequestsPerMinute = 50;
  static const Duration _rateLimitWindow = Duration(minutes: 1);

  final ApiKeyService _apiKeyService;
  http.Client _httpClient;
  final RetryExecutor _retryExecutor;
  bool _isClientClosed = false;

  // Rate limiting tracking
  final List<DateTime> _requestTimestamps = [];

  // Usage monitoring
  final TranscriptionUsageMonitor _usageMonitor =
      TranscriptionUsageMonitor.getInstance();

  OpenAIWhisperService({
    required ApiKeyService apiKeyService,
    http.Client? httpClient,
    RetryPolicy? retryPolicy,
    CircuitBreaker? circuitBreaker,
  })  : _apiKeyService = apiKeyService,
        _httpClient = httpClient ?? http.Client(),
        _retryExecutor = RetryExecutor(
          retryPolicy: retryPolicy ??
              const RetryPolicy(
                maxAttempts: 3,
                initialDelay: Duration(seconds: 1),
                backoffMultiplier: 2.0,
                maxDelay: Duration(seconds: 30),
              ),
          circuitBreaker: circuitBreaker ??
              CircuitBreaker(
                failureThreshold: 5,
                recoveryTimeout: const Duration(minutes: 2),
              ),
        ) {
    _isClientClosed = false;
  }

  @override
  Future<void> initialize() async {
    log('OpenAIWhisperService: Initializing Whisper API service');

    // Verify API key is available
    final apiKey = await _apiKeyService.getApiKey('openai');
    if (apiKey == null || apiKey.isEmpty) {
      throw TranscriptionError.authenticationError(
        'OpenAI API key not configured',
      );
    }

    log('OpenAIWhisperService: Initialization complete');
  }

  @override
  Future<bool> isServiceAvailable() async {
    try {
      final apiKey = await _apiKeyService.getApiKey('openai');
      if (apiKey == null || apiKey.isEmpty) {
        return false;
      }

      if (_isClientClosed) {
        _httpClient = http.Client();
        _isClientClosed = false;
      }

      // Test API connectivity with a simple request
      final response = await _httpClient.get(
        Uri.parse('$_baseUrl/models'),
        headers: await _buildHeaders(),
      );

      return response.statusCode == 200;
    } catch (e) {
      log('OpenAIWhisperService: Service availability check failed: $e');
      return false;
    }
  }

  @override
  Future<TranscriptionResult> transcribeAudioFile(
    File audioFile,
    TranscriptionRequest request,
  ) async {
    log(
      'OpenAIWhisperService: Starting transcription for file: ${audioFile.path}',
    );

    final startTime = DateTime.now();

    try {
      // Check rate limiting
      await _checkRateLimit();

      // Validate file
      await _validateAudioFile(audioFile);

      // Read file bytes
      final audioBytes = await audioFile.readAsBytes();

      // Get audio duration (approximate)
      final audioDurationMs = await _estimateAudioDuration(audioFile);

      // Make API request with retry logic
      final response = await _retryExecutor.execute(
        () => _makeTranscriptionRequest(
          audioBytes,
          audioFile.path.split('/').last,
          request,
        ),
        operationName: 'transcribe_audio_file',
      );

      final processingTime = DateTime.now().difference(startTime);

      // Parse response
      final result = TranscriptionResult.fromWhisperResponse(
        response,
        processingTimeMs: processingTime.inMilliseconds,
        audioDurationMs: audioDurationMs,
        provider: 'openai_whisper',
      );

      // Update usage statistics
      await _usageMonitor.recordTranscriptionRequest(
        success: true,
        processingTime: processingTime,
        audioDurationMs: audioDurationMs,
        provider: 'openai_whisper',
        additionalMetrics: {
          'api_endpoint': '$_baseUrl/audio/transcriptions',
          'model': 'whisper-1',
        },
      );

      log('OpenAIWhisperService: Transcription completed successfully');
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
        provider: 'openai_whisper',
        errorType: errorType,
        additionalMetrics: {
          'api_endpoint': '$_baseUrl/audio/transcriptions',
          'error_message': e.toString(),
        },
      );

      log('OpenAIWhisperService: Transcription failed: $e');
      rethrow;
    }
  }

  @override
  Future<TranscriptionResult> transcribeAudioBytes(
    List<int> audioBytes,
    TranscriptionRequest request,
  ) async {
    log('OpenAIWhisperService: Starting transcription for audio bytes');

    final startTime = DateTime.now();

    try {
      // Check rate limiting
      await _checkRateLimit();

      // Validate audio data
      _validateAudioBytes(audioBytes);

      // Estimate duration (rough estimate based on file size)
      final audioDurationMs = _estimateAudioDurationFromBytes(
        audioBytes,
        request.audioFormat,
      );

      // Make API request with retry logic
      final response = await _retryExecutor.execute(
        () => _makeTranscriptionRequest(
          audioBytes,
          'audio.${request.audioFormat ?? 'wav'}',
          request,
        ),
        operationName: 'transcribe_audio_bytes',
      );

      final processingTime = DateTime.now().difference(startTime);

      // Parse response
      final result = TranscriptionResult.fromWhisperResponse(
        response,
        processingTimeMs: processingTime.inMilliseconds,
        audioDurationMs: audioDurationMs,
        provider: 'openai_whisper',
      );

      // Update usage statistics
      await _usageMonitor.recordTranscriptionRequest(
        success: true,
        processingTime: processingTime,
        audioDurationMs: audioDurationMs,
        provider: 'openai_whisper',
        additionalMetrics: {
          'api_endpoint': '$_baseUrl/audio/transcriptions',
          'model': 'whisper-1',
        },
      );

      log('OpenAIWhisperService: Transcription completed successfully');
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
        provider: 'openai_whisper',
        errorType: errorType,
        additionalMetrics: {
          'api_endpoint': '$_baseUrl/audio/transcriptions',
          'error_message': e.toString(),
        },
      );

      log('OpenAIWhisperService: Transcription failed: $e');
      rethrow;
    }
  }

  @override
  Future<List<TranscriptionLanguage>> getSupportedLanguages() async {
    // Return all supported Whisper languages
    return TranscriptionLanguage.values;
  }

  @override
  Future<TranscriptionLanguage?> detectLanguage(File audioFile) async {
    log('OpenAIWhisperService: Detecting language for file: ${audioFile.path}');

    try {
      // Create a request with auto language detection
      final request = TranscriptionRequest(
        language: TranscriptionLanguage.auto,
        responseFormat: 'verbose_json',
      );

      // Transcribe with language detection
      final result = await transcribeAudioFile(audioFile, request);

      log(
        'OpenAIWhisperService: Detected language: ${result.language?.displayName}',
      );
      return result.language;
    } catch (e) {
      log('OpenAIWhisperService: Language detection failed: $e');
      return null;
    }
  }

  @override
  Future<TranscriptionUsageStats> getUsageStats() async {
    return _usageMonitor.getCurrentStats();
  }

  @override
  Future<void> dispose() async {
    log('OpenAIWhisperService: Disposing service');
    if (!_isClientClosed) {
      _httpClient.close();
      _isClientClosed = true;
    }
  }

  /// Build HTTP headers for API requests
  Future<Map<String, String>> _buildHeaders() async {
    final apiKey = await _apiKeyService.getApiKey('openai');
    if (apiKey == null || apiKey.isEmpty) {
      throw TranscriptionError.authenticationError(
        'OpenAI API key not available',
      );
    }

    return {
      'Authorization': 'Bearer $apiKey',
      'User-Agent': 'MeetingSummarizer/1.0',
    };
  }

  /// Check rate limiting before making request
  Future<void> _checkRateLimit() async {
    final now = DateTime.now();

    // Remove old timestamps outside the rate limit window
    _requestTimestamps.removeWhere(
      (timestamp) => now.difference(timestamp) > _rateLimitWindow,
    );

    // Check if we're at the rate limit
    if (_requestTimestamps.length >= _maxRequestsPerMinute) {
      final oldestRequest = _requestTimestamps.first;
      final waitTime = _rateLimitWindow - now.difference(oldestRequest);

      log(
        'OpenAIWhisperService: Rate limit reached, waiting ${waitTime.inSeconds}s',
      );

      // Throw rate limit error instead of automatically waiting
      throw TranscriptionError.rateLimitError(
        'Rate limit exceeded: $_maxRequestsPerMinute requests per minute',
        retryAfter: waitTime,
      );
    }

    // Add current request timestamp
    _requestTimestamps.add(now);
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

    // OpenAI Whisper has a 25MB file size limit
    const maxFileSizeBytes = 25 * 1024 * 1024;
    if (fileSize > maxFileSizeBytes) {
      throw TranscriptionError.fileSizeError(
        'Audio file too large: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB. Maximum allowed: 25 MB',
        fileSize: fileSize,
        maxSize: maxFileSizeBytes,
      );
    }

    // Check file extension
    final extension = audioFile.path.split('.').last.toLowerCase();
    const supportedFormats = ['mp3', 'mp4', 'm4a', 'wav', 'webm', 'flac'];
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
    const maxFileSizeBytes = 25 * 1024 * 1024;
    if (audioBytes.length > maxFileSizeBytes) {
      throw TranscriptionError.fileSizeError(
        'Audio data too large: ${(audioBytes.length / (1024 * 1024)).toStringAsFixed(1)} MB. Maximum allowed: 25 MB',
        fileSize: audioBytes.length,
        maxSize: maxFileSizeBytes,
      );
    }
  }

  /// Make the actual transcription API request
  Future<Map<String, dynamic>> _makeTranscriptionRequest(
    List<int> audioBytes,
    String filename,
    TranscriptionRequest request,
  ) async {
    final uri = Uri.parse('$_baseUrl$_transcriptionsEndpoint');

    // Create multipart request
    final multipartRequest = http.MultipartRequest('POST', uri);

    // Add headers
    multipartRequest.headers.addAll(await _buildHeaders());

    // Add audio file
    multipartRequest.files.add(
      http.MultipartFile.fromBytes('file', audioBytes, filename: filename),
    );

    // Add API parameters
    final apiParams = request.toJson();
    for (final entry in apiParams.entries) {
      multipartRequest.fields[entry.key] = entry.value.toString();
    }

    log(
      'OpenAIWhisperService: Sending transcription request to ${uri.toString()}',
    );

    // Send request
    final streamedResponse = await multipartRequest.send();
    final response = await http.Response.fromStream(streamedResponse);

    log(
      'OpenAIWhisperService: Received response with status: ${response.statusCode}',
    );

    if (response.statusCode != 200) {
      final errorBody = response.body;
      log('OpenAIWhisperService: API error response: $errorBody');

      Map<String, dynamic>? errorData;
      try {
        errorData = jsonDecode(errorBody) as Map<String, dynamic>;
      } catch (e) {
        // Ignore JSON parsing error
      }

      final errorMessage = errorData?['error']?['message'] as String? ??
          'HTTP ${response.statusCode}: ${response.reasonPhrase}';

      // Create appropriate TranscriptionError based on status code
      switch (response.statusCode) {
        case 401:
          throw TranscriptionError.authenticationError(
            'Invalid API key: $errorMessage',
          );
        case 429:
          final retryAfter = _parseRetryAfter(response.headers['retry-after']);
          throw TranscriptionError.rateLimitError(
            'Rate limit exceeded: $errorMessage',
            retryAfter: retryAfter,
          );
        case 413:
          throw TranscriptionError.fileSizeError(
            'File too large: $errorMessage',
          );
        case 415:
          throw TranscriptionError.audioFormatError(
            'Unsupported audio format: $errorMessage',
          );
        case 500:
        case 502:
        case 503:
        case 504:
          throw TranscriptionError(
            type: TranscriptionErrorType.serviceUnavailable,
            message: 'OpenAI service error: $errorMessage',
            isRetryable: true,
            suggestedRetryDelay: const Duration(seconds: 30),
            metadata: {
              'status_code': response.statusCode,
              'error_body': errorBody,
            },
          );
        default:
          throw TranscriptionError(
            type: TranscriptionErrorType.unknownError,
            message: 'OpenAI API error: $errorMessage',
            isRetryable: response.statusCode >= 500,
            metadata: {
              'status_code': response.statusCode,
              'error_body': errorBody,
            },
          );
      }
    }

    try {
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      log('OpenAIWhisperService: Successfully parsed API response');
      return responseData;
    } catch (e) {
      log('OpenAIWhisperService: Failed to parse API response: $e');
      throw TranscriptionError(
        type: TranscriptionErrorType.invalidRequest,
        message: 'Invalid JSON response from OpenAI API',
        detailMessage: e.toString(),
        originalError: e,
        isRetryable: false,
        metadata: {'response_body': response.body},
      );
    }
  }

  /// Parse retry-after header value
  Duration? _parseRetryAfter(String? retryAfterHeader) {
    if (retryAfterHeader == null) return null;

    // Try to parse as seconds
    final seconds = int.tryParse(retryAfterHeader);
    if (seconds != null) {
      return Duration(seconds: seconds);
    }

    // Try to parse as HTTP date format (not commonly used by OpenAI)
    try {
      final retryTime = DateTime.parse(retryAfterHeader);
      final now = DateTime.now();
      if (retryTime.isAfter(now)) {
        return retryTime.difference(now);
      }
    } catch (e) {
      // Ignore parse error
    }

    return null;
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
        case 'mp4':
          estimatedBitrate = 256000; // 256 kbps
          break;
        case 'flac':
          estimatedBitrate = 1000000; // ~1 Mbps average
          break;
        default:
          estimatedBitrate = 320000; // 320 kbps default
      }

      // Calculate duration: (file size in bits) / (bitrate) * 1000 for milliseconds
      final durationMs = (fileSize * 8 / estimatedBitrate * 1000).round();
      return durationMs;
    } catch (e) {
      log('OpenAIWhisperService: Could not estimate audio duration: $e');
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
      case 'mp4':
        estimatedBitrate = 256000; // 256 kbps
        break;
      case 'flac':
        estimatedBitrate = 1000000; // ~1 Mbps average
        break;
      default:
        estimatedBitrate = 320000; // 320 kbps default
    }

    // Calculate duration: (file size in bits) / (bitrate) * 1000 for milliseconds
    final durationMs = (fileSize * 8 / estimatedBitrate * 1000).round();
    return durationMs;
  }
}
