import '../enums/audio_format.dart';
import '../enums/audio_quality.dart';
import '../models/audio_configuration.dart';
import 'audio_format_manager.dart';
import 'codec_manager.dart';

enum OptimizationStrategy {
  minimizeSize,
  maximizeQuality,
  balanced,
  speechOptimized,
  musicOptimized,
}

class OptimizationResult {
  final AudioConfiguration configuration;
  final double estimatedFileSizeMB;
  final String strategy;
  final List<String> optimizations;
  final double qualityScore;
  final double compressionRatio;

  const OptimizationResult({
    required this.configuration,
    required this.estimatedFileSizeMB,
    required this.strategy,
    required this.optimizations,
    required this.qualityScore,
    required this.compressionRatio,
  });
}

class FileSizeOptimizer {
  static const FileSizeOptimizer _instance = FileSizeOptimizer._internal();

  factory FileSizeOptimizer() => _instance;

  const FileSizeOptimizer._internal();

  AudioFormatManager get _formatManager => AudioFormatManager();
  CodecManager get _codecManager => CodecManager();

  OptimizationResult optimizeForTarget({
    required int targetSizeMB,
    required Duration expectedDuration,
    required String recordingType,
    OptimizationStrategy strategy = OptimizationStrategy.balanced,
  }) {
    final optimizations = <String>[];

    AudioFormat optimalFormat;
    AudioQuality optimalQuality;

    switch (strategy) {
      case OptimizationStrategy.minimizeSize:
        optimalFormat = _selectForMinimalSize();
        optimalQuality = _selectQualityForSize(
          optimalFormat,
          targetSizeMB,
          expectedDuration,
        );
        optimizations.add(
          'Selected most compressed format: ${optimalFormat.extension.toUpperCase()}',
        );
        optimizations.add('Reduced quality to fit target size');
        break;

      case OptimizationStrategy.maximizeQuality:
        optimalQuality = _selectForMaximalQuality();
        optimalFormat = _selectFormatForQuality(
          optimalQuality,
          targetSizeMB,
          expectedDuration,
        );
        optimizations.add('Selected highest quality: ${optimalQuality.label}');
        optimizations.add('Optimized format for quality preservation');
        break;

      case OptimizationStrategy.speechOptimized:
        optimalQuality = AudioQuality.medium;
        optimalFormat = _selectForSpeech();
        optimizations.add('Optimized for speech content');
        optimizations.add('Selected speech-appropriate quality settings');
        break;

      case OptimizationStrategy.musicOptimized:
        optimalQuality = AudioQuality.high;
        optimalFormat = _selectForMusic();
        optimizations.add('Optimized for music content');
        optimizations.add('Selected high-fidelity settings');
        break;

      case OptimizationStrategy.balanced:
        final result = _balancedOptimization(
          targetSizeMB,
          expectedDuration,
          recordingType,
        );
        optimalFormat = result.format;
        optimalQuality = result.quality;
        optimizations.addAll(result.optimizations);
        break;
    }

    final codec = _codecManager.getOptimalCodec(
      format: optimalFormat,
      quality: optimalQuality,
      prioritizeQuality: strategy == OptimizationStrategy.maximizeQuality,
      prioritizePerformance: strategy == OptimizationStrategy.minimizeSize,
    );

    final configuration = AudioConfiguration(
      format: optimalFormat,
      quality: optimalQuality,
      sampleRate: optimalQuality.sampleRate,
      bitDepth: optimalQuality.bitDepth,
      channels: recordingType.toLowerCase().contains('stereo') ? 2 : 1,
      enableNoiseReduction:
          recordingType.toLowerCase().contains('speech') ||
          recordingType.toLowerCase().contains('voice') ||
          recordingType.toLowerCase().contains('meeting'),
      enableAutoGainControl: true,
    );

    final estimatedSize = _formatManager.estimateFileSize(
      format: optimalFormat,
      quality: optimalQuality,
      duration: expectedDuration,
    );

    final qualityScore = _calculateQualityScore(optimalFormat, optimalQuality);
    final compressionRatio = _codecManager.estimateCompressionRatio(
      codec: codec,
      quality: optimalQuality,
    );

    return OptimizationResult(
      configuration: configuration,
      estimatedFileSizeMB: estimatedSize,
      strategy: strategy.name,
      optimizations: optimizations,
      qualityScore: qualityScore,
      compressionRatio: compressionRatio,
    );
  }

  List<OptimizationResult> generateRecommendations({
    required int targetSizeMB,
    required Duration expectedDuration,
    required String recordingType,
  }) {
    final strategies = [
      OptimizationStrategy.minimizeSize,
      OptimizationStrategy.balanced,
      OptimizationStrategy.maximizeQuality,
    ];

    if (recordingType.toLowerCase().contains('speech') ||
        recordingType.toLowerCase().contains('voice') ||
        recordingType.toLowerCase().contains('meeting')) {
      strategies.add(OptimizationStrategy.speechOptimized);
    } else {
      strategies.add(OptimizationStrategy.musicOptimized);
    }

    return strategies.map((strategy) {
      return optimizeForTarget(
        targetSizeMB: targetSizeMB,
        expectedDuration: expectedDuration,
        recordingType: recordingType,
        strategy: strategy,
      );
    }).toList();
  }

