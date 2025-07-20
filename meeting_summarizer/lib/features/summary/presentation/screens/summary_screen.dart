/// Summary screen for the meeting summarizer application
library;

import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/models/database/summary.dart';
import '../../../../core/models/database/transcription.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/encrypted_database_service.dart';
import '../widgets/summary_viewer.dart';
import '../widgets/action_items_list.dart';
import '../widgets/summary_type_selector.dart';

/// Main summary screen with summary generation and management
class SummaryScreen extends StatefulWidget {
  /// Required transcription ID to generate summary for
  final String transcriptionId;

  /// Optional existing summary to display
  final Summary? existingSummary;

  /// Optional transcription data
  final Transcription? transcription;

  const SummaryScreen({
    super.key,
    required this.transcriptionId,
    this.existingSummary,
    this.transcription,
  });

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen>
    with TickerProviderStateMixin {
  // Services
  EncryptedDatabaseService? _databaseService;
  DatabaseHelper? _databaseHelper;

  // State management
  List<Summary> _summaries = [];
  Summary? _currentSummary;
  Transcription? _transcription;
  bool _isGenerating = false;
  bool _isLoading = true;
  double _generationProgress = 0.0;
  String _statusMessage = 'Loading summaries...';

  // UI State
  SummaryType _selectedType = SummaryType.brief;
  int _selectedSummaryIndex = 0;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Constants
  static const Duration _animationDuration = Duration(milliseconds: 300);
  static const double _cardElevation = 4.0;
  static const EdgeInsets _screenPadding = EdgeInsets.all(12.0);

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeAndLoadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      await EncryptedDatabaseService.initialize();
      _databaseService = EncryptedDatabaseService();
      _databaseHelper = _databaseService?.databaseHelper;
    } catch (e) {
      log('Failed to initialize EncryptedDatabaseService: $e');
      // Fallback to direct DatabaseHelper if encryption service fails
      _databaseHelper = DatabaseHelper();
    }
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    _slideController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
  }

  Future<void> _initializeAndLoadData() async {
    await _initializeServices();
    await _loadData();
  }

  Future<void> _loadData() async {
    if (_databaseHelper == null) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Database service not available';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Loading summaries...';
      });

      // Load transcription data
      if (widget.transcription != null) {
        _transcription = widget.transcription;
      } else if (widget.transcriptionId.isNotEmpty) {
        _transcription = await _databaseHelper!.getTranscription(
          widget.transcriptionId,
        );
      }

      // Load existing summaries
      if (widget.transcriptionId.isNotEmpty) {
        _summaries = await _databaseHelper!.getSummariesByTranscription(
          widget.transcriptionId,
        );
      }

      // Set current summary
      if (widget.existingSummary != null) {
        _currentSummary = widget.existingSummary;
        _selectedSummaryIndex = _summaries.indexWhere(
          (s) => s.id == _currentSummary?.id,
        );
        if (_selectedSummaryIndex == -1) _selectedSummaryIndex = 0;
      } else if (_summaries.isNotEmpty) {
        _currentSummary = _summaries.first;
        _selectedSummaryIndex = 0;
      }

      setState(() {
        _isLoading = false;
        _statusMessage = _summaries.isEmpty
            ? 'No summaries found. Generate one to get started.'
            : 'Summaries loaded';
      });

      // Start animations
      _fadeController.forward();
      _slideController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error loading summaries: $e';
      });
      _showErrorSnackBar('Failed to load summaries: $e');
    }
  }

  Future<void> _generateSummary() async {
    if (_transcription == null) {
      _showErrorSnackBar('No transcription available to summarize');
      return;
    }

    if (_transcription?.text.isEmpty ?? true) {
      _showErrorSnackBar('Transcription text is empty');
      return;
    }

    try {
      setState(() {
        _isGenerating = true;
        _generationProgress = 0.0;
        _statusMessage = 'Preparing to generate summary...';
      });

      // Simulate generation progress
      final progressTimer = Timer.periodic(const Duration(milliseconds: 100), (
        timer,
      ) {
        setState(() {
          _generationProgress = math.min(_generationProgress + 0.02, 0.9);
          if (_generationProgress < 0.3) {
            _statusMessage = 'Analyzing transcription...';
          } else if (_generationProgress < 0.6) {
            _statusMessage = 'Generating summary...';
          } else if (_generationProgress < 0.9) {
            _statusMessage = 'Finalizing summary...';
          }
        });
      });

      // TODO: Implement actual AI summary generation service
      // For now, create a mock summary
      await Future.delayed(const Duration(seconds: 2));

      progressTimer.cancel();
      setState(() {
        _generationProgress = 1.0;
        _statusMessage = 'Summary generated successfully!';
      });

      // Create mock summary
      final newSummary = Summary(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        transcriptionId: widget.transcriptionId,
        content: _generateMockSummaryContent(),
        type: _selectedType,
        provider: 'mock_provider',
        model: 'mock_model',
        confidence: 0.85,
        wordCount: _calculateWordCount(_generateMockSummaryContent()),
        characterCount: _generateMockSummaryContent().length,
        keyPoints: _generateMockKeyPoints(),
        actionItems: _generateMockActionItems(),
        sentiment: SentimentType.neutral,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to database
      if (_databaseHelper != null) {
        await _databaseHelper!.insertSummary(newSummary);
      }

      // Update UI state
      setState(() {
        _summaries.insert(0, newSummary);
        _currentSummary = newSummary;
        _selectedSummaryIndex = 0;
        _isGenerating = false;
        _statusMessage = 'Summary generated successfully!';
      });

      _showSuccessSnackBar('Summary generated successfully!');
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _statusMessage = 'Error generating summary: $e';
      });
      _showErrorSnackBar('Failed to generate summary: $e');
    }
  }

  String _generateMockSummaryContent() {
    switch (_selectedType) {
      case SummaryType.brief:
        return 'This meeting covered key project updates and discussed upcoming milestones. The team reviewed current progress and identified areas for improvement.';
      case SummaryType.detailed:
        return 'The meeting began with a comprehensive review of the current project status. Team members presented their individual progress reports, highlighting both achievements and challenges encountered since the last meeting. Key discussion points included resource allocation, timeline adjustments, and risk mitigation strategies. The team also reviewed upcoming deliverables and established clear action items for the next sprint.';
      case SummaryType.bulletPoints:
        return '• Project status review completed\n• Individual progress reports presented\n• Resource allocation discussed\n• Timeline adjustments proposed\n• Risk mitigation strategies identified\n• Action items established for next sprint';
      case SummaryType.actionItems:
        return 'Action Items Summary:\n1. Complete user testing by Friday\n2. Review design mockups with stakeholders\n3. Update project timeline based on feedback\n4. Schedule follow-up meeting for next week';
    }
  }

  List<String> _generateMockKeyPoints() {
    return [
      'Project status review completed',
      'Resource allocation needs attention',
      'Timeline adjustments required',
      'Risk mitigation strategies identified',
      'Next sprint planning initiated',
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
    ];
  }

  int _calculateWordCount(String text) {
    return text.trim().split(RegExp(r'\s+')).length;
  }

  void _onSummaryTypeChanged(SummaryType type) {
    setState(() {
      _selectedType = type;
    });
  }

  void _onSummarySelected(int index) {
    if (index >= 0 && index < _summaries.length) {
      setState(() {
        _selectedSummaryIndex = index;
        _currentSummary = _summaries[index];
      });
    }
  }

  Future<void> _deleteSummary(String summaryId) async {
    if (_databaseHelper == null) return;

    try {
      await _databaseHelper!.deleteSummary(summaryId);

      setState(() {
        _summaries.removeWhere((s) => s.id == summaryId);
        if (_currentSummary?.id == summaryId) {
          _currentSummary = _summaries.isNotEmpty ? _summaries.first : null;
          _selectedSummaryIndex = 0;
        }
      });

      _showSuccessSnackBar('Summary deleted successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to delete summary: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meeting Summary'),
        actions: [
          if (_transcription != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isGenerating ? null : _generateSummary,
              tooltip: 'Generate New Summary',
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportSummary();
                  break;
                case 'share':
                  _shareSummary();
                  break;
                case 'settings':
                  _openSettings();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Export Summary'),
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share),
                  title: Text('Share Summary'),
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Summary Settings'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildMainContent(),
      floatingActionButton: _transcription != null
          ? FloatingActionButton.extended(
              onPressed: _isGenerating ? null : _generateSummary,
              label: Text(_isGenerating ? 'Generating...' : 'Generate Summary'),
              icon: _isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
            )
          : null,
    );
  }

  Widget _buildMainContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: _screenPadding,
          child: Column(
            children: [
              if (_isGenerating) _buildGenerationProgress(),
              if (_summaries.isNotEmpty) _buildSummarySelector(),
              if (_summaries.isNotEmpty) _buildSummaryTypeSelector(),
              Expanded(
                child: _currentSummary != null
                    ? _buildSummaryContent()
                    : _buildEmptyState(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenerationProgress() {
    return Card(
      elevation: _cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: _generationProgress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(_statusMessage, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySelector() {
    return Card(
      elevation: _cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Summaries',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _summaries.length,
                itemBuilder: (context, index) {
                  final summary = _summaries[index];
                  final isSelected = index == _selectedSummaryIndex;
                  return GestureDetector(
                    onTap: () => _onSummarySelected(index),
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getIconForSummaryType(summary.type),
                            color: isSelected ? Colors.white : Colors.grey[600],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            summary.type.displayName,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[600],
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTypeSelector() {
    return SummaryTypeSelector(
      selectedType: _selectedType,
      onTypeChanged: _onSummaryTypeChanged,
    );
  }

  Widget _buildSummaryContent() {
    final currentSummary = _currentSummary;
    if (currentSummary == null) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          SummaryViewer(
            summary: currentSummary,
            onDelete: () => _deleteSummary(currentSummary.id),
          ),
          const SizedBox(height: 16),
          if (currentSummary.actionItems?.isNotEmpty ?? false)
            ActionItemsList(
              actionItems: currentSummary.actionItems ?? [],
              onActionItemUpdated: (actionItem) {
                // TODO: Implement action item updates
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.summarize, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Summaries Available',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            _transcription != null
                ? 'Generate a summary to get started'
                : 'No transcription available to summarize',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getIconForSummaryType(SummaryType type) {
    switch (type) {
      case SummaryType.brief:
        return Icons.short_text;
      case SummaryType.detailed:
        return Icons.article;
      case SummaryType.bulletPoints:
        return Icons.format_list_bulleted;
      case SummaryType.actionItems:
        return Icons.task_alt;
    }
  }

  void _exportSummary() {
    if (_currentSummary == null) return;
    // TODO: Implement export functionality
    _showSuccessSnackBar('Export feature coming soon');
  }

  void _shareSummary() {
    if (_currentSummary == null) return;
    // TODO: Implement share functionality
    _showSuccessSnackBar('Share feature coming soon');
  }

  void _openSettings() {
    // TODO: Implement settings dialog
    _showSuccessSnackBar('Settings feature coming soon');
  }
}
