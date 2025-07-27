import 'dart:developer';
import '../../models/calendar/calendar_event.dart';
import '../../models/calendar/meeting_context.dart';

/// Service for extracting detailed meeting context from calendar events
class MeetingContextExtractionService {
  /// Extract comprehensive meeting context from a calendar event
  Future<MeetingContext> extractMeetingContext(
    CalendarEvent event,
    double detectionConfidence,
  ) async {
    log('MeetingContextExtractionService: Extracting context for "${event.title}"');

    try {
      final participants = await _extractParticipants(event);
      final agendaItems = await _extractAgendaItems(event);
      final tags = await _extractTags(event);
      final type = await _detectMeetingType(event);
      final priority = await _determinePriority(event, participants);
      final virtualMeetingInfo = await _extractVirtualMeetingInfo(event);
      final location = await _extractMeetingLocation(event);
      final recordingPreferences = await _extractRecordingPreferences(event);
      final summaryDistribution =
          await _extractSummaryDistribution(event, participants);
      final preparationNotes = await _extractPreparationNotes(event);
      final previousMeetingIds = await _findPreviousMeetingReferences(event);

      final meetingContext = MeetingContext(
        event: event,
        type: type,
        participants: participants,
        agendaItems: agendaItems,
        tags: tags,
        expectedDuration: event.duration,
        preparationNotes: preparationNotes,
        previousMeetingIds: previousMeetingIds,
        priority: priority,
        shouldAutoRecord: _shouldAutoRecord(event, type, detectionConfidence),
        recordingPreferences: recordingPreferences,
        summaryDistribution: summaryDistribution,
        virtualMeetingInfo: virtualMeetingInfo,
        location: location,
        detectionConfidence: detectionConfidence,
        extractedAt: DateTime.now(),
      );

      log('MeetingContextExtractionService: Successfully extracted context for "${event.title}"');
      return meetingContext;
    } catch (e) {
      log('MeetingContextExtractionService: Error extracting context: $e');
      rethrow;
    }
  }

  /// Extract meeting participants with enhanced role detection
  Future<List<MeetingParticipant>> _extractParticipants(
      CalendarEvent event) async {
    final participants = <MeetingParticipant>[];

    for (final attendee in event.attendees) {
      final role = _determineParticipantRole(attendee, event);

      final participant = MeetingParticipant(
        name: attendee.name ?? _extractNameFromEmail(attendee.email ?? ''),
        email: attendee.email ?? '',
        role: role,
        isOptional: attendee.type == AttendeeType.optional,
        hasAccepted: attendee.status == AttendeeStatus.accepted,
      );

      participants.add(participant);
    }

    log('MeetingContextExtractionService: Extracted ${participants.length} participants');
    return participants;
  }

  /// Determine participant role based on event context
  ParticipantRole _determineParticipantRole(
      EventAttendee attendee, CalendarEvent event) {
    // Organizer role
    if (attendee.isOrganizer == true) {
      return ParticipantRole.organizer;
    }

    // Check for presenter indicators in name or email
    final name = (attendee.name ?? '').toLowerCase();
    final email = (attendee.email ?? '').toLowerCase();
    final title = event.title.toLowerCase();
    final description = (event.description ?? '').toLowerCase();

    // Presenter role indicators
    if (title.contains('presentation') || title.contains('demo')) {
      if (name.isNotEmpty && title.contains(name.split(' ').first)) {
        return ParticipantRole.presenter;
      }
    }

    // Check description for presenter mentions
    if (description.contains('presented by') ||
        description.contains('presenter:')) {
      if (name.isNotEmpty && description.contains(name)) {
        return ParticipantRole.presenter;
      }
    }

    // Optional attendees
    if (attendee.type == AttendeeType.optional) {
      return ParticipantRole.optional;
    }

    // Resource role (meeting rooms, equipment)
    if (email.contains('room') ||
        email.contains('resource') ||
        name.contains('room') ||
        name.contains('conference')) {
      return ParticipantRole.resource;
    }

    // Default to attendee
    return ParticipantRole.attendee;
  }

