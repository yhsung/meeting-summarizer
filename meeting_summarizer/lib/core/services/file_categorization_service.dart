import 'package:path/path.dart' as path;

import '../models/storage/file_category.dart';
import '../models/storage/file_metadata.dart';

/// Service for intelligent file categorization and auto-tagging
class FileCategorizationService {
  static const Map<String, FileCategory> _extensionCategoryMap = {
    // Audio formats
    '.wav': FileCategory.recordings,
    '.mp3': FileCategory.recordings,
    '.aac': FileCategory.recordings,
    '.m4a': FileCategory.recordings,
    '.flac': FileCategory.recordings,
    '.ogg': FileCategory.recordings,

    // Enhanced audio (typically with processing markers)
    '.enhanced.wav': FileCategory.enhancedAudio,
    '.enhanced.mp3': FileCategory.enhancedAudio,
    '.processed.wav': FileCategory.enhancedAudio,
    '.processed.mp3': FileCategory.enhancedAudio,

    // Text formats
    '.txt': FileCategory.transcriptions,
    '.md': FileCategory.summaries,
    '.html': FileCategory.exports,
    '.pdf': FileCategory.exports,
    '.docx': FileCategory.exports,

    // Data formats
    '.json': FileCategory.cache,
    '.xml': FileCategory.cache,
    '.csv': FileCategory.exports,

    // Archive formats
    '.zip': FileCategory.archive,
    '.tar': FileCategory.archive,
    '.gz': FileCategory.archive,
    '.bak': FileCategory.archive,
  };

  static const Map<String, List<String>> _categoryTagSuggestions = {
    'recordings': ['audio', 'original', 'recording'],
    'enhancedAudio': ['audio', 'enhanced', 'processed'],
    'transcriptions': ['text', 'transcription', 'speech-to-text'],
    'summaries': ['text', 'summary', 'ai-generated'],
    'exports': ['export', 'shared', 'output'],
    'cache': ['cache', 'temporary'],
    'imports': ['import', 'external'],
    'archive': ['archive', 'backup'],
  };

  /// Automatically categorize a file based on its properties
  static FileCategory categorizeFile(String filePath, {String? content}) {
    final fileName = path.basename(filePath).toLowerCase();
    final extension = path.extension(filePath).toLowerCase();

    // Check for enhanced/processed audio markers in filename
    if (fileName.contains('enhanced') || fileName.contains('processed')) {
      if (_isAudioFile(extension)) {
        return FileCategory.enhancedAudio;
      }
    }

    // Check for specific filename patterns
    if (fileName.contains('transcription') || fileName.contains('transcript')) {
      return FileCategory.transcriptions;
    }

    if (fileName.contains('summary') || fileName.contains('report')) {
      return FileCategory.summaries;
    }

    if (fileName.contains('export') || fileName.contains('shared')) {
      return FileCategory.exports;
    }

    if (fileName.contains('import') || fileName.contains('imported')) {
      return FileCategory.imports;
    }

    if (fileName.contains('backup') || fileName.contains('archive')) {
      return FileCategory.archive;
    }

    if (fileName.contains('cache') || fileName.contains('temp')) {
      return FileCategory.cache;
    }

    // Check extension mapping
    if (_extensionCategoryMap.containsKey(extension)) {
      return _extensionCategoryMap[extension]!;
    }

    // Check compound extensions (e.g., .enhanced.wav)
    for (final compoundExt in _extensionCategoryMap.keys) {
      if (fileName.endsWith(compoundExt)) {
        return _extensionCategoryMap[compoundExt]!;
      }
    }

    // Content-based categorization
    if (content != null) {
      return _categorizeByContent(content);
    }

    // Default fallback based on basic extension
    if (_isAudioFile(extension)) {
      return FileCategory.recordings;
    } else if (_isTextFile(extension)) {
      return FileCategory.transcriptions;
    } else if (_isDocumentFile(extension)) {
      return FileCategory.exports;
    }

    // Ultimate fallback
    return FileCategory.cache;
  }

