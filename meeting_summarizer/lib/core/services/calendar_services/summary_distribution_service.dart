import 'dart:developer';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../../models/calendar/meeting_context.dart';
import '../../models/database/recording.dart';
import '../../models/database/summary.dart';
import '../../models/database/transcription.dart';
import '../gdpr_compliance_service.dart';

/// Service for distributing meeting summaries to attendees
class SummaryDistributionService {
  final GdprComplianceService _gdprService;
  Map<String, dynamic> _smtpConfig = {};
  bool _isInitialized = false;

  SummaryDistributionService(this._gdprService);

  /// Initialize the distribution service with SMTP configuration
  Future<void> initialize(Map<String, dynamic> config) async {
    _smtpConfig = Map.from(config);

    if (!_validateSmtpConfig(_smtpConfig)) {
      throw ArgumentError(
          'Invalid SMTP configuration for summary distribution');
    }

    _isInitialized = true;
    log('SummaryDistributionService: Initialized with SMTP configuration');
  }

  /// Distribute meeting summary to attendees
  Future<DistributionResult> distributeSummary({
    required MeetingContext meetingContext,
    required Summary summary,
    Transcription? transcription,
    Recording? recording,
    List<String>? customRecipients,
  }) async {
    if (!_isInitialized) {
      throw StateError('Summary distribution service not initialized');
    }

    try {
      log('SummaryDistributionService: Distributing summary for meeting "${meetingContext.event.title}"');

      // Check GDPR compliance for data sharing
      final gdprCheckResult = await _checkGdprCompliance(
        meetingContext,
        customRecipients,
      );

      if (!gdprCheckResult.canShare) {
        return DistributionResult(
          success: false,
          error: 'GDPR compliance check failed: ${gdprCheckResult.reason}',
          distributedTo: [],
          failedDeliveries: [],
        );
      }

      // Determine recipients
      final recipients = _determineRecipients(meetingContext, customRecipients);

      if (recipients.isEmpty) {
        return DistributionResult(
          success: true,
          message: 'No valid recipients found for distribution',
          distributedTo: [],
          failedDeliveries: [],
        );
      }

      // Generate email content
      final emailContent = await _generateEmailContent(
        meetingContext,
        summary,
        transcription,
        recording,
      );

      // Send emails
      final distributionResults = await _sendEmails(recipients, emailContent);

      // Log distribution activity
      await _logDistributionActivity(
        meetingContext,
        summary,
        distributionResults,
      );

      final successfulDeliveries = distributionResults
          .where((r) => r.success)
          .map((r) => r.recipient)
          .toList();

      final failedDeliveries = distributionResults
          .where((r) => !r.success)
          .map((r) => EmailDeliveryFailure(
                recipient: r.recipient,
                reason: r.error ?? 'Unknown error',
              ))
          .toList();

      log('SummaryDistributionService: Distribution completed. '
          'Success: ${successfulDeliveries.length}, Failed: ${failedDeliveries.length}');

      return DistributionResult(
        success: failedDeliveries.isEmpty,
        message: failedDeliveries.isEmpty
            ? 'Summary distributed successfully to all recipients'
            : 'Summary distributed with some failures',
        distributedTo: successfulDeliveries,
        failedDeliveries: failedDeliveries,
      );
    } catch (e) {
      log('SummaryDistributionService: Error distributing summary: $e');
      return DistributionResult(
        success: false,
        error: 'Failed to distribute summary: $e',
        distributedTo: [],
        failedDeliveries: [],
      );
    }
  }

  /// Schedule delayed distribution after meeting ends
  Future<void> scheduleDistribution({
    required MeetingContext meetingContext,
    required Summary summary,
    Transcription? transcription,
    Recording? recording,
    Duration? delay,
  }) async {
    final distributionTime = meetingContext.event.endTime.add(
      delay ??
          meetingContext.summaryDistribution?.delayAfterMeeting ??
          const Duration(minutes: 15),
    );

    log('SummaryDistributionService: Scheduling distribution for ${distributionTime.toIso8601String()}');

    // In a real implementation, this would use a job queue or scheduler
    // For now, we'll use a simple timer for demonstration
    final delayDuration = distributionTime.difference(DateTime.now());

    if (delayDuration.isNegative) {
      // Meeting already ended, distribute immediately
      await distributeSummary(
        meetingContext: meetingContext,
        summary: summary,
        transcription: transcription,
        recording: recording,
      );
    } else {
      // Schedule for future delivery
      Future.delayed(delayDuration, () async {
        await distributeSummary(
          meetingContext: meetingContext,
          summary: summary,
          transcription: transcription,
          recording: recording,
        );
      });
    }
  }

