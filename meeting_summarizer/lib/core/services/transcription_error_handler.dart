/// Error handling and retry mechanisms for transcription services
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' hide log;
import 'dart:developer';


/// Types of transcription errors
enum TranscriptionErrorType {
  /// Network connectivity issues
  networkError,

  /// API authentication failures
  authenticationError,

  /// Rate limiting exceeded
  rateLimitError,

  /// Invalid audio file or format
  audioFormatError,

  /// File too large or processing limits exceeded
  fileSizeError,

  /// API service temporarily unavailable
  serviceUnavailable,

  /// Quota or billing issues
  quotaExceeded,

  /// Invalid API request parameters
  invalidRequest,

  /// Unknown or unexpected errors
  unknownError,

  /// Client-side configuration errors
  configurationError,

  /// Audio processing or transcription errors
  processingError,
}

/// Detailed transcription error with retry information
class TranscriptionError extends Error {
  final TranscriptionErrorType type;
  final String message;
  final String? detailMessage;
  final Object? originalError;
  final StackTrace? originalStackTrace;
  final bool isRetryable;
  final Duration? suggestedRetryDelay;
  final Map<String, dynamic> metadata;

  TranscriptionError({
    required this.type,
    required this.message,
    this.detailMessage,
    this.originalError,
    this.originalStackTrace,
    required this.isRetryable,
    this.suggestedRetryDelay,
    this.metadata = const {},
  });

  /// Create error from HTTP exception
  factory TranscriptionError.fromHttpException(HttpException httpException) {
    final statusCode = _extractStatusCode(httpException.message);

    return TranscriptionError(
      type: _mapHttpStatusToErrorType(statusCode),
      message: _getErrorMessage(statusCode, httpException.message),
      detailMessage: httpException.message,
      originalError: httpException,
      isRetryable: _isHttpStatusRetryable(statusCode),
      suggestedRetryDelay: _getRetryDelay(statusCode),
      metadata: {
        'status_code': statusCode,
        'uri': httpException.uri?.toString(),
      },
    );
  }

  /// Create error from socket exception (network issues)
  factory TranscriptionError.fromSocketException(
    SocketException socketException,
  ) {
    return TranscriptionError(
      type: TranscriptionErrorType.networkError,
      message: 'Network connection failed',
      detailMessage: socketException.message,
      originalError: socketException,
      isRetryable: true,
      suggestedRetryDelay: const Duration(seconds: 5),
      metadata: {
        'address': socketException.address?.address,
        'port': socketException.port,
      },
    );
  }

  /// Create error from timeout exception
  factory TranscriptionError.fromTimeoutException(
    TimeoutException timeoutException,
  ) {
    return TranscriptionError(
      type: TranscriptionErrorType.networkError,
      message: 'Request timed out',
      detailMessage: timeoutException.message,
      originalError: timeoutException,
      isRetryable: true,
      suggestedRetryDelay: const Duration(seconds: 10),
      metadata: {'timeout_duration': timeoutException.duration?.inSeconds},
    );
  }

  /// Create error for invalid audio format
  factory TranscriptionError.audioFormatError(
    String message, {
    String? format,
  }) {
    return TranscriptionError(
      type: TranscriptionErrorType.audioFormatError,
      message: message,
      isRetryable: false,
      metadata: {'format': format},
    );
  }

  /// Create error for file size issues
  factory TranscriptionError.fileSizeError(
    String message, {
    int? fileSize,
    int? maxSize,
  }) {
    return TranscriptionError(
      type: TranscriptionErrorType.fileSizeError,
      message: message,
      isRetryable: false,
      metadata: {'file_size': fileSize, 'max_size': maxSize},
    );
  }

  /// Create error for authentication issues
  factory TranscriptionError.authenticationError(String message) {
    return TranscriptionError(
      type: TranscriptionErrorType.authenticationError,
      message: message,
      isRetryable: false,
    );
  }

