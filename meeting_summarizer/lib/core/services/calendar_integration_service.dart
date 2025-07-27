import 'dart:async';
import 'dart:developer';
import '../enums/calendar_provider.dart';
import '../interfaces/calendar_service_interface.dart';
import '../models/calendar/calendar_event.dart';
import '../models/calendar/meeting_context.dart';
import '../models/database/recording.dart';
import '../models/database/summary.dart';
import '../models/database/transcription.dart';
import 'calendar_services/calendar_service_factory.dart';
import 'calendar_services/meeting_detection_service.dart';
import 'calendar_services/meeting_context_extraction_service.dart';
import 'calendar_services/summary_distribution_service.dart';
import 'gdpr_compliance_service.dart';
import 'settings_service.dart';

/// Main service for calendar integration and meeting management
class CalendarIntegrationService {
  final SettingsService _settingsService;
  final GdprComplianceService _gdprService;

  late final MeetingDetectionService _meetingDetection;
  late final MeetingContextExtractionService _contextExtraction;
  late final SummaryDistributionService _summaryDistribution;

  final List<CalendarProvider> _enabledProviders = [];
  final Map<CalendarProvider, CalendarServiceInterface> _services = {};

  Timer? _meetingMonitorTimer;
  final StreamController<MeetingEvent> _meetingEventController =
      StreamController<MeetingEvent>.broadcast();

  bool _isInitialized = false;

  CalendarIntegrationService(this._settingsService, this._gdprService) {
    _meetingDetection = MeetingDetectionService();
    _contextExtraction = MeetingContextExtractionService();
    _summaryDistribution = SummaryDistributionService(_gdprService);
  }

  /// Stream of meeting events for real-time updates
  Stream<MeetingEvent> get meetingEventStream => _meetingEventController.stream;

  /// Initialize the calendar integration service
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      log('CalendarIntegrationService: Initializing calendar integration');

      // Load settings
      await _loadSettings();

      // Initialize services for enabled providers
      await _initializeCalendarServices();

      // Initialize summary distribution
      await _initializeSummaryDistribution();

      // Start meeting monitoring
      await _startMeetingMonitoring();

