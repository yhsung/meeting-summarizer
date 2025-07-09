/// Summary generator widget for AI-powered summary generation
library;

import 'package:flutter/material.dart';

import '../../../../core/models/database/summary.dart';
import '../../../../core/models/database/transcription.dart';

/// Widget for generating AI-powered summaries from transcriptions
class SummaryGenerator extends StatefulWidget {
  /// The transcription to generate summary from
  final Transcription transcription;

  /// The type of summary to generate
  final SummaryType summaryType;

  /// Callback when summary generation is completed
  final ValueChanged<Summary>? onSummaryGenerated;

  /// Callback when generation progress changes
  final ValueChanged<double>? onProgressChanged;

  /// Callback when generation status changes
  final ValueChanged<String>? onStatusChanged;

  /// Whether generation is currently in progress
  final bool isGenerating;

  const SummaryGenerator({
    super.key,
    required this.transcription,
    required this.summaryType,
    this.onSummaryGenerated,
    this.onProgressChanged,
    this.onStatusChanged,
    this.isGenerating = false,
  });

  @override
  State<SummaryGenerator> createState() => _SummaryGeneratorState();
}

class _SummaryGeneratorState extends State<SummaryGenerator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  double _progress = 0.0;
  String _statusMessage = 'Ready to generate summary';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(SummaryGenerator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isGenerating && !oldWidget.isGenerating) {
      _startGeneration();
    }
  }

  Future<void> _startGeneration() async {
    if (!mounted) return;

    setState(() {
      _progress = 0.0;
      _statusMessage = 'Initializing generation...';
    });
    widget.onProgressChanged?.call(_progress);
    widget.onStatusChanged?.call(_statusMessage);

    try {
      // Simulate generation process with progress updates
      await _simulateGenerationProcess();

      // Generate the actual summary
      final summary = await _generateSummary();

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _statusMessage = 'Summary generated successfully!';
        });
        widget.onProgressChanged?.call(_progress);
        widget.onStatusChanged?.call(_statusMessage);
        widget.onSummaryGenerated?.call(summary);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error generating summary: $e';
        });
        widget.onStatusChanged?.call(_statusMessage);
      }
    }
  }

  Future<void> _simulateGenerationProcess() async {
    final steps = [
      (0.1, 'Analyzing transcription content...'),
      (0.2, 'Identifying key topics...'),
      (0.3, 'Extracting main points...'),
      (0.4, 'Processing speaker context...'),
      (0.5, 'Generating summary structure...'),
      (0.6, 'Creating summary content...'),
      (0.7, 'Identifying action items...'),
      (0.8, 'Analyzing sentiment...'),
      (0.9, 'Finalizing summary...'),
    ];

    for (final (progress, message) in steps) {
      if (!mounted || !widget.isGenerating) break;

      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted) {
        setState(() {
          _progress = progress;
          _statusMessage = message;
        });
        widget.onProgressChanged?.call(_progress);
        widget.onStatusChanged?.call(_statusMessage);
      }
    }
  }

  Future<Summary> _generateSummary() async {
    // TODO: Implement actual AI-powered summary generation
    // This is a mock implementation for demonstration

    await Future.delayed(const Duration(milliseconds: 500));

    final content = _generateMockContent();
    final keyPoints = _generateMockKeyPoints();
    final actionItems = _generateMockActionItems();

    return Summary(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      transcriptionId: widget.transcription.id,
      content: content,
      type: widget.summaryType,
      provider: 'mock_ai_provider',
      model: 'mock_model_v1',
      confidence: 0.85,
      wordCount: _calculateWordCount(content),
      characterCount: content.length,
      keyPoints: keyPoints,
      actionItems: actionItems,
      sentiment: _analyzeSentiment(content),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  String _generateMockContent() {
    switch (widget.summaryType) {
      case SummaryType.brief:
        return 'This meeting covered key project updates and discussed upcoming milestones. The team reviewed current progress and identified areas for improvement. Key decisions were made regarding resource allocation and timeline adjustments.';
      case SummaryType.detailed:
        return 'The meeting began with a comprehensive review of the current project status. Team members presented their individual progress reports, highlighting both achievements and challenges encountered since the last meeting. Key discussion points included resource allocation, timeline adjustments, and risk mitigation strategies. The team also reviewed upcoming deliverables and established clear action items for the next sprint. Several important decisions were made regarding the project direction and resource allocation.';
      case SummaryType.bulletPoints:
        return '• Project status review completed\n• Individual progress reports presented\n• Resource allocation discussed\n• Timeline adjustments proposed\n• Risk mitigation strategies identified\n• Action items established for next sprint\n• Key decisions made on project direction';
      case SummaryType.actionItems:
        return 'Action Items Summary:\n1. Complete user testing by Friday - assigned to John Smith\n2. Review design mockups with stakeholders - assigned to Jane Doe\n3. Update project timeline based on feedback - assigned to Project Manager\n4. Schedule follow-up meeting for next week - assigned to Team Lead\n5. Prepare budget proposal for additional resources - assigned to Finance Team';
    }
  }

  List<String> _generateMockKeyPoints() {
    return [
      'Project milestone review completed successfully',
      'Resource allocation needs immediate attention',
      'Timeline adjustments required for Q2 deliverables',
      'Risk mitigation strategies identified and documented',
      'Next sprint planning initiated with clear objectives',
      'Budget considerations for additional resources discussed',
    ];
  }

  List<ActionItem> _generateMockActionItems() {
    return [
      ActionItem(
        id: '1',
        text: 'Complete user testing by Friday',
        assignee: 'John Smith',
        dueDate: DateTime.now().add(const Duration(days: 3)),
        priority: ActionItemPriority.high,
        status: ActionItemStatus.pending,
      ),
      ActionItem(
        id: '2',
        text: 'Review design mockups with stakeholders',
        assignee: 'Jane Doe',
        dueDate: DateTime.now().add(const Duration(days: 7)),
        priority: ActionItemPriority.medium,
        status: ActionItemStatus.pending,
      ),
      ActionItem(
        id: '3',
        text: 'Update project timeline based on feedback',
        assignee: 'Project Manager',
        dueDate: DateTime.now().add(const Duration(days: 5)),
        priority: ActionItemPriority.high,
        status: ActionItemStatus.pending,
      ),
    ];
  }

  int _calculateWordCount(String text) {
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
  }

  SentimentType _analyzeSentiment(String content) {
    // Mock sentiment analysis
    final lowerContent = content.toLowerCase();

    final positiveWords = [
      'success',
      'achieve',
      'complete',
      'good',
      'great',
      'excellent',
    ];
    final negativeWords = [
      'problem',
      'issue',
      'concern',
      'fail',
      'delay',
      'risk',
    ];

    int positiveCount = 0;
    int negativeCount = 0;

    for (final word in positiveWords) {
      if (lowerContent.contains(word)) positiveCount++;
    }

    for (final word in negativeWords) {
      if (lowerContent.contains(word)) negativeCount++;
    }

    if (positiveCount > negativeCount) return SentimentType.positive;
    if (negativeCount > positiveCount) return SentimentType.negative;
    return SentimentType.neutral;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildProgressIndicator(),
                const SizedBox(height: 16),
                _buildStatusMessage(),
                if (widget.isGenerating) ...[
                  const SizedBox(height: 16),
                  _buildGenerationSteps(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.auto_awesome,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Summary Generation',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Generating ${widget.summaryType.displayName}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        if (widget.isGenerating)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: _progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(_progress * 100).toInt()}%',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              widget.isGenerating ? 'Generating...' : 'Ready',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.blue[600]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationSteps() {
    final steps = [
      'Analyzing transcription content',
      'Identifying key topics',
      'Extracting main points',
      'Processing speaker context',
      'Generating summary structure',
      'Creating summary content',
      'Identifying action items',
      'Analyzing sentiment',
      'Finalizing summary',
    ];

    final currentStep = (_progress * steps.length).floor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Generation Steps',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isCompleted = index < currentStep;
          final isCurrent = index == currentStep;

          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  isCompleted
                      ? Icons.check_circle
                      : isCurrent
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: isCompleted
                      ? Colors.green
                      : isCurrent
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    step,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isCompleted || isCurrent
                          ? Colors.black87
                          : Colors.grey[600],
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
