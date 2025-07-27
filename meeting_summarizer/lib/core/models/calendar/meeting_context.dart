import 'package:json_annotation/json_annotation.dart';
import 'calendar_event.dart';

part 'meeting_context.g.dart';

/// Extracted meeting context from calendar events
@JsonSerializable()
class MeetingContext {
  /// Associated calendar event
  final CalendarEvent event;

  /// Extracted meeting type
  final MeetingType type;

  /// Meeting participants with roles
  final List<MeetingParticipant> participants;

  /// Extracted agenda items
  final List<String> agendaItems;

  /// Meeting tags extracted from title/description
  final Set<String> tags;

  /// Expected meeting duration
  final Duration expectedDuration;

  /// Meeting preparation notes
  final String? preparationNotes;

  /// Previous meeting references
  final List<String> previousMeetingIds;

  /// Meeting priority level
  final MeetingPriority priority;

  /// Whether automatic recording should be triggered
  final bool shouldAutoRecord;

  /// Recording preferences for this meeting
  final RecordingPreferences? recordingPreferences;

  /// Summary distribution settings
  final SummaryDistribution? summaryDistribution;

  /// Extracted virtual meeting information
  final VirtualMeetingInfo? virtualMeetingInfo;

  /// Meeting room or location details
  final MeetingLocation? location;

  /// Confidence score for meeting detection (0.0 to 1.0)
  final double detectionConfidence;

  /// Timestamp when context was extracted
  final DateTime extractedAt;

  const MeetingContext({
    required this.event,
    required this.type,
    this.participants = const [],
    this.agendaItems = const [],
    this.tags = const {},
    required this.expectedDuration,
    this.preparationNotes,
    this.previousMeetingIds = const [],
    this.priority = MeetingPriority.normal,
    this.shouldAutoRecord = false,
    this.recordingPreferences,
    this.summaryDistribution,
    this.virtualMeetingInfo,
    this.location,
    this.detectionConfidence = 0.0,
    required this.extractedAt,
  });

  /// Create MeetingContext from JSON
  factory MeetingContext.fromJson(Map<String, dynamic> json) =>
      _$MeetingContextFromJson(json);

  /// Convert MeetingContext to JSON
  Map<String, dynamic> toJson() => _$MeetingContextToJson(this);

  /// Whether this is a high-confidence meeting detection
  bool get isHighConfidence => detectionConfidence >= 0.8;

  /// Whether this meeting is recurring
  bool get isRecurring => event.recurrenceRule != null;

  /// Number of attendees
  int get attendeeCount => participants.length;

  /// Whether this is a large meeting (>10 attendees)
  bool get isLargeMeeting => attendeeCount > 10;

  /// Get attendees by email for distribution
  List<String> get attendeeEmails =>
      participants.map((p) => p.email).where((e) => e.isNotEmpty).toList();

  /// Create a copy with modified fields
  MeetingContext copyWith({
    CalendarEvent? event,
    MeetingType? type,
    List<MeetingParticipant>? participants,
    List<String>? agendaItems,
    Set<String>? tags,
    Duration? expectedDuration,
    String? preparationNotes,
    List<String>? previousMeetingIds,
    MeetingPriority? priority,
    bool? shouldAutoRecord,
    RecordingPreferences? recordingPreferences,
    SummaryDistribution? summaryDistribution,
    VirtualMeetingInfo? virtualMeetingInfo,
    MeetingLocation? location,
    double? detectionConfidence,
    DateTime? extractedAt,
  }) {
    return MeetingContext(
      event: event ?? this.event,
      type: type ?? this.type,
      participants: participants ?? this.participants,
      agendaItems: agendaItems ?? this.agendaItems,
      tags: tags ?? this.tags,
      expectedDuration: expectedDuration ?? this.expectedDuration,
      preparationNotes: preparationNotes ?? this.preparationNotes,
      previousMeetingIds: previousMeetingIds ?? this.previousMeetingIds,
      priority: priority ?? this.priority,
      shouldAutoRecord: shouldAutoRecord ?? this.shouldAutoRecord,
      recordingPreferences: recordingPreferences ?? this.recordingPreferences,
      summaryDistribution: summaryDistribution ?? this.summaryDistribution,
      virtualMeetingInfo: virtualMeetingInfo ?? this.virtualMeetingInfo,
      location: location ?? this.location,
      detectionConfidence: detectionConfidence ?? this.detectionConfidence,
      extractedAt: extractedAt ?? this.extractedAt,
    );
  }

