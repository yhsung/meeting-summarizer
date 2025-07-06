import '../enums/audio_format.dart';
import '../enums/audio_quality.dart';

class AudioConfiguration {
  final AudioFormat format;
  final AudioQuality quality;
  final bool noiseReduction;
  final bool autoGainControl;
  final Duration? recordingLimit;
  final String? outputDirectory;

  const AudioConfiguration({
    this.format = AudioFormat.wav,
    this.quality = AudioQuality.high,
    this.noiseReduction = true,
    this.autoGainControl = true,
    this.recordingLimit,
    this.outputDirectory,
  });

  AudioConfiguration copyWith({
    AudioFormat? format,
    AudioQuality? quality,
    bool? noiseReduction,
    bool? autoGainControl,
    Duration? recordingLimit,
    String? outputDirectory,
  }) {
    return AudioConfiguration(
      format: format ?? this.format,
      quality: quality ?? this.quality,
      noiseReduction: noiseReduction ?? this.noiseReduction,
      autoGainControl: autoGainControl ?? this.autoGainControl,
      recordingLimit: recordingLimit ?? this.recordingLimit,
      outputDirectory: outputDirectory ?? this.outputDirectory,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioConfiguration &&
        other.format == format &&
        other.quality == quality &&
        other.noiseReduction == noiseReduction &&
        other.autoGainControl == autoGainControl &&
        other.recordingLimit == recordingLimit &&
        other.outputDirectory == outputDirectory;
  }

  @override
  int get hashCode {
    return Object.hash(
      format,
      quality,
      noiseReduction,
      autoGainControl,
      recordingLimit,
      outputDirectory,
    );
  }
}