  /// Create error for rate limiting
  factory TranscriptionError.rateLimitError(
    String message, {
    Duration? retryAfter,
  }) {
    return TranscriptionError(
      type: TranscriptionErrorType.rateLimitError,
      message: message,
      isRetryable: true,
      suggestedRetryDelay: retryAfter ?? const Duration(minutes: 1),
      metadata: {'retry_after_seconds': retryAfter?.inSeconds},
    );
  }

  /// Extract status code from HTTP error message
  static int? _extractStatusCode(String message) {
    final match = RegExp(r'HTTP (\d{3})').firstMatch(message);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// Map HTTP status codes to error types
  static TranscriptionErrorType _mapHttpStatusToErrorType(int? statusCode) {
    if (statusCode == null) return TranscriptionErrorType.unknownError;

    switch (statusCode) {
      case 401:
      case 403:
        return TranscriptionErrorType.authenticationError;
      case 413:
        return TranscriptionErrorType.fileSizeError;
      case 415:
        return TranscriptionErrorType.audioFormatError;
      case 429:
        return TranscriptionErrorType.rateLimitError;
      case 500:
      case 502:
      case 503:
      case 504:
        return TranscriptionErrorType.serviceUnavailable;
      case 400:
        return TranscriptionErrorType.invalidRequest;
      default:
        return TranscriptionErrorType.unknownError;
    }
  }

  /// Get user-friendly error message
  static String _getErrorMessage(int? statusCode, String originalMessage) {
    if (statusCode == null) return 'Unknown error occurred';

    switch (statusCode) {
      case 401:
        return 'Invalid API key or authentication failed';
      case 403:
        return 'Access forbidden - check API permissions';
      case 413:
        return 'Audio file too large - maximum 25MB allowed';
      case 415:
        return 'Unsupported audio format';
      case 429:
        return 'Rate limit exceeded - too many requests';
      case 500:
        return 'Internal server error';
      case 502:
        return 'Bad gateway - service temporarily unavailable';
      case 503:
        return 'Service temporarily unavailable';
      case 504:
        return 'Gateway timeout - request took too long';
      case 400:
        return 'Invalid request parameters';
      default:
        return 'HTTP error $statusCode: ${originalMessage.split(':').last.trim()}';
    }
  }

  /// Check if HTTP status code is retryable
  static bool _isHttpStatusRetryable(int? statusCode) {
    if (statusCode == null) return true;

    switch (statusCode) {
      case 408: // Request Timeout
      case 429: // Too Many Requests
      case 500: // Internal Server Error
      case 502: // Bad Gateway
      case 503: // Service Unavailable
      case 504: // Gateway Timeout
        return true;
      default:
        return false;
    }
  }

  /// Get suggested retry delay for HTTP status
  static Duration? _getRetryDelay(int? statusCode) {
    if (statusCode == null) return const Duration(seconds: 5);

    switch (statusCode) {
      case 429:
        return const Duration(minutes: 1);
      case 503:
      case 504:
        return const Duration(seconds: 30);
      case 500:
      case 502:
        return const Duration(seconds: 10);
      default:
        return const Duration(seconds: 5);
    }
  }

  @override
  String toString() {
    return 'TranscriptionError(${type.name}): $message';
  }
}

/// Retry policy configuration
class RetryPolicy {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final bool enableJitter;
  final List<TranscriptionErrorType> retryableErrorTypes;

  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(minutes: 5),
    this.enableJitter = true,
    this.retryableErrorTypes = const [
      TranscriptionErrorType.networkError,
      TranscriptionErrorType.rateLimitError,
      TranscriptionErrorType.serviceUnavailable,
    ],
  });

  /// Conservative retry policy for production
  factory RetryPolicy.conservative() {
    return const RetryPolicy(
      maxAttempts: 2,
      initialDelay: Duration(seconds: 2),
      backoffMultiplier: 1.5,
      maxDelay: Duration(minutes: 1),
      enableJitter: true,
    );
  }

  /// Aggressive retry policy for development/testing
  factory RetryPolicy.aggressive() {
    return const RetryPolicy(
      maxAttempts: 5,
      initialDelay: Duration(milliseconds: 500),
      backoffMultiplier: 2.0,
      maxDelay: Duration(minutes: 10),
      enableJitter: true,
    );
  }

  /// No retry policy
  factory RetryPolicy.noRetry() {
    return const RetryPolicy(maxAttempts: 1, retryableErrorTypes: []);
  }

  /// Check if error type is retryable
  bool isRetryable(TranscriptionErrorType errorType) {
    return retryableErrorTypes.contains(errorType);
  }

  /// Calculate delay for retry attempt
  Duration calculateDelay(int attemptNumber, {Duration? suggestedDelay}) {
    if (attemptNumber <= 0) return Duration.zero;

    // Use suggested delay if provided and it's longer
    final baseDelay = suggestedDelay ?? initialDelay;

    // Calculate exponential backoff
    final backoffDelay = Duration(
      milliseconds:
          (baseDelay.inMilliseconds * pow(backoffMultiplier, attemptNumber - 1))
              .round(),
    );

    // Apply maximum delay limit
    final limitedDelay = Duration(
      milliseconds: min(backoffDelay.inMilliseconds, maxDelay.inMilliseconds),
    );

    // Add jitter to prevent thundering herd
    if (enableJitter) {
      final jitterMs = Random().nextInt(limitedDelay.inMilliseconds ~/ 4);
      return Duration(milliseconds: limitedDelay.inMilliseconds + jitterMs);
    }

    return limitedDelay;
  }
}

