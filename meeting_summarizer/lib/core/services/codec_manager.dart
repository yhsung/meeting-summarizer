import 'dart:io';
import '../enums/audio_format.dart';
import '../enums/audio_quality.dart';

enum CodecType {
  aac,
  mp3,
  pcm,
  opus,
  vorbis,
}

class CodecInfo {
  final CodecType type;
  final String name;
  final List<AudioFormat> supportedFormats;
  final List<AudioQuality> supportedQualities;
  final bool isHardwareAccelerated;
  final bool isLossless;
  final double compressionEfficiency;

  const CodecInfo({
    required this.type,
    required this.name,
    required this.supportedFormats,
    required this.supportedQualities,
    required this.isHardwareAccelerated,
    required this.isLossless,
    required this.compressionEfficiency,
  });
}

class CodecManager {
  static const CodecManager _instance = CodecManager._internal();
  
  factory CodecManager() => _instance;
  
  const CodecManager._internal();

  static const Map<CodecType, CodecInfo> _codecDatabase = {
    CodecType.aac: CodecInfo(
      type: CodecType.aac,
      name: 'Advanced Audio Coding',
      supportedFormats: [AudioFormat.aac, AudioFormat.m4a],
      supportedQualities: [AudioQuality.low, AudioQuality.medium, AudioQuality.high],
      isHardwareAccelerated: true,
      isLossless: false,
      compressionEfficiency: 0.89,
    ),
    CodecType.mp3: CodecInfo(
      type: CodecType.mp3,
      name: 'MPEG-1 Audio Layer III',
      supportedFormats: [AudioFormat.mp3],
      supportedQualities: [AudioQuality.low, AudioQuality.medium, AudioQuality.high],
      isHardwareAccelerated: false,
      isLossless: false,
      compressionEfficiency: 0.80,
    ),
    CodecType.pcm: CodecInfo(
      type: CodecType.pcm,
      name: 'Pulse Code Modulation',
      supportedFormats: [AudioFormat.wav],
      supportedQualities: [AudioQuality.low, AudioQuality.medium, AudioQuality.high, AudioQuality.ultra],
      isHardwareAccelerated: true,
      isLossless: true,
      compressionEfficiency: 1.0,
    ),
    CodecType.opus: CodecInfo(
      type: CodecType.opus,
      name: 'Opus Interactive Audio Codec',
      supportedFormats: [AudioFormat.wav],
      supportedQualities: [AudioQuality.low, AudioQuality.medium, AudioQuality.high],
      isHardwareAccelerated: false,
      isLossless: false,
      compressionEfficiency: 0.95,
    ),
    CodecType.vorbis: CodecInfo(
      type: CodecType.vorbis,
      name: 'Vorbis Audio Codec',
      supportedFormats: [AudioFormat.wav],
      supportedQualities: [AudioQuality.low, AudioQuality.medium, AudioQuality.high],
      isHardwareAccelerated: false,
      isLossless: false,
      compressionEfficiency: 0.85,
    ),
  };

  CodecType getOptimalCodec({
    required AudioFormat format,
    required AudioQuality quality,
    required bool prioritizeQuality,
    required bool prioritizePerformance,
  }) {
    final availableCodecs = getAvailableCodecs();
    final compatibleCodecs = availableCodecs.where((codec) {
      final info = _codecDatabase[codec]!;
      return info.supportedFormats.contains(format) && 
             info.supportedQualities.contains(quality);
    }).toList();

    if (compatibleCodecs.isEmpty) {
      return _getDefaultCodecForFormat(format);
    }

    if (prioritizeQuality) {
      return _selectForQuality(compatibleCodecs);
    } else if (prioritizePerformance) {
      return _selectForPerformance(compatibleCodecs);
    } else {
      return _selectBalanced(compatibleCodecs);
    }
  }

  List<CodecType> getAvailableCodecs() {
    if (Platform.isIOS) {
      return [CodecType.aac, CodecType.pcm];
    } else if (Platform.isAndroid) {
      return [CodecType.aac, CodecType.mp3, CodecType.pcm];
    } else {
      return [CodecType.mp3, CodecType.pcm, CodecType.opus, CodecType.vorbis];
    }
  }

