import 'dart:io';
import '../enums/audio_format.dart';
import '../enums/audio_quality.dart';
import '../models/audio_configuration.dart';

class AudioFormatManager {
  static const AudioFormatManager _instance = AudioFormatManager._internal();

  factory AudioFormatManager() => _instance;

  const AudioFormatManager._internal();

  AudioFormat getOptimalFormat({
    required AudioQuality quality,
    required bool prioritizeQuality,
    required bool prioritizeSize,
    int? maxFileSizeMB,
    Duration? expectedDuration,
  }) {
    final platformCapabilities = _getPlatformCapabilities();

    if (prioritizeQuality && !prioritizeSize) {
      return _selectForQuality(platformCapabilities);
    } else if (prioritizeSize && !prioritizeQuality) {
      return _selectForSize(platformCapabilities);
    } else {
      return _selectBalanced(
        platformCapabilities,
        quality,
        maxFileSizeMB,
        expectedDuration,
      );
    }
  }

  AudioQuality getOptimalQuality({
    required AudioFormat format,
    required String recordingType,
    int? maxFileSizeMB,
    Duration? expectedDuration,
  }) {
    final isSpeech =
        recordingType.toLowerCase().contains('speech') ||
        recordingType.toLowerCase().contains('voice') ||
        recordingType.toLowerCase().contains('meeting');

    if (maxFileSizeMB != null && expectedDuration != null) {
      return _selectQualityBySize(format, maxFileSizeMB, expectedDuration);
    }

    return isSpeech ? AudioQuality.medium : AudioQuality.high;
  }

  AudioConfiguration getOptimalConfiguration({
    required String recordingType,
    bool prioritizeQuality = false,
    bool prioritizeSize = false,
    int? maxFileSizeMB,
    Duration? expectedDuration,
  }) {
    final quality = getOptimalQuality(
      format: AudioFormat.m4a,
      recordingType: recordingType,
      maxFileSizeMB: maxFileSizeMB,
      expectedDuration: expectedDuration,
    );

    final format = getOptimalFormat(
      quality: quality,
      prioritizeQuality: prioritizeQuality,
      prioritizeSize: prioritizeSize,
      maxFileSizeMB: maxFileSizeMB,
      expectedDuration: expectedDuration,
    );

    return AudioConfiguration(
      format: format,
      quality: quality,
      sampleRate: quality.sampleRate,
      bitDepth: quality.bitDepth,
      channels: 1,
      enableNoiseReduction: true,
      enableAutoGainControl: true,
    );
  }

  double estimateFileSize({
    required AudioFormat format,
    required AudioQuality quality,
    required Duration duration,
  }) {
    final uncompressedSize =
        quality.estimatedFileSizePerMinute * (duration.inSeconds / 60);
    return uncompressedSize * format.compressionRatio;
  }

  List<AudioFormat> getSupportedFormats() {
    return _getPlatformCapabilities().supportedFormats;
  }

  List<AudioQuality> getRecommendedQualities({
    required String recordingType,
    required AudioFormat format,
  }) {
    final isSpeech =
        recordingType.toLowerCase().contains('speech') ||
        recordingType.toLowerCase().contains('voice') ||
        recordingType.toLowerCase().contains('meeting');

    if (isSpeech) {
      return [AudioQuality.low, AudioQuality.medium, AudioQuality.high];
    } else {
      return [AudioQuality.medium, AudioQuality.high, AudioQuality.ultra];
    }
  }