  /// Extract name from email address
  String _extractNameFromEmail(String email) {
    if (email.isEmpty) return '';

    final atIndex = email.indexOf('@');
    if (atIndex > 0) {
      final localPart = email.substring(0, atIndex);
      // Convert common patterns like "john.doe" to "John Doe"
      return localPart
          .split(RegExp(r'[._-]'))
          .map((part) =>
              part.isNotEmpty ? part[0].toUpperCase() + part.substring(1) : '')
          .join(' ');
    }

    return email;
  }

  /// Extract structured agenda items from event description
  Future<List<String>> _extractAgendaItems(CalendarEvent event) async {
    final description = event.description;
    if (description == null || description.isEmpty) {
      return [];
    }

    final agendaItems = <String>[];

    try {
      // Look for explicit agenda sections
      final agendaSection = _extractSectionContent(description, 'agenda');
      if (agendaSection.isNotEmpty) {
        agendaItems.addAll(_parseListItems(agendaSection));
      }

      // If no explicit agenda, look for structured content
      if (agendaItems.isEmpty) {
        // Numbered items
        final numberedMatches =
            RegExp(r'^\s*(\d+)[.)]\s*(.+)$', multiLine: true)
                .allMatches(description);
        for (final match in numberedMatches) {
          final item = match.group(2)?.trim();
          if (item != null && item.isNotEmpty) {
            agendaItems.add(item);
          }
        }

        // Bulleted items
        if (agendaItems.isEmpty) {
          final bulletMatches = RegExp(r'^\s*[•\-\*]\s*(.+)$', multiLine: true)
              .allMatches(description);
          for (final match in bulletMatches) {
            final item = match.group(1)?.trim();
            if (item != null && item.isNotEmpty) {
              agendaItems.add(item);
            }
          }
        }

        // Topic-based extraction
        if (agendaItems.isEmpty) {
          agendaItems.addAll(_extractTopicBasedAgenda(description));
        }
      }

      log('MeetingContextExtractionService: Extracted ${agendaItems.length} agenda items');
      return agendaItems;
    } catch (e) {
      log('MeetingContextExtractionService: Error extracting agenda items: $e');
      return [];
    }
  }

  /// Extract content from a specific section in description
  String _extractSectionContent(String description, String sectionName) {
    final sectionPattern = RegExp(
      '${sectionName}:?\\s*\\n([\\s\\S]*?)(?=\\n\\w+:|\\Z)',
      caseSensitive: false,
    );

    final match = sectionPattern.firstMatch(description);
    return match?.group(1)?.trim() ?? '';
  }

  /// Parse list items from text
  List<String> _parseListItems(String text) {
    final items = <String>[];

    // Split by lines and clean up
    final lines = text.split('\n');
    for (final line in lines) {
      final cleaned = line.trim();
      if (cleaned.isNotEmpty && !cleaned.startsWith('---')) {
        // Remove common list markers
        final item = cleaned.replaceFirst(RegExp(r'^[\d.)\-\*•]\s*'), '');
        if (item.isNotEmpty) {
          items.add(item);
        }
      }
    }

    return items;
  }

  /// Extract agenda items based on common topic patterns
  List<String> _extractTopicBasedAgenda(String description) {
    final items = <String>[];

    // Look for common meeting topics
    final topicPatterns = [
      r'discuss\s+(.+?)(?=\.|;|\n|$)',
      r'review\s+(.+?)(?=\.|;|\n|$)',
      r'update\s+on\s+(.+?)(?=\.|;|\n|$)',
      r'go\s+over\s+(.+?)(?=\.|;|\n|$)',
      r'talk\s+about\s+(.+?)(?=\.|;|\n|$)',
    ];

    for (final pattern in topicPatterns) {
      final matches =
          RegExp(pattern, caseSensitive: false).allMatches(description);
      for (final match in matches) {
        final topic = match.group(1)?.trim();
        if (topic != null && topic.isNotEmpty) {
          items.add('Discuss $topic');
        }
      }
    }

    return items;
  }

