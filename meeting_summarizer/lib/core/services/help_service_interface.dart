import '../models/help/help_article.dart';
import '../models/help/faq_item.dart';
import '../models/help/contextual_help.dart';

/// Interface for help system operations
abstract class HelpServiceInterface {
  // Article operations
  Future<List<HelpArticle>> getAllArticles();
  Future<List<HelpArticle>> getArticlesByCategory(String categoryId);
  Future<List<HelpArticle>> getFeaturedArticles();
  Future<HelpArticle?> getArticleById(String id);
  Future<List<HelpArticle>> searchArticles(String query);
  Future<void> incrementArticleViews(String articleId);

  // FAQ operations
  Future<List<FaqItem>> getAllFaqs();
  Future<List<FaqItem>> getFaqsByCategory(String categoryId);
  Future<List<FaqItem>> getPopularFaqs();
  Future<FaqItem?> getFaqById(String id);
  Future<List<FaqItem>> searchFaqs(String query);
  Future<void> incrementFaqViews(String faqId);
  Future<void> voteFaqHelpfulness(String faqId, bool isHelpful);

  // Category operations
  Future<List<HelpCategory>> getAllCategories();
  Future<HelpCategory?> getCategoryById(String id);

  // Contextual help operations
  Future<List<ContextualHelp>> getContextualHelp(String context);
  Future<ContextualHelp?> getContextualHelpById(String id);
  Future<void> markContextualHelpShown(String id);
  Future<bool> shouldShowContextualHelp(String id);

  // Tour operations
  Future<List<HelpTour>> getAllTours();
  Future<HelpTour?> getTourById(String id);
  Future<void> startTour(String tourId);
  Future<void> completeTour(String tourId);
  Future<bool> isTourCompleted(String tourId);

  // Search operations
  Future<Map<String, List<dynamic>>> searchAll(String query);
  Future<List<String>> getSearchSuggestions(String partialQuery);

  // Analytics
  Future<Map<String, dynamic>> getHelpAnalytics();
  Future<void> trackHelpEvent(String event, Map<String, dynamic> data);

  // Cache management
  Future<void> refreshCache();
  Future<void> clearCache();
}
