import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Utility class to analyze audio files and detect if they contain actual audio data
class AudioFileAnalyzer {
  /// Analyzes an audio file to determine if it contains actual audio data
  /// Returns true if the file contains non-zero audio data
  /// Supports WAV and basic file size analysis for other formats
  static Future<AudioAnalysisResult> analyzeAudioFile(String filePath) async {
    try {
      final file = File(filePath);
      
      if (!await file.exists()) {
        return AudioAnalysisResult(
          hasAudio: false,
          fileSize: 0,
          error: 'File does not exist',
        );
      }

      final bytes = await file.readAsBytes();
      final fileSize = bytes.length;
      final extension = filePath.split('.').last.toLowerCase();
      
      if (fileSize < 100) {
        return AudioAnalysisResult(
          hasAudio: false,
          fileSize: fileSize,
          error: 'File too small to contain meaningful audio data',
        );
      }

      // For WAV files, do detailed analysis
      if (extension == 'wav') {
        if (!_isValidWavFile(bytes)) {
          return AudioAnalysisResult(
            hasAudio: false,
            fileSize: fileSize,
            error: 'Not a valid WAV file',
          );
        }

        // Analyze the audio data portion
        final audioDataInfo = _analyzeAudioData(bytes);
        
        return AudioAnalysisResult(
          hasAudio: audioDataInfo.hasNonZeroData,
          fileSize: fileSize,
          audioDataSize: audioDataInfo.audioDataSize,
          maxAmplitude: audioDataInfo.maxAmplitude,
          nonZeroSamples: audioDataInfo.nonZeroSamples,
          totalSamples: audioDataInfo.totalSamples,
          sampleRate: audioDataInfo.sampleRate,
          channels: audioDataInfo.channels,
          bitDepth: audioDataInfo.bitDepth,
        );
      } else {
        // For other formats (AAC, MP3, etc.), use heuristic analysis
        final hasAudio = _analyzeNonWavFile(bytes, extension);
        
        return AudioAnalysisResult(
          hasAudio: hasAudio,
          fileSize: fileSize,
          audioDataSize: fileSize - 100, // Approximate header size
          maxAmplitude: hasAudio ? 1000 : 0, // Estimated
          nonZeroSamples: hasAudio ? 1000 : 0,
          totalSamples: hasAudio ? 1000 : 0,
          sampleRate: 44100, // Default assumption
          channels: 1,
          bitDepth: 16,
        );
      }
    } catch (e) {
      return AudioAnalysisResult(
        hasAudio: false,
        fileSize: 0,
        error: 'Error analyzing file: $e',
      );
    }
  }

  /// Checks if the file has a valid WAV header
  static bool _isValidWavFile(Uint8List bytes) {
    if (bytes.length < 44) return false;
    
    // Check RIFF header
    final riffHeader = String.fromCharCodes(bytes.sublist(0, 4));
    if (riffHeader != 'RIFF') return false;
    
    // Check WAVE header
    final waveHeader = String.fromCharCodes(bytes.sublist(8, 12));
    if (waveHeader != 'WAVE') return false;
    
    return true;
  }

  /// Analyzes the audio data portion of a WAV file
  static _AudioDataInfo _analyzeAudioData(Uint8List bytes) {
    // Parse WAV header to find audio data
    int dataOffset = 44; // Standard WAV header size
    int audioDataSize = 0;
    int sampleRate = 0;
    int channels = 0;
    int bitDepth = 0;
    
    // Parse format chunk
    if (bytes.length >= 44) {
      sampleRate = _readLittleEndianInt32(bytes, 24);
      channels = _readLittleEndianInt16(bytes, 22);
      bitDepth = _readLittleEndianInt16(bytes, 34);
    }
    
    // Find data chunk
    int offset = 36;
    while (offset < bytes.length - 8) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = _readLittleEndianInt32(bytes, offset + 4);
      
      if (chunkId == 'data') {
        dataOffset = offset + 8;
        audioDataSize = chunkSize;
        break;
      }
      offset += 8 + chunkSize;
    }
    
    if (audioDataSize == 0) {
      return _AudioDataInfo(
        hasNonZeroData: false,
        audioDataSize: 0,
        maxAmplitude: 0,
        nonZeroSamples: 0,
        totalSamples: 0,
        sampleRate: sampleRate,
        channels: channels,
        bitDepth: bitDepth,
      );
    }
    
