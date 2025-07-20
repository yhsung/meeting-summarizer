import 'dart:async';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'ai_summarization_service_interface.dart';
import 'ai_provider_factory.dart';
import '../models/summarization_configuration.dart';
import '../models/summarization_result.dart';
import '../enums/summary_type.dart';
import '../exceptions/summarization_exceptions.dart';

/// OpenAI GPT-based summarization service implementation
class OpenAISummarizationService implements AISummarizationServiceInterface {
  final Dio _dio;
  final AIProviderConfig _config;
  bool _isInitialized = false;

  OpenAISummarizationService(this._config) : _dio = Dio() {
    _setupDio();
  }

  void _setupDio() {
    _dio.options = BaseOptions(
      baseUrl: _config.baseUrl ?? 'https://api.openai.com/v1',
      connectTimeout: _config.timeout,
      receiveTimeout: _config.timeout,
      headers: {
        'Authorization': 'Bearer ${_config.apiKey}',
        'Content-Type': 'application/json',
        'User-Agent': 'MeetingSummarizer/1.0.0',
      },
    );

    // Add logging in debug mode
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          logPrint: (obj) =>
              log(obj.toString(), name: 'OpenAISummarizationService'),
        ),
      );
    }
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Test connection with a simple request
      await _testConnection();
      _isInitialized = true;
      log('OpenAISummarizationService: Initialized successfully');
    } catch (e, stackTrace) {
      throw SummarizationExceptions.initializationFailed(
        'OpenAI service initialization failed: $e',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      _dio.close();
      _isInitialized = false;
      log('OpenAISummarizationService: Disposed successfully');
    } catch (e) {
      log('OpenAISummarizationService: Error during disposal: $e');
    }
  }

  @override
  Future<SummarizationResult> generateSummary({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
    String? sessionId,
  }) async {
    _ensureInitialized();

    try {
      final prompt = _buildPrompt(transcriptionText, configuration);
      final response = await _makeRequest(prompt, configuration);

      return _parseResponse(
        response,
        configuration,
        sessionId ?? _generateId(),
      );
    } catch (e) {
      throw SummarizationExceptions.processingFailed(
        'Summary generation failed: $e',
      );
    }
  }

  @override
  Stream<SummarizationResult> generateSummaryStream({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
    String? sessionId,
  }) async* {
    _ensureInitialized();

    try {
      // For now, just yield the regular summary result
      // Streaming could be implemented later with SSE
      final result = await generateSummary(
        transcriptionText: transcriptionText,
        configuration: configuration,
        sessionId: sessionId,
      );
      yield result;
    } catch (e) {
      throw SummarizationExceptions.processingFailed(
        'Streaming summary generation failed: $e',
      );
    }
  }

  @override
  Future<List<ActionItem>> extractActionItems({
    required String text,
    String? context,
  }) async {
    _ensureInitialized();

    try {
      final prompt = _buildActionItemsPrompt(text, context);
      final response = await _makeRequest(
        prompt,
        SummarizationConfiguration.actionItemsDefault(),
      );

      return _parseActionItems(response);
    } catch (e) {
      throw SummarizationExceptions.processingFailed(
        'Action items extraction failed: $e',
      );
    }
  }

  @override
  Future<List<KeyDecision>> identifyKeyDecisions({
    required String text,
    String? context,
  }) async {
    _ensureInitialized();

    try {
      final prompt = _buildKeyDecisionsPrompt(text, context);
      final response = await _makeRequest(
        prompt,
        SummarizationConfiguration.meetingDefault(),
      );

      return _parseKeyDecisions(response);
    } catch (e) {
      throw SummarizationExceptions.processingFailed(
        'Key decisions identification failed: $e',
      );
    }
  }

  @override
  Future<List<TopicExtract>> extractTopics({
    required String text,
    int maxTopics = 10,
  }) async {
    _ensureInitialized();

    try {
      final prompt = _buildTopicsPrompt(text, maxTopics);
      final response = await _makeRequest(
        prompt,
        SummarizationConfiguration.meetingDefault(),
      );

      return _parseTopics(response);
    } catch (e) {
      throw SummarizationExceptions.processingFailed(
        'Topics extraction failed: $e',
      );
    }
  }

  @override
  Future<Map<String, SummarizationResult>> generateMultipleSummaries({
    required String transcriptionText,
    required List<SummarizationConfiguration> configurations,
    String? sessionId,
  }) async {
    final results = <String, SummarizationResult>{};

    for (final config in configurations) {
      final result = await generateSummary(
        transcriptionText: transcriptionText,
        configuration: config,
        sessionId: sessionId,
      );
      results[config.summaryType.value] = result;
    }

    return results;
  }

  @override
  Future<ConfigurationValidationResult> validateConfiguration(
    SummarizationConfiguration configuration,
  ) async {
    final errors = <String>[];
    final warnings = <String>[];

    // Validate token limits
    if (configuration.maxTokens > capabilities.maxOutputTokens) {
      errors.add(
        'Max tokens (${configuration.maxTokens}) exceeds limit (${capabilities.maxOutputTokens})',
      );
    }

    // Validate language support
    if (!capabilities.supportedLanguages.contains(configuration.language)) {
      warnings.add(
        'Language ${configuration.language} may not be fully supported',
      );
    }

    // Validate summary type
    if (!capabilities.supportedSummaryTypes.contains(
      configuration.summaryType.value,
    )) {
      warnings.add(
        'Summary type ${configuration.summaryType.value} may not be optimized',
      );
    }

    return ConfigurationValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  @override
  ServiceCapabilities get capabilities {
    return const ServiceCapabilities(
      supportedLanguages: [
        'en',
        'es',
        'fr',
        'de',
        'it',
        'pt',
        'ja',
        'ko',
        'zh',
        'ar',
        'hi',
        'ru',
      ],
      supportedSummaryTypes: [
        'brief',
        'detailed',
        'bullet_points',
        'action_items',
        'executive',
        'meeting_notes',
        'key_highlights',
        'topical',
      ],
      maxInputTokens: 32000,
      maxOutputTokens: 4000,
      supportsStreaming: true,
      supportsActionItems: true,
      supportsDecisionExtraction: true,
      supportsTopicExtraction: true,
      supportsBatchProcessing: false,
    );
  }

  @override
  Future<bool> isReady() async {
    if (!_isInitialized) return false;

    try {
      await _testConnection();
      return true;
    } catch (e) {
      log('OpenAISummarizationService: Service not ready: $e');
      return false;
    }
  }

  @override
  Future<ServiceHealthStatus> getHealthStatus() async {
    if (!_isInitialized) {
      return ServiceHealthStatus.unhealthy(
        status: 'not_initialized',
        issues: ['Service not initialized'],
      );
    }

    try {
      await _testConnection();
      return ServiceHealthStatus.healthy();
    } catch (e) {
      return ServiceHealthStatus.unhealthy(
        status: 'connection_failed',
        issues: ['Unable to connect to OpenAI API: $e'],
        metrics: {'error': e.toString()},
      );
    }
  }

  Future<void> _testConnection() async {
    try {
      final response = await _dio.get('/models');
      if (response.statusCode != 200) {
        throw Exception('API returned status ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection test failed: $e');
    }
  }

  String _buildPrompt(
    String transcriptionText,
    SummarizationConfiguration config,
  ) {
    final buffer = StringBuffer();

    // System context based on summary type
    buffer.writeln(_getSystemPrompt(config.summaryType));
    buffer.writeln();

    // Additional context if provided
    if (config.additionalContext != null &&
        config.additionalContext!.isNotEmpty) {
      buffer.writeln('Additional Context: ${config.additionalContext}');
      buffer.writeln();
    }

    // Length specification
    if (config.summaryLength.maxWords > 0) {
      buffer.writeln('Target Length: ~${config.summaryLength.maxWords} words');
      buffer.writeln();
    }

    // Language specification
    if (config.language != 'en') {
      buffer.writeln('Please respond in language: ${config.language}');
      buffer.writeln();
    }

    // The transcription to summarize
    buffer.writeln('Transcription to summarize:');
    buffer.writeln(transcriptionText);

    return buffer.toString();
  }

  String _getSystemPrompt(SummaryType type) {
    switch (type) {
      case SummaryType.brief:
        return 'You are a professional meeting summarizer. Create a concise, clear summary that captures the main points and outcomes. Focus on key decisions, action items, and important discussions.';

      case SummaryType.detailed:
        return 'You are a professional meeting summarizer. Create a comprehensive, detailed summary that covers all major topics discussed, decisions made, and action items identified. Include context and background where relevant.';

      case SummaryType.bulletPoints:
        return 'You are a professional meeting summarizer. Create a well-organized bullet-point summary that clearly lists main topics, key decisions, action items, and important notes. Use clear formatting and hierarchical structure.';

      case SummaryType.actionItems:
        return 'You are a professional meeting summarizer focused on action items. Extract and clearly list all action items, tasks, decisions, and follow-ups mentioned in the meeting. Include who is responsible and any deadlines mentioned.';

      case SummaryType.executive:
        return 'You are a professional executive summary writer. Create a high-level executive summary suitable for leadership review. Focus on strategic decisions, business impact, key outcomes, and next steps.';

      case SummaryType.meetingNotes:
        return 'You are a professional note-taker. Create comprehensive meeting notes that capture the flow of discussion, participants\' contributions, decisions made, and action items. Maintain chronological order where appropriate.';

      case SummaryType.keyHighlights:
        return 'You are a professional meeting summarizer focused on highlights. Extract and present the most important and noteworthy points, decisions, announcements, and insights from the meeting.';

      case SummaryType.topical:
        return 'You are a professional meeting summarizer. Organize the summary by topics and themes discussed. Group related points together and provide clear topic headings for easy navigation.';

      case SummaryType.speakerFocused:
        return 'You are a professional meeting summarizer. Organize the summary by speaker contributions and dialogue. Highlight who said what and track individual contributions to the discussion.';

      case SummaryType.custom:
        return 'You are a professional meeting summarizer. Create a custom summary based on the user\'s specific requirements and focus areas.';
    }
  }

  String _buildActionItemsPrompt(String text, String? context) {
    final buffer = StringBuffer();
    buffer.writeln(
      'You are an expert at extracting action items from meeting transcriptions.',
    );
    buffer.writeln(
      'Extract all action items, tasks, assignments, and follow-ups mentioned.',
    );
    buffer.writeln('For each action item, identify:');
    buffer.writeln('- The task description');
    buffer.writeln('- Who is responsible (if mentioned)');
    buffer.writeln('- Any deadline or timeline (if mentioned)');
    buffer.writeln('- Priority level (if indicated)');
    buffer.writeln();

    if (context != null && context.isNotEmpty) {
      buffer.writeln('Context: $context');
      buffer.writeln();
    }

    buffer.writeln('Text to analyze:');
    buffer.writeln(text);

    return buffer.toString();
  }

  String _buildKeyDecisionsPrompt(String text, String? context) {
    final buffer = StringBuffer();
    buffer.writeln(
      'You are an expert at identifying key decisions from meeting transcriptions.',
    );
    buffer.writeln(
      'Extract all important decisions, conclusions, and resolutions made.',
    );
    buffer.writeln('For each decision, identify:');
    buffer.writeln('- The decision made');
    buffer.writeln('- Who made the decision (if mentioned)');
    buffer.writeln('- The context or reasoning');
    buffer.writeln('- Any conditions or next steps');
    buffer.writeln();

    if (context != null && context.isNotEmpty) {
      buffer.writeln('Context: $context');
      buffer.writeln();
    }

    buffer.writeln('Text to analyze:');
    buffer.writeln(text);

    return buffer.toString();
  }

  String _buildTopicsPrompt(String text, int maxTopics) {
    final buffer = StringBuffer();
    buffer.writeln(
      'You are an expert at extracting topics and themes from meeting transcriptions.',
    );
    buffer.writeln(
      'Identify the main topics, themes, and subject areas discussed.',
    );
    buffer.writeln(
      'Extract up to $maxTopics topics, ranked by importance and time spent.',
    );
    buffer.writeln('For each topic, provide:');
    buffer.writeln('- Topic name/title');
    buffer.writeln('- Brief description');
    buffer.writeln('- Key points discussed');
    buffer.writeln();
    buffer.writeln('Text to analyze:');
    buffer.writeln(text);

    return buffer.toString();
  }

  Future<Map<String, dynamic>> _makeRequest(
    String prompt,
    SummarizationConfiguration config,
  ) async {
    final requestData = {
      'model': _config.model ?? 'gpt-3.5-turbo',
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      'max_tokens': config.maxTokens,
      'temperature': config.temperature,
      'stream': false,
      ..._config.parameters,
    };

    final response = await _dio.post('/chat/completions', data: requestData);

    if (response.statusCode != 200) {
      throw Exception(
        'OpenAI API returned status ${response.statusCode}: ${response.data}',
      );
    }

    return response.data as Map<String, dynamic>;
  }

  SummarizationResult _parseResponse(
    Map<String, dynamic> response,
    SummarizationConfiguration config,
    String sessionId,
  ) {
    try {
      final choices = response['choices'] as List;
      if (choices.isEmpty) {
        throw Exception('No choices in OpenAI response');
      }

      final content = choices[0]['message']['content'] as String;
      final usage = response['usage'] as Map<String, dynamic>?;

      return SummarizationResult(
        id: sessionId,
        content: content.trim(),
        summaryType: config.summaryType,
        actionItems: const [],
        keyDecisions: const [],
        topics: const [],
        keyHighlights: _extractKeyPoints(content),
        confidenceScore: 0.85, // OpenAI doesn't provide confidence scores
        wordCount: _countWords(content),
        characterCount: content.length,
        processingTimeMs: 0, // Would need to track this
        aiModel: _config.model ?? 'gpt-3.5-turbo',
        language: config.language,
        createdAt: DateTime.now(),
        sourceTranscriptionId: '', // Would need to be passed in
        metadata: SummarizationMetadata(
          totalTokens: usage?['total_tokens'] ?? 0,
          promptTokens: usage?['prompt_tokens'] ?? 0,
          completionTokens: usage?['completion_tokens'] ?? 0,
        ),
      );
    } catch (e) {
      throw Exception('Failed to parse OpenAI response: $e');
    }
  }

  List<ActionItem> _parseActionItems(Map<String, dynamic> response) {
    try {
      final content =
          (response['choices'] as List)[0]['message']['content'] as String;

      // Simple parsing - would be enhanced with better NLP
      final actionItems = <ActionItem>[];
      final lines = content.split('\n');

      for (final line in lines) {
        if (line.trim().isNotEmpty &&
            (line.contains('TODO') ||
                line.contains('Action:') ||
                line.contains('Task:'))) {
          actionItems.add(
            ActionItem(
              id: _generateId(),
              description: line.trim(),
              priority: 'medium',
            ),
          );
        }
      }

      return actionItems;
    } catch (e) {
      throw Exception('Failed to parse action items: $e');
    }
  }

  List<KeyDecision> _parseKeyDecisions(Map<String, dynamic> response) {
    try {
      final content =
          (response['choices'] as List)[0]['message']['content'] as String;

      // Simple parsing - would be enhanced with better NLP
      final decisions = <KeyDecision>[];
      final lines = content.split('\n');

      for (final line in lines) {
        if (line.trim().isNotEmpty &&
            (line.contains('Decision:') ||
                line.contains('Resolved:') ||
                line.contains('Agreed:'))) {
          decisions.add(
            KeyDecision(id: _generateId(), description: line.trim()),
          );
        }
      }

      return decisions;
    } catch (e) {
      throw Exception('Failed to parse key decisions: $e');
    }
  }

  List<TopicExtract> _parseTopics(Map<String, dynamic> response) {
    try {
      final content =
          (response['choices'] as List)[0]['message']['content'] as String;

      // Simple parsing - would be enhanced with better NLP
      final topics = <TopicExtract>[];
      final lines = content.split('\n');

      for (int i = 0; i < lines.length && topics.length < 10; i++) {
        final line = lines[i].trim();
        if (line.isNotEmpty && line.contains(':')) {
          final parts = line.split(':');
          if (parts.length >= 2) {
            topics.add(
              TopicExtract(
                topic: parts[0].trim(),
                relevance: 1.0 - (topics.length * 0.1), // Decreasing relevance
                keywords: [],
                description: parts.sublist(1).join(':').trim(),
              ),
            );
          }
        }
      }

      return topics;
    } catch (e) {
      throw Exception('Failed to parse topics: $e');
    }
  }

  List<String> _extractKeyPoints(String content) {
    // Simple key points extraction
    final points = <String>[];
    final lines = content.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('•') ||
          trimmed.startsWith('-') ||
          trimmed.startsWith('*') ||
          trimmed.contains('Key point:') ||
          trimmed.contains('Important:')) {
        points.add(trimmed);
      }
    }

    return points;
  }

  int _countWords(String text) {
    return text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw SummarizationExceptions.serviceUnavailable(
        'OpenAI service not initialized. Call initialize() first.',
      );
    }
  }
}
