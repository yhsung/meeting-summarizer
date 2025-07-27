import 'package:flutter/material.dart';
import '../../../../core/models/calendar/meeting_context.dart';
import '../../../../core/services/calendar_integration_service.dart';
import '../../../../core/services/gdpr_compliance_service.dart';
import '../../../../core/services/settings_service.dart';
import '../widgets/calendar_settings_widget.dart';
import '../widgets/upcoming_meetings_widget.dart';

/// Screen for calendar integration and meeting management
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  late final CalendarIntegrationService _calendarService;
  late final TabController _tabController;

  bool _isInitialized = false;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeServices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_isInitialized) {
      _calendarService.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      // In a real app, these would be injected via dependency injection
      final settingsService = SettingsService();
      final gdprService = GdprComplianceService();

      await settingsService.initialize();

      _calendarService =
          CalendarIntegrationService(settingsService, gdprService);
      await _calendarService.initialize();

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _initializationError = e.toString();
      });
    }
  }

  void _onMeetingTap(MeetingContext meeting) {
    _showMeetingDetails(meeting);
  }

  void _onRecordingStart(MeetingContext meeting) {
    _showRecordingDialog(meeting);
  }

  void _showMeetingDetails(MeetingContext meeting) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(meeting.event.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Type', _formatMeetingType(meeting.type)),
              _buildDetailRow(
                  'Duration', _formatDuration(meeting.expectedDuration)),
              _buildDetailRow('Attendees', '${meeting.participants.length}'),
              if (meeting.event.location != null)
                _buildDetailRow('Location', meeting.event.location!),
              if (meeting.virtualMeetingInfo != null)
                _buildDetailRow(
                    'Platform',
                    _formatVirtualPlatform(
                        meeting.virtualMeetingInfo!.platform)),
              _buildDetailRow('Confidence',
                  '${(meeting.detectionConfidence * 100).round()}%'),
              if (meeting.agendaItems.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Agenda:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...meeting.agendaItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Text('• $item'),
                  ),
                ),
              ],
              if (meeting.tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Tags:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: meeting.tags
                      .map(
                        (tag) => Chip(
                          label: Text(tag),
                          backgroundColor: Colors.blue.shade100,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (!meeting.event.isPast)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _onRecordingStart(meeting);
              },
              icon: const Icon(Icons.fiber_manual_record),
              label: const Text('Record'),
            ),
        ],
      ),
    );
  }

  void _showRecordingDialog(MeetingContext meeting) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Recording'),
        content: Text(
          'Start recording for "${meeting.event.title}"?\n\n'
          'This will begin audio recording and transcription for the meeting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Integrate with recording service
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Recording started for "${meeting.event.title}"'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: const Icon(Icons.fiber_manual_record),
            label: const Text('Start'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatMeetingType(MeetingType type) {
    switch (type) {
      case MeetingType.standup:
        return 'Daily Standup';
      case MeetingType.oneOnOne:
        return 'One-on-One';
      case MeetingType.teamMeeting:
        return 'Team Meeting';
      case MeetingType.presentation:
        return 'Presentation';
      case MeetingType.interview:
        return 'Interview';
      case MeetingType.training:
        return 'Training';
      case MeetingType.brainstorming:
        return 'Brainstorming';
      case MeetingType.retrospective:
        return 'Retrospective';
      case MeetingType.planning:
        return 'Planning';
      case MeetingType.review:
        return 'Review';
      case MeetingType.other:
        return 'Other';
    }
  }

  String _formatVirtualPlatform(VirtualPlatform platform) {
    switch (platform) {
      case VirtualPlatform.zoom:
        return 'Zoom';
      case VirtualPlatform.teams:
        return 'Microsoft Teams';
      case VirtualPlatform.meet:
        return 'Google Meet';
      case VirtualPlatform.webex:
        return 'Webex';
      case VirtualPlatform.skype:
        return 'Skype';
      case VirtualPlatform.other:
        return 'Virtual Meeting';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  Widget _buildErrorState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar Integration'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to Initialize',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.red.shade600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _initializationError ?? 'Unknown error occurred',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _initializationError = null;
                  });
                  _initializeServices();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar Integration'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing calendar services...'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initializationError != null) {
      return _buildErrorState();
    }

    if (!_isInitialized) {
      return _buildLoadingState();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar Integration'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.upcoming),
              text: 'Meetings',
            ),
            Tab(
              icon: Icon(Icons.settings),
              text: 'Settings',
            ),
            Tab(
              icon: Icon(Icons.analytics),
              text: 'Analytics',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Meetings Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: UpcomingMeetingsWidget(
              calendarService: _calendarService,
              onMeetingTap: _onMeetingTap,
              onRecordingStart: _onRecordingStart,
            ),
          ),

          // Settings Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: CalendarSettingsWidget(
              calendarService: _calendarService,
              onSettingsChanged: () {
                // Refresh meetings when settings change
                setState(() {});
              },
            ),
          ),

          // Analytics Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildAnalyticsTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    final stats = _calendarService.getMeetingDetectionStats();

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meeting Detection Statistics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildStatRow(
                    'Events Processed', stats.totalEventsProcessed.toString()),
                _buildStatRow(
                    'Meetings Detected', stats.meetingsDetected.toString()),
                _buildStatRow('Detection Rate',
                    '${(stats.detectionRate * 100).toStringAsFixed(1)}%'),
                _buildStatRow('Average Confidence',
                    '${(stats.averageConfidence * 100).toStringAsFixed(1)}%'),
                if (stats.lastProcessedAt != null)
                  _buildStatRow(
                      'Last Updated',
                      stats.lastProcessedAt!
                          .toLocal()
                          .toString()
                          .split('.')[0]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (stats.meetingTypeDistribution.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meeting Types Distribution',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ...stats.meetingTypeDistribution.entries.map(
                    (entry) => _buildStatRow(
                      _formatMeetingType(entry.key),
                      entry.value.toString(),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
