/// Anthropic Claude-based summarization service implementation
library;

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

/// Anthropic Claude-based summarization service implementation
class AnthropicSummarizationService implements AISummarizationServiceInterface {
  final Dio _dio;
  final AIProviderConfig _config;
  bool _isInitialized = false;

  AnthropicSummarizationService(this._config) : _dio = Dio() {
    _setupDio();
  }

  void _setupDio() {
    _dio.options = BaseOptions(
      baseUrl: 'https://api.anthropic.com/v1',
      connectTimeout: _config.timeout,
      receiveTimeout: _config.timeout,
      headers: {
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
        'x-api-key': _config.apiKey,
      },
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          logPrint: (obj) => log(obj.toString()),
        ),
      );
    }
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (_config.apiKey?.isEmpty ?? true) {
        throw SummarizationExceptions.invalidConfiguration(
          ['API key cannot be empty'],
        );
      }

      // Test connection with a simple request
      await _testConnection();
      _isInitialized = true;
      log('AnthropicSummarizationService: Initialized successfully');
    } catch (e) {
      log('AnthropicSummarizationService: Initialization failed: $e');
      throw SummarizationExceptions.initializationFailed(
        'Failed to initialize Anthropic service: $e',
      );
    }
  }

  Future<void> _testConnection() async {
    try {
      final response = await _dio.post(
        '/messages',
        data: {
          'model': 'claude-3-5-sonnet-20241022',
          'max_tokens': 10,
          'messages': [
            {'role': 'user', 'content': 'Test'},
          ],
        },
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Connection test failed');
      }
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 400) {
        // 400 with valid auth means API is working
        return;
      }
      rethrow;
    }
  }

  @override
  Future<SummarizationResult> generateSummary({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
    String? sessionId,
  }) async {
    if (!_isInitialized) {
      throw SummarizationExceptions.initializationFailed(
        'Service not initialized',
      );
    }

    if (transcriptionText.trim().isEmpty) {
      throw SummarizationExceptions.invalidConfiguration(
        ['Text is required for summarization'],
      );
    }

    try {
      final prompt = _buildPrompt(transcriptionText, configuration);
      final response = await _makeRequest(prompt, configuration);
      return _parseResponse(response, configuration, sessionId);
    } catch (e) {
      if (e is SummarizationException) rethrow;
      throw SummarizationExceptions.processingFailed(
        'Failed to generate summary: $e',
      );
    }
  }

  String _buildPrompt(String text, SummarizationConfiguration config) {
    final summaryType = config.summaryType;
    final typeInstructions = _getTypeInstructions(summaryType);

    return '''You are an expert meeting analyst. Analyze the following meeting transcription and create a ${summaryType.displayName.toLowerCase()}.

$typeInstructions

Meeting Transcription:
"""
$text
"""

Please provide your analysis in a clear, well-structured format that focuses on the key information and actionable insights.''';
  }

  String _getTypeInstructions(SummaryType type) {
    switch (type) {
      case SummaryType.brief:
        return 'Create a concise executive summary (100-300 words) highlighting main topics, key decisions, and action items.';
      case SummaryType.detailed:
        return 'Create a comprehensive summary (500-1000 words) with detailed discussion points, context, and complete action items.';
      case SummaryType.bulletPoints:
        return 'Create a structured bullet-point summary with main topics as primary bullets and key details as sub-points.';
      case SummaryType.actionItems:
        return 'Focus specifically on extracting and organizing all action items, responsibilities, deadlines, and follow-up requirements.';
      case SummaryType.executive:
        return 'Create an executive-level summary focusing on strategic decisions, high-level outcomes, and business impact.';
      case SummaryType.meetingNotes:
        return 'Create structured meeting notes with topics, discussions, decisions, and action items.';
      case SummaryType.keyHighlights:
        return 'Extract and highlight the most important points and insights from the discussion.';
    }
  }

  Future<Map<String, dynamic>> _makeRequest(
    String prompt,
    SummarizationConfiguration config,
  ) async {
    try {
      final response = await _dio.post(
        '/messages',
        data: {
          'model': 'claude-3-5-sonnet-20241022',
          'max_tokens': 4096,
          'temperature': 0.3,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        },
      );

      if (response.statusCode != 200) {
        throw SummarizationExceptions.networkError(
          'Anthropic API error: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw SummarizationExceptions.operationTimeout(
          const Duration(seconds: 60),
        );
      }

      final statusCode = e.response?.statusCode;
      switch (statusCode) {
        case 401:
          throw SummarizationExceptions.authenticationFailed(
            'Invalid Anthropic API key',
          );
        case 429:
          throw SummarizationExceptions.rateLimitExceeded(
            const Duration(minutes: 1),
          );
        case 400:
          throw SummarizationExceptions.invalidConfiguration(
            'Invalid request to Anthropic API',
            ['Check configuration parameters'],
          );
        default:
          throw SummarizationExceptions.networkError(
            'Network error: ${e.message}',
            statusCode: statusCode,
          );
      }
    }
  }

  SummarizationResult _parseResponse(
    Map<String, dynamic> response,
    SummarizationConfiguration config,
    String? sessionId,
  ) {
    try {
      final content = response['content'] as List<dynamic>?;
      if (content == null || content.isEmpty) {
        throw SummarizationExceptions.parsingFailed(
          'No content in response',
          rawResponse: response.toString(),
        );
      }

      final textContent = content.first as Map<String, dynamic>?;
      if (textContent?['type'] != 'text') {
        throw SummarizationExceptions.parsingFailed(
          'Invalid content type',
          rawResponse: response.toString(),
        );
      }

      final summaryText = textContent?['text'] as String? ?? '';
      if (summaryText.trim().isEmpty) {
        throw SummarizationExceptions.parsingFailed(
          'Empty summary generated',
          rawResponse: response.toString(),
        );
      }

      final wordCount = summaryText.split(RegExp(r'\s+')).length;
      final confidence = _calculateConfidence(summaryText, config.summaryType);

      return SummarizationResult(
        id: sessionId ?? _generateId(),
        content: summaryText.trim(),
        summaryType: config.summaryType,
        keyDecisions: [],
        topics: [],
        keyHighlights: _extractKeyPoints(summaryText),
        confidenceScore: confidence,
        wordCount: wordCount,
        characterCount: summaryText.length,
        aiModel: 'claude-3-5-sonnet-20241022',
        language: 'en',
        createdAt: DateTime.now(),
        sourceTranscriptionId: '',
        actionItems: [],
        metadata: SummarizationMetadata(
          provider: 'anthropic',
          processingTime: 0,
          modelVersion: 'claude-3-5-sonnet-20241022',
          requestId: sessionId ?? _generateId(),
        ),
      );
    } catch (e) {
      if (e is SummarizationException) rethrow;
      throw SummarizationExceptions.parsingFailed(
        'Failed to parse response: $e',
        rawResponse: response.toString(),
      );
    }
  }

  double _calculateConfidence(String text, SummaryType type) {
    double confidence = 0.85; // Base confidence for Anthropic

    // Adjust based on content quality indicators
    if (text.length < 50) confidence -= 0.2;
    if (text.contains('•') || text.contains('-') || text.contains('1.')) {
      confidence += 0.05; // Structured content
    }
    if (text.toLowerCase().contains('action') ||
        text.toLowerCase().contains('decision')) {
      confidence += 0.05; // Contains actionable content
    }

    return confidence.clamp(0.0, 1.0);
  }

  List<String> _extractKeyPoints(String text) {
    final keyPoints = <String>[];

    // Extract bullet points
    final bulletRegex = RegExp(r'^[\s]*[•\-\*]\s*(.+)$', multiLine: true);
    final matches = bulletRegex.allMatches(text);
    for (final match in matches) {
      final point = match.group(1)?.trim();
      if (point != null && point.isNotEmpty) {
        keyPoints.add(point);
      }
    }

    // If no bullets, extract key sentences
    if (keyPoints.isEmpty) {
      final sentences = text.split(RegExp(r'[.!?]+'));
      for (final sentence in sentences) {
        final trimmed = sentence.trim();
        if (trimmed.length > 20 && trimmed.length < 200) {
          if (trimmed.toLowerCase().contains('key') ||
              trimmed.toLowerCase().contains('important') ||
              trimmed.toLowerCase().contains('decision')) {
            keyPoints.add(trimmed);
          }
        }
      }
    }

    return keyPoints.take(10).toList();
  }

  String _generateId() {
    return 'anthropic_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Required interface methods - simplified implementations
  @override
  Stream<SummarizationResult> generateSummaryStream({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
    String? sessionId,
  }) async* {
    yield await generateSummary(
      transcriptionText: transcriptionText,
      configuration: configuration,
      sessionId: sessionId,
    );
  }

  @override
  Future<List<ActionItem>> extractActionItems({
    required String text,
    String? context,
  }) async {
    // Simplified implementation
    return [];
  }

  @override
  Future<List<KeyDecision>> identifyKeyDecisions({
    required String text,
    String? context,
  }) async {
    // Simplified implementation
    return [];
  }

  @override
  Future<List<TopicExtract>> extractTopics({
    required String text,
    int maxTopics = 10,
  }) async {
    // Simplified implementation
    return [];
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
      results[config.summaryType.toString()] = result;
    }
    return results;
  }

  @override
  Future<void> dispose() async {
    try {
      _dio.close();
      _isInitialized = false;
      log('AnthropicSummarizationService: Disposed');
    } catch (e) {
      log('AnthropicSummarizationService: Error during disposal: $e');
    }
  }
}
