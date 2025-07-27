import 'dart:developer' as dev;
import 'dart:math';
import '../../interfaces/calendar_service_interface.dart';
import '../../models/calendar/calendar_event.dart';
import '../../models/calendar/meeting_context.dart';

/// Service for detecting meetings from calendar events
class MeetingDetectionService implements MeetingDetectionServiceInterface {
  MeetingDetectionRules _rules = const MeetingDetectionRules();
  MeetingDetectionStats _stats = MeetingDetectionStats(
    totalEventsProcessed: 0,
    meetingsDetected: 0,
    averageConfidence: 0.0,
    meetingTypeDistribution: {},
    lastProcessedAt: DateTime.now(),
  );

  @override
  Future<List<MeetingContext>> detectMeetings(
      List<CalendarEvent> events) async {
    dev.log(
        'MeetingDetectionService: Processing ${events.length} events for meeting detection');

    final meetings = <MeetingContext>[];
    int detectedCount = 0;
    double totalConfidence = 0.0;
    final typeDistribution = <MeetingType, int>{};

    for (final event in events) {
      final meetingContext = await detectMeeting(event);
      if (meetingContext != null) {
        meetings.add(meetingContext);
        detectedCount++;
        totalConfidence += meetingContext.detectionConfidence;

        final type = meetingContext.type;
        typeDistribution[type] = (typeDistribution[type] ?? 0) + 1;
      }
    }

    // Update statistics
    _stats = MeetingDetectionStats(
      totalEventsProcessed: _stats.totalEventsProcessed + events.length,
      meetingsDetected: _stats.meetingsDetected + detectedCount,
      averageConfidence:
          detectedCount > 0 ? totalConfidence / detectedCount : 0.0,
      meetingTypeDistribution: typeDistribution,
      lastProcessedAt: DateTime.now(),
    );

    dev.log(
        'MeetingDetectionService: Detected ${meetings.length} meetings from ${events.length} events');
    return meetings;
  }

  @override
  Future<MeetingContext?> detectMeeting(CalendarEvent event) async {
    try {
      final confidence = _calculateMeetingConfidence(event);

      if (confidence < _rules.minimumConfidenceThreshold) {
        return null;
      }

      // Extract meeting details
      final type = _detectMeetingType(event);
      final participants = _extractParticipants(event);
      final agendaItems = _extractAgendaItems(event);
      final tags = _extractTags(event);
      final priority = _determinePriority(event, participants.length);
      final virtualMeetingInfo = _extractVirtualMeetingInfo(event);
      final location = _extractMeetingLocation(event);
      final shouldAutoRecord = _shouldAutoRecord(event, confidence, type);

      final meetingContext = MeetingContext(
        event: event,
        type: type,
        participants: participants,
        agendaItems: agendaItems,
        tags: tags,
        expectedDuration: event.duration,
        priority: priority,
        shouldAutoRecord: shouldAutoRecord,
        virtualMeetingInfo: virtualMeetingInfo,
        location: location,
        detectionConfidence: confidence,
        extractedAt: DateTime.now(),
      );

      dev.log(
          'MeetingDetectionService: Detected meeting "${event.title}" with ${confidence.toStringAsFixed(2)} confidence');
      return meetingContext;
    } catch (e) {
      dev.log(
          'MeetingDetectionService: Error detecting meeting for event "${event.title}": $e');
      return null;
    }
  }

  @override
  void configureMeetingRules(MeetingDetectionRules rules) {
    _rules = rules;
    dev.log('MeetingDetectionService: Updated meeting detection rules');
  }

  @override
  MeetingDetectionStats getDetectionStats() {
    return _stats;
  }

  /// Calculate meeting confidence score (0.0 to 1.0)
  double _calculateMeetingConfidence(CalendarEvent event) {
    double confidence = 0.0;

    // Title analysis (40% weight)
    confidence += _analyzeTitle(event.title) * 0.4;

    // Duration analysis (20% weight)
    confidence += _analyzeDuration(event.duration) * 0.2;

    // Attendee analysis (25% weight)
    confidence += _analyzeAttendees(event.attendees) * 0.25;

    // Description analysis (10% weight)
    confidence += _analyzeDescription(event.description) * 0.1;

    // Virtual meeting indicators (5% weight)
    confidence += _analyzeVirtualMeetingIndicators(event) * 0.05;

    return min(1.0, max(0.0, confidence));
  }