  double calculateDynamicFileSize({
    required AudioConfiguration configuration,
    required Duration currentDuration,
    Duration? totalExpectedDuration,
  }) {
    final baseSize = _formatManager.estimateFileSize(
      format: configuration.format,
      quality: configuration.quality,
      duration: currentDuration,
    );

    if (totalExpectedDuration != null &&
        totalExpectedDuration > currentDuration) {
      final projectedSize = _formatManager.estimateFileSize(
        format: configuration.format,
        quality: configuration.quality,
        duration: totalExpectedDuration,
      );
      return projectedSize;
    }

    return baseSize;
  }

  String getSizeOptimizationTip({
    required double currentSizeMB,
    required int targetSizeMB,
    required AudioConfiguration configuration,
  }) {
    if (currentSizeMB <= targetSizeMB) {
      return 'Current configuration fits within target size';
    }

    final ratio = currentSizeMB / targetSizeMB;

    if (ratio > 2.0) {
      return 'Consider switching to a more compressed format like MP3 or reducing quality significantly';
    } else if (ratio > 1.5) {
      return 'Reduce audio quality or switch to a more compressed format';
    } else {
      return 'Small adjustment needed - slightly reduce quality or enable more aggressive compression';
    }
  }

  AudioFormat _selectForMinimalSize() {
    final supportedFormats = _formatManager.getSupportedFormats();

    if (supportedFormats.contains(AudioFormat.aac)) {
      return AudioFormat.aac;
    } else if (supportedFormats.contains(AudioFormat.mp3)) {
      return AudioFormat.mp3;
    } else if (supportedFormats.contains(AudioFormat.m4a)) {
      return AudioFormat.m4a;
    } else {
      return AudioFormat.wav;
    }
  }

  AudioQuality _selectForMaximalQuality() {
    return AudioQuality.ultra;
  }

  AudioFormat _selectForSpeech() {
    final supportedFormats = _formatManager.getSupportedFormats();

    if (supportedFormats.contains(AudioFormat.aac)) {
      return AudioFormat.aac;
    } else if (supportedFormats.contains(AudioFormat.mp3)) {
      return AudioFormat.mp3;
    } else {
      return supportedFormats.first;
    }
  }

  AudioFormat _selectForMusic() {
    final supportedFormats = _formatManager.getSupportedFormats();

    if (supportedFormats.contains(AudioFormat.m4a)) {
      return AudioFormat.m4a;
    } else if (supportedFormats.contains(AudioFormat.wav)) {
      return AudioFormat.wav;
    } else {
      return supportedFormats.first;
    }
  }

  AudioQuality _selectQualityForSize(
    AudioFormat format,
    int targetSizeMB,
    Duration duration,
  ) {
    for (final quality in AudioQuality.values.reversed) {
      final estimatedSize = _formatManager.estimateFileSize(
        format: format,
        quality: quality,
        duration: duration,
      );

      if (estimatedSize <= targetSizeMB) {
        return quality;
      }
    }

    return AudioQuality.low;
  }

  AudioFormat _selectFormatForQuality(
    AudioQuality quality,
    int targetSizeMB,
    Duration duration,
  ) {
    final supportedFormats = _formatManager.getSupportedFormats();

    for (final format in [
      AudioFormat.wav,
      AudioFormat.m4a,
      AudioFormat.aac,
      AudioFormat.mp3,
    ]) {
      if (!supportedFormats.contains(format)) continue;

      final estimatedSize = _formatManager.estimateFileSize(
        format: format,
        quality: quality,
        duration: duration,
      );

      if (estimatedSize <= targetSizeMB) {
        return format;
      }
    }

    return supportedFormats.first;
  }

  _BalancedResult _balancedOptimization(
    int targetSizeMB,
    Duration duration,
    String recordingType,
  ) {
    final optimizations = <String>[];

    final isSpeech =
        recordingType.toLowerCase().contains('speech') ||
        recordingType.toLowerCase().contains('voice') ||
        recordingType.toLowerCase().contains('meeting');

    AudioQuality quality = isSpeech ? AudioQuality.medium : AudioQuality.high;
    AudioFormat format = AudioFormat.m4a;

    optimizations.add('Selected balanced quality: ${quality.label}');
    optimizations.add(
      'Selected efficient format: ${format.extension.toUpperCase()}',
    );

    double estimatedSize = _formatManager.estimateFileSize(
      format: format,
      quality: quality,
      duration: duration,
    );

    if (estimatedSize > targetSizeMB) {
      if (quality != AudioQuality.low) {
        quality = AudioQuality.values[AudioQuality.values.indexOf(quality) - 1];
        optimizations.add('Reduced quality to fit target size');
      }

      estimatedSize = _formatManager.estimateFileSize(
        format: format,
        quality: quality,
        duration: duration,
      );

      if (estimatedSize > targetSizeMB && format != AudioFormat.aac) {
        format = AudioFormat.aac;
        optimizations.add('Switched to more compressed format');
      }
    }

    return _BalancedResult(
      format: format,
      quality: quality,
      optimizations: optimizations,
    );
  }

  double _calculateQualityScore(AudioFormat format, AudioQuality quality) {
    double formatScore = format.isLossless ? 1.0 : 0.8;
    double qualityScore =
        (AudioQuality.values.indexOf(quality) + 1) / AudioQuality.values.length;

    return (formatScore + qualityScore) / 2;
  }
}

class _BalancedResult {
  final AudioFormat format;
  final AudioQuality quality;
  final List<String> optimizations;

  const _BalancedResult({
    required this.format,
    required this.quality,
    required this.optimizations,
  });
}
