import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/enums/audio_format.dart';
import 'package:meeting_summarizer/core/enums/audio_quality.dart';
import 'package:meeting_summarizer/core/models/audio_configuration.dart';
import 'package:meeting_summarizer/core/services/file_size_optimizer.dart';

void main() {
  group('FileSizeOptimizer', () {
    late FileSizeOptimizer optimizer;

    setUp(() {
      optimizer = FileSizeOptimizer();
    });

    group('optimizeForTarget', () {
      test('should return optimization result with minimizeSize strategy', () {
        final result = optimizer.optimizeForTarget(
          targetSizeMB: 10,
          expectedDuration: const Duration(minutes: 5),
          recordingType: 'speech',
          strategy: OptimizationStrategy.minimizeSize,
        );

        expect(result, isA<OptimizationResult>());
        expect(result.configuration, isA<AudioConfiguration>());
        expect(result.estimatedFileSizeMB, lessThanOrEqualTo(10.0));
        expect(result.strategy, 'minimizeSize');
        expect(result.optimizations, isNotEmpty);
        expect(result.qualityScore, greaterThan(0.0));
        expect(result.compressionRatio, greaterThan(0.0));
      });

      test(
        'should return optimization result with maximizeQuality strategy',
        () {
          final result = optimizer.optimizeForTarget(
            targetSizeMB: 50,
            expectedDuration: const Duration(minutes: 5),
            recordingType: 'music',
            strategy: OptimizationStrategy.maximizeQuality,
          );

          expect(result, isA<OptimizationResult>());
          expect(result.strategy, 'maximizeQuality');
          expect(result.qualityScore, greaterThan(0.5));
        },
      );

      test('should optimize for speech content', () {
        final result = optimizer.optimizeForTarget(
          targetSizeMB: 15,
          expectedDuration: const Duration(minutes: 10),
          recordingType: 'meeting',
          strategy: OptimizationStrategy.speechOptimized,
        );

        expect(result, isA<OptimizationResult>());
        expect(result.strategy, 'speechOptimized');
        expect(result.configuration.noiseReduction, isTrue);
        expect(result.configuration.channels, 1);
      });

      test('should optimize for music content', () {
        final result = optimizer.optimizeForTarget(
          targetSizeMB: 30,
          expectedDuration: const Duration(minutes: 5),
          recordingType: 'music',
          strategy: OptimizationStrategy.musicOptimized,
        );

        expect(result, isA<OptimizationResult>());
        expect(result.strategy, 'musicOptimized');
        expect(
          result.configuration.quality,
          isIn([AudioQuality.high, AudioQuality.ultra]),
        );
      });

      test('should provide balanced optimization', () {
        final result = optimizer.optimizeForTarget(
          targetSizeMB: 20,
          expectedDuration: const Duration(minutes: 8),
          recordingType: 'podcast',
          strategy: OptimizationStrategy.balanced,
        );

        expect(result, isA<OptimizationResult>());
        expect(result.strategy, 'balanced');
        expect(result.estimatedFileSizeMB, lessThanOrEqualTo(20.0));
        expect(result.qualityScore, greaterThan(0.3));
      });
    });

    group('generateRecommendations', () {
      test('should return multiple recommendations', () {
        final recommendations = optimizer.generateRecommendations(
          targetSizeMB: 25,
          expectedDuration: const Duration(minutes: 10),
          recordingType: 'voice',
        );

        expect(recommendations, isNotEmpty);
        expect(recommendations.length, greaterThanOrEqualTo(3));
        expect(
          recommendations.every((r) => r.estimatedFileSizeMB <= 25.0),
          isTrue,
        );
      });

      test('should include speech optimization for speech content', () {
        final recommendations = optimizer.generateRecommendations(
          targetSizeMB: 15,
          expectedDuration: const Duration(minutes: 5),
          recordingType: 'meeting notes',
        );

        final strategies = recommendations.map((r) => r.strategy).toList();
        expect(strategies, contains('speechOptimized'));
      });

      test('should include music optimization for music content', () {
        final recommendations = optimizer.generateRecommendations(
          targetSizeMB: 40,
          expectedDuration: const Duration(minutes: 3),
          recordingType: 'instrumental music',
        );

        final strategies = recommendations.map((r) => r.strategy).toList();
        expect(strategies, contains('musicOptimized'));
      });
    });

    group('calculateDynamicFileSize', () {
      test('should calculate size for current duration', () {
        final config = AudioConfiguration.raw(
          format: AudioFormat.mp3,
          quality: AudioQuality.medium,
          sampleRate: 22050,
          bitDepth: 16,
        );

        final size = optimizer.calculateDynamicFileSize(
          configuration: config,
          currentDuration: const Duration(minutes: 3),
        );

        expect(size, greaterThan(0.0));
      });

      test('should project size for expected duration', () {
        final config = AudioConfiguration.raw(
          format: AudioFormat.wav,
          quality: AudioQuality.high,
          sampleRate: 44100,
          bitDepth: 16,
        );

        final currentSize = optimizer.calculateDynamicFileSize(
          configuration: config,
          currentDuration: const Duration(minutes: 2),
        );

        final projectedSize = optimizer.calculateDynamicFileSize(
          configuration: config,
          currentDuration: const Duration(minutes: 2),
          totalExpectedDuration: const Duration(minutes: 10),
        );

        expect(projectedSize, greaterThan(currentSize));
      });
    });

    group('getSizeOptimizationTip', () {
      test('should return fitting message when size is within target', () {
        final config = AudioConfiguration.raw(
          format: AudioFormat.mp3,
          quality: AudioQuality.low,
          sampleRate: 8000,
          bitDepth: 8,
        );

        final tip = optimizer.getSizeOptimizationTip(
          currentSizeMB: 8.0,
          targetSizeMB: 10,
          configuration: config,
        );

        expect(tip, contains('fits within target'));
      });

      test(
        'should suggest compression when size exceeds target significantly',
        () {
          final config = AudioConfiguration.raw(
            format: AudioFormat.wav,
            quality: AudioQuality.ultra,
            sampleRate: 48000,
            bitDepth: 24,
          );

          final tip = optimizer.getSizeOptimizationTip(
            currentSizeMB: 25.0,
            targetSizeMB: 10,
            configuration: config,
          );

          expect(tip, isNotEmpty);
          expect(
            tip.toLowerCase(),
            anyOf([
              contains('compress'),
              contains('quality'),
              contains('format'),
            ]),
          );
        },
      );

      test('should provide appropriate advice for different size ratios', () {
        final config = AudioConfiguration.raw(
          format: AudioFormat.m4a,
          quality: AudioQuality.high,
          sampleRate: 44100,
          bitDepth: 16,
        );

        final smallOverageTip = optimizer.getSizeOptimizationTip(
          currentSizeMB: 12.0,
          targetSizeMB: 10,
          configuration: config,
        );

        final largeOverageTip = optimizer.getSizeOptimizationTip(
          currentSizeMB: 30.0,
          targetSizeMB: 10,
          configuration: config,
        );

        expect(smallOverageTip, isNot(equals(largeOverageTip)));
      });
    });

    group('optimization edge cases', () {
      test('should handle very small target sizes', () {
        final result = optimizer.optimizeForTarget(
          targetSizeMB: 1,
          expectedDuration: const Duration(minutes: 5),
          recordingType: 'voice note',
          strategy: OptimizationStrategy.minimizeSize,
        );

        expect(result, isA<OptimizationResult>());
        expect(result.configuration.quality, AudioQuality.low);
      });

      test('should handle very long durations', () {
        final result = optimizer.optimizeForTarget(
          targetSizeMB: 100,
          expectedDuration: const Duration(hours: 2),
          recordingType: 'lecture',
          strategy: OptimizationStrategy.balanced,
        );

        expect(result, isA<OptimizationResult>());
        expect(result.estimatedFileSizeMB, lessThanOrEqualTo(100.0));
      });

      test('should handle very large target sizes', () {
        final result = optimizer.optimizeForTarget(
          targetSizeMB: 500,
          expectedDuration: const Duration(minutes: 10),
          recordingType: 'studio recording',
          strategy: OptimizationStrategy.maximizeQuality,
        );

        expect(result, isA<OptimizationResult>());
        expect(
          result.configuration.quality,
          isIn([AudioQuality.high, AudioQuality.ultra]),
        );
      });
    });
  });
}
