import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_summarizer/core/services/secure_api_service.dart';

void main() {
  group('SecureApiService Tests', () {
    group('JWT Token Management', () {
      test('should create JWT token from JSON response', () {
        final json = {
          'access_token': 'test_access_token',
          'refresh_token': 'test_refresh_token',
          'expires_in': 3600,
          'token_type': 'Bearer',
          'scope': 'read write',
        };

        final token = JwtToken.fromJson(json);

        expect(token.accessToken, equals('test_access_token'));
        expect(token.refreshToken, equals('test_refresh_token'));
        expect(token.tokenType, equals('Bearer'));
        expect(token.scopes, equals(['read', 'write']));
        expect(token.isExpired, isFalse);
      });

      test('should detect expired tokens', () {
        final expiredToken = JwtToken(
          accessToken: 'test_token',
          refreshToken: 'refresh_token',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );

        expect(expiredToken.isExpired, isTrue);
      });

      test('should detect expiring soon tokens', () {
        final expiringSoonToken = JwtToken(
          accessToken: 'test_token',
          refreshToken: 'refresh_token',
          expiresAt: DateTime.now().add(const Duration(minutes: 2)),
        );

        expect(expiringSoonToken.isExpiringSoon, isTrue);
      });

      test('should serialize token to JSON', () {
        final token = JwtToken(
          accessToken: 'test_access_token',
          refreshToken: 'test_refresh_token',
          expiresAt: DateTime.parse('2024-01-01T12:00:00Z'),
          tokenType: 'Bearer',
          scopes: ['read', 'write'],
        );

        final json = token.toJson();

        expect(json['access_token'], equals('test_access_token'));
        expect(json['refresh_token'], equals('test_refresh_token'));
        expect(json['token_type'], equals('Bearer'));
        expect(json['scopes'], equals(['read', 'write']));
      });
    });

    group('API Error Handling', () {
      test('should create appropriate error types', () {
        final error = ApiError(
          type: ApiErrorType.network,
          message: 'Network connection failed',
        );

        expect(error.type, equals(ApiErrorType.network));
        expect(error.message, equals('Network connection failed'));
        expect(error.timestamp, isA<DateTime>());
      });

      test('should map error types correctly', () {
        expect(ApiErrorType.values, contains(ApiErrorType.network));
        expect(ApiErrorType.values, contains(ApiErrorType.authentication));
        expect(ApiErrorType.values, contains(ApiErrorType.authorization));
        expect(ApiErrorType.values, contains(ApiErrorType.rateLimited));
        expect(ApiErrorType.values, contains(ApiErrorType.timeout));
      });

      test('should include status code in error', () {
        final error = ApiError(
          type: ApiErrorType.authentication,
          message: 'Invalid credentials',
          statusCode: 401,
        );

        expect(error.statusCode, equals(401));
        expect(error.toString(), contains('401'));
      });
    });

    group('Rate Limiting Configuration', () {
      test('should create rate limit config with defaults', () {
        const config = RateLimitConfig();

        expect(config.maxRequestsPerMinute, equals(60));
        expect(config.maxRequestsPerHour, equals(1000));
        expect(config.maxRequestsPerDay, equals(10000));
        expect(config.retryDelay, equals(Duration(seconds: 60)));
      });

      test('should create rate limit config with custom values', () {
        const config = RateLimitConfig(
          maxRequestsPerMinute: 10,
          maxRequestsPerHour: 100,
          maxRequestsPerDay: 1000,
          retryDelay: Duration(minutes: 2),
        );

        expect(config.maxRequestsPerMinute, equals(10));
        expect(config.maxRequestsPerHour, equals(100));
        expect(config.maxRequestsPerDay, equals(1000));
        expect(config.retryDelay, equals(Duration(minutes: 2)));
      });
    });

    group('Security Configuration', () {
      test('should create security config with required fields', () {
        const config = SecurityConfig(
          pinnedCertificates: ['sha256:example'],
          allowedHosts: ['api.example.com'],
        );

        expect(config.pinnedCertificates, contains('sha256:example'));
        expect(config.allowedHosts, contains('api.example.com'));
        expect(config.enableRequestSigning, isTrue);
        expect(config.enableResponseVerification, isTrue);
        expect(config.enableEncryption, isTrue);
      });

      test('should create security config with custom settings', () {
        const config = SecurityConfig(
          pinnedCertificates: ['sha256:cert1', 'sha256:cert2'],
          allowedHosts: ['api.example.com', 'secure.example.com'],
          connectionTimeout: Duration(seconds: 45),
          receiveTimeout: Duration(seconds: 45),
          enableRequestSigning: false,
          enableResponseVerification: false,
          enableEncryption: false,
        );

        expect(config.pinnedCertificates, hasLength(2));
        expect(config.allowedHosts, hasLength(2));
        expect(config.connectionTimeout, equals(Duration(seconds: 45)));
        expect(config.receiveTimeout, equals(Duration(seconds: 45)));
        expect(config.enableRequestSigning, isFalse);
        expect(config.enableResponseVerification, isFalse);
        expect(config.enableEncryption, isFalse);
      });
    });

    group('Request Metrics', () {
      test('should create request metrics with required fields', () {
        final startTime = DateTime.now();

        final metrics = RequestMetrics(
          endpoint: '/api/test',
          method: 'GET',
          startTime: startTime,
        );

        expect(metrics.endpoint, equals('/api/test'));
        expect(metrics.method, equals('GET'));
        expect(metrics.startTime, equals(startTime));
        expect(metrics.fromCache, isFalse);
      });

      test('should create request metrics with all fields', () {
        final startTime = DateTime.now();
        final endTime = startTime.add(const Duration(milliseconds: 500));

        final metrics = RequestMetrics(
          endpoint: '/api/test',
          method: 'POST',
          startTime: startTime,
          endTime: endTime,
          statusCode: 201,
          responseSize: 1024,
          duration: endTime.difference(startTime),
          fromCache: true,
        );

        expect(metrics.endpoint, equals('/api/test'));
        expect(metrics.method, equals('POST'));
        expect(metrics.statusCode, equals(201));
        expect(metrics.responseSize, equals(1024));
        expect(metrics.duration?.inMilliseconds, equals(500));
        expect(metrics.fromCache, isTrue);
      });

      test('should serialize metrics to JSON', () {
        final startTime = DateTime.now();
        final metrics = RequestMetrics(
          endpoint: '/api/test',
          method: 'POST',
          startTime: startTime,
          statusCode: 201,
        );

        final json = metrics.toJson();

        expect(json['endpoint'], equals('/api/test'));
        expect(json['method'], equals('POST'));
        expect(json['statusCode'], equals(201));
        expect(json['startTime'], isA<String>());
        expect(json['fromCache'], isFalse);
      });
    });

    group('Request Priority', () {
      test('should have all priority levels', () {
        expect(RequestPriority.values, hasLength(4));
        expect(RequestPriority.values, contains(RequestPriority.low));
        expect(RequestPriority.values, contains(RequestPriority.normal));
        expect(RequestPriority.values, contains(RequestPriority.high));
        expect(RequestPriority.values, contains(RequestPriority.critical));
      });
    });

    group('API Error Types', () {
      test('should have all error types', () {
        expect(ApiErrorType.values, hasLength(9));
        expect(ApiErrorType.values, contains(ApiErrorType.network));
        expect(ApiErrorType.values, contains(ApiErrorType.timeout));
        expect(ApiErrorType.values, contains(ApiErrorType.authentication));
        expect(ApiErrorType.values, contains(ApiErrorType.authorization));
        expect(ApiErrorType.values, contains(ApiErrorType.validation));
        expect(ApiErrorType.values, contains(ApiErrorType.server));
        expect(ApiErrorType.values, contains(ApiErrorType.rateLimited));
        expect(ApiErrorType.values, contains(ApiErrorType.certificateError));
        expect(ApiErrorType.values, contains(ApiErrorType.unknown));
      });
    });

    group('Error Scenarios', () {
      test('should handle network errors gracefully', () {
        final networkError = ApiError(
          type: ApiErrorType.network,
          message: 'Network connection failed',
        );

        expect(networkError.type, equals(ApiErrorType.network));
        expect(networkError.toString(), contains('Network connection failed'));
        expect(networkError.toString(), contains('network'));
      });

      test('should handle authentication errors', () {
        final authError = ApiError(
          type: ApiErrorType.authentication,
          message: 'Invalid credentials',
          statusCode: 401,
        );

        expect(authError.type, equals(ApiErrorType.authentication));
        expect(authError.statusCode, equals(401));
        expect(authError.toString(), contains('authentication'));
        expect(authError.toString(), contains('401'));
      });

      test('should handle timeout errors', () {
        final timeoutError = ApiError(
          type: ApiErrorType.timeout,
          message: 'Request timeout',
        );

        expect(timeoutError.type, equals(ApiErrorType.timeout));
        expect(timeoutError.message, contains('timeout'));
      });

      test('should include original error in ApiError', () {
        final originalError = Exception('Original error');
        final apiError = ApiError(
          type: ApiErrorType.unknown,
          message: 'Wrapped error',
          originalError: originalError,
        );

        expect(apiError.originalError, equals(originalError));
      });
    });

    group('Security Features Validation', () {
      test('should validate certificate pinning format', () {
        const config = SecurityConfig(
          pinnedCertificates: ['sha256:abcd1234', 'sha256:efgh5678'],
          allowedHosts: ['secure-api.example.com'],
        );

        for (final cert in config.pinnedCertificates) {
          expect(cert, startsWith('sha256:'));
        }
      });

      test('should validate allowed hosts format', () {
        const config = SecurityConfig(
          pinnedCertificates: [],
          allowedHosts: [
            'api.example.com',
            'auth.example.com',
            'data.example.com',
          ],
        );

        expect(config.allowedHosts, hasLength(3));
        for (final host in config.allowedHosts) {
          expect(host, isA<String>());
          expect(host.length, greaterThan(0));
        }
      });
    });
  });
}
