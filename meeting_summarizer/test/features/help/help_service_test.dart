import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meeting_summarizer/core/services/help_service.dart';
import 'package:meeting_summarizer/core/models/help/help_article.dart';
import 'package:meeting_summarizer/core/models/help/faq_item.dart';
import 'package:meeting_summarizer/core/models/help/contextual_help.dart';

void main() {
  group('HelpService', () {
    late HelpService helpService;

    setUp(() {
      // Set up shared preferences mock
      SharedPreferences.setMockInitialValues({});
      helpService = HelpService.instance;
    });

    tearDown(() {
      // Clear singleton instance for clean tests
      // Note: This is a simplification - in real implementation
      // you'd need a proper reset method
    });

    group('Article Operations', () {
      test('should return all articles', () async {
        final articles = await helpService.getAllArticles();

        expect(articles, isNotEmpty);
        expect(articles, isA<List<HelpArticle>>());
      });

      test('should filter articles by category', () async {
        final articles = await helpService.getArticlesByCategory(
          'getting-started',
        );

        expect(articles, isA<List<HelpArticle>>());
        for (final article in articles) {
          expect(article.category.id, equals('getting-started'));
        }
      });

      test('should return featured articles', () async {
        final featuredArticles = await helpService.getFeaturedArticles();

        expect(featuredArticles, isA<List<HelpArticle>>());
        for (final article in featuredArticles) {
          expect(article.isFeatured, isTrue);
        }
      });

      test('should find article by id', () async {
        // First get an article to test with
        final articles = await helpService.getAllArticles();
        expect(articles, isNotEmpty);

        final firstArticle = articles.first;
        final foundArticle = await helpService.getArticleById(firstArticle.id);

        expect(foundArticle, isNotNull);
        expect(foundArticle!.id, equals(firstArticle.id));
        expect(foundArticle.title, equals(firstArticle.title));
      });

      test('should return null for non-existent article id', () async {
        final article = await helpService.getArticleById('non-existent-id');
        expect(article, isNull);
      });

      test('should search articles by query', () async {
        final searchResults = await helpService.searchArticles('recording');

        expect(searchResults, isA<List<HelpArticle>>());
        // At least one result should contain 'recording' in title, content, or tags
        expect(
          searchResults.any(
            (article) =>
                article.title.toLowerCase().contains('recording') ||
                article.content.toLowerCase().contains('recording') ||
                article.tags.any(
                  (tag) => tag.toLowerCase().contains('recording'),
                ),
          ),
          isTrue,
        );
      });

      test('should return all articles for empty search query', () async {
        final allArticles = await helpService.getAllArticles();
        final searchResults = await helpService.searchArticles('');

        expect(searchResults.length, equals(allArticles.length));
      });

      test('should increment article views', () async {
        await expectLater(
          helpService.incrementArticleViews('test-article-id'),
          completes,
        );
      });
    });

    group('FAQ Operations', () {
      test('should return all FAQs', () async {
        final faqs = await helpService.getAllFaqs();

        expect(faqs, isNotEmpty);
        expect(faqs, isA<List<FaqItem>>());
      });

      test('should filter FAQs by category', () async {
        final faqs = await helpService.getFaqsByCategory('getting-started');

        expect(faqs, isA<List<FaqItem>>());
        for (final faq in faqs) {
          expect(faq.categoryId, equals('getting-started'));
        }
      });

      test('should return popular FAQs', () async {
        final popularFaqs = await helpService.getPopularFaqs();

        expect(popularFaqs, isA<List<FaqItem>>());
        for (final faq in popularFaqs) {
          expect(faq.isPopular, isTrue);
        }
      });

      test('should find FAQ by id', () async {
        final faqs = await helpService.getAllFaqs();
        expect(faqs, isNotEmpty);

        final firstFaq = faqs.first;
        final foundFaq = await helpService.getFaqById(firstFaq.id);

        expect(foundFaq, isNotNull);
        expect(foundFaq!.id, equals(firstFaq.id));
        expect(foundFaq.question, equals(firstFaq.question));
      });

      test('should search FAQs by query', () async {
        final searchResults = await helpService.searchFaqs('permission');

        expect(searchResults, isA<List<FaqItem>>());
        // At least one result should contain 'permission' in question, answer, or tags
        expect(
          searchResults.any(
            (faq) =>
                faq.question.toLowerCase().contains('permission') ||
                faq.answer.toLowerCase().contains('permission') ||
                faq.tags.any((tag) => tag.toLowerCase().contains('permission')),
          ),
          isTrue,
        );
      });

      test('should increment FAQ views', () async {
        await expectLater(
          helpService.incrementFaqViews('test-faq-id'),
          completes,
        );
      });

      test('should vote FAQ helpfulness', () async {
        await expectLater(
          helpService.voteFaqHelpfulness('test-faq-id', true),
          completes,
        );

        await expectLater(
          helpService.voteFaqHelpfulness('test-faq-id', false),
          completes,
        );
      });
    });

    group('Category Operations', () {
      test('should return all categories', () async {
        final categories = await helpService.getAllCategories();

        expect(categories, isNotEmpty);
        expect(categories, isA<List<HelpCategory>>());

        // Check that categories are sorted
        for (int i = 1; i < categories.length; i++) {
          expect(
            categories[i].sortOrder >= categories[i - 1].sortOrder,
            isTrue,
          );
        }
      });

      test('should find category by id', () async {
        final categories = await helpService.getAllCategories();
        expect(categories, isNotEmpty);

        final firstCategory = categories.first;
        final foundCategory = await helpService.getCategoryById(
          firstCategory.id,
        );

        expect(foundCategory, isNotNull);
        expect(foundCategory!.id, equals(firstCategory.id));
        expect(foundCategory.name, equals(firstCategory.name));
      });

      test('should return null for non-existent category id', () async {
        final category = await helpService.getCategoryById('non-existent-id');
        expect(category, isNull);
      });
    });

    group('Contextual Help Operations', () {
      test('should return contextual help for context', () async {
        final contextualHelp = await helpService.getContextualHelp(
          'recording_screen',
        );

        expect(contextualHelp, isA<List<ContextualHelp>>());
        for (final help in contextualHelp) {
          expect(help.context, equals('recording_screen'));
        }
      });

      test('should find contextual help by id', () async {
        final contextualHelp = await helpService.getContextualHelp(
          'recording_screen',
        );
        if (contextualHelp.isNotEmpty) {
          final firstHelp = contextualHelp.first;
          final foundHelp = await helpService.getContextualHelpById(
            firstHelp.id,
          );

          expect(foundHelp, isNotNull);
          expect(foundHelp!.id, equals(firstHelp.id));
        }
      });

      test('should mark contextual help as shown', () async {
        const helpId = 'test-help-id';

        // Initially should show help
        final shouldShowBefore = await helpService.shouldShowContextualHelp(
          helpId,
        );
        expect(shouldShowBefore, isTrue);

        // Mark as shown
        await helpService.markContextualHelpShown(helpId);

        // Should not show help anymore
        final shouldShowAfter = await helpService.shouldShowContextualHelp(
          helpId,
        );
        expect(shouldShowAfter, isFalse);
      });
    });

    group('Tour Operations', () {
      test('should return all tours', () async {
        final tours = await helpService.getAllTours();

        expect(tours, isA<List<HelpTour>>());
      });

      test('should find tour by id', () async {
        final tours = await helpService.getAllTours();
        if (tours.isNotEmpty) {
          final firstTour = tours.first;
          final foundTour = await helpService.getTourById(firstTour.id);

          expect(foundTour, isNotNull);
          expect(foundTour!.id, equals(firstTour.id));
        }
      });

      test('should track tour completion', () async {
        const tourId = 'test-tour-id';

        // Initially tour should not be completed
        final isCompletedBefore = await helpService.isTourCompleted(tourId);
        expect(isCompletedBefore, isFalse);

        // Start and complete tour
        await helpService.startTour(tourId);
        await helpService.completeTour(tourId);

        // Tour should now be completed
        final isCompletedAfter = await helpService.isTourCompleted(tourId);
        expect(isCompletedAfter, isTrue);
      });
    });

    group('Search Operations', () {
      test('should search all content types', () async {
        final results = await helpService.searchAll('meeting');

        expect(results, isA<Map<String, List<dynamic>>>());
        expect(results.containsKey('articles'), isTrue);
        expect(results.containsKey('faqs'), isTrue);
        expect(results['articles'], isA<List<HelpArticle>>());
        expect(results['faqs'], isA<List<FaqItem>>());
      });

      test('should provide search suggestions', () async {
        final suggestions = await helpService.getSearchSuggestions('rec');

        expect(suggestions, isA<List<String>>());
        expect(suggestions.length, lessThanOrEqualTo(10));

        // All suggestions should contain the query
        for (final suggestion in suggestions) {
          expect(suggestion.toLowerCase().contains('rec'), isTrue);
        }
      });

      test('should return empty suggestions for short queries', () async {
        final suggestions = await helpService.getSearchSuggestions('a');
        expect(suggestions, isEmpty);
      });
    });

    group('Analytics Operations', () {
      test('should return help analytics', () async {
        final analytics = await helpService.getHelpAnalytics();
        expect(analytics, isA<Map<String, dynamic>>());
      });

      test('should track help events', () async {
        await expectLater(
          helpService.trackHelpEvent('test_event', {'key': 'value'}),
          completes,
        );
      });
    });

    group('Cache Operations', () {
      test('should refresh cache', () async {
        await expectLater(helpService.refreshCache(), completes);
      });

      test('should clear cache', () async {
        await expectLater(helpService.clearCache(), completes);
      });
    });

    group('Data Models', () {
      test('HelpArticle model should serialize/deserialize correctly', () {
        final now = DateTime.now();
        final category = HelpCategory(
          id: 'test-category',
          name: 'Test Category',
          description: 'Test description',
          icon: const IconData(123),
          color: const Color(0xFF000000),
        );

        final article = HelpArticle(
          id: 'test-article',
          title: 'Test Article',
          content: 'Test content',
          excerpt: 'Test excerpt',
          tags: ['tag1', 'tag2'],
          category: category,
          createdAt: now,
          updatedAt: now,
          viewCount: 10,
          isFeatured: true,
        );

        final json = article.toJson();
        final deserializedArticle = HelpArticle.fromJson(json);

        expect(deserializedArticle.id, equals(article.id));
        expect(deserializedArticle.title, equals(article.title));
        expect(deserializedArticle.content, equals(article.content));
        expect(deserializedArticle.excerpt, equals(article.excerpt));
        expect(deserializedArticle.tags, equals(article.tags));
        expect(deserializedArticle.viewCount, equals(article.viewCount));
        expect(deserializedArticle.isFeatured, equals(article.isFeatured));
      });

      test('FaqItem model should serialize/deserialize correctly', () {
        final now = DateTime.now();
        final faq = FaqItem(
          id: 'test-faq',
          question: 'Test question?',
          answer: 'Test answer',
          tags: ['tag1', 'tag2'],
          categoryId: 'test-category',
          createdAt: now,
          updatedAt: now,
          viewCount: 5,
          isPopular: true,
          helpfulVotes: 8,
          totalVotes: 10,
        );

        final json = faq.toJson();
        final deserializedFaq = FaqItem.fromJson(json);

        expect(deserializedFaq.id, equals(faq.id));
        expect(deserializedFaq.question, equals(faq.question));
        expect(deserializedFaq.answer, equals(faq.answer));
        expect(deserializedFaq.tags, equals(faq.tags));
        expect(deserializedFaq.categoryId, equals(faq.categoryId));
        expect(deserializedFaq.viewCount, equals(faq.viewCount));
        expect(deserializedFaq.isPopular, equals(faq.isPopular));
        expect(deserializedFaq.helpfulVotes, equals(faq.helpfulVotes));
        expect(deserializedFaq.totalVotes, equals(faq.totalVotes));
        expect(deserializedFaq.helpfulnessPercent, equals(80.0));
      });

      test('ContextualHelp model should serialize/deserialize correctly', () {
        final help = ContextualHelp(
          id: 'test-help',
          context: 'test_screen',
          trigger: 'first_visit',
          title: 'Test Help',
          content: 'Test help content',
          type: HelpTooltipType.tooltip,
          position: HelpTooltipPosition.top,
          displayDuration: const Duration(seconds: 5),
          isDismissible: true,
          prerequisites: ['help1', 'help2'],
        );

        final json = help.toJson();
        final deserializedHelp = ContextualHelp.fromJson(json);

        expect(deserializedHelp.id, equals(help.id));
        expect(deserializedHelp.context, equals(help.context));
        expect(deserializedHelp.trigger, equals(help.trigger));
        expect(deserializedHelp.title, equals(help.title));
        expect(deserializedHelp.content, equals(help.content));
        expect(deserializedHelp.type, equals(help.type));
        expect(deserializedHelp.position, equals(help.position));
        expect(deserializedHelp.displayDuration, equals(help.displayDuration));
        expect(deserializedHelp.isDismissible, equals(help.isDismissible));
        expect(deserializedHelp.prerequisites, equals(help.prerequisites));
      });
    });
  });
}