/// Circuit breaker pattern for failing services
class CircuitBreaker {
  final int failureThreshold;
  final Duration recoveryTimeout;
  final Duration halfOpenTimeout;

  int _failureCount = 0;
  CircuitBreakerState _state = CircuitBreakerState.closed;
  DateTime? _lastFailureTime;
  DateTime? _lastHalfOpenTime;

  CircuitBreaker({
    this.failureThreshold = 5,
    this.recoveryTimeout = const Duration(minutes: 5),
    this.halfOpenTimeout = const Duration(seconds: 30),
  });

  /// Check if circuit breaker allows the request
  bool get isOpen => _state == CircuitBreakerState.open;

  /// Check if circuit breaker is in half-open state
  bool get isHalfOpen => _state == CircuitBreakerState.halfOpen;

  /// Current state of the circuit breaker
  CircuitBreakerState get state => _state;

  /// Current failure count
  int get failureCount => _failureCount;

  /// Execute a function with circuit breaker protection
  Future<T> execute<T>(Future<T> Function() operation) async {
    if (!_canExecute()) {
      throw TranscriptionError(
        type: TranscriptionErrorType.serviceUnavailable,
        message: 'Service circuit breaker is open - too many recent failures',
        isRetryable: true,
        suggestedRetryDelay: _getRetryDelay(),
        metadata: {
          'circuit_breaker_state': _state.name,
          'failure_count': _failureCount,
          'last_failure': _lastFailureTime?.toIso8601String(),
        },
      );
    }

    try {
      final result = await operation();
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }

  /// Check if the circuit breaker allows execution
  bool _canExecute() {
    final now = DateTime.now();

    switch (_state) {
      case CircuitBreakerState.closed:
        return true;

      case CircuitBreakerState.open:
        if (_lastFailureTime != null &&
            now.difference(_lastFailureTime!) >= recoveryTimeout) {
          _state = CircuitBreakerState.halfOpen;
          _lastHalfOpenTime = now;
          return true;
        }
        return false;

      case CircuitBreakerState.halfOpen:
        if (_lastHalfOpenTime != null &&
            now.difference(_lastHalfOpenTime!) >= halfOpenTimeout) {
          // Half-open timeout expired, go back to open
          _state = CircuitBreakerState.open;
          _lastFailureTime = now;
          return false;
        }
        return true;
    }
  }

  /// Handle successful operation
  void _onSuccess() {
    _failureCount = 0;
    _state = CircuitBreakerState.closed;
    _lastFailureTime = null;
    _lastHalfOpenTime = null;
  }

  /// Handle failed operation
  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_state == CircuitBreakerState.halfOpen) {
      // Failure in half-open state, go back to open
      _state = CircuitBreakerState.open;
    } else if (_failureCount >= failureThreshold) {
      // Too many failures, open the circuit
      _state = CircuitBreakerState.open;
    }
  }

  /// Get suggested retry delay based on circuit breaker state
  Duration _getRetryDelay() {
    switch (_state) {
      case CircuitBreakerState.open:
        return recoveryTimeout;
      case CircuitBreakerState.halfOpen:
        return halfOpenTimeout;
      case CircuitBreakerState.closed:
        return Duration.zero;
    }
  }

  /// Reset circuit breaker to initial state
  void reset() {
    _failureCount = 0;
    _state = CircuitBreakerState.closed;
    _lastFailureTime = null;
    _lastHalfOpenTime = null;
  }

  /// Get circuit breaker status
  Map<String, dynamic> getStatus() {
    return {
      'state': _state.name,
      'failure_count': _failureCount,
      'failure_threshold': failureThreshold,
      'last_failure_time': _lastFailureTime?.toIso8601String(),
      'recovery_timeout_seconds': recoveryTimeout.inSeconds,
      'can_execute': _canExecute(),
    };
  }
}

