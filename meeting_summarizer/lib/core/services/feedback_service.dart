import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/feedback/feedback_item.dart';
import '../models/feedback/feedback_analytics.dart';
import '../database/database_helper.dart';

/// Service for managing user feedback, ratings, and app store reviews
class FeedbackService {
  static const String _feedbackTableName = 'feedback_items';
  static const String _lastRatingPromptKey = 'last_rating_prompt';
  static const String _appLaunchCountKey = 'app_launch_count';
  static const String _feedbackSubmittedKey = 'feedback_submitted';
  static const String _neverShowRatingKey = 'never_show_rating';
  static const String _hasRatedAppKey = 'has_rated_app';

  final DatabaseHelper _databaseHelper;
  final SharedPreferences _prefs;
  final InAppReview _inAppReview;
  final Uuid _uuid;

  /// Stream controller for feedback events
  final StreamController<FeedbackItem> _feedbackController =
      StreamController<FeedbackItem>.broadcast();

  /// Stream of feedback submission events
  Stream<FeedbackItem> get feedbackStream => _feedbackController.stream;

  FeedbackService({
    required DatabaseHelper databaseHelper,
    required SharedPreferences prefs,
    InAppReview? inAppReview,
    Uuid? uuid,
  }) : _databaseHelper = databaseHelper,
       _prefs = prefs,
       _inAppReview = inAppReview ?? InAppReview.instance,
       _uuid = uuid ?? const Uuid();

  /// Initialize the feedback service and create necessary tables
  Future<void> initialize() async {
    try {
      await _createFeedbackTable();
      await _incrementAppLaunchCount();
      developer.log(
        'FeedbackService initialized successfully',
        name: 'FeedbackService',
      );
    } catch (e) {
      developer.log(
        'Failed to initialize FeedbackService: $e',
        name: 'FeedbackService',
        level: 1000,
      );
      rethrow;
    }
  }

  /// Create the feedback table if it doesn't exist
  Future<void> _createFeedbackTable() async {
    const createTableQuery =
        '''
      CREATE TABLE IF NOT EXISTS $_feedbackTableName (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        rating INTEGER,
        subject TEXT NOT NULL,
        message TEXT NOT NULL,
        email TEXT,
        app_version TEXT NOT NULL,
        platform TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        is_submitted INTEGER NOT NULL DEFAULT 0,
        attachment_path TEXT,
        tags TEXT NOT NULL
      )
    ''';

    final db = await _databaseHelper.database;
    await db.execute(createTableQuery);
  }

  /// Increment app launch count for rating prompt timing
  Future<void> _incrementAppLaunchCount() async {
    final currentCount = _prefs.getInt(_appLaunchCountKey) ?? 0;
    await _prefs.setInt(_appLaunchCountKey, currentCount + 1);
  }

  /// Submit feedback item to local storage and optionally to remote service
  Future<String> submitFeedback({
    required FeedbackType type,
    int? rating,
    required String subject,
    required String message,
    String? email,
    String? attachmentPath,
    List<String> tags = const [],
  }) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final feedbackId = _uuid.v4();

      final feedback = FeedbackItem(
        id: feedbackId,
        type: type,
        rating: rating,
        subject: subject,
        message: message,
        email: email,
        appVersion: packageInfo.version,
        platform: _getCurrentPlatform(),
        createdAt: DateTime.now(),
        isSubmitted: true,
        attachmentPath: attachmentPath,
        tags: tags,
      );

      await _storeFeedback(feedback);

      // Mark that user has submitted feedback
      await _prefs.setBool(_feedbackSubmittedKey, true);

      // Emit feedback event
      _feedbackController.add(feedback);

      developer.log(
        'Feedback submitted successfully: ${feedback.id}',
        name: 'FeedbackService',
      );

