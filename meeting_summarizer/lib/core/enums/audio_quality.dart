enum AudioQuality {
  low('Low', 8000, 8),
  medium('Medium', 22050, 16),
  high('High', 44100, 16);

  const AudioQuality(this.label, this.sampleRate, this.bitDepth);

  final String label;
  final int sampleRate;
  final int bitDepth;

  int get bitRate {
    switch (this) {
      case AudioQuality.low:
        return 32000; // 32 kbps
      case AudioQuality.medium:
        return 128000; // 128 kbps
      case AudioQuality.high:
        return 320000; // 320 kbps
    }
  }
}