  /// Check GDPR compliance for summary distribution
  Future<GdprComplianceResult> _checkGdprCompliance(
    MeetingContext meetingContext,
    List<String>? customRecipients,
  ) async {
    try {
      // Check if distribution is enabled
      if (meetingContext.summaryDistribution?.enabled != true) {
        return GdprComplianceResult(
          canShare: false,
          reason: 'Summary distribution not enabled for this meeting',
        );
      }

      // Check for explicit consent
      final recipients = customRecipients ?? meetingContext.attendeeEmails;

      for (final email in recipients) {
        final hasConsent = await _gdprService.hasDataProcessingConsent(
          email,
          'meeting_summary_distribution',
        );

        if (!hasConsent) {
          log('SummaryDistributionService: No consent for distribution to $email');
          // In a real implementation, you might exclude non-consenting users
          // rather than blocking the entire distribution
        }
      }

      return GdprComplianceResult(canShare: true);
    } catch (e) {
      log('SummaryDistributionService: GDPR compliance check failed: $e');
      return GdprComplianceResult(
        canShare: false,
        reason: 'GDPR compliance check failed: $e',
      );
    }
  }

  /// Determine email recipients based on meeting context and preferences
  List<String> _determineRecipients(
    MeetingContext meetingContext,
    List<String>? customRecipients,
  ) {
    if (customRecipients != null && customRecipients.isNotEmpty) {
      return customRecipients;
    }

    final summaryDistribution = meetingContext.summaryDistribution;
    if (summaryDistribution != null &&
        summaryDistribution.recipients.isNotEmpty) {
      return summaryDistribution.recipients;
    }

    // Default to all attendees who have accepted
    return meetingContext.participants
        .where((p) =>
            p.email.isNotEmpty &&
            p.hasAccepted &&
            p.role != ParticipantRole.resource)
        .map((p) => p.email)
        .toList();
  }

  /// Generate email content for summary distribution
  Future<EmailContent> _generateEmailContent(
    MeetingContext meetingContext,
    Summary summary,
    Transcription? transcription,
    Recording? recording,
  ) async {
    final event = meetingContext.event;
    final distribution = meetingContext.summaryDistribution;

    // Email subject
    final subject = 'Meeting Summary: ${event.title}';

    // Email body
    final bodyBuffer = StringBuffer();

    // Header
    bodyBuffer.writeln('# Meeting Summary');
    bodyBuffer.writeln();
    bodyBuffer.writeln('**Meeting:** ${event.title}');
    bodyBuffer.writeln('**Date:** ${_formatDate(event.startTime)}');
    bodyBuffer.writeln('**Duration:** ${_formatDuration(event.duration)}');

    if (event.location != null) {
      bodyBuffer.writeln('**Location:** ${event.location}');
    }

    bodyBuffer.writeln();

    // Attendees
    if (meetingContext.participants.isNotEmpty) {
      bodyBuffer.writeln('## Attendees');
      for (final participant in meetingContext.participants) {
        if (participant.role != ParticipantRole.resource) {
          final roleLabel = _formatParticipantRole(participant.role);
          bodyBuffer.writeln('- ${participant.name} ($roleLabel)');
        }
      }
      bodyBuffer.writeln();
    }

    // Summary content
    bodyBuffer.writeln('## Summary');
    bodyBuffer.writeln(summary.content);
    bodyBuffer.writeln();

    // Action items
    if (distribution?.includeActionItems == true &&
        summary.actionItems.isNotEmpty) {
      bodyBuffer.writeln('## Action Items');
      for (int i = 0; i < summary.actionItems.length; i++) {
        bodyBuffer.writeln('${i + 1}. ${summary.actionItems[i]}');
      }
      bodyBuffer.writeln();
    }

    // Key points
    if (summary.keyPoints.isNotEmpty) {
      bodyBuffer.writeln('## Key Points');
      for (final point in summary.keyPoints) {
        bodyBuffer.writeln('- $point');
      }
      bodyBuffer.writeln();
    }

    // Transcript (if requested and available)
    if (distribution?.includeTranscript == true &&
        transcription != null &&
        transcription.text.isNotEmpty) {
      bodyBuffer.writeln('## Transcript');
      bodyBuffer.writeln('```');
      bodyBuffer.writeln(transcription.text);
      bodyBuffer.writeln('```');
      bodyBuffer.writeln();
    }

    // Footer
    bodyBuffer.writeln('---');
    bodyBuffer
        .writeln('*This summary was automatically generated and distributed.*');
    bodyBuffer.writeln(
        '*If you have questions or need to opt out of future distributions, please contact the meeting organizer.*');

    return EmailContent(
      subject: subject,
      htmlBody: _convertMarkdownToHtml(bodyBuffer.toString()),
      textBody: bodyBuffer.toString(),
    );
  }

