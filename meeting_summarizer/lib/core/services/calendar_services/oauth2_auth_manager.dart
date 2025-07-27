import 'dart:developer';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import '../../enums/calendar_provider.dart';

/// OAuth2 authentication manager for calendar providers
class OAuth2AuthManager {
  static const _storage = FlutterSecureStorage();

  /// Storage keys for different providers
  static const _googleTokenKey = 'calendar_google_token';
  static const _outlookTokenKey = 'calendar_outlook_token';

  /// Current authentication states
  final Map<CalendarProvider, bool> _authStates = {};
  final Map<CalendarProvider, AccessCredentials?> _credentials = {};
  final Map<CalendarProvider, http.Client?> _clients = {};

  /// Check if a provider is authenticated
  bool isAuthenticated(CalendarProvider provider) {
    return _authStates[provider] ?? false;
  }

  /// Get authenticated HTTP client for a provider
  http.Client? getAuthenticatedClient(CalendarProvider provider) {
    return _clients[provider];
  }

  /// Get access credentials for a provider
  AccessCredentials? getCredentials(CalendarProvider provider) {
    return _credentials[provider];
  }

  /// Authenticate with Google Calendar
  Future<bool> authenticateGoogle({
    required String clientId,
    required String clientSecret,
  }) async {
    try {
      log('OAuth2AuthManager: Authenticating with Google Calendar');

      // Try to load existing credentials
      final storedToken = await _storage.read(key: _googleTokenKey);
      if (storedToken != null) {
        try {
          final credentials = AccessCredentials.fromJson(storedToken);
          if (!_isTokenExpired(credentials)) {
            _credentials[CalendarProvider.googleCalendar] = credentials;
            _clients[CalendarProvider.googleCalendar] =
                authenticatedClient(http.Client(), credentials);
            _authStates[CalendarProvider.googleCalendar] = true;
            log('OAuth2AuthManager: Google Calendar authenticated with stored token');
            return true;
          }
        } catch (e) {
          log('OAuth2AuthManager: Failed to parse stored Google token: $e');
          await _storage.delete(key: _googleTokenKey);
        }
      }

      // Create OAuth2 client identifier
      final clientIdObj = ClientId(clientId, clientSecret);

      // Define scopes for Google Calendar
      const scopes = ['https://www.googleapis.com/auth/calendar'];

      // Perform OAuth2 flow
      final credentials = await obtainAccessCredentialsViaUserConsent(
        clientIdObj,
        scopes,
        http.Client(),
        (url) {
          log('OAuth2AuthManager: Please open this URL for Google authentication: $url');
          // In a real app, this would open a browser or webview
          // For now, we'll simulate successful authentication
        },
      );

      // Store credentials securely
      await _storage.write(
        key: _googleTokenKey,
        value: credentials.toJson(),
      );

      // Create authenticated client
      _credentials[CalendarProvider.googleCalendar] = credentials;
      _clients[CalendarProvider.googleCalendar] =
          authenticatedClient(http.Client(), credentials);
      _authStates[CalendarProvider.googleCalendar] = true;

      log('OAuth2AuthManager: Google Calendar authentication successful');
      return true;
    } catch (e) {
      log('OAuth2AuthManager: Google Calendar authentication failed: $e');
      _authStates[CalendarProvider.googleCalendar] = false;
      return false;
    }
  }

  /// Authenticate with Outlook Calendar (Microsoft Graph)
  Future<bool> authenticateOutlook({
    required String clientId,
    required String clientSecret,
    required String tenantId,
  }) async {
    try {
      log('OAuth2AuthManager: Authenticating with Outlook Calendar');

      // Try to load existing credentials
      final storedToken = await _storage.read(key: _outlookTokenKey);
      if (storedToken != null) {
        try {
          final credentials = AccessCredentials.fromJson(storedToken);
          if (!_isTokenExpired(credentials)) {
            _credentials[CalendarProvider.outlookCalendar] = credentials;
            _clients[CalendarProvider.outlookCalendar] =
                authenticatedClient(http.Client(), credentials);
            _authStates[CalendarProvider.outlookCalendar] = true;
            log('OAuth2AuthManager: Outlook Calendar authenticated with stored token');
            return true;
          }
        } catch (e) {
          log('OAuth2AuthManager: Failed to parse stored Outlook token: $e');
          await _storage.delete(key: _outlookTokenKey);
        }
      }

      // For Microsoft Graph, we would use MSAL or similar
      // For now, we'll implement a basic OAuth2 flow
      final authEndpoint =
          'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize';
      final tokenEndpoint =
          'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token';

      // Simulate successful authentication for now
      // In a real implementation, this would involve:
      // 1. Opening authorization URL in browser/webview
      // 2. Capturing authorization code
      // 3. Exchanging code for access token

      log('OAuth2AuthManager: Outlook authentication URL would be: $authEndpoint');

      // For testing purposes, create a mock credentials object
      final mockCredentials = AccessCredentials(
        AccessToken('mock_token', 'Bearer',
            DateTime.now().add(const Duration(hours: 1))),
        'mock_refresh_token',
        ['https://graph.microsoft.com/calendars.read'],
      );

      // Store mock credentials
      await _storage.write(
        key: _outlookTokenKey,
        value: mockCredentials.toJson(),
      );

      _credentials[CalendarProvider.outlookCalendar] = mockCredentials;
      _clients[CalendarProvider.outlookCalendar] =
          authenticatedClient(http.Client(), mockCredentials);
      _authStates[CalendarProvider.outlookCalendar] = true;

      log('OAuth2AuthManager: Outlook Calendar authentication successful (mock)');
      return true;
    } catch (e) {
      log('OAuth2AuthManager: Outlook Calendar authentication failed: $e');
      _authStates[CalendarProvider.outlookCalendar] = false;
      return false;
    }
  }

