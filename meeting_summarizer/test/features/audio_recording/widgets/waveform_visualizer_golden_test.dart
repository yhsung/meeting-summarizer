/// Golden file tests for WaveformVisualizer widget
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:meeting_summarizer/features/audio_recording/presentation/widgets/waveform_visualizer.dart';
import '../../../utils/golden_test_helpers.dart';

void main() {
  group('WaveformVisualizer Golden Tests', () {
    setUpAll(() async {
      await GoldenTestHelpers.initialize();
    });

    testGoldens('WaveformVisualizer - Basic States', (tester) async {
      // Test different waveform states
      await GoldenTestHelpers.testWidgetStates(
        tester: tester,
        goldenFilePrefix: 'waveform_visualizer',
        widgetBuilder: (state) {
          switch (state) {
            case 'empty':
              return const WaveformVisualizer(
                waveformData: [],
                currentAmplitude: 0.0,
                height: 100,
                width: 300,
              );
            case 'loading':
              return const WaveformVisualizer(
                waveformData: [0.1, 0.2, 0.1, 0.3, 0.2],
                currentAmplitude: 0.2,
                height: 100,
                width: 300,
              );
            case 'active':
              return const WaveformVisualizer(
                waveformData: [0.3, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 0.2],
                currentAmplitude: 0.8,
                height: 100,
                width: 300,
                showCurrentAmplitude: true,
              );
            case 'quiet':
              return const WaveformVisualizer(
                waveformData: [0.1, 0.05, 0.08, 0.03, 0.06, 0.02, 0.04],
                currentAmplitude: 0.05,
                height: 100,
                width: 300,
              );
            default:
              return const SizedBox.shrink();
          }
        },
        states: ['empty', 'loading', 'active', 'quiet'],
      );
    });

    testGoldens('WaveformVisualizer - Color Variations', (tester) async {
      final colorScenarios = {
        'blue': const WaveformVisualizer(
          waveformData: [0.3, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 0.2],
          currentAmplitude: 0.7,
          waveColor: Colors.blue,
          backgroundColor: Colors.transparent,
          height: 100,
          width: 300,
        ),
        'green': const WaveformVisualizer(
          waveformData: [0.3, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 0.2],
          currentAmplitude: 0.7,
          waveColor: Colors.green,
          backgroundColor: Colors.black12,
          height: 100,
          width: 300,
        ),
        'red': const WaveformVisualizer(
          waveformData: [0.3, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 0.2],
          currentAmplitude: 0.7,
          waveColor: Colors.red,
          backgroundColor: Color(0xFFF5F5F5),
          height: 100,
          width: 300,
        ),
        'custom': const WaveformVisualizer(
          waveformData: [0.3, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 0.2],
          currentAmplitude: 0.7,
          waveColor: Color(0xFF6C5CE7),
          backgroundColor: Color(0xFFF8F9FA),
          height: 100,
          width: 300,
        ),
      };

      await GoldenTestHelpers.generateCustomGoldens(
        tester: tester,
        goldenFileName: 'waveform_visualizer_colors',
        scenarios: colorScenarios,
      );
    });

    testGoldens('WaveformVisualizer - Size Variations', (tester) async {
      final sizeScenarios = {
        'small': const WaveformVisualizer(
          waveformData: [0.3, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 0.2],
          currentAmplitude: 0.7,
          height: 50,
          width: 150,
        ),
        'medium': const WaveformVisualizer(
          waveformData: [0.3, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 0.2],
          currentAmplitude: 0.7,
          height: 100,
          width: 300,
        ),
        'large': const WaveformVisualizer(
          waveformData: [0.3, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 0.2],
          currentAmplitude: 0.7,
          height: 150,
          width: 450,
        ),
        'wide': const WaveformVisualizer(
          waveformData: [
            0.3,
            0.7,
            0.5,
            0.9,
            0.6,
            0.4,
            0.8,
            0.2,
            0.5,
            0.3,
            0.8,
            0.4,
          ],
          currentAmplitude: 0.6,
          height: 80,
          width: 600,
        ),
      };

      await GoldenTestHelpers.generateCustomGoldens(
        tester: tester,
        goldenFileName: 'waveform_visualizer_sizes',
        scenarios: sizeScenarios,
      );
    });

    testGoldens('WaveformVisualizer - Data Density', (tester) async {
      final dataScenarios = {
        'sparse': const WaveformVisualizer(
          waveformData: [0.3, 0.7, 0.2],
          currentAmplitude: 0.5,
          height: 100,
          width: 300,
        ),
        'normal': const WaveformVisualizer(
          waveformData: [0.3, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 0.2, 0.5, 0.3],
          currentAmplitude: 0.6,
          height: 100,
          width: 300,
        ),
        'dense': WaveformVisualizer(
          waveformData: List.generate(50, (i) => (i % 10) / 10.0),
          currentAmplitude: 0.7,
          height: 100,
          width: 300,
        ),
        'very_dense': WaveformVisualizer(
          waveformData: List.generate(100, (i) => (i % 20) / 20.0 + 0.1),
          currentAmplitude: 0.8,
          height: 100,
          width: 300,
          maxDataPoints: 100,
        ),
      };

      await GoldenTestHelpers.generateCustomGoldens(
        tester: tester,
        goldenFileName: 'waveform_visualizer_density',
        scenarios: dataScenarios,
      );
    });

    testGoldens('WaveformVisualizer - Current Amplitude Display', (
      tester,
    ) async {
      final amplitudeScenarios = {
        'with_amplitude': const WaveformVisualizer(
          waveformData: [0.3, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 0.2],
          currentAmplitude: 0.7,
          height: 100,
          width: 300,
          showCurrentAmplitude: true,
        ),
        'without_amplitude': const WaveformVisualizer(
          waveformData: [0.3, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 0.2],
          currentAmplitude: 0.7,
          height: 100,
          width: 300,
          showCurrentAmplitude: false,
        ),
        'zero_amplitude': const WaveformVisualizer(
          waveformData: [0.3, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 0.2],
          currentAmplitude: 0.0,
          height: 100,
          width: 300,
          showCurrentAmplitude: true,
        ),
        'max_amplitude': const WaveformVisualizer(
          waveformData: [0.3, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 0.2],
          currentAmplitude: 1.0,
          height: 100,
          width: 300,
          showCurrentAmplitude: true,
        ),
      };

      await GoldenTestHelpers.generateCustomGoldens(
        tester: tester,
        goldenFileName: 'waveform_visualizer_amplitude',
        scenarios: amplitudeScenarios,
      );
    });

    testGoldens('WaveformVisualizer - Multiple Devices', (tester) async {
      const widget = WaveformVisualizer(
        waveformData: [
          0.3,
          0.7,
          0.5,
          0.9,
          0.6,
          0.4,
          0.8,
          0.2,
          0.5,
          0.3,
          0.7,
          0.4,
        ],
        currentAmplitude: 0.6,
        height: 100,
        width: 300,
        waveColor: Colors.blue,
        showCurrentAmplitude: true,
      );

      await GoldenTestHelpers.testWidgetOnMultipleDevices(
        tester: tester,
        widget: widget,
        goldenFileName: 'waveform_visualizer_devices',
        devices: GoldenTestHelpers.extendedTestDevices,
      );
    });

    testGoldens('WaveformVisualizer - Dark Theme', (tester) async {
      const widget = WaveformVisualizer(
        waveformData: [0.3, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 0.2],
        currentAmplitude: 0.7,
        height: 100,
        width: 300,
        waveColor: Colors.lightBlue,
        backgroundColor: Colors.black12,
      );

      await GoldenTestHelpers.testWidgetOnMultipleDevices(
        tester: tester,
        widget: widget,
        goldenFileName: 'waveform_visualizer_theme',
        testBothThemes: true,
      );
    });

    testGoldens('WaveformVisualizer - Real-world Scenarios', (tester) async {
      final realWorldScenarios = {
        'meeting_start': const WaveformVisualizer(
          waveformData: [0.1, 0.2, 0.15, 0.08, 0.12, 0.05],
          currentAmplitude: 0.05,
          height: 100,
          width: 300,
          waveColor: Colors.green,
        ),
        'active_discussion': WaveformVisualizer(
          waveformData: [0.6, 0.8, 0.9, 0.7, 0.85, 0.6, 0.9, 0.7, 0.8, 0.65],
          currentAmplitude: 0.8,
          height: 100,
          width: 300,
          waveColor: Colors.orange,
        ),
        'quiet_moment': const WaveformVisualizer(
          waveformData: [0.02, 0.05, 0.03, 0.01, 0.04, 0.02, 0.03],
          currentAmplitude: 0.02,
          height: 100,
          width: 300,
          waveColor: Colors.grey,
        ),
        'presentation_mode': WaveformVisualizer(
          waveformData: [0.4, 0.5, 0.6, 0.5, 0.45, 0.5, 0.55, 0.5, 0.6, 0.45],
          currentAmplitude: 0.5,
          height: 100,
          width: 300,
          waveColor: Colors.purple,
        ),
      };

      await GoldenTestHelpers.generateCustomGoldens(
        tester: tester,
        goldenFileName: 'waveform_visualizer_scenarios',
        scenarios: realWorldScenarios,
      );
    });
  });
}
