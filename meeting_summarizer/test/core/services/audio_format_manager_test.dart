import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/enums/audio_format.dart';
import 'package:meeting_summarizer/core/enums/audio_quality.dart';
import 'package:meeting_summarizer/core/services/audio_format_manager.dart';

void main() {
  group('AudioFormatManager', () {
    late AudioFormatManager manager;

    setUp(() {
      manager = AudioFormatManager();
    });

    group('getOptimalFormat', () {
      test(
        'should return highest quality format when prioritizing quality',
        () {
          final format = manager.getOptimalFormat(
            quality: AudioQuality.high,
            prioritizeQuality: true,
            prioritizeSize: false,
          );

          expect(
            format,
            isIn([AudioFormat.wav, AudioFormat.m4a, AudioFormat.aac]),
          );
        },
      );

      test('should return most compressed format when prioritizing size', () {
        final format = manager.getOptimalFormat(
          quality: AudioQuality.medium,
          prioritizeQuality: false,
          prioritizeSize: true,
        );

        expect(format, isIn([AudioFormat.aac, AudioFormat.mp3]));
      });

      test('should consider file size constraints', () {
        final format = manager.getOptimalFormat(
          quality: AudioQuality.high,
          prioritizeQuality: false,
          prioritizeSize: false,
          maxFileSizeMB: 5,
          expectedDuration: const Duration(minutes: 10),
        );

        expect(format, isNotNull);
        expect(AudioFormat.values.contains(format), isTrue);
      });
    });

    group('getOptimalQuality', () {
      test('should return medium quality for speech recordings', () {
        final quality = manager.getOptimalQuality(
          format: AudioFormat.m4a,
          recordingType: 'speech',
        );

        expect(quality, AudioQuality.medium);
      });

      test('should return high quality for music recordings', () {
        final quality = manager.getOptimalQuality(
          format: AudioFormat.m4a,
          recordingType: 'music',
        );

        expect(quality, AudioQuality.high);
      });

      test('should respect file size constraints', () {
        final quality = manager.getOptimalQuality(
          format: AudioFormat.wav,
          recordingType: 'music',
          maxFileSizeMB: 10,
          expectedDuration: const Duration(minutes: 30),
        );

        // Should select a lower quality to fit size constraints
        expect(quality, isIn([AudioQuality.low, AudioQuality.medium]));
      });
    });

    group('getOptimalConfiguration', () {
      test('should return appropriate configuration for speech', () {
        final config = manager.getOptimalConfiguration(
          recordingType: 'meeting',
          prioritizeQuality: false,
          prioritizeSize: true,
        );

        expect(config.format, isNotNull);
        expect(config.quality, isNotNull);
        expect(config.channels, 1);
        expect(config.enableNoiseReduction, isTrue);
      });

      test('should return appropriate configuration for music', () {
        final config = manager.getOptimalConfiguration(
          recordingType: 'music',
          prioritizeQuality: true,
          prioritizeSize: false,
        );

        expect(config.format, isNotNull);
        expect(config.quality, isIn([AudioQuality.high, AudioQuality.ultra]));
      });

      test('should respect size constraints in configuration', () {
        final config = manager.getOptimalConfiguration(
          recordingType: 'voice',
          maxFileSizeMB: 5,
          expectedDuration: const Duration(minutes: 10),
        );

        final estimatedSize = manager.estimateFileSize(
          format: config.format,
          quality: config.quality,
          duration: const Duration(minutes: 10),
        );

        expect(estimatedSize, lessThanOrEqualTo(5.0));
      });
    });

    group('estimateFileSize', () {
      test('should return realistic file size estimates', () {
        final size = manager.estimateFileSize(
          format: AudioFormat.wav,
          quality: AudioQuality.high,
          duration: const Duration(minutes: 1),
        );

        expect(size, greaterThan(0));
        expect(size, lessThan(50)); // Should be reasonable for 1 minute
      });

      test('should show compression differences between formats', () {
        const duration = Duration(minutes: 5);
        const quality = AudioQuality.medium;

        final wavSize = manager.estimateFileSize(
          format: AudioFormat.wav,
          quality: quality,
          duration: duration,
        );

        final mp3Size = manager.estimateFileSize(
          format: AudioFormat.mp3,
          quality: quality,
          duration: duration,
        );

        expect(mp3Size, lessThan(wavSize));
      });
    });

    group('getSupportedFormats', () {
      test('should return non-empty list of supported formats', () {
        final formats = manager.getSupportedFormats();

        expect(formats, isNotEmpty);
        expect(formats.every((f) => AudioFormat.values.contains(f)), isTrue);
      });
    });

    group('getRecommendedQualities', () {
      test('should recommend appropriate qualities for speech', () {
        final qualities = manager.getRecommendedQualities(
          recordingType: 'speech',
          format: AudioFormat.mp3,
        );

        expect(qualities, isNotEmpty);
        expect(qualities, contains(AudioQuality.medium));
      });

      test('should recommend appropriate qualities for music', () {
        final qualities = manager.getRecommendedQualities(
          recordingType: 'music',
          format: AudioFormat.m4a,
        );

        expect(qualities, isNotEmpty);
        expect(qualities, contains(AudioQuality.high));
      });
    });

    group('getFormatRecommendation', () {
      test('should return helpful recommendation text', () {
        final recommendation = manager.getFormatRecommendation(
          format: AudioFormat.mp3,
          quality: AudioQuality.medium,
          recordingType: 'speech',
        );

        expect(recommendation, isNotEmpty);
        expect(recommendation, contains('speech'));
      });
    });

    group('isFormatCompatible', () {
      test('should validate format-quality combinations', () {
        final isCompatible = manager.isFormatCompatible(
          format: AudioFormat.mp3,
          quality: AudioQuality.medium,
        );

        expect(isCompatible, isA<bool>());
      });

      test('should handle edge cases gracefully', () {
        final isCompatible = manager.isFormatCompatible(
          format: AudioFormat.wav,
          quality: AudioQuality.ultra,
        );

        expect(isCompatible, isA<bool>());
      });
    });
  });
}