    // Analyze audio samples
    final audioData = bytes.sublist(dataOffset, dataOffset + audioDataSize);
    int nonZeroSamples = 0;
    int maxAmplitude = 0;
    int totalSamples = audioDataSize ~/ (bitDepth ~/ 8);
    
    // Analyze samples based on bit depth
    if (bitDepth == 16) {
      for (int i = 0; i < audioData.length - 1; i += 2) {
        final sample = _readLittleEndianInt16(audioData, i);
        final amplitude = sample.abs();
        if (amplitude > 0) {
          nonZeroSamples++;
          if (amplitude > maxAmplitude) {
            maxAmplitude = amplitude;
          }
        }
      }
    } else if (bitDepth == 8) {
      for (int i = 0; i < audioData.length; i++) {
        final sample = audioData[i] - 128; // 8-bit is unsigned, convert to signed
        final amplitude = sample.abs();
        if (amplitude > 0) {
          nonZeroSamples++;
          if (amplitude > maxAmplitude) {
            maxAmplitude = amplitude;
          }
        }
      }
    }
    
    return _AudioDataInfo(
      hasNonZeroData: nonZeroSamples > 0,
      audioDataSize: audioDataSize,
      maxAmplitude: maxAmplitude,
      nonZeroSamples: nonZeroSamples,
      totalSamples: totalSamples,
      sampleRate: sampleRate,
      channels: channels,
      bitDepth: bitDepth,
    );
  }

  static int _readLittleEndianInt32(Uint8List bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  static int _readLittleEndianInt16(Uint8List bytes, int offset) {
    return bytes[offset] | (bytes[offset + 1] << 8);
  }

  /// Analyzes non-WAV audio files using heuristic methods
  static bool _analyzeNonWavFile(Uint8List bytes, String extension) {
    // For AAC/MP3 files, check for reasonable file size and format markers
    if (extension == 'aac' || extension == 'm4a') {
      // Look for AAC/MP4 markers
      final content = String.fromCharCodes(bytes.take(1000).toList());
      if (content.contains('ftyp') || content.contains('mp4a') || content.contains('M4A')) {
        return bytes.length > 1000; // Reasonable size for AAC
      }
    }
    
    if (extension == 'mp3') {
      // Look for MP3 frame headers
      for (int i = 0; i < bytes.length - 1; i++) {
        if (bytes[i] == 0xFF && (bytes[i + 1] & 0xE0) == 0xE0) {
          return bytes.length > 1000; // Found MP3 frame header
        }
      }
    }
    
    // Default heuristic: if file is reasonably sized, assume it has audio
    return bytes.length > 5000;
  }
}

/// Internal class to hold audio data analysis results
class _AudioDataInfo {
  final bool hasNonZeroData;
  final int audioDataSize;
  final int maxAmplitude;
  final int nonZeroSamples;
  final int totalSamples;
  final int sampleRate;
  final int channels;
  final int bitDepth;

  _AudioDataInfo({
    required this.hasNonZeroData,
    required this.audioDataSize,
    required this.maxAmplitude,
    required this.nonZeroSamples,
    required this.totalSamples,
    required this.sampleRate,
    required this.channels,
    required this.bitDepth,
  });
}

/// Result of audio file analysis
class AudioAnalysisResult {
  final bool hasAudio;
  final int fileSize;
  final int audioDataSize;
  final int maxAmplitude;
  final int nonZeroSamples;
  final int totalSamples;
  final int sampleRate;
  final int channels;
  final int bitDepth;
  final String? error;

  AudioAnalysisResult({
    required this.hasAudio,
    required this.fileSize,
    this.audioDataSize = 0,
    this.maxAmplitude = 0,
    this.nonZeroSamples = 0,
    this.totalSamples = 0,
    this.sampleRate = 0,
    this.channels = 0,
    this.bitDepth = 0,
    this.error,
  });

  @override
  String toString() {
    if (error != null) {
      return 'AudioAnalysisResult(error: $error)';
    }
    
    return 'AudioAnalysisResult('
        'hasAudio: $hasAudio, '
        'fileSize: ${fileSize}B, '
        'audioDataSize: ${audioDataSize}B, '
        'maxAmplitude: $maxAmplitude, '
        'nonZeroSamples: $nonZeroSamples/$totalSamples, '
        'sampleRate: ${sampleRate}Hz, '
        'channels: $channels, '
        'bitDepth: ${bitDepth}bit'
        ')';
  }

  /// Gets a percentage of non-zero samples
  double get nonZeroPercentage => 
      totalSamples > 0 ? (nonZeroSamples / totalSamples) * 100 : 0;
}