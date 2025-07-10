/// Quality scoring and feedback integration service for AI summarization
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/summarization_result.dart';
import '../models/summarization_configuration.dart';
import '../enums/summary_type.dart';

/// Service for quality scoring and feedback integration
class QualityScoringService {
  static const Uuid _uuid = Uuid();

  /// Private constructor to prevent instantiation
  QualityScoringService._();

  /// Comprehensive quality assessment of a summarization result
  static Future<QualityAssessment> assessQuality({
    required SummarizationResult result,
    required String originalTranscription,
    required SummarizationConfiguration configuration,
    Future<String> Function(String prompt, String systemPrompt)? aiCall,
    List<UserFeedback>? userFeedback,
    SummarizationResult? referenceSummary,
  }) async {
    try {
      // Calculate multiple quality scores
      final accuracyScore = _calculateAccuracyScore(
        result,
        originalTranscription,
        configuration,
      );

      final completenessScore = _calculateCompletenessScore(
        result,
        originalTranscription,
        configuration,
      );

      final clarityScore = _calculateClarityScore(result, configuration);

      final relevanceScore = _calculateRelevanceScore(
        result,
        configuration,
        originalTranscription,
      );

      final structureScore = _calculateStructureScore(result, configuration);

      // AI-powered quality assessment if available
      QualityDimensions? aiAssessment;
      if (aiCall != null) {
        aiAssessment = await _getAIQualityAssessment(
          result,
          originalTranscription,
          configuration,
          aiCall,
        );
      }

      // User feedback integration
      final feedbackScore = _calculateFeedbackScore(userFeedback);

      // Reference comparison if available
      final comparisonScore = referenceSummary != null
          ? _compareWithReference(result, referenceSummary)
          : null;

      // Calculate overall quality score
      final overallScore = _calculateOverallScore(
        accuracyScore,
        completenessScore,
        clarityScore,
        relevanceScore,
        structureScore,
        feedbackScore,
        aiAssessment,
        comparisonScore,
      );

      // Generate improvement recommendations
      final recommendations = _generateRecommendations(
        result,
        configuration,
        accuracyScore,
        completenessScore,
        clarityScore,
        relevanceScore,
        structureScore,
        userFeedback,
      );

      return QualityAssessment(
        id: _uuid.v4(),
        summaryId: result.id,
        overallScore: overallScore,
        accuracyScore: accuracyScore,
        completenessScore: completenessScore,
        clarityScore: clarityScore,
        relevanceScore: relevanceScore,
        structureScore: structureScore,
        feedbackScore: feedbackScore,
        aiAssessment: aiAssessment,
        comparisonScore: comparisonScore,
        recommendations: recommendations,
        userFeedback: userFeedback ?? [],
        assessmentDate: DateTime.now(),
        configurationUsed: configuration,
      );
    } catch (e) {
      debugPrint('QualityScoringService: Quality assessment failed: $e');

      // Return a basic assessment in case of error
      return QualityAssessment(
        id: _uuid.v4(),
        summaryId: result.id,
        overallScore: result.confidenceScore,
        accuracyScore: result.confidenceScore,
        completenessScore: 0.5,
        clarityScore: 0.5,
        relevanceScore: 0.5,
        structureScore: 0.5,
        recommendations: [
          'Quality assessment failed - manual review recommended',
        ],
        userFeedback: userFeedback ?? [],
        assessmentDate: DateTime.now(),
        configurationUsed: configuration,
      );
    }
  }

  /// Calculate accuracy score based on content analysis
  static double _calculateAccuracyScore(
    SummarizationResult result,
    String originalTranscription,
    SummarizationConfiguration configuration,
  ) {
    double score = 0.7; // Base score

    // Check for factual consistency
    final originalWords = _tokenize(originalTranscription.toLowerCase());
    final summaryWords = _tokenize(result.content.toLowerCase());

    // Key term preservation
    final keyTerms = _extractKeyTerms(originalWords);
    final preservedTerms = keyTerms
        .where((term) => summaryWords.contains(term))
        .length;

    if (keyTerms.isNotEmpty) {
      final preservationRatio = preservedTerms / keyTerms.length;
      score += preservationRatio * 0.2;
    }

    // Number accuracy for metrics, dates, amounts
    final numberAccuracy = _checkNumberAccuracy(
      originalTranscription,
      result.content,
    );
    score += numberAccuracy * 0.1;

    return score.clamp(0.0, 1.0);
  }

