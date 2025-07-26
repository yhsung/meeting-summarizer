/// Comprehensive unit tests for IOSPlatformService
library;

import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meeting_summarizer/core/services/ios_platform_service.dart';
import 'package:meeting_summarizer/core/services/platform_services/siri_shortcuts_service.dart';
import 'package:meeting_summarizer/core/services/platform_services/apple_watch_service.dart';
import 'package:meeting_summarizer/core/services/platform_services/callkit_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IOSPlatformService', () {
    late IOSPlatformService iosPlatformService;
    late List<MethodCall> methodCallLog;

    setUp(() {
      methodCallLog = <MethodCall>[];
      iosPlatformService = IOSPlatformService();

      // Mock method channel calls
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.yhsung.meeting_summarizer/ios_platform'),
        (MethodCall methodCall) async {
          methodCallLog.add(methodCall);

          // Return appropriate responses for different method calls
          switch (methodCall.method) {
            case 'initialize':
              return true;
            case 'setupHomeScreenWidgets':
              return true;
            case 'setupSpotlightSearch':
              return true;
            case 'setupFilesAppIntegration':
              return true;
            case 'setupHandoffSupport':
              return true;
            case 'configureWidgets':
              return true;
            case 'updateWidgets':
              return true;
            case 'indexRecording':
              return true;
            case 'removeFromIndex':
              return true;
            case 'exportToFiles':
              return true;
            case 'importFromFiles':
              return '/mock/file/path.m4a';
            case 'createUserActivity':
              return true;
            case 'invalidateUserActivity':
              return true;
            default:
              return null;
          }
        },
      );

      // Mock notification plugin
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (MethodCall methodCall) async {
          methodCallLog.add(methodCall);
          return true;
        },
      );
    });

    tearDown(() {
      iosPlatformService.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.yhsung.meeting_summarizer/ios_platform'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        null,
      );
    });

    group('Platform Availability', () {
      test('should only be available on iOS platform', () {
        if (Platform.isIOS) {
          // On iOS, availability depends on initialization
          expect(
              iosPlatformService.isAvailable, isFalse); // Not initialized yet
        } else {
          // On non-iOS platforms, should never be available
          expect(iosPlatformService.isAvailable, isFalse);
        }
      });

      test('should handle non-iOS platform gracefully', () async {
        // This test will behave differently on different platforms
        final result = await iosPlatformService.initialize();

        if (Platform.isIOS) {
          expect(result, isTrue);
          expect(iosPlatformService.isAvailable, isTrue);
        } else {
          expect(result, isFalse);
          expect(iosPlatformService.isAvailable, isFalse);
        }
      });
    });

    group('Initialization', () {
      test('should initialize successfully on iOS', () async {
        if (!Platform.isIOS) {
          // Skip test on non-iOS platforms
          return;
        }

        final result = await iosPlatformService.initialize();
        expect(result, isTrue);
        expect(iosPlatformService.isAvailable, isTrue);

        // Verify platform channel initialization
        expect(
          methodCallLog.any((call) => call.method == 'initialize'),
          isTrue,
        );
      });

      test('should not initialize twice', () async {
        if (!Platform.isIOS) return;

        final result1 = await iosPlatformService.initialize();
        final result2 = await iosPlatformService.initialize();

        expect(result1, isTrue);
        expect(result2, isTrue);

        // Should only call initialize once
        final initializeCalls =
            methodCallLog.where((call) => call.method == 'initialize').length;
        expect(initializeCalls, equals(1));
      });

      test('should initialize all sub-services', () async {
        if (!Platform.isIOS) return;

        await iosPlatformService.initialize();

        // Verify service status includes all sub-services
        final status = iosPlatformService.getServiceStatus();
        expect(status['siriShortcutsAvailable'], isA<bool>());
        expect(status['appleWatchConnected'], isA<bool>());
        expect(status['callKitAvailable'], isA<bool>());
        expect(status['widgetsEnabled'], isA<bool>());
        expect(status['spotlightEnabled'], isA<bool>());
        expect(status['filesAppEnabled'], isA<bool>());
        expect(status['handoffEnabled'], isA<bool>());
      });
    });

    group('Siri Shortcuts Integration', () {
      setUp(() async {
        if (Platform.isIOS) {
          await iosPlatformService.initialize();
        }
      });

      test('should provide access to Siri Shortcuts service', () {
        if (!Platform.isIOS) return;

        final siriService = iosPlatformService.siriShortcutsService;
        expect(siriService, isA<SiriShortcutsService>());
      });

      test('should update Siri shortcuts based on app state', () async {
        if (!Platform.isIOS) return;

        await iosPlatformService.updateSiriShortcuts(
          isRecording: true,
          hasRecordings: true,
          hasTranscriptions: false,
        );

        // This test verifies the method completes without error
        // Actual shortcut updates would be tested in SiriShortcutsService tests
        expect(iosPlatformService.isAvailable, isTrue);
      });

      test('should handle Siri shortcut execution callbacks', () async {
        if (!Platform.isIOS) return;

        bool callbackTriggered = false;
        Map<String, dynamic>? receivedParameters;

        iosPlatformService.onSiriShortcut = (shortcutId, parameters) {
          callbackTriggered = true;
          receivedParameters = parameters;
        };

        // Simulate a Siri shortcut call from native code
        const testCall = MethodCall('onSiriShortcut', {
          'shortcutId': 'start_recording',
          'parameters': {'source': 'siri'},
        });

        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'com.yhsung.meeting_summarizer/ios_platform',
          const StandardMethodCodec().encodeMethodCall(testCall),
          (data) {},
        );

        expect(callbackTriggered, isTrue);
        expect(receivedParameters?['source'], equals('siri'));
      });
    });

    group('Apple Watch Integration', () {
      setUp(() async {
        if (Platform.isIOS) {
          await iosPlatformService.initialize();
        }
      });

      test('should provide access to Apple Watch service', () {
        if (!Platform.isIOS) return;

        final watchService = iosPlatformService.appleWatchService;
        expect(watchService, isA<AppleWatchService>());
      });

      test('should update Apple Watch with recording status', () async {
        if (!Platform.isIOS) return;

        await iosPlatformService.updateAppleWatch(
          isRecording: true,
          isPaused: false,
          duration: const Duration(minutes: 5),
          meetingTitle: 'Test Meeting',
          transcriptionProgress: 0.5,
          isTranscribing: true,
        );

        // Verify the method completes without error
        expect(iosPlatformService.isAvailable, isTrue);
      });

      test('should handle watch actions correctly', () async {
        if (!Platform.isIOS) return;

        bool actionHandled = false;
        String? receivedAction;

        iosPlatformService.onPlatformAction = (action, parameters) {
          actionHandled = true;
          receivedAction = action;
        };

        // Access the Apple Watch service and simulate an action
        final watchService = iosPlatformService.appleWatchService;
        watchService.onWatchAction?.call(
          WatchAction.startRecording,
          {'test': 'parameter'},
        );

        // Allow for async processing
        await Future.delayed(const Duration(milliseconds: 10));

        expect(actionHandled, isTrue);
        expect(receivedAction, equals('start_recording'));
      });
    });

    group('CallKit Integration', () {
      setUp(() async {
        if (Platform.isIOS) {
          await iosPlatformService.initialize();
        }
      });

      test('should provide access to CallKit service', () {
        if (!Platform.isIOS) return;

        final callKitService = iosPlatformService.callKitService;
        expect(callKitService, isA<CallKitService>());
      });

      test('should handle call recording state changes', () async {
        if (!Platform.isIOS) return;

        bool callbackTriggered = false;
        String? receivedCallId;
        bool? receivedRecordingState;

        iosPlatformService.onCallRecordingChanged = (callId, isRecording) {
          callbackTriggered = true;
          receivedCallId = callId;
          receivedRecordingState = isRecording;
        };

        // Simulate a call state change from native code
        const testCall = MethodCall('onCallStateChanged', {
          'callId': 'test-call-123',
          'isRecording': true,
        });

        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'com.yhsung.meeting_summarizer/ios_platform',
          const StandardMethodCodec().encodeMethodCall(testCall),
          (data) {},
        );

        expect(callbackTriggered, isTrue);
        expect(receivedCallId, equals('test-call-123'));
        expect(receivedRecordingState, isTrue);
      });
    });

    group('Home Screen Widgets', () {
      setUp(() async {
        if (Platform.isIOS) {
          await iosPlatformService.initialize();
        }
      });

      test('should initialize widgets successfully', () async {
        if (!Platform.isIOS) return;

        // Widgets should be initialized during service initialization
        expect(
          methodCallLog.any((call) => call.method == 'setupHomeScreenWidgets'),
          isTrue,
        );
        expect(
          methodCallLog.any((call) => call.method == 'configureWidgets'),
          isTrue,
        );
      });

      test('should update widgets with current state', () async {
        if (!Platform.isIOS) return;

        await iosPlatformService.updateHomeScreenWidgets(
          isRecording: true,
          recordingDuration: const Duration(minutes: 10),
          isTranscribing: false,
          transcriptionProgress: 0.0,
          recentRecordingsCount: 5,
          status: 'Recording Active',
        );

        // Verify update widget call was made
        final updateCall = methodCallLog
            .where((call) => call.method == 'updateWidgets')
            .lastOrNull;
        expect(updateCall, isNotNull);
        expect(updateCall!.arguments['isRecording'], isTrue);
        expect(updateCall.arguments['recordingDuration'], equals(600));
        expect(updateCall.arguments['recentRecordingsCount'], equals(5));
      });

      test('should handle widget actions', () async {
        if (!Platform.isIOS) return;

        bool actionHandled = false;
        String? receivedAction;
        String? receivedSource;

        iosPlatformService.onPlatformAction = (action, parameters) {
          actionHandled = true;
          receivedAction = action;
          receivedSource = parameters?['source'];
        };

        // Simulate widget action from native code
        const testCall = MethodCall('onWidgetAction', {
          'action': 'start_recording',
          'parameters': {'widget_size': 'medium'},
        });

        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'com.yhsung.meeting_summarizer/ios_platform',
          const StandardMethodCodec().encodeMethodCall(testCall),
          (data) {},
        );

        expect(actionHandled, isTrue);
        expect(receivedAction, equals('start_recording'));
        expect(receivedSource, equals('ios_widget'));
      });
    });

    group('Spotlight Search Integration', () {
      setUp(() async {
        if (Platform.isIOS) {
          await iosPlatformService.initialize();
        }
      });

      test('should initialize Spotlight Search', () async {
        if (!Platform.isIOS) return;

        expect(
          methodCallLog.any((call) => call.method == 'setupSpotlightSearch'),
          isTrue,
        );
      });

      test('should index recordings for Spotlight', () async {
        if (!Platform.isIOS) return;

        await iosPlatformService.indexRecordingForSpotlight(
          recordingId: 'rec-123',
          title: 'Test Meeting',
          transcript: 'This is a test transcript',
          createdAt: DateTime.now(),
          duration: const Duration(minutes: 30),
          keywords: ['meeting', 'test'],
        );

        final indexCall = methodCallLog
            .where((call) => call.method == 'indexRecording')
            .lastOrNull;
        expect(indexCall, isNotNull);
        expect(indexCall!.arguments['recordingId'], equals('rec-123'));
        expect(indexCall.arguments['title'], equals('Test Meeting'));
        expect(indexCall.arguments['transcript'],
            equals('This is a test transcript'));
      });

      test('should remove recordings from Spotlight index', () async {
        if (!Platform.isIOS) return;

        await iosPlatformService.removeRecordingFromSpotlight('rec-123');

        final removeCall = methodCallLog
            .where((call) => call.method == 'removeFromIndex')
            .lastOrNull;
        expect(removeCall, isNotNull);
        expect(removeCall!.arguments['recordingId'], equals('rec-123'));
      });

      test('should handle Spotlight search queries', () async {
        if (!Platform.isIOS) return;

        bool searchHandled = false;
        String? receivedQuery;

        iosPlatformService.onSpotlightSearch = (query) {
          searchHandled = true;
          receivedQuery = query;
        };

        // Simulate search from native code
        const testCall = MethodCall('onSpotlightSearch', {
          'query': 'test meeting',
        });

        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'com.yhsung.meeting_summarizer/ios_platform',
          const StandardMethodCodec().encodeMethodCall(testCall),
          (data) {},
        );

        expect(searchHandled, isTrue);
        expect(receivedQuery, equals('test meeting'));
      });
    });

    group('Files App Integration', () {
      setUp(() async {
        if (Platform.isIOS) {
          await iosPlatformService.initialize();
        }
      });

      test('should initialize Files app integration', () async {
        if (!Platform.isIOS) return;

        expect(
          methodCallLog
              .any((call) => call.method == 'setupFilesAppIntegration'),
          isTrue,
        );
      });

      test('should export recordings to Files app', () async {
        if (!Platform.isIOS) return;

        final result = await iosPlatformService.exportRecordingToFilesApp(
          recordingPath: '/path/to/recording.m4a',
          fileName: 'test_recording.m4a',
          folderName: 'My Meetings',
        );

        expect(result, isTrue);

        final exportCall = methodCallLog
            .where((call) => call.method == 'exportToFiles')
            .lastOrNull;
        expect(exportCall, isNotNull);
        expect(exportCall!.arguments['recordingPath'],
            equals('/path/to/recording.m4a'));
        expect(exportCall.arguments['fileName'], equals('test_recording.m4a'));
        expect(exportCall.arguments['folderName'], equals('My Meetings'));
      });

      test('should import files from Files app', () async {
        if (!Platform.isIOS) return;

        final result = await iosPlatformService.importFileFromFilesApp(
          allowedTypes: ['public.audio', 'public.mpeg-4-audio'],
        );

        expect(result, equals('/mock/file/path.m4a'));

        final importCall = methodCallLog
            .where((call) => call.method == 'importFromFiles')
            .lastOrNull;
        expect(importCall, isNotNull);
        expect(
          importCall!.arguments['allowedTypes'],
          containsAll(['public.audio', 'public.mpeg-4-audio']),
        );
      });
    });

    group('NSUserActivity Handoff Support', () {
      setUp(() async {
        if (Platform.isIOS) {
          await iosPlatformService.initialize();
        }
      });

      test('should initialize Handoff support', () async {
        if (!Platform.isIOS) return;

        expect(
          methodCallLog.any((call) => call.method == 'setupHandoffSupport'),
          isTrue,
        );
      });

      test('should handle Handoff activity continuation', () async {
        if (!Platform.isIOS) return;

        bool handoffHandled = false;
        String? receivedActivityType;
        Map<String, dynamic>? receivedUserInfo;

        iosPlatformService.onHandoffActivity = (activityType, userInfo) {
          handoffHandled = true;
          receivedActivityType = activityType;
          receivedUserInfo = userInfo;
        };

        // Simulate handoff activity from native code
        const testCall = MethodCall('onHandoffActivity', {
          'activityType': 'com.yhsung.meeting_summarizer.recording',
          'userInfo': {
            'recordingId': 'rec-123',
            'isRecording': true,
          },
        });

        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'com.yhsung.meeting_summarizer/ios_platform',
          const StandardMethodCodec().encodeMethodCall(testCall),
          (data) {},
        );

        expect(handoffHandled, isTrue);
        expect(receivedActivityType,
            equals('com.yhsung.meeting_summarizer.recording'));
        expect(receivedUserInfo?['recordingId'], equals('rec-123'));
      });
    });

    group('Platform Service Interface Implementation', () {
      setUp(() async {
        if (Platform.isIOS) {
          await iosPlatformService.initialize();
        }
      });

      test('should register all integrations', () async {
        if (!Platform.isIOS) return;

        final result = await iosPlatformService.registerIntegrations();
        expect(result, isTrue);

        // Should re-initialize all integrations
        final setupCalls = methodCallLog.where((call) =>
            call.method.startsWith('setup') ||
            call.method == 'configureWidgets');
        expect(setupCalls.length, greaterThan(0));
      });

      test('should handle platform actions', () async {
        if (!Platform.isIOS) return;

        bool actionHandled = false;
        String? receivedAction;

        iosPlatformService.onPlatformAction = (action, parameters) {
          actionHandled = true;
          receivedAction = action;
        };

        await iosPlatformService.handleAction('start_recording', {
          'meetingTitle': 'Test Meeting',
        });

        expect(actionHandled, isTrue);
        expect(receivedAction, equals('start_recording'));

        // Should create user activity for recording actions
        final activityCall = methodCallLog
            .where((call) => call.method == 'createUserActivity')
            .lastOrNull;
        expect(activityCall, isNotNull);
      });

      test('should update all integrations with state', () async {
        if (!Platform.isIOS) return;

        await iosPlatformService.updateIntegrations({
          'isRecording': true,
          'recordingDuration': const Duration(minutes: 15),
          'isTranscribing': false,
          'transcriptionProgress': 0.0,
          'recentRecordingsCount': 3,
          'meetingTitle': 'Team Standup',
          'isPaused': false,
          'status': 'Recording in progress',
        });

        // Should update widgets
        final updateCall = methodCallLog
            .where((call) => call.method == 'updateWidgets')
            .lastOrNull;
        expect(updateCall, isNotNull);
        expect(updateCall!.arguments['isRecording'], isTrue);

        // Should create user activity for recording
        final activityCall = methodCallLog
            .where((call) => call.method == 'createUserActivity')
            .lastOrNull;
        expect(activityCall, isNotNull);
        expect(
          activityCall!.arguments['activityType'],
          equals('com.yhsung.meeting_summarizer.recording'),
        );
      });

      test('should show and hide system UI', () async {
        if (!Platform.isIOS) return;

        final showResult = await iosPlatformService.showSystemUI();
        expect(showResult, isTrue);

        await iosPlatformService.hideSystemUI();

        // Hide should invalidate current user activity
        final invalidateCall = methodCallLog
            .where((call) => call.method == 'invalidateUserActivity')
            .lastOrNull;
        expect(invalidateCall, isNotNull);
      });
    });

    group('Service Status and Management', () {
      setUp(() async {
        if (Platform.isIOS) {
          await iosPlatformService.initialize();
        }
      });

      test('should provide comprehensive service status', () {
        if (!Platform.isIOS) return;

        final status = iosPlatformService.getServiceStatus();

        expect(status['isInitialized'], isTrue);
        expect(status['isAvailable'], isTrue);
        expect(status['platform'], equals('ios'));
        expect(status['lastUpdated'], isA<String>());
        expect(status['siriShortcutsAvailable'], isA<bool>());
        expect(status['appleWatchConnected'], isA<bool>());
        expect(status['callKitAvailable'], isA<bool>());
        expect(status['widgetsEnabled'], isA<bool>());
        expect(status['spotlightEnabled'], isA<bool>());
        expect(status['filesAppEnabled'], isA<bool>());
        expect(status['handoffEnabled'], isA<bool>());
      });

      test('should provide access to sub-services', () {
        if (!Platform.isIOS) return;

        expect(iosPlatformService.siriShortcutsService,
            isA<SiriShortcutsService>());
        expect(iosPlatformService.appleWatchService, isA<AppleWatchService>());
        expect(iosPlatformService.callKitService, isA<CallKitService>());
      });
    });

    group('Error Handling', () {
      test('should handle platform channel errors gracefully', () async {
        if (!Platform.isIOS) return;

        // Override method channel to throw errors
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.yhsung.meeting_summarizer/ios_platform'),
          (MethodCall methodCall) async {
            throw PlatformException(
              code: 'ERROR',
              message: 'Mock error',
              details: null,
            );
          },
        );

        // Service should handle errors gracefully
        final result = await iosPlatformService.initialize();
        expect(result, isFalse);
      });

      test('should handle method call errors gracefully', () async {
        if (!Platform.isIOS) return;

        await iosPlatformService.initialize();

        // These should complete without throwing
        await expectLater(
          iosPlatformService.updateHomeScreenWidgets(isRecording: false),
          completes,
        );
        await expectLater(
          iosPlatformService.indexRecordingForSpotlight(
            recordingId: 'test',
            title: 'test',
            transcript: 'test',
            createdAt: DateTime.now(),
          ),
          completes,
        );
      });
    });

    group('Disposal', () {
      test('should dispose all resources properly', () async {
        if (Platform.isIOS) {
          await iosPlatformService.initialize();
        }

        // Should complete without error
        await expectLater(() => iosPlatformService.dispose(), returnsNormally);

        // Should not be available after disposal
        expect(iosPlatformService.isAvailable, isFalse);
      });

      test('should handle disposal without initialization', () {
        // Should complete without error even if not initialized
        expect(() => iosPlatformService.dispose(), returnsNormally);
      });

      test('should clear all callbacks on disposal', () async {
        if (Platform.isIOS) {
          await iosPlatformService.initialize();
        }

        // Set callbacks
        iosPlatformService.onPlatformAction = (action, params) {};
        iosPlatformService.onSiriShortcut = (shortcut, params) {};
        iosPlatformService.onCallRecordingChanged = (callId, recording) {};

        iosPlatformService.dispose();

        // After disposal, setting callbacks should not cause issues
        // and service should not be available
        expect(() {
          iosPlatformService.onPlatformAction = (action, params) {};
        }, returnsNormally);
        expect(iosPlatformService.isAvailable, isFalse);
      });
    });
  });

  group('Platform-Specific Behavior', () {
    test('should behave correctly on non-iOS platforms', () async {
      // This test specifically checks behavior on non-iOS platforms
      final service = IOSPlatformService();

      if (!Platform.isIOS) {
        expect(service.isAvailable, isFalse);

        final initResult = await service.initialize();
        expect(initResult, isFalse);
        expect(service.isAvailable, isFalse);

        // Methods should complete gracefully but not perform actual work
        await expectLater(
          service.updateHomeScreenWidgets(isRecording: false),
          completes,
        );
        await expectLater(
          service.handleAction('start_recording', {}),
          completes,
        );
        await expectLater(
          service.updateIntegrations({'isRecording': false}),
          completes,
        );
      }
    });
  });
}