  /// Extract tags from various sources
  Future<Set<String>> _extractTags(CalendarEvent event) async {
    final tags = <String>{};
    final content = '${event.title} ${event.description ?? ''}'.toLowerCase();

    // Project tags in brackets
    final bracketMatches = RegExp(r'\[([^\]]+)\]').allMatches(content);
    for (final match in bracketMatches) {
      final tag = match.group(1)?.trim();
      if (tag != null && tag.isNotEmpty) {
        tags.add(tag);
      }
    }

    // Hashtags
    final hashtagMatches = RegExp(r'#(\w+)').allMatches(content);
    for (final match in hashtagMatches) {
      final tag = match.group(1)?.trim();
      if (tag != null && tag.isNotEmpty) {
        tags.add(tag);
      }
    }

    // Department/team tags
    final departments = [
      'engineering',
      'product',
      'design',
      'marketing',
      'sales',
      'hr',
      'finance',
      'legal',
      'operations',
      'support',
      'qa',
      'devops'
    ];

    for (final dept in departments) {
      if (content.contains(dept)) {
        tags.add(dept);
      }
    }

    // Meeting type tags
    final meetingTypes = [
      'standup',
      'retrospective',
      'planning',
      'review',
      'demo',
      'interview',
      'onboarding',
      'training',
      'brainstorm'
    ];

    for (final type in meetingTypes) {
      if (content.contains(type)) {
        tags.add(type);
      }
    }

    // Priority tags
    if (RegExp(r'\b(urgent|high.?priority|important)\b').hasMatch(content)) {
      tags.add('urgent');
    }

    if (RegExp(r'\b(quarterly|q[1-4])\b').hasMatch(content)) {
      tags.add('quarterly');
    }

    log('MeetingContextExtractionService: Extracted ${tags.length} tags');
    return tags;
  }

  /// Detect meeting type with enhanced logic
  Future<MeetingType> _detectMeetingType(CalendarEvent event) async {
    final title = event.title.toLowerCase();
    final description = (event.description ?? '').toLowerCase();
    final content = '$title $description';
    final attendeeCount = event.attendees.length;

    // 1:1 meetings
    if (RegExp(r'\b(1:1|one.?on.?one|1.?on.?1)\b').hasMatch(content) ||
        (attendeeCount == 2 && !content.contains('team'))) {
      return MeetingType.oneOnOne;
    }

    // Standup meetings
    if (RegExp(r'\b(standup|stand.?up|daily|scrum)\b').hasMatch(content)) {
      return MeetingType.standup;
    }

    // Interviews
    if (RegExp(r'\b(interview|candidate|hiring|screening)\b')
        .hasMatch(content)) {
      return MeetingType.interview;
    }

    // Presentations
    if (RegExp(r'\b(presentation|demo|showcase|pitch|show.?and.?tell)\b')
        .hasMatch(content)) {
      return MeetingType.presentation;
    }

    // Training
    if (RegExp(r'\b(training|workshop|learning|tutorial|onboarding)\b')
        .hasMatch(content)) {
      return MeetingType.training;
    }

    // Brainstorming
    if (RegExp(r'\b(brainstorm|ideation|creative|innovation|whiteboard)\b')
        .hasMatch(content)) {
      return MeetingType.brainstorming;
    }

    // Retrospectives
    if (RegExp(r'\b(retro|retrospective|postmortem|lessons.?learned)\b')
        .hasMatch(content)) {
      return MeetingType.retrospective;
    }

    // Planning
    if (RegExp(r'\b(planning|roadmap|strategy|sprint.?planning|milestone)\b')
        .hasMatch(content)) {
      return MeetingType.planning;
    }

    // Reviews
    if (RegExp(r'\b(review|feedback|evaluation|assessment|code.?review)\b')
        .hasMatch(content)) {
      return MeetingType.review;
    }

    // Default to team meeting for multi-person meetings
    return MeetingType.teamMeeting;
  }

