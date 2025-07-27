import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/services/calendar_services/meeting_detection_service.dart';
import 'package:meeting_summarizer/core/models/calendar/calendar_event.dart';
import 'package:meeting_summarizer/core/models/calendar/meeting_context.dart';
import 'package:meeting_summarizer/core/enums/calendar_provider.dart';
import 'package:meeting_summarizer/core/interfaces/calendar_service_interface.dart';

void main() {
  group('MeetingDetectionService', () {
    late MeetingDetectionService service;

    setUp(() {
      service = MeetingDetectionService();
    });

    group('detectMeeting', () {
      test('should detect high-confidence team meeting', () async {
        final event = CalendarEvent(
          id: 'test-meeting-1',
          title: 'Weekly Team Standup',
          description: 'Discuss progress, blockers, and upcoming tasks',
          startTime: DateTime.now().add(const Duration(hours: 1)),
          endTime: DateTime.now().add(const Duration(hours: 1, minutes: 30)),
          attendees: [
            const EventAttendee(
              name: 'John Doe',
              email: 'john@example.com',
              status: AttendeeStatus.accepted,
            ),
            const EventAttendee(
              name: 'Jane Smith',
              email: 'jane@example.com',
              status: AttendeeStatus.accepted,
            ),
            const EventAttendee(
              name: 'Bob Wilson',
              email: 'bob@example.com',
              status: AttendeeStatus.tentative,
            ),
          ],
          provider: CalendarProvider.googleCalendar,
        );

        final result = await service.detectMeeting(event);

        expect(result, isNotNull);
        expect(result!.type, equals(MeetingType.standup));
        expect(result.detectionConfidence, greaterThan(0.7));
        expect(result.event.id, equals('test-meeting-1'));
        expect(result.participants.length, equals(3));
      });

      test('should detect 1:1 meeting', () async {
        final event = CalendarEvent(
          id: 'test-meeting-2',
          title: 'John & Jane 1:1',
          description: 'Monthly check-in and career discussion',
          startTime: DateTime.now().add(const Duration(hours: 2)),
          endTime: DateTime.now().add(const Duration(hours: 2, minutes: 60)),
          attendees: [
            const EventAttendee(
              name: 'John Doe',
              email: 'john@example.com',
              status: AttendeeStatus.accepted,
              isOrganizer: true,
            ),
            const EventAttendee(
              name: 'Jane Smith',
              email: 'jane@example.com',
              status: AttendeeStatus.accepted,
            ),
          ],
          provider: CalendarProvider.googleCalendar,
        );

        final result = await service.detectMeeting(event);

        expect(result, isNotNull);
        expect(result!.type, equals(MeetingType.oneOnOne));
        expect(result.detectionConfidence, greaterThan(0.7));
        expect(result.participants.length, equals(2));
      });

      test('should detect interview meeting', () async {
        final event = CalendarEvent(
          id: 'test-meeting-3',
          title: 'Technical Interview - Senior Developer',
          description: 'Interview candidate for senior developer position',
          startTime: DateTime.now().add(const Duration(hours: 3)),
          endTime: DateTime.now().add(const Duration(hours: 4)),
          attendees: [
            const EventAttendee(
              name: 'HR Manager',
              email: 'hr@example.com',
              status: AttendeeStatus.accepted,
              isOrganizer: true,
            ),
            const EventAttendee(
              name: 'Tech Lead',
              email: 'lead@example.com',
              status: AttendeeStatus.accepted,
            ),
            const EventAttendee(
              name: 'Candidate',
              email: 'candidate@email.com',
              status: AttendeeStatus.needsAction,
            ),
          ],
          provider: CalendarProvider.googleCalendar,
        );

        final result = await service.detectMeeting(event);

        expect(result, isNotNull);
        expect(result!.type, equals(MeetingType.interview));
        expect(result.detectionConfidence, greaterThan(0.7));
        expect(result.shouldAutoRecord, isTrue);
      });

      test('should reject non-meeting events', () async {
        final event = CalendarEvent(
          id: 'test-event-1',
          title: 'Lunch Break',
          description: 'Personal lunch time',
          startTime: DateTime.now().add(const Duration(hours: 5)),
          endTime: DateTime.now().add(const Duration(hours: 5, minutes: 60)),
          attendees: [],
          provider: CalendarProvider.googleCalendar,
        );

        final result = await service.detectMeeting(event);

        expect(result, isNull);
      });

      test('should detect virtual meeting information', () async {
        final event = CalendarEvent(
          id: 'test-meeting-4',
          title: 'Product Demo',
          description:
              'Join Zoom Meeting: https://zoom.us/j/123456789?pwd=password123',
          startTime: DateTime.now().add(const Duration(hours: 1)),
          endTime: DateTime.now().add(const Duration(hours: 1, minutes: 45)),
          attendees: [
            const EventAttendee(
              name: 'Product Manager',
              email: 'pm@example.com',
              status: AttendeeStatus.accepted,
              isOrganizer: true,
            ),
            const EventAttendee(
              name: 'Sales Team',
              email: 'sales@example.com',
              status: AttendeeStatus.accepted,
            ),
          ],
          provider: CalendarProvider.googleCalendar,
        );

        final result = await service.detectMeeting(event);

        expect(result, isNotNull);
        expect(result!.type, equals(MeetingType.presentation));
        expect(result.virtualMeetingInfo, isNotNull);
        expect(
            result.virtualMeetingInfo!.platform, equals(VirtualPlatform.zoom));
        expect(result.virtualMeetingInfo!.meetingId, equals('123456789'));
      });

      test('should extract agenda items from description', () async {
        final event = CalendarEvent(
          id: 'test-meeting-5',
          title: 'Sprint Planning',
          description: '''
Sprint Planning Meeting

Agenda:
1. Review previous sprint outcomes
2. Discuss upcoming user stories
3. Estimate story points
4. Plan sprint capacity

Please review the backlog before the meeting.
          ''',
          startTime: DateTime.now().add(const Duration(hours: 1)),
          endTime: DateTime.now().add(const Duration(hours: 3)),
          attendees: [
            const EventAttendee(
              name: 'Scrum Master',
              email: 'scrum@example.com',
              status: AttendeeStatus.accepted,
              isOrganizer: true,
            ),
            const EventAttendee(
              name: 'Developer 1',
              email: 'dev1@example.com',
              status: AttendeeStatus.accepted,
            ),
            const EventAttendee(
              name: 'Developer 2',
              email: 'dev2@example.com',
              status: AttendeeStatus.accepted,
            ),
          ],
          provider: CalendarProvider.googleCalendar,
        );

        final result = await service.detectMeeting(event);

        expect(result, isNotNull);
        expect(result!.type, equals(MeetingType.planning));
        expect(result.agendaItems.length, equals(4));
        expect(result.agendaItems[0], contains('Review previous sprint'));
        expect(
            result.agendaItems[1], contains('Discuss upcoming user stories'));
      });

      test('should handle events with different durations', () async {
        // Very short meeting
        final shortEvent = CalendarEvent(
          id: 'test-meeting-6',
          title: 'Quick Sync',
          startTime: DateTime.now().add(const Duration(hours: 1)),
          endTime: DateTime.now().add(const Duration(hours: 1, minutes: 10)),
          attendees: [
            const EventAttendee(name: 'Person 1', email: 'p1@example.com'),
            const EventAttendee(name: 'Person 2', email: 'p2@example.com'),
          ],
          provider: CalendarProvider.googleCalendar,
        );

        final shortResult = await service.detectMeeting(shortEvent);
        expect(shortResult, isNull); // Below minimum duration

        // Very long meeting
        final longEvent = CalendarEvent(
          id: 'test-meeting-7',
          title: 'All Day Workshop',
          startTime: DateTime.now().add(const Duration(hours: 1)),
          endTime: DateTime.now().add(const Duration(hours: 9)),
          attendees: [
            const EventAttendee(name: 'Trainer', email: 'trainer@example.com'),
            const EventAttendee(name: 'Student 1', email: 's1@example.com'),
            const EventAttendee(name: 'Student 2', email: 's2@example.com'),
          ],
          provider: CalendarProvider.googleCalendar,
        );

        final longResult = await service.detectMeeting(longEvent);
        expect(longResult, isNotNull);
        expect(longResult!.type, equals(MeetingType.training));
      });
    });

    group('detectMeetings', () {
      test('should process multiple events and return detected meetings',
          () async {
        final events = [
          CalendarEvent(
            id: 'meeting-1',
            title: 'Daily Standup',
            startTime: DateTime.now().add(const Duration(hours: 1)),
            endTime: DateTime.now().add(const Duration(hours: 1, minutes: 30)),
            attendees: [
              const EventAttendee(name: 'Dev 1', email: 'dev1@example.com'),
              const EventAttendee(name: 'Dev 2', email: 'dev2@example.com'),
            ],
            provider: CalendarProvider.googleCalendar,
          ),
          CalendarEvent(
            id: 'non-meeting-1',
            title: 'Lunch',
            startTime: DateTime.now().add(const Duration(hours: 5)),
            endTime: DateTime.now().add(const Duration(hours: 6)),
            attendees: [],
            provider: CalendarProvider.googleCalendar,
          ),
          CalendarEvent(
            id: 'meeting-2',
            title: 'Product Review',
            startTime: DateTime.now().add(const Duration(hours: 3)),
            endTime: DateTime.now().add(const Duration(hours: 4)),
            attendees: [
              const EventAttendee(name: 'PM', email: 'pm@example.com'),
              const EventAttendee(
                  name: 'Designer', email: 'design@example.com'),
              const EventAttendee(name: 'Developer', email: 'dev@example.com'),
            ],
            provider: CalendarProvider.googleCalendar,
          ),
        ];

        final results = await service.detectMeetings(events);

        expect(results.length, equals(2));
        expect(results.any((m) => m.event.id == 'meeting-1'), isTrue);
        expect(results.any((m) => m.event.id == 'meeting-2'), isTrue);
        expect(results.any((m) => m.event.id == 'non-meeting-1'), isFalse);
      });

      test('should update detection statistics', () async {
        final events = [
          CalendarEvent(
            id: 'meeting-1',
            title: 'Team Meeting',
            startTime: DateTime.now().add(const Duration(hours: 1)),
            endTime: DateTime.now().add(const Duration(hours: 2)),
            attendees: [
              const EventAttendee(name: 'Person 1', email: 'p1@example.com'),
              const EventAttendee(name: 'Person 2', email: 'p2@example.com'),
            ],
            provider: CalendarProvider.googleCalendar,
          ),
        ];

        await service.detectMeetings(events);
        final stats = service.getDetectionStats();

        expect(stats.totalEventsProcessed, equals(1));
        expect(stats.meetingsDetected, equals(1));
        expect(stats.detectionRate, equals(1.0));
        expect(stats.lastProcessedAt, isNotNull);
      });
    });

    group('configureMeetingRules', () {
      test('should apply custom detection rules', () async {
        // Configure strict rules
        const strictRules = MeetingDetectionRules(
          minimumConfidenceThreshold: 0.9,
          minimumMeetingDuration: Duration(minutes: 30),
          minimumAttendeeCount: 3,
        );

        service.configureMeetingRules(strictRules);

        // Test with meeting that would normally pass but fails strict rules
        final event = CalendarEvent(
          id: 'test-meeting',
          title: 'Quick Team Check-in',
          startTime: DateTime.now().add(const Duration(hours: 1)),
          endTime: DateTime.now().add(const Duration(hours: 1, minutes: 15)),
          attendees: [
            const EventAttendee(name: 'Person 1', email: 'p1@example.com'),
            const EventAttendee(name: 'Person 2', email: 'p2@example.com'),
          ],
          provider: CalendarProvider.googleCalendar,
        );

        final result = await service.detectMeeting(event);
        expect(result, isNull); // Should fail due to strict rules
      });

      test('should respect custom keywords', () async {
        const customRules = MeetingDetectionRules(
          meetingKeywords: ['sync', 'huddle'],
          excludeKeywords: ['social', 'party'],
        );

        service.configureMeetingRules(customRules);

        // Test with custom keyword
        final event1 = CalendarEvent(
          id: 'test-meeting-1',
          title: 'Team Huddle',
          startTime: DateTime.now().add(const Duration(hours: 1)),
          endTime: DateTime.now().add(const Duration(hours: 1, minutes: 30)),
          attendees: [
            const EventAttendee(name: 'Person 1', email: 'p1@example.com'),
            const EventAttendee(name: 'Person 2', email: 'p2@example.com'),
          ],
          provider: CalendarProvider.googleCalendar,
        );

        final result1 = await service.detectMeeting(event1);
        expect(result1, isNotNull);

        // Test with exclude keyword
        final event2 = CalendarEvent(
          id: 'test-meeting-2',
          title: 'Office Party',
          startTime: DateTime.now().add(const Duration(hours: 2)),
          endTime: DateTime.now().add(const Duration(hours: 4)),
          attendees: [
            const EventAttendee(name: 'Person 1', email: 'p1@example.com'),
            const EventAttendee(name: 'Person 2', email: 'p2@example.com'),
          ],
          provider: CalendarProvider.googleCalendar,
        );

        final result2 = await service.detectMeeting(event2);
        expect(result2, isNull);
      });
    });

    group('edge cases', () {
      test('should handle events with no attendees when not required',
          () async {
        const rules = MeetingDetectionRules(requireAttendees: false);
        service.configureMeetingRules(rules);

        final event = CalendarEvent(
          id: 'solo-meeting',
          title: 'Meeting Preparation',
          startTime: DateTime.now().add(const Duration(hours: 1)),
          endTime: DateTime.now().add(const Duration(hours: 1, minutes: 30)),
          attendees: [],
          provider: CalendarProvider.googleCalendar,
        );

        final result = await service.detectMeeting(event);
        expect(result, isNotNull);
      });

      test('should handle events with only organizer', () async {
        final event = CalendarEvent(
          id: 'organizer-only',
          title: 'Planning Session',
          startTime: DateTime.now().add(const Duration(hours: 1)),
          endTime: DateTime.now().add(const Duration(hours: 1, minutes: 60)),
          attendees: [
            const EventAttendee(
              name: 'Organizer',
              email: 'org@example.com',
              isOrganizer: true,
            ),
          ],
          provider: CalendarProvider.googleCalendar,
        );

        final result = await service.detectMeeting(event);
        expect(result, isNull); // Should fail minimum attendee requirement
      });

      test('should handle events with null/empty descriptions', () async {
        final event = CalendarEvent(
          id: 'no-description',
          title: 'Team Meeting',
          description: null,
          startTime: DateTime.now().add(const Duration(hours: 1)),
          endTime: DateTime.now().add(const Duration(hours: 1, minutes: 30)),
          attendees: [
            const EventAttendee(name: 'Person 1', email: 'p1@example.com'),
            const EventAttendee(name: 'Person 2', email: 'p2@example.com'),
          ],
          provider: CalendarProvider.googleCalendar,
        );

        final result = await service.detectMeeting(event);
        expect(result, isNotNull);
      });
    });
  });
}
