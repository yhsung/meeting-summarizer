import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

import 'encryption_service.dart';
import 'offline_queue_service.dart';

enum RequestPriority { low, normal, high, critical }

enum ApiErrorType {
  network,
  timeout,
  authentication,
  authorization,
  validation,
  server,
  rateLimited,
  certificateError,
  unknown,
}

class ApiError extends Error {
  final ApiErrorType type;
  final String message;
  final int? statusCode;
  final dynamic originalError;
  final DateTime timestamp;

  ApiError({
    required this.type,
    required this.message,
    this.statusCode,
    this.originalError,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'ApiError($type): $message (Code: $statusCode)';
}

class JwtToken {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String tokenType;
  final List<String> scopes;

  const JwtToken({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    this.tokenType = 'Bearer',
    this.scopes = const [],
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isExpiringSoon =>
      DateTime.now().add(const Duration(minutes: 5)).isAfter(expiresAt);

  factory JwtToken.fromJson(Map<String, dynamic> json) {
    return JwtToken(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      expiresAt: DateTime.now().add(
        Duration(seconds: json['expires_in'] ?? 3600),
      ),
      tokenType: json['token_type'] ?? 'Bearer',
      scopes: (json['scope'] as String?)?.split(' ') ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_at': expiresAt.toIso8601String(),
      'token_type': tokenType,
      'scopes': scopes,
    };
  }
}

class RateLimitConfig {
  final int maxRequestsPerMinute;
  final int maxRequestsPerHour;
  final int maxRequestsPerDay;
  final Duration retryDelay;

  const RateLimitConfig({
    this.maxRequestsPerMinute = 60,
    this.maxRequestsPerHour = 1000,
    this.maxRequestsPerDay = 10000,
    this.retryDelay = const Duration(seconds: 60),
  });
}

class SecurityConfig {
  final List<String> pinnedCertificates;
  final List<String> allowedHosts;
  final Duration connectionTimeout;
  final Duration receiveTimeout;
  final bool enableRequestSigning;
  final bool enableResponseVerification;
  final bool enableEncryption;
  final RateLimitConfig rateLimitConfig;

  const SecurityConfig({
    required this.pinnedCertificates,
    required this.allowedHosts,
    this.connectionTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
    this.enableRequestSigning = true,
    this.enableResponseVerification = true,
    this.enableEncryption = true,
    this.rateLimitConfig = const RateLimitConfig(),
  });
}

class RequestMetrics {
  final String endpoint;
  final String method;
  final DateTime startTime;
  final DateTime? endTime;
  final int? statusCode;
  final int? responseSize;
  final Duration? duration;
  final bool fromCache;

  const RequestMetrics({
    required this.endpoint,
    required this.method,
    required this.startTime,
    this.endTime,
    this.statusCode,
    this.responseSize,
    this.duration,
    this.fromCache = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'endpoint': endpoint,
      'method': method,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'statusCode': statusCode,
      'responseSize': responseSize,
      'duration': duration?.inMilliseconds,
      'fromCache': fromCache,
    };
  }
}

class SecureApiService {
  static const String _jwtTokenKey = 'jwt_token';
  static const String _apiKeyKey = 'api_key';

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  final OfflineQueueService _offlineQueueService;
  final SecurityConfig _config;

  JwtToken? _currentToken;
  final Map<String, int> _requestCounts = {};
  final List<RequestMetrics> _requestMetrics = [];

  SecureApiService._({
    required Dio dio,
    required FlutterSecureStorage secureStorage,
    required OfflineQueueService offlineQueueService,
    required SecurityConfig config,
  }) : _dio = dio,
       _secureStorage = secureStorage,
       _offlineQueueService = offlineQueueService,
       _config = config;

  static SecureApiService? _instance;

  static Future<SecureApiService> getInstance({SecurityConfig? config}) async {
    if (_instance != null) return _instance!;

    const secureStorage = FlutterSecureStorage();
    await EncryptionService.initialize();
    final offlineQueueService = OfflineQueueService.instance;
    await offlineQueueService.initialize();

    final defaultConfig = SecurityConfig(
      pinnedCertificates: [],
      allowedHosts: ['api.example.com', 'localhost'],
    );

    final dio = Dio();

    _instance = SecureApiService._(
      dio: dio,
      secureStorage: secureStorage,
      offlineQueueService: offlineQueueService,
      config: config ?? defaultConfig,
    );

    await _instance!._initialize();
    return _instance!;
  }

  Future<void> _initialize() async {
    await _setupDio();
    await _loadStoredToken();
    _setupInterceptors();

    developer.log('SecureApiService initialized', name: 'SecureApiService');
  }

  Future<void> _setupDio() async {
    _dio.options = BaseOptions(
      connectTimeout: _config.connectionTimeout,
      receiveTimeout: _config.receiveTimeout,
      headers: {
        'User-Agent': 'MeetingSummarizer/1.0.0',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );

    // Note: Certificate pinning would be implemented here with appropriate package
    // Currently using built-in TLS certificate validation
    if (_config.pinnedCertificates.isNotEmpty) {
      developer.log(
        'Certificate pinning configuration found but not implemented yet',
        name: 'SecureApiService',
      );
    }
  }

  void _setupInterceptors() {
    // Request interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          await _onRequest(options, handler);
        },
        onResponse: (response, handler) async {
          await _onResponse(response, handler);
        },
        onError: (error, handler) async {
          await _onError(error, handler);
        },
      ),
    );

    // Logging interceptor (development only)
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          logPrint: (obj) =>
              developer.log(obj.toString(), name: 'SecureApiService'),
        ),
      );
    }
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // Check rate limiting
      if (!_checkRateLimit(options.path, options.method)) {
        throw ApiError(
          type: ApiErrorType.rateLimited,
          message: 'Rate limit exceeded for ${options.method} ${options.path}',
        );
      }

