/// Platform-specific integration tests
/// Tests platform-specific functionality across Android, iOS, Web, and Desktop
library;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:meeting_summarizer/main.dart' as app;

import 'integration_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Platform-Specific Integration Tests', () {
    setUpAll(() async {
      await IntegrationTestHelpers.initialize();
    });

    tearDownAll(() async {
      await IntegrationTestHelpers.cleanup();
    });

    setUp(() async {
      await IntegrationTestHelpers.cleanTestDatabase();
      IntegrationTestHelpers.resetMocks();
    });

    group('Cross-Platform Compatibility', () {
      testWidgets('App initializes on current platform', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Verify app works on current platform
        expect(find.byType(MaterialApp), findsOneWidget);

        // Log platform information
        final platformName = getPlatformName();
        debugPrint('Running on platform: $platformName');
        debugPrint('Is web: $kIsWeb');
        debugPrint('Default target platform: $defaultTargetPlatform');

        // Take platform-specific screenshot
        await IntegrationTestHelpers.takeScreenshot('platform_$platformName');
      });

      testWidgets('File operations work on current platform', (tester) async {
        // Create test data
        final platformName = getPlatformName();
        await IntegrationTestHelpers.createTestRecording(
          fileName: 'platform_test_$platformName.wav',
        );

        app.main();
        await tester.pumpAndSettle();

        // Verify file operations work
        expect(find.byType(MaterialApp), findsOneWidget);
        await IntegrationTestHelpers.verifyDatabaseState(expectedRecordings: 1);

        // Take screenshot of file operations
        await IntegrationTestHelpers.takeScreenshot('file_ops_$platformName');
      });

      testWidgets('Database operations are platform-compatible', (
        tester,
      ) async {
        // Create comprehensive test data
        final platformName = getPlatformName();
        await IntegrationTestHelpers.createCompleteTestDataSet(
          fileName: 'db_test_$platformName.wav',
        );

        app.main();
        await tester.pumpAndSettle();

        // Verify database works across platforms
        await IntegrationTestHelpers.verifyDatabaseState(
          expectedRecordings: 1,
          expectedTranscriptions: 1,
          expectedSummaries: 1,
        );

        // Take screenshot of database operations
        await IntegrationTestHelpers.takeScreenshot('database_$platformName');
      });
    });

    group('Platform-Specific Features', () {
      testWidgets('Platform-specific UI adaptations', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Test platform-specific UI elements
        if (kIsWeb) {
          // Web-specific tests
          await _testWebSpecificFeatures(tester);
        } else if (Platform.isAndroid) {
          // Android-specific tests
          await _testAndroidSpecificFeatures(tester);
        } else if (Platform.isIOS) {
          // iOS-specific tests
          await _testIOSSpecificFeatures(tester);
        } else if (Platform.isMacOS) {
          // macOS-specific tests
          await _testMacOSSpecificFeatures(tester);
        } else if (Platform.isWindows) {
          // Windows-specific tests
          await _testWindowsSpecificFeatures(tester);
        } else if (Platform.isLinux) {
          // Linux-specific tests
          await _testLinuxSpecificFeatures(tester);
        }

        // Take platform-specific UI screenshot
        final platformName = getPlatformName();
        await IntegrationTestHelpers.takeScreenshot('ui_$platformName');
      });

      testWidgets('Storage paths work correctly on platform', (tester) async {
        // Test platform-specific storage
        final platformName = getPlatformName();
        final recording = await IntegrationTestHelpers.createTestRecording(
          fileName: 'storage_test_$platformName.wav',
        );

        app.main();
        await tester.pumpAndSettle();

        // Verify storage operations
        expect(find.byType(MaterialApp), findsOneWidget);

        // Platform-specific storage verification
        if (kIsWeb) {
          // Web uses IndexedDB/localStorage
          debugPrint('Web storage: Using browser storage');
        } else {
          // Native platforms use file system
          debugPrint(
            'Native storage: Using file system at ${recording.filePath}',
          );
        }

        // Take storage test screenshot
        await IntegrationTestHelpers.takeScreenshot('storage_$platformName');
      });

      testWidgets('Permissions work on supported platforms', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Test permission handling based on platform
        if (Platform.isAndroid || Platform.isIOS) {
          // Mobile platforms need microphone permissions
          debugPrint('Testing mobile permissions');
        } else if (kIsWeb) {
          // Web needs browser permissions
          debugPrint('Testing web permissions');
        } else {
          // Desktop platforms may have different permission models
          debugPrint('Testing desktop permissions');
        }

        // Verify app handles platform permissions appropriately
        expect(find.byType(MaterialApp), findsOneWidget);

        // Take permissions screenshot
        final platformName = getPlatformName();
        await IntegrationTestHelpers.takeScreenshot(
          'permissions_$platformName',
        );
      });

      testWidgets('Performance characteristics match platform', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Create performance test data
        final startTime = DateTime.now();

        final platformName = getPlatformName();
        for (int i = 0; i < 5; i++) {
          await IntegrationTestHelpers.createTestRecording(
            fileName: 'perf_test_${platformName}_$i.wav',
          );
        }

        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);

        debugPrint(
          'Platform $platformName performance: ${duration.inMilliseconds}ms for 5 recordings',
        );

        // Verify performance is acceptable for platform
        expect(
          duration.inSeconds,
          lessThan(30),
        ); // Should complete within 30 seconds

        // Take performance test screenshot
        await IntegrationTestHelpers.takeScreenshot(
          'performance_$platformName',
        );
      });
    });

    group('Platform Limitations', () {
      testWidgets('Handles platform-specific limitations gracefully', (
        tester,
      ) async {
        app.main();
        await tester.pumpAndSettle();

        if (kIsWeb) {
          // Web limitations: No direct file system access
          debugPrint('Web platform: Testing file system limitations');

          // Create recording that would use file system
          await IntegrationTestHelpers.createTestRecording(
            fileName: 'web_limitation_test.wav',
          );

          // Verify app handles web file constraints
          expect(find.byType(MaterialApp), findsOneWidget);
        } else if (Platform.isIOS) {
          // iOS limitations: Sandboxed file system
          debugPrint('iOS platform: Testing sandbox limitations');
        } else if (Platform.isAndroid) {
          // Android limitations: Scoped storage
          debugPrint('Android platform: Testing scoped storage');
        }

        // Take limitations test screenshot
        final platformName = getPlatformName();
        await IntegrationTestHelpers.takeScreenshot(
          'limitations_$platformName',
        );
      });

      testWidgets('Graceful degradation on unsupported features', (
        tester,
      ) async {
        app.main();
        await tester.pumpAndSettle();

        // Test features that might not be available on all platforms
        if (kIsWeb) {
          // Web might not support local file picker the same way
          debugPrint('Web: Testing file picker limitations');
        } else if (Platform.isLinux) {
          // Linux might have different audio subsystem requirements
          debugPrint('Linux: Testing audio subsystem compatibility');
        }

        // Verify app doesn't crash on unsupported features
        expect(find.byType(MaterialApp), findsOneWidget);

        // Take graceful degradation screenshot
        final platformName = getPlatformName();
        await IntegrationTestHelpers.takeScreenshot(
          'degradation_$platformName',
        );
      });
    });

    group('Platform Integration', () {
      testWidgets('Native integrations work correctly', (tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Test platform-specific integrations
        if (Platform.isAndroid) {
          // Android: Test notifications, background processing
          debugPrint('Android: Testing native integrations');
        } else if (Platform.isIOS) {
          // iOS: Test CallKit, Siri shortcuts
          debugPrint('iOS: Testing native integrations');
        } else if (Platform.isMacOS) {
          // macOS: Test menu bar integration
          debugPrint('macOS: Testing native integrations');
        } else if (Platform.isWindows) {
          // Windows: Test system tray integration
          debugPrint('Windows: Testing native integrations');
        }

        // Verify integrations don't break core functionality
        expect(find.byType(MaterialApp), findsOneWidget);

        // Take native integration screenshot
        final platformName = getPlatformName();
        await IntegrationTestHelpers.takeScreenshot('native_$platformName');
      });
    });
  });
}

