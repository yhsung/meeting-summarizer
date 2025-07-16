import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/services/bsd_logger_service.dart';
import 'package:meeting_summarizer/core/services/logger_extensions.dart';

void main() {
  group('BsdLoggerService', () {
    late BsdLoggerService logger;

    setUp(() {
      logger = BsdLoggerService.getInstance();
    });

    tearDown(() async {
      await logger.dispose();
    });

    group('Singleton Pattern', () {
      test('should return the same instance', () {
        final logger1 = BsdLoggerService.getInstance();
        final logger2 = BsdLoggerService.getInstance();
        expect(logger1, same(logger2));
      });
    });

    group('Log Levels', () {
      test('should log emergency messages', () {
        expect(() => logger.emergency('System is down'), returnsNormally);
      });

      test('should log alert messages', () {
        expect(
          () => logger.alert('Immediate action required'),
          returnsNormally,
        );
      });

      test('should log critical messages', () {
        expect(() => logger.critical('Critical condition'), returnsNormally);
      });

      test('should log error messages', () {
        expect(() => logger.error('Error occurred'), returnsNormally);
      });

      test('should log warning messages', () {
        expect(() => logger.warning('Warning condition'), returnsNormally);
      });

      test('should log notice messages', () {
        expect(() => logger.notice('Normal but significant'), returnsNormally);
      });

      test('should log info messages', () {
        expect(() => logger.info('Information message'), returnsNormally);
      });

      test('should log debug messages', () {
        expect(() => logger.debug('Debug information'), returnsNormally);
      });
    });

    group('Log Entry Formatting', () {
      test('should format log entry with BSD syslog format', () {
        final entry = LogEntry(
          priority: LogPriority.info,
          facility: LogFacility.user,
          timestamp: DateTime(2024, 1, 15, 10, 30, 45),
          hostname: 'testhost',
          processName: 'testapp',
          message: 'Test message',
          processId: 1234,
        );

        final formatted = entry.toBsdFormat('MMM dd HH:mm:ss');
        expect(
          formatted,
          contains('<14>'),
        ); // Priority value: user(1) * 8 + info(6) = 14
        expect(formatted, contains('Jan 15 10:30:45'));
        expect(formatted, contains('testhost'));
        expect(formatted, contains('testapp[1234]'));
        expect(formatted, contains('Test message'));
      });

      test('should format log entry with structured data', () {
        final entry = LogEntry(
          priority: LogPriority.info,
          facility: LogFacility.user,
          timestamp: DateTime(2024, 1, 15, 10, 30, 45),
          hostname: 'testhost',
          processName: 'testapp',
          message: 'Test message',
          structuredData: {'userId': '123', 'action': 'login'},
        );

        final formatted = entry.toBsdFormat('MMM dd HH:mm:ss');
        expect(formatted, contains('[userId="123" action="login"]'));
      });

      test('should format log entry with tag', () {
        final entry = LogEntry(
          priority: LogPriority.info,
          facility: LogFacility.user,
          timestamp: DateTime(2024, 1, 15, 10, 30, 45),
          hostname: 'testhost',
          processName: 'testapp',
          message: 'Test message',
          tag: 'AUTH',
        );

        final formatted = entry.toBsdFormat('MMM dd HH:mm:ss');
        expect(formatted, contains('[AUTH]'));
      });
    });

    group('Priority Calculation', () {
      test('should calculate correct priority value', () {
        final entry = LogEntry(
          priority: LogPriority.error,
          facility: LogFacility.mail,
          timestamp: DateTime.now(),
          hostname: 'test',
          processName: 'test',
          message: 'test',
        );

        // mail(2) * 8 + error(3) = 19
        expect(entry.priorityValue, equals(19));
      });

      test('should calculate priority for different facilities', () {
        final kernelEmergency = LogEntry(
          priority: LogPriority.emergency,
          facility: LogFacility.kernel,
          timestamp: DateTime.now(),
          hostname: 'test',
          processName: 'test',
          message: 'test',
        );

        final userInfo = LogEntry(
          priority: LogPriority.info,
          facility: LogFacility.user,
          timestamp: DateTime.now(),
          hostname: 'test',
          processName: 'test',
          message: 'test',
        );

        // kernel(0) * 8 + emergency(0) = 0
        expect(kernelEmergency.priorityValue, equals(0));
        // user(1) * 8 + info(6) = 14
        expect(userInfo.priorityValue, equals(14));
      });
    });

    group('Configuration', () {
      test('should initialize with default config', () async {
        await logger.initialize();
        expect(logger.config.minLevel, equals(LogPriority.info));
        expect(logger.config.defaultFacility, equals(LogFacility.user));
        expect(logger.config.enableConsoleOutput, isTrue);
        expect(logger.config.enableFileOutput, isFalse);
      });

      test('should initialize with custom config', () async {
        final config = LogConfig(
          minLevel: LogPriority.debug,
          defaultFacility: LogFacility.daemon,
          enableConsoleOutput: false,
          enableFileOutput: true,
        );

        await logger.initialize(config: config);
        expect(logger.config.minLevel, equals(LogPriority.debug));
        expect(logger.config.defaultFacility, equals(LogFacility.daemon));
        expect(logger.config.enableConsoleOutput, isFalse);
        expect(logger.config.enableFileOutput, isTrue);
      });
    });

    group('Log Buffer', () {
      test('should store log entries in buffer', () async {
        await logger.initialize();
        logger.info('Test message');

        final logs = logger.getRecentLogs(limit: 10);
        expect(logs.length, equals(1));
        expect(logs.first.message, equals('Test message'));
      });

      test('should filter logs by priority', () async {
        await logger.initialize();
        logger.info('Info message');
        logger.error('Error message');
        logger.debug('Debug message');

        final errorLogs = logger.getLogsByPriority(LogPriority.error);
        expect(errorLogs.length, equals(1));
        expect(errorLogs.first.message, equals('Error message'));
      });

      test('should filter logs by facility', () async {
        await logger.initialize();
        logger.info('User message', facility: LogFacility.user);
        logger.info('Daemon message', facility: LogFacility.daemon);

        final userLogs = logger.getLogsByFacility(LogFacility.user);
        expect(userLogs.length, equals(1));
        expect(userLogs.first.message, equals('User message'));
      });

      test('should search logs by content', () async {
        await logger.initialize();
        logger.info('Database connection established');
        logger.info('User login successful');
        logger.info('Database query executed');

        final dbLogs = logger.searchLogs('database');
        expect(dbLogs.length, equals(2));
      });

      test('should clear log buffer', () async {
        await logger.initialize();
        logger.info('Test message');

        expect(logger.getRecentLogs().length, equals(1));
        logger.clearBuffer();
        expect(logger.getRecentLogs().length, equals(0));
      });
    });

    group('Log Export', () {
      test('should export logs to JSON', () async {
        await logger.initialize();
        logger.info('Test message', data: {'key': 'value'});

        final jsonOutput = logger.exportLogsToJson();
        expect(jsonOutput, isNotEmpty);
        expect(jsonOutput, contains('Test message'));
        expect(jsonOutput, contains('key'));
        expect(jsonOutput, contains('value'));
      });
    });
  });

  group('Logger Extensions', () {
    late BsdLoggerService logger;

    setUp(() async {
      logger = BsdLoggerService.getInstance();
      await logger.initialize();
    });

    tearDown(() async {
      await logger.dispose();
    });

    group('Context Logging', () {
      test('should log with context information', () {
        expect(
          () => logger.logWithContext(
            LogPriority.info,
            'Test message',
            className: 'TestClass',
            methodName: 'testMethod',
            userId: 'user123',
          ),
          returnsNormally,
        );

        final logs = logger.getRecentLogs(limit: 1);
        expect(logs.first.message, equals('Test message'));
      });

      test('should log method entry', () {
        expect(
          () => logger.logMethodEntry(
            'TestClass',
            'testMethod',
            parameters: {'param1': 'value1'},
          ),
          returnsNormally,
        );

        final logs = logger.getRecentLogs(limit: 1);
        expect(logs.first.message, contains('Method entry'));
      });

      test('should log method exit', () {
        expect(
          () => logger.logMethodExit(
            'TestClass',
            'testMethod',
            result: 'success',
            duration: Duration(milliseconds: 100),
          ),
          returnsNormally,
        );

        final logs = logger.getRecentLogs(limit: 1);
        expect(logs.first.message, contains('Method exit'));
      });
    });

    group('Performance Logging', () {
      test('should log performance metrics', () {
        expect(
          () => logger.logPerformance(
            'Database query',
            Duration(milliseconds: 50),
            metrics: {'rows': 100},
          ),
          returnsNormally,
        );

        final logs = logger.getRecentLogs(limit: 1);
        expect(logs.first.message, contains('Performance'));
      });

      test('should time and log function execution', () async {
        final result = await logger.timeAndLog('Test operation', () async {
          await Future.delayed(Duration(milliseconds: 10));
          return 'completed';
        });

        expect(result, equals('completed'));
        final logs = logger.getRecentLogs(limit: 2);
        expect(
          logs.any((log) => log.message.contains('Starting operation')),
          isTrue,
        );
        expect(logs.any((log) => log.message.contains('Performance')), isTrue);
      });
    });

    group('Specialized Logging', () {
      test('should log database operations', () {
        expect(
          () => logger.logDatabase(
            'SELECT',
            'users',
            recordCount: 10,
            duration: Duration(milliseconds: 25),
          ),
          returnsNormally,
        );

        final logs = logger.getRecentLogs(limit: 1);
        expect(logs.first.message, contains('Database operation'));
      });

      test('should log API requests', () {
        expect(
          () => logger.logApiRequest(
            'GET',
            '/api/users',
            statusCode: 200,
            duration: Duration(milliseconds: 150),
          ),
          returnsNormally,
        );

        final logs = logger.getRecentLogs(limit: 1);
        expect(logs.first.message, contains('API request'));
      });

      test('should log user actions', () {
        expect(
          () => logger.logUserAction(
            'login',
            'user123',
            details: 'Successful login',
          ),
          returnsNormally,
        );

        final logs = logger.getRecentLogs(limit: 1);
        expect(logs.first.message, contains('User action'));
      });

      test('should log security events', () {
        expect(
          () => logger.logSecurityEvent(
            'Failed login attempt',
            'user123',
            ipAddress: '192.168.1.100',
          ),
          returnsNormally,
        );

        final logs = logger.getRecentLogs(limit: 1);
        expect(logs.first.message, contains('Security event'));
      });
    });

    group('Error Logging', () {
      test('should log errors with stack trace', () {
        final error = Exception('Test error');
        final stackTrace = StackTrace.current;

        expect(
          () => logger.logError(
            'Operation failed',
            error,
            stackTrace: stackTrace,
            className: 'TestClass',
          ),
          returnsNormally,
        );

        final logs = logger.getRecentLogs(limit: 1);
        expect(logs.first.message, equals('Operation failed'));
      });

      test('should log retry attempts', () {
        expect(
          () => logger.logRetry(
            'Database connection',
            2,
            3,
            error: 'Connection timeout',
          ),
          returnsNormally,
        );

        final logs = logger.getRecentLogs(limit: 1);
        expect(logs.first.message, contains('Retry attempt'));
      });
    });
  });

  group('Logger Mixin', () {
    test('should provide easy logging integration', () async {
      final testLogger = BsdLoggerService.getInstance();
      await testLogger.initialize();

      final testClass = TestClassWithMixin();

      expect(() => testClass.testLogging(), returnsNormally);

      final logs = testLogger.getRecentLogs(limit: 1);
      expect(logs.isNotEmpty, isTrue);
      expect(logs.first.message, contains('Test method'));

      await testLogger.dispose();
    });
  });
}

class TestClassWithMixin with LoggerMixin {
  void testLogging() {
    logWithClass(LogPriority.info, 'Test method called');
  }
}
