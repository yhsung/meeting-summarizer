/// Exception classes for AI summarization operations
library;

/// Base exception for all summarization-related errors
abstract class SummarizationException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const SummarizationException(
    this.message, {
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    final codeStr = code != null ? ' [$code]' : '';
    return 'SummarizationException$codeStr: $message';
  }
}

/// Exception thrown when service initialization fails
class SummarizationInitializationException extends SummarizationException {
  const SummarizationInitializationException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Exception thrown when configuration is invalid
class InvalidConfigurationException extends SummarizationException {
  final List<String> validationErrors;

  const InvalidConfigurationException(
    super.message,
    this.validationErrors, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    final codeStr = code != null ? ' [$code]' : '';
    final errorsStr = validationErrors.join(', ');
    return 'InvalidConfigurationException$codeStr: $message. Errors: $errorsStr';
  }
}

/// Exception thrown when API quota is exceeded
class QuotaExceededException extends SummarizationException {
  final int currentUsage;
  final int quotaLimit;
  final DateTime? resetTime;

  const QuotaExceededException(
    super.message,
    this.currentUsage,
    this.quotaLimit, {
    this.resetTime,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    final codeStr = code != null ? ' [$code]' : '';
    final resetStr = resetTime != null ? ' (resets at $resetTime)' : '';
    return 'QuotaExceededException$codeStr: $message. Usage: $currentUsage/$quotaLimit$resetStr';
  }
}

/// Exception thrown when input text exceeds token limits
class TokenLimitExceededException extends SummarizationException {
  final int actualTokens;
  final int maxTokens;

  const TokenLimitExceededException(
    super.message,
    this.actualTokens,
    this.maxTokens, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    final codeStr = code != null ? ' [$code]' : '';
    return 'TokenLimitExceededException$codeStr: $message. Tokens: $actualTokens/$maxTokens';
  }
}

/// Exception thrown when AI model is unavailable
class ModelUnavailableException extends SummarizationException {
  final String modelName;

  const ModelUnavailableException(
    super.message,
    this.modelName, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    final codeStr = code != null ? ' [$code]' : '';
    return 'ModelUnavailableException$codeStr: $message. Model: $modelName';
  }
}

/// Exception thrown when API rate limits are hit
class RateLimitExceededException extends SummarizationException {
  final Duration retryAfter;

  const RateLimitExceededException(
    super.message,
    this.retryAfter, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    final codeStr = code != null ? ' [$code]' : '';
    return 'RateLimitExceededException$codeStr: $message. Retry after: $retryAfter';
  }
}

/// Exception thrown when authentication fails
class AuthenticationException extends SummarizationException {
  const AuthenticationException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Exception thrown when AI processing fails
class AIProcessingException extends SummarizationException {
  final String? modelResponse;

  const AIProcessingException(
    super.message, {
    this.modelResponse,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    final codeStr = code != null ? ' [$code]' : '';
    final responseStr = modelResponse != null
        ? ' Response: $modelResponse'
        : '';
    return 'AIProcessingException$codeStr: $message.$responseStr';
  }
}

/// Exception thrown when network requests fail
class NetworkException extends SummarizationException {
  final int? statusCode;

  const NetworkException(
    super.message, {
    this.statusCode,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    final codeStr = code != null ? ' [$code]' : '';
    final statusStr = statusCode != null ? ' (HTTP $statusCode)' : '';
    return 'NetworkException$codeStr: $message$statusStr';
  }
}

/// Exception thrown when response parsing fails
class ResponseParsingException extends SummarizationException {
  final String? rawResponse;

  const ResponseParsingException(
    super.message, {
    this.rawResponse,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    final codeStr = code != null ? ' [$code]' : '';
    return 'ResponseParsingException$codeStr: $message';
  }
}

/// Exception thrown when operation times out
class TimeoutException extends SummarizationException {
  final Duration timeout;

  const TimeoutException(
    super.message,
    this.timeout, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    final codeStr = code != null ? ' [$code]' : '';
    return 'TimeoutException$codeStr: $message. Timeout: $timeout';
  }
}

/// Exception thrown when service is unavailable
class ServiceUnavailableException extends SummarizationException {
  const ServiceUnavailableException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });
}

/// Utility class for creating common exceptions
class SummarizationExceptions {
  SummarizationExceptions._();

  static SummarizationInitializationException initializationFailed(
    String reason, {
    dynamic originalError,
    StackTrace? stackTrace,
  }) {
    return SummarizationInitializationException(
      'Failed to initialize summarization service: $reason',
      code: 'INIT_FAILED',
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  static InvalidConfigurationException invalidConfiguration(
    List<String> errors, {
    String? additionalMessage,
  }) {
    final message = additionalMessage ?? 'Configuration validation failed';
    return InvalidConfigurationException(
      message,
      errors,
      code: 'INVALID_CONFIG',
    );
  }

  static TokenLimitExceededException tokenLimitExceeded(
    int actualTokens,
    int maxTokens,
  ) {
    return TokenLimitExceededException(
      'Input text exceeds maximum token limit',
      actualTokens,
      maxTokens,
      code: 'TOKEN_LIMIT_EXCEEDED',
    );
  }

  static QuotaExceededException quotaExceeded(
    int currentUsage,
    int quotaLimit, {
    DateTime? resetTime,
  }) {
    return QuotaExceededException(
      'API quota limit exceeded',
      currentUsage,
      quotaLimit,
      resetTime: resetTime,
      code: 'QUOTA_EXCEEDED',
    );
  }

  static RateLimitExceededException rateLimitExceeded(Duration retryAfter) {
    return RateLimitExceededException(
      'API rate limit exceeded',
      retryAfter,
      code: 'RATE_LIMIT_EXCEEDED',
    );
  }

  static AuthenticationException authenticationFailed([String? reason]) {
    final message = reason != null
        ? 'Authentication failed: $reason'
        : 'Authentication failed';
    return AuthenticationException(message, code: 'AUTH_FAILED');
  }

  static ModelUnavailableException modelUnavailable(String modelName) {
    return ModelUnavailableException(
      'AI model is currently unavailable',
      modelName,
      code: 'MODEL_UNAVAILABLE',
    );
  }

  static AIProcessingException processingFailed(
    String reason, {
    String? modelResponse,
  }) {
    return AIProcessingException(
      'AI processing failed: $reason',
      modelResponse: modelResponse,
      code: 'PROCESSING_FAILED',
    );
  }

  static NetworkException networkError(
    String reason, {
    int? statusCode,
    dynamic originalError,
  }) {
    return NetworkException(
      'Network error: $reason',
      statusCode: statusCode,
      code: 'NETWORK_ERROR',
      originalError: originalError,
    );
  }

  static ResponseParsingException parsingFailed(
    String reason, {
    String? rawResponse,
  }) {
    return ResponseParsingException(
      'Failed to parse response: $reason',
      rawResponse: rawResponse,
      code: 'PARSING_FAILED',
    );
  }

  static TimeoutException operationTimeout(Duration timeout) {
    return TimeoutException(
      'Operation timed out',
      timeout,
      code: 'OPERATION_TIMEOUT',
    );
  }

  static ServiceUnavailableException serviceUnavailable([String? reason]) {
    final message = reason != null
        ? 'Service unavailable: $reason'
        : 'Summarization service is currently unavailable';
    return ServiceUnavailableException(message, code: 'SERVICE_UNAVAILABLE');
  }
}