      return feedbackId;
    } catch (e) {
      developer.log(
        'Failed to submit feedback: $e',
        name: 'FeedbackService',
        level: 1000,
      );
      rethrow;
    }
  }

  /// Store feedback in local database
  Future<void> _storeFeedback(FeedbackItem feedback) async {
    const insertQuery =
        '''
      INSERT INTO $_feedbackTableName (
        id, type, rating, subject, message, email, app_version, platform,
        created_at, is_submitted, attachment_path, tags
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''';

    final db = await _databaseHelper.database;
    await db.rawInsert(insertQuery, [
      feedback.id,
      feedback.type.name,
      feedback.rating,
      feedback.subject,
      feedback.message,
      feedback.email,
      feedback.appVersion,
      feedback.platform,
      feedback.createdAt.millisecondsSinceEpoch,
      feedback.isSubmitted ? 1 : 0,
      feedback.attachmentPath,
      feedback.tags.join(','),
    ]);
  }

  /// Get all feedback items
  Future<List<FeedbackItem>> getAllFeedback() async {
    try {
      const query =
          'SELECT * FROM $_feedbackTableName ORDER BY created_at DESC';
      final db = await _databaseHelper.database;
      final results = await db.rawQuery(query);

      return results.map((row) => _feedbackFromRow(row)).toList();
    } catch (e) {
      developer.log(
        'Failed to get feedback: $e',
        name: 'FeedbackService',
        level: 1000,
      );
      return [];
    }
  }

  /// Get feedback analytics
  Future<FeedbackAnalytics> getFeedbackAnalytics() async {
    try {
      final feedback = await getAllFeedback();
      return FeedbackAnalytics.fromFeedbackList(feedback);
    } catch (e) {
      developer.log(
        'Failed to get feedback analytics: $e',
        name: 'FeedbackService',
        level: 1000,
      );
      return FeedbackAnalytics.empty();
    }
  }

  /// Check if we should show rating prompt based on usage patterns
  Future<bool> shouldShowRatingPrompt() async {
    try {
      // Don't show if user explicitly opted out
      if (_prefs.getBool(_neverShowRatingKey) ?? false) {
        return false;
      }

      // Don't show if already rated
      if (_prefs.getBool(_hasRatedAppKey) ?? false) {
        return false;
      }

      // Check app launch count (show after 10 launches)
      final launchCount = _prefs.getInt(_appLaunchCountKey) ?? 0;
      if (launchCount < 10) {
        return false;
      }

      // Check time since last prompt (wait at least 7 days)
      final lastPrompt = _prefs.getInt(_lastRatingPromptKey);
      if (lastPrompt != null) {
        final daysSinceLastPrompt = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(lastPrompt))
            .inDays;
        if (daysSinceLastPrompt < 7) {
          return false;
        }
      }

      // Check if user has already provided feedback
      final hasFeedback = _prefs.getBool(_feedbackSubmittedKey) ?? false;
      if (hasFeedback) {
        final analytics = await getFeedbackAnalytics();
        // Only show app store prompt if we have good ratings
        return analytics.shouldPromptAppStoreReview;
      }

      return true;
    } catch (e) {
      developer.log(
        'Error checking rating prompt eligibility: $e',
        name: 'FeedbackService',
        level: 1000,
      );
      return false;
    }
  }

  /// Show rating prompt to user
  Future<bool> showRatingPrompt() async {
    try {
      // Update last prompt time
      await _prefs.setInt(
        _lastRatingPromptKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      // Check if in-app review is available
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        await _prefs.setBool(_hasRatedAppKey, true);
        return true;
      } else {
        // Fallback to opening app store
        await _inAppReview.openStoreListing();
        return true;
      }
    } catch (e) {
      developer.log(
        'Failed to show rating prompt: $e',
        name: 'FeedbackService',
        level: 1000,
      );
      return false;
    }
  }

  /// User chose not to rate the app
  Future<void> neverShowRatingPrompt() async {
    await _prefs.setBool(_neverShowRatingKey, true);
  }

  /// Get current platform string
  String _getCurrentPlatform() {
    if (kIsWeb) {
      return 'web';
    } else if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isIOS) {
      return 'ios';
    } else if (Platform.isMacOS) {
      return 'macos';
    } else if (Platform.isWindows) {
      return 'windows';
    } else if (Platform.isLinux) {
      return 'linux';
    } else {
      return 'unknown';
    }
  }

  /// Convert database row to FeedbackItem
  FeedbackItem _feedbackFromRow(Map<String, dynamic> row) {
    return FeedbackItem(
      id: row['id'] as String,
      type: FeedbackType.values.firstWhere(
        (t) => t.name == row['type'],
        orElse: () => FeedbackType.general,
      ),
      rating: row['rating'] as int?,
      subject: row['subject'] as String,
      message: row['message'] as String,
      email: row['email'] as String?,
      appVersion: row['app_version'] as String,
      platform: row['platform'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      isSubmitted: (row['is_submitted'] as int) == 1,
      attachmentPath: row['attachment_path'] as String?,
      tags: (row['tags'] as String)
          .split(',')
          .where((t) => t.isNotEmpty)
          .toList(),
    );
  }

  /// Get feedback statistics for debugging/admin purposes
  Future<Map<String, dynamic>> getFeedbackStats() async {
    try {
      final analytics = await getFeedbackAnalytics();
      final launchCount = _prefs.getInt(_appLaunchCountKey) ?? 0;
      final hasRated = _prefs.getBool(_hasRatedAppKey) ?? false;
      final neverShow = _prefs.getBool(_neverShowRatingKey) ?? false;

      return {
        'totalFeedback': analytics.totalFeedback,
        'averageRating': analytics.averageRating,
        'appLaunchCount': launchCount,
        'hasRatedApp': hasRated,
        'neverShowRating': neverShow,
        'shouldShowPrompt': await shouldShowRatingPrompt(),
      };
    } catch (e) {
      developer.log(
        'Failed to get feedback stats: $e',
        name: 'FeedbackService',
        level: 1000,
      );
      return {};
    }
  }

  /// Clean up resources
  void dispose() {
    _feedbackController.close();
  }
}