  /// Send emails to recipients
  Future<List<EmailDeliveryResult>> _sendEmails(
    List<String> recipients,
    EmailContent content,
  ) async {
    final results = <EmailDeliveryResult>[];

    try {
      // Create SMTP server configuration
      final smtpServer = _createSmtpServer();

      for (final recipient in recipients) {
        try {
          log('SummaryDistributionService: Sending email to $recipient');

          // Create message
          final message = Message()
            ..from =
                Address(_smtpConfig['sender_email'], _smtpConfig['sender_name'])
            ..recipients.add(recipient)
            ..subject = content.subject
            ..text = content.textBody
            ..html = content.htmlBody;

          // Send email
          final sendReport = await send(message, smtpServer);

          results.add(EmailDeliveryResult(
            recipient: recipient,
            success: true,
            messageId: sendReport.toString(),
          ));

          log('SummaryDistributionService: Email sent successfully to $recipient');
        } catch (e) {
          log('SummaryDistributionService: Failed to send email to $recipient: $e');
          results.add(EmailDeliveryResult(
            recipient: recipient,
            success: false,
            error: e.toString(),
          ));
        }
      }
    } catch (e) {
      log('SummaryDistributionService: SMTP configuration error: $e');
      for (final recipient in recipients) {
        results.add(EmailDeliveryResult(
          recipient: recipient,
          success: false,
          error: 'SMTP configuration error: $e',
        ));
      }
    }

    return results;
  }

  /// Create SMTP server configuration
  SmtpServer _createSmtpServer() {
    final host = _smtpConfig['smtp_host'] as String;
    final port = _smtpConfig['smtp_port'] as int;
    final username = _smtpConfig['smtp_username'] as String;
    final password = _smtpConfig['smtp_password'] as String;
    final useSsl = _smtpConfig['use_ssl'] as bool? ?? true;

    if (useSsl) {
      return SmtpServer(
        host,
        port: port,
        ssl: true,
        username: username,
        password: password,
      );
    } else {
      return SmtpServer(
        host,
        port: port,
        username: username,
        password: password,
      );
    }
  }

  /// Log distribution activity for audit purposes
  Future<void> _logDistributionActivity(
    MeetingContext meetingContext,
    Summary summary,
    List<EmailDeliveryResult> results,
  ) async {
    try {
      // In a real implementation, this would log to an audit system
      final successCount = results.where((r) => r.success).length;
      final failureCount = results.where((r) => !r.success).length;

      log('SummaryDistributionService: Distribution activity logged - '
          'Meeting: ${meetingContext.event.id}, '
          'Summary: ${summary.id}, '
          'Success: $successCount, '
          'Failures: $failureCount');
    } catch (e) {
      log('SummaryDistributionService: Failed to log distribution activity: $e');
    }
  }

  /// Validate SMTP configuration
  bool _validateSmtpConfig(Map<String, dynamic> config) {
    final requiredKeys = [
      'smtp_host',
      'smtp_port',
      'smtp_username',
      'smtp_password',
      'sender_email',
      'sender_name',
    ];

    for (final key in requiredKeys) {
      if (!config.containsKey(key) || config[key] == null) {
        return false;
      }
    }

    return true;
  }

  /// Format date for email display
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Format participant role for display
  String _formatParticipantRole(ParticipantRole role) {
    switch (role) {
      case ParticipantRole.organizer:
        return 'Organizer';
      case ParticipantRole.presenter:
        return 'Presenter';
      case ParticipantRole.attendee:
        return 'Attendee';
      case ParticipantRole.optional:
        return 'Optional';
      case ParticipantRole.resource:
        return 'Resource';
    }
  }

  /// Convert markdown to HTML (simplified)
  String _convertMarkdownToHtml(String markdown) {
    return markdown
        .replaceAll(RegExp(r'^# (.+)$', multiLine: true), '<h1>\$1</h1>')
        .replaceAll(RegExp(r'^## (.+)$', multiLine: true), '<h2>\$1</h2>')
        .replaceAll(RegExp(r'^### (.+)$', multiLine: true), '<h3>\$1</h3>')
        .replaceAll(
            RegExp(r'^\*\*(.+)\*\*', multiLine: true), '<strong>\$1</strong>')
        .replaceAll(RegExp(r'^\* (.+)$', multiLine: true), '<li>\$1</li>')
        .replaceAll(RegExp(r'^(\d+)\. (.+)$', multiLine: true), '<li>\$2</li>')
        .replaceAll('\n', '<br/>')
        .replaceAll('```', '<pre><code>')
        .replaceAll('```', '</code></pre>');
  }
}

/// GDPR compliance check result
class GdprComplianceResult {
  final bool canShare;
  final String? reason;

  const GdprComplianceResult({
    required this.canShare,
    this.reason,
  });
}

/// Email content structure
class EmailContent {
  final String subject;
  final String htmlBody;
  final String textBody;

  const EmailContent({
    required this.subject,
    required this.htmlBody,
    required this.textBody,
  });
}

/// Email delivery result
class EmailDeliveryResult {
  final String recipient;
  final bool success;
  final String? messageId;
  final String? error;

  const EmailDeliveryResult({
    required this.recipient,
    required this.success,
    this.messageId,
    this.error,
  });
}

/// Summary distribution result
class DistributionResult {
  final bool success;
  final String? message;
  final String? error;
  final List<String> distributedTo;
  final List<EmailDeliveryFailure> failedDeliveries;

  const DistributionResult({
    required this.success,
    this.message,
    this.error,
    required this.distributedTo,
    required this.failedDeliveries,
  });
}

/// Email delivery failure details
class EmailDeliveryFailure {
  final String recipient;
  final String reason;

  const EmailDeliveryFailure({
    required this.recipient,
    required this.reason,
  });
}
