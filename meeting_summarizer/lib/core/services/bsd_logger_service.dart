/// BSD Syslog Format (RFC3164) Logger Service
///
/// Provides structured logging following BSD syslog format with:
/// - Priority levels (Emergency, Alert, Critical, Error, Warning, Notice, Info, Debug)
/// - Facility types (User, Mail, Daemon, Auth, Syslog, etc.)
/// - Timestamp formatting
/// - Hostname and process identification
/// - Message formatting with structured data
///
/// Usage:
/// ```dart
/// final logger = BsdLoggerService.getInstance();
/// logger.info('Application started');
/// logger.error('Database connection failed', facility: LogFacility.daemon);
/// logger.debug('Processing request', data: {'userId': '123', 'action': 'login'});
/// ```
library;

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// BSD Syslog priority levels (RFC3164)
enum LogPriority {
  emergency(0, 'EMERG'), // System is unusable
  alert(1, 'ALERT'), // Action must be taken immediately
  critical(2, 'CRIT'), // Critical conditions
  error(3, 'ERROR'), // Error conditions
  warning(4, 'WARN'), // Warning conditions
  notice(5, 'NOTICE'), // Normal but significant condition
  info(6, 'INFO'), // Informational messages
  debug(7, 'DEBUG'); // Debug-level messages

  const LogPriority(this.value, this.name);
  final int value;
  final String name;
}

/// BSD Syslog facility types (RFC3164)
enum LogFacility {
  kernel(0, 'KERN'), // Kernel messages
  user(1, 'USER'), // User-level messages
  mail(2, 'MAIL'), // Mail system
  daemon(3, 'DAEMON'), // System daemons
  auth(4, 'AUTH'), // Security/authorization messages
  syslog(5, 'SYSLOG'), // Messages generated internally by syslogd
  lpr(6, 'LPR'), // Line printer subsystem
  news(7, 'NEWS'), // Network news subsystem
  uucp(8, 'UUCP'), // UUCP subsystem
  cron(9, 'CRON'), // Clock daemon
  authpriv(10, 'AUTHPRIV'), // Security/authorization messages
  ftp(11, 'FTP'), // FTP daemon
  local0(16, 'LOCAL0'), // Local use facility 0
  local1(17, 'LOCAL1'), // Local use facility 1
  local2(18, 'LOCAL2'), // Local use facility 2
  local3(19, 'LOCAL3'), // Local use facility 3
  local4(20, 'LOCAL4'), // Local use facility 4
  local5(21, 'LOCAL5'), // Local use facility 5
  local6(22, 'LOCAL6'), // Local use facility 6
  local7(23, 'LOCAL7'); // Local use facility 7

  const LogFacility(this.value, this.name);
  final int value;
  final String name;
}

/// Log configuration for BSD Logger
class LogConfig {
  final LogPriority minLevel;
  final LogFacility defaultFacility;
  final String hostname;
  final String processName;
  final bool enableConsoleOutput;
  final bool enableFileOutput;
  final String? logFilePath;
  final int maxLogFileSize;
  final int maxLogFiles;
  final String timestampFormat;
  final bool enableStructuredData;

  const LogConfig({
    this.minLevel = LogPriority.info,
    this.defaultFacility = LogFacility.user,
    this.hostname = 'localhost',
    this.processName = 'meeting-summarizer',
    this.enableConsoleOutput = true,
    this.enableFileOutput = false,
    this.logFilePath,
    this.maxLogFileSize = 10 * 1024 * 1024, // 10MB
    this.maxLogFiles = 5,
    this.timestampFormat = 'MMM dd HH:mm:ss',
    this.enableStructuredData = true,
  });
}

/// Structured log entry following BSD syslog format
class LogEntry {
  final LogPriority priority;
  final LogFacility facility;
  final DateTime timestamp;
  final String hostname;
  final String processName;
  final String message;
  final Map<String, dynamic>? structuredData;
  final String? tag;
  final int? processId;

  const LogEntry({
    required this.priority,
    required this.facility,
    required this.timestamp,
    required this.hostname,
    required this.processName,
    required this.message,
    this.structuredData,
    this.tag,
    this.processId,
  });

  /// Calculate BSD syslog priority value (facility * 8 + priority)
  int get priorityValue => facility.value * 8 + priority.value;

  /// Format the log entry according to BSD syslog format (RFC3164)
  String toBsdFormat(String timestampFormat) {
    final timestampStr = _formatTimestamp(timestamp, timestampFormat);
    final priorityStr = '<$priorityValue>';
    final processInfo = processId != null
        ? '$processName[$processId]'
        : processName;
    final tagStr = tag != null ? '[$tag]' : '';

    var formattedMessage =
        '$priorityStr$timestampStr $hostname $processInfo$tagStr: $message';

    // Add structured data if enabled
    if (structuredData != null && structuredData!.isNotEmpty) {
      final structuredStr = _formatStructuredData(structuredData!);
      formattedMessage += ' $structuredStr';
    }

    return formattedMessage;
  }

