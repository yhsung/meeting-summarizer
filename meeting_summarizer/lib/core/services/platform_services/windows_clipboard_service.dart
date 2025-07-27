/// Windows Clipboard Integration Service
///
/// Provides advanced clipboard operations for sharing transcripts,
/// summaries, and recording information with rich formatting support.
library;

import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:flutter/services.dart' as flutter_services;
import 'package:flutter/services.dart';

/// Clipboard data format types
enum ClipboardFormat {
  text('text/plain'),
  html('text/html'),
  rtf('text/rtf'),
  markdown('text/markdown'),
  json('application/json'),
  custom('application/meeting-summarizer');

  const ClipboardFormat(this.mimeType);
  final String mimeType;
}

/// Clipboard data item (custom implementation to avoid conflict with Flutter's ClipboardData)
class WindowsClipboardData {
  final ClipboardFormat format;
  final String data;
  final Map<String, String>? metadata;

  const WindowsClipboardData({
    required this.format,
    required this.data,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'format': format.mimeType,
        'data': data,
        'metadata': metadata ?? {},
      };
}

/// Rich clipboard content with multiple formats
class RichClipboardContent {
  final String title;
  final List<WindowsClipboardData> formats;
  final DateTime timestamp;

  const RichClipboardContent({
    required this.title,
    required this.formats,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'formats': formats.map((f) => f.toJson()).toList(),
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Transcript sharing options
class TranscriptSharingOptions {
  final bool includeTimestamps;
  final bool includeSpeakerLabels;
  final bool includeConfidenceScores;
  final bool formatAsMarkdown;
  final bool includeMetadata;

  const TranscriptSharingOptions({
    this.includeTimestamps = true,
    this.includeSpeakerLabels = true,
    this.includeConfidenceScores = false,
    this.formatAsMarkdown = true,
    this.includeMetadata = true,
  });

  Map<String, dynamic> toJson() => {
        'includeTimestamps': includeTimestamps,
        'includeSpeakerLabels': includeSpeakerLabels,
        'includeConfidenceScores': includeConfidenceScores,
        'formatAsMarkdown': formatAsMarkdown,
        'includeMetadata': includeMetadata,
      };
}

/// Windows Clipboard Service
class WindowsClipboardService {
  static const String _logTag = 'WindowsClipboardService';
  static const String _channelName =
      'com.yhsung.meeting_summarizer/windows_clipboard';

  // Platform channel for native Windows clipboard operations
  static const MethodChannel _platform = MethodChannel(_channelName);

  bool _isInitialized = false;
  bool _clipboardAccess = false;
  StreamController<String>? _clipboardMonitor;

  // Callbacks
  void Function(String content, ClipboardFormat format)? onClipboardChanged;

  /// Initialize Windows clipboard service
  Future<bool> initialize() async {
    try {
      if (!Platform.isWindows) {
        log('$_logTag: Clipboard service only available on Windows',
            name: _logTag);
        return false;
      }

      // Initialize platform channel
      await _initializePlatformChannel();

      // Check clipboard access permissions
      _clipboardAccess = await _checkClipboardAccess();

      if (_clipboardAccess) {
        _isInitialized = true;
        log('$_logTag: Windows clipboard service initialized', name: _logTag);
        return true;
      } else {
        log('$_logTag: Clipboard access not available', name: _logTag);
        return false;
      }
    } catch (e) {
      log('$_logTag: Failed to initialize Windows clipboard service: $e',
          name: _logTag);
      return false;
    }
  }

  /// Check if service is available
  bool get isAvailable => Platform.isWindows && _isInitialized;
  bool get hasClipboardAccess => _clipboardAccess;

  /// Initialize platform channel
  Future<void> _initializePlatformChannel() async {
    try {
      _platform.setMethodCallHandler(_handleNativeMethodCall);

      // Test connectivity
      final result = await _platform.invokeMethod<bool>('initialize') ?? false;
      if (!result) {
        log('$_logTag: Failed to initialize native clipboard channel',
            name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Platform channel initialization error: $e', name: _logTag);
    }
  }

  /// Handle method calls from native Windows code
  Future<void> _handleNativeMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onClipboardChanged':
          final content = call.arguments['content'] as String?;
          final format = call.arguments['format'] as String?;

          if (content != null && format != null) {
            final clipboardFormat = ClipboardFormat.values.firstWhere(
              (f) => f.mimeType == format,
              orElse: () => ClipboardFormat.text,
            );
            onClipboardChanged?.call(content, clipboardFormat);
          }
          break;

        default:
          log('$_logTag: Unknown native method call: ${call.method}',
              name: _logTag);
      }
    } catch (e) {
      log('$_logTag: Error handling native method call: $e', name: _logTag);
    }
  }

  /// Check clipboard access
  Future<bool> _checkClipboardAccess() async {
    try {
      final result = await _platform.invokeMethod<bool>('checkAccess') ?? false;
      log('$_logTag: Clipboard access: $result', name: _logTag);
      return result;
    } catch (e) {
      log('$_logTag: Failed to check clipboard access: $e', name: _logTag);
      return false;
    }
  }

  /// Copy text to clipboard
  Future<bool> copyText(String text) async {
    if (!isAvailable) return false;

    try {
      await flutter_services.Clipboard.setData(
          flutter_services.ClipboardData(text: text));
      log('$_logTag: Text copied to clipboard', name: _logTag);
      return true;
    } catch (e) {
      log('$_logTag: Failed to copy text to clipboard: $e', name: _logTag);
      return false;
    }
  }

  /// Copy rich content to clipboard
  Future<bool> copyRichContent(RichClipboardContent content) async {
    if (!isAvailable) return false;

    try {
      final result = await _platform.invokeMethod<bool>(
            'copyRichContent',
            content.toJson(),
          ) ??
          false;

      if (result) {
        log('$_logTag: Rich content copied to clipboard: ${content.title}',
            name: _logTag);
      }
      return result;
    } catch (e) {
      log('$_logTag: Failed to copy rich content to clipboard: $e',
          name: _logTag);
      return false;
    }
  }

  /// Copy transcript to clipboard with formatting options
  Future<bool> copyTranscript({
    required String transcript,
    required String title,
    TranscriptSharingOptions? options,
    Map<String, dynamic>? metadata,
  }) async {
    if (!isAvailable) return false;

    try {
      final sharingOptions = options ?? const TranscriptSharingOptions();

      // Format transcript based on options
      final formattedTranscript = _formatTranscript(
        transcript,
        sharingOptions,
        metadata,
      );

      // Create rich clipboard content with multiple formats
      final clipboardFormats = <WindowsClipboardData>[
        WindowsClipboardData(
          format: ClipboardFormat.text,
          data: _stripFormatting(formattedTranscript),
        ),
      ];

      if (sharingOptions.formatAsMarkdown) {
        clipboardFormats.add(WindowsClipboardData(
          format: ClipboardFormat.markdown,
          data: formattedTranscript,
        ));
      }

      // Add HTML format
      clipboardFormats.add(WindowsClipboardData(
        format: ClipboardFormat.html,
        data: _markdownToHtml(formattedTranscript),
      ));

      // Add JSON format with metadata
      if (sharingOptions.includeMetadata) {
        clipboardFormats.add(WindowsClipboardData(
          format: ClipboardFormat.json,
          data: _createJsonFormat(transcript, title, metadata, sharingOptions),
        ));
      }

      final richContent = RichClipboardContent(
        title: title,
        formats: clipboardFormats,
        timestamp: DateTime.now(),
      );

      return await copyRichContent(richContent);
    } catch (e) {
      log('$_logTag: Failed to copy transcript to clipboard: $e',
          name: _logTag);
      return false;
    }
  }

  /// Copy summary to clipboard
  Future<bool> copySummary({
    required String summary,
    required String title,
    Map<String, dynamic>? metadata,
  }) async {
    if (!isAvailable) return false;

    try {
      final formattedSummary = _formatSummary(summary, title, metadata);

      final clipboardFormats = [
        WindowsClipboardData(
          format: ClipboardFormat.text,
          data: _stripFormatting(formattedSummary),
        ),
        WindowsClipboardData(
          format: ClipboardFormat.markdown,
          data: formattedSummary,
        ),
        WindowsClipboardData(
          format: ClipboardFormat.html,
          data: _markdownToHtml(formattedSummary),
        ),
      ];

      final richContent = RichClipboardContent(
        title: 'Meeting Summary: $title',
        formats: clipboardFormats,
        timestamp: DateTime.now(),
      );

      return await copyRichContent(richContent);
    } catch (e) {
      log('$_logTag: Failed to copy summary to clipboard: $e', name: _logTag);
      return false;
    }
  }

  /// Copy recording information to clipboard
  Future<bool> copyRecordingInfo({
    required Map<String, dynamic> recordingInfo,
    bool includeTranscript = false,
  }) async {
    if (!isAvailable) return false;

    try {
      final formattedInfo =
          _formatRecordingInfo(recordingInfo, includeTranscript);

      final clipboardFormats = [
        WindowsClipboardData(
          format: ClipboardFormat.text,
          data: _stripFormatting(formattedInfo),
        ),
        WindowsClipboardData(
          format: ClipboardFormat.markdown,
          data: formattedInfo,
        ),
        WindowsClipboardData(
          format: ClipboardFormat.json,
          data: _jsonEncode(recordingInfo),
        ),
      ];

      final richContent = RichClipboardContent(
        title: 'Recording: ${recordingInfo['title'] ?? 'Unknown'}',
        formats: clipboardFormats,
        timestamp: DateTime.now(),
      );

      return await copyRichContent(richContent);
    } catch (e) {
      log('$_logTag: Failed to copy recording info to clipboard: $e',
          name: _logTag);
      return false;
    }
  }

  /// Get clipboard content
  Future<String?> getClipboardText() async {
    if (!isAvailable) return null;

    try {
      final clipboardData =
          await flutter_services.Clipboard.getData('text/plain');
      return clipboardData?.text;
    } catch (e) {
      log('$_logTag: Failed to get clipboard text: $e', name: _logTag);
      return null;
    }
  }

  /// Check if clipboard contains specific format
  Future<bool> hasFormat(ClipboardFormat format) async {
    if (!isAvailable) return false;

    try {
      final result = await _platform.invokeMethod<bool>(
            'hasFormat',
            {'format': format.mimeType},
          ) ??
          false;
      return result;
    } catch (e) {
      log('$_logTag: Failed to check clipboard format: $e', name: _logTag);
      return false;
    }
  }

  /// Start monitoring clipboard changes
  Future<void> startClipboardMonitoring() async {
    if (!isAvailable) return;

    try {
      await _platform.invokeMethod('startMonitoring');
      log('$_logTag: Clipboard monitoring started', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to start clipboard monitoring: $e', name: _logTag);
    }
  }

  /// Stop monitoring clipboard changes
  Future<void> stopClipboardMonitoring() async {
    if (!isAvailable) return;

    try {
      await _platform.invokeMethod('stopMonitoring');
      log('$_logTag: Clipboard monitoring stopped', name: _logTag);
    } catch (e) {
      log('$_logTag: Failed to stop clipboard monitoring: $e', name: _logTag);
    }
  }

  /// Format transcript with options
  String _formatTranscript(
    String transcript,
    TranscriptSharingOptions options,
    Map<String, dynamic>? metadata,
  ) {
    final buffer = StringBuffer();

    // Add header if metadata is included
    if (options.includeMetadata && metadata != null) {
      buffer.writeln('# Meeting Transcript');
      buffer.writeln();
      if (metadata['title'] != null) {
        buffer.writeln('**Title:** ${metadata['title']}');
      }
      if (metadata['date'] != null) {
        buffer.writeln('**Date:** ${metadata['date']}');
      }
      if (metadata['duration'] != null) {
        buffer.writeln('**Duration:** ${metadata['duration']}');
      }
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }

    // Add transcript content
    buffer.write(transcript);

    // Add footer if metadata is included
    if (options.includeMetadata) {
      buffer.writeln();
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln('*Generated by Meeting Summarizer*');
    }

    return buffer.toString();
  }

  /// Format summary for clipboard
  String _formatSummary(
    String summary,
    String title,
    Map<String, dynamic>? metadata,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('# Meeting Summary: $title');
    buffer.writeln();

    if (metadata != null) {
      if (metadata['date'] != null) {
        buffer.writeln('**Date:** ${metadata['date']}');
      }
      if (metadata['duration'] != null) {
        buffer.writeln('**Duration:** ${metadata['duration']}');
      }
      if (metadata['participants'] != null) {
        buffer.writeln('**Participants:** ${metadata['participants']}');
      }
      buffer.writeln();
    }

    buffer.writeln('## Summary');
    buffer.writeln();
    buffer.write(summary);

    buffer.writeln();
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('*Generated by Meeting Summarizer*');

    return buffer.toString();
  }

  /// Format recording information
  String _formatRecordingInfo(
    Map<String, dynamic> recordingInfo,
    bool includeTranscript,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('# Recording Information');
    buffer.writeln();

    recordingInfo.forEach((key, value) {
      if (key != 'transcript' || includeTranscript) {
        buffer.writeln('**${_capitalizeFirst(key)}:** $value');
      }
    });

    if (includeTranscript && recordingInfo['transcript'] != null) {
      buffer.writeln();
      buffer.writeln('## Transcript');
      buffer.writeln();
      buffer.write(recordingInfo['transcript']);
    }

    return buffer.toString();
  }

  /// Strip markdown formatting for plain text
  String _stripFormatting(String markdown) {
    return markdown
        .replaceAll(RegExp(r'[#*_`]'), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// Convert markdown to HTML
  String _markdownToHtml(String markdown) {
    // Basic markdown to HTML conversion
    return markdown
        .replaceAll(RegExp(r'^# (.+)$', multiLine: true), r'<h1>$1</h1>')
        .replaceAll(RegExp(r'^## (.+)$', multiLine: true), r'<h2>$1</h2>')
        .replaceAll(RegExp(r'^### (.+)$', multiLine: true), r'<h3>$1</h3>')
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'<strong>$1</strong>')
        .replaceAll(RegExp(r'\*(.+?)\*'), r'<em>$1</em>')
        .replaceAll(RegExp(r'`(.+?)`'), r'<code>$1</code>')
        .replaceAll('\n\n', '</p><p>')
        .replaceAll('\n', '<br>')
        .replaceAll('---', '<hr>')
        .replaceAll(RegExp(r'^(.+)$'), '<p>\$1</p>');
  }

  /// Create JSON format
  String _createJsonFormat(
    String transcript,
    String title,
    Map<String, dynamic>? metadata,
    TranscriptSharingOptions options,
  ) {
    final jsonData = {
      'title': title,
      'transcript': transcript,
      'metadata': metadata ?? {},
      'options': options.toJson(),
      'exportedAt': DateTime.now().toIso8601String(),
      'exportedBy': 'Meeting Summarizer',
    };

    return _jsonEncode(jsonData);
  }

  /// JSON encode helper
  String _jsonEncode(dynamic object) {
    // In a real implementation, use proper JSON encoding
    return object.toString();
  }

  /// Capitalize first letter
  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Get service status
  Map<String, dynamic> getServiceStatus() {
    return {
      'isAvailable': isAvailable,
      'hasClipboardAccess': hasClipboardAccess,
      'lastUpdate': DateTime.now().toIso8601String(),
    };
  }

  /// Dispose resources
  void dispose() {
    try {
      // Stop clipboard monitoring
      stopClipboardMonitoring();

      // Close clipboard monitor stream
      _clipboardMonitor?.close();
      _clipboardMonitor = null;

      // Clear callbacks
      onClipboardChanged = null;

      _isInitialized = false;
      log('$_logTag: Service disposed', name: _logTag);
    } catch (e) {
      log('$_logTag: Error disposing service: $e', name: _logTag);
    }
  }
}
