/// User rights management service for GDPR compliance
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/gdpr/user_rights_request.dart';
import '../enums/data_category.dart';
import 'gdpr_compliance_service.dart';

/// Service for managing user rights requests and fulfillment under GDPR
class UserRightsManager {
  static const String _requestsStorageKey = 'gdpr_user_rights_requests';
  static const int _defaultResponseTimeDays = 30;

  bool _isInitialized = false;
  SharedPreferences? _prefs;

  /// In-memory cache of user rights requests
  final Map<String, UserRightsRequest> _requestsCache = {};

  /// Stream controller for user rights events
  final StreamController<UserRightsEvent> _eventController =
      StreamController<UserRightsEvent>.broadcast();

  /// Initialize the user rights manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log('UserRightsManager: Initializing...');

      _prefs = await SharedPreferences.getInstance();
      await _loadUserRightsRequests();

      _isInitialized = true;
      log('UserRightsManager: Initialization completed');
    } catch (e) {
      log('UserRightsManager: Initialization failed: $e');
      throw GDPRComplianceException(
        'Failed to initialize user rights manager: $e',
      );
    }
  }

  /// Dispose of the user rights manager
  Future<void> dispose() async {
    try {
      await _eventController.close();
      _requestsCache.clear();
      _isInitialized = false;
      log('UserRightsManager: Disposed');
    } catch (e) {
      log('UserRightsManager: Error during disposal: $e');
    }
  }

  /// Stream of user rights events
  Stream<UserRightsEvent> get events => _eventController.stream;

  /// Submit a user rights request
  Future<UserRightsRequest> submitRequest({
    required String userId,
    required UserRightType rightType,
    required String description,
    List<String> dataCategories = const [],
    String? verificationMethod,
    int priority = 1,
    Map<String, dynamic> metadata = const {},
  }) async {
    _ensureInitialized();

    try {
      final now = DateTime.now();
      final dueDate = now.add(Duration(days: _defaultResponseTimeDays));

      final request = UserRightsRequest(
        id: _generateRequestId(userId, rightType),
        userId: userId,
        rightType: rightType,
        status: RequestStatus.pending,
        description: description,
        dataCategories: dataCategories,
        verificationMethod: verificationMethod,
        identityVerified: false,
        submittedAt: now,
        dueDate: dueDate,
        priority: priority,
        involvesSensitiveData: _checkIfInvolvesSensitiveData(dataCategories),
        metadata: metadata,
        createdAt: now,
        updatedAt: now,
      );

      await _storeRequest(request);

      _eventController.add(UserRightsEvent.requestSubmitted(request));

      log('UserRightsManager: User rights request submitted: ${request.id}');
      return request;
    } catch (e) {
      log('UserRightsManager: Error submitting request: $e');
      throw GDPRComplianceException('Failed to submit user rights request: $e');
    }
  }

  /// Update request status
  Future<UserRightsRequest> updateRequestStatus({
    required String requestId,
    required RequestStatus status,
    String? assignedTo,
    String? processingNotes,
    String? rejectionReason,
  }) async {
    _ensureInitialized();

    try {
      final request = _requestsCache[requestId];
      if (request == null) {
        throw GDPRComplianceException('Request not found: $requestId');
      }

      final now = DateTime.now();
      final updatedRequest = request.copyWith(
        status: status,
        processingStartedAt: status == RequestStatus.inProgress
            ? (request.processingStartedAt ?? now)
            : request.processingStartedAt,
        completedAt: status.isFinal ? now : null,
        assignedTo: assignedTo ?? request.assignedTo,
        processingNotes: processingNotes ?? request.processingNotes,
        rejectionReason: rejectionReason ?? request.rejectionReason,
        updatedAt: now,
      );

      await _storeRequest(updatedRequest);

      _eventController.add(UserRightsEvent.statusUpdated(updatedRequest));

      log(
        'UserRightsManager: Request status updated: ${request.id} -> ${status.value}',
      );
      return updatedRequest;
    } catch (e) {
      log('UserRightsManager: Error updating request status: $e');
      throw GDPRComplianceException('Failed to update request status: $e');
    }
  }

  /// Process right to access request
  Future<String> processAccessRequest(String requestId) async {
    _ensureInitialized();

    try {
      final request = _requestsCache[requestId];
      if (request == null || request.rightType != UserRightType.access) {
        throw GDPRComplianceException('Invalid access request: $requestId');
      }

      // Update status to in progress
      await updateRequestStatus(
        requestId: requestId,
        status: RequestStatus.inProgress,
        processingNotes: 'Generating data export...',
      );

      // Generate data export
      final exportFilePath = await _generateDataExport(
        request.userId,
        request.dataCategories,
      );

      // Update request with completion
      final completedRequest = request.copyWith(
        status: RequestStatus.completed,
        fulfillmentFiles: [exportFilePath],
        processingNotes: 'Data export generated successfully',
        completedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _storeRequest(completedRequest);

      _eventController.add(UserRightsEvent.requestCompleted(completedRequest));

      log('UserRightsManager: Access request processed: $requestId');
      return exportFilePath;
    } catch (e) {
      log('UserRightsManager: Error processing access request: $e');

      // Update request with failed status
      if (_requestsCache.containsKey(requestId)) {
        await updateRequestStatus(
          requestId: requestId,
          status: RequestStatus.failed,
          processingNotes: 'Failed to process request: $e',
        );
      }

      throw GDPRComplianceException('Failed to process access request: $e');
    }
  }

  /// Process right to erasure request
  Future<void> processErasureRequest(String requestId) async {
    _ensureInitialized();

    try {
      final request = _requestsCache[requestId];
      if (request == null || request.rightType != UserRightType.erasure) {
        throw GDPRComplianceException('Invalid erasure request: $requestId');
      }

      // Update status to in progress
      await updateRequestStatus(
        requestId: requestId,
        status: RequestStatus.inProgress,
        processingNotes: 'Processing data deletion...',
      );

      // Perform data deletion
      await _performDataDeletion(request.userId, request.dataCategories);

      // Update request with completion
      await updateRequestStatus(
        requestId: requestId,
        status: RequestStatus.completed,
        processingNotes: 'Data deletion completed successfully',
      );

      _eventController.add(UserRightsEvent.requestCompleted(request));

      log('UserRightsManager: Erasure request processed: $requestId');
    } catch (e) {
      log('UserRightsManager: Error processing erasure request: $e');

      // Update request with failed status
      if (_requestsCache.containsKey(requestId)) {
        await updateRequestStatus(
          requestId: requestId,
          status: RequestStatus.failed,
          processingNotes: 'Failed to process request: $e',
        );
      }

      throw GDPRComplianceException('Failed to process erasure request: $e');
    }
  }

  /// Process right to rectification request
  Future<void> processRectificationRequest(
    String requestId,
    Map<String, dynamic> corrections,
  ) async {
    _ensureInitialized();

    try {
      final request = _requestsCache[requestId];
      if (request == null || request.rightType != UserRightType.rectification) {
        throw GDPRComplianceException(
          'Invalid rectification request: $requestId',
        );
      }

      // Update status to in progress
      await updateRequestStatus(
        requestId: requestId,
        status: RequestStatus.inProgress,
        processingNotes: 'Applying data corrections...',
      );

      // Apply data corrections
      await _applyDataCorrections(request.userId, corrections);

      // Update request with completion
      await updateRequestStatus(
        requestId: requestId,
        status: RequestStatus.completed,
        processingNotes: 'Data corrections applied successfully',
      );

      _eventController.add(UserRightsEvent.requestCompleted(request));

      log('UserRightsManager: Rectification request processed: $requestId');
    } catch (e) {
      log('UserRightsManager: Error processing rectification request: $e');

      // Update request with failed status
      if (_requestsCache.containsKey(requestId)) {
        await updateRequestStatus(
          requestId: requestId,
          status: RequestStatus.failed,
          processingNotes: 'Failed to process request: $e',
        );
      }

      throw GDPRComplianceException(
        'Failed to process rectification request: $e',
      );
    }
  }

  /// Process right to portability request
  Future<String> processPortabilityRequest(
    String requestId,
    String format,
  ) async {
    _ensureInitialized();

    try {
      final request = _requestsCache[requestId];
      if (request == null || request.rightType != UserRightType.portability) {
        throw GDPRComplianceException(
          'Invalid portability request: $requestId',
        );
      }

      // Update status to in progress
      await updateRequestStatus(
        requestId: requestId,
        status: RequestStatus.inProgress,
        processingNotes: 'Generating portable data export...',
      );

      // Generate portable data export
      final exportFilePath = await _generatePortableDataExport(
        request.userId,
        request.dataCategories,
        format,
      );

      // Update request with completion
      final completedRequest = request.copyWith(
        status: RequestStatus.completed,
        fulfillmentFiles: [exportFilePath],
        processingNotes: 'Portable data export generated successfully',
        completedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _storeRequest(completedRequest);

      _eventController.add(UserRightsEvent.requestCompleted(completedRequest));

      log('UserRightsManager: Portability request processed: $requestId');
      return exportFilePath;
    } catch (e) {
      log('UserRightsManager: Error processing portability request: $e');

      // Update request with failed status
      if (_requestsCache.containsKey(requestId)) {
        await updateRequestStatus(
          requestId: requestId,
          status: RequestStatus.failed,
          processingNotes: 'Failed to process request: $e',
        );
      }

      throw GDPRComplianceException(
        'Failed to process portability request: $e',
      );
    }
  }

  /// Get user rights request by ID
  Future<UserRightsRequest?> getRequest(String requestId) async {
    _ensureInitialized();
    return _requestsCache[requestId];
  }

  /// Get all requests for a specific user
  Future<List<UserRightsRequest>> getUserRequests(String userId) async {
    _ensureInitialized();

    return _requestsCache.values
        .where((request) => request.userId == userId)
        .toList();
  }

  /// Get pending requests for a specific user
  Future<List<UserRightsRequest>> getPendingRequests(String userId) async {
    _ensureInitialized();

    return _requestsCache.values
        .where((request) => request.userId == userId && request.status.isActive)
        .toList();
  }

  /// Get all requests across all users
  Future<List<UserRightsRequest>> getAllRequests() async {
    _ensureInitialized();
    return _requestsCache.values.toList();
  }

  /// Get overdue requests
  Future<List<UserRightsRequest>> getOverdueRequests() async {
    _ensureInitialized();

    return _requestsCache.values.where((request) => request.isOverdue).toList();
  }

  /// Get requests requiring urgent attention
  Future<List<UserRightsRequest>> getUrgentRequests() async {
    _ensureInitialized();

    return _requestsCache.values
        .where((request) => request.needsUrgentAttention)
        .toList();
  }

  /// Verify user identity for a request
  Future<UserRightsRequest> verifyIdentity({
    required String requestId,
    required String verificationMethod,
    Map<String, dynamic> verificationData = const {},
  }) async {
    _ensureInitialized();

    try {
      final request = _requestsCache[requestId];
      if (request == null) {
        throw GDPRComplianceException('Request not found: $requestId');
      }

      final verifiedRequest = request.copyWith(
        identityVerified: true,
        verificationMethod: verificationMethod,
        metadata: {
          ...request.metadata,
          'verification_completed_at': DateTime.now().toIso8601String(),
          'verification_data': verificationData,
        },
        updatedAt: DateTime.now(),
      );

      await _storeRequest(verifiedRequest);

      _eventController.add(UserRightsEvent.identityVerified(verifiedRequest));

      log('UserRightsManager: Identity verified for request: $requestId');
      return verifiedRequest;
    } catch (e) {
      log('UserRightsManager: Error verifying identity: $e');
      throw GDPRComplianceException('Failed to verify identity: $e');
    }
  }

  /// Generate data export for access request
  Future<String> _generateDataExport(
    String userId,
    List<String> dataCategories,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${directory.path}/gdpr_exports');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final exportFile = File(
        '${exportDir.path}/user_data_${userId}_$timestamp.json',
      );

      // Collect user data based on requested categories
      final userData = await _collectUserData(userId, dataCategories);

      // Write data to file
      await exportFile.writeAsString(jsonEncode(userData));

      log('UserRightsManager: Data export generated: ${exportFile.path}');
      return exportFile.path;
    } catch (e) {
      log('UserRightsManager: Error generating data export: $e');
      throw GDPRComplianceException('Failed to generate data export: $e');
    }
  }

  /// Generate portable data export for portability request
  Future<String> _generatePortableDataExport(
    String userId,
    List<String> dataCategories,
    String format,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${directory.path}/gdpr_exports');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = format.toLowerCase() == 'xml' ? 'xml' : 'json';
      final exportFile = File(
        '${exportDir.path}/portable_data_${userId}_$timestamp.$extension',
      );

      // Collect user data in portable format
      final userData = await _collectUserDataPortable(
        userId,
        dataCategories,
        format,
      );

      // Write data to file
      await exportFile.writeAsString(userData);

      log(
        'UserRightsManager: Portable data export generated: ${exportFile.path}',
      );
      return exportFile.path;
    } catch (e) {
      log('UserRightsManager: Error generating portable data export: $e');
      throw GDPRComplianceException(
        'Failed to generate portable data export: $e',
      );
    }
  }

  /// Collect user data for export
  Future<Map<String, dynamic>> _collectUserData(
    String userId,
    List<String> dataCategories,
  ) async {
    final userData = <String, dynamic>{
      'user_id': userId,
      'export_timestamp': DateTime.now().toIso8601String(),
      'export_type': 'gdpr_access_request',
      'data_categories': dataCategories,
      'data': {},
    };

    // TODO: Implement actual data collection from various sources
    // This would integrate with your app's data storage systems

    for (final categoryStr in dataCategories) {
      final category = DataCategory.fromString(categoryStr);

      switch (category) {
        case DataCategory.personalInfo:
          userData['data']['personal_info'] = {
            'note': 'Personal information data would be collected here',
          };
          break;
        case DataCategory.audioData:
          userData['data']['audio_data'] = {
            'note': 'Audio recording data would be collected here',
          };
          break;
        case DataCategory.transcriptionData:
          userData['data']['transcription_data'] = {
            'note': 'Transcription data would be collected here',
          };
          break;
        case DataCategory.summaryData:
          userData['data']['summary_data'] = {
            'note': 'Summary data would be collected here',
          };
          break;
        default:
          userData['data'][category.value] = {
            'note': 'Data for ${category.displayName} would be collected here',
          };
      }
    }

    return userData;
  }

  /// Collect user data in portable format
  Future<String> _collectUserDataPortable(
    String userId,
    List<String> dataCategories,
    String format,
  ) async {
    final userData = await _collectUserData(userId, dataCategories);

    if (format.toLowerCase() == 'xml') {
      // Simple XML conversion (in production, use a proper XML library)
      return _convertToXML(userData);
    }

    return jsonEncode(userData);
  }

  /// Simple XML conversion (placeholder implementation)
  String _convertToXML(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<user_data>');

    data.forEach((key, value) {
      buffer.writeln('  <$key>$value</$key>');
    });

    buffer.writeln('</user_data>');
    return buffer.toString();
  }

  /// Perform data deletion for erasure request
  Future<void> _performDataDeletion(
    String userId,
    List<String> dataCategories,
  ) async {
    // TODO: Implement actual data deletion from various sources
    // This would integrate with your app's data storage systems

    log(
      'UserRightsManager: Data deletion would be performed for user $userId, categories: $dataCategories',
    );

    // Example of what would happen:
    // - Delete user records from database
    // - Remove audio files
    // - Clear transcription data
    // - Remove summary data
    // - Clear cache and preferences
    // - Anonymize any data that cannot be deleted for legal reasons
  }

  /// Apply data corrections for rectification request
  Future<void> _applyDataCorrections(
    String userId,
    Map<String, dynamic> corrections,
  ) async {
    // TODO: Implement actual data corrections in various sources
    // This would integrate with your app's data storage systems

    log(
      'UserRightsManager: Data corrections would be applied for user $userId: $corrections',
    );

    // Example of what would happen:
    // - Update user profile information
    // - Correct transcription data
    // - Update summary information
    // - Modify metadata
  }

  /// Check if request involves sensitive data categories
  bool _checkIfInvolvesSensitiveData(List<String> dataCategories) {
    for (final categoryStr in dataCategories) {
      final category = DataCategory.fromString(categoryStr);
      if (category.isSensitive) return true;
    }
    return false;
  }

  /// Load user rights requests from storage
  Future<void> _loadUserRightsRequests() async {
    try {
      final storedData = _prefs!.getString(_requestsStorageKey);
      if (storedData != null) {
        final Map<String, dynamic> data = jsonDecode(storedData);

        _requestsCache.clear();
        data.forEach((requestId, requestJson) {
          final request = UserRightsRequest.fromJson(
            requestJson as Map<String, dynamic>,
          );
          _requestsCache[requestId] = request;
        });

        log(
          'UserRightsManager: Loaded ${_requestsCache.length} user rights requests',
        );
      }
    } catch (e) {
      log('UserRightsManager: Error loading user rights requests: $e');
      _requestsCache.clear();
    }
  }

  /// Save user rights requests to storage
  Future<void> _saveUserRightsRequests() async {
    try {
      final Map<String, dynamic> data = {};
      _requestsCache.forEach((requestId, request) {
        data[requestId] = request.toJson();
      });

      await _prefs!.setString(_requestsStorageKey, jsonEncode(data));
    } catch (e) {
      log('UserRightsManager: Error saving user rights requests: $e');
      throw GDPRComplianceException('Failed to save user rights requests: $e');
    }
  }

  /// Store a user rights request
  Future<void> _storeRequest(UserRightsRequest request) async {
    try {
      _requestsCache[request.id] = request;
      await _saveUserRightsRequests();
    } catch (e) {
      log('UserRightsManager: Error storing request: $e');
      throw GDPRComplianceException('Failed to store user rights request: $e');
    }
  }

  /// Generate unique request ID
  String _generateRequestId(String userId, UserRightType rightType) {
    return 'rights_${userId}_${rightType.value}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Ensure manager is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw GDPRComplianceException('User rights manager not initialized');
    }
  }
}

/// User rights event for notifications
class UserRightsEvent {
  final String type;
  final UserRightsRequest request;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  const UserRightsEvent({
    required this.type,
    required this.request,
    required this.timestamp,
    this.data = const {},
  });

  factory UserRightsEvent.requestSubmitted(UserRightsRequest request) {
    return UserRightsEvent(
      type: 'request_submitted',
      request: request,
      timestamp: DateTime.now(),
      data: {'rightType': request.rightType.value},
    );
  }

  factory UserRightsEvent.statusUpdated(UserRightsRequest request) {
    return UserRightsEvent(
      type: 'status_updated',
      request: request,
      timestamp: DateTime.now(),
      data: {'status': request.status.value},
    );
  }

  factory UserRightsEvent.requestCompleted(UserRightsRequest request) {
    return UserRightsEvent(
      type: 'request_completed',
      request: request,
      timestamp: DateTime.now(),
      data: {'rightType': request.rightType.value},
    );
  }

  factory UserRightsEvent.identityVerified(UserRightsRequest request) {
    return UserRightsEvent(
      type: 'identity_verified',
      request: request,
      timestamp: DateTime.now(),
      data: {'verificationMethod': request.verificationMethod},
    );
  }
}