      _isInitialized = true;
      log('CalendarIntegrationService: Calendar integration initialized successfully');
    } catch (e) {
      log('CalendarIntegrationService: Failed to initialize: $e');
      rethrow;
    }
  }

  /// Get upcoming meetings across all enabled providers
  Future<List<MeetingContext>> getUpcomingMeetings({
    Duration? timeWindow,
  }) async {
    _ensureInitialized();

    final endTime = DateTime.now().add(timeWindow ?? const Duration(days: 7));
    final allEvents = <CalendarEvent>[];

    // Fetch events from all enabled providers
    for (final provider in _enabledProviders) {
      final service = _services[provider];
      if (service != null && service.isAuthenticated) {
        try {
          final events = await service.getEvents(
            startDate: DateTime.now(),
            endDate: endTime,
          );
          allEvents.addAll(events);
        } catch (e) {
          log('CalendarIntegrationService: Error fetching events from $provider: $e');
        }
      }
    }

    // Detect meetings
    final meetings = await _meetingDetection.detectMeetings(allEvents);

    log('CalendarIntegrationService: Found ${meetings.length} upcoming meetings');
    return meetings;
  }

  /// Get today's meetings
  Future<List<MeetingContext>> getTodaysMeetings() async {
    return getUpcomingMeetings(timeWindow: const Duration(days: 1));
  }

  /// Get meeting context for a specific event
  Future<MeetingContext?> getMeetingContext(CalendarEvent event) async {
    _ensureInitialized();

    try {
      final meetingContext = await _meetingDetection.detectMeeting(event);
      if (meetingContext != null) {
        return await _contextExtraction.extractMeetingContext(
          event,
          meetingContext.detectionConfidence,
        );
      }
      return null;
    } catch (e) {
      log('CalendarIntegrationService: Error getting meeting context: $e');
      return null;
    }
  }

  /// Search for meetings across all providers
  Future<List<MeetingContext>> searchMeetings({
    required String query,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _ensureInitialized();

    final allEvents = <CalendarEvent>[];

    // Search across all enabled providers
    for (final provider in _enabledProviders) {
      final service = _services[provider];
      if (service != null && service.isAuthenticated) {
        try {
          final events = await service.searchEvents(
            query: query,
            startDate: startDate,
            endDate: endDate,
          );
          allEvents.addAll(events);
        } catch (e) {
          log('CalendarIntegrationService: Error searching events in $provider: $e');
        }
      }
    }

    // Detect meetings in search results
    final meetings = await _meetingDetection.detectMeetings(allEvents);

    log('CalendarIntegrationService: Found ${meetings.length} meetings matching query "$query"');
    return meetings;
  }

  /// Distribute meeting summary to attendees
  Future<bool> distributeMeetingSummary({
    required MeetingContext meetingContext,
    required Summary summary,
    Transcription? transcription,
    Recording? recording,
    List<String>? customRecipients,
  }) async {
    _ensureInitialized();

    try {
      final result = await _summaryDistribution.distributeSummary(
        meetingContext: meetingContext,
        summary: summary,
        transcription: transcription,
        recording: recording,
        customRecipients: customRecipients,
      );

      if (result.success) {
        _meetingEventController.add(MeetingEvent(
          type: MeetingEventType.summaryDistributed,
          meetingContext: meetingContext,
          message:
              'Summary distributed to ${result.distributedTo.length} recipients',
        ));
      }

      return result.success;
    } catch (e) {
      log('CalendarIntegrationService: Error distributing summary: $e');
      return false;
    }
  }

  /// Configure calendar provider
  Future<bool> configureProvider({
    required CalendarProvider provider,
    required Map<String, dynamic> config,
  }) async {
    try {
      log('CalendarIntegrationService: Configuring $provider');

      final service = CalendarServiceFactory.getService(provider);

      if (!service.validateConfiguration(config)) {
        log('CalendarIntegrationService: Invalid configuration for $provider');
        return false;
      }

      await service.initialize(config);

      if (provider.requiresOAuth) {
        final authSuccess = await service.authenticate();
        if (!authSuccess) {
          log('CalendarIntegrationService: Authentication failed for $provider');
          return false;
        }
      }

      _services[provider] = service;
      if (!_enabledProviders.contains(provider)) {
        _enabledProviders.add(provider);
      }

      // Save configuration
      await _saveProviderSettings(provider, config);

      log('CalendarIntegrationService: Successfully configured $provider');
      return true;
    } catch (e) {
      log('CalendarIntegrationService: Error configuring $provider: $e');
      return false;
    }
  }

  /// Disconnect from a calendar provider
  Future<void> disconnectProvider(CalendarProvider provider) async {
    try {
      final service = _services[provider];
      if (service != null) {
        await service.disconnect();
        _services.remove(provider);
      }

      _enabledProviders.remove(provider);
      await _removeProviderSettings(provider);

      log('CalendarIntegrationService: Disconnected from $provider');
    } catch (e) {
      log('CalendarIntegrationService: Error disconnecting from $provider: $e');
    }
  }

  /// Get authentication status for all providers
  Map<CalendarProvider, bool> getAuthenticationStatus() {
    final status = <CalendarProvider, bool>{};

    for (final provider in CalendarProvider.values) {
      final service = _services[provider];
      status[provider] = service?.isAuthenticated ?? false;
    }

    return status;
  }

  /// Configure meeting detection rules
  void configureMeetingDetection(MeetingDetectionRules rules) {
    _meetingDetection.configureMeetingRules(rules);
    log('CalendarIntegrationService: Updated meeting detection rules');
  }

  /// Get meeting detection statistics
  MeetingDetectionStats getMeetingDetectionStats() {
    return _meetingDetection.getDetectionStats();
  }

  /// Load settings from storage
  Future<void> _loadSettings() async {
    try {
      // Load enabled providers
      final enabledProviderNames = await _settingsService.getStringList(
        'calendar_enabled_providers',
        defaultValue: [],
      );

      _enabledProviders.clear();
      for (final name in enabledProviderNames) {
        try {
          final provider = CalendarProvider.values.firstWhere(
            (p) => p.identifier == name,
          );
          _enabledProviders.add(provider);
        } catch (e) {
          log('CalendarIntegrationService: Unknown provider: $name');
        }
      }

      log('CalendarIntegrationService: Loaded ${_enabledProviders.length} enabled providers');
    } catch (e) {
      log('CalendarIntegrationService: Error loading settings: $e');
    }
  }

  /// Initialize calendar services for enabled providers
  Future<void> _initializeCalendarServices() async {
    for (final provider in _enabledProviders) {
      try {
        final config = await _loadProviderSettings(provider);
        if (config.isNotEmpty) {
          await configureProvider(provider: provider, config: config);
        }
      } catch (e) {
        log('CalendarIntegrationService: Error initializing $provider: $e');
      }
    }
  }

  /// Initialize summary distribution service
  Future<void> _initializeSummaryDistribution() async {
    try {
      final smtpConfig = await _loadSmtpSettings();
      if (smtpConfig.isNotEmpty) {
        await _summaryDistribution.initialize(smtpConfig);
      }
    } catch (e) {
      log('CalendarIntegrationService: Error initializing summary distribution: $e');
    }
  }

  /// Start monitoring for upcoming meetings
  Future<void> _startMeetingMonitoring() async {
    final monitoringEnabled = await _settingsService.getBool(
      'calendar_meeting_monitoring_enabled',
      defaultValue: true,
    );

    if (monitoringEnabled) {
      _meetingMonitorTimer = Timer.periodic(
        const Duration(minutes: 5),
        _checkUpcomingMeetings,
      );
      log('CalendarIntegrationService: Started meeting monitoring');
    }
  }

  /// Check for upcoming meetings and trigger events
  Future<void> _checkUpcomingMeetings(Timer timer) async {
    try {
      final upcomingMeetings = await getUpcomingMeetings(
        timeWindow: const Duration(hours: 1),
      );

      for (final meeting in upcomingMeetings) {
        final timeUntilMeeting =
            meeting.event.startTime.difference(DateTime.now());

        // Trigger events for meetings starting soon
        if (timeUntilMeeting.inMinutes <= 15 &&
            timeUntilMeeting.inMinutes > 0) {
          _meetingEventController.add(MeetingEvent(
            type: MeetingEventType.meetingStartingSoon,
            meetingContext: meeting,
            message:
                'Meeting "${meeting.event.title}" starts in ${timeUntilMeeting.inMinutes} minutes',
          ));
        }

        // Trigger auto-recording if enabled
        if (meeting.shouldAutoRecord && timeUntilMeeting.inMinutes <= 5) {
          _meetingEventController.add(MeetingEvent(
            type: MeetingEventType.autoRecordingTriggered,
            meetingContext: meeting,
            message: 'Auto-recording triggered for "${meeting.event.title}"',
          ));
        }
      }
    } catch (e) {
      log('CalendarIntegrationService: Error checking upcoming meetings: $e');
    }
  }

  /// Load provider-specific settings
  Future<Map<String, dynamic>> _loadProviderSettings(
      CalendarProvider provider) async {
    try {
      final settingsKey = 'calendar_${provider.identifier}_config';
      final configJson = await _settingsService.getString(settingsKey);

      if (configJson != null && configJson.isNotEmpty) {
        // In a real implementation, you would parse JSON here
        // For now, return empty map
        return {};
      }

      return {};
    } catch (e) {
      log('CalendarIntegrationService: Error loading settings for $provider: $e');
      return {};
    }
  }

  /// Save provider-specific settings
  Future<void> _saveProviderSettings(
    CalendarProvider provider,
    Map<String, dynamic> config,
  ) async {
    try {
      final settingsKey = 'calendar_${provider.identifier}_config';
      // In a real implementation, you would serialize config to JSON
      await _settingsService.setString(settingsKey, 'config_placeholder');

      // Update enabled providers list
      final enabledProviderNames =
          _enabledProviders.map((p) => p.identifier).toList();
      await _settingsService.setStringList(
          'calendar_enabled_providers', enabledProviderNames);
    } catch (e) {
      log('CalendarIntegrationService: Error saving settings for $provider: $e');
    }
  }

  /// Remove provider settings
  Future<void> _removeProviderSettings(CalendarProvider provider) async {
    try {
      final settingsKey = 'calendar_${provider.identifier}_config';
      await _settingsService.remove(settingsKey);

      // Update enabled providers list
      final enabledProviderNames =
          _enabledProviders.map((p) => p.identifier).toList();
      await _settingsService.setStringList(
          'calendar_enabled_providers', enabledProviderNames);
    } catch (e) {
      log('CalendarIntegrationService: Error removing settings for $provider: $e');
    }
  }

  /// Load SMTP settings for summary distribution
  Future<Map<String, dynamic>> _loadSmtpSettings() async {
    try {
      // Load SMTP configuration from settings
      final smtpHost = await _settingsService.getString('smtp_host');
      final smtpPort =
          await _settingsService.getInt('smtp_port', defaultValue: 587);
      final smtpUsername = await _settingsService.getString('smtp_username');
      final smtpPassword = await _settingsService.getString('smtp_password');
      final senderEmail = await _settingsService.getString('sender_email');
      final senderName = await _settingsService.getString('sender_name');
      final useSsl =
          await _settingsService.getBool('smtp_use_ssl', defaultValue: true);

      if (smtpHost != null &&
          smtpUsername != null &&
          smtpPassword != null &&
          senderEmail != null) {
        return {
          'smtp_host': smtpHost,
          'smtp_port': smtpPort,
          'smtp_username': smtpUsername,
          'smtp_password': smtpPassword,
          'sender_email': senderEmail,
          'sender_name': senderName ?? 'Meeting Summarizer',
          'use_ssl': useSsl,
        };
      }

      return {};
    } catch (e) {
      log('CalendarIntegrationService: Error loading SMTP settings: $e');
      return {};
    }
  }

  /// Ensure service is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('CalendarIntegrationService not initialized');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _meetingMonitorTimer?.cancel();
    await _meetingEventController.close();

    for (final service in _services.values) {
      try {
        await service.disconnect();
      } catch (e) {
        log('CalendarIntegrationService: Error disconnecting service: $e');
      }
    }

    CalendarServiceFactory.dispose();
    log('CalendarIntegrationService: Disposed');
  }
}

/// Meeting event for real-time notifications
class MeetingEvent {
  final MeetingEventType type;
  final MeetingContext meetingContext;
  final String message;
  final DateTime timestamp;

  MeetingEvent({
    required this.type,
    required this.meetingContext,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Types of meeting events
enum MeetingEventType {
  meetingStartingSoon,
  autoRecordingTriggered,
  summaryDistributed,
  meetingDetected,
  meetingUpdated,
  meetingCancelled,
}
