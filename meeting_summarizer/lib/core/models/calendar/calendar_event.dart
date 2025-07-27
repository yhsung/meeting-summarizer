import 'package:json_annotation/json_annotation.dart';
import '../../enums/calendar_provider.dart';

part 'calendar_event.g.dart';

/// Represents a calendar event with normalized data across providers
@JsonSerializable()
class CalendarEvent {
  /// Unique identifier for the event
  final String id;

  /// Event title/summary
  final String title;

  /// Event description/body
  final String? description;

  /// Event start date and time
  final DateTime startTime;

  /// Event end date and time
  final DateTime endTime;

  /// Event location (physical or virtual)
  final String? location;

  /// Event organizer information
  final EventOrganizer? organizer;

  /// List of event attendees
  final List<EventAttendee> attendees;

  /// Calendar provider this event comes from
  final CalendarProvider provider;

  /// Whether this event is an all-day event
  final bool isAllDay;

  /// Recurrence rule for recurring events
  final String? recurrenceRule;

  /// Whether this event has been identified as a meeting
  final bool isMeeting;

  /// Meeting confidence score (0.0 to 1.0)
  final double meetingConfidence;

  /// Virtual meeting URL if available
  final String? meetingUrl;

  /// Event status (confirmed, tentative, cancelled)
  final EventStatus status;

  /// Event timezone
  final String timezone;

  /// Additional metadata from the provider
  final Map<String, dynamic>? metadata;

  /// Timestamp when this event was last updated
  final DateTime? lastModified;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    this.organizer,
    this.attendees = const [],
    required this.provider,
    this.isAllDay = false,
    this.recurrenceRule,
    this.isMeeting = false,
    this.meetingConfidence = 0.0,
    this.meetingUrl,
    this.status = EventStatus.confirmed,
    this.timezone = 'UTC',
    this.metadata,
    this.lastModified,
  });

  /// Create CalendarEvent from JSON
  factory CalendarEvent.fromJson(Map<String, dynamic> json) =>
      _$CalendarEventFromJson(json);

  /// Convert CalendarEvent to JSON
  Map<String, dynamic> toJson() => _$CalendarEventToJson(this);

  /// Duration of the event
  Duration get duration => endTime.difference(startTime);

  /// Whether this event is currently active
  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startTime) && now.isBefore(endTime);
  }

  /// Whether this event is in the future
  bool get isFuture => DateTime.now().isBefore(startTime);

  /// Whether this event is in the past
  bool get isPast => DateTime.now().isAfter(endTime);

  /// Create a copy with modified fields
  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    EventOrganizer? organizer,
    List<EventAttendee>? attendees,
    CalendarProvider? provider,
    bool? isAllDay,
    String? recurrenceRule,
    bool? isMeeting,
    double? meetingConfidence,
    String? meetingUrl,
    EventStatus? status,
    String? timezone,
    Map<String, dynamic>? metadata,
    DateTime? lastModified,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      organizer: organizer ?? this.organizer,
      attendees: attendees ?? this.attendees,
      provider: provider ?? this.provider,
      isAllDay: isAllDay ?? this.isAllDay,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      isMeeting: isMeeting ?? this.isMeeting,
      meetingConfidence: meetingConfidence ?? this.meetingConfidence,
      meetingUrl: meetingUrl ?? this.meetingUrl,
      status: status ?? this.status,
      timezone: timezone ?? this.timezone,
      metadata: metadata ?? this.metadata,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEvent &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          provider == other.provider;

  @override
  int get hashCode => id.hashCode ^ provider.hashCode;

  @override
  String toString() =>
      'CalendarEvent(id: $id, title: $title, provider: $provider)';
}

/// Event organizer information
@JsonSerializable()
class EventOrganizer {
  final String? name;
  final String? email;
  final bool? isCurrentUser;

  const EventOrganizer({
    this.name,
    this.email,
    this.isCurrentUser,
  });

  factory EventOrganizer.fromJson(Map<String, dynamic> json) =>
      _$EventOrganizerFromJson(json);

  Map<String, dynamic> toJson() => _$EventOrganizerToJson(this);

  @override
  String toString() => 'EventOrganizer(name: $name, email: $email)';
}

/// Event attendee information
@JsonSerializable()
class EventAttendee {
  final String? name;
  final String? email;
  final AttendeeStatus status;
  final AttendeeType type;
  final bool? isOrganizer;
  final bool? isCurrentUser;

  const EventAttendee({
    this.name,
    this.email,
    this.status = AttendeeStatus.needsAction,
    this.type = AttendeeType.required,
    this.isOrganizer = false,
    this.isCurrentUser = false,
  });

  factory EventAttendee.fromJson(Map<String, dynamic> json) =>
      _$EventAttendeeFromJson(json);

  Map<String, dynamic> toJson() => _$EventAttendeeToJson(this);

  @override
  String toString() =>
      'EventAttendee(name: $name, email: $email, status: $status)';
}

/// Event status enumeration
enum EventStatus {
  confirmed,
  tentative,
  cancelled,
}

/// Attendee response status
enum AttendeeStatus {
  needsAction,
  accepted,
  declined,
  tentative,
}

/// Attendee type
enum AttendeeType {
  required,
  optional,
  resource,
}