  @override
  String toString() => 'MeetingContext(event: ${event.title}, type: $type)';
}

/// Meeting participant with role information
@JsonSerializable()
class MeetingParticipant {
  final String name;
  final String email;
  final ParticipantRole role;
  final bool isOptional;
  final bool hasAccepted;

  const MeetingParticipant({
    required this.name,
    required this.email,
    this.role = ParticipantRole.attendee,
    this.isOptional = false,
    this.hasAccepted = false,
  });

  factory MeetingParticipant.fromJson(Map<String, dynamic> json) =>
      _$MeetingParticipantFromJson(json);

  Map<String, dynamic> toJson() => _$MeetingParticipantToJson(this);

  /// Create from EventAttendee
  factory MeetingParticipant.fromAttendee(EventAttendee attendee) {
    return MeetingParticipant(
      name: attendee.name ?? '',
      email: attendee.email ?? '',
      role: attendee.isOrganizer == true
          ? ParticipantRole.organizer
          : ParticipantRole.attendee,
      isOptional: attendee.type == AttendeeType.optional,
      hasAccepted: attendee.status == AttendeeStatus.accepted,
    );
  }
}

/// Virtual meeting platform information
@JsonSerializable()
class VirtualMeetingInfo {
  final VirtualPlatform platform;
  final String meetingId;
  final String joinUrl;
  final String? dialInNumber;
  final String? accessCode;
  final String? password;

  const VirtualMeetingInfo({
    required this.platform,
    required this.meetingId,
    required this.joinUrl,
    this.dialInNumber,
    this.accessCode,
    this.password,
  });

  factory VirtualMeetingInfo.fromJson(Map<String, dynamic> json) =>
      _$VirtualMeetingInfoFromJson(json);

  Map<String, dynamic> toJson() => _$VirtualMeetingInfoToJson(this);
}

/// Physical meeting location information
@JsonSerializable()
class MeetingLocation {
  final String name;
  final String? address;
  final String? building;
  final String? room;
  final String? floor;
  final LocationType type;

  const MeetingLocation({
    required this.name,
    this.address,
    this.building,
    this.room,
    this.floor,
    this.type = LocationType.office,
  });

  factory MeetingLocation.fromJson(Map<String, dynamic> json) =>
      _$MeetingLocationFromJson(json);

  Map<String, dynamic> toJson() => _$MeetingLocationToJson(this);
}

/// Recording preferences for a meeting
@JsonSerializable()
class RecordingPreferences {
  final bool autoStart;
  final bool autoStop;
  final bool recordAudio;
  final bool recordVideo;
  final String audioQuality;
  final bool enhanceAudio;

  const RecordingPreferences({
    this.autoStart = false,
    this.autoStop = false,
    this.recordAudio = true,
    this.recordVideo = false,
    this.audioQuality = 'high',
    this.enhanceAudio = true,
  });

  factory RecordingPreferences.fromJson(Map<String, dynamic> json) =>
      _$RecordingPreferencesFromJson(json);

  Map<String, dynamic> toJson() => _$RecordingPreferencesToJson(this);
}

/// Summary distribution configuration
@JsonSerializable()
class SummaryDistribution {
  final bool enabled;
  final List<String> recipients;
  final bool includeTranscript;
  final bool includeActionItems;
  final String deliveryMethod;
  final Duration delayAfterMeeting;

  const SummaryDistribution({
    this.enabled = false,
    this.recipients = const [],
    this.includeTranscript = true,
    this.includeActionItems = true,
    this.deliveryMethod = 'email',
    this.delayAfterMeeting = const Duration(minutes: 15),
  });

  factory SummaryDistribution.fromJson(Map<String, dynamic> json) =>
      _$SummaryDistributionFromJson(json);

  Map<String, dynamic> toJson() => _$SummaryDistributionToJson(this);
}

/// Meeting type enumeration
enum MeetingType {
  standup,
  oneOnOne,
  teamMeeting,
  presentation,
  interview,
  training,
  brainstorming,
  retrospective,
  planning,
  review,
  other,
}

/// Meeting priority levels
enum MeetingPriority {
  low,
  normal,
  high,
  urgent,
}

/// Participant roles in meetings
enum ParticipantRole {
  organizer,
  presenter,
  attendee,
  optional,
  resource,
}

/// Virtual meeting platforms
enum VirtualPlatform {
  zoom,
  teams,
  meet,
  webex,
  skype,
  other,
}

/// Meeting location types
enum LocationType {
  office,
  conference,
  home,
  external,
  virtual,
}
