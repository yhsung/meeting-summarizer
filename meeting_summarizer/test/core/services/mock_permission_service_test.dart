import 'package:flutter_test/flutter_test.dart';

import 'package:meeting_summarizer/core/services/permission_service_interface.dart';
import 'mock_permission_service.dart';

void main() {
  group('Mock Permission Service Tests', () {
    late MockPermissionService mockService;

    setUp(() {
      mockService = MockPermissionService();
    });

    tearDown(() async {
      await mockService.dispose();
    });

    group('Initialization and Lifecycle', () {
      test('should initialize successfully', () async {
        await expectLater(mockService.initialize(), completes);
      });

      test('should dispose successfully', () async {
        await mockService.initialize();
        await expectLater(mockService.dispose(), completes);
      });

      test('should handle multiple dispose calls', () async {
        await mockService.initialize();
        await mockService.dispose();
        await expectLater(mockService.dispose(), completes);
      });
    });

    group('Permission State Management', () {
      test('should simulate permission state changes', () async {
        await mockService.initialize();

        // Set initial state
        mockService.setMockPermissionState(
          PermissionType.microphone,
          PermissionState.denied,
        );

        var state = await mockService.checkPermission(
          PermissionType.microphone,
        );
        expect(state, equals(PermissionState.denied));

        // Simulate permission change
        mockService.simulatePermissionChange(
          PermissionType.microphone,
          PermissionState.granted,
        );

        state = await mockService.checkPermission(PermissionType.microphone);
        expect(state, equals(PermissionState.granted));
      });

      test('should check multiple permissions', () async {
        await mockService.initialize();

        mockService.setMockPermissionState(
          PermissionType.microphone,
          PermissionState.granted,
        );
        mockService.setMockPermissionState(
          PermissionType.storage,
          PermissionState.denied,
        );

        final results = await mockService.checkPermissions([
          PermissionType.microphone,
          PermissionType.storage,
        ]);

        expect(
          results[PermissionType.microphone],
          equals(PermissionState.granted),
        );
        expect(results[PermissionType.storage], equals(PermissionState.denied));
      });
    });

    group('Permission Requests', () {
      test('should grant permission when denied', () async {
        await mockService.initialize();

        // Set initial state to denied
        mockService.setMockPermissionState(
          PermissionType.microphone,
          PermissionState.denied,
        );

        // Request permission (mock will grant it)
        final result = await mockService.requestPermission(
          PermissionType.microphone,
        );

        expect(result.isGranted, isTrue);
        expect(result.state, equals(PermissionState.granted));
      });

      test('should return granted when already granted', () async {
        await mockService.initialize();

        // Set initial state to granted
        mockService.setMockPermissionState(
          PermissionType.microphone,
          PermissionState.granted,
        );

        final result = await mockService.requestPermission(
          PermissionType.microphone,
        );

        expect(result.isGranted, isTrue);
        expect(result.state, equals(PermissionState.granted));
      });

      test('should handle permanently denied permissions', () async {
        await mockService.initialize();

        // Set permission to permanently denied
        mockService.setMockPermissionState(
          PermissionType.microphone,
          PermissionState.permanentlyDenied,
        );

        final result = await mockService.requestPermission(
          PermissionType.microphone,
        );

        expect(result.isGranted, isFalse);
        expect(result.isPermanentlyDenied, isTrue);
        expect(result.state, equals(PermissionState.permanentlyDenied));
      });

      test('should handle restricted permissions', () async {
        await mockService.initialize();

        // Set permission to restricted
        mockService.setMockPermissionState(
          PermissionType.microphone,
          PermissionState.restricted,
        );

        final result = await mockService.requestPermission(
          PermissionType.microphone,
        );

        expect(result.isGranted, isFalse);
        expect(result.errorMessage, contains('restricted'));
      });

      test('should request multiple permissions', () async {
        await mockService.initialize();

        mockService.setMockPermissionState(
          PermissionType.microphone,
          PermissionState.denied,
        );
        mockService.setMockPermissionState(
          PermissionType.storage,
          PermissionState.granted,
        );

        final results = await mockService.requestPermissions([
          PermissionType.microphone,
          PermissionType.storage,
        ]);

        expect(results[PermissionType.microphone]?.isGranted, isTrue);
        expect(results[PermissionType.storage]?.isGranted, isTrue);
      });
    });

    group('Permission State Monitoring', () {
      test('should emit permission state changes via stream', () async {
        await mockService.initialize();

        final stateChanges = <Map<PermissionType, PermissionState>>[];
        final subscription = mockService.permissionStateStream.listen(
          (states) => stateChanges.add(states),
        );

        // Simulate state change
        mockService.simulatePermissionChange(
          PermissionType.microphone,
          PermissionState.granted,
        );

        await Future.delayed(Duration(milliseconds: 10));
        await subscription.cancel();

        expect(stateChanges, isNotEmpty);
        expect(
          stateChanges.last[PermissionType.microphone],
          equals(PermissionState.granted),
        );
      });

      test('should handle stream errors gracefully', () async {
        await mockService.initialize();

        bool errorOccurred = false;
        final subscription = mockService.permissionStateStream.listen(
          (states) {
            // Normal state change
          },
          onError: (error) {
            errorOccurred = true;
          },
        );

        await Future.delayed(Duration(milliseconds: 10));
        await subscription.cancel();

        // Should not have errors in normal operation
        expect(errorOccurred, isFalse);
      });
    });

    group('Permission Analytics', () {
      test('should track request analytics', () async {
        await mockService.initialize();

        // Make multiple requests
        await mockService.requestPermission(PermissionType.microphone);
        await mockService.requestPermission(PermissionType.microphone);
        await mockService.requestPermission(PermissionType.storage);

        final analytics = mockService.getPermissionAnalytics();

        expect(analytics['totalRequests'], equals(3));
        expect(
          analytics['requestCounts']['PermissionType.microphone'],
          equals(2),
        );
        expect(analytics['requestCounts']['PermissionType.storage'], equals(1));
      });

      test('should calculate success rate correctly', () async {
        await mockService.initialize();

        // Set up different permission states
        mockService.setMockPermissionState(
          PermissionType.microphone,
          PermissionState.denied,
        );
        mockService.setMockPermissionState(
          PermissionType.storage,
          PermissionState.granted,
        );

        await mockService.requestPermission(PermissionType.microphone);
        await mockService.requestPermission(PermissionType.storage);

        final analytics = mockService.getPermissionAnalytics();

        expect(analytics, contains('successRate'));
        expect(analytics['successRate'], isA<double>());
        expect(analytics['successRate'], greaterThanOrEqualTo(0.0));
        expect(analytics['successRate'], lessThanOrEqualTo(100.0));
      });

      test('should reset tracking correctly', () async {
        await mockService.initialize();

        // Make some requests
        await mockService.requestPermission(PermissionType.microphone);
        await mockService.requestPermission(PermissionType.storage);

        var analytics = mockService.getPermissionAnalytics();
        expect(analytics['totalRequests'], equals(2));

        // Reset tracking
        mockService.resetPermissionTracking();

        analytics = mockService.getPermissionAnalytics();
        expect(analytics['totalRequests'], equals(0));
      });
    });

    group('Required Permissions', () {
      test('should identify missing required permissions', () async {
        await mockService.initialize();

        final missing = await mockService.getMissingRequiredPermissions();
        expect(missing, isA<List<PermissionType>>());
        expect(missing, contains(PermissionType.microphone));
      });

      test('should validate all required permissions', () async {
        await mockService.initialize();

        // Set microphone permission to granted (required permission)
        mockService.setMockPermissionState(
          PermissionType.microphone,
          PermissionState.granted,
        );

        final hasAll = await mockService.hasRequiredPermissions();
        expect(hasAll, isTrue);
      });

      test('should detect when required permissions are missing', () async {
        await mockService.initialize();

        // Keep microphone permission denied (it's required)
        mockService.setMockPermissionState(
          PermissionType.microphone,
          PermissionState.denied,
        );

        final hasAll = await mockService.hasRequiredPermissions();
        expect(hasAll, isFalse);
      });
    });

    group('Platform Information', () {
      test('should provide platform permission information', () {
        final info = mockService.getPlatformPermissionInfo(
          PermissionType.microphone,
        );

        expect(info, contains('permissionType'));
        expect(info, contains('platform'));
        expect(info, contains('isSupported'));
        expect(info, contains('settingsKey'));
        expect(info['platform'], equals('mock'));
        expect(info['isSupported'], isTrue);
      });

      test('should handle different permission types', () {
        for (final type in PermissionType.values) {
          final info = mockService.getPlatformPermissionInfo(type);
          expect(info, isA<Map<String, dynamic>>());
          expect(info['permissionType'], equals(type.toString()));
        }
      });
    });

    group('Error Handling', () {
      test('should throw when not initialized', () async {
        // Don't initialize the service

        expect(
          () => mockService.checkPermission(PermissionType.microphone),
          throwsA(isA<StateError>()),
        );

        expect(
          () => mockService.requestPermission(PermissionType.microphone),
          throwsA(isA<StateError>()),
        );
      });

      test('should handle unknown permission states', () async {
        await mockService.initialize();

        // Don't set any mock state, should return unknown
        final state = await mockService.checkPermission(
          PermissionType.notification,
        );
        expect(state, equals(PermissionState.unknown));
      });
    });

    group('Settings Integration', () {
      test('should open app settings successfully', () async {
        await mockService.initialize();

        final result = await mockService.openAppSettings();
        expect(result, isTrue);
      });

      test(
        'should show rationale for previously requested permissions',
        () async {
          await mockService.initialize();

          // First request
          await mockService.requestPermission(PermissionType.microphone);

          // Should show rationale for subsequent requests
          final shouldShow = await mockService.shouldShowRationale(
            PermissionType.microphone,
          );
          expect(shouldShow, isTrue);
        },
      );

      test(
        'should not show rationale for never requested permissions',
        () async {
          await mockService.initialize();

          // Never requested permission
          final shouldShow = await mockService.shouldShowRationale(
            PermissionType.notification,
          );
          expect(shouldShow, isFalse);
        },
      );
    });
  });
}
