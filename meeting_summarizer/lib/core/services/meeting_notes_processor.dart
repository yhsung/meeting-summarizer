/// Specialized processor for formal meeting notes with timestamp formatting
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../enums/summary_type.dart';
import '../models/summarization_configuration.dart';
import '../models/summarization_result.dart';
import '../exceptions/summarization_exceptions.dart';
import 'summary_type_processors.dart';

/// Processor specialized for formal meeting notes with timestamp formatting
class MeetingNotesProcessor extends SummaryTypeProcessor {
  static const Uuid _uuid = Uuid();

  @override
  bool canProcess(SummarizationConfiguration configuration) {
    return configuration.summaryType == SummaryType.meetingNotes;
  }

  @override
  int get priority => 15;

  @override
  Future<SummarizationResult> process({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
    required Future<String> Function(String prompt, String systemPrompt) aiCall,
    String? sessionId,
  }) async {
    final startTime = DateTime.now();

    try {
      // Extract timestamp information from transcription
      final timestampData = _extractTimestampData(transcriptionText);

      // Generate structured meeting notes
      final meetingNotes = await _generateMeetingNotes(
        transcriptionText,
        timestampData,
        configuration,
        aiCall,
      );

      // Format with proper meeting structure
      final formattedNotes = _formatMeetingNotes(
        meetingNotes,
        timestampData,
        configuration,
      );

      final processingTime = DateTime.now().difference(startTime);

      return SummarizationResult(
        id: _uuid.v4(),
        content: formattedNotes,
        summaryType: configuration.summaryType,
        actionItems: configuration.extractActionItems
            ? await _extractTimestampedActionItems(
                transcriptionText,
                timestampData,
                aiCall,
              )
            : [],
        keyDecisions: configuration.identifyDecisions
            ? await _extractTimestampedDecisions(
                transcriptionText,
                timestampData,
                aiCall,
              )
            : [],
        topics: configuration.extractTopics
            ? await _extractTimestampedTopics(
                transcriptionText,
                timestampData,
                aiCall,
              )
            : [],
        keyHighlights: _extractMeetingHighlights(formattedNotes),
        confidenceScore: _calculateMeetingNotesConfidence(
          formattedNotes,
          timestampData,
          transcriptionText,
        ),
        wordCount: formattedNotes.split(' ').length,
        characterCount: formattedNotes.length,
        processingTimeMs: processingTime.inMilliseconds,
        aiModel: 'processor-meeting-notes-v1.0',
        language: configuration.language,
        createdAt: DateTime.now(),
        sourceTranscriptionId: sessionId ?? _uuid.v4(),
        metadata: SummarizationMetadata(
          totalTokens:
              (transcriptionText.length / 4).ceil() +
              (formattedNotes.length / 4).ceil(),
          promptTokens: (transcriptionText.length / 4).ceil(),
          completionTokens: (formattedNotes.length / 4).ceil(),
          streamingUsed: false,
          additionalData: {
            'timestamp_count': timestampData.length,
            'meeting_duration': _calculateMeetingDuration(timestampData),
            'agenda_items': _extractAgendaItems(formattedNotes).length,
            'participant_count': _estimateParticipantCount(transcriptionText),
          },
        ),
      );
    } catch (e) {
      throw SummarizationExceptions.processingFailed(
        'Meeting notes processing failed: $e',
      );
    }
  }

  /// Extract timestamp information from transcription
  List<TimestampEntry> _extractTimestampData(String transcriptionText) {
    final timestamps = <TimestampEntry>[];
    final lines = transcriptionText.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Look for various timestamp formats
      final timestampMatch = _findTimestamp(line);
      if (timestampMatch != null) {
        timestamps.add(
          TimestampEntry(
            timestamp: timestampMatch.timestamp,
            content: timestampMatch.content,
            lineNumber: i,
            speaker: timestampMatch.speaker,
          ),
        );
      }
    }

    // If no explicit timestamps found, generate synthetic ones
    if (timestamps.isEmpty) {
      timestamps.addAll(_generateSyntheticTimestamps(transcriptionText));
    }

