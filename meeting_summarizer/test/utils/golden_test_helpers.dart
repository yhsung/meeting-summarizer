/// Golden file testing utilities and configuration
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

/// Golden test configuration and utilities
class GoldenTestHelpers {
  /// Common device configurations for golden tests
  static const List<Device> testDevices = [
    Device.phone,
    Device.iphone11,
    Device.tabletPortrait,
    Device.tabletLandscape,
  ];

  /// Small phone device for compact UI testing
  static const Device smallPhone = Device(
    name: 'small_phone',
    size: Size(320, 568), // iPhone SE size
    devicePixelRatio: 2.0,
    textScale: 1.0,
  );

  /// Large tablet device for expansive UI testing
  static const Device largeTablet = Device(
    name: 'large_tablet',
    size: Size(1366, 1024), // iPad Pro 12.9" landscape
    devicePixelRatio: 2.0,
    textScale: 1.0,
  );

  /// Extended device list including edge cases
  static const List<Device> extendedTestDevices = [
    smallPhone,
    Device.phone,
    Device.iphone11,
    Device.tabletPortrait,
    Device.tabletLandscape,
    largeTablet,
  ];

  /// Initialize golden toolkit configuration
  static Future<void> initialize() async {
    return loadAppFonts();
  }

  /// Create a themed widget wrapper for consistent golden tests
  static Widget createTestWrapper({
    required Widget child,
    ThemeData? theme,
    ThemeData? darkTheme,
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('en', 'US'),
    List<NavigatorObserver> navigatorObservers = const [],
  }) {
    return MaterialApp(
      theme: theme ?? _defaultLightTheme,
      darkTheme: darkTheme ?? _defaultDarkTheme,
      themeMode: themeMode,
      locale: locale,
      navigatorObservers: navigatorObservers,
      home: Scaffold(body: child),
    );
  }

  /// Create a localized test wrapper
  static Widget createLocalizedWrapper({
    required Widget child,
    List<Locale> supportedLocales = const [
      Locale('en', 'US'),
      Locale('es', 'ES'),
      Locale('fr', 'FR'),
    ],
    Locale locale = const Locale('en', 'US'),
  }) {
    return MaterialApp(
      theme: _defaultLightTheme,
      locale: locale,
      supportedLocales: supportedLocales,
      home: Scaffold(body: child),
    );
  }

  /// Test a widget with multiple device configurations
  static Future<void> testWidgetOnMultipleDevices({
    required WidgetTester tester,
    required Widget widget,
    required String goldenFileName,
    List<Device> devices = testDevices,
    ThemeData? theme,
    ThemeData? darkTheme,
    bool testBothThemes = false,
  }) async {
    final wrappedWidget = createTestWrapper(
      child: widget,
      theme: theme,
      darkTheme: darkTheme,
    );

    if (testBothThemes) {
      // Test light theme
      await tester.pumpWidgetBuilder(
        createTestWrapper(
          child: widget,
          theme: theme ?? _defaultLightTheme,
          themeMode: ThemeMode.light,
        ),
      );
      await multiScreenGolden(
        tester,
        '${goldenFileName}_light',
        devices: devices,
      );

      // Test dark theme
      await tester.pumpWidgetBuilder(
        createTestWrapper(
          child: widget,
          darkTheme: darkTheme ?? _defaultDarkTheme,
          themeMode: ThemeMode.dark,
        ),
      );
      await multiScreenGolden(
        tester,
        '${goldenFileName}_dark',
        devices: devices,
      );
    } else {
      await tester.pumpWidgetBuilder(wrappedWidget);
      await multiScreenGolden(tester, goldenFileName, devices: devices);
    }
  }

  /// Test a screen with navigation and state management
  static Future<void> testScreenWithNavigation({
    required WidgetTester tester,
    required Widget screen,
    required String goldenFileName,
    List<Device> devices = testDevices,
    VoidCallback? setupAction,
    Duration pumpDuration = const Duration(milliseconds: 100),
  }) async {
    await tester.pumpWidgetBuilder(createTestWrapper(child: screen));

    // Allow for initial animations and state setup
    await tester.pump(pumpDuration);

    // Execute any setup actions (like tapping buttons, entering text)
    if (setupAction != null) {
      setupAction();
      await tester.pump();
    }

    await multiScreenGolden(tester, goldenFileName, devices: devices);
  }

  /// Test widget states (loading, error, success, empty)
  static Future<void> testWidgetStates({
    required WidgetTester tester,
    required Widget Function(String state) widgetBuilder,
    required String goldenFilePrefix,
    List<String> states = const ['loading', 'error', 'success', 'empty'],
    List<Device> devices = testDevices,
  }) async {
    for (final state in states) {
      final widget = widgetBuilder(state);
      await tester.pumpWidgetBuilder(createTestWrapper(child: widget));
      await multiScreenGolden(
        tester,
        '${goldenFilePrefix}_$state',
        devices: devices,
      );
    }
  }

  /// Test widget with different text scales for accessibility
  static Future<void> testWidgetAccessibility({
    required WidgetTester tester,
    required Widget widget,
    required String goldenFileName,
    List<double> textScales = const [0.8, 1.0, 1.2, 1.5, 2.0],
    Device device = Device.phone,
  }) async {
    for (final scale in textScales) {
      await tester.pumpWidgetBuilder(createTestWrapper(child: widget));

      await screenMatchesGolden(
        tester,
        '${goldenFileName}_scale_${scale.toString().replaceAll('.', '_')}',
        customPump: (tester) async {
          await tester.pump();
        },
      );
    }
  }

