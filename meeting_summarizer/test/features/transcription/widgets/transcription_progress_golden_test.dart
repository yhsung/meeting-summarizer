/// Golden file tests for TranscriptionProgress widget
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:meeting_summarizer/features/transcription/presentation/widgets/transcription_progress.dart';
import '../../../utils/golden_test_helpers.dart';

void main() {
  group('TranscriptionProgress Golden Tests', () {
    setUpAll(() async {
      await GoldenTestHelpers.initialize();
    });

    testGoldens('TranscriptionProgress - Progress States', (tester) async {
      await GoldenTestHelpers.testWidgetStates(
        tester: tester,
        goldenFilePrefix: 'transcription_progress',
        widgetBuilder: (state) {
          switch (state) {
            case 'starting':
              return const TranscriptionProgress(
                progress: 0.0,
                statusMessage: 'Initializing transcription...',
                showPercentage: true,
              );
            case 'in_progress':
              return const TranscriptionProgress(
                progress: 0.45,
                statusMessage: 'Transcribing audio...',
                showPercentage: true,
              );
            case 'nearly_done':
              return const TranscriptionProgress(
                progress: 0.85,
                statusMessage: 'Finalizing transcription...',
                showPercentage: true,
              );
            case 'completed':
              return const TranscriptionProgress(
                progress: 1.0,
                statusMessage: 'Transcription completed!',
                showPercentage: true,
              );
            default:
              return const SizedBox.shrink();
          }
        },
        states: ['starting', 'in_progress', 'nearly_done', 'completed'],
      );
    });

    testGoldens('TranscriptionProgress - Percentage Display', (tester) async {
      final percentageScenarios = {
        'with_percentage': const TranscriptionProgress(
          progress: 0.67,
          statusMessage: 'Processing audio segments...',
          showPercentage: true,
        ),
        'without_percentage': const TranscriptionProgress(
          progress: 0.67,
          statusMessage: 'Processing audio segments...',
          showPercentage: false,
        ),
        'zero_percent': const TranscriptionProgress(
          progress: 0.0,
          statusMessage: 'Starting transcription process...',
          showPercentage: true,
        ),
        'hundred_percent': const TranscriptionProgress(
          progress: 1.0,
          statusMessage: 'Transcription finished successfully',
          showPercentage: true,
        ),
      };

      await GoldenTestHelpers.generateCustomGoldens(
        tester: tester,
        goldenFileName: 'transcription_progress_percentage',
        scenarios: percentageScenarios,
      );
    });

    testGoldens('TranscriptionProgress - Status Messages', (tester) async {
      final messageScenarios = {
        'short_message': const TranscriptionProgress(
          progress: 0.3,
          statusMessage: 'Processing...',
          showPercentage: true,
        ),
        'detailed_message': const TranscriptionProgress(
          progress: 0.6,
          statusMessage:
              'Analyzing audio patterns and converting speech to text',
          showPercentage: true,
        ),
        'error_message': const TranscriptionProgress(
          progress: 0.4,
          statusMessage: 'Retrying transcription due to network issues',
          showPercentage: false,
        ),
        'multilingual': const TranscriptionProgress(
          progress: 0.75,
          statusMessage:
              'Transcripción en progreso - Detectando idioma automáticamente',
          showPercentage: true,
        ),
      };

      await GoldenTestHelpers.generateCustomGoldens(
        tester: tester,
        goldenFileName: 'transcription_progress_messages',
        scenarios: messageScenarios,
      );
    });

    testGoldens('TranscriptionProgress - Real-world Scenarios', (tester) async {
      final realWorldScenarios = {
        'meeting_start': const TranscriptionProgress(
          progress: 0.05,
          statusMessage: 'Detecting speakers and audio quality...',
          showPercentage: true,
        ),
        'active_transcription': const TranscriptionProgress(
          progress: 0.42,
          statusMessage: 'Converting speech from multiple speakers...',
          showPercentage: true,
        ),
        'quality_check': const TranscriptionProgress(
          progress: 0.78,
          statusMessage: 'Improving accuracy and formatting text...',
          showPercentage: true,
        ),
        'finalizing': const TranscriptionProgress(
          progress: 0.95,
          statusMessage: 'Adding timestamps and speaker labels...',
          showPercentage: true,
        ),
      };

      await GoldenTestHelpers.generateCustomGoldens(
        tester: tester,
        goldenFileName: 'transcription_progress_scenarios',
        scenarios: realWorldScenarios,
      );
    });

    testGoldens('TranscriptionProgress - Multiple Devices', (tester) async {
      const widget = TranscriptionProgress(
        progress: 0.58,
        statusMessage:
            'Transcribing high-quality audio with speaker identification',
        showPercentage: true,
      );

      await GoldenTestHelpers.testWidgetOnMultipleDevices(
        tester: tester,
        widget: widget,
        goldenFileName: 'transcription_progress_devices',
        devices: GoldenTestHelpers.extendedTestDevices,
      );
    });

    testGoldens('TranscriptionProgress - Light and Dark Themes', (
      tester,
    ) async {
      const widget = TranscriptionProgress(
        progress: 0.72,
        statusMessage: 'Processing natural language patterns...',
        showPercentage: true,
      );

      await GoldenTestHelpers.testWidgetOnMultipleDevices(
        tester: tester,
        widget: widget,
        goldenFileName: 'transcription_progress_themes',
        testBothThemes: true,
      );
    });

    testGoldens('TranscriptionProgress - Accessibility Testing', (
      tester,
    ) async {
      const widget = TranscriptionProgress(
        progress: 0.63,
        statusMessage: 'Converting speech to text with high accuracy',
        showPercentage: true,
      );

      await GoldenTestHelpers.testWidgetAccessibility(
        tester: tester,
        widget: widget,
        goldenFileName: 'transcription_progress_accessibility',
        textScales: [0.8, 1.0, 1.2, 1.5, 2.0],
      );
    });

    testGoldens('TranscriptionProgress - Edge Cases', (tester) async {
      final edgeCaseScenarios = {
        'empty_message': const TranscriptionProgress(
          progress: 0.5,
          statusMessage: '',
          showPercentage: true,
        ),
        'very_long_message': const TranscriptionProgress(
          progress: 0.33,
          statusMessage:
              'This is an extremely long status message that might wrap to multiple lines and test how the widget handles extensive text content while maintaining proper layout and readability',
          showPercentage: true,
        ),
        'special_characters': const TranscriptionProgress(
          progress: 0.66,
          statusMessage:
              'Processing special characters: ñ, é, ü, ™, © & symbols',
          showPercentage: false,
        ),
        'numbers_and_symbols': const TranscriptionProgress(
          progress: 0.89,
          statusMessage: 'Transcribing: 123 items @ 45% accuracy (±2.5%)',
          showPercentage: true,
        ),
      };

      await GoldenTestHelpers.generateCustomGoldens(
        tester: tester,
        goldenFileName: 'transcription_progress_edge_cases',
        scenarios: edgeCaseScenarios,
        devices: [
          GoldenTestHelpers.testDevices.first,
        ], // Test on single device for edge cases
      );
    });
  });
}