  /// Calculate completeness score
  static double _calculateCompletenessScore(
    SummarizationResult result,
    String originalTranscription,
    SummarizationConfiguration configuration,
  ) {
    double score = 0.6; // Base score

    // Check if major topics are covered
    final originalSentences = originalTranscription.split(RegExp(r'[.!?]+'));
    final summarySentences = result.content.split(RegExp(r'[.!?]+'));

    // Coverage ratio
    final coverageRatio = math.min(
      summarySentences.length / (originalSentences.length * 0.3),
      1.0,
    );
    score += coverageRatio * 0.2;

    // Check for required elements
    if (configuration.extractActionItems && result.actionItems.isNotEmpty) {
      score += 0.05;
    }

    if (configuration.identifyDecisions && result.keyDecisions.isNotEmpty) {
      score += 0.05;
    }

    if (configuration.extractTopics && result.topics.isNotEmpty) {
      score += 0.05;
    }

    // Length appropriateness
    final lengthScore = _assessLengthAppropriate(result, configuration);
    score += lengthScore * 0.05;

    return score.clamp(0.0, 1.0);
  }

  /// Calculate clarity score
  static double _calculateClarityScore(
    SummarizationResult result,
    SummarizationConfiguration configuration,
  ) {
    double score = 0.7; // Base score

    final sentences = result.content.split(RegExp(r'[.!?]+'));

    // Average sentence length (optimal: 15-25 words)
    final avgSentenceLength = sentences.isNotEmpty
        ? result.wordCount / sentences.length
        : 0;

    if (avgSentenceLength >= 10 && avgSentenceLength <= 30) {
      score += 0.1;
    }

    // Structure indicators
    final hasHeaders = result.content.contains(
      RegExp(r'^#+\s', multiLine: true),
    );
    final hasBullets = result.content.contains(
      RegExp(r'^[-•*]\s', multiLine: true),
    );
    final hasNumbering = result.content.contains(
      RegExp(r'^\d+\.\s', multiLine: true),
    );

    if (hasHeaders || hasBullets || hasNumbering) {
      score += 0.1;
    }

    // Readability indicators
    final readabilityScore = _calculateReadabilityScore(result.content);
    score += readabilityScore * 0.1;

    return score.clamp(0.0, 1.0);
  }

  /// Calculate relevance score
  static double _calculateRelevanceScore(
    SummarizationResult result,
    SummarizationConfiguration configuration,
    String originalTranscription,
  ) {
    double score = 0.7; // Base score

    // Focus alignment
    final focusScore = _assessFocusAlignment(
      result,
      configuration,
      originalTranscription,
    );
    score += focusScore * 0.2;

    // Summary type appropriateness
    final typeScore = _assessSummaryTypeAppropriate(result, configuration);
    score += typeScore * 0.1;

    return score.clamp(0.0, 1.0);
  }