  String getFormatRecommendation({
    required AudioFormat format,
    required AudioQuality quality,
    required String recordingType,
  }) {
    final isSpeech =
        recordingType.toLowerCase().contains('speech') ||
        recordingType.toLowerCase().contains('voice') ||
        recordingType.toLowerCase().contains('meeting');

    if (isSpeech) {
      if (format == AudioFormat.mp3 && quality == AudioQuality.medium) {
        return 'Excellent choice for speech recordings - good quality with small file size';
      } else if (format == AudioFormat.m4a && quality == AudioQuality.medium) {
        return 'Great choice for speech - better quality than MP3 with similar file size';
      }
    } else {
      if (format == AudioFormat.m4a && quality == AudioQuality.high) {
        return 'Excellent choice for music - high quality with reasonable file size';
      } else if (format == AudioFormat.wav && quality == AudioQuality.ultra) {
        return 'Professional quality - uncompressed audio with maximum fidelity';
      }
    }

    return 'Good choice for ${recordingType.toLowerCase()} recordings';
  }

  bool isFormatCompatible({
    required AudioFormat format,
    required AudioQuality quality,
  }) {
    final capabilities = _getPlatformCapabilities();

    if (!capabilities.supportedFormats.contains(format)) {
      return false;
    }

    if (format == AudioFormat.wav && quality == AudioQuality.ultra) {
      return capabilities.supportsHighBitDepth;
    }

    return true;
  }

  _PlatformCapabilities _getPlatformCapabilities() {
    if (Platform.isIOS) {
      return _PlatformCapabilities(
        supportedFormats: [AudioFormat.m4a, AudioFormat.aac, AudioFormat.wav],
        supportsHighBitDepth: true,
        preferredFormat: AudioFormat.m4a,
        maxQuality: AudioQuality.ultra,
      );
    } else if (Platform.isAndroid) {
      return _PlatformCapabilities(
        supportedFormats: [AudioFormat.mp3, AudioFormat.aac, AudioFormat.wav],
        supportsHighBitDepth: false,
        preferredFormat: AudioFormat.aac,
        maxQuality: AudioQuality.high,
      );
    } else {
      return _PlatformCapabilities(
        supportedFormats: [AudioFormat.mp3, AudioFormat.wav],
        supportsHighBitDepth: true,
        preferredFormat: AudioFormat.wav,
        maxQuality: AudioQuality.ultra,
      );
    }
  }

  AudioFormat _selectForQuality(_PlatformCapabilities capabilities) {
    final supportedFormats = capabilities.supportedFormats;
    if (supportedFormats.contains(AudioFormat.wav)) {
      return AudioFormat.wav;
    } else if (supportedFormats.contains(AudioFormat.m4a)) {
      return AudioFormat.m4a;
    } else if (supportedFormats.contains(AudioFormat.aac)) {
      return AudioFormat.aac;
    } else {
      return AudioFormat.mp3;
    }
  }

  AudioFormat _selectForSize(_PlatformCapabilities capabilities) {
    final supportedFormats = capabilities.supportedFormats;
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

  AudioFormat _selectBalanced(
    _PlatformCapabilities capabilities,
    AudioQuality quality,
    int? maxFileSizeMB,
    Duration? expectedDuration,
  ) {
    if (maxFileSizeMB != null && expectedDuration != null) {
      for (final format in capabilities.supportedFormats) {
        final estimatedSize = estimateFileSize(
          format: format,
          quality: quality,
          duration: expectedDuration,
        );

        if (estimatedSize <= maxFileSizeMB) {
          return format;
        }
      }
    }

    return capabilities.preferredFormat;
  }

  AudioQuality _selectQualityBySize(
    AudioFormat format,
    int maxFileSizeMB,
    Duration expectedDuration,
  ) {
    for (final quality in AudioQuality.values.reversed) {
      final estimatedSize = estimateFileSize(
        format: format,
        quality: quality,
        duration: expectedDuration,
      );

      if (estimatedSize <= maxFileSizeMB) {
        return quality;
      }
    }

    return AudioQuality.low;
  }
}

class _PlatformCapabilities {
  final List<AudioFormat> supportedFormats;
  final bool supportsHighBitDepth;
  final AudioFormat preferredFormat;
  final AudioQuality maxQuality;

  const _PlatformCapabilities({
    required this.supportedFormats,
    required this.supportsHighBitDepth,
    required this.preferredFormat,
    required this.maxQuality,
  });
}
