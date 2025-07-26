/// Advanced topic extraction and keyword identification service
library;

import 'dart:async';
import 'dart:developer';

import '../models/summarization_result.dart';

/// Service for advanced topic extraction and keyword identification
class TopicExtractionService {
  /// Private constructor to prevent instantiation
  TopicExtractionService._();

  /// Extract topics from transcription text using multiple analysis methods
  static Future<List<TopicExtract>> extractTopics({
    required String transcriptionText,
    required Future<String> Function(String prompt, String systemPrompt) aiCall,
    int maxTopics = 10,
    double relevanceThreshold = 0.3,
    String? contextHint,
  }) async {
    try {
      // Combine AI-powered extraction with statistical analysis
      final aiTopics = await _extractTopicsWithAI(
        transcriptionText,
        aiCall,
        maxTopics,
        contextHint,
      );

      final statisticalTopics = _extractTopicsStatistically(
        transcriptionText,
        maxTopics,
      );

      // Merge and rank topics
      final mergedTopics = _mergeAndRankTopics(
        aiTopics,
        statisticalTopics,
        relevanceThreshold,
      );

      return mergedTopics.take(maxTopics).toList();
    } catch (e) {
      log('TopicExtractionService: Topic extraction failed: $e');
      return _extractTopicsStatistically(transcriptionText, maxTopics);
    }
  }

  /// Extract keywords from text using frequency analysis and contextual relevance
  static List<String> extractKeywords({
    required String text,
    int maxKeywords = 20,
    double relevanceThreshold = 0.4,
    List<String>? stopWords,
  }) {
    final words = _tokenizeText(text);
    final stopWordsSet = stopWords?.toSet() ?? _getDefaultStopWords();

    // Filter out stop words and short words
    final filteredWords = words
        .where(
          (word) =>
              word.length > 2 &&
              !stopWordsSet.contains(word.toLowerCase()) &&
              RegExp(r'^[a-zA-Z]+$').hasMatch(word),
        )
        .map((word) => word.toLowerCase())
        .toList();

    // Calculate word frequencies
    final wordFreq = <String, int>{};
    for (final word in filteredWords) {
      wordFreq[word] = (wordFreq[word] ?? 0) + 1;
    }

    // Calculate TF-IDF-like scores
    final wordScores = <String, double>{};
    final totalWords = filteredWords.length;

    for (final entry in wordFreq.entries) {
      final word = entry.key;
      final frequency = entry.value;

      // Term frequency
      final tf = frequency / totalWords;

      // Positional weight (words appearing early get higher scores)
      final firstPosition = filteredWords.indexOf(word) / filteredWords.length;
      final positionalWeight = 1.0 - (firstPosition * 0.3);

      // Length bonus for compound words
      final lengthBonus = word.length > 6 ? 1.2 : 1.0;

      // Combined relevance score
      final score = tf * positionalWeight * lengthBonus;

      if (score >= relevanceThreshold) {
        wordScores[word] = score;
      }
    }

    // Sort by score and return top keywords
    final sortedKeywords = wordScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedKeywords.map((entry) => entry.key).take(maxKeywords).toList();
  }

  /// Analyze topic overlap and relationships
  static Map<String, List<String>> analyzeTopicRelationships(
    List<TopicExtract> topics,
  ) {
    final relationships = <String, List<String>>{};

    for (int i = 0; i < topics.length; i++) {
      final topic1 = topics[i];
      final relatedTopics = <String>[];

      for (int j = 0; j < topics.length; j++) {
        if (i == j) continue;

        final topic2 = topics[j];
        final similarity = _calculateTopicSimilarity(topic1, topic2);

        if (similarity > 0.3) {
          relatedTopics.add(topic2.topic);
        }
      }

      if (relatedTopics.isNotEmpty) {
        relationships[topic1.topic] = relatedTopics;
      }
    }

    return relationships;
  }