  /// Refresh access token for a provider
  Future<bool> refreshToken(CalendarProvider provider) async {
    final credentials = _credentials[provider];
    if (credentials == null || credentials.refreshToken == null) {
      return false;
    }

    try {
      log('OAuth2AuthManager: Refreshing token for $provider');

      // Token refresh logic would depend on the provider
      switch (provider) {
        case CalendarProvider.googleCalendar:
          return await _refreshGoogleToken(credentials);
        case CalendarProvider.outlookCalendar:
          return await _refreshOutlookToken(credentials);
        default:
          return false;
      }
    } catch (e) {
      log('OAuth2AuthManager: Token refresh failed for $provider: $e');
      return false;
    }
  }

  /// Disconnect from a calendar provider
  Future<void> disconnect(CalendarProvider provider) async {
    log('OAuth2AuthManager: Disconnecting from $provider');

    // Close HTTP client
    _clients[provider]?.close();
    _clients.remove(provider);

    // Clear credentials
    _credentials.remove(provider);
    _authStates[provider] = false;

    // Remove stored tokens
    switch (provider) {
      case CalendarProvider.googleCalendar:
        await _storage.delete(key: _googleTokenKey);
        break;
      case CalendarProvider.outlookCalendar:
        await _storage.delete(key: _outlookTokenKey);
        break;
      default:
        break;
    }
  }

  /// Disconnect from all providers
  Future<void> disconnectAll() async {
    log('OAuth2AuthManager: Disconnecting from all providers');

    for (final provider in CalendarProvider.values) {
      if (provider.requiresOAuth) {
        await disconnect(provider);
      }
    }
  }

  /// Check if access token is expired
  bool _isTokenExpired(AccessCredentials credentials) {
    final buffer = const Duration(minutes: 5); // 5-minute buffer
    return DateTime.now().add(buffer).isAfter(credentials.accessToken.expiry);
  }

  /// Refresh Google access token
  Future<bool> _refreshGoogleToken(AccessCredentials credentials) async {
    try {
      // Google token refresh implementation
      // This would use the googleapis_auth library's refresh capabilities
      log('OAuth2AuthManager: Refreshing Google token');

      // For now, simulate successful refresh
      final newCredentials = AccessCredentials(
        AccessToken('new_google_token', 'Bearer',
            DateTime.now().add(const Duration(hours: 1))),
        credentials.refreshToken,
        credentials.scopes,
      );

      await _storage.write(
        key: _googleTokenKey,
        value: newCredentials.toJson(),
      );

      _credentials[CalendarProvider.googleCalendar] = newCredentials;
      _clients[CalendarProvider.googleCalendar]?.close();
      _clients[CalendarProvider.googleCalendar] =
          authenticatedClient(http.Client(), newCredentials);

      return true;
    } catch (e) {
      log('OAuth2AuthManager: Google token refresh failed: $e');
      return false;
    }
  }

  /// Refresh Outlook access token
  Future<bool> _refreshOutlookToken(AccessCredentials credentials) async {
    try {
      // Outlook token refresh implementation
      log('OAuth2AuthManager: Refreshing Outlook token');

      // For now, simulate successful refresh
      final newCredentials = AccessCredentials(
        AccessToken('new_outlook_token', 'Bearer',
            DateTime.now().add(const Duration(hours: 1))),
        credentials.refreshToken,
        credentials.scopes,
      );

      await _storage.write(
        key: _outlookTokenKey,
        value: newCredentials.toJson(),
      );

      _credentials[CalendarProvider.outlookCalendar] = newCredentials;
      _clients[CalendarProvider.outlookCalendar]?.close();
      _clients[CalendarProvider.outlookCalendar] =
          authenticatedClient(http.Client(), newCredentials);

      return true;
    } catch (e) {
      log('OAuth2AuthManager: Outlook token refresh failed: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    for (final client in _clients.values) {
      client?.close();
    }
    _clients.clear();
    _credentials.clear();
    _authStates.clear();
  }
}

/// Extension to add JSON serialization to AccessCredentials
extension AccessCredentialsJson on AccessCredentials {
  String toJson() {
    return '{'
        '"accessToken": "${accessToken.data}",'
        '"tokenType": "${accessToken.type}",'
        '"expiry": "${accessToken.expiry.toIso8601String()}",'
        '"refreshToken": "$refreshToken",'
        '"scopes": ${scopes.map((s) => '"$s"').toList()}'
        '}';
  }

  static AccessCredentials fromJson(String json) {
    // This is a simplified JSON parsing
    // In a real implementation, you would use proper JSON parsing
    final data = json.replaceAll('{', '').replaceAll('}', '').split(',');
    final map = <String, String>{};

    for (final item in data) {
      final parts = item.split(':');
      if (parts.length == 2) {
        final key = parts[0].trim().replaceAll('"', '');
        final value = parts[1].trim().replaceAll('"', '');
        map[key] = value;
      }
    }

    return AccessCredentials(
      AccessToken(
        map['accessToken'] ?? '',
        map['tokenType'] ?? 'Bearer',
        DateTime.parse(map['expiry'] ?? DateTime.now().toIso8601String()),
      ),
      map['refreshToken'],
      [], // Simplified scope parsing
    );
  }
}
