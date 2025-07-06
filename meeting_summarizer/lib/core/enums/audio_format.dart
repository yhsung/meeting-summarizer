enum AudioFormat {
  wav('wav', 'audio/wav'),
  mp3('mp3', 'audio/mpeg'),
  m4a('m4a', 'audio/mp4'),
  aac('aac', 'audio/aac');

  const AudioFormat(this.extension, this.mimeType);

  final String extension;
  final String mimeType;

  static AudioFormat fromExtension(String extension) {
    return AudioFormat.values.firstWhere(
      (format) => format.extension == extension.toLowerCase(),
      orElse: () => AudioFormat.wav,
    );
  }
}
