/// Summary type enumerations for AI-powered content summarization
library;

/// Types of summaries that can be generated from transcribed content
enum SummaryType {
  /// Brief overview highlighting key points (100-200 words)
  brief('brief', 'Brief Summary', 'Quick overview with essential points'),

  /// Detailed comprehensive summary (500+ words)
  detailed(
    'detailed',
    'Detailed Summary',
    'Comprehensive analysis with full context',
  ),

  /// Structured bullet points format
  bulletPoints(
    'bullet_points',
    'Bullet Points',
    'Key information in bullet format',
  ),

  /// Action items and follow-up tasks
  actionItems(
    'action_items',
    'Action Items',
    'Extracted tasks and assignments',
  ),

  /// Executive summary for leadership
  executive(
    'executive',
    'Executive Summary',
    'High-level overview for decision makers',
  ),

  /// Meeting notes with timestamps
  meetingNotes(
    'meeting_notes',
    'Meeting Notes',
    'Formatted notes with timeline',
  ),

  /// Key highlights and insights
  keyHighlights(
    'key_highlights',
    'Key Highlights',
    'Important insights and decisions',
  ),

  /// Topic-based summary
  topical('topical', 'Topical Summary', 'Organized by discussion topics'),

  /// Speaker-focused summary
  speakerFocused(
    'speaker_focused',
    'Speaker Summary',
    'Organized by speaker contributions',
  ),

  /// Custom format defined by user
  custom('custom', 'Custom Format', 'User-defined summary format');

  const SummaryType(this.value, this.displayName, this.description);

  /// String value for database storage and API calls
  final String value;

  /// Human-readable display name
  final String displayName;

  /// Description of the summary type
  final String description;

  /// Create SummaryType from string value
  static SummaryType fromString(String value) {
    return SummaryType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => SummaryType.brief,
    );
  }

  /// Get all available summary types
  static List<SummaryType> get allTypes => SummaryType.values;

  /// Get summary types suitable for meetings
  static List<SummaryType> get meetingTypes => [
    SummaryType.brief,
    SummaryType.detailed,
    SummaryType.actionItems,
    SummaryType.executive,
    SummaryType.meetingNotes,
    SummaryType.keyHighlights,
  ];

  /// Get summary types suitable for content analysis
  static List<SummaryType> get analysisTypes => [
    SummaryType.topical,
    SummaryType.speakerFocused,
    SummaryType.bulletPoints,
    SummaryType.keyHighlights,
  ];

  @override
  String toString() => value;
}

/// Length categories for summary generation
enum SummaryLength {
  /// Short summary (100-200 words)
  short('short', 'Short', 100, 200),

  /// Medium summary (200-500 words)
  medium('medium', 'Medium', 200, 500),

  /// Long summary (500-1000 words)
  long('long', 'Long', 500, 1000),

  /// Extended summary (1000+ words)
  extended('extended', 'Extended', 1000, 2000),

  /// Custom length defined by user
  custom('custom', 'Custom', 0, 0);

  const SummaryLength(
    this.value,
    this.displayName,
    this.minWords,
    this.maxWords,
  );

  /// String value for configuration
  final String value;

  /// Human-readable display name
  final String displayName;

  /// Minimum word count
  final int minWords;

  /// Maximum word count
  final int maxWords;

  /// Create SummaryLength from string value
  static SummaryLength fromString(String value) {
    return SummaryLength.values.firstWhere(
      (length) => length.value == value,
      orElse: () => SummaryLength.medium,
    );
  }

  /// Get word count range description
  String get wordCountRange {
    if (this == SummaryLength.custom) return 'Custom length';
    if (maxWords >= 2000) return '$minWords+ words';
    return '$minWords-$maxWords words';
  }

  @override
  String toString() => value;
}

/// Focus areas for targeted summarization
enum SummaryFocus {
  /// General overview of all content
  general('general', 'General', 'Overall summary of all content'),

  /// Focus on decisions made
  decisions('decisions', 'Decisions', 'Key decisions and resolutions'),

  /// Focus on action items and tasks
  actions('actions', 'Actions', 'Tasks and follow-up items'),

  /// Focus on technical discussions
  technical('technical', 'Technical', 'Technical details and specifications'),

  /// Focus on business implications
  business('business', 'Business', 'Business impact and considerations'),

  /// Focus on strategic planning
  strategic('strategic', 'Strategic', 'Strategic planning and vision'),

  /// Focus on financial discussions
  financial('financial', 'Financial', 'Financial aspects and budget'),

  /// Focus on timeline and deadlines
  timeline('timeline', 'Timeline', 'Schedules and time-sensitive items'),

  /// Focus on risks and challenges
  risks('risks', 'Risks', 'Identified risks and mitigation'),

  /// Focus on opportunities
  opportunities(
    'opportunities',
    'Opportunities',
    'Potential opportunities and benefits',
  ),

  /// Custom focus defined by user
  custom('custom', 'Custom', 'User-defined focus area');

  const SummaryFocus(this.value, this.displayName, this.description);

  /// String value for configuration
  final String value;

  /// Human-readable display name
  final String displayName;

  /// Description of the focus area
  final String description;

  /// Create SummaryFocus from string value
  static SummaryFocus fromString(String value) {
    return SummaryFocus.values.firstWhere(
      (focus) => focus.value == value,
      orElse: () => SummaryFocus.general,
    );
  }

  /// Get business-focused areas
  static List<SummaryFocus> get businessFocuses => [
    SummaryFocus.decisions,
    SummaryFocus.business,
    SummaryFocus.strategic,
    SummaryFocus.financial,
    SummaryFocus.opportunities,
  ];

  /// Get project-focused areas
  static List<SummaryFocus> get projectFocuses => [
    SummaryFocus.actions,
    SummaryFocus.technical,
    SummaryFocus.timeline,
    SummaryFocus.risks,
  ];

  @override
  String toString() => value;
}
