/// Logger Extensions for common logging patterns
///
/// Provides convenient methods for logging with context, performance tracking,
/// and structured data formatting.
library;

import 'dart:async';
import 'bsd_logger_service.dart';

/// Extension methods for BsdLoggerService
extension BsdLoggerExtensions on BsdLoggerService {
  /// Log with context information
  void logWithContext(
    LogPriority priority,
    String message, {
    String? className,
    String? methodName,
    String? userId,
    String? sessionId,
    String? requestId,
    LogFacility? facility,
    Map<String, dynamic>? additionalData,
  }) {
    final contextData = <String, dynamic>{
      if (className != null) 'class': className,
      if (methodName != null) 'method': methodName,
      if (userId != null) 'user_id': userId,
      if (sessionId != null) 'session_id': sessionId,
      if (requestId != null) 'request_id': requestId,
      if (additionalData != null) ...additionalData,
    };

    switch (priority) {
      case LogPriority.emergency:
        emergency(message, facility: facility, data: contextData);
        break;
      case LogPriority.alert:
        alert(message, facility: facility, data: contextData);
        break;
      case LogPriority.critical:
        critical(message, facility: facility, data: contextData);
        break;
      case LogPriority.error:
        error(message, facility: facility, data: contextData);
        break;
      case LogPriority.warning:
        warning(message, facility: facility, data: contextData);
        break;
      case LogPriority.notice:
        notice(message, facility: facility, data: contextData);
        break;
      case LogPriority.info:
        info(message, facility: facility, data: contextData);
        break;
      case LogPriority.debug:
        debug(message, facility: facility, data: contextData);
        break;
    }
  }

  /// Log method entry
  void logMethodEntry(
    String className,
    String methodName, {
    Map<String, dynamic>? parameters,
    String? userId,
    LogFacility? facility,
  }) {
    logWithContext(
      LogPriority.debug,
      'Method entry: $className.$methodName',
      className: className,
      methodName: methodName,
      userId: userId,
      facility: facility,
      additionalData: parameters,
    );
  }

  /// Log method exit
  void logMethodExit(
    String className,
    String methodName, {
    dynamic result,
    Duration? duration,
    String? userId,
    LogFacility? facility,
  }) {
    final data = <String, dynamic>{
      if (result != null) 'result': result.toString(),
      if (duration != null) 'duration_ms': duration.inMilliseconds,
    };

    logWithContext(
      LogPriority.debug,
      'Method exit: $className.$methodName',
      className: className,
      methodName: methodName,
      userId: userId,
      facility: facility,
      additionalData: data,
    );
  }

  /// Log performance metrics
  void logPerformance(
    String operation,
    Duration duration, {
    String? className,
    String? methodName,
    Map<String, dynamic>? metrics,
    LogFacility? facility,
  }) {
    final data = <String, dynamic>{
      'operation': operation,
      'duration_ms': duration.inMilliseconds,
      if (metrics != null) ...metrics,
    };

    logWithContext(
      LogPriority.info,
      'Performance: $operation completed in ${duration.inMilliseconds}ms',
      className: className,
      methodName: methodName,
      facility: facility,
      additionalData: data,
    );
  }

  /// Log database operations
  void logDatabase(
    String operation,
    String? table, {
    int? recordCount,
    Duration? duration,
    String? error,
    LogFacility? facility,
  }) {
    final priority = error != null ? LogPriority.error : LogPriority.info;
    final data = <String, dynamic>{
      'operation': operation,
      if (table != null) 'table': table,
      if (recordCount != null) 'record_count': recordCount,
      if (duration != null) 'duration_ms': duration.inMilliseconds,
      if (error != null) 'error': error,
    };

    final message = error != null
        ? 'Database operation failed: $operation'
        : 'Database operation: $operation';

    switch (priority) {
      case LogPriority.error:
        this.error(
          message,
          facility: facility ?? LogFacility.daemon,
          data: data,
        );
        break;
      case LogPriority.info:
        info(message, facility: facility ?? LogFacility.daemon, data: data);
        break;
      default:
        info(message, facility: facility ?? LogFacility.daemon, data: data);
        break;
    }
  }

  /// Log API requests
  void logApiRequest(
    String method,
    String endpoint, {
    int? statusCode,
    Duration? duration,
    String? error,
    Map<String, dynamic>? requestData,
    LogFacility? facility,
  }) {
    final priority = error != null
        ? LogPriority.error
        : (statusCode != null && statusCode >= 400)
        ? LogPriority.warning
        : LogPriority.info;

    final data = <String, dynamic>{
      'method': method,
      'endpoint': endpoint,
      if (statusCode != null) 'status_code': statusCode,
      if (duration != null) 'duration_ms': duration.inMilliseconds,
      if (error != null) 'error': error,
      if (requestData != null) ...requestData,
    };

    final message = error != null
        ? 'API request failed: $method $endpoint'
        : 'API request: $method $endpoint';

    switch (priority) {
      case LogPriority.error:
        this.error(
          message,
          facility: facility ?? LogFacility.daemon,
          data: data,
        );
        break;
      case LogPriority.warning:
        warning(message, facility: facility ?? LogFacility.daemon, data: data);
        break;
      case LogPriority.info:
        info(message, facility: facility ?? LogFacility.daemon, data: data);
        break;
      default:
        info(message, facility: facility ?? LogFacility.daemon, data: data);
        break;
    }
  }

  /// Log user actions
  void logUserAction(
    String action,
    String userId, {
    String? details,
    Map<String, dynamic>? metadata,
    LogFacility? facility,
  }) {
    final data = <String, dynamic>{
      'action': action,
      'user_id': userId,
      if (details != null) 'details': details,
      if (metadata != null) ...metadata,
    };

    info(
      'User action: $action by $userId',
      facility: facility ?? LogFacility.auth,
      data: data,
    );
  }

