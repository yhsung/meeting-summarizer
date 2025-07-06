import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/enums/audio_format.dart';
import 'package:meeting_summarizer/core/enums/audio_quality.dart';
import 'package:meeting_summarizer/core/services/codec_manager.dart';

void main() {
  group('CodecManager', () {
    late CodecManager manager;

    setUp(() {
      manager = CodecManager();
    });

    group('getOptimalCodec', () {
      test('should return appropriate codec for format and quality', () {
        final codec = manager.getOptimalCodec(
          format: AudioFormat.mp3,
          quality: AudioQuality.medium,
          prioritizeQuality: false,
          prioritizePerformance: false,
        );

        expect(codec, isA<CodecType>());
      });

      test('should prioritize quality when requested', () {
        final codec = manager.getOptimalCodec(
          format: AudioFormat.wav,
          quality: AudioQuality.ultra,
          prioritizeQuality: true,
          prioritizePerformance: false,
        );

        final codecInfo = manager.getCodecInfo(codec);
        expect(codecInfo.compressionEfficiency, greaterThanOrEqualTo(0.8));
      });

      test('should prioritize performance when requested', () {
        final codec = manager.getOptimalCodec(
          format: AudioFormat.m4a,
          quality: AudioQuality.high,
          prioritizeQuality: false,
          prioritizePerformance: true,
        );

        final codecInfo = manager.getCodecInfo(codec);
        expect(codecInfo, isNotNull);
      });
    });

    group('getAvailableCodecs', () {
      test('should return non-empty list of available codecs', () {
        final codecs = manager.getAvailableCodecs();

        expect(codecs, isNotEmpty);
        expect(codecs.every((c) => CodecType.values.contains(c)), isTrue);
      });
    });

    group('getCompatibleCodecs', () {
      test('should return codecs compatible with format and quality', () {
        final codecs = manager.getCompatibleCodecs(
          format: AudioFormat.mp3,
          quality: AudioQuality.medium,
        );

        expect(codecs, isNotEmpty);
        for (final codec in codecs) {
          final info = manager.getCodecInfo(codec);
          expect(info.supportedFormats, contains(AudioFormat.mp3));
          expect(info.supportedQualities, contains(AudioQuality.medium));
        }
      });

      test('should handle unsupported combinations gracefully', () {
        final codecs = manager.getCompatibleCodecs(
          format: AudioFormat.wav,
          quality: AudioQuality.ultra,
        );

        expect(codecs, isA<List<CodecType>>());
      });
    });

    group('getCodecInfo', () {
      test('should return valid codec information', () {
        final info = manager.getCodecInfo(CodecType.aac);

        expect(info.type, CodecType.aac);
        expect(info.name, isNotEmpty);
        expect(info.supportedFormats, isNotEmpty);
        expect(info.supportedQualities, isNotEmpty);
        expect(info.compressionEfficiency, greaterThanOrEqualTo(0.0));
        expect(info.compressionEfficiency, lessThanOrEqualTo(1.0));
      });

      test('should return correct information for all codec types', () {
        for (final codecType in CodecType.values) {
          final info = manager.getCodecInfo(codecType);
          
          expect(info.type, codecType);
          expect(info.name, isNotEmpty);
          expect(info.supportedFormats, isNotEmpty);
          expect(info.supportedQualities, isNotEmpty);
        }
      });
    });

    group('isCodecSupported', () {
      test('should correctly identify supported codecs', () {
        final availableCodecs = manager.getAvailableCodecs();
        
        for (final codec in availableCodecs) {
          expect(manager.isCodecSupported(codec), isTrue);
        }
      });
    });

    group('isHardwareAccelerated', () {
      test('should return boolean for hardware acceleration status', () {
        final isAccelerated = manager.isHardwareAccelerated(CodecType.aac);
        expect(isAccelerated, isA<bool>());
      });
    });

    group('getCodecRecommendation', () {
      test('should return helpful recommendation text', () {
        final recommendation = manager.getCodecRecommendation(
          codec: CodecType.aac,
          format: AudioFormat.m4a,
          quality: AudioQuality.high,
        );

        expect(recommendation, isNotEmpty);
        expect(recommendation, isA<String>());
      });

      test('should provide different recommendations for different codecs', () {
        final aacRecommendation = manager.getCodecRecommendation(
          codec: CodecType.aac,
          format: AudioFormat.m4a,
          quality: AudioQuality.high,
        );

        final mp3Recommendation = manager.getCodecRecommendation(
          codec: CodecType.mp3,
          format: AudioFormat.mp3,
          quality: AudioQuality.medium,
        );

        expect(aacRecommendation, isNot(equals(mp3Recommendation)));
      });
    });

    group('getCodecParameters', () {
      test('should return complete parameter map', () {
        final params = manager.getCodecParameters(
          codec: CodecType.aac,
          format: AudioFormat.m4a,
          quality: AudioQuality.high,
        );

        expect(params, isA<Map<String, dynamic>>());
        expect(params, containsPair('codec', isA<String>()));
        expect(params, containsPair('format', isA<String>()));
        expect(params, containsPair('mimeType', isA<String>()));
        expect(params, containsPair('sampleRate', isA<int>()));
        expect(params, containsPair('bitDepth', isA<int>()));
        expect(params, containsPair('bitRate', isA<int>()));
        expect(params, containsPair('channels', isA<int>()));
        expect(params, containsPair('isHardwareAccelerated', isA<bool>()));
        expect(params, containsPair('isLossless', isA<bool>()));
        expect(params, containsPair('compressionEfficiency', isA<double>()));
      });

      test('should return consistent parameters for same codec-format-quality combination', () {
        final params1 = manager.getCodecParameters(
          codec: CodecType.mp3,
          format: AudioFormat.mp3,
          quality: AudioQuality.medium,
        );

        final params2 = manager.getCodecParameters(
          codec: CodecType.mp3,
          format: AudioFormat.mp3,
          quality: AudioQuality.medium,
        );

        expect(params1, equals(params2));
      });
    });

    group('estimateCompressionRatio', () {
      test('should return realistic compression ratios', () {
        final ratio = manager.estimateCompressionRatio(
          codec: CodecType.mp3,
          quality: AudioQuality.medium,
        );

        expect(ratio, greaterThan(0.0));
        expect(ratio, lessThanOrEqualTo(1.0));
      });

      test('should return 1.0 for lossless codecs', () {
        final ratio = manager.estimateCompressionRatio(
          codec: CodecType.pcm,
          quality: AudioQuality.high,
        );

        expect(ratio, equals(1.0));
      });

      test('should return different ratios for different qualities', () {
        final lowRatio = manager.estimateCompressionRatio(
          codec: CodecType.aac,
          quality: AudioQuality.low,
        );

        final highRatio = manager.estimateCompressionRatio(
          codec: CodecType.aac,
          quality: AudioQuality.high,
        );

        expect(lowRatio, isNot(equals(highRatio)));
      });
    });
  });
}