  /// Determine meeting priority
  Future<MeetingPriority> _determinePriority(
    CalendarEvent event,
    List<MeetingParticipant> participants,
  ) async {
    final title = event.title.toLowerCase();
    final description = (event.description ?? '').toLowerCase();
    final content = '$title $description';

    // Urgent indicators
    if (RegExp(r'\b(urgent|asap|emergency|critical|immediate)\b')
        .hasMatch(content)) {
      return MeetingPriority.urgent;
    }

    // High priority indicators
    if (RegExp(r'\b(high.?priority|important|ceo|vp|director|executive|board)\b')
            .hasMatch(content) ||
        participants.length > 20 ||
        event.duration.inHours >= 2) {
      return MeetingPriority.high;
    }

    // Low priority indicators
    if (RegExp(r'\b(low.?priority|optional|fyi|info|social|coffee)\b')
            .hasMatch(content) ||
        event.duration.inMinutes <= 15) {
      return MeetingPriority.low;
    }

    return MeetingPriority.normal;
  }

  /// Extract virtual meeting information
  Future<VirtualMeetingInfo?> _extractVirtualMeetingInfo(
      CalendarEvent event) async {
    final content = '${event.description ?? ''} ${event.location ?? ''}';

    // Zoom meetings
    final zoomMatch = RegExp(r'zoom\.us/j/(\d+)(?:\?pwd=([A-Za-z0-9]+))?',
            caseSensitive: false)
        .firstMatch(content);
    if (zoomMatch != null) {
      return VirtualMeetingInfo(
        platform: VirtualPlatform.zoom,
        meetingId: zoomMatch.group(1) ?? '',
        joinUrl: 'https://${zoomMatch.group(0)}',
        password: zoomMatch.group(2),
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
        joinUrl: 'https://${meetMatch.group(0)}',
      );
    }

    // Microsoft Teams
    final teamsMatch = RegExp(r'teams\.microsoft\.com/l/meetup-join/[^\s]+',
            caseSensitive: false)
        .firstMatch(content);
    if (teamsMatch != null) {
      return VirtualMeetingInfo(
        platform: VirtualPlatform.teams,
        meetingId: 'teams-meeting',
        joinUrl: 'https://${teamsMatch.group(0)}',
      );
    }

    // WebEx
    final webexMatch =
        RegExp(r'([a-zA-Z0-9-]+\.webex\.com)/.*', caseSensitive: false)
            .firstMatch(content);
    if (webexMatch != null) {
      return VirtualMeetingInfo(
        platform: VirtualPlatform.webex,
        meetingId: 'webex-meeting',
        joinUrl: 'https://${webexMatch.group(0)}',
      );
    }

    return null;
  }

  /// Extract physical meeting location information
  Future<MeetingLocation?> _extractMeetingLocation(CalendarEvent event) async {
    final location = event.location;
    if (location == null || location.isEmpty) {
      return null;
    }

    // Virtual meeting indicators
    if (RegExp(r'\b(virtual|online|remote|zoom|teams|meet|webex)\b',
            caseSensitive: false)
        .hasMatch(location)) {
      return MeetingLocation(
        name: location,
        type: LocationType.virtual,
      );
    }

    // Conference room patterns
    final roomPatterns = [
      RegExp(r'(.+?)\s*[-,]\s*(?:room|conference|meeting)\s+(.+)',
          caseSensitive: false),
      RegExp(r'(?:room|conference|meeting)\s+(.+?)(?:\s*[-,]\s*(.+))?',
          caseSensitive: false),
      RegExp(r'(.+?)\s+building\s*[-,]\s*(.+)', caseSensitive: false),
    ];

    for (final pattern in roomPatterns) {
      final match = pattern.firstMatch(location);
      if (match != null) {
        return MeetingLocation(
          name: location,
          building: match.group(1)?.trim(),
          room: match.group(2)?.trim(),
          type: LocationType.conference,
        );
      }
    }

    // Address patterns (external locations)
    if (RegExp(r'\d+.*(?:street|st|avenue|ave|road|rd|drive|dr|boulevard|blvd)',
            caseSensitive: false)
        .hasMatch(location)) {
      return MeetingLocation(
        name: location,
        address: location,
        type: LocationType.external,
      );
    }

    // Default to office location
    return MeetingLocation(
      name: location,
      type: LocationType.office,
    );
  }

