import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/calendar/meeting_context.dart';
import '../../../../core/services/calendar_integration_service.dart';

/// Widget for displaying upcoming meetings from calendar integration
class UpcomingMeetingsWidget extends StatefulWidget {
  final CalendarIntegrationService calendarService;
  final Function(MeetingContext)? onMeetingTap;
  final Function(MeetingContext)? onRecordingStart;

  const UpcomingMeetingsWidget({
    super.key,
    required this.calendarService,
    this.onMeetingTap,
    this.onRecordingStart,
  });

  @override
  State<UpcomingMeetingsWidget> createState() => _UpcomingMeetingsWidgetState();
}

class _UpcomingMeetingsWidgetState extends State<UpcomingMeetingsWidget> {
  List<MeetingContext> _meetings = [];
  bool _isLoading = false;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMeetings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final meetings = await widget.calendarService.getUpcomingMeetings();
      setState(() {
        _meetings = meetings;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildMeetingCard(MeetingContext meeting) {
    final event = meeting.event;
    final now = DateTime.now();
    final timeUntilMeeting = event.startTime.difference(now);
    final isStartingSoon =
        timeUntilMeeting.inMinutes <= 15 && timeUntilMeeting.inMinutes > 0;
    final isActive = event.isActive;
    final isPast = event.isPast;

    Color cardColor = Colors.white;
    Color borderColor = Colors.grey.shade300;

    if (isActive) {
      cardColor = Colors.green.shade50;
      borderColor = Colors.green;
    } else if (isStartingSoon) {
      cardColor = Colors.orange.shade50;
      borderColor = Colors.orange;
    } else if (isPast) {
      cardColor = Colors.grey.shade50;
      borderColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: InkWell(
        onTap: () => widget.onMeetingTap?.call(meeting),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isPast ? Colors.grey.shade600 : null,
                          ),
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (isStartingSoon && !isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${timeUntilMeeting.inMinutes}m',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatMeetingTime(event.startTime, event.endTime),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (event.location != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.location!,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (meeting.participants.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.people,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${meeting.participants.length} attendees',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
              if (meeting.virtualMeetingInfo != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.videocam,
                      size: 16,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatVirtualPlatform(
                          meeting.virtualMeetingInfo!.platform),
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              if (meeting.shouldAutoRecord) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.fiber_manual_record,
                      size: 16,
                      color: Colors.red.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Auto-recording enabled',
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (meeting.detectionConfidence > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getConfidenceColor(meeting.detectionConfidence),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(meeting.detectionConfidence * 100).round()}% confidence',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getMeetingTypeColor(meeting.type),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatMeetingType(meeting.type),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!isPast && widget.onRecordingStart != null)
                    IconButton(
                      onPressed: () => widget.onRecordingStart?.call(meeting),
                      icon: Icon(
                        Icons.fiber_manual_record,
                        color: Colors.red.shade600,
                      ),
                      tooltip: 'Start Recording',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMeetingTime(DateTime start, DateTime end) {
    final formatter = DateFormat('MMM d, h:mm a');
    final timeFormatter = DateFormat('h:mm a');

    if (start.day == end.day) {
      return '${formatter.format(start)} - ${timeFormatter.format(end)}';
    } else {
      return '${formatter.format(start)} - ${formatter.format(end)}';
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

  String _formatMeetingType(MeetingType type) {
    switch (type) {
      case MeetingType.standup:
        return 'Standup';
      case MeetingType.oneOnOne:
        return '1:1';
      case MeetingType.teamMeeting:
        return 'Team';
      case MeetingType.presentation:
        return 'Presentation';
      case MeetingType.interview:
        return 'Interview';
      case MeetingType.training:
        return 'Training';
      case MeetingType.brainstorming:
        return 'Brainstorm';
      case MeetingType.retrospective:
        return 'Retro';
      case MeetingType.planning:
        return 'Planning';
      case MeetingType.review:
        return 'Review';
      case MeetingType.other:
        return 'Meeting';
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  Color _getMeetingTypeColor(MeetingType type) {
    switch (type) {
      case MeetingType.standup:
        return Colors.blue;
      case MeetingType.oneOnOne:
        return Colors.purple;
      case MeetingType.teamMeeting:
        return Colors.teal;
      case MeetingType.presentation:
        return Colors.indigo;
      case MeetingType.interview:
        return Colors.orange;
      case MeetingType.training:
        return Colors.green;
      case MeetingType.brainstorming:
        return Colors.amber;
      case MeetingType.retrospective:
        return Colors.deepPurple;
      case MeetingType.planning:
        return Colors.brown;
      case MeetingType.review:
        return Colors.cyan;
      case MeetingType.other:
        return Colors.grey;
    }
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No upcoming meetings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect your calendar accounts to see upcoming meetings here.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              'Error loading meetings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.red.shade600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error occurred',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMeetings,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.upcoming),
                const SizedBox(width: 8),
                Text(
                  'Upcoming Meetings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    onPressed: _loadMeetings,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading && _meetings.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _buildErrorState()
            else if (_meetings.isEmpty)
              _buildEmptyState()
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: Scrollbar(
                  controller: _scrollController,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _meetings.length,
                    itemBuilder: (context, index) {
                      return _buildMeetingCard(_meetings[index]);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