  /// Generate automatic tags for a file
  static List<String> generateAutoTags(
    String filePath,
    FileCategory category, {
    String? content,
    Map<String, dynamic>? customMetadata,
  }) {
    final tags = <String>{};
    final fileName = path.basename(filePath).toLowerCase();
    final extension = path.extension(filePath).toLowerCase();

    // Add category-based tags
    if (_categoryTagSuggestions.containsKey(category.name)) {
      tags.addAll(_categoryTagSuggestions[category.name]!);
    }

    // Add file type tags
    tags.add(_getFileTypeTag(extension));

    // Add quality/format tags based on filename
    if (fileName.contains('high') || fileName.contains('hq')) {
      tags.add('high-quality');
    }
    if (fileName.contains('low') || fileName.contains('lq')) {
      tags.add('low-quality');
    }
    if (fileName.contains('compressed')) {
      tags.add('compressed');
    }
    if (fileName.contains('uncompressed')) {
      tags.add('uncompressed');
    }

    // Add processing tags
    if (fileName.contains('noise-reduced') || fileName.contains('nr')) {
      tags.add('noise-reduced');
    }
    if (fileName.contains('enhanced')) {
      tags.add('enhanced');
    }
    if (fileName.contains('normalized')) {
      tags.add('normalized');
    }

    // Add date-based tags
    final now = DateTime.now();
    tags.add('${now.year}');
    tags.add('${now.year}-${now.month.toString().padLeft(2, '0')}');

    // Add content-based tags
    if (content != null) {
      tags.addAll(_extractContentTags(content));
    }

    // Add metadata-based tags
    if (customMetadata != null) {
      tags.addAll(_extractMetadataTags(customMetadata));
    }

    return tags.toList()..sort();
  }