  /// Calculate structure score
  static double _calculateStructureScore(
    SummarizationResult result,
    SummarizationConfiguration configuration,
  ) {
    double score = 0.6; // Base score

    // Check for logical organization
    final hasIntroduction = _hasIntroduction(result.content);
    final hasConclusion = _hasConclusion(result.content);
    final hasTransitions = _hasTransitions(result.content);

    if (hasIntroduction) score += 0.1;
    if (hasConclusion) score += 0.1;
    if (hasTransitions) score += 0.1;

    // Type-specific structure requirements
    switch (configuration.summaryType) {
      case SummaryType.meetingNotes:
        if (result.content.contains('**Date:**') &&
            result.content.contains('**Time:**')) {
          score += 0.1;
        }
        break;
      case SummaryType.executive:
        if (result.content.contains('##') ||
            result.content.contains('Executive')) {
          score += 0.1;
        }
        break;
      case SummaryType.actionItems:
        if (result.actionItems.isNotEmpty) {
          score += 0.1;
        }
        break;
      default:
        break;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Calculate feedback-based score
  static double? _calculateFeedbackScore(List<UserFeedback>? userFeedback) {
    if (userFeedback == null || userFeedback.isEmpty) return null;

    final ratings = userFeedback
        .where((feedback) => feedback.rating != null)
        .map((feedback) => feedback.rating!)
        .toList();

    if (ratings.isEmpty) return null;

    final avgRating = ratings.reduce((a, b) => a + b) / ratings.length;
    return (avgRating / 5.0).clamp(0.0, 1.0); // Normalize to 0-1 scale
  }

  /// Get AI-powered quality assessment
  static Future<QualityDimensions> _getAIQualityAssessment(
    SummarizationResult result,
    String originalTranscription,
    SummarizationConfiguration configuration,
    Future<String> Function(String, String) aiCall,
  ) async {
    try {
      const systemPrompt =
          '''You are an expert at evaluating summary quality. Assess the following summary across multiple dimensions and provide scores from 0.0 to 1.0.''';

      final prompt =
          '''Evaluate this summary quality across these dimensions:

ACCURACY: How factually correct is the summary compared to the original?
COMPLETENESS: How well does it cover the important points?
CLARITY: How clear and understandable is the writing?
RELEVANCE: How well does it match the intended purpose and focus?
STRUCTURE: How well-organized and coherent is the summary?

ORIGINAL TRANSCRIPTION:
${originalTranscription.length > 2000 ? '${originalTranscription.substring(0, 2000)}...' : originalTranscription}

SUMMARY TO EVALUATE:
${result.content}

SUMMARY TYPE: ${configuration.summaryType.displayName}
INTENDED FOCUS: ${configuration.summaryFocus.description}

Provide scores in this exact format:
ACCURACY: 0.X
COMPLETENESS: 0.X
CLARITY: 0.X
RELEVANCE: 0.X
STRUCTURE: 0.X
OVERALL: 0.X
FEEDBACK: Brief explanation of strengths and weaknesses''';

      final response = await aiCall(prompt, systemPrompt);
      return _parseAIAssessment(response);
    } catch (e) {
      debugPrint('QualityScoringService: AI assessment failed: $e');
      return QualityDimensions(
        accuracy: 0.7,
        completeness: 0.7,
        clarity: 0.7,
        relevance: 0.7,
        structure: 0.7,
        overall: 0.7,
        feedback: 'AI assessment unavailable',
      );
    }
  }

  /// Parse AI assessment response
  static QualityDimensions _parseAIAssessment(String response) {
    final lines = response.split('\n');

    double accuracy = 0.7;
    double completeness = 0.7;
    double clarity = 0.7;
    double relevance = 0.7;
    double structure = 0.7;
    double overall = 0.7;
    String feedback = 'No specific feedback provided';

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('ACCURACY:')) {
        accuracy = double.tryParse(trimmed.substring(9).trim()) ?? accuracy;
      } else if (trimmed.startsWith('COMPLETENESS:')) {
        completeness =
            double.tryParse(trimmed.substring(13).trim()) ?? completeness;
      } else if (trimmed.startsWith('CLARITY:')) {
        clarity = double.tryParse(trimmed.substring(8).trim()) ?? clarity;
      } else if (trimmed.startsWith('RELEVANCE:')) {
        relevance = double.tryParse(trimmed.substring(10).trim()) ?? relevance;
      } else if (trimmed.startsWith('STRUCTURE:')) {
        structure = double.tryParse(trimmed.substring(10).trim()) ?? structure;
      } else if (trimmed.startsWith('OVERALL:')) {
        overall = double.tryParse(trimmed.substring(8).trim()) ?? overall;
      } else if (trimmed.startsWith('FEEDBACK:')) {
        feedback = trimmed.substring(9).trim();
      }
    }

    return QualityDimensions(
      accuracy: accuracy.clamp(0.0, 1.0),
      completeness: completeness.clamp(0.0, 1.0),
      clarity: clarity.clamp(0.0, 1.0),
      relevance: relevance.clamp(0.0, 1.0),
      structure: structure.clamp(0.0, 1.0),
      overall: overall.clamp(0.0, 1.0),
      feedback: feedback,
    );
  }

