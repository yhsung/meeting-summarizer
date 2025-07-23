/// Integration test runner
/// Executes all integration tests in the correct order
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Import all test suites
import 'app_workflow_test.dart' as app_workflow;
import 'cloud_sync_test.dart' as cloud_sync;
import 'platform_tests.dart' as platform_tests;

import 'integration_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Meeting Summarizer Integration Test Suite', () {
    setUpAll(() async {
      debugPrint('🧪 Starting Meeting Summarizer Integration Tests');
      debugPrint('Platform: ${IntegrationTestHelpers.getPlatformName()}');
      debugPrint('Test Environment: Integration');

      await IntegrationTestHelpers.initialize();
      debugPrint('✅ Integration test environment initialized');
    });

    tearDownAll(() async {
      debugPrint('🧹 Cleaning up integration test environment');
      await IntegrationTestHelpers.cleanup();
      debugPrint('✅ Integration test cleanup completed');
    });

    // Run test suites in order of complexity

    debugPrint('📱 Running App Workflow Tests...');
    app_workflow.main();

    debugPrint('☁️ Running Cloud Sync Tests...');
    cloud_sync.main();

    debugPrint('🖥️ Running Platform-Specific Tests...');
    platform_tests.main();

    debugPrint('🎉 All integration test suites completed');
  });
}