  /// Format timestamp according to BSD syslog format
  String _formatTimestamp(DateTime timestamp, String format) {
    // Simple timestamp formatting for BSD syslog
    final month = _getMonthName(timestamp.month);
    final day = timestamp.day.toString().padLeft(2, ' ');
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');

    return '$month $day $hour:$minute:$second';
  }

  /// Get month name abbreviation
  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  /// Format structured data according to RFC5424 style
  String _formatStructuredData(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.write('[');

    final entries = data.entries
        .map((e) {
          final value = e.value.toString().replaceAll('"', '\\"');
          return '${e.key}="$value"';
        })
        .join(' ');

    buffer.write(entries);
    buffer.write(']');

    return buffer.toString();
  }

  /// Convert to JSON for structured logging
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'priority': priority.name,
      'facility': facility.name,
      'hostname': hostname,
      'process': processName,
      'pid': processId,
      'tag': tag,
      'message': message,
      'structured_data': structuredData,
    };
  }
}

/// BSD Syslog Logger Service Implementation
class BsdLoggerService {
  static BsdLoggerService? _instance;
  static BsdLoggerService getInstance() {
    _instance ??= BsdLoggerService._internal();
    return _instance!;
  }

  BsdLoggerService._internal();

  LogConfig _config = const LogConfig();
  bool _isInitialized = false;
  File? _logFile;
  final List<LogEntry> _logBuffer = [];
  static const int _maxBufferSize = 1000;

  /// Initialize the logger with configuration
  Future<void> initialize({LogConfig? config}) async {
    _config = config ?? const LogConfig();

    if (_config.enableFileOutput) {
      await _initializeFileLogging();
    }

    _isInitialized = true;
  }

  /// Initialize file logging
  Future<void> _initializeFileLogging() async {
    if (_config.logFilePath != null) {
      _logFile = File(_config.logFilePath!);
      final directory = _logFile!.parent;
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }
  }

  /// Log an emergency message
  void emergency(
    String message, {
    LogFacility? facility,
    String? tag,
    Map<String, dynamic>? data,
  }) {
    _log(
      LogPriority.emergency,
      message,
      facility: facility,
      tag: tag,
      data: data,
    );
  }

  /// Log an alert message
  void alert(
    String message, {
    LogFacility? facility,
    String? tag,
    Map<String, dynamic>? data,
  }) {
    _log(LogPriority.alert, message, facility: facility, tag: tag, data: data);
  }

  /// Log a critical message
  void critical(
    String message, {
    LogFacility? facility,
    String? tag,
    Map<String, dynamic>? data,
  }) {
    _log(
      LogPriority.critical,
      message,
      facility: facility,
      tag: tag,
      data: data,
    );
  }

  /// Log an error message
  void error(
    String message, {
    LogFacility? facility,
    String? tag,
    Map<String, dynamic>? data,
  }) {
    _log(LogPriority.error, message, facility: facility, tag: tag, data: data);
  }

  /// Log a warning message
  void warning(
    String message, {
    LogFacility? facility,
    String? tag,
    Map<String, dynamic>? data,
  }) {
    _log(
      LogPriority.warning,
      message,
      facility: facility,
      tag: tag,
      data: data,
    );
  }

  /// Log a notice message
  void notice(
    String message, {
    LogFacility? facility,
    String? tag,
    Map<String, dynamic>? data,
  }) {
    _log(LogPriority.notice, message, facility: facility, tag: tag, data: data);
  }

  /// Log an informational message
  void info(
    String message, {
    LogFacility? facility,
    String? tag,
    Map<String, dynamic>? data,
  }) {
    _log(LogPriority.info, message, facility: facility, tag: tag, data: data);
  }

  /// Log a debug message
  void debug(
    String message, {
    LogFacility? facility,
    String? tag,
    Map<String, dynamic>? data,
  }) {
    _log(LogPriority.debug, message, facility: facility, tag: tag, data: data);
  }

  /// Core logging method
  void _log(
    LogPriority priority,
    String message, {
    LogFacility? facility,
    String? tag,
    Map<String, dynamic>? data,
  }) {
    if (!_isInitialized) {
      // Fall back to debugPrint if not initialized
      debugPrint('BsdLogger not initialized: $message');
      return;
    }

    // Check if log level is enabled
    if (priority.value > _config.minLevel.value) {
      return;
    }

    final entry = LogEntry(
      priority: priority,
      facility: facility ?? _config.defaultFacility,
      timestamp: DateTime.now(),
      hostname: _config.hostname,
      processName: _config.processName,
      message: message,
      structuredData: _config.enableStructuredData ? data : null,
      tag: tag,
      processId: pid,
    );

    _processLogEntry(entry);
  }