/// Circuit breaker states
enum CircuitBreakerState {
  /// Normal operation - requests pass through
  closed,

  /// Too many failures - requests are blocked
  open,

  /// Testing if service has recovered - limited requests allowed
  halfOpen,
}

/// Retry executor with exponential backoff and circuit breaker
class RetryExecutor {
  final RetryPolicy retryPolicy;
  final CircuitBreaker? circuitBreaker;

  const RetryExecutor({required this.retryPolicy, this.circuitBreaker});

  /// Execute operation with retry logic
  Future<T> execute<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    operationName ??= 'transcription_operation';

    for (int attempt = 1; attempt <= retryPolicy.maxAttempts; attempt++) {
      try {
        log(
          'RetryExecutor: Attempting $operationName (attempt $attempt/${retryPolicy.maxAttempts})',
        );

        // Use circuit breaker if available
        if (circuitBreaker != null) {
          return await circuitBreaker!.execute(operation);
        } else {
          return await operation();
        }
      } catch (e) {
        final error = _convertToTranscriptionError(e);

        log(
          'RetryExecutor: $operationName failed on attempt $attempt: ${error.message}',
        );

        // Check if we should retry
        final shouldRetry =
            attempt < retryPolicy.maxAttempts &&
            error.isRetryable &&
            retryPolicy.isRetryable(error.type);

        if (!shouldRetry) {
          log(
            'RetryExecutor: $operationName failed permanently after $attempt attempts',
          );
          throw error;
        }

        // Calculate delay before next attempt
        final delay = retryPolicy.calculateDelay(
          attempt,
          suggestedDelay: error.suggestedRetryDelay,
        );

        log(
          'RetryExecutor: Retrying $operationName after ${delay.inSeconds}s delay',
        );
        await Future.delayed(delay);
      }
    }

    // This should never be reached due to the loop logic, but included for completeness
    throw TranscriptionError(
      type: TranscriptionErrorType.unknownError,
      message: 'Retry executor completed without success or failure',
      isRetryable: false,
    );
  }

  /// Convert any exception to a TranscriptionError
  TranscriptionError _convertToTranscriptionError(Object error) {
    if (error is TranscriptionError) {
      return error;
    } else if (error is HttpException) {
      return TranscriptionError.fromHttpException(error);
    } else if (error is SocketException) {
      return TranscriptionError.fromSocketException(error);
    } else if (error is TimeoutException) {
      return TranscriptionError.fromTimeoutException(error);
    } else if (error is FormatException) {
      return TranscriptionError(
        type: TranscriptionErrorType.invalidRequest,
        message: 'Invalid response format: ${error.message}',
        originalError: error,
        isRetryable: false,
      );
    } else if (error is StateError) {
      return TranscriptionError(
        type: TranscriptionErrorType.configurationError,
        message: error.message,
        originalError: error,
        isRetryable: false,
      );
    } else {
      return TranscriptionError(
        type: TranscriptionErrorType.unknownError,
        message: 'Unexpected error: ${error.toString()}',
        originalError: error,
        isRetryable: true,
        suggestedRetryDelay: const Duration(seconds: 5),
      );
    }
  }
}