    return timestamps;
  }

  /// Find timestamp in line
  TimestampMatch? _findTimestamp(String line) {
    // Pattern for common timestamp formats
    final patterns = [
      // [HH:MM:SS] Speaker: content
      RegExp(r'^\[(\d{1,2}:\d{2}:\d{2})\]\s*([^:]+):\s*(.+)$'),
      // HH:MM:SS Speaker: content
      RegExp(r'^(\d{1,2}:\d{2}:\d{2})\s+([^:]+):\s*(.+)$'),
      // [HH:MM] Speaker: content
      RegExp(r'^\[(\d{1,2}:\d{2})\]\s*([^:]+):\s*(.+)$'),
      // HH:MM Speaker: content
      RegExp(r'^(\d{1,2}:\d{2})\s+([^:]+):\s*(.+)$'),
      // Speaker (HH:MM): content
      RegExp(r'^([^(]+)\s*\((\d{1,2}:\d{2})\):\s*(.+)$'),
      // At HH:MM, Speaker: content
      RegExp(r'^At\s+(\d{1,2}:\d{2}),\s*([^:]+):\s*(.+)$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(line);
      if (match != null) {
        String timeStr;
        String speaker;
        String content;

        if (pattern.pattern.contains(r'\((\d{1,2}:\d{2})\)')) {
          // Speaker (time) format
          speaker = match.group(1)!.trim();
          timeStr = match.group(2)!;
          content = match.group(3)!;
        } else if (pattern.pattern.startsWith(r'At\s+')) {
          // At time, Speaker format
          timeStr = match.group(1)!;
          speaker = match.group(2)!.trim();
          content = match.group(3)!;
        } else {
          // Standard time Speaker format
          timeStr = match.group(1)!;
          speaker = match.group(2)!.trim();
          content = match.group(3)!;
        }

        final timestamp = _parseTimeString(timeStr);
        if (timestamp != null) {
          return TimestampMatch(
            timestamp: timestamp,
            speaker: speaker,
            content: content,
          );
        }
      }
    }

    return null;
  }

  /// Parse time string to Duration
  Duration? _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        // HH:MM format
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        return Duration(hours: hours, minutes: minutes);
      } else if (parts.length == 3) {
        // HH:MM:SS format
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final seconds = int.parse(parts[2]);
        return Duration(hours: hours, minutes: minutes, seconds: seconds);
      }
    } catch (e) {
      debugPrint('MeetingNotesProcessor: Failed to parse time "$timeStr": $e');
    }
    return null;
  }

  /// Generate synthetic timestamps for text without explicit timestamps
  List<TimestampEntry> _generateSyntheticTimestamps(String transcriptionText) {
    final timestamps = <TimestampEntry>[];
    final lines = transcriptionText.split('\n');
    final speakerPattern = RegExp(r'^([A-Z][a-zA-Z\s]+):\s*(.+)$');

    Duration currentTime = const Duration(hours: 10); // Start at 10:00 AM
    const avgSpeakingDuration = Duration(
      minutes: 2,
    ); // Average 2 minutes per speaker turn

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final match = speakerPattern.firstMatch(line);
      if (match != null) {
        final speaker = match.group(1)!.trim();
        final content = match.group(2)!;

        timestamps.add(
          TimestampEntry(
            timestamp: currentTime,
            content: content,
            lineNumber: i,
            speaker: speaker,
          ),
        );

        // Increment time based on content length
        final wordCount = content.split(' ').length;
        final estimatedDuration = Duration(
          milliseconds: (wordCount * 0.5 * 1000)
              .round(), // ~0.5 seconds per word
        );
        currentTime = Duration(
          milliseconds:
              currentTime.inMilliseconds +
              estimatedDuration.inMilliseconds.clamp(
                avgSpeakingDuration.inMilliseconds ~/ 2,
                avgSpeakingDuration.inMilliseconds * 2,
              ),
        );
      }
    }

    return timestamps;
  }

  /// Generate formal meeting notes with AI assistance
  Future<String> _generateMeetingNotes(
    String transcriptionText,
    List<TimestampEntry> timestampData,
    SummarizationConfiguration configuration,
    Future<String> Function(String, String) aiCall,
  ) async {
    final timelineContext = timestampData.isNotEmpty
        ? _buildTimelineContext(timestampData)
        : 'No explicit timestamps found - using estimated chronology';

    const systemPrompt =
        '''You are an expert meeting secretary creating formal meeting notes. Focus on:
- Professional meeting documentation format
- Chronological organization with clear time markers
- Agenda items and discussion flow
- Participant contributions and roles
- Action items with assignments
- Decision points and rationale
- Follow-up items and next steps''';

    final prompt =
        '''Create formal meeting notes from the following transcription. Structure them as professional meeting minutes with:

1. Meeting header with date, time, participants
2. Agenda items in chronological order
3. Time-stamped discussion points
4. Clear attribution of comments to speakers
5. Decision points highlighted
6. Action items with assignments
7. Next steps and follow-up

TIMELINE CONTEXT:
$timelineContext

TRANSCRIPTION:
${transcriptionText.trim()}

Create comprehensive, professional meeting notes:''';

    return await aiCall(prompt, systemPrompt);
  }

  /// Build timeline context from timestamp data
  String _buildTimelineContext(List<TimestampEntry> timestampData) {
    final timeline = <String>[];

    for (final entry in timestampData.take(10)) {
      final timeStr = _formatDuration(entry.timestamp);
      final preview = entry.content.length > 50
          ? '${entry.content.substring(0, 50)}...'
          : entry.content;
      timeline.add('$timeStr - ${entry.speaker}: $preview');
    }

    return timeline.join('\n');
  }

  /// Format meeting notes with proper structure
  String _formatMeetingNotes(
    String notes,
    List<TimestampEntry> timestampData,
    SummarizationConfiguration configuration,
  ) {
    final sections = <String>[];
    final now = DateTime.now();

    // Meeting Header
    sections.add('# Meeting Notes');
    sections.add('');
    sections.add('**Date:** ${_formatDate(now)}');
    sections.add('**Time:** ${_formatMeetingTimeRange(timestampData)}');
    sections.add('**Duration:** ${_formatMeetingDuration(timestampData)}');

    if (timestampData.isNotEmpty) {
      final participants = _extractParticipants(timestampData);
      sections.add('**Participants:** ${participants.join(', ')}');
    }

    sections.add('');
    sections.add('---');
    sections.add('');

    // Process the AI-generated notes
    final processedNotes = _enhanceMeetingNotesStructure(notes, timestampData);
    sections.add(processedNotes);

    // Add timestamp reference if available
    if (timestampData.isNotEmpty && configuration.includeTimestamps) {
      sections.add('');
      sections.add('## Timeline Reference');
      sections.add('');

      for (final entry in timestampData.take(20)) {
        final timeStr = _formatDuration(entry.timestamp);
        sections.add('- **$timeStr** - ${entry.speaker}');
      }
    }

    return sections.join('\n');
  }

  /// Enhance notes structure with proper formatting
  String _enhanceMeetingNotesStructure(
    String notes,
    List<TimestampEntry> timestampData,
  ) {
    final lines = notes.split('\n');
    final enhancedLines = <String>[];

    for (final line in lines) {
      if (line.trim().isEmpty) {
        enhancedLines.add(line);
        continue;
      }

      // Enhance headers
      if (line.trim().startsWith('##')) {
        enhancedLines.add(line);
      } else if (_isAgendaItem(line)) {
        enhancedLines.add('## ${line.trim()}');
      } else if (_isActionItem(line)) {
        enhancedLines.add('**Action:** ${line.trim()}');
      } else if (_isDecisionPoint(line)) {
        enhancedLines.add('**Decision:** ${line.trim()}');
      } else {
        enhancedLines.add(line);
      }
    }

    return enhancedLines.join('\n');
  }

  /// Extract timestamped action items
  Future<List<ActionItem>> _extractTimestampedActionItems(
    String transcriptionText,
    List<TimestampEntry> timestampData,
    Future<String> Function(String, String) aiCall,
  ) async {
    try {
      final timelineContext = _buildTimelineContext(timestampData);

      final prompt =
          '''Extract action items from the meeting transcription with timestamp context.

TIMELINE:
$timelineContext

For each action item, identify:
- Task description
- Responsible person (if mentioned)
- Due date or timeline (if mentioned)
- When in the meeting it was discussed
- Priority level

TRANSCRIPTION:
$transcriptionText

Return action items with timeline context.''';

      const systemPrompt =
          'Extract action items with timeline and context information.';

      final response = await aiCall(prompt, systemPrompt);
      return _parseTimestampedActionItems(response, timestampData);
    } catch (e) {
      debugPrint('MeetingNotesProcessor: Action item extraction failed: $e');
      return [];
    }
  }

  /// Extract timestamped decisions
  Future<List<KeyDecision>> _extractTimestampedDecisions(
    String transcriptionText,
    List<TimestampEntry> timestampData,
    Future<String> Function(String, String) aiCall,
  ) async {
    try {
      final timelineContext = _buildTimelineContext(timestampData);

      final prompt =
          '''Extract key decisions from the meeting transcription with timestamp context.

TIMELINE:
$timelineContext

For each decision, identify:
- What was decided
- Who made the decision
- When in the meeting it occurred
- Rationale or context
- Business impact

TRANSCRIPTION:
$transcriptionText

Return decisions with timeline context.''';

      const systemPrompt =
          'Extract decisions with timeline and context information.';

      final response = await aiCall(prompt, systemPrompt);
      return _parseTimestampedDecisions(response, timestampData);
    } catch (e) {
      debugPrint('MeetingNotesProcessor: Decision extraction failed: $e');
      return [];
    }
  }

  /// Extract timestamped topics
  Future<List<TopicExtract>> _extractTimestampedTopics(
    String transcriptionText,
    List<TimestampEntry> timestampData,
    Future<String> Function(String, String) aiCall,
  ) async {
    try {
      final timelineContext = _buildTimelineContext(timestampData);

      final prompt =
          '''Extract discussion topics from the meeting transcription with timeline context.

TIMELINE:
$timelineContext

For each topic, identify:
- Topic name
- When it was discussed
- Key participants in the discussion
- Main points covered
- Duration of discussion

TRANSCRIPTION:
$transcriptionText

Return topics with timeline context.''';

      const systemPrompt =
          'Extract topics with timeline and discussion context.';

      final response = await aiCall(prompt, systemPrompt);
      return _parseTimestampedTopics(response, timestampData);
    } catch (e) {
      debugPrint('MeetingNotesProcessor: Topic extraction failed: $e');
      return [];
    }
  }

  /// Extract meeting highlights
  List<String> _extractMeetingHighlights(String notes) {
    final highlights = <String>[];
    final lines = notes.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty &&
          (trimmed.startsWith('**Decision:**') ||
              trimmed.startsWith('**Action:**') ||
              trimmed.contains('important') ||
              trimmed.contains('critical') ||
              trimmed.contains('unanimous') ||
              trimmed.contains('approved'))) {
        final cleaned = trimmed
            .replaceAll('**Decision:**', '')
            .replaceAll('**Action:**', '')
            .trim();

        if (cleaned.length > 20) {
          highlights.add(cleaned);
        }
      }
    }

    return highlights.take(8).toList();
  }

  /// Calculate meeting notes confidence score
  double _calculateMeetingNotesConfidence(
    String notes,
    List<TimestampEntry> timestampData,
    String originalText,
  ) {
    if (notes.isEmpty) return 0.0;

    double score = 0.7;

    // Structure quality
    final hasHeader = notes.contains('# Meeting Notes');
    final hasTimeline =
        notes.contains('Timeline') || notes.contains('**Time:**');
    final hasDecisions = notes.contains('**Decision:**');
    final hasActions = notes.contains('**Action:**');

    if (hasHeader) score += 0.05;
    if (hasTimeline) score += 0.05;
    if (hasDecisions) score += 0.05;
    if (hasActions) score += 0.05;

    // Timestamp integration
    if (timestampData.isNotEmpty) {
      score += 0.1;
    }

    // Content completeness
    final wordRatio = notes.split(' ').length / originalText.split(' ').length;
    if (wordRatio > 0.3 && wordRatio < 0.8) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Helper methods for formatting and analysis

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String _formatMeetingTimeRange(List<TimestampEntry> timestampData) {
    if (timestampData.isEmpty) return 'Time not specified';

    final startTime = timestampData.first.timestamp;
    final endTime = timestampData.last.timestamp;

    return '${_formatDuration(startTime)} - ${_formatDuration(endTime)}';
  }

  String _formatMeetingDuration(List<TimestampEntry> timestampData) {
    if (timestampData.length < 2) return 'Duration not available';

    final duration =
        timestampData.last.timestamp - timestampData.first.timestamp;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  int _calculateMeetingDuration(List<TimestampEntry> timestampData) {
    if (timestampData.length < 2) return 0;
    return timestampData.last.timestamp.inMinutes -
        timestampData.first.timestamp.inMinutes;
  }

  List<String> _extractParticipants(List<TimestampEntry> timestampData) {
    final participants = <String>{};

    for (final entry in timestampData) {
      if (entry.speaker.isNotEmpty) {
        participants.add(entry.speaker);
      }
    }

    return participants.toList()..sort();
  }

  List<String> _extractAgendaItems(String notes) {
    final agendaItems = <String>[];
    final lines = notes.split('\n');

    for (final line in lines) {
      if (line.startsWith('## ') &&
          !line.contains('Meeting Notes') &&
          !line.contains('Timeline')) {
        agendaItems.add(line.substring(3).trim());
      }
    }

    return agendaItems;
  }

  int _estimateParticipantCount(String transcriptionText) {
    final speakerPattern = RegExp(r'^([A-Z][a-zA-Z\s]+):', multiLine: true);
    final speakers = <String>{};

    for (final match in speakerPattern.allMatches(transcriptionText)) {
      speakers.add(match.group(1)!.trim());
    }

    return speakers.length;
  }

  bool _isAgendaItem(String line) {
    final agendaKeywords = ['agenda', 'item', 'topic', 'discussion', 'review'];
    final lower = line.toLowerCase();
    return agendaKeywords.any((keyword) => lower.contains(keyword)) &&
        !line.startsWith('##');
  }

  bool _isActionItem(String line) {
    final actionKeywords = ['action', 'todo', 'task', 'assign', 'follow-up'];
    final lower = line.toLowerCase();
    return actionKeywords.any((keyword) => lower.contains(keyword));
  }

  bool _isDecisionPoint(String line) {
    final decisionKeywords = [
      'decision',
      'decided',
      'approved',
      'agreed',
      'concluded',
    ];
    final lower = line.toLowerCase();
    return decisionKeywords.any((keyword) => lower.contains(keyword));
  }

  /// Parse timestamped action items from AI response
  List<ActionItem> _parseTimestampedActionItems(
    String response,
    List<TimestampEntry> timestampData,
  ) {
    final items = <ActionItem>[];
    final lines = response.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty || !_isActionItem(line)) continue;

      final description = line.trim().replaceAll(RegExp(r'^[-•*]\s*'), '');

      // Try to find associated timestamp
      Duration? associatedTimestamp;
      for (final timestamp in timestampData) {
        if (description.toLowerCase().contains(
              timestamp.speaker.toLowerCase(),
            ) ||
            timestamp.content.toLowerCase().contains(
              description.toLowerCase().split(' ').first,
            )) {
          associatedTimestamp = timestamp.timestamp;
          break;
        }
      }

      items.add(
        ActionItem(
          id: _uuid.v4(),
          description: description,
          timestamp: associatedTimestamp,
          priority: 'medium',
          confidence: 0.8,
        ),
      );
    }

    return items.take(10).toList();
  }

  /// Parse timestamped decisions from AI response
  List<KeyDecision> _parseTimestampedDecisions(
    String response,
    List<TimestampEntry> timestampData,
  ) {
    final decisions = <KeyDecision>[];
    final lines = response.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty || !_isDecisionPoint(line)) continue;

      final description = line.trim().replaceAll(RegExp(r'^[-•*]\s*'), '');

      // Try to find associated timestamp
      Duration? associatedTimestamp;
      for (final timestamp in timestampData) {
        if (description.toLowerCase().contains(
              timestamp.speaker.toLowerCase(),
            ) ||
            timestamp.content.toLowerCase().contains(
              description.toLowerCase().split(' ').first,
            )) {
          associatedTimestamp = timestamp.timestamp;
          break;
        }
      }

      decisions.add(
        KeyDecision(
          id: _uuid.v4(),
          description: description,
          timestamp: associatedTimestamp,
          confidence: 0.8,
        ),
      );
    }

    return decisions.take(8).toList();
  }

  /// Parse timestamped topics from AI response
  List<TopicExtract> _parseTimestampedTopics(
    String response,
    List<TimestampEntry> timestampData,
  ) {
    final topics = <TopicExtract>[];
    final lines = response.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty || !line.contains('-')) continue;

      final parts = line.split('-');
      if (parts.length < 2) continue;

      final topicName = parts[1].trim();

      // Estimate discussion duration
      Duration discussionDuration = const Duration(minutes: 5);
      final relevantTimestamps = timestampData
          .where(
            (t) =>
                t.content.toLowerCase().contains(topicName.toLowerCase()) ||
                topicName.toLowerCase().contains(t.speaker.toLowerCase()),
          )
          .toList();

      if (relevantTimestamps.length > 1) {
        discussionDuration =
            relevantTimestamps.last.timestamp -
            relevantTimestamps.first.timestamp;
      }

      topics.add(
        TopicExtract(
          topic: topicName,
          relevance: 0.7,
          keywords: topicName.split(' ').take(3).toList(),
          description: 'Meeting discussion topic',
          discussionDuration: discussionDuration,
        ),
      );
    }

    return topics.take(6).toList();
  }
}

/// Data classes for timestamp handling

class TimestampEntry {
  final Duration timestamp;
  final String content;
  final int lineNumber;
  final String speaker;

  const TimestampEntry({
    required this.timestamp,
    required this.content,
    required this.lineNumber,
    required this.speaker,
  });
}

class TimestampMatch {
  final Duration timestamp;
  final String speaker;
  final String content;

  const TimestampMatch({
    required this.timestamp,
    required this.speaker,
    required this.content,
  });
}
