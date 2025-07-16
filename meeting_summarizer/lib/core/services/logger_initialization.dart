/// Logger Initialization and Configuration
///
/// Provides centralized initialization and configuration for the BSD logger system.
/// This should be called during app startup to configure logging behavior.
library;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'bsd_logger_service.dart';
import 'logger_extensions.dart';

class LoggerInitialization {
  static bool _isInitialized = false;

  /// Initialize the logger system with appropriate configuration
  static Future<void> initialize({
    LogPriority? minLevel,
    bool? enableFileLogging,
    String? logFileName,
  }) async {
    if (_isInitialized) return;

    final logger = BsdLoggerService.getInstance();

    // Determine log level based on build mode
    final logLevel =
        minLevel ?? (kDebugMode ? LogPriority.debug : LogPriority.info);

    // Configure file logging for production builds
    String? logFilePath;
    if (enableFileLogging == true ||
        (!kDebugMode && enableFileLogging != false)) {
      logFilePath = await _getLogFilePath(
        logFileName ?? 'meeting_summarizer.log',
      );
    }

    final config = LogConfig(
      minLevel: logLevel,
      defaultFacility: LogFacility.user,
      hostname: _getHostname(),
      processName: 'meeting-summarizer',
      enableConsoleOutput: true,
      enableFileOutput: logFilePath != null,
      logFilePath: logFilePath,
      maxLogFileSize: 10 * 1024 * 1024, // 10MB
      maxLogFiles: 5,
      timestampFormat: 'MMM dd HH:mm:ss',
      enableStructuredData: true,
    );

    await logger.initialize(config: config);
    _isInitialized = true;

    // Log initialization
    logger.info(
      'Logger initialized',
      data: {
        'log_level': logLevel.name,
        'console_output': config.enableConsoleOutput,
        'file_output': config.enableFileOutput,
        'log_file': logFilePath,
        'debug_mode': kDebugMode,
      },
    );
  }

  /// Get the appropriate log file path
  static Future<String> _getLogFilePath(String fileName) async {
    final directory = await getApplicationSupportDirectory();
    final logsDir = Directory(path.join(directory.path, 'logs'));

    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }

    return path.join(logsDir.path, fileName);
  }

  /// Get hostname for logging
  static String _getHostname() {
    try {
      return Platform.localHostname;
    } catch (e) {
      return 'unknown';
    }
  }

  /// Configure logging for different environments
  static Future<void> configureForEnvironment(String environment) async {
    late LogConfig config;

    switch (environment.toLowerCase()) {
      case 'development':
        config = const LogConfig(
          minLevel: LogPriority.debug,
          enableConsoleOutput: true,
          enableFileOutput: false,
          enableStructuredData: true,
        );
        break;

      case 'testing':
        config = const LogConfig(
          minLevel: LogPriority.info,
          enableConsoleOutput: true,
          enableFileOutput: false,
          enableStructuredData: true,
        );
        break;

      case 'staging':
        config = LogConfig(
          minLevel: LogPriority.info,
          enableConsoleOutput: true,
          enableFileOutput: true,
          logFilePath: await _getLogFilePath('meeting_summarizer_staging.log'),
          enableStructuredData: true,
        );
        break;

      case 'production':
        config = LogConfig(
          minLevel: LogPriority.notice,
          enableConsoleOutput: false,
          enableFileOutput: true,
          logFilePath: await _getLogFilePath(
            'meeting_summarizer_production.log',
          ),
          maxLogFileSize: 50 * 1024 * 1024, // 50MB
          maxLogFiles: 10,
          enableStructuredData: true,
        );
        break;

      default:
        config = const LogConfig(); // Default configuration
    }

    final logger = BsdLoggerService.getInstance();
    await logger.updateConfig(config);

    logger.info(
      'Logger configured for environment',
      data: {
        'environment': environment,
        'config': {
          'min_level': config.minLevel.name,
          'console_output': config.enableConsoleOutput,
          'file_output': config.enableFileOutput,
          'log_file': config.logFilePath,
        },
      },
    );
  }

  /// Enable or disable specific log levels
  static Future<void> setLogLevel(LogPriority level) async {
    final logger = BsdLoggerService.getInstance();
    final currentConfig = logger.config;

    final newConfig = LogConfig(
      minLevel: level,
      defaultFacility: currentConfig.defaultFacility,
      hostname: currentConfig.hostname,
      processName: currentConfig.processName,
      enableConsoleOutput: currentConfig.enableConsoleOutput,
      enableFileOutput: currentConfig.enableFileOutput,
      logFilePath: currentConfig.logFilePath,
      maxLogFileSize: currentConfig.maxLogFileSize,
      maxLogFiles: currentConfig.maxLogFiles,
      timestampFormat: currentConfig.timestampFormat,
      enableStructuredData: currentConfig.enableStructuredData,
    );

    await logger.updateConfig(newConfig);

    logger.info(
      'Log level changed',
      data: {'old_level': currentConfig.minLevel.name, 'new_level': level.name},
    );
  }

  /// Get current logger configuration
  static LogConfig getCurrentConfig() {
    final logger = BsdLoggerService.getInstance();
    return logger.config;
  }

  /// Check if logger is initialized
  static bool get isInitialized => _isInitialized;
}