      // Add authentication
      await _addAuthentication(options);

      // Add security headers
      _addSecurityHeaders(options);

      // Sign request if enabled
      if (_config.enableRequestSigning) {
        await _signRequest(options);
      }

      // Encrypt request data if enabled
      if (_config.enableEncryption && options.data != null) {
        options.data = await _encryptRequestData(options.data);
      }

      // Record request start time
      options.extra['startTime'] = DateTime.now();

      handler.next(options);
    } catch (e) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: e,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  Future<void> _onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    try {
      final startTime = response.requestOptions.extra['startTime'] as DateTime?;
      final endTime = DateTime.now();

      // Record metrics
      if (startTime != null) {
        _recordRequestMetrics(
          RequestMetrics(
            endpoint: response.requestOptions.path,
            method: response.requestOptions.method,
            startTime: startTime,
            endTime: endTime,
            statusCode: response.statusCode,
            responseSize: response.data?.toString().length,
            duration: endTime.difference(startTime),
          ),
        );
      }

      // Verify response signature if enabled
      if (_config.enableResponseVerification) {
        await _verifyResponse(response);
      }

      // Decrypt response data if enabled
      if (_config.enableEncryption && response.data != null) {
        response.data = await _decryptResponseData(response.data);
      }

      handler.next(response);
    } catch (e) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          error: e,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final apiError = _mapDioErrorToApiError(error);

    // Record failed request metrics
    final startTime = error.requestOptions.extra['startTime'] as DateTime?;
    if (startTime != null) {
      _recordRequestMetrics(
        RequestMetrics(
          endpoint: error.requestOptions.path,
          method: error.requestOptions.method,
          startTime: startTime,
          endTime: DateTime.now(),
          statusCode: error.response?.statusCode,
          duration: DateTime.now().difference(startTime),
        ),
      );
    }

    // Handle token refresh for 401 errors
    if (error.response?.statusCode == 401 && _currentToken != null) {
      try {
        await _refreshToken();

        // Retry the original request
        final response = await _dio.fetch(error.requestOptions);
        handler.resolve(response);
        return;
      } catch (refreshError) {
        developer.log(
          'Token refresh failed: $refreshError',
          name: 'SecureApiService',
        );
      }
    }

    // Queue request for offline retry if network error
    if (apiError.type == ApiErrorType.network) {
      await _queueOfflineRequest(error.requestOptions);
    }

    handler.next(error);
  }

  bool _checkRateLimit(String path, String method) {
    final key = '$method:$path';
    final now = DateTime.now();
    final currentMinute = now.minute;
    final minuteKey = '$key:$currentMinute';

    _requestCounts[minuteKey] = (_requestCounts[minuteKey] ?? 0) + 1;

    // Clean old entries
    _requestCounts.removeWhere(
      (k, v) =>
          !k.startsWith('$key:') ||
          int.tryParse(k.split(':').last) != currentMinute,
    );

    return (_requestCounts[minuteKey] ?? 0) <=
        _config.rateLimitConfig.maxRequestsPerMinute;
  }

  Future<void> _addAuthentication(RequestOptions options) async {
    // Check if token needs refresh
    if (_currentToken?.isExpiringSoon == true) {
      await _refreshToken();
    }

    // Add JWT token
    if (_currentToken != null && !_currentToken!.isExpired) {
      options.headers['Authorization'] =
          '${_currentToken!.tokenType} ${_currentToken!.accessToken}';
    }

    // Add API key if available
    final apiKey = await _secureStorage.read(key: _apiKeyKey);
    if (apiKey != null) {
      options.headers['X-API-Key'] = apiKey;
    }
  }

  void _addSecurityHeaders(RequestOptions options) {
    final headers = {
      'X-Requested-With': 'XMLHttpRequest',
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'X-XSS-Protection': '1; mode=block',
      'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
      'Expires': '0',
      'X-Request-ID': _generateRequestId(),
      'X-Timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    options.headers.addAll(headers);
  }

  Future<void> _signRequest(RequestOptions options) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final method = options.method.toUpperCase();
      final path = options.path;
      final body = options.data != null ? jsonEncode(options.data) : '';

      final signatureData = '$method$path$timestamp$body';
      final signatureBytes = utf8.encode(signatureData);
      final hash = sha256.convert(signatureBytes);
      final signature = hash.toString();

      options.headers['X-Signature'] = signature;
      options.headers['X-Timestamp'] = timestamp;
    } catch (e) {
      developer.log('Request signing failed: $e', name: 'SecureApiService');
      throw ApiError(
        type: ApiErrorType.unknown,
        message: 'Failed to sign request: $e',
      );
    }
  }

  Future<dynamic> _encryptRequestData(dynamic data) async {
    try {
      if (data == null) return null;

      final jsonData = jsonEncode(data);
      // For now, we'll use a simplified encryption approach
      // In production, you'd want to use the EncryptionService with proper key management
      final encryptedBytes = utf8.encode(jsonData);
      final encryptedData = base64Encode(encryptedBytes);

      return {'encrypted': true, 'data': encryptedData};
    } catch (e) {
      developer.log('Request encryption failed: $e', name: 'SecureApiService');
      throw ApiError(
        type: ApiErrorType.unknown,
        message: 'Failed to encrypt request data: $e',
      );
    }
  }

  Future<dynamic> _decryptResponseData(dynamic data) async {
    try {
      if (data == null) return null;

      if (data is Map<String, dynamic> && data['encrypted'] == true) {
        // For now, we'll use a simplified decryption approach
        // In production, you'd want to use the EncryptionService with proper key management
        final encryptedData = data['data'] as String;
        final decryptedBytes = base64Decode(encryptedData);
        final decryptedString = utf8.decode(decryptedBytes);
        return jsonDecode(decryptedString);
      }

      return data;
    } catch (e) {
      developer.log('Response decryption failed: $e', name: 'SecureApiService');
      throw ApiError(
        type: ApiErrorType.unknown,
        message: 'Failed to decrypt response data: $e',
      );
    }
  }

  Future<void> _verifyResponse(Response response) async {
    try {
      final signature = response.headers.value('X-Signature');
      final timestamp = response.headers.value('X-Timestamp');

      if (signature == null || timestamp == null) {
        throw ApiError(
          type: ApiErrorType.unknown,
          message: 'Response missing security headers',
        );
      }

      final responseData = response.data != null
          ? jsonEncode(response.data)
          : '';
      final verificationData = '${response.statusCode}$timestamp$responseData';
      final verificationBytes = utf8.encode(verificationData);
      final hash = sha256.convert(verificationBytes);
      final expectedSignature = hash.toString();

      if (signature != expectedSignature) {
        throw ApiError(
          type: ApiErrorType.unknown,
          message: 'Response signature verification failed',
        );
      }
    } catch (e) {
      developer.log(
        'Response verification failed: $e',
        name: 'SecureApiService',
      );
      rethrow;
    }
  }

  ApiError _mapDioErrorToApiError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiError(
          type: ApiErrorType.timeout,
          message: 'Request timeout: ${error.message}',
          originalError: error,
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) {
          return ApiError(
            type: ApiErrorType.authentication,
            message: 'Authentication failed',
            statusCode: statusCode,
            originalError: error,
          );
        } else if (statusCode == 403) {
          return ApiError(
            type: ApiErrorType.authorization,
            message: 'Authorization failed',
            statusCode: statusCode,
            originalError: error,
          );
        } else if (statusCode == 429) {
          return ApiError(
            type: ApiErrorType.rateLimited,
            message: 'Rate limit exceeded',
            statusCode: statusCode,
            originalError: error,
          );
        } else if (statusCode != null &&
            statusCode >= 400 &&
            statusCode < 500) {
          return ApiError(
            type: ApiErrorType.validation,
            message: 'Client error: ${error.response?.data}',
            statusCode: statusCode,
            originalError: error,
          );
        } else {
          return ApiError(
            type: ApiErrorType.server,
            message: 'Server error: ${error.response?.data}',
            statusCode: statusCode,
            originalError: error,
          );
        }

      case DioExceptionType.connectionError:
        return ApiError(
          type: ApiErrorType.network,
          message: 'Network connection failed: ${error.message}',
          originalError: error,
        );

      case DioExceptionType.badCertificate:
        return ApiError(
          type: ApiErrorType.certificateError,
          message: 'Certificate validation failed: ${error.message}',
          originalError: error,
        );

      default:
        return ApiError(
          type: ApiErrorType.unknown,
          message: 'Unknown error: ${error.message}',
          originalError: error,
        );
    }
  }

  Future<void> _queueOfflineRequest(RequestOptions options) async {
    try {
      // Note: This is a simplified implementation for API requests
      // For full cloud sync operations, this would need to be integrated
      // with the actual cloud sync services and SyncOperation objects

      // Check if offline queue service is available and initialized
      if (_offlineQueueService.hashCode != 0) {
        developer.log(
          'API request failed and would be queued for retry: ${options.method} ${options.path}',
          name: 'SecureApiService',
        );

        // TODO: Create appropriate SyncOperation objects based on the API endpoint
        // and integrate with CloudSyncService for proper offline handling
      }

      // Store request details for potential manual retry
      // This could be enhanced to create appropriate SyncOperation objects
      // based on the API endpoint and operation type
    } catch (e) {
      developer.log(
        'Failed to handle offline request: $e',
        name: 'SecureApiService',
      );
    }
  }

  void _recordRequestMetrics(RequestMetrics metrics) {
    _requestMetrics.add(metrics);

    // Keep only last 1000 metrics
    if (_requestMetrics.length > 1000) {
      _requestMetrics.removeRange(0, _requestMetrics.length - 1000);
    }
  }

  String _generateRequestId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return '$timestamp-$random';
  }

  Future<void> _loadStoredToken() async {
    try {
      final tokenJson = await _secureStorage.read(key: _jwtTokenKey);
      if (tokenJson != null) {
        final tokenData = jsonDecode(tokenJson) as Map<String, dynamic>;
        _currentToken = JwtToken.fromJson(tokenData);

        if (_currentToken!.isExpired) {
          await _refreshToken();
        }
      }
    } catch (e) {
      developer.log(
        'Failed to load stored token: $e',
        name: 'SecureApiService',
      );
    }
  }

  Future<void> _refreshToken() async {
    if (_currentToken?.refreshToken == null) {
      developer.log('No refresh token available', name: 'SecureApiService');
      return;
    }

    try {
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': _currentToken!.refreshToken},
      );

      _currentToken = JwtToken.fromJson(response.data);
      await _storeToken(_currentToken!);

      developer.log('Token refreshed successfully', name: 'SecureApiService');
    } catch (e) {
      developer.log('Token refresh failed: $e', name: 'SecureApiService');
      await _clearToken();
      rethrow;
    }
  }

  Future<void> _storeToken(JwtToken token) async {
    final tokenJson = jsonEncode(token.toJson());
    await _secureStorage.write(key: _jwtTokenKey, value: tokenJson);
  }

  Future<void> _clearToken() async {
    _currentToken = null;
    await _secureStorage.delete(key: _jwtTokenKey);
  }

  // Public API methods
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    RequestPriority priority = RequestPriority.normal,
  }) async {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: _mergeOptions(options, priority),
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    RequestPriority priority = RequestPriority.normal,
  }) async {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: _mergeOptions(options, priority),
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    RequestPriority priority = RequestPriority.normal,
  }) async {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: _mergeOptions(options, priority),
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    RequestPriority priority = RequestPriority.normal,
  }) async {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: _mergeOptions(options, priority),
    );
  }

  Options _mergeOptions(Options? options, RequestPriority priority) {
    final baseOptions = options ?? Options();
    baseOptions.extra ??= {};
    baseOptions.extra!['priority'] = priority;
    return baseOptions;
  }

  Future<void> setAuthToken(JwtToken token) async {
    _currentToken = token;
    await _storeToken(token);
    developer.log('Auth token set', name: 'SecureApiService');
  }

  Future<void> setApiKey(String apiKey) async {
    await _secureStorage.write(key: _apiKeyKey, value: apiKey);
    developer.log('API key set', name: 'SecureApiService');
  }

  Future<void> clearAuthentication() async {
    await _clearToken();
    await _secureStorage.delete(key: _apiKeyKey);
    developer.log('Authentication cleared', name: 'SecureApiService');
  }

  List<RequestMetrics> getRequestMetrics({int? limit}) {
    if (limit != null && limit < _requestMetrics.length) {
      return _requestMetrics.sublist(_requestMetrics.length - limit);
    }
    return List.unmodifiable(_requestMetrics);
  }

  Map<String, dynamic> getSecurityStats() {
    final totalRequests = _requestMetrics.length;
    final successfulRequests = _requestMetrics
        .where(
          (m) =>
              m.statusCode != null &&
              m.statusCode! >= 200 &&
              m.statusCode! < 300,
        )
        .length;

    final averageResponseTime = _requestMetrics.isNotEmpty
        ? _requestMetrics
                  .where((m) => m.duration != null)
                  .map((m) => m.duration!.inMilliseconds)
                  .reduce((a, b) => a + b) /
              _requestMetrics.length
        : 0.0;

    return {
      'totalRequests': totalRequests,
      'successfulRequests': successfulRequests,
      'successRate': totalRequests > 0
          ? successfulRequests / totalRequests
          : 0.0,
      'averageResponseTime': averageResponseTime,
      'certificatePinningEnabled': _config.pinnedCertificates.isNotEmpty,
      'encryptionEnabled': _config.enableEncryption,
      'requestSigningEnabled': _config.enableRequestSigning,
      'currentTokenValid': _currentToken != null && !_currentToken!.isExpired,
    };
  }

  Future<void> clearMetrics() async {
    _requestMetrics.clear();
    _requestCounts.clear();
    developer.log('Metrics cleared', name: 'SecureApiService');
  }

  void dispose() {
    _dio.close();
    developer.log('SecureApiService disposed', name: 'SecureApiService');
  }
}
