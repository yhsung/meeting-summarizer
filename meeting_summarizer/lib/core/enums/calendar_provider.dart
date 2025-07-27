/// Calendar provider enumeration for different calendar services
enum CalendarProvider {
  googleCalendar,
  outlookCalendar,
  appleCalendar,
  deviceCalendar,
}

/// Calendar provider extensions for utility methods
extension CalendarProviderExtension on CalendarProvider {
  /// Human-readable name for the calendar provider
  String get displayName {
    switch (this) {
      case CalendarProvider.googleCalendar:
        return 'Google Calendar';
      case CalendarProvider.outlookCalendar:
        return 'Outlook Calendar';
      case CalendarProvider.appleCalendar:
        return 'Apple Calendar';
      case CalendarProvider.deviceCalendar:
        return 'Device Calendar';
    }
  }

  /// Provider identifier for API calls
  String get identifier {
    switch (this) {
      case CalendarProvider.googleCalendar:
        return 'google';
      case CalendarProvider.outlookCalendar:
        return 'outlook';
      case CalendarProvider.appleCalendar:
        return 'apple';
      case CalendarProvider.deviceCalendar:
        return 'device';
    }
  }

  /// Whether this provider requires OAuth2 authentication
  bool get requiresOAuth {
    switch (this) {
      case CalendarProvider.googleCalendar:
      case CalendarProvider.outlookCalendar:
        return true;
      case CalendarProvider.appleCalendar:
      case CalendarProvider.deviceCalendar:
        return false;
    }
  }

  /// OAuth2 scopes required for calendar access
  List<String> get requiredScopes {
    switch (this) {
      case CalendarProvider.googleCalendar:
        return ['https://www.googleapis.com/auth/calendar'];
      case CalendarProvider.outlookCalendar:
        return ['https://graph.microsoft.com/calendars.read'];
      case CalendarProvider.appleCalendar:
      case CalendarProvider.deviceCalendar:
        return [];
    }
  }
}