  /// Compare with reference summary
  static double _compareWithReference(
    SummarizationResult result,
    SummarizationResult reference,
  ) {
    // Content similarity
    final contentSimilarity = _calculateContentSimilarity(
      result.content,
      reference.content,
    );

    // Structure similarity
    final structureSimilarity = _calculateStructureSimilarity(
      result,
      reference,
    );

    // Feature similarity (action items, decisions, etc.)
    final featureSimilarity = _calculateFeatureSimilarity(result, reference);

    return (contentSimilarity * 0.5 +
            structureSimilarity * 0.3 +
            featureSimilarity * 0.2)
        .clamp(0.0, 1.0);
  }

  /// Calculate overall quality score
  static double _calculateOverallScore(
    double accuracyScore,
    double completenessScore,
    double clarityScore,
    double relevanceScore,
    double structureScore,
    double? feedbackScore,
    QualityDimensions? aiAssessment,
    double? comparisonScore,
  ) {
    // Base weighted average
    double score =
        (accuracyScore * 0.25 +
        completenessScore * 0.25 +
        clarityScore * 0.20 +
        relevanceScore * 0.20 +
        structureScore * 0.10);

    // Incorporate feedback if available
    if (feedbackScore != null) {
      score = score * 0.7 + feedbackScore * 0.3;
    }

    // Incorporate AI assessment if available
    if (aiAssessment != null) {
      score = score * 0.8 + aiAssessment.overall * 0.2;
    }

    // Incorporate comparison score if available
    if (comparisonScore != null) {
      score = score * 0.9 + comparisonScore * 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Generate improvement recommendations
  static List<String> _generateRecommendations(
    SummarizationResult result,
    SummarizationConfiguration configuration,
    double accuracyScore,
    double completenessScore,
    double clarityScore,
    double relevanceScore,
    double structureScore,
    List<UserFeedback>? userFeedback,
  ) {
    final recommendations = <String>[];

    // Score-based recommendations
    if (accuracyScore < 0.7) {
      recommendations.add(
        'Improve accuracy by including more specific details and verifying key facts',
      );
    }

    if (completenessScore < 0.7) {
      recommendations.add(
        'Enhance completeness by covering more key topics and including missing elements',
      );
    }

    if (clarityScore < 0.7) {
      recommendations.add(
        'Improve clarity with better structure, shorter sentences, and clearer language',
      );
    }

    if (relevanceScore < 0.7) {
      recommendations.add(
        'Better align content with the specified focus and summary type requirements',
      );
    }

    if (structureScore < 0.7) {
      recommendations.add(
        'Enhance organization with clear sections, logical flow, and proper formatting',
      );
    }

    // Configuration-specific recommendations
    if (configuration.extractActionItems && result.actionItems.isEmpty) {
      recommendations.add(
        'Add action item extraction as specified in the configuration',
      );
    }

    if (configuration.identifyDecisions && result.keyDecisions.isEmpty) {
      recommendations.add('Include key decision identification as requested');
    }

    // User feedback-based recommendations
    if (userFeedback != null) {
      for (final feedback in userFeedback) {
        if (feedback.comments.isNotEmpty) {
          recommendations.add('User feedback: ${feedback.comments}');
        }
      }
    }

    // Length-based recommendations
    if (result.wordCount < 50) {
      recommendations.add(
        'Consider expanding the summary to provide more comprehensive coverage',
      );
    } else if (result.wordCount > 500 &&
        configuration.summaryLength == SummaryLength.short) {
      recommendations.add(
        'Reduce length to better match the requested brief summary format',
      );
    }

    return recommendations.isNotEmpty
        ? recommendations
        : ['Summary quality is good - no specific improvements needed'];
  }

  /// Helper methods for quality assessment

  static List<String> _tokenize(String text) {
    return text
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 2)
        .toList();
  }

  static List<String> _extractKeyTerms(List<String> words) {
    final termFreq = <String, int>{};
    for (final word in words) {
      termFreq[word] = (termFreq[word] ?? 0) + 1;
    }

    // Return terms that appear multiple times (likely important)
    return termFreq.entries
        .where((entry) => entry.value > 1)
        .map((entry) => entry.key)
        .toList();
  }

  static double _checkNumberAccuracy(String original, String summary) {
    final numberPattern = RegExp(r'\b\d+(?:\.\d+)?\b');
    final originalNumbers = numberPattern
        .allMatches(original)
        .map((match) => match.group(0)!)
        .toSet();
    final summaryNumbers = numberPattern
        .allMatches(summary)
        .map((match) => match.group(0)!)
        .toSet();

    if (originalNumbers.isEmpty) return 1.0;

    final preservedNumbers = originalNumbers
        .intersection(summaryNumbers)
        .length;
    return preservedNumbers / originalNumbers.length;
  }

  static double _assessLengthAppropriate(
    SummarizationResult result,
    SummarizationConfiguration configuration,
  ) {
    final wordCount = result.wordCount;
    final expectedRange = _getExpectedWordRange(configuration);

    if (wordCount >= expectedRange.start && wordCount <= expectedRange.end) {
      return 1.0;
    } else if (wordCount < expectedRange.start) {
      return (wordCount / expectedRange.start).clamp(0.5, 1.0);
    } else {
      return (expectedRange.end / wordCount).clamp(0.5, 1.0);
    }
  }

  static ({int start, int end}) _getExpectedWordRange(
    SummarizationConfiguration configuration,
  ) {
    return switch (configuration.summaryLength) {
      SummaryLength.short => (start: 50, end: 150),
      SummaryLength.medium => (start: 150, end: 300),
      SummaryLength.long => (start: 300, end: 600),
      SummaryLength.extended => (start: 600, end: 1200),
      SummaryLength.custom =>
        configuration.customWordCount != null
            ? (
                start: (configuration.customWordCount! * 0.8).round(),
                end: (configuration.customWordCount! * 1.2).round(),
              )
            : (start: 100, end: 300),
    };
  }

  static double _calculateReadabilityScore(String text) {
    final sentences = text.split(RegExp(r'[.!?]+'));
    final words = _tokenize(text);

    if (sentences.isEmpty || words.isEmpty) return 0.5;

    final avgWordsPerSentence = words.length / sentences.length;
    final avgSyllablesPerWord = _estimateAverageSyllables(words);

    // Simplified Flesch Reading Ease approximation
    final readingEase =
        206.835 - (1.015 * avgWordsPerSentence) - (84.6 * avgSyllablesPerWord);

    // Convert to 0-1 scale (optimal range: 60-100)
    return ((readingEase - 40) / 60).clamp(0.0, 1.0);
  }

  static double _estimateAverageSyllables(List<String> words) {
    if (words.isEmpty) return 1.0;

    int totalSyllables = 0;
    for (final word in words) {
      totalSyllables += _countSyllables(word);
    }

    return totalSyllables / words.length;
  }

  static int _countSyllables(String word) {
    final vowels = 'aeiouy';
    int syllableCount = 0;
    bool previousWasVowel = false;

    for (int i = 0; i < word.length; i++) {
      final char = word[i].toLowerCase();
      final isVowel = vowels.contains(char);

      if (isVowel && !previousWasVowel) {
        syllableCount++;
      }
      previousWasVowel = isVowel;
    }

    // Adjust for silent 'e'
    if (word.toLowerCase().endsWith('e') && syllableCount > 1) {
      syllableCount--;
    }

    return math.max(1, syllableCount);
  }

  static double _assessFocusAlignment(
    SummarizationResult result,
    SummarizationConfiguration configuration,
    String originalTranscription,
  ) {
    final focusKeywords = _getFocusKeywords(configuration.summaryFocus);
    final summaryLower = result.content.toLowerCase();

    final matchingKeywords = focusKeywords
        .where((keyword) => summaryLower.contains(keyword))
        .length;

    return focusKeywords.isNotEmpty
        ? (matchingKeywords / focusKeywords.length).clamp(0.0, 1.0)
        : 1.0;
  }

  static List<String> _getFocusKeywords(SummaryFocus focus) {
    return switch (focus) {
      SummaryFocus.decisions => [
        'decision',
        'decided',
        'choose',
        'agree',
        'approve',
      ],
      SummaryFocus.actions => ['action', 'task', 'todo', 'assign', 'complete'],
      SummaryFocus.technical => [
        'technical',
        'system',
        'implement',
        'code',
        'architecture',
      ],
      SummaryFocus.business => [
        'business',
        'revenue',
        'market',
        'strategy',
        'roi',
      ],
      SummaryFocus.timeline => [
        'deadline',
        'schedule',
        'timeline',
        'milestone',
        'date',
      ],
      SummaryFocus.risks => [
        'risk',
        'challenge',
        'issue',
        'problem',
        'mitigation',
      ],
      SummaryFocus.opportunities => [
        'opportunity',
        'benefit',
        'advantage',
        'growth',
        'improve',
      ],
      _ => [],
    };
  }

  static double _assessSummaryTypeAppropriate(
    SummarizationResult result,
    SummarizationConfiguration configuration,
  ) {
    return switch (configuration.summaryType) {
      SummaryType.actionItems => result.actionItems.isNotEmpty ? 1.0 : 0.5,
      SummaryType.executive =>
        result.content.contains('executive') ||
                result.content.contains('strategic')
            ? 1.0
            : 0.7,
      SummaryType.meetingNotes =>
        result.content.contains('**') || result.content.contains('##')
            ? 1.0
            : 0.7,
      SummaryType.bulletPoints =>
        result.content.contains('•') || result.content.contains('-')
            ? 1.0
            : 0.7,
      _ => 1.0,
    };
  }

  static bool _hasIntroduction(String content) {
    final firstSentence = content.split('.').first.toLowerCase();
    return firstSentence.contains('summary') ||
        firstSentence.contains('meeting') ||
        firstSentence.contains('discussion') ||
        firstSentence.contains('overview');
  }

  static bool _hasConclusion(String content) {
    final lastParagraph = content.split('\n\n').last.toLowerCase();
    return lastParagraph.contains('conclusion') ||
        lastParagraph.contains('summary') ||
        lastParagraph.contains('next steps') ||
        lastParagraph.contains('follow-up');
  }

  static bool _hasTransitions(String content) {
    final transitions = [
      'additionally',
      'furthermore',
      'however',
      'therefore',
      'meanwhile',
    ];
    final contentLower = content.toLowerCase();
    return transitions.any((transition) => contentLower.contains(transition));
  }

  static double _calculateContentSimilarity(String content1, String content2) {
    final words1 = _tokenize(content1.toLowerCase()).toSet();
    final words2 = _tokenize(content2.toLowerCase()).toSet();

    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;

    return union > 0 ? intersection / union : 0.0;
  }

  static double _calculateStructureSimilarity(
    SummarizationResult result1,
    SummarizationResult result2,
  ) {
    double similarity = 0.0;

    // Compare structure elements
    final hasHeaders1 = result1.content.contains('##');
    final hasHeaders2 = result2.content.contains('##');
    if (hasHeaders1 == hasHeaders2) similarity += 0.25;

    final hasBullets1 =
        result1.content.contains('•') || result1.content.contains('-');
    final hasBullets2 =
        result2.content.contains('•') || result2.content.contains('-');
    if (hasBullets1 == hasBullets2) similarity += 0.25;

    // Compare word count ranges
    final wordRatio =
        math.min(result1.wordCount, result2.wordCount) /
        math.max(result1.wordCount, result2.wordCount);
    similarity += wordRatio * 0.5;

    return similarity;
  }

  static double _calculateFeatureSimilarity(
    SummarizationResult result1,
    SummarizationResult result2,
  ) {
    double similarity = 0.0;

    // Action items similarity
    if (result1.actionItems.isNotEmpty && result2.actionItems.isNotEmpty) {
      similarity += 0.33;
    } else if (result1.actionItems.isEmpty && result2.actionItems.isEmpty) {
      similarity += 0.33;
    }

    // Decisions similarity
    if (result1.keyDecisions.isNotEmpty && result2.keyDecisions.isNotEmpty) {
      similarity += 0.33;
    } else if (result1.keyDecisions.isEmpty && result2.keyDecisions.isEmpty) {
      similarity += 0.33;
    }

    // Topics similarity
    if (result1.topics.isNotEmpty && result2.topics.isNotEmpty) {
      similarity += 0.34;
    } else if (result1.topics.isEmpty && result2.topics.isEmpty) {
      similarity += 0.34;
    }

    return similarity;
  }

  /// Process user feedback for quality improvement
  static QualityInsights processUserFeedback(List<UserFeedback> feedbackList) {
    if (feedbackList.isEmpty) {
      return QualityInsights(
        averageRating: null,
        commonIssues: [],
        improvementSuggestions: [],
        positiveAspects: [],
        feedbackCount: 0,
      );
    }

    // Calculate average rating
    final ratings = feedbackList
        .where((f) => f.rating != null)
        .map((f) => f.rating!)
        .toList();

    final averageRating = ratings.isNotEmpty
        ? ratings.reduce((a, b) => a + b) / ratings.length
        : null;

    // Analyze common issues and positive aspects
    final allComments = feedbackList
        .map((f) => f.comments.toLowerCase())
        .where((c) => c.isNotEmpty)
        .toList();

    final commonIssues = _extractCommonIssues(allComments);
    final positiveAspects = _extractPositiveAspects(allComments);
    final suggestions = _generateImprovementSuggestions(
      commonIssues,
      averageRating,
    );

    return QualityInsights(
      averageRating: averageRating,
      commonIssues: commonIssues,
      improvementSuggestions: suggestions,
      positiveAspects: positiveAspects,
      feedbackCount: feedbackList.length,
    );
  }

  static List<String> _extractCommonIssues(List<String> comments) {
    final issueKeywords = {
      'too long': 'Summary length needs reduction',
      'too short': 'Summary needs more detail',
      'unclear': 'Clarity improvements needed',
      'missing': 'Important information missing',
      'inaccurate': 'Accuracy issues identified',
      'confusing': 'Structure and organization needs improvement',
    };

    final foundIssues = <String>[];
    for (final entry in issueKeywords.entries) {
      final issueCount = comments
          .where((comment) => comment.contains(entry.key))
          .length;

      if (issueCount >= 2 || issueCount / comments.length > 0.3) {
        foundIssues.add(entry.value);
      }
    }

    return foundIssues;
  }

  static List<String> _extractPositiveAspects(List<String> comments) {
    final positiveKeywords = {
      'clear': 'Clear and understandable',
      'comprehensive': 'Comprehensive coverage',
      'well-organized': 'Good organization',
      'helpful': 'Helpful content',
      'accurate': 'Accurate information',
      'concise': 'Appropriate length',
    };

    final foundPositives = <String>[];
    for (final entry in positiveKeywords.entries) {
      final positiveCount = comments
          .where((comment) => comment.contains(entry.key))
          .length;

      if (positiveCount >= 2 || positiveCount / comments.length > 0.3) {
        foundPositives.add(entry.value);
      }
    }

    return foundPositives;
  }

  static List<String> _generateImprovementSuggestions(
    List<String> commonIssues,
    double? averageRating,
  ) {
    final suggestions = <String>[];

    if (averageRating != null && averageRating < 3.0) {
      suggestions.add('Overall quality needs significant improvement');
    }

    for (final issue in commonIssues) {
      if (issue.contains('length')) {
        suggestions.add('Adjust summary length based on user preferences');
      } else if (issue.contains('clarity')) {
        suggestions.add('Improve sentence structure and word choice');
      } else if (issue.contains('missing')) {
        suggestions.add('Enhance completeness by including more key points');
      } else if (issue.contains('accuracy')) {
        suggestions.add('Strengthen fact-checking and verification processes');
      } else if (issue.contains('organization')) {
        suggestions.add('Improve logical flow and structural organization');
      }
    }

    if (suggestions.isEmpty) {
      suggestions.add('Continue maintaining current quality standards');
    }

    return suggestions;
  }
}

/// Data classes for quality assessment

class QualityAssessment {
  final String id;
  final String summaryId;
  final double overallScore;
  final double accuracyScore;
  final double completenessScore;
  final double clarityScore;
  final double relevanceScore;
  final double structureScore;
  final double? feedbackScore;
  final QualityDimensions? aiAssessment;
  final double? comparisonScore;
  final List<String> recommendations;
  final List<UserFeedback> userFeedback;
  final DateTime assessmentDate;
  final SummarizationConfiguration configurationUsed;

