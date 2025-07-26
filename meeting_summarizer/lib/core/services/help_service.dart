import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as dev;

import '../models/help/help_article.dart';
import '../models/help/faq_item.dart';
import '../models/help/contextual_help.dart';
import 'help_service_interface.dart';

/// Implementation of help system service
class HelpService implements HelpServiceInterface {
  static HelpService? _instance;
  static HelpService get instance => _instance ??= HelpService._internal();

  HelpService._internal();

  // Cache keys
  static const String _articlesKey = 'help_articles_cache';
  static const String _faqsKey = 'help_faqs_cache';
  static const String _categoriesKey = 'help_categories_cache';
  static const String _contextualHelpKey = 'help_contextual_cache';
  static const String _toursKey = 'help_tours_cache';
  static const String _analyticsKey = 'help_analytics';
  static const String _shownHelpKey = 'shown_contextual_help';
  static const String _completedToursKey = 'completed_tours';

  // Cache variables
  List<HelpArticle>? _cachedArticles;
  List<FaqItem>? _cachedFaqs;
  List<HelpCategory>? _cachedCategories;
  List<ContextualHelp>? _cachedContextualHelp;
  List<HelpTour>? _cachedTours;

  // Initialization flag
  bool _initialized = false;

  /// Initialize the help system
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _loadHelpContent();
      _initialized = true;
      dev.log('Help service initialized successfully', name: 'HelpService');
    } catch (e) {
      dev.log(
        'Failed to initialize help service: $e',
        name: 'HelpService',
        level: 900,
      );
      rethrow;
    }
  }

  /// Load help content from assets and cache
  Future<void> _loadHelpContent() async {
    try {
      // Load categories first
      await _loadCategories();

      // Load articles
      await _loadArticles();

      // Load FAQs
      await _loadFaqs();

      // Load contextual help
      await _loadContextualHelp();

      // Load tours
      await _loadTours();

      dev.log('Help content loaded successfully', name: 'HelpService');
    } catch (e) {
      dev.log(
        'Error loading help content: $e',
        name: 'HelpService',
        level: 900,
      );
      rethrow;
    }
  }

  /// Load categories from assets
  Future<void> _loadCategories() async {
    if (_cachedCategories != null) return;

    try {
      _cachedCategories = _getDefaultCategories();
      dev.log(
        'Loaded ${_cachedCategories!.length} help categories',
        name: 'HelpService',
      );
    } catch (e) {
      dev.log('Error loading categories: $e', name: 'HelpService', level: 900);
      _cachedCategories = _getDefaultCategories();
    }
  }

  /// Load articles from assets or cache
  Future<void> _loadArticles() async {
    if (_cachedArticles != null) return;

    try {
      // Try to load from cache first
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_articlesKey);

      if (cachedData != null) {
        final List<dynamic> jsonList = json.decode(cachedData);
        _cachedArticles =
            jsonList.map((json) => HelpArticle.fromJson(json)).toList();
      } else {
        // Load default articles if no cache
        _cachedArticles = _getDefaultArticles();

        // Cache the default articles
        final jsonData = json.encode(
          _cachedArticles!.map((article) => article.toJson()).toList(),
        );
        await prefs.setString(_articlesKey, jsonData);
      }

      dev.log(
        'Loaded ${_cachedArticles!.length} help articles',
        name: 'HelpService',
      );
    } catch (e) {
      dev.log('Error loading articles: $e', name: 'HelpService', level: 900);
      _cachedArticles = _getDefaultArticles();
    }
  }

  /// Load FAQs from assets or cache
  Future<void> _loadFaqs() async {
    if (_cachedFaqs != null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_faqsKey);

      if (cachedData != null) {
        final List<dynamic> jsonList = json.decode(cachedData);
        _cachedFaqs = jsonList.map((json) => FaqItem.fromJson(json)).toList();
      } else {
        _cachedFaqs = _getDefaultFaqs();

        final jsonData = json.encode(
          _cachedFaqs!.map((faq) => faq.toJson()).toList(),
        );
        await prefs.setString(_faqsKey, jsonData);
      }

      dev.log('Loaded ${_cachedFaqs!.length} FAQ items', name: 'HelpService');
    } catch (e) {
      dev.log('Error loading FAQs: $e', name: 'HelpService', level: 900);
      _cachedFaqs = _getDefaultFaqs();
    }
  }

  /// Load contextual help from cache
  Future<void> _loadContextualHelp() async {
    if (_cachedContextualHelp != null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_contextualHelpKey);

      if (cachedData != null) {
        final List<dynamic> jsonList = json.decode(cachedData);
        _cachedContextualHelp =
            jsonList.map((json) => ContextualHelp.fromJson(json)).toList();
      } else {
        _cachedContextualHelp = _getDefaultContextualHelp();

        final jsonData = json.encode(
          _cachedContextualHelp!.map((help) => help.toJson()).toList(),
        );
        await prefs.setString(_contextualHelpKey, jsonData);
      }

      dev.log(
        'Loaded ${_cachedContextualHelp!.length} contextual help items',
        name: 'HelpService',
      );
    } catch (e) {
      dev.log(
        'Error loading contextual help: $e',
        name: 'HelpService',
        level: 900,
      );
      _cachedContextualHelp = _getDefaultContextualHelp();
    }
  }

  /// Load tours from cache
  Future<void> _loadTours() async {
    if (_cachedTours != null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_toursKey);

      if (cachedData != null) {
        final List<dynamic> jsonList = json.decode(cachedData);
        _cachedTours = jsonList.map((json) => HelpTour.fromJson(json)).toList();
      } else {
        _cachedTours = _getDefaultTours();

        final jsonData = json.encode(
          _cachedTours!.map((tour) => tour.toJson()).toList(),
        );
        await prefs.setString(_toursKey, jsonData);
      }

      dev.log('Loaded ${_cachedTours!.length} help tours', name: 'HelpService');
    } catch (e) {
      dev.log('Error loading tours: $e', name: 'HelpService', level: 900);
      _cachedTours = _getDefaultTours();
    }
  }

  @override
  Future<List<HelpArticle>> getAllArticles() async {
    await initialize();
    return List.from(_cachedArticles ?? []);
  }

  @override
  Future<List<HelpArticle>> getArticlesByCategory(String categoryId) async {
    final articles = await getAllArticles();
    return articles
        .where((article) => article.category.id == categoryId)
        .toList();
  }

  @override
  Future<List<HelpArticle>> getFeaturedArticles() async {
    final articles = await getAllArticles();
    return articles.where((article) => article.isFeatured).toList();
  }

  @override
  Future<HelpArticle?> getArticleById(String id) async {
    final articles = await getAllArticles();
    try {
      return articles.firstWhere((article) => article.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<HelpArticle>> searchArticles(String query) async {
    if (query.isEmpty) return getAllArticles();

    final articles = await getAllArticles();
    final lowercaseQuery = query.toLowerCase();

    return articles.where((article) {
      return article.title.toLowerCase().contains(lowercaseQuery) ||
          article.content.toLowerCase().contains(lowercaseQuery) ||
          article.excerpt.toLowerCase().contains(lowercaseQuery) ||
          article.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  @override
  Future<void> incrementArticleViews(String articleId) async {
    try {
      await trackHelpEvent('article_viewed', {'articleId': articleId});
      dev.log('Incremented views for article: $articleId', name: 'HelpService');
    } catch (e) {
      dev.log(
        'Error incrementing article views: $e',
        name: 'HelpService',
        level: 900,
      );
    }
  }

  @override
  Future<List<FaqItem>> getAllFaqs() async {
    await initialize();
    return List.from(_cachedFaqs ?? []);
  }

  @override
  Future<List<FaqItem>> getFaqsByCategory(String categoryId) async {
    final faqs = await getAllFaqs();
    return faqs.where((faq) => faq.categoryId == categoryId).toList();
  }

  @override
  Future<List<FaqItem>> getPopularFaqs() async {
    final faqs = await getAllFaqs();
    return faqs.where((faq) => faq.isPopular).toList();
  }

  @override
  Future<FaqItem?> getFaqById(String id) async {
    final faqs = await getAllFaqs();
    try {
      return faqs.firstWhere((faq) => faq.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<FaqItem>> searchFaqs(String query) async {
    if (query.isEmpty) return getAllFaqs();

    final faqs = await getAllFaqs();
    final lowercaseQuery = query.toLowerCase();

    return faqs.where((faq) {
      return faq.question.toLowerCase().contains(lowercaseQuery) ||
          faq.answer.toLowerCase().contains(lowercaseQuery) ||
          faq.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  @override
  Future<void> incrementFaqViews(String faqId) async {
    try {
      await trackHelpEvent('faq_viewed', {'faqId': faqId});
      dev.log('Incremented views for FAQ: $faqId', name: 'HelpService');
    } catch (e) {
      dev.log(
        'Error incrementing FAQ views: $e',
        name: 'HelpService',
        level: 900,
      );
    }
  }

  @override
  Future<void> voteFaqHelpfulness(String faqId, bool isHelpful) async {
    try {
      await trackHelpEvent('faq_voted', {
        'faqId': faqId,
        'isHelpful': isHelpful,
      });
      dev.log(
        'Recorded vote for FAQ: $faqId, helpful: $isHelpful',
        name: 'HelpService',
      );
    } catch (e) {
      dev.log('Error recording FAQ vote: $e', name: 'HelpService', level: 900);
    }
  }

  @override
  Future<List<HelpCategory>> getAllCategories() async {
    await initialize();
    return List.from(_cachedCategories ?? []);
  }

  @override
  Future<HelpCategory?> getCategoryById(String id) async {
    final categories = await getAllCategories();
    try {
      return categories.firstWhere((category) => category.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<ContextualHelp>> getContextualHelp(String context) async {
    await initialize();
    final contextualHelp = _cachedContextualHelp ?? [];
    return contextualHelp.where((help) => help.context == context).toList();
  }

  @override
  Future<ContextualHelp?> getContextualHelpById(String id) async {
    await initialize();
    final contextualHelp = _cachedContextualHelp ?? [];
    try {
      return contextualHelp.firstWhere((help) => help.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> markContextualHelpShown(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shownHelp = prefs.getStringList(_shownHelpKey) ?? [];
      if (!shownHelp.contains(id)) {
        shownHelp.add(id);
        await prefs.setStringList(_shownHelpKey, shownHelp);
      }
      await trackHelpEvent('contextual_help_shown', {'helpId': id});
      dev.log('Marked contextual help as shown: $id', name: 'HelpService');
    } catch (e) {
      dev.log(
        'Error marking contextual help as shown: $e',
        name: 'HelpService',
        level: 900,
      );
    }
  }

  @override
  Future<bool> shouldShowContextualHelp(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shownHelp = prefs.getStringList(_shownHelpKey) ?? [];
      return !shownHelp.contains(id);
    } catch (e) {
      dev.log(
        'Error checking contextual help status: $e',
        name: 'HelpService',
        level: 900,
      );
      return false;
    }
  }

  @override
  Future<List<HelpTour>> getAllTours() async {
    await initialize();
    return List.from(_cachedTours ?? []);
  }

  @override
  Future<HelpTour?> getTourById(String id) async {
    final tours = await getAllTours();
    try {
      return tours.firstWhere((tour) => tour.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> startTour(String tourId) async {
    try {
      await trackHelpEvent('tour_started', {'tourId': tourId});
      dev.log('Started help tour: $tourId', name: 'HelpService');
    } catch (e) {
      dev.log('Error starting tour: $e', name: 'HelpService', level: 900);
    }
  }

  @override
  Future<void> completeTour(String tourId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completedTours = prefs.getStringList(_completedToursKey) ?? [];
      if (!completedTours.contains(tourId)) {
        completedTours.add(tourId);
        await prefs.setStringList(_completedToursKey, completedTours);
      }
      await trackHelpEvent('tour_completed', {'tourId': tourId});
      dev.log('Completed help tour: $tourId', name: 'HelpService');
    } catch (e) {
      dev.log('Error completing tour: $e', name: 'HelpService', level: 900);
    }
  }

  @override
  Future<bool> isTourCompleted(String tourId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completedTours = prefs.getStringList(_completedToursKey) ?? [];
      return completedTours.contains(tourId);
    } catch (e) {
      dev.log(
        'Error checking tour completion: $e',
        name: 'HelpService',
        level: 900,
      );
      return false;
    }
  }

  @override
  Future<Map<String, List<dynamic>>> searchAll(String query) async {
    if (query.isEmpty) {
      return {'articles': await getAllArticles(), 'faqs': await getAllFaqs()};
    }

    final articles = await searchArticles(query);
    final faqs = await searchFaqs(query);

    return {'articles': articles, 'faqs': faqs};
  }

  @override
  Future<List<String>> getSearchSuggestions(String partialQuery) async {
    if (partialQuery.length < 2) return [];

    final suggestions = <String>{};
    final lowercaseQuery = partialQuery.toLowerCase();

    // Get suggestions from articles
    final articles = await getAllArticles();
    for (final article in articles) {
      if (article.title.toLowerCase().contains(lowercaseQuery)) {
        suggestions.add(article.title);
      }
      for (final tag in article.tags) {
        if (tag.toLowerCase().contains(lowercaseQuery)) {
          suggestions.add(tag);
        }
      }
    }

    // Get suggestions from FAQs
    final faqs = await getAllFaqs();
    for (final faq in faqs) {
      if (faq.question.toLowerCase().contains(lowercaseQuery)) {
        suggestions.add(faq.question);
      }
      for (final tag in faq.tags) {
        if (tag.toLowerCase().contains(lowercaseQuery)) {
          suggestions.add(tag);
        }
      }
    }

    return suggestions.take(10).toList();
  }

  @override
  Future<Map<String, dynamic>> getHelpAnalytics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final analyticsData = prefs.getString(_analyticsKey);

      if (analyticsData != null) {
        return json.decode(analyticsData);
      }

      return {};
    } catch (e) {
      dev.log(
        'Error getting help analytics: $e',
        name: 'HelpService',
        level: 900,
      );
      return {};
    }
  }

  @override
  Future<void> trackHelpEvent(String event, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final analytics = await getHelpAnalytics();

      final eventData = {
        'timestamp': DateTime.now().toIso8601String(),
        'event': event,
        'data': data,
      };

      final events = List<Map<String, dynamic>>.from(analytics['events'] ?? []);
      events.add(eventData);

      // Keep only last 1000 events
      if (events.length > 1000) {
        events.removeRange(0, events.length - 1000);
      }

      analytics['events'] = events;
      analytics['lastUpdated'] = DateTime.now().toIso8601String();

      await prefs.setString(_analyticsKey, json.encode(analytics));
    } catch (e) {
      dev.log('Error tracking help event: $e', name: 'HelpService', level: 900);
    }
  }

  @override
  Future<void> refreshCache() async {
    _cachedArticles = null;
    _cachedFaqs = null;
    _cachedCategories = null;
    _cachedContextualHelp = null;
    _cachedTours = null;
    _initialized = false;

    await initialize();
    dev.log('Help service cache refreshed', name: 'HelpService');
  }

  @override
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_articlesKey);
      await prefs.remove(_faqsKey);
      await prefs.remove(_categoriesKey);
      await prefs.remove(_contextualHelpKey);
      await prefs.remove(_toursKey);
      await prefs.remove(_analyticsKey);

      await refreshCache();
      dev.log('Help service cache cleared', name: 'HelpService');
    } catch (e) {
      dev.log('Error clearing help cache: $e', name: 'HelpService', level: 900);
    }
  }

  // Default data methods
  List<HelpCategory> _getDefaultCategories() {
    return [
      HelpCategory(
        id: 'getting-started',
        name: 'Getting Started',
        description: 'Basic setup and first steps',
        icon: Icons.play_arrow,
        color: Colors.green,
        sortOrder: 1,
      ),
      HelpCategory(
        id: 'recording',
        name: 'Recording',
        description: 'Audio recording features',
        icon: Icons.mic,
        color: Colors.red,
        sortOrder: 2,
      ),
      HelpCategory(
        id: 'transcription',
        name: 'Transcription',
        description: 'Speech-to-text features',
        icon: Icons.transcribe,
        color: Colors.blue,
        sortOrder: 3,
      ),
      HelpCategory(
        id: 'summaries',
        name: 'Summaries',
        description: 'AI-generated summaries',
        icon: Icons.summarize,
        color: Colors.purple,
        sortOrder: 4,
      ),
      HelpCategory(
        id: 'sync',
        name: 'Cloud Sync',
        description: 'Cloud storage and synchronization',
        icon: Icons.cloud,
        color: Colors.orange,
        sortOrder: 5,
      ),
      HelpCategory(
        id: 'troubleshooting',
        name: 'Troubleshooting',
        description: 'Common issues and solutions',
        icon: Icons.build,
        color: Colors.grey,
        sortOrder: 6,
      ),
    ];
  }

  List<HelpArticle> _getDefaultArticles() {
    final now = DateTime.now();
    final categories = _getDefaultCategories();

    return [
      HelpArticle(
        id: 'welcome',
        title: 'Welcome to Meeting Summarizer',
        content:
            '''Welcome to Meeting Summarizer! This powerful app helps you record, transcribe, and summarize your meetings with AI-powered features.

## Key Features

- **High-Quality Recording**: Crystal clear audio capture with background noise reduction
- **AI Transcription**: Accurate speech-to-text with speaker identification
- **Smart Summaries**: Automatically generated meeting summaries and action items
- **Cloud Sync**: Secure backup and sync across all your devices
- **Privacy First**: Your data stays secure with end-to-end encryption

## Getting Started

1. Grant microphone permissions when prompted
2. Start your first recording by tapping the record button
3. Let the app transcribe your audio automatically
4. Generate intelligent summaries with one tap
5. Save and sync your meetings to the cloud

Need help? Check out our other help articles or contact support.''',
        excerpt:
            'Learn the basics of Meeting Summarizer and get started with your first recording',
        tags: ['getting started', 'welcome', 'overview'],
        category: categories[0], // getting-started
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
        isFeatured: true,
      ),
      HelpArticle(
        id: 'recording-basics',
        title: 'Recording Your First Meeting',
        content:
            '''Recording meetings with Meeting Summarizer is simple and efficient.

## Starting a Recording

1. Open the app and navigate to the recording screen
2. Tap the red record button to start
3. The app will request microphone permission if needed
4. You'll see real-time waveforms indicating audio capture

## During Recording

- The app shows recording duration and file size
- Audio is processed in real-time for quality optimization
- You can pause and resume recording as needed
- Background noise is automatically reduced

## Stopping Recording

1. Tap the stop button when finished
2. The recording is automatically saved
3. Transcription begins immediately
4. You can add notes or tags to organize your recordings

## Best Practices

- Position your device close to speakers
- Ensure a quiet environment when possible
- Test audio quality before important meetings
- Use headphones to prevent feedback

For troubleshooting recording issues, see our troubleshooting guide.''',
        excerpt: 'Step-by-step guide to recording your meetings',
        tags: ['recording', 'audio', 'microphone'],
        category: categories[1], // recording
        createdAt: now.subtract(const Duration(days: 25)),
        updatedAt: now.subtract(const Duration(days: 25)),
        isFeatured: true,
      ),
      HelpArticle(
        id: 'transcription-guide',
        title: 'Understanding Transcription Features',
        content:
            '''Meeting Summarizer offers powerful transcription capabilities to convert your audio into text.

## Transcription Engines

- **OpenAI Whisper**: Highly accurate, supports multiple languages
- **Google Speech**: Fast processing, good for clear audio
- **Local Processing**: Privacy-focused, works offline

## Features

### Speaker Identification
The app can identify different speakers in your meetings and label them accordingly.

### Language Support
Supports over 50 languages with automatic language detection.

### Real-time Processing
Transcription begins as soon as recording stops, with live preview available.

## Accuracy Tips

1. **Clear Audio**: Ensure speakers are close to the microphone
2. **Minimize Background Noise**: Use quiet environments
3. **Good Internet**: Online services require stable connection
4. **Proper Setup**: Test audio settings before important meetings

## Editing Transcriptions

- Review and edit transcriptions for accuracy
- Add speaker names for better organization
- Include timestamps for easy reference
- Export transcriptions in multiple formats

## Privacy and Security

All transcriptions are encrypted and stored securely. Local processing keeps your data on-device.''',
        excerpt: 'Learn how to get the most accurate transcriptions',
        tags: ['transcription', 'speech-to-text', 'accuracy'],
        category: categories[2], // transcription
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(const Duration(days: 20)),
        isFeatured: true,
      ),
    ];
  }

  List<FaqItem> _getDefaultFaqs() {
    final now = DateTime.now();

    return [
      FaqItem(
        id: 'faq-permissions',
        question: 'Why does the app need microphone permission?',
        answer:
            'Meeting Summarizer needs microphone access to record audio from your meetings. This is the core functionality of the app. Your audio is processed securely and never shared without your consent.',
        tags: ['permissions', 'microphone', 'privacy'],
        categoryId: 'getting-started',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 30)),
        isPopular: true,
        helpfulVotes: 45,
        totalVotes: 50,
      ),
      FaqItem(
        id: 'faq-offline',
        question: 'Can I use the app offline?',
        answer:
            'Yes! You can record meetings offline. However, some features like AI summarization and cloud transcription require an internet connection. Local Whisper transcription works offline.',
        tags: ['offline', 'internet', 'features'],
        categoryId: 'getting-started',
        createdAt: now.subtract(const Duration(days: 25)),
        updatedAt: now.subtract(const Duration(days: 25)),
        isPopular: true,
        helpfulVotes: 38,
        totalVotes: 42,
      ),
      FaqItem(
        id: 'faq-storage',
        question: 'How much storage space do recordings take?',
        answer:
            'Recording size depends on length and quality settings. Typically, a 1-hour meeting uses about 30-60MB. You can adjust quality settings to balance file size and audio clarity.',
        tags: ['storage', 'file size', 'quality'],
        categoryId: 'recording',
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: now.subtract(const Duration(days: 20)),
        helpfulVotes: 32,
        totalVotes: 35,
      ),
      FaqItem(
        id: 'faq-languages',
        question: 'What languages are supported for transcription?',
        answer:
            'Meeting Summarizer supports over 50 languages including English, Spanish, French, German, Chinese, Japanese, and many more. The app can automatically detect the language being spoken.',
        tags: ['languages', 'transcription', 'international'],
        categoryId: 'transcription',
        createdAt: now.subtract(const Duration(days: 15)),
        updatedAt: now.subtract(const Duration(days: 15)),
        helpfulVotes: 28,
        totalVotes: 30,
      ),
      FaqItem(
        id: 'faq-cloud-sync',
        question: 'Is my data safe in the cloud?',
        answer:
            'Yes, all your data is encrypted before being stored in the cloud. We use industry-standard encryption and never access your recordings or transcriptions. You control your data completely.',
        tags: ['cloud', 'security', 'encryption', 'privacy'],
        categoryId: 'sync',
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 10)),
        isPopular: true,
        helpfulVotes: 41,
        totalVotes: 44,
      ),
    ];
  }

  List<ContextualHelp> _getDefaultContextualHelp() {
    return [
      ContextualHelp(
        id: 'recording-screen-first-visit',
        context: 'recording_screen',
        trigger: 'first_visit',
        title: 'Welcome to Recording',
        content:
            'This is where you can record your meetings. Tap the red button to start recording, and tap again to stop.',
        type: HelpTooltipType.coach,
        position: HelpTooltipPosition.center,
        displayDuration: const Duration(seconds: 5),
      ),
      ContextualHelp(
        id: 'waveform-explanation',
        context: 'recording_screen',
        trigger: 'recording_started',
        title: 'Audio Visualization',
        content:
            'These waveforms show your audio input in real-time. Larger waves indicate louder sound.',
        type: HelpTooltipType.tooltip,
        position: HelpTooltipPosition.bottom,
        displayDuration: const Duration(seconds: 3),
      ),
      ContextualHelp(
        id: 'transcription-process',
        context: 'transcription_screen',
        trigger: 'first_transcription',
        title: 'Transcription in Progress',
        content:
            'Your audio is being converted to text. This may take a few moments depending on the length of your recording.',
        type: HelpTooltipType.overlay,
        position: HelpTooltipPosition.center,
      ),
      ContextualHelp(
        id: 'summary-generation',
        context: 'summary_screen',
        trigger: 'first_summary',
        title: 'AI Summary Generation',
        content:
            'Our AI analyzes your transcription to create intelligent summaries, action items, and key insights.',
        type: HelpTooltipType.popover,
        position: HelpTooltipPosition.top,
      ),
    ];
  }

  List<HelpTour> _getDefaultTours() {
    return [
      HelpTour(
        id: 'app-overview-tour',
        name: 'App Overview',
        description: 'A quick tour of the main features',
        steps: [
          HelpTourStep(
            id: 'tour-step-1',
            tourId: 'app-overview-tour',
            stepNumber: 1,
            targetElementId: 'navigation_bar',
            title: 'Navigation',
            content:
                'Use the bottom navigation to access different sections of the app.',
            position: HelpTooltipPosition.top,
          ),
          HelpTourStep(
            id: 'tour-step-2',
            tourId: 'app-overview-tour',
            stepNumber: 2,
            targetElementId: 'record_button',
            title: 'Start Recording',
            content: 'Tap this button to start recording your meetings.',
            position: HelpTooltipPosition.top,
          ),
          HelpTourStep(
            id: 'tour-step-3',
            tourId: 'app-overview-tour',
            stepNumber: 3,
            targetElementId: 'settings_icon',
            title: 'Settings',
            content: 'Access app settings and preferences here.',
            position: HelpTooltipPosition.bottom,
          ),
        ],
      ),
    ];
  }
}