  /// Test form interactions and validation states
  static Future<void> testFormStates({
    required WidgetTester tester,
    required Widget form,
    required String goldenFilePrefix,
    required Map<String, VoidCallback> interactions,
    List<Device> devices = testDevices,
  }) async {
    for (final entry in interactions.entries) {
      await tester.pumpWidgetBuilder(createTestWrapper(child: form));

      // Execute the interaction
      entry.value();
      await tester.pump();

      await multiScreenGolden(
        tester,
        '${goldenFilePrefix}_${entry.key}',
        devices: devices,
      );
    }
  }

  /// Test widget with different orientations
  static Future<void> testWidgetOrientations({
    required WidgetTester tester,
    required Widget widget,
    required String goldenFileName,
  }) async {
    // Portrait
    await tester.pumpWidgetBuilder(createTestWrapper(child: widget));
    await multiScreenGolden(
      tester,
      '${goldenFileName}_portrait',
      devices: [Device.phone, Device.tabletPortrait],
    );

    // Landscape
    await multiScreenGolden(
      tester,
      '${goldenFileName}_landscape',
      devices: [
        Device.phone.copyWith(size: const Size(812, 375)),
        Device.tabletLandscape,
      ],
    );
  }

  /// Generate goldens for a widget with custom test scenarios
  static Future<void> generateCustomGoldens({
    required WidgetTester tester,
    required String goldenFileName,
    required Map<String, Widget> scenarios,
    List<Device> devices = testDevices,
  }) async {
    for (final entry in scenarios.entries) {
      await tester.pumpWidgetBuilder(createTestWrapper(child: entry.value));
      await multiScreenGolden(
        tester,
        '${goldenFileName}_${entry.key}',
        devices: devices,
      );
    }
  }

  /// Default light theme for consistent testing
  static final ThemeData _defaultLightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2196F3),
      brightness: Brightness.light,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Roboto'),
      displayMedium: TextStyle(fontFamily: 'Roboto'),
      displaySmall: TextStyle(fontFamily: 'Roboto'),
      headlineLarge: TextStyle(fontFamily: 'Roboto'),
      headlineMedium: TextStyle(fontFamily: 'Roboto'),
      headlineSmall: TextStyle(fontFamily: 'Roboto'),
      titleLarge: TextStyle(fontFamily: 'Roboto'),
      titleMedium: TextStyle(fontFamily: 'Roboto'),
      titleSmall: TextStyle(fontFamily: 'Roboto'),
      bodyLarge: TextStyle(fontFamily: 'Roboto'),
      bodyMedium: TextStyle(fontFamily: 'Roboto'),
      bodySmall: TextStyle(fontFamily: 'Roboto'),
      labelLarge: TextStyle(fontFamily: 'Roboto'),
      labelMedium: TextStyle(fontFamily: 'Roboto'),
      labelSmall: TextStyle(fontFamily: 'Roboto'),
    ),
  );

  /// Default dark theme for consistent testing
  static final ThemeData _defaultDarkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2196F3),
      brightness: Brightness.dark,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Roboto'),
      displayMedium: TextStyle(fontFamily: 'Roboto'),
      displaySmall: TextStyle(fontFamily: 'Roboto'),
      headlineLarge: TextStyle(fontFamily: 'Roboto'),
      headlineMedium: TextStyle(fontFamily: 'Roboto'),
      headlineSmall: TextStyle(fontFamily: 'Roboto'),
      titleLarge: TextStyle(fontFamily: 'Roboto'),
      titleMedium: TextStyle(fontFamily: 'Roboto'),
      titleSmall: TextStyle(fontFamily: 'Roboto'),
      bodyLarge: TextStyle(fontFamily: 'Roboto'),
      bodyMedium: TextStyle(fontFamily: 'Roboto'),
      bodySmall: TextStyle(fontFamily: 'Roboto'),
      labelLarge: TextStyle(fontFamily: 'Roboto'),
      labelMedium: TextStyle(fontFamily: 'Roboto'),
      labelSmall: TextStyle(fontFamily: 'Roboto'),
    ),
  );

  /// Create a mock data context for testing
  static Widget createMockDataWrapper({
    required Widget child,
    bool hasRecordings = true,
    bool hasTranscriptions = true,
    bool hasSummaries = true,
    bool isLoading = false,
    bool hasError = false,
    String? errorMessage,
  }) {
    return createTestWrapper(
      child: Builder(
        builder: (context) {
          // In a real implementation, this would provide mock data
          // through providers or inherited widgets
          return child;
        },
      ),
    );
  }

  /// Utility to create consistent padding for golden test snapshots
  static Widget addGoldenPadding(Widget child) {
    return Padding(padding: const EdgeInsets.all(16.0), child: child);
  }
}

/// Extension to add convenience methods to Device
extension DeviceExtension on Device {
  /// Create a copy of this device with modified properties
  Device copyWith({
    String? name,
    Size? size,
    double? devicePixelRatio,
    double? textScale,
  }) {
    return Device(
      name: name ?? this.name,
      size: size ?? this.size,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
      textScale: textScale ?? this.textScale,
    );
  }
}