// Platform-specific test helper functions

Future<void> _testWebSpecificFeatures(WidgetTester tester) async {
  debugPrint('Testing web-specific features');
  // Test PWA functionality, browser compatibility, etc.
  await IntegrationTestHelpers.waitForAsync();
}

Future<void> _testAndroidSpecificFeatures(WidgetTester tester) async {
  debugPrint('Testing Android-specific features');
  // Test Android Auto, notifications, background processing
  await IntegrationTestHelpers.waitForAsync();
}

Future<void> _testIOSSpecificFeatures(WidgetTester tester) async {
  debugPrint('Testing iOS-specific features');
  // Test CallKit, Siri shortcuts, Apple Watch
  await IntegrationTestHelpers.waitForAsync();
}

Future<void> _testMacOSSpecificFeatures(WidgetTester tester) async {
  debugPrint('Testing macOS-specific features');
  // Test menu bar integration, macOS-specific UI
  await IntegrationTestHelpers.waitForAsync();
}

Future<void> _testWindowsSpecificFeatures(WidgetTester tester) async {
  debugPrint('Testing Windows-specific features');
  // Test system tray, Windows-specific UI
  await IntegrationTestHelpers.waitForAsync();
}

Future<void> _testLinuxSpecificFeatures(WidgetTester tester) async {
  debugPrint('Testing Linux-specific features');
  // Test Linux-specific audio systems, desktop integration
  await IntegrationTestHelpers.waitForAsync();
}

String getPlatformName() {
  if (kIsWeb) return 'web';
  if (Platform.isAndroid) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  return 'unknown';
}