  const QualityAssessment({
    required this.id,
    required this.summaryId,
    required this.overallScore,
    required this.accuracyScore,
    required this.completenessScore,
    required this.clarityScore,
    required this.relevanceScore,
    required this.structureScore,
    this.feedbackScore,
    this.aiAssessment,
    this.comparisonScore,
    required this.recommendations,
    required this.userFeedback,
    required this.assessmentDate,
    required this.configurationUsed,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'summaryId': summaryId,
      'overallScore': overallScore,
      'accuracyScore': accuracyScore,
      'completenessScore': completenessScore,
      'clarityScore': clarityScore,
      'relevanceScore': relevanceScore,
      'structureScore': structureScore,
      'feedbackScore': feedbackScore,
      'aiAssessment': aiAssessment?.toJson(),
      'comparisonScore': comparisonScore,
      'recommendations': recommendations,
      'userFeedback': userFeedback.map((f) => f.toJson()).toList(),
      'assessmentDate': assessmentDate.toIso8601String(),
      'configurationUsed': configurationUsed.toJson(),
    };
  }
}

class QualityDimensions {
  final double accuracy;
  final double completeness;
  final double clarity;
  final double relevance;
  final double structure;
  final double overall;
  final String feedback;

  const QualityDimensions({
    required this.accuracy,
    required this.completeness,
    required this.clarity,
    required this.relevance,
    required this.structure,
    required this.overall,
    required this.feedback,
  });

  Map<String, dynamic> toJson() {
    return {
      'accuracy': accuracy,
      'completeness': completeness,
      'clarity': clarity,
      'relevance': relevance,
      'structure': structure,
      'overall': overall,
      'feedback': feedback,
    };
  }
}

class UserFeedback {
  final String id;
  final String summaryId;
  final int? rating; // 1-5 scale
  final String comments;
  final DateTime timestamp;
  final String? userId;

  const UserFeedback({
    required this.id,
    required this.summaryId,
    this.rating,
    required this.comments,
    required this.timestamp,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'summaryId': summaryId,
      'rating': rating,
      'comments': comments,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
    };
  }
}

class QualityInsights {
  final double? averageRating;
  final List<String> commonIssues;
  final List<String> improvementSuggestions;
  final List<String> positiveAspects;
  final int feedbackCount;

  const QualityInsights({
    required this.averageRating,
    required this.commonIssues,
    required this.improvementSuggestions,
    required this.positiveAspects,
    required this.feedbackCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'averageRating': averageRating,
      'commonIssues': commonIssues,
      'improvementSuggestions': improvementSuggestions,
      'positiveAspects': positiveAspects,
      'feedbackCount': feedbackCount,
    };
  }
}