  /// Extract recording preferences from event content
  Future<RecordingPreferences?> _extractRecordingPreferences(
      CalendarEvent event) async {
    final content = '${event.title} ${event.description ?? ''}'.toLowerCase();

    // Check for explicit recording preferences
    final hasRecordingMention =
        RegExp(r'\b(record|recording|transcript)\b').hasMatch(content);

    if (!hasRecordingMention) {
      return null;
    }

    return RecordingPreferences(
      autoStart:
          RegExp(r'\b(auto.?record|automatically.?record)\b').hasMatch(content),
      autoStop: true, // Default to auto-stop
      recordAudio: true, // Always record audio
      recordVideo: RegExp(r'\b(video|camera|screen)\b').hasMatch(content),
      audioQuality: 'high',
      enhanceAudio: true,
    );
  }

  /// Extract summary distribution preferences
  Future<SummaryDistribution?> _extractSummaryDistribution(
    CalendarEvent event,
    List<MeetingParticipant> participants,
  ) async {
    final content = '${event.title} ${event.description ?? ''}'.toLowerCase();

    // Check for summary/notes sharing indicators
    final needsSummary =
        RegExp(r'\b(summary|notes|action.?items|follow.?up|share.?notes)\b')
            .hasMatch(content);

    if (!needsSummary) {
      return null;
    }

    // Default to sharing with all participants
    final recipients = participants
        .where((p) => p.email.isNotEmpty && p.role != ParticipantRole.resource)
        .map((p) => p.email)
        .toList();

    return SummaryDistribution(
      enabled: true,
      recipients: recipients,
      includeTranscript:
          !RegExp(r'\b(no.?transcript|summary.?only)\b').hasMatch(content),
      includeActionItems: true,
      deliveryMethod: 'email',
      delayAfterMeeting: const Duration(minutes: 15),
    );
  }

  /// Extract preparation notes
  Future<String?> _extractPreparationNotes(CalendarEvent event) async {
    final description = event.description;
    if (description == null || description.isEmpty) {
      return null;
    }

    // Look for preparation sections
    final prepSections = [
      'preparation',
      'prep',
      'before the meeting',
      'please review',
      'background',
      'context',
      'prerequisites'
    ];

    for (final section in prepSections) {
      final content = _extractSectionContent(description, section);
      if (content.isNotEmpty) {
        return content;
      }
    }

    return null;
  }

  /// Find references to previous meetings
  Future<List<String>> _findPreviousMeetingReferences(
      CalendarEvent event) async {
    final description = event.description ?? '';
    final previousMeetingIds = <String>[];

    // Look for meeting ID patterns
    final idPatterns = [
      RegExp(r'previous.?meeting:\s*([a-f0-9-]{36})', caseSensitive: false),
      RegExp(r'follow.?up.?to:\s*([a-f0-9-]{36})', caseSensitive: false),
      RegExp(r'continuation.?of:\s*([a-f0-9-]{36})', caseSensitive: false),
    ];

    for (final pattern in idPatterns) {
      final matches = pattern.allMatches(description);
      for (final match in matches) {
        final id = match.group(1);
        if (id != null && id.isNotEmpty) {
          previousMeetingIds.add(id);
        }
      }
    }

    return previousMeetingIds;
  }

  /// Determine if meeting should auto-record
  bool _shouldAutoRecord(
      CalendarEvent event, MeetingType type, double confidence) {
    // High confidence meetings
    if (confidence >= 0.9) {
      return true;
    }

    // Important meeting types
    const autoRecordTypes = {
      MeetingType.interview,
      MeetingType.presentation,
      MeetingType.training,
      MeetingType.review,
    };

    if (autoRecordTypes.contains(type)) {
      return true;
    }

    // Explicit recording requests
    final content = '${event.title} ${event.description ?? ''}'.toLowerCase();
    if (RegExp(r'\b(record|recording|transcript|notes)\b').hasMatch(content)) {
      return true;
    }

    return false;
  }
}
