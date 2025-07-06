enum AudioQuality {
  low('Low', 8000, 8, 'Voice recording, minimal storage'),
  medium('Medium', 22050, 16, 'Good balance of quality and file size'),
  high('High', 44100, 16, 'High quality recording, larger file size'),
  ultra('Ultra', 48000, 24, 'Professional quality, maximum file size');

  const AudioQuality(this.label, this.sampleRate, this.bitDepth, this.description);

  final String label;
  final int sampleRate;
  final int bitDepth;
  final String description;

  int get bitRate {
    switch (this) {
      case AudioQuality.low:
        return 32000; // 32 kbps
      case AudioQuality.medium:
        return 128000; // 128 kbps
      case AudioQuality.high:
        return 320000; // 320 kbps
      case AudioQuality.ultra:
        return 1411200; // 1411 kbps (CD quality)
    }
  }

  double get estimatedFileSizePerMinute {
    final bytesPerSecond = (sampleRate * bitDepth) / 8;
    return (bytesPerSecond * 60) / (1024 * 1024); // MB per minute
  }

  bool get isRecommendedForSpeech {
    switch (this) {
      case AudioQuality.low:
      case AudioQuality.medium:
        return true;
      case AudioQuality.high:
      case AudioQuality.ultra:
        return false;
    }
  }

  bool get isRecommendedForMusic {
    switch (this) {
      case AudioQuality.low:
        return false;
      case AudioQuality.medium:
      case AudioQuality.high:
      case AudioQuality.ultra:
        return true;
    }
  }
}
