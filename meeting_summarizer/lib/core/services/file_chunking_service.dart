import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:crypto/crypto.dart';

import '../models/cloud_sync/file_change.dart';

/// Service for splitting files into chunks for efficient transfer and delta synchronization
class FileChunkingService {
  static FileChunkingService? _instance;
  static FileChunkingService get instance =>
      _instance ??= FileChunkingService._();
  FileChunkingService._();

  // Configurable chunk sizes for different file types and scenarios
  static const Map<String, int> _chunkSizesByType = {
    'default': 1024 * 1024, // 1MB default
    'small': 256 * 1024, // 256KB for small files
    'large': 4 * 1024 * 1024, // 4MB for large files
    'text': 64 * 1024, // 64KB for text files
    'audio': 2 * 1024 * 1024, // 2MB for audio files
    'video': 8 * 1024 * 1024, // 8MB for video files
  };

  static const int _minChunkSize = 64 * 1024; // 64KB minimum
  static const int _maxChunkSize = 16 * 1024 * 1024; // 16MB maximum

  /// Split a file into chunks for transfer
  Future<List<FileChunk>> createFileChunks({
    required String filePath,
    int? customChunkSize,
    bool calculateChecksums = true,
  }) async {
    try {
      log('FileChunkingService: Creating chunks for $filePath');

      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException('File not found', filePath);
      }

      final fileSize = await file.length();
      final chunkSize =
          customChunkSize ?? _determineOptimalChunkSize(filePath, fileSize);
      final chunks = <FileChunk>[];

      log(
        'FileChunkingService: File size: $fileSize bytes, chunk size: $chunkSize bytes',
      );

      final randomAccessFile = await file.open();
      int offset = 0;
      int chunkIndex = 0;

      while (offset < fileSize) {
        final remainingBytes = fileSize - offset;
        final currentChunkSize =
            remainingBytes > chunkSize ? chunkSize : remainingBytes;

        await randomAccessFile.setPosition(offset);
        final chunkData = await randomAccessFile.read(currentChunkSize);

        String checksum = '';
        if (calculateChecksums) {
          checksum = sha256.convert(chunkData).toString();
        }

        chunks.add(
          FileChunk(
            index: chunkIndex,
            offset: offset,
            size: currentChunkSize,
            checksum: checksum,
            isChanged: true, // Initially mark as changed
            data: chunkData,
          ),
        );

        offset += currentChunkSize;
        chunkIndex++;
      }

      await randomAccessFile.close();

      log('FileChunkingService: Created ${chunks.length} chunks for $filePath');
      return chunks;
    } catch (e, stackTrace) {
      log(
        'FileChunkingService: Error creating chunks for $filePath: $e',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Compare chunks to identify changes between file versions
  Future<List<FileChunk>> identifyChangedChunks({
    required List<FileChunk> previousChunks,
    required List<FileChunk> currentChunks,
  }) async {
    try {
      log(
        'FileChunkingService: Comparing ${previousChunks.length} previous chunks '
        'with ${currentChunks.length} current chunks',
      );

      final changedChunks = <FileChunk>[];
      final maxChunks = currentChunks.length > previousChunks.length
          ? currentChunks.length
          : previousChunks.length;

      for (int i = 0; i < maxChunks; i++) {
        if (i >= currentChunks.length) {
          // Chunk was removed (file shrunk)
          continue;
        }

        final currentChunk = currentChunks[i];

        if (i >= previousChunks.length) {
          // New chunk (file grew)
          changedChunks.add(currentChunk.copyWith(isChanged: true));
          continue;
        }

        final previousChunk = previousChunks[i];

        // Compare checksums to detect changes
        if (currentChunk.checksum != previousChunk.checksum) {
          changedChunks.add(currentChunk.copyWith(isChanged: true));
        }
      }

      log(
        'FileChunkingService: Identified ${changedChunks.length} changed chunks',
      );

      return changedChunks;
    } catch (e, stackTrace) {
      log(
        'FileChunkingService: Error identifying changed chunks: $e',
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Reassemble chunks back into a file
  Future<bool> reassembleFile({
    required String outputPath,
    required List<FileChunk> chunks,
    bool verifyIntegrity = true,
  }) async {
    try {
      log(
        'FileChunkingService: Reassembling ${chunks.length} chunks to $outputPath',
      );

      // Sort chunks by index to ensure correct order
      final sortedChunks = List<FileChunk>.from(chunks)
        ..sort((a, b) => a.index.compareTo(b.index));

      final outputFile = File(outputPath);
      final sink = outputFile.openWrite();

      int expectedOffset = 0;
      for (final chunk in sortedChunks) {
        if (chunk.offset != expectedOffset) {
          log(
            'FileChunkingService: Warning - chunk offset mismatch. '
            'Expected: $expectedOffset, got: ${chunk.offset}',
          );
        }

        if (chunk.data != null) {
          sink.add(chunk.data!);
        } else {
          log(
            'FileChunkingService: Warning - chunk ${chunk.index} has no data',
          );
        }

        expectedOffset += chunk.size;
      }

      await sink.close();

      if (verifyIntegrity) {
        final isValid = await _verifyFileIntegrity(outputPath, sortedChunks);
        if (!isValid) {
          log('FileChunkingService: File integrity verification failed');
          return false;
        }
      }

      log('FileChunkingService: Successfully reassembled file to $outputPath');
      return true;
    } catch (e, stackTrace) {
      log(
        'FileChunkingService: Error reassembling file: $e',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Calculate optimal chunk size based on file characteristics
  int _determineOptimalChunkSize(String filePath, int fileSize) {
    // Get file extension to determine type
    final extension = filePath.split('.').last.toLowerCase();

    // Determine base chunk size by file type
    int baseChunkSize;
    if (_chunkSizesByType.containsKey(extension)) {
      baseChunkSize = _chunkSizesByType[extension]!;
    } else if (_isTextFile(extension)) {
      baseChunkSize = _chunkSizesByType['text']!;
    } else if (_isAudioFile(extension)) {
      baseChunkSize = _chunkSizesByType['audio']!;
    } else if (_isVideoFile(extension)) {
      baseChunkSize = _chunkSizesByType['video']!;
    } else {
      baseChunkSize = _chunkSizesByType['default']!;
    }

    // Adjust based on file size
    if (fileSize < 1024 * 1024) {
      // Small files: use smaller chunks
      baseChunkSize = _chunkSizesByType['small']!;
    } else if (fileSize > 100 * 1024 * 1024) {
      // Large files: use larger chunks
      baseChunkSize = _chunkSizesByType['large']!;
    }

    // Ensure chunk size is within bounds
    baseChunkSize = baseChunkSize.clamp(_minChunkSize, _maxChunkSize);

    // Ensure we don't create too many tiny chunks
    final maxChunks = 1000; // Reasonable maximum
    if (fileSize / baseChunkSize > maxChunks) {
      baseChunkSize = (fileSize / maxChunks).ceil();
    }

    log(
      'FileChunkingService: Determined chunk size $baseChunkSize bytes for '
      '$filePath (${fileSize ~/ 1024} KB)',
    );

    return baseChunkSize;
  }

  /// Check if file extension indicates a text file
  bool _isTextFile(String extension) {
    const textExtensions = {
      'txt',
      'md',
      'json',
      'xml',
      'csv',
      'log',
      'yaml',
      'yml',
      'js',
      'ts',
      'dart',
      'py',
      'java',
      'cpp',
      'c',
      'h',
    };
    return textExtensions.contains(extension);
  }

  /// Check if file extension indicates an audio file
  bool _isAudioFile(String extension) {
    const audioExtensions = {'mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg', 'wma'};
    return audioExtensions.contains(extension);
  }

  /// Check if file extension indicates a video file
  bool _isVideoFile(String extension) {
    const videoExtensions = {'mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv', 'webm'};
    return videoExtensions.contains(extension);
  }

  /// Verify file integrity after reassembly
  Future<bool> _verifyFileIntegrity(
    String filePath,
    List<FileChunk> expectedChunks,
  ) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return false;
      }

      final actualSize = await file.length();
      final expectedSize = expectedChunks.fold<int>(
        0,
        (sum, chunk) => sum + chunk.size,
      );

      if (actualSize != expectedSize) {
        log(
          'FileChunkingService: Size mismatch - expected: $expectedSize, actual: $actualSize',
        );
        return false;
      }

      // Verify chunk checksums
      final randomAccessFile = await file.open();

      for (final chunk in expectedChunks) {
        if (chunk.checksum.isEmpty) continue; // Skip if no checksum available

        await randomAccessFile.setPosition(chunk.offset);
        final chunkData = await randomAccessFile.read(chunk.size);
        final actualChecksum = sha256.convert(chunkData).toString();

        if (actualChecksum != chunk.checksum) {
          log(
            'FileChunkingService: Checksum mismatch for chunk ${chunk.index}',
          );
          await randomAccessFile.close();
          return false;
        }
      }

      await randomAccessFile.close();
      return true;
    } catch (e) {
      log('FileChunkingService: Error verifying file integrity: $e');
      return false;
    }
  }

  /// Get chunk information for a file without reading chunk data
  Future<ChunkInfo> getChunkInfo({
    required String filePath,
    int? customChunkSize,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileSystemException('File not found', filePath);
      }

      final fileSize = await file.length();
      final chunkSize =
          customChunkSize ?? _determineOptimalChunkSize(filePath, fileSize);
      final chunkCount = (fileSize / chunkSize).ceil();

      return ChunkInfo(
        filePath: filePath,
        fileSize: fileSize,
        chunkSize: chunkSize,
        chunkCount: chunkCount,
        estimatedTransferTime: _estimateTransferTime(fileSize, chunkCount),
      );
    } catch (e) {
      log('FileChunkingService: Error getting chunk info: $e');
      rethrow;
    }
  }

  /// Estimate transfer time based on file size and chunk count
  Duration _estimateTransferTime(int fileSize, int chunkCount) {
    // Very rough estimation based on typical network speeds
    const avgNetworkSpeedBytesPerSecond = 1024 * 1024; // 1 MB/s
    const chunkOverheadMs = 100; // 100ms overhead per chunk

    final transferSeconds = fileSize / avgNetworkSpeedBytesPerSecond;
    final overheadSeconds = (chunkCount * chunkOverheadMs) / 1000;

    return Duration(
      milliseconds: ((transferSeconds + overheadSeconds) * 1000).round(),
    );
  }

  /// Create chunks from existing file data without reading from disk
  List<FileChunk> createChunksFromData({
    required List<int> data,
    int? customChunkSize,
    bool calculateChecksums = true,
  }) {
    final chunkSize = customChunkSize ?? _chunkSizesByType['default']!;
    final chunks = <FileChunk>[];

    int offset = 0;
    int chunkIndex = 0;

    while (offset < data.length) {
      final remainingBytes = data.length - offset;
      final currentChunkSize =
          remainingBytes > chunkSize ? chunkSize : remainingBytes;

      final chunkData = data.sublist(offset, offset + currentChunkSize);

      String checksum = '';
      if (calculateChecksums) {
        checksum = sha256.convert(chunkData).toString();
      }

      chunks.add(
        FileChunk(
          index: chunkIndex,
          offset: offset,
          size: currentChunkSize,
          checksum: checksum,
          isChanged: true,
          data: chunkData,
        ),
      );

      offset += currentChunkSize;
      chunkIndex++;
    }

    return chunks;
  }
}

/// Information about file chunking without actual chunk data
class ChunkInfo {
  final String filePath;
  final int fileSize;
  final int chunkSize;
  final int chunkCount;
  final Duration estimatedTransferTime;

  const ChunkInfo({
    required this.filePath,
    required this.fileSize,
    required this.chunkSize,
    required this.chunkCount,
    required this.estimatedTransferTime,
  });

  /// Get formatted file size
  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get formatted chunk size
  String get formattedChunkSize {
    if (chunkSize < 1024) return '$chunkSize B';
    if (chunkSize < 1024 * 1024) {
      return '${(chunkSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(chunkSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  String toString() {
    return 'ChunkInfo(file: $formattedFileSize, chunks: $chunkCount x $formattedChunkSize, '
        'est. time: ${estimatedTransferTime.inSeconds}s)';
  }
}