  /// Analyze event title for meeting indicators
  double _analyzeTitle(String title) {
    final titleLower = title.toLowerCase();
    double score = 0.0;

    // Check for meeting keywords
    for (final keyword in _rules.meetingKeywords) {
      if (titleLower.contains(keyword.toLowerCase())) {
        score += 0.3;
        break;
      }
    }

    // Check for exclude keywords (negative score)
    for (final keyword in _rules.excludeKeywords) {
      if (titleLower.contains(keyword.toLowerCase())) {
        score -= 0.5;
        break;
      }
    }

    // Common meeting patterns
    if (RegExp(r'\b(sync|standup|retro|planning|review|demo)\b',
            caseSensitive: false)
        .hasMatch(title)) {
      score += 0.4;
    }

    // Project or team names pattern
    if (RegExp(r'\b(team|project|squad|group)\b', caseSensitive: false)
        .hasMatch(title)) {
      score += 0.2;
    }

    // 1:1 or one-on-one pattern
    if (RegExp(r'\b(1:1|one.?on.?one|1.?on.?1)\b', caseSensitive: false)
        .hasMatch(title)) {
      score += 0.3;
    }

    return min(1.0, max(0.0, score));
  }

  /// Analyze event duration for meeting patterns
  double _analyzeDuration(Duration duration) {
    final minutes = duration.inMinutes;

    // Very short events (< 15 min) are less likely to be meetings
    if (minutes < _rules.minimumMeetingDuration.inMinutes) {
      return 0.1;
    }

    // Very long events (> 4 hours) are less likely to be typical meetings
    if (minutes > _rules.maximumMeetingDuration.inMinutes) {
      return 0.3;
    }

    // Common meeting durations
    if ([15, 30, 60, 90].contains(minutes)) {
      return 0.8;
    }

    // Other reasonable durations
    if (minutes >= 15 && minutes <= 120) {
      return 0.6;
    }

    return 0.4;
  }

  /// Analyze attendees for meeting patterns
  double _analyzeAttendees(List<EventAttendee> attendees) {
    final attendeeCount = attendees.length;

    if (!_rules.requireAttendees) {
      return 0.5; // Neutral if attendees not required
    }

    if (attendeeCount < _rules.minimumAttendeeCount) {
      return 0.2;
    }

    // 1-on-1 meetings
    if (attendeeCount == 2) {
      return 0.8;
    }

    // Small team meetings
    if (attendeeCount >= 3 && attendeeCount <= 8) {
      return 0.9;
    }

    // Large meetings
    if (attendeeCount > 8 && attendeeCount <= 20) {
      return 0.7;
    }

    // Very large meetings (less typical)
    if (attendeeCount > 20) {
      return 0.5;
    }

    return 0.6;
  }

  /// Analyze event description for meeting indicators
  double _analyzeDescription(String? description) {
    if (description == null || description.isEmpty) {
      return 0.5; // Neutral
    }

    final descLower = description.toLowerCase();
    double score = 0.5;

    // Meeting agenda indicators
    if (RegExp(r'\b(agenda|discuss|review|update|planning)\b',
            caseSensitive: false)
        .hasMatch(description)) {
      score += 0.3;
    }

    // Action items or follow-up indicators
    if (RegExp(r'\b(action.?items?|follow.?up|next.?steps?)\b',
            caseSensitive: false)
        .hasMatch(description)) {
      score += 0.2;
    }

    // Meeting dial-in information
    if (RegExp(r'\b(dial.?in|phone|call|zoom|teams|meet)\b',
            caseSensitive: false)
        .hasMatch(description)) {
      score += 0.3;
    }

    return min(1.0, max(0.0, score));
  }

  /// Analyze virtual meeting indicators
  double _analyzeVirtualMeetingIndicators(CalendarEvent event) {
    if (!_rules.detectVirtualMeetings) {
      return 0.5;
    }

    double score = 0.0;

    // Check for virtual meeting URLs
    final description = event.description ?? '';
    final location = event.location ?? '';

    final virtualPatterns = [
      r'zoom\.us',
      r'teams\.microsoft\.com',
      r'meet\.google\.com',
      r'webex\.com',
      r'gotomeeting\.com',
      r'skype\.com',
    ];

    for (final pattern in virtualPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(description) ||
          RegExp(pattern, caseSensitive: false).hasMatch(location)) {
        score = 0.8;
        break;
      }
    }

