import 'dart:developer';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;
import '../../interfaces/calendar_service_interface.dart';
import '../../models/calendar/calendar_event.dart';
import '../../enums/calendar_provider.dart';
import 'oauth2_auth_manager.dart';

/// Google Calendar service implementation
class GoogleCalendarService implements CalendarServiceInterface {
  final OAuth2AuthManager _authManager;
  calendar.CalendarApi? _calendarApi;
  Map<String, dynamic> _config = {};

  GoogleCalendarService(this._authManager);

  @override
  CalendarProvider get provider => CalendarProvider.googleCalendar;

  @override
  bool get isAuthenticated => _authManager.isAuthenticated(provider);

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    _config = Map.from(config);

    if (!validateConfiguration(config)) {
      throw ArgumentError('Invalid Google Calendar configuration');
    }

    log('GoogleCalendarService: Initialized with configuration');
  }

  @override
  Future<bool> authenticate() async {
    final clientId = _config['client_id'] as String?;
    final clientSecret = _config['client_secret'] as String?;

    if (clientId == null || clientSecret == null) {
      log('GoogleCalendarService: Missing client_id or client_secret');
      return false;
    }

    final success = await _authManager.authenticateGoogle(
      clientId: clientId,
      clientSecret: clientSecret,
    );

    if (success) {
      final client = _authManager.getAuthenticatedClient(provider);
      if (client != null) {
        _calendarApi = calendar.CalendarApi(client);
        log('GoogleCalendarService: Calendar API initialized');
      }
    }

    return success;
  }

  @override
  Future<void> disconnect() async {
    await _authManager.disconnect(provider);
    _calendarApi = null;
    log('GoogleCalendarService: Disconnected');
  }

  @override
  Future<List<CalendarEvent>> getEvents({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? calendarIds,
  }) async {
    if (_calendarApi == null) {
      throw StateError('Google Calendar service not authenticated');
    }

    try {
      log('GoogleCalendarService: Fetching events from $startDate to $endDate');

      final events = <CalendarEvent>[];
      final calendarsToQuery = calendarIds ?? ['primary'];

      for (final calendarId in calendarsToQuery) {
        try {
          final response = await _calendarApi!.events.list(
            calendarId,
            timeMin: startDate,
            timeMax: endDate,
            singleEvents: true,
            orderBy: 'startTime',
            maxResults: 250,
          );

          if (response.items != null) {
            for (final item in response.items!) {
              final event = _convertGoogleEvent(item);
              if (event != null) {
                events.add(event);
              }
            }
          }
        } catch (e) {
          log('GoogleCalendarService: Error fetching events from calendar $calendarId: $e');
        }
      }

      log('GoogleCalendarService: Retrieved ${events.length} events');
      return events;
    } catch (e) {
      log('GoogleCalendarService: Error fetching events: $e');
      rethrow;
    }
  }

  @override
  Future<CalendarEvent?> getEvent(String eventId) async {
    if (_calendarApi == null) {
      throw StateError('Google Calendar service not authenticated');
    }

    try {
      log('GoogleCalendarService: Fetching event $eventId');

      final response = await _calendarApi!.events.get('primary', eventId);
      return _convertGoogleEvent(response);
    } catch (e) {
      log('GoogleCalendarService: Error fetching event $eventId: $e');
      return null;
    }
  }

  @override
  Future<List<CalendarEvent>> searchEvents({
    required String query,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_calendarApi == null) {
      throw StateError('Google Calendar service not authenticated');
    }

    try {
      log('GoogleCalendarService: Searching events with query: $query');

      final response = await _calendarApi!.events.list(
        'primary',
        q: query,
        timeMin: startDate,
        timeMax: endDate,
        singleEvents: true,
        orderBy: 'startTime',
        maxResults: 100,
      );

      final events = <CalendarEvent>[];
      if (response.items != null) {
        for (final item in response.items!) {
          final event = _convertGoogleEvent(item);
          if (event != null) {
            events.add(event);
          }
        }
      }

      log('GoogleCalendarService: Found ${events.length} events matching query');
      return events;
    } catch (e) {
      log('GoogleCalendarService: Error searching events: $e');
      return [];
    }
  }

  @override
  Future<List<CalendarInfo>> getCalendars() async {
    if (_calendarApi == null) {
      throw StateError('Google Calendar service not authenticated');
    }

    try {
      log('GoogleCalendarService: Fetching calendar list');

      final response = await _calendarApi!.calendarList.list();
      final calendars = <CalendarInfo>[];

      if (response.items != null) {
        for (final item in response.items!) {
          final calendarInfo = CalendarInfo(
            id: item.id ?? '',
            name: item.summary ?? 'Unknown Calendar',
            description: item.description,
            accessRole: _convertAccessRole(item.accessRole),
            isPrimary: item.primary ?? false,
            color: item.backgroundColor,
            timezone: item.timeZone,
          );
          calendars.add(calendarInfo);
        }
      }

      log('GoogleCalendarService: Retrieved ${calendars.length} calendars');
      return calendars;
    } catch (e) {
      log('GoogleCalendarService: Error fetching calendars: $e');
      return [];
    }
  }

  @override
  Future<CalendarEvent> createEvent(CalendarEvent event) async {
    if (_calendarApi == null) {
      throw StateError('Google Calendar service not authenticated');
    }

    try {
      log('GoogleCalendarService: Creating event: ${event.title}');

      final googleEvent = _convertToGoogleEvent(event);
      final response =
          await _calendarApi!.events.insert(googleEvent, 'primary');

      final createdEvent = _convertGoogleEvent(response);
      if (createdEvent == null) {
        throw Exception('Failed to convert created event');
      }

      log('GoogleCalendarService: Event created with ID: ${response.id}');
      return createdEvent;
    } catch (e) {
      log('GoogleCalendarService: Error creating event: $e');
      rethrow;
    }
  }

  @override
  Future<CalendarEvent> updateEvent(CalendarEvent event) async {
    if (_calendarApi == null) {
      throw StateError('Google Calendar service not authenticated');
    }

    try {
      log('GoogleCalendarService: Updating event: ${event.id}');

      final googleEvent = _convertToGoogleEvent(event);
      final response = await _calendarApi!.events.update(
        googleEvent,
        'primary',
        event.id,
      );

      final updatedEvent = _convertGoogleEvent(response);
      if (updatedEvent == null) {
        throw Exception('Failed to convert updated event');
      }

      log('GoogleCalendarService: Event updated: ${event.id}');
      return updatedEvent;
    } catch (e) {
      log('GoogleCalendarService: Error updating event: $e');
      rethrow;
    }
  }

  @override
  Future<bool> deleteEvent(String eventId) async {
    if (_calendarApi == null) {
      throw StateError('Google Calendar service not authenticated');
    }

    try {
      log('GoogleCalendarService: Deleting event: $eventId');

      await _calendarApi!.events.delete('primary', eventId);

      log('GoogleCalendarService: Event deleted: $eventId');
      return true;
    } catch (e) {
      log('GoogleCalendarService: Error deleting event: $e');
      return false;
    }
  }

  @override
  Stream<CalendarChangeEvent>? watchCalendarChanges() {
    // Google Calendar push notifications would be implemented here
    // For now, return null (not supported in this implementation)
    log('GoogleCalendarService: Calendar change watching not implemented');
    return null;
  }

  @override
  Map<String, dynamic> getConfigurationRequirements() {
    return {
      'client_id': {
        'type': 'string',
        'required': true,
        'description': 'Google OAuth2 client ID',
      },
      'client_secret': {
        'type': 'string',
        'required': true,
        'description': 'Google OAuth2 client secret',
      },
    };
  }

  @override
  bool validateConfiguration(Map<String, dynamic> config) {
    return config.containsKey('client_id') &&
        config.containsKey('client_secret') &&
        config['client_id'] is String &&
        config['client_secret'] is String;
  }

  /// Convert Google Calendar event to our CalendarEvent model
  CalendarEvent? _convertGoogleEvent(calendar.Event googleEvent) {
    try {
      final id = googleEvent.id;
      final title = googleEvent.summary;

      if (id == null || title == null) {
        return null;
      }

      // Handle start and end times
      DateTime startTime;
      DateTime endTime;
      bool isAllDay = false;

      if (googleEvent.start?.dateTime != null) {
        startTime = googleEvent.start!.dateTime!;
      } else if (googleEvent.start?.date != null) {
        startTime = googleEvent.start!.date!;
        isAllDay = true;
      } else {
        return null;
      }

      if (googleEvent.end?.dateTime != null) {
        endTime = googleEvent.end!.dateTime!;
      } else if (googleEvent.end?.date != null) {
        endTime = googleEvent.end!.date!;
      } else {
        endTime = startTime.add(const Duration(hours: 1));
      }

      // Convert attendees
      final attendees = <EventAttendee>[];
      if (googleEvent.attendees != null) {
        for (final attendee in googleEvent.attendees!) {
          attendees.add(EventAttendee(
            name: attendee.displayName,
            email: attendee.email,
            status: _convertAttendeeStatus(attendee.responseStatus),
            isOrganizer: attendee.organizer ?? false,
          ));
        }
      }

      // Convert organizer
      EventOrganizer? organizer;
      if (googleEvent.organizer != null) {
        organizer = EventOrganizer(
          name: googleEvent.organizer!.displayName,
          email: googleEvent.organizer!.email,
        );
      }

      return CalendarEvent(
        id: id,
        title: title,
        description: googleEvent.description,
        startTime: startTime,
        endTime: endTime,
        location: googleEvent.location,
        organizer: organizer,
        attendees: attendees,
        provider: provider,
        isAllDay: isAllDay,
        recurrenceRule: googleEvent.recurrence?.join(';'),
        status: _convertEventStatus(googleEvent.status),
        lastModified: googleEvent.updated,
        metadata: {
          'googleEventId': id,
          'htmlLink': googleEvent.htmlLink,
          'visibility': googleEvent.visibility,
          'transparency': googleEvent.transparency,
        },
      );
    } catch (e) {
      log('GoogleCalendarService: Error converting Google event: $e');
      return null;
    }
  }

  /// Convert our CalendarEvent to Google Calendar event
  calendar.Event _convertToGoogleEvent(CalendarEvent event) {
    final googleEvent = calendar.Event();

    googleEvent.id = event.id.isNotEmpty ? event.id : null;
    googleEvent.summary = event.title;
    googleEvent.description = event.description;
    googleEvent.location = event.location;

    // Set start and end times
    if (event.isAllDay) {
      googleEvent.start = calendar.EventDateTime(date: event.startTime);
      googleEvent.end = calendar.EventDateTime(date: event.endTime);
    } else {
      googleEvent.start = calendar.EventDateTime(dateTime: event.startTime);
      googleEvent.end = calendar.EventDateTime(dateTime: event.endTime);
    }

    // Convert attendees
    if (event.attendees.isNotEmpty) {
      googleEvent.attendees = event.attendees.map((attendee) {
        return calendar.EventAttendee(
          displayName: attendee.name,
          email: attendee.email,
          responseStatus: _convertToGoogleAttendeeStatus(attendee.status),
          organizer: attendee.isOrganizer,
        );
      }).toList();
    }

    // Convert organizer
    if (event.organizer != null) {
      googleEvent.organizer = calendar.EventOrganizer(
        displayName: event.organizer!.name,
        email: event.organizer!.email,
      );
    }

    return googleEvent;
  }

  /// Convert Google attendee status to our enum
  AttendeeStatus _convertAttendeeStatus(String? status) {
    switch (status) {
      case 'accepted':
        return AttendeeStatus.accepted;
      case 'declined':
        return AttendeeStatus.declined;
      case 'tentative':
        return AttendeeStatus.tentative;
      default:
        return AttendeeStatus.needsAction;
    }
  }

  /// Convert our attendee status to Google status
  String _convertToGoogleAttendeeStatus(AttendeeStatus status) {
    switch (status) {
      case AttendeeStatus.accepted:
        return 'accepted';
      case AttendeeStatus.declined:
        return 'declined';
      case AttendeeStatus.tentative:
        return 'tentative';
      case AttendeeStatus.needsAction:
        return 'needsAction';
    }
  }

  /// Convert Google event status to our enum
  EventStatus _convertEventStatus(String? status) {
    switch (status) {
      case 'confirmed':
        return EventStatus.confirmed;
      case 'tentative':
        return EventStatus.tentative;
      case 'cancelled':
        return EventStatus.cancelled;
      default:
        return EventStatus.confirmed;
    }
  }

  /// Convert Google access role to our enum
  CalendarAccessRole _convertAccessRole(String? role) {
    switch (role) {
      case 'none':
        return CalendarAccessRole.none;
      case 'freeBusyReader':
        return CalendarAccessRole.freeBusyReader;
      case 'reader':
        return CalendarAccessRole.reader;
      case 'writer':
        return CalendarAccessRole.writer;
      case 'owner':
        return CalendarAccessRole.owner;
      default:
        return CalendarAccessRole.reader;
    }
  }
}