  /// Suggest additional tags based on existing files and patterns
  static List<String> suggestTags(
    String filePath,
    List<FileMetadata> existingFiles, {
    String? content,
  }) {
    final suggestions = <String>{};
    final fileName = path.basename(filePath).toLowerCase();

    // Find similar files and extract common tags
    final similarFiles = existingFiles.where((file) {
      final similarity = _calculateFilenameSimilarity(
        fileName,
        file.fileName.toLowerCase(),
      );
      return similarity > 0.3; // 30% similarity threshold
    }).toList();

    // Extract common tags from similar files
    final tagCounts = <String, int>{};
    for (final file in similarFiles) {
      for (final tag in file.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }

    // Suggest tags that appear in multiple similar files
    for (final entry in tagCounts.entries) {
      if (entry.value >= 2) {
        // Tag appears in at least 2 similar files
        suggestions.add(entry.key);
      }
    }

    // Add content-based suggestions
    if (content != null) {
      suggestions.addAll(_extractContentTags(content, minOccurrences: 2));
    }

    return suggestions.toList()..sort();
  }

  /// Validate and clean up tags
  static List<String> validateTags(List<String> tags) {
    final validTags = <String>[];

    for (final tag in tags) {
      final cleanTag = tag.trim().toLowerCase();

      // Skip empty or very short tags
      if (cleanTag.length < 2) continue;

      // Skip tags with invalid characters
      if (!RegExp(r'^[a-z0-9\-_\.]+$').hasMatch(cleanTag)) continue;

      // Skip duplicate tags
      if (validTags.contains(cleanTag)) continue;

      // Skip overly generic tags
      if (_isGenericTag(cleanTag)) continue;

      validTags.add(cleanTag);
    }

    return validTags;
  }

  /// Get smart search suggestions based on tags and metadata
  static List<String> getSearchSuggestions(
    List<FileMetadata> allFiles, {
    String? currentQuery,
  }) {
    final suggestions = <String>{};
    final tagFrequency = <String, int>{};

    // Count tag frequencies
    for (final file in allFiles) {
      for (final tag in file.tags) {
        tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
      }
    }

    // Add popular tags as suggestions
    final popularTags =
        tagFrequency.entries
            .where((entry) => entry.value >= 3) // Tags used by at least 3 files
            .map((entry) => entry.key)
            .toList()
          ..sort((a, b) => tagFrequency[b]!.compareTo(tagFrequency[a]!));

    suggestions.addAll(popularTags.take(10)); // Top 10 popular tags

    // Add category names as suggestions
    for (final category in FileCategory.values) {
      suggestions.add(category.displayName.toLowerCase());
    }

    // Add time-based suggestions
    final now = DateTime.now();
    suggestions.addAll([
      'today',
      'this week',
      'this month',
      'last month',
      now.year.toString(),
      (now.year - 1).toString(),
    ]);

    // Filter by current query if provided
    if (currentQuery != null && currentQuery.isNotEmpty) {
      final query = currentQuery.toLowerCase();
      return suggestions
          .where((suggestion) => suggestion.contains(query))
          .toList();
    }

    return suggestions.toList();
  }

  // Private helper methods

  static bool _isAudioFile(String extension) {
    return [
      '.wav',
      '.mp3',
      '.aac',
      '.m4a',
      '.flac',
      '.ogg',
    ].contains(extension);
  }

  static bool _isTextFile(String extension) {
    return ['.txt', '.md', '.json'].contains(extension);
  }

  static bool _isDocumentFile(String extension) {
    return ['.pdf', '.docx', '.html', '.csv'].contains(extension);
  }

  static FileCategory _categorizeByContent(String content) {
    final contentLower = content.toLowerCase();

    if (contentLower.contains('transcript') ||
        contentLower.contains('speaker')) {
      return FileCategory.transcriptions;
    }

    if (contentLower.contains('summary') ||
        contentLower.contains('conclusion')) {
      return FileCategory.summaries;
    }

    // Check for JSON structure (likely metadata/cache)
    if (content.trim().startsWith('{') && content.trim().endsWith('}')) {
      return FileCategory.cache;
    }

    return FileCategory.transcriptions; // Default for text content
  }

  static String _getFileTypeTag(String extension) {
    switch (extension) {
      case '.wav':
        return 'wav';
      case '.mp3':
        return 'mp3';
      case '.aac':
        return 'aac';
      case '.m4a':
        return 'm4a';
      case '.txt':
        return 'text';
      case '.md':
        return 'markdown';
      case '.json':
        return 'json';
      case '.pdf':
        return 'pdf';
      default:
        return extension.replaceFirst('.', '');
    }
  }

  static List<String> _extractContentTags(
    String content, {
    int minOccurrences = 1,
  }) {
    final tags = <String>{};
    final words = content.toLowerCase().split(RegExp(r'\W+'));
    final wordCounts = <String, int>{};

    // Count word occurrences
    for (final word in words) {
      if (word.length >= 3 && !_isStopWord(word)) {
        wordCounts[word] = (wordCounts[word] ?? 0) + 1;
      }
    }

    // Extract words that occur frequently enough
    for (final entry in wordCounts.entries) {
      if (entry.value >= minOccurrences) {
        tags.add(entry.key);
      }
    }

    return tags.toList();
  }

  static List<String> _extractMetadataTags(Map<String, dynamic> metadata) {
    final tags = <String>{};

    // Extract tags from metadata keys and values
    for (final entry in metadata.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value.toString().toLowerCase();

      if (key.contains('quality')) {
        tags.add('quality-$value');
      }
      if (key.contains('format')) {
        tags.add('format-$value');
      }
      if (key.contains('duration') && value.isNotEmpty) {
        tags.add('duration');
      }
      if (key.contains('speaker') && value.isNotEmpty) {
        tags.add('speaker');
      }
    }

    return tags.toList();
  }

  static double _calculateFilenameSimilarity(String name1, String name2) {
    // Simple Jaccard similarity for filename comparison
    final words1 = name1
        .split(RegExp(r'\W+'))
        .where((w) => w.isNotEmpty)
        .toSet();
    final words2 = name2
        .split(RegExp(r'\W+'))
        .where((w) => w.isNotEmpty)
        .toSet();

    if (words1.isEmpty && words2.isEmpty) return 1.0;
    if (words1.isEmpty || words2.isEmpty) return 0.0;

    final intersection = words1.intersection(words2);
    final union = words1.union(words2);

    return intersection.length / union.length;
  }

  static bool _isGenericTag(String tag) {
    const genericTags = {
      'file',
      'data',
      'content',
      'item',
      'new',
      'old',
      'temp',
      'tmp',
      'test',
      'sample',
      'example',
      'default',
      'misc',
      'other',
    };
    return genericTags.contains(tag);
  }

  static bool _isStopWord(String word) {
    const stopWords = {
      'the',
      'and',
      'or',
      'but',
      'in',
      'on',
      'at',
      'to',
      'for',
      'of',
      'with',
      'by',
      'from',
      'up',
      'about',
      'into',
      'through',
      'during',
      'before',
      'after',
      'above',
      'below',
      'this',
      'that',
      'these',
      'those',
      'i',
      'me',
      'my',
      'myself',
      'we',
      'our',
      'ours',
      'ourselves',
      'you',
      'your',
      'yours',
      'yourself',
      'yourselves',
      'he',
      'him',
      'his',
      'himself',
      'she',
      'her',
      'hers',
      'herself',
      'it',
      'its',
      'itself',
      'they',
      'them',
      'their',
      'theirs',
      'themselves',
      'what',
      'which',
      'who',
      'whom',
      'when',
      'where',
      'why',
      'how',
      'all',
      'any',
      'both',
      'each',
      'few',
      'more',
      'most',
      'other',
      'some',
      'such',
      'no',
      'nor',
      'not',
      'only',
      'own',
      'same',
      'so',
      'than',
      'too',
      'very',
      'can',
      'will',
      'just',
      'should',
      'now',
    };
    return stopWords.contains(word);
  }
}
