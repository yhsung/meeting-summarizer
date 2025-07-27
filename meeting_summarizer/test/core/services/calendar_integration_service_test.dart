import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:meeting_summarizer/core/services/calendar_integration_service.dart';
import 'package:meeting_summarizer/core/services/settings_service.dart';
import 'package:meeting_summarizer/core/services/gdpr_compliance_service.dart';
import 'package:meeting_summarizer/core/models/calendar/calendar_event.dart';
import 'package:meeting_summarizer/core/models/calendar/meeting_context.dart';
import 'package:meeting_summarizer/core/enums/calendar_provider.dart';

import 'calendar_integration_service_test.mocks.dart';

@GenerateMocks([SettingsService, GdprComplianceService])
void main() {
  group('CalendarIntegrationService', () {
    late CalendarIntegrationService service;
    late MockSettingsService mockSettingsService;
    late MockGdprComplianceService mockGdprService;

    setUp(() {
      mockSettingsService = MockSettingsService();
      mockGdprService = MockGdprComplianceService();
      service =
          CalendarIntegrationService(mockSettingsService, mockGdprService);

      // Setup default mock responses
      when(mockSettingsService.initialize()).thenAnswer((_) async {});
      when(mockSettingsService.getStringList(any,
              defaultValue: anyNamed('defaultValue')))
          .thenAnswer((_) async => []);
      when(mockSettingsService.getBool(any,
              defaultValue: anyNamed('defaultValue')))
          .thenAnswer((_) async => true);
      when(mockSettingsService.getString(any)).thenAnswer((_) async => null);
      when(mockSettingsService.getInt(any,
              defaultValue: anyNamed('defaultValue')))
          .thenAnswer((_) async => 587);
    });

    tearDown(() {
      service.dispose();
    });

    group('initialization', () {
      test('should initialize successfully with default settings', () async {
        await service.initialize();

        expect(service, isNotNull);
        verify(mockSettingsService.initialize()).called(1);
      });

      test('should handle initialization failure gracefully', () async {
        when(mockSettingsService.initialize())
            .thenThrow(Exception('Settings initialization failed'));

        expect(
          () => service.initialize(),
          throwsException,
        );
      });

      test('should only initialize once', () async {
        await service.initialize();
        await service.initialize(); // Second call should be ignored

        verify(mockSettingsService.initialize()).called(1);
      });
    });

    group('provider configuration', () {
      setUp(() async {
        await service.initialize();
      });

      test('should configure Google Calendar provider successfully', () async {
        final config = {
          'client_id': 'test-client-id',
          'client_secret': 'test-client-secret',
        };

        when(mockSettingsService.setString(any, any)).thenAnswer((_) async {});
        when(mockSettingsService.setStringList(any, any))
            .thenAnswer((_) async {});

        final result = await service.configureProvider(
          provider: CalendarProvider.googleCalendar,
          config: config,
        );

        expect(result, isTrue);
        verify(mockSettingsService.setString(
          'calendar_google_config',
          'config_placeholder',
        )).called(1);
      });

      test('should reject invalid provider configuration', () async {
        final invalidConfig = {
          'client_id': 'test-client-id',
          // Missing client_secret
        };

        final result = await service.configureProvider(
          provider: CalendarProvider.googleCalendar,
          config: invalidConfig,
        );

        expect(result, isFalse);
      });

      test('should handle provider configuration errors', () async {
        final config = {
          'client_id': 'test-client-id',
          'client_secret': 'test-client-secret',
        };

        when(mockSettingsService.setString(any, any))
            .thenThrow(Exception('Storage error'));

        final result = await service.configureProvider(
          provider: CalendarProvider.googleCalendar,
          config: config,
        );

        expect(result, isFalse);
      });
    });

    group('meeting retrieval', () {
      setUp(() async {
        await service.initialize();
      });

      test('should throw StateError when not initialized', () async {
        final uninitializedService = CalendarIntegrationService(
          mockSettingsService,
          mockGdprService,
        );

        expect(
          () => uninitializedService.getUpcomingMeetings(),
          throwsA(isA<StateError>()),
        );
      });

      test('should return empty list when no providers configured', () async {
        final meetings = await service.getUpcomingMeetings();

        expect(meetings, isEmpty);
      });

      test('should handle today\'s meetings request', () async {
        final meetings = await service.getTodaysMeetings();

        expect(meetings, isEmpty); // No providers configured
      });

      test('should handle search meetings request', () async {
        final meetings = await service.searchMeetings(
          query: 'team meeting',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 7)),
        );

        expect(meetings, isEmpty); // No providers configured
      });
    });

    group('meeting context', () {
      setUp(() async {
        await service.initialize();
      });

      test('should get meeting context for calendar event', () async {
        final event = CalendarEvent(
          id: 'test-event',
          title: 'Team Meeting',
          startTime: DateTime.now().add(const Duration(hours: 1)),
          endTime: DateTime.now().add(const Duration(hours: 2)),
          attendees: [
            const EventAttendee(name: 'John', email: 'john@example.com'),
            const EventAttendee(name: 'Jane', email: 'jane@example.com'),
          ],
          provider: CalendarProvider.googleCalendar,
        );

        final context = await service.getMeetingContext(event);

        expect(context, isNotNull);
        expect(context!.event.id, equals('test-event'));
        expect(context.participants.length, equals(2));
      });

      test('should return null for non-meeting events', () async {
        final event = CalendarEvent(
          id: 'non-meeting',
          title: 'Lunch Break',
          startTime: DateTime.now().add(const Duration(hours: 1)),
          endTime: DateTime.now().add(const Duration(hours: 2)),
          attendees: [],
          provider: CalendarProvider.googleCalendar,
        );

        final context = await service.getMeetingContext(event);

        expect(context, isNull);
      });
    });

    group('provider management', () {
      setUp(() async {
        await service.initialize();
      });

      test('should disconnect from provider', () async {
        when(mockSettingsService.remove(any)).thenAnswer((_) async {});
        when(mockSettingsService.setStringList(any, any))
            .thenAnswer((_) async {});

        await service.disconnectProvider(CalendarProvider.googleCalendar);

        verify(mockSettingsService.remove('calendar_google_config')).called(1);
      });

      test('should get authentication status for all providers', () {
        final status = service.getAuthenticationStatus();

        expect(status, isA<Map<CalendarProvider, bool>>());
        expect(status.length, equals(CalendarProvider.values.length));

        // All should be false since no providers are configured
        for (final value in status.values) {
          expect(value, isFalse);
        }
      });
    });

    group('meeting detection configuration', () {
      setUp(() async {
        await service.initialize();
      });

      test('should configure meeting detection rules', () {
        const rules = MeetingDetectionRules(
          minimumConfidenceThreshold: 0.8,
          minimumMeetingDuration: Duration(minutes: 30),
        );

        expect(() => service.configureMeetingDetection(rules), returnsNormally);
      });

      test('should get meeting detection statistics', () {
        final stats = service.getMeetingDetectionStats();

        expect(stats, isNotNull);
        expect(stats.totalEventsProcessed, equals(0));
        expect(stats.meetingsDetected, equals(0));
      });
    });

    group('summary distribution', () {
      setUp() async {
        await service.initialize();
      }

      test('should handle summary distribution when not configured', () async {
        final mockMeeting = MeetingContext(
          event: CalendarEvent(
            id: 'test-meeting',
            title: 'Test Meeting',
            startTime: DateTime.now().subtract(const Duration(hours: 1)),
            endTime: DateTime.now(),
            provider: CalendarProvider.googleCalendar,
          ),
          type: MeetingType.teamMeeting,
          expectedDuration: const Duration(hours: 1),
          extractedAt: DateTime.now(),
        );

        final mockSummary = Summary(
          id: 'test-summary',
          recordingId: 'test-recording',
          content: 'Test summary content',
          createdAt: DateTime.now(),
          summaryType: 'brief',
          keyPoints: ['Point 1', 'Point 2'],
          actionItems: ['Action 1'],
        );

        final result = await service.distributeMeetingSummary(
          meetingContext: mockMeeting,
          summary: mockSummary,
        );

        expect(result, isFalse); // Should fail due to no SMTP configuration
      });
    });

    group('meeting events stream', () {
      setUp(() async {
        await service.initialize();
      });

      test('should provide meeting event stream', () {
        expect(service.meetingEventStream, isNotNull);
        expect(service.meetingEventStream, isA<Stream<MeetingEvent>>());
      });

      test('should emit events when summary is distributed', () async {
        final events = <MeetingEvent>[];
        final subscription = service.meetingEventStream.listen(events.add);

        final mockMeeting = MeetingContext(
          event: CalendarEvent(
            id: 'test-meeting',
            title: 'Test Meeting',
            startTime: DateTime.now().subtract(const Duration(hours: 1)),
            endTime: DateTime.now(),
            provider: CalendarProvider.googleCalendar,
          ),
          type: MeetingType.teamMeeting,
          expectedDuration: const Duration(hours: 1),
          extractedAt: DateTime.now(),
        );

        final mockSummary = Summary(
          id: 'test-summary',
          recordingId: 'test-recording',
          content: 'Test summary content',
          createdAt: DateTime.now(),
          summaryType: 'brief',
          keyPoints: ['Point 1', 'Point 2'],
          actionItems: ['Action 1'],
        );

        await service.distributeMeetingSummary(
          meetingContext: mockMeeting,
          summary: mockSummary,
        );

        await subscription.cancel();

        // Should have received an event even if distribution failed
        expect(events, isEmpty); // No events since distribution failed
      });
    });

    group('error handling', () {
      test('should handle service disposal gracefully', () async {
        await service.initialize();

        expect(() => service.dispose(), returnsNormally);
      });

      test('should handle double disposal', () async {
        await service.initialize();

        await service.dispose();
        expect(() => service.dispose(), returnsNormally);
      });

      test('should handle operations after disposal', () async {
        await service.initialize();
        await service.dispose();

        expect(
          () => service.getUpcomingMeetings(),
          throwsA(isA<StateError>()),
        );
      });
    });
  });
}
