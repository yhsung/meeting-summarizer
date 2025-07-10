/// Prompt template service for AI summarization requests
library;

import '../enums/summary_type.dart';
import '../models/summarization_configuration.dart';

/// Service for generating AI prompts based on configuration
class PromptTemplateService {
  /// Private constructor to prevent instantiation
  PromptTemplateService._();

  /// Generate prompt for summarization request
  static String generatePrompt({
    required String transcriptionText,
    required SummarizationConfiguration configuration,
  }) {
    final basePrompt = _getBasePrompt(configuration);
    final typeSpecificPrompt = _getTypeSpecificPrompt(configuration);
    final formatInstructions = _getFormatInstructions(configuration);
    final contextInstructions = _getContextInstructions(configuration);

    return '''
$basePrompt

$typeSpecificPrompt

$formatInstructions

$contextInstructions

TRANSCRIPTION TO SUMMARIZE:
${transcriptionText.trim()}

Please provide the summary following the above requirements:''';
  }

  /// Generate system prompt for model context
  static String generateSystemPrompt(SummarizationConfiguration configuration) {
    return '''You are an expert meeting summarizer and content analyst. Your role is to create clear, accurate, and useful summaries from transcribed audio content.

Key principles:
- Focus on factual content and avoid speculation
- Maintain the original context and meaning
- Use ${configuration.tone} tone throughout
- Prioritize ${configuration.summaryFocus.description.toLowerCase()}
- Output in ${_getLanguageName(configuration.language)}

Your summaries should be professional, concise, and actionable.''';
  }

  /// Get base prompt instructions
  static String _getBasePrompt(SummarizationConfiguration configuration) {
    final wordRange =
        configuration.summaryLength == SummaryLength.custom &&
            configuration.customWordCount != null
        ? '${configuration.customWordCount} words'
        : configuration.summaryLength.wordCountRange;

    return '''Create a ${configuration.summaryType.displayName.toLowerCase()} ($wordRange) with a ${configuration.tone} tone, focusing on ${configuration.effectiveFocusDescription.toLowerCase()}.''';
  }

  /// Get type-specific prompt instructions
  static String _getTypeSpecificPrompt(
    SummarizationConfiguration configuration,
  ) {
    switch (configuration.summaryType) {
      case SummaryType.brief:
        return '''Extract the most important points and key outcomes. Focus on high-level insights that someone could read quickly to understand the main topics and decisions.''';

      case SummaryType.detailed:
        return '''Provide a comprehensive analysis including context, discussion details, reasoning behind decisions, and implications. Include background information and nuanced points that provide full understanding.''';

      case SummaryType.bulletPoints:
        return '''Format as clear, concise bullet points. Each point should be self-contained and capture a specific insight, decision, or action item. Use parallel structure and active voice.''';

      case SummaryType.actionItems:
        return '''Focus exclusively on extractable tasks, assignments, deadlines, and follow-up activities. Include who is responsible (if mentioned), when tasks are due, and any dependencies or prerequisites.''';

      case SummaryType.executive:
        return '''Create a high-level strategic overview for senior leadership. Focus on business impact, strategic decisions, resource implications, and recommended next steps. Avoid technical details unless strategically relevant.''';

      case SummaryType.meetingNotes:
        return '''Structure as formal meeting notes with chronological flow. Include agenda items discussed, participants' contributions, decisions made, and action items assigned. Maintain professional meeting documentation format.''';

      case SummaryType.keyHighlights:
        return '''Identify and emphasize the most significant insights, breakthrough moments, important decisions, and notable quotes or statements. Focus on content that stakeholders would want to remember or reference later.''';

      case SummaryType.topical:
        return '''Organize content by main discussion themes or subject areas. Group related points together under clear topic headings. Show how different topics relate to each other and the overall objectives.''';

      case SummaryType.speakerFocused:
        return '''Organize by speaker contributions, highlighting each person's main points, perspectives, and contributions to the discussion. Maintain individual voice and perspective while showing how contributions build on each other.''';

      case SummaryType.custom:
        return configuration.customPrompt ??
            'Follow the custom instructions provided in the additional context.';
    }
  }

  /// Get format-specific instructions
  static String _getFormatInstructions(
    SummarizationConfiguration configuration,
  ) {
    final instructions = <String>[];

    if (configuration.includeTimestamps) {
      instructions.add(
        'Include relevant timestamps where mentioned in the transcription',
      );
    }

    if (configuration.includeSpeakerInfo) {
      instructions.add(
        'Identify and attribute contributions to specific speakers when mentioned',
      );
    }

    if (configuration.extractActionItems) {
      instructions.add(
        'Extract and list action items with assignments and deadlines',
      );
    }

    if (configuration.identifyDecisions) {
      instructions.add('Clearly identify and highlight key decisions made');
    }

    if (configuration.extractTopics) {
      instructions.add('Identify main topics and themes discussed');
    }

    if (configuration.includeConfidenceScores) {
      instructions.add('Indicate confidence level for extracted information');
    }

    if (instructions.isEmpty) {
      return '';
    }

    return 'FORMATTING REQUIREMENTS:\n${instructions.map((i) => '- $i').join('\n')}';
  }