    // Generic virtual meeting indicators
    if (RegExp(r'\b(virtual|online|remote|video.?call)\b', caseSensitive: false)
        .hasMatch(description + ' ' + location)) {
      score = max(score, 0.6);
    }

    return score;
  }

  /// Detect the type of meeting based on event data
  MeetingType _detectMeetingType(CalendarEvent event) {
    final title = event.title.toLowerCase();
    final description = (event.description ?? '').toLowerCase();
    final content = '$title $description';

    // 1:1 meetings
    if (RegExp(r'\b(1:1|one.?on.?one|1.?on.?1)\b').hasMatch(content)) {
      return MeetingType.oneOnOne;
    }

    // Standup meetings
    if (RegExp(r'\b(standup|stand.?up|daily|scrum)\b').hasMatch(content)) {
      return MeetingType.standup;
    }

    // Interview
    if (RegExp(r'\b(interview|candidate|hiring)\b').hasMatch(content)) {
      return MeetingType.interview;
    }

    // Presentation
    if (RegExp(r'\b(presentation|demo|showcase|pitch)\b').hasMatch(content)) {
      return MeetingType.presentation;
    }

    // Training
    if (RegExp(r'\b(training|workshop|learning|tutorial)\b')
        .hasMatch(content)) {
      return MeetingType.training;
    }

    // Brainstorming
    if (RegExp(r'\b(brainstorm|ideation|creative|innovation)\b')
        .hasMatch(content)) {
      return MeetingType.brainstorming;
    }

    // Retrospective
    if (RegExp(r'\b(retro|retrospective|postmortem|lessons.?learned)\b')
        .hasMatch(content)) {
      return MeetingType.retrospective;
    }

    // Planning
    if (RegExp(r'\b(planning|roadmap|strategy|sprint.?planning)\b')
        .hasMatch(content)) {
      return MeetingType.planning;
    }

    // Review
    if (RegExp(r'\b(review|feedback|evaluation|assessment)\b')
        .hasMatch(content)) {
      return MeetingType.review;
    }

    // Default to team meeting
    return MeetingType.teamMeeting;
  }

  /// Extract participants from event attendees
  List<MeetingParticipant> _extractParticipants(CalendarEvent event) {
    return event.attendees
        .map((attendee) => MeetingParticipant.fromAttendee(attendee))
        .toList();
  }

  /// Extract agenda items from event description
  List<String> _extractAgendaItems(CalendarEvent event) {
    final description = event.description;
    if (description == null || description.isEmpty) {
      return [];
    }

    final agendaItems = <String>[];

    // Look for numbered lists
    final numberedItems =
        RegExp(r'^\s*\d+\.?\s+(.+)$', multiLine: true).allMatches(description);
    for (final match in numberedItems) {
      agendaItems.add(match.group(1)?.trim() ?? '');
    }

    // Look for bulleted lists
    if (agendaItems.isEmpty) {
      final bulletedItems = RegExp(r'^\s*[•\-\*]\s+(.+)$', multiLine: true)
          .allMatches(description);
      for (final match in bulletedItems) {
        agendaItems.add(match.group(1)?.trim() ?? '');
      }
    }

    return agendaItems.where((item) => item.isNotEmpty).toList();
  }

  /// Extract tags from event title and description
  Set<String> _extractTags(CalendarEvent event) {
    final tags = <String>{};
    final content = '${event.title} ${event.description ?? ''}'.toLowerCase();

    // Project tags
    final projectMatches = RegExp(r'\[([^\]]+)\]').allMatches(content);
    for (final match in projectMatches) {
      tags.add(match.group(1)?.trim() ?? '');
    }

    // Hashtags
    final hashtagMatches = RegExp(r'#(\w+)').allMatches(content);
    for (final match in hashtagMatches) {
      tags.add(match.group(1)?.trim() ?? '');
    }

    // Common meeting categories
    final categories = [
      'urgent',
      'weekly',
      'monthly',
      'quarterly',
      'annual',
      'public',
      'private',
      'internal',
      'external',
      'client',
      'team',
      'all-hands',
      'leadership',
      'engineering',
      'design',
      'product',
      'marketing',
      'sales',
      'hr',
      'finance'
    ];

    for (final category in categories) {
      if (content.contains(category)) {
        tags.add(category);
      }
    }

    return tags;
  }

  /// Determine meeting priority based on various factors
  MeetingPriority _determinePriority(CalendarEvent event, int attendeeCount) {
    final title = event.title.toLowerCase();
    final description = (event.description ?? '').toLowerCase();
    final content = '$title $description';

    // Urgent indicators
    if (RegExp(r'\b(urgent|asap|emergency|critical|important)\b')
        .hasMatch(content)) {
      return MeetingPriority.urgent;
    }

    // High priority indicators
    if (RegExp(r'\b(high.?priority|ceo|vp|director|executive)\b')
            .hasMatch(content) ||
        attendeeCount > 15) {
      return MeetingPriority.high;
    }

    // Low priority indicators
    if (RegExp(r'\b(low.?priority|optional|fyi|info)\b').hasMatch(content) ||
        event.duration.inMinutes < 30) {
      return MeetingPriority.low;
    }

    return MeetingPriority.normal;
  }

  /// Extract virtual meeting information
  VirtualMeetingInfo? _extractVirtualMeetingInfo(CalendarEvent event) {
    final content = '${event.description ?? ''} ${event.location ?? ''}';

    // Zoom
    final zoomMatch =
        RegExp(r'zoom\.us/j/(\d+)', caseSensitive: false).firstMatch(content);
    if (zoomMatch != null) {
      return VirtualMeetingInfo(
        platform: VirtualPlatform.zoom,
        meetingId: zoomMatch.group(1) ?? '',
        joinUrl: zoomMatch.group(0) ?? '',
      );
    }

    // Google Meet
    final meetMatch =
        RegExp(r'meet\.google\.com/([a-z-]+)', caseSensitive: false)
            .firstMatch(content);
    if (meetMatch != null) {
      return VirtualMeetingInfo(
        platform: VirtualPlatform.meet,
        meetingId: meetMatch.group(1) ?? '',
        joinUrl: meetMatch.group(0) ?? '',
      );
    }

    // Microsoft Teams
    final teamsMatch = RegExp(r'teams\.microsoft\.com/.*', caseSensitive: false)
        .firstMatch(content);
    if (teamsMatch != null) {
      return VirtualMeetingInfo(
        platform: VirtualPlatform.teams,
        meetingId: 'teams-meeting',
        joinUrl: teamsMatch.group(0) ?? '',
      );
    }

    return null;
  }

  /// Extract meeting location information
  MeetingLocation? _extractMeetingLocation(CalendarEvent event) {
    final location = event.location;
    if (location == null || location.isEmpty) {
      return null;
    }

    // Virtual meeting location
    if (RegExp(r'\b(virtual|online|remote|zoom|teams|meet)\b',
            caseSensitive: false)
        .hasMatch(location)) {
      return MeetingLocation(
        name: location,
        type: LocationType.virtual,
      );
    }

    // Office/room pattern
    final roomMatch = RegExp(r'(.*?)\s*[-,]\s*(room|conference|meeting)\s+(.+)',
            caseSensitive: false)
        .firstMatch(location);
    if (roomMatch != null) {
      return MeetingLocation(
        name: location,
        building: roomMatch.group(1)?.trim(),
        room: roomMatch.group(3)?.trim(),
        type: LocationType.conference,
      );
    }

    return MeetingLocation(
      name: location,
      type: LocationType.office,
    );
  }

  /// Determine if meeting should auto-record
  bool _shouldAutoRecord(
      CalendarEvent event, double confidence, MeetingType type) {
    // High confidence meetings
    if (confidence >= 0.9) {
      return true;
    }

    // Specific meeting types that should be recorded
    const recordableTypes = {
      MeetingType.interview,
      MeetingType.presentation,
      MeetingType.training,
      MeetingType.review,
    };

    if (recordableTypes.contains(type)) {
      return true;
    }

    // Check for explicit recording requests
    final content = '${event.title} ${event.description ?? ''}'.toLowerCase();
    if (RegExp(r'\b(record|recording|transcript|notes)\b').hasMatch(content)) {
      return true;
    }

    return false;
  }
}