  /// Process and output log entry
  void _processLogEntry(LogEntry entry) {
    // Add to buffer
    _logBuffer.add(entry);
    if (_logBuffer.length > _maxBufferSize) {
      _logBuffer.removeAt(0);
    }

    // Console output
    if (_config.enableConsoleOutput) {
      _outputToConsole(entry);
    }

    // File output
    if (_config.enableFileOutput && _logFile != null) {
      _outputToFile(entry);
    }
  }

  /// Output to console
  void _outputToConsole(LogEntry entry) {
    final formattedMessage = entry.toBsdFormat(_config.timestampFormat);

    if (kDebugMode) {
      // Use different output methods based on priority
      switch (entry.priority) {
        case LogPriority.emergency:
        case LogPriority.alert:
        case LogPriority.critical:
        case LogPriority.error:
          debugPrint('🔴 $formattedMessage');
          break;
        case LogPriority.warning:
          debugPrint('🟡 $formattedMessage');
          break;
        case LogPriority.notice:
          debugPrint('🔵 $formattedMessage');
          break;
        case LogPriority.info:
          debugPrint('ℹ️ $formattedMessage');
          break;
        case LogPriority.debug:
          debugPrint('🐛 $formattedMessage');
          break;
      }
    } else {
      // In release mode, use debugPrint for important messages
      if (entry.priority.value <= LogPriority.error.value) {
        debugPrint(formattedMessage);
      }
    }
  }

  /// Output to file
  void _outputToFile(LogEntry entry) {
    if (_logFile == null) return;

    try {
      final formattedMessage = entry.toBsdFormat(_config.timestampFormat);
      _logFile!.writeAsStringSync('$formattedMessage\n', mode: FileMode.append);

      // Check file size and rotate if necessary
      _checkAndRotateLog();
    } catch (e) {
      debugPrint('BsdLoggerService: Failed to write to log file: $e');
    }
  }

  /// Check and rotate log files
  void _checkAndRotateLog() {
    if (_logFile == null) return;

    try {
      final stat = _logFile!.statSync();
      if (stat.size > _config.maxLogFileSize) {
        _rotateLogFile();
      }
    } catch (e) {
      debugPrint('BsdLoggerService: Failed to check log file size: $e');
    }
  }

  /// Rotate log file
  Future<void> _rotateLogFile() async {
    if (_logFile == null) return;

    try {
      final basePath = _logFile!.path;

      // Rotate existing log files
      for (int i = _config.maxLogFiles - 1; i > 0; i--) {
        final oldFile = File('$basePath.$i');
        final newFile = File('$basePath.${i + 1}');

        if (await oldFile.exists()) {
          await oldFile.rename(newFile.path);
        }
      }

      // Move current log to .1
      final rotatedFile = File('$basePath.1');
      await _logFile!.rename(rotatedFile.path);

      // Create new log file
      _logFile = File(basePath);
    } catch (e) {
      debugPrint('BsdLoggerService: Failed to rotate log file: $e');
    }
  }

  /// Get recent log entries
  List<LogEntry> getRecentLogs({int limit = 100}) {
    final start = _logBuffer.length > limit ? _logBuffer.length - limit : 0;
    return _logBuffer.sublist(start);
  }

  /// Get logs filtered by priority
  List<LogEntry> getLogsByPriority(LogPriority priority) {
    return _logBuffer.where((entry) => entry.priority == priority).toList();
  }

  /// Get logs filtered by facility
  List<LogEntry> getLogsByFacility(LogFacility facility) {
    return _logBuffer.where((entry) => entry.facility == facility).toList();
  }

  /// Get logs within time range
  List<LogEntry> getLogsByTimeRange(DateTime start, DateTime end) {
    return _logBuffer.where((entry) {
      return entry.timestamp.isAfter(start) && entry.timestamp.isBefore(end);
    }).toList();
  }

  /// Search logs by message content
  List<LogEntry> searchLogs(String query) {
    return _logBuffer.where((entry) {
      return entry.message.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  /// Export logs to JSON
  String exportLogsToJson({int? limit}) {
    final logs = limit != null ? getRecentLogs(limit: limit) : _logBuffer;
    return jsonEncode(logs.map((entry) => entry.toJson()).toList());
  }

  /// Clear log buffer
  void clearBuffer() {
    _logBuffer.clear();
  }

  /// Get current configuration
  LogConfig get config => _config;

  /// Update configuration
  Future<void> updateConfig(LogConfig newConfig) async {
    _config = newConfig;

    if (_config.enableFileOutput && _logFile == null) {
      await _initializeFileLogging();
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _logBuffer.clear();
    _logFile = null;
    _isInitialized = false;
  }
}