/// Migration helper for existing debugPrint calls
class LoggerMigration {
  static final BsdLoggerService _logger = BsdLoggerService.getInstance();

  /// Replace debugPrint with structured logging
  static void debugPrint(
    String message, {
    String? className,
    String? methodName,
    LogFacility? facility,
    Map<String, dynamic>? data,
  }) {
    if (kDebugMode) {
      _logger.logWithContext(
        LogPriority.debug,
        message,
        className: className,
        methodName: methodName,
        facility: facility,
        additionalData: data,
      );
    }
  }

  /// Replace print with structured logging
  static void print(
    String message, {
    LogPriority priority = LogPriority.info,
    String? className,
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

  /// Log service operations
  static void logServiceOperation(
    String serviceName,
    String operation, {
    bool success = true,
    String? error,
    Duration? duration,
    Map<String, dynamic>? metadata,
  }) {
    final priority = success ? LogPriority.info : LogPriority.error;
    final message = success
        ? '$serviceName: $operation completed'
        : '$serviceName: $operation failed';

    final data = <String, dynamic>{
      'service': serviceName,
      'operation': operation,
      'success': success,
      if (error != null) 'error': error,
      if (duration != null) 'duration_ms': duration.inMilliseconds,
      if (metadata != null) ...metadata,
    };

    _logger.logWithContext(
      priority,
      message,
      className: serviceName,
      methodName: operation,
      facility: LogFacility.daemon,
      additionalData: data,
    );
  }

  /// Log database operations
  static void logDatabaseOperation(
    String operation,
    String table, {
    bool success = true,
    String? error,
    Duration? duration,
    int? recordCount,
  }) {
    _logger.logDatabase(
      operation,
      table,
      recordCount: recordCount,
      duration: duration,
      error: error,
    );
  }

  /// Log API calls
  static void logApiCall(
    String method,
    String endpoint, {
    int? statusCode,
    Duration? duration,
    String? error,
    Map<String, dynamic>? requestData,
  }) {
    _logger.logApiRequest(
      method,
      endpoint,
      statusCode: statusCode,
      duration: duration,
      error: error,
      requestData: requestData,
    );
  }
}

/// Example usage and migration patterns
class LoggingExamples {
  static void showMigrationExamples() {
    // OLD: debugPrint('LocalWhisperService: Initialization complete');
    // NEW:
    LoggerMigration.debugPrint(
      'Initialization complete',
      className: 'LocalWhisperService',
      methodName: 'initialize',
    );

    // OLD: debugPrint('DatabaseHelper: Query executed in ${duration.inMilliseconds}ms');
    // NEW:
    LoggerMigration.logDatabaseOperation(
      'SELECT',
      'recordings',
      success: true,
      duration: Duration(milliseconds: 150),
      recordCount: 10,
    );

    // OLD: debugPrint('API request failed: $error');
    // NEW:
    LoggerMigration.logApiCall(
      'POST',
      '/api/transcribe',
      statusCode: 500,
      duration: Duration(seconds: 2),
      error: 'Server error',
    );
  }
}