  List<CodecType> getCompatibleCodecs({
    required AudioFormat format,
    required AudioQuality quality,
  }) {
    return getAvailableCodecs().where((codec) {
      final info = _codecDatabase[codec]!;
      return info.supportedFormats.contains(format) && 
             info.supportedQualities.contains(quality);
    }).toList();
  }

  CodecInfo getCodecInfo(CodecType codec) {
    return _codecDatabase[codec]!;
  }

  bool isCodecSupported(CodecType codec) {
    return getAvailableCodecs().contains(codec);
  }

  bool isHardwareAccelerated(CodecType codec) {
    final info = _codecDatabase[codec];
    return info?.isHardwareAccelerated ?? false;
  }

  String getCodecRecommendation({
    required CodecType codec,
    required AudioFormat format,
    required AudioQuality quality,
  }) {
    final info = _codecDatabase[codec]!;
    
    if (info.isHardwareAccelerated) {
      return 'Hardware accelerated codec - excellent performance and battery efficiency';
    } else if (info.isLossless) {
      return 'Lossless codec - perfect audio quality with no compression artifacts';
    } else if (info.compressionEfficiency > 0.9) {
      return 'High-efficiency codec - excellent quality-to-size ratio';
    } else if (info.compressionEfficiency > 0.8) {
      return 'Good compression codec - balanced quality and file size';
    } else {
      return 'Standard codec - widely compatible with good quality';
    }
  }

  Map<String, dynamic> getCodecParameters({
    required CodecType codec,
    required AudioFormat format,
    required AudioQuality quality,
  }) {
    final info = _codecDatabase[codec]!;
    
    return {
      'codec': codec.name,
      'format': format.extension,
      'mimeType': format.mimeType,
      'sampleRate': quality.sampleRate,
      'bitDepth': quality.bitDepth,
      'bitRate': quality.bitRate,
      'channels': 1,
      'isHardwareAccelerated': info.isHardwareAccelerated,
      'isLossless': info.isLossless,
      'compressionEfficiency': info.compressionEfficiency,
    };
  }

  double estimateCompressionRatio({
    required CodecType codec,
    required AudioQuality quality,
  }) {
    final info = _codecDatabase[codec]!;
    
    if (info.isLossless) {
      return 1.0;
    }
    
    final baseCompression = info.compressionEfficiency;
    final qualityFactor = _getQualityFactor(quality);
    
    return baseCompression * qualityFactor;
  }

  CodecType _getDefaultCodecForFormat(AudioFormat format) {
    switch (format) {
      case AudioFormat.mp3:
        return CodecType.mp3;
      case AudioFormat.aac:
      case AudioFormat.m4a:
        return CodecType.aac;
      case AudioFormat.wav:
        return CodecType.pcm;
    }
  }

  CodecType _selectForQuality(List<CodecType> codecs) {
    final losslessCodecs = codecs.where((codec) => _codecDatabase[codec]!.isLossless).toList();
    if (losslessCodecs.isNotEmpty) {
      return losslessCodecs.first;
    }
    
    codecs.sort((a, b) => _codecDatabase[b]!.compressionEfficiency.compareTo(_codecDatabase[a]!.compressionEfficiency));
    return codecs.first;
  }

  CodecType _selectForPerformance(List<CodecType> codecs) {
    final hardwareCodecs = codecs.where((codec) => _codecDatabase[codec]!.isHardwareAccelerated).toList();
    if (hardwareCodecs.isNotEmpty) {
      return hardwareCodecs.first;
    }
    
    return codecs.first;
  }

  CodecType _selectBalanced(List<CodecType> codecs) {
    final scores = codecs.map((codec) {
      final info = _codecDatabase[codec]!;
      double score = info.compressionEfficiency;
      if (info.isHardwareAccelerated) score += 0.2;
      if (info.isLossless) score += 0.1;
      return MapEntry(codec, score);
    }).toList();
    
    scores.sort((a, b) => b.value.compareTo(a.value));
    return scores.first.key;
  }

  double _getQualityFactor(AudioQuality quality) {
    switch (quality) {
      case AudioQuality.low:
        return 0.3;
      case AudioQuality.medium:
        return 0.6;
      case AudioQuality.high:
        return 0.9;
      case AudioQuality.ultra:
        return 1.0;
    }
  }
}