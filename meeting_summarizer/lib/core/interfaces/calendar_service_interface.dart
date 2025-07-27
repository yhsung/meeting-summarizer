import '../models/calendar/calendar_event.dart';
import '../models/calendar/meeting_context.dart';
import '../enums/calendar_provider.dart';

/// Abstract interface for calendar service implementations
abstract class CalendarServiceInterface {
  /// Calendar provider type
  CalendarProvider get provider;

  /// Whether the service is currently authenticated
  bool get isAuthenticated;

  /// Initialize the calendar service with configuration
  Future<void> initialize(Map<String, dynamic> config);

  /// Authenticate with the calendar provider
  Future<bool> authenticate();

  /// Disconnect and clear authentication
  Future<void> disconnect();

  /// Get calendar events for a date range
  Future<List<CalendarEvent>> getEvents({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? calendarIds,
  });

  /// Get events for today
  Future<List<CalendarEvent>> getTodaysEvents() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return getEvents(startDate: today, endDate: tomorrow);
  }

  /// Get upcoming events (next 7 days)
  Future<List<CalendarEvent>> getUpcomingEvents() {
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));

    return getEvents(startDate: now, endDate: weekFromNow);
  }

  /// Get a specific event by ID
  Future<CalendarEvent?> getEvent(String eventId);

  /// Search for events by query
  Future<List<CalendarEvent>> searchEvents({
    required String query,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Get available calendars
  Future<List<CalendarInfo>> getCalendars();

  /// Create a new calendar event
  Future<CalendarEvent> createEvent(CalendarEvent event);

  /// Update an existing calendar event
  Future<CalendarEvent> updateEvent(CalendarEvent event);

  /// Delete a calendar event
  Future<bool> deleteEvent(String eventId);

  /// Watch for calendar changes (if supported)
  Stream<CalendarChangeEvent>? watchCalendarChanges();

  /// Get calendar-specific configuration requirements
  Map<String, dynamic> getConfigurationRequirements();

  /// Validate configuration before initialization
  bool validateConfiguration(Map<String, dynamic> config);
}

/// Calendar information structure
class CalendarInfo {
  final String id;
  final String name;
  final String? description;
  final CalendarAccessRole accessRole;
  final bool isPrimary;
  final String? color;
  final String? timezone;

  const CalendarInfo({
    required this.id,
    required this.name,
    this.description,
    this.accessRole = CalendarAccessRole.reader,
    this.isPrimary = false,
    this.color,
    this.timezone,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'accessRole': accessRole.name,
        'isPrimary': isPrimary,
        'color': color,
        'timezone': timezone,
      };

  factory CalendarInfo.fromJson(Map<String, dynamic> json) => CalendarInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        accessRole: CalendarAccessRole.values.firstWhere(
          (role) => role.name == json['accessRole'],
          orElse: () => CalendarAccessRole.reader,
        ),
        isPrimary: json['isPrimary'] as bool? ?? false,
        color: json['color'] as String?,
        timezone: json['timezone'] as String?,
      );
}

/// Calendar change event for real-time updates
class CalendarChangeEvent {
  final CalendarChangeType type;
  final String eventId;
  final CalendarEvent? event;
  final DateTime timestamp;

  const CalendarChangeEvent({
    required this.type,
    required this.eventId,
    this.event,
    required this.timestamp,
  });
}

/// Types of calendar changes
enum CalendarChangeType {
  created,
  updated,
  deleted,
  moved,
}

/// Calendar access roles
enum CalendarAccessRole {
  none,
  freeBusyReader,
  reader,
  writer,
  owner,
}

/// Meeting detection service interface
abstract class MeetingDetectionServiceInterface {
  /// Detect meetings from calendar events
  Future<List<MeetingContext>> detectMeetings(List<CalendarEvent> events);

  /// Detect if a single event is a meeting
  Future<MeetingContext?> detectMeeting(CalendarEvent event);

  /// Configure meeting detection rules
  void configureMeetingRules(MeetingDetectionRules rules);

  /// Get current detection statistics
  MeetingDetectionStats getDetectionStats();
}

/// Meeting detection configuration
class MeetingDetectionRules {
  final double minimumConfidenceThreshold;
  final Duration minimumMeetingDuration;
  final Duration maximumMeetingDuration;
  final int minimumAttendeeCount;
  final List<String> meetingKeywords;
  final List<String> excludeKeywords;
  final bool requireAttendees;
  final bool detectVirtualMeetings;

  const MeetingDetectionRules({
    this.minimumConfidenceThreshold = 0.7,
    this.minimumMeetingDuration = const Duration(minutes: 15),
    this.maximumMeetingDuration = const Duration(hours: 8),
    this.minimumAttendeeCount = 1,
    this.meetingKeywords = const [
      'meeting',
      'call',
      'sync',
      'standup',
      'review',
      'planning',
      'interview',
      'demo',
      'presentation',
      'brainstorm',
      'retrospective'
    ],
    this.excludeKeywords = const [
      'lunch',
      'dinner',
      'vacation',
      'holiday',
      'birthday',
      'personal',
      'appointment',
      'break',
      'block'
    ],
    this.requireAttendees = true,
    this.detectVirtualMeetings = true,
  });
}

/// Meeting detection statistics
class MeetingDetectionStats {
  final int totalEventsProcessed;
  final int meetingsDetected;
  final double averageConfidence;
  final Map<MeetingType, int> meetingTypeDistribution;
  final DateTime lastProcessedAt;

  const MeetingDetectionStats({
    required this.totalEventsProcessed,
    required this.meetingsDetected,
    required this.averageConfidence,
    required this.meetingTypeDistribution,
    required this.lastProcessedAt,
  });

  double get detectionRate =>
      totalEventsProcessed > 0 ? meetingsDetected / totalEventsProcessed : 0.0;
}