  /// Get context-specific instructions
  static String _getContextInstructions(
    SummarizationConfiguration configuration,
  ) {
    final instructions = <String>[];

    if (configuration.additionalContext != null &&
        configuration.additionalContext!.isNotEmpty) {
      instructions.add(
        'Additional context: ${configuration.additionalContext}',
      );
    }

    // Add focus-specific guidance
    switch (configuration.summaryFocus) {
      case SummaryFocus.decisions:
        instructions.add(
          'Pay special attention to decision-making moments, alternatives considered, and rationale provided',
        );
        break;
      case SummaryFocus.actions:
        instructions.add(
          'Prioritize actionable items, assignments, and next steps over theoretical discussion',
        );
        break;
      case SummaryFocus.technical:
        instructions.add(
          'Include technical details, specifications, and implementation considerations',
        );
        break;
      case SummaryFocus.business:
        instructions.add(
          'Focus on business impact, ROI, costs, and strategic implications',
        );
        break;
      case SummaryFocus.timeline:
        instructions.add(
          'Emphasize deadlines, schedules, milestones, and time-sensitive information',
        );
        break;
      case SummaryFocus.risks:
        instructions.add(
          'Highlight potential risks, challenges, and mitigation strategies discussed',
        );
        break;
      case SummaryFocus.opportunities:
        instructions.add(
          'Focus on opportunities, benefits, and positive outcomes identified',
        );
        break;
      default:
        break;
    }

    // Add length-specific guidance
    if (configuration.summaryLength == SummaryLength.short) {
      instructions.add(
        'Prioritize only the most critical information due to length constraints',
      );
    } else if (configuration.summaryLength == SummaryLength.extended) {
      instructions.add(
        'Provide comprehensive coverage including context and background information',
      );
    }

    if (instructions.isEmpty) {
      return '';
    }

    return '\nADDITIONAL GUIDANCE:\n${instructions.map((i) => '- $i').join('\n')}';
  }

  /// Get language name from code
  static String _getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'es':
        return 'Spanish';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'it':
        return 'Italian';
      case 'pt':
        return 'Portuguese';
      case 'ja':
        return 'Japanese';
      case 'ko':
        return 'Korean';
      case 'zh':
        return 'Chinese';
      default:
        return 'English';
    }
  }

  /// Generate prompt for action item extraction
  static String generateActionItemPrompt(String text, {String? context}) {
    return '''Extract action items from the following text. For each action item, identify:
- Clear description of the task
- Assigned person (if mentioned)
- Due date or deadline (if mentioned)
- Priority level (high/medium/low based on context)
- Any dependencies or prerequisites

${context != null ? 'Context: $context\n' : ''}
TEXT TO ANALYZE:
$text

Provide action items in structured format with confidence scores for each extraction.''';
  }

  /// Generate prompt for key decision identification
  static String generateDecisionPrompt(String text, {String? context}) {
    return '''Identify key decisions made in the following text. For each decision, extract:
- Clear description of what was decided
- Who made the decision (if mentioned)
- Reasoning or rationale provided
- Impact or consequences discussed
- Implementation timeline (if mentioned)

${context != null ? 'Context: $context\n' : ''}
TEXT TO ANALYZE:
$text

Focus on concrete decisions rather than discussions or options considered.''';
  }

  /// Generate prompt for topic extraction
  static String generateTopicPrompt(String text, {int maxTopics = 10}) {
    return '''Extract the main topics and themes from the following text. For each topic:
- Provide a clear, concise topic name
- List 3-5 relevant keywords
- Assign relevance score (0.0-1.0)
- Brief description of how this topic was discussed

Return up to $maxTopics topics, ranked by relevance and discussion time.

TEXT TO ANALYZE:
$text

Focus on substantive topics that received significant discussion rather than brief mentions.''';
  }

  /// Generate follow-up prompt for streaming responses
  static String generateFollowUpPrompt({
    required String originalText,
    required String previousSummary,
    required SummarizationConfiguration configuration,
  }) {
    return '''Continue and improve the following summary based on the complete text. 
Maintain consistency with the existing summary while incorporating any additional insights from the full content.

PREVIOUS SUMMARY:
$previousSummary

COMPLETE TEXT:
$originalText

Please provide an enhanced version that maintains the ${configuration.summaryType.displayName.toLowerCase()} format and ${configuration.tone} tone.''';
  }

  /// Generate validation prompt for quality checking
  static String generateValidationPrompt({
    required String originalText,
    required String summary,
    required SummarizationConfiguration configuration,
  }) {
    return '''Evaluate the quality and accuracy of this summary against the original text. Check for:

1. ACCURACY: Does the summary accurately represent the content?
2. COMPLETENESS: Are all important points covered for a ${configuration.summaryType.displayName.toLowerCase()}?
3. CLARITY: Is the summary clear and well-structured?
4. RELEVANCE: Does it focus on ${configuration.summaryFocus.description.toLowerCase()} as requested?
5. LENGTH: Does it meet the ${configuration.summaryLength.wordCountRange} requirement?

ORIGINAL TEXT:
$originalText

SUMMARY TO EVALUATE:
$summary

Provide a quality score (0.0-1.0) and specific feedback for improvement.''';
  }
}
