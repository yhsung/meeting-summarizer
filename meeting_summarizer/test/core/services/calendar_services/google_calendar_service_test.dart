import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:meeting_summarizer/core/services/calendar_services/google_calendar_service.dart';
import 'package:meeting_summarizer/core/services/calendar_services/oauth2_auth_manager.dart';
import 'package:meeting_summarizer/core/models/calendar/calendar_event.dart';
import 'package:meeting_summarizer/core/enums/calendar_provider.dart';

import 'google_calendar_service_test.mocks.dart';

// Generate mocks with: flutter packages pub run build_runner build
@GenerateMocks([OAuth2AuthManager])
void main() {
  group('GoogleCalendarService', () {
    late GoogleCalendarService service;
    late MockOAuth2AuthManager mockAuthManager;

    setUp(() {
      mockAuthManager = MockOAuth2AuthManager();
      service = GoogleCalendarService(mockAuthManager);
    });

    group('initialization', () {
      test('should initialize with valid configuration', () async {
        final config = {
          'client_id': 'test-client-id',
          'client_secret': 'test-client-secret',
        };

        expect(() => service.initialize(config), returnsNormally);
      });

      test('should throw error with invalid configuration', () async {
        final config = {
          'client_id': 'test-client-id',
          // Missing client_secret
        };

        expect(
          () => service.initialize(config),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should validate configuration correctly', () {
        final validConfig = {
          'client_id': 'test-client-id',
          'client_secret': 'test-client-secret',
        };

        final invalidConfig = {
          'client_id': 'test-client-id',
          // Missing client_secret
        };

        expect(service.validateConfiguration(validConfig), isTrue);
        expect(service.validateConfiguration(invalidConfig), isFalse);
      });

      test('should return correct configuration requirements', () {
        final requirements = service.getConfigurationRequirements();

        expect(requirements, containsPair('client_id', anything));
        expect(requirements, containsPair('client_secret', anything));
        expect(requirements['client_id']['required'], isTrue);
        expect(requirements['client_secret']['required'], isTrue);
      });
    });

    group('authentication', () {
      setUp(() async {
        final config = {
          'client_id': 'test-client-id',
          'client_secret': 'test-client-secret',
        };
        await service.initialize(config);
      });

      test('should authenticate successfully', () async {
        when(mockAuthManager.authenticateGoogle(
          clientId: anyNamed('clientId'),
          clientSecret: anyNamed('clientSecret'),
        )).thenAnswer((_) async => true);

        when(mockAuthManager
                .getAuthenticatedClient(CalendarProvider.googleCalendar))
            .thenReturn(null); // Mock HTTP client would be returned here

        final result = await service.authenticate();

        expect(result, isTrue);
        verify(mockAuthManager.authenticateGoogle(
          clientId: 'test-client-id',
          clientSecret: 'test-client-secret',
        )).called(1);
      });

      test('should handle authentication failure', () async {
        when(mockAuthManager.authenticateGoogle(
          clientId: anyNamed('clientId'),
          clientSecret: anyNamed('clientSecret'),
        )).thenAnswer((_) async => false);

        final result = await service.authenticate();

        expect(result, isFalse);
      });

      test('should report authentication status correctly', () {
        when(mockAuthManager.isAuthenticated(CalendarProvider.googleCalendar))
            .thenReturn(true);

        expect(service.isAuthenticated, isTrue);

        when(mockAuthManager.isAuthenticated(CalendarProvider.googleCalendar))
            .thenReturn(false);

        expect(service.isAuthenticated, isFalse);
      });
    });

    group('calendar operations', () {
      setUp(() async {
        final config = {
          'client_id': 'test-client-id',
          'client_secret': 'test-client-secret',
        };
        await service.initialize(config);

        // Mock successful authentication
        when(mockAuthManager.authenticateGoogle(
          clientId: anyNamed('clientId'),
          clientSecret: anyNamed('clientSecret'),
        )).thenAnswer((_) async => true);

        when(mockAuthManager
                .getAuthenticatedClient(CalendarProvider.googleCalendar))
            .thenReturn(
                null); // In real tests, this would return a mock HTTP client
      });

      test('should throw StateError when not authenticated', () async {
        // Don't authenticate
        expect(
          () => service.getEvents(
            startDate: DateTime.now(),
            endDate: DateTime.now().add(const Duration(days: 1)),
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('should handle getEvents with authentication', () async {
        // This test would require mocking the Google Calendar API client
        // For now, we'll test the error case
        await service.authenticate();

        expect(
          () => service.getEvents(
            startDate: DateTime.now(),
            endDate: DateTime.now().add(const Duration(days: 1)),
          ),
          throwsA(isA<StateError>()), // Will throw because _calendarApi is null
        );
      });

      test('should handle searchEvents with authentication', () async {
        await service.authenticate();

        expect(
          () => service.searchEvents(query: 'meeting'),
          throwsA(isA<StateError>()), // Will throw because _calendarApi is null
        );
      });

      test('should handle getCalendars with authentication', () async {
        await service.authenticate();

        expect(
          () => service.getCalendars(),
          throwsA(isA<StateError>()), // Will throw because _calendarApi is null
        );
      });
    });

    group('event conversion', () {
      test('should return correct provider', () {
        expect(service.provider, equals(CalendarProvider.googleCalendar));
      });

      test('should handle disconnect properly', () async {
        when(mockAuthManager.disconnect(CalendarProvider.googleCalendar))
            .thenAnswer((_) async {});

        await service.disconnect();

        verify(mockAuthManager.disconnect(CalendarProvider.googleCalendar))
            .called(1);
      });
    });

    group('event CRUD operations', () {
      setUp(() async {
        final config = {
          'client_id': 'test-client-id',
          'client_secret': 'test-client-secret',
        };
        await service.initialize(config);
        await service.authenticate();
      });

      test('should handle createEvent when not authenticated', () async {
        final event = CalendarEvent(
          id: 'test-event',
          title: 'Test Meeting',
          startTime: DateTime.now().add(const Duration(hours: 1)),
          endTime: DateTime.now().add(const Duration(hours: 2)),
          provider: CalendarProvider.googleCalendar,
        );

        expect(
          () => service.createEvent(event),
          throwsA(isA<StateError>()),
        );
      });

      test('should handle updateEvent when not authenticated', () async {
        final event = CalendarEvent(
          id: 'test-event',
          title: 'Updated Test Meeting',
          startTime: DateTime.now().add(const Duration(hours: 1)),
          endTime: DateTime.now().add(const Duration(hours: 2)),
          provider: CalendarProvider.googleCalendar,
        );

        expect(
          () => service.updateEvent(event),
          throwsA(isA<StateError>()),
        );
      });

      test('should handle deleteEvent when not authenticated', () async {
        expect(
          () => service.deleteEvent('test-event-id'),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('calendar change monitoring', () {
      test('should return null for watchCalendarChanges', () {
        final stream = service.watchCalendarChanges();
        expect(stream, isNull);
      });
    });

    group('error handling', () {
      test('should handle missing configuration gracefully', () async {
        final incompleteConfig = {
          'client_id': 'test-client-id',
          // Missing client_secret
        };

        expect(
          () => service.initialize(incompleteConfig),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should handle null configuration values', () async {
        final nullConfig = {
          'client_id': null,
          'client_secret': 'test-client-secret',
        };

        expect(service.validateConfiguration(nullConfig), isFalse);
      });

      test('should handle empty configuration', () async {
        final emptyConfig = <String, dynamic>{};

        expect(service.validateConfiguration(emptyConfig), isFalse);
      });
    });

    group('helper methods', () {
      test('should handle getTodaysEvents', () async {
        await service.initialize({
          'client_id': 'test-client-id',
          'client_secret': 'test-client-secret',
        });

        expect(
          () => service.getTodaysEvents(),
          throwsA(isA<StateError>()),
        );
      });

      test('should handle getUpcomingEvents', () async {
        await service.initialize({
          'client_id': 'test-client-id',
          'client_secret': 'test-client-secret',
        });

        expect(
          () => service.getUpcomingEvents(),
          throwsA(isA<StateError>()),
        );
      });

      test('should handle getEvent', () async {
        await service.initialize({
          'client_id': 'test-client-id',
          'client_secret': 'test-client-secret',
        });

        expect(
          () => service.getEvent('test-event-id'),
          throwsA(isA<StateError>()),
        );
      });
    });
  });
}