  /// Log security events
  void logSecurityEvent(
    String event,
    String? userId, {
    String? ipAddress,
    String? userAgent,
    String? details,
    LogFacility? facility,
  }) {
    final data = <String, dynamic>{
      'event': event,
      if (userId != null) 'user_id': userId,
      if (ipAddress != null) 'ip_address': ipAddress,
      if (userAgent != null) 'user_agent': userAgent,
      if (details != null) 'details': details,
    };

    notice(
      'Security event: $event',
      facility: facility ?? LogFacility.authpriv,
      data: data,
    );
  }

  /// Log system events
  void logSystemEvent(
    String event, {
    String? component,
    String? details,
    Map<String, dynamic>? systemInfo,
    LogFacility? facility,
  }) {
    final data = <String, dynamic>{
      'event': event,
      if (component != null) 'component': component,
      if (details != null) 'details': details,
      if (systemInfo != null) ...systemInfo,
    };

    info(
      'System event: $event',
      facility: facility ?? LogFacility.daemon,
      data: data,
    );
  }

  /// Log errors with stack trace
  void logError(
    String message,
    dynamic error, {
    StackTrace? stackTrace,
    String? className,
    String? methodName,
    LogFacility? facility,
  }) {
    final data = <String, dynamic>{
      'error_type': error.runtimeType.toString(),
      'error_message': error.toString(),
      if (stackTrace != null) 'stack_trace': stackTrace.toString(),
    };

    logWithContext(
      LogPriority.error,
      message,
      className: className,
      methodName: methodName,
      facility: facility,
      additionalData: data,
    );
  }

  /// Time and log a function execution
  Future<T> timeAndLog<T>(
    String operation,
    Future<T> Function() function, {
    String? className,
    String? methodName,
    LogFacility? facility,
  }) async {
    final stopwatch = Stopwatch()..start();

    logWithContext(
      LogPriority.debug,
      'Starting operation: $operation',
      className: className,
      methodName: methodName,
      facility: facility,
    );

    try {
      final result = await function();
      stopwatch.stop();

      logPerformance(
        operation,
        stopwatch.elapsed,
        className: className,
        methodName: methodName,
        facility: facility,
      );

      return result;
    } catch (error, stackTrace) {
      stopwatch.stop();

      logError(
        'Operation failed: $operation',
        error,
        stackTrace: stackTrace,
        className: className,
        methodName: methodName,
        facility: facility,
      );

      rethrow;
    }
  }

  /// Log with automatic retry information
  void logRetry(
    String operation,
    int attempt,
    int maxAttempts, {
    String? error,
    Duration? delay,
    LogFacility? facility,
  }) {
    final data = <String, dynamic>{
      'operation': operation,
      'attempt': attempt,
      'max_attempts': maxAttempts,
      if (error != null) 'error': error,
      if (delay != null) 'retry_delay_ms': delay.inMilliseconds,
    };

    warning(
      'Retry attempt $attempt/$maxAttempts for: $operation',
      facility: facility,
      data: data,
    );
  }

  /// Log configuration changes
  void logConfigChange(
    String setting,
    dynamic oldValue,
    dynamic newValue, {
    String? userId,
    LogFacility? facility,
  }) {
    final data = <String, dynamic>{
      'setting': setting,
      'old_value': oldValue?.toString(),
      'new_value': newValue?.toString(),
      if (userId != null) 'changed_by': userId,
    };

    notice(
      'Configuration changed: $setting',
      facility: facility ?? LogFacility.daemon,
      data: data,
    );
  }
}

/// Logger mixin for easy integration with classes
mixin LoggerMixin {
  static final BsdLoggerService _logger = BsdLoggerService.getInstance();

  /// Get the logger instance
  BsdLoggerService get logger => _logger;

  /// Get the class name for logging
  String get className => runtimeType.toString();

  /// Log with class context
  void logWithClass(
    LogPriority priority,
    String message, {
    String? methodName,
    LogFacility? facility,
    Map<String, dynamic>? data,
  }) {
    _logger.logWithContext(
      priority,
      message,
      className: className,
      methodName: methodName,
      facility: facility,
      additionalData: data,
    );
  }

  /// Log method entry with class context
  void logEntry(
    String methodName, {
    Map<String, dynamic>? parameters,
    LogFacility? facility,
  }) {
    _logger.logMethodEntry(
      className,
      methodName,
      parameters: parameters,
      facility: facility,
    );
  }

  /// Log method exit with class context
  void logExit(
    String methodName, {
    dynamic result,
    Duration? duration,
    LogFacility? facility,
  }) {
    _logger.logMethodExit(
      className,
      methodName,
      result: result,
      duration: duration,
      facility: facility,
    );
  }

  /// Log error with class context
  void logError(
    String message,
    dynamic error, {
    StackTrace? stackTrace,
    String? methodName,
    LogFacility? facility,
  }) {
    _logger.logError(
      message,
      error,
      stackTrace: stackTrace,
      className: className,
      methodName: methodName,
      facility: facility,
    );
  }

  /// Time and log method execution
  Future<T> timeMethod<T>(
    String methodName,
    Future<T> Function() function, {
    LogFacility? facility,
  }) {
    return _logger.timeAndLog(
      '$className.$methodName',
      function,
      className: className,
      methodName: methodName,
      facility: facility,
    );
  }
}

/// Convenience logger instance
final logger = BsdLoggerService.getInstance();