  /// Generate topic hierarchy based on keyword overlap
  static Map<String, List<String>> buildTopicHierarchy(
    List<TopicExtract> topics,
  ) {
    final hierarchy = <String, List<String>>{};

    // Sort topics by relevance to identify parent topics
    final sortedTopics = List<TopicExtract>.from(topics)
      ..sort((a, b) => b.relevance.compareTo(a.relevance));

    for (final topic in sortedTopics) {
      final children = <String>[];

      for (final otherTopic in topics) {
        if (topic.topic == otherTopic.topic) continue;

        // Check if this topic is a subtopic
        if (_isSubtopic(topic, otherTopic)) {
          children.add(otherTopic.topic);
        }
      }

      if (children.isNotEmpty) {
        hierarchy[topic.topic] = children;
      }
    }

    return hierarchy;
  }

  /// AI-powered topic extraction
  static Future<List<TopicExtract>> _extractTopicsWithAI(
    String text,
    Future<String> Function(String, String) aiCall,
    int maxTopics,
    String? contextHint,
  ) async {
    final prompt =
        '''Extract the main topics and themes from the following text. For each topic provide:
- Topic name (2-4 words)
- Relevance score (0.0-1.0)
- 3-5 relevant keywords
- Brief description of how this topic was discussed
- Discussion duration estimate (in minutes)

${contextHint != null ? 'Context: $contextHint\n' : ''}

Return exactly $maxTopics topics, ranked by relevance and discussion time.

TEXT TO ANALYZE:
$text

Format each topic as:
TOPIC: [name]
RELEVANCE: [score]
KEYWORDS: [word1, word2, word3, word4, word5]
DESCRIPTION: [brief description]
DURATION: [minutes]
---''';

    const systemPrompt =
        '''You are an expert at identifying discussion topics and themes from meeting transcriptions. Focus on substantive topics that received significant discussion time rather than brief mentions.''';

    final response = await aiCall(prompt, systemPrompt);
    return _parseAITopicResponse(response);
  }

  /// Statistical topic extraction using keyword clustering
  static List<TopicExtract> _extractTopicsStatistically(
    String text,
    int maxTopics,
  ) {
    final keywords = extractKeywords(text: text, maxKeywords: 50);
    final sentences = text.split(RegExp(r'[.!?]+'));

    // Group keywords into topic clusters
    final topicClusters = _clusterKeywords(keywords, sentences);

    // Convert clusters to TopicExtract objects
    final topics = <TopicExtract>[];

    for (int i = 0; i < topicClusters.length && i < maxTopics; i++) {
      final cluster = topicClusters[i];
      final topicName = _generateTopicName(cluster);
      final relevance = _calculateClusterRelevance(cluster, sentences);

      topics.add(
        TopicExtract(
          topic: topicName,
          relevance: relevance,
          keywords: cluster.take(5).toList(),
          description:
              'Statistically identified topic based on keyword frequency',
          discussionDuration: Duration(
            minutes: (relevance * 15).round().clamp(1, 30),
          ),
        ),
      );
    }

    return topics;
  }

  /// Merge AI and statistical topics, removing duplicates
  static List<TopicExtract> _mergeAndRankTopics(
    List<TopicExtract> aiTopics,
    List<TopicExtract> statisticalTopics,
    double threshold,
  ) {
    final mergedTopics = <TopicExtract>[];
    final processedTopics = <String>{};

    // Add AI topics first (they're usually more accurate)
    for (final topic in aiTopics) {
      if (topic.relevance >= threshold) {
        mergedTopics.add(topic);
        processedTopics.add(topic.topic.toLowerCase());
      }
    }

    // Add statistical topics that don't overlap with AI topics
    for (final topic in statisticalTopics) {
      if (topic.relevance >= threshold &&
          !_isTopicDuplicate(topic, processedTopics)) {
        mergedTopics.add(topic);
        processedTopics.add(topic.topic.toLowerCase());
      }
    }

    // Sort by relevance
    mergedTopics.sort((a, b) => b.relevance.compareTo(a.relevance));

    return mergedTopics;
  }

