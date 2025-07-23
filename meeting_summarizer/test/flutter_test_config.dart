/// Flutter test configuration for golden file testing
library;

import 'dart:async';

import 'package:golden_toolkit/golden_toolkit.dart';

import 'utils/golden_test_helpers.dart';

/// Global test configuration for golden file testing
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  return GoldenToolkit.runWithConfiguration(
    () async {
      // Initialize golden test helpers
      await GoldenTestHelpers.initialize();

      // Run the actual tests
      await testMain();
    },
    config: GoldenToolkitConfiguration(
      // Skip golden file assertions in CI if not needed
      skipGoldenAssertion: () => false,

      // Enable pumping frames for animations
      enableRealShadows: true,

      // Configure default device sizes for tests
      defaultDevices: GoldenTestHelpers.testDevices,
    ),
  );
}