  /// Parse AI response into TopicExtract objects
  static List<TopicExtract> _parseAITopicResponse(String response) {
    final topics = <TopicExtract>[];
    final topicSections = response.split('---');

    for (final section in topicSections) {
      if (section.trim().isEmpty) continue;

      try {
        final topic = _parseTopicSection(section);
        if (topic != null) {
          topics.add(topic);
        }
      } catch (e) {
        log('TopicExtractionService: Failed to parse topic section: $e');
      }
    }

    return topics;
  }

  /// Parse individual topic section
  static TopicExtract? _parseTopicSection(String section) {
    final lines = section.split('\n');

    String? topicName;
    double? relevance;
    List<String>? keywords;
    String? description;
    Duration? duration;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('TOPIC:')) {
        topicName = trimmed.substring(6).trim();
      } else if (trimmed.startsWith('RELEVANCE:')) {
        relevance = double.tryParse(trimmed.substring(10).trim());
      } else if (trimmed.startsWith('KEYWORDS:')) {
        final keywordStr = trimmed.substring(9).trim();
        keywords = keywordStr
            .split(',')
            .map((k) => k.trim())
            .where((k) => k.isNotEmpty)
            .toList();
      } else if (trimmed.startsWith('DESCRIPTION:')) {
        description = trimmed.substring(12).trim();
      } else if (trimmed.startsWith('DURATION:')) {
        final durationStr = trimmed.substring(9).trim();
        final minutes = int.tryParse(
          durationStr.replaceAll(RegExp(r'[^\d]'), ''),
        );
        if (minutes != null) {
          duration = Duration(minutes: minutes);
        }
      }
    }

    if (topicName != null && relevance != null && keywords != null) {
      return TopicExtract(
        topic: topicName,
        relevance: relevance.clamp(0.0, 1.0),
        keywords: keywords,
        description: description ?? 'AI-extracted topic',
        discussionDuration: duration ?? const Duration(minutes: 5),
      );
    }

    return null;
  }

  /// Tokenize text into words
  static List<String> _tokenizeText(String text) {
    return text
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
  }

  /// Get default stop words
  static Set<String> _getDefaultStopWords() {
    return {
      'a',
      'an',
      'and',
      'are',
      'as',
      'at',
      'be',
      'by',
      'for',
      'from',
      'has',
      'he',
      'in',
      'is',
      'it',
      'its',
      'of',
      'on',
      'that',
      'the',
      'to',
      'was',
      'will',
      'with',
      'we',
      'you',
      'i',
      'me',
      'my',
      'our',
      'us',
      'they',
      'them',
      'their',
      'this',
      'these',
      'those',
      'have',
      'had',
      'been',
      'do',
      'does',
      'did',
      'can',
      'could',
      'should',
      'would',
      'may',
      'might',
      'must',
      'shall',
      'am',
      'or',
      'but',
      'if',
      'when',
      'where',
      'how',
      'what',
      'who',
      'why',
      'which',
      'because',
      'before',
      'after',
      'above',
      'below',
      'up',
      'down',
      'out',
      'off',
      'over',
      'under',
      'again',
      'further',
      'then',
      'once',
    };
  }

  /// Cluster keywords into topic groups
  static List<List<String>> _clusterKeywords(
    List<String> keywords,
    List<String> sentences,
  ) {
    final clusters = <List<String>>[];
    final used = <String>{};

    for (final keyword in keywords) {
      if (used.contains(keyword)) continue;

      final cluster = [keyword];
      used.add(keyword);

      // Find related keywords that appear in similar contexts
      for (final otherKeyword in keywords) {
        if (used.contains(otherKeyword) || cluster.length >= 8) continue;

        final cooccurrence = _calculateCooccurrence(
          keyword,
          otherKeyword,
          sentences,
        );

        if (cooccurrence > 0.3) {
          cluster.add(otherKeyword);
          used.add(otherKeyword);
        }
      }

      if (cluster.length >= 2) {
        clusters.add(cluster);
      }
    }

    return clusters;
  }

  /// Calculate co-occurrence score between two keywords
  static double _calculateCooccurrence(
    String keyword1,
    String keyword2,
    List<String> sentences,
  ) {
    int bothCount = 0;
    int totalOccurrences = 0;

    for (final sentence in sentences) {
      final lowerSentence = sentence.toLowerCase();
      final has1 = lowerSentence.contains(keyword1);
      final has2 = lowerSentence.contains(keyword2);

      if (has1 || has2) {
        totalOccurrences++;
        if (has1 && has2) {
          bothCount++;
        }
      }
    }

    return totalOccurrences > 0 ? bothCount / totalOccurrences : 0.0;
  }

  /// Generate topic name from keyword cluster
  static String _generateTopicName(List<String> cluster) {
    if (cluster.isEmpty) return 'Unknown Topic';
    if (cluster.length == 1) return cluster.first;

    // Try to form a meaningful topic name
    final sortedCluster = List<String>.from(cluster)
      ..sort((a, b) => b.length.compareTo(a.length));

    // Use the two most significant keywords
    if (sortedCluster.length >= 2) {
      return '${sortedCluster[0]} & ${sortedCluster[1]}';
    }

    return sortedCluster.first;
  }

  /// Calculate cluster relevance based on keyword frequency in sentences
  static double _calculateClusterRelevance(
    List<String> cluster,
    List<String> sentences,
  ) {
    int totalMatches = 0;

    for (final sentence in sentences) {
      final lowerSentence = sentence.toLowerCase();
      final matches =
          cluster.where((keyword) => lowerSentence.contains(keyword)).length;
      totalMatches += matches;
    }

    final avgMatches = totalMatches / sentences.length;
    return (avgMatches / cluster.length).clamp(0.0, 1.0);
  }

  /// Check if topic is a duplicate
  static bool _isTopicDuplicate(
    TopicExtract topic,
    Set<String> processedTopics,
  ) {
    final topicLower = topic.topic.toLowerCase();

    // Check exact match
    if (processedTopics.contains(topicLower)) {
      return true;
    }

    // Check for high keyword overlap
    for (final processedTopic in processedTopics) {
      final similarity = _calculateStringSimilarity(topicLower, processedTopic);
      if (similarity > 0.7) {
        return true;
      }
    }

    return false;
  }

  /// Calculate similarity between two topics
  static double _calculateTopicSimilarity(
    TopicExtract topic1,
    TopicExtract topic2,
  ) {
    // Keyword overlap
    final keywords1 = topic1.keywords.map((k) => k.toLowerCase()).toSet();
    final keywords2 = topic2.keywords.map((k) => k.toLowerCase()).toSet();

    final intersection = keywords1.intersection(keywords2).length;
    final union = keywords1.union(keywords2).length;

    final keywordSimilarity = union > 0 ? intersection / union : 0.0;

    // Topic name similarity
    final nameSimilarity = _calculateStringSimilarity(
      topic1.topic.toLowerCase(),
      topic2.topic.toLowerCase(),
    );

    return (keywordSimilarity * 0.7) + (nameSimilarity * 0.3);
  }

  /// Check if one topic is a subtopic of another
  static bool _isSubtopic(TopicExtract parentTopic, TopicExtract childTopic) {
    // Check if child topic keywords are subset of parent
    final parentKeywords =
        parentTopic.keywords.map((k) => k.toLowerCase()).toSet();
    final childKeywords =
        childTopic.keywords.map((k) => k.toLowerCase()).toSet();

    final overlap = parentKeywords.intersection(childKeywords).length;
    final childSize = childKeywords.length;

    // Consider it a subtopic if 60% of child keywords are in parent
    return childSize > 0 && (overlap / childSize) >= 0.6;
  }

  /// Calculate string similarity using simple character overlap
  static double _calculateStringSimilarity(String str1, String str2) {
    if (str1 == str2) return 1.0;
    if (str1.isEmpty || str2.isEmpty) return 0.0;

    final chars1 = str1.split('').toSet();
    final chars2 = str2.split('').toSet();

    final intersection = chars1.intersection(chars2).length;
    final union = chars1.union(chars2).length;

    return union > 0 ? intersection / union : 0.0;
  }
}
