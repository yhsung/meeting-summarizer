/// Widget for displaying transcription results with various formatting options
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/transcription_result.dart';

/// Widget to display transcription results with rich formatting
class TranscriptionViewer extends StatefulWidget {
  final TranscriptionResult result;
  final bool showTimestamps;
  final bool showSpeakers;
  final bool showConfidence;
  final bool enableSearch;

  const TranscriptionViewer({
    super.key,
    required this.result,
    this.showTimestamps = true,
    this.showSpeakers = false,
    this.showConfidence = false,
    this.enableSearch = true,
  });

  @override
  State<TranscriptionViewer> createState() => _TranscriptionViewerState();
}

class _TranscriptionViewerState extends State<TranscriptionViewer> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  final List<int> _searchMatches = [];
  int _currentSearchIndex = 0;
  bool _showSearchBar = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Toggle search bar visibility
  void _toggleSearch() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        _searchController.clear();
        _searchQuery = '';
        _searchMatches.clear();
        _currentSearchIndex = 0;
      }
    });
  }

  /// Handle search query changes
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _searchMatches.clear();
      _currentSearchIndex = 0;

      if (query.isNotEmpty) {
        _findSearchMatches();
      }
    });
  }

  /// Find search matches in transcription text
  void _findSearchMatches() {
    final text = widget.result.text.toLowerCase();
    int index = 0;

    while (index < text.length) {
      final matchIndex = text.indexOf(_searchQuery, index);
      if (matchIndex == -1) break;

      _searchMatches.add(matchIndex);
      index = matchIndex + 1;
    }
  }

  /// Navigate to next search result
  void _nextSearchResult() {
    if (_searchMatches.isEmpty) return;

    setState(() {
      _currentSearchIndex = (_currentSearchIndex + 1) % _searchMatches.length;
    });
  }

  /// Navigate to previous search result
  void _previousSearchResult() {
    if (_searchMatches.isEmpty) return;

    setState(() {
      _currentSearchIndex = _currentSearchIndex > 0
          ? _currentSearchIndex - 1
          : _searchMatches.length - 1;
    });
  }

  /// Copy text to clipboard
  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.result.text));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Format timestamp for display
  String _formatTimestamp(double seconds) {
    final minutes = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Build highlighted text with search matches
  Widget _buildHighlightedText(String text, TextStyle? style) {
    if (_searchQuery.isEmpty || _searchMatches.isEmpty) {
      return Text(text, style: style);
    }

    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (int i = 0; i < _searchMatches.length; i++) {
      final matchIndex = _searchMatches[i];

      // Add text before match
      if (matchIndex > lastIndex) {
        spans.add(
          TextSpan(text: text.substring(lastIndex, matchIndex), style: style),
        );
      }

      // Add highlighted match
      final isCurrentMatch = i == _currentSearchIndex;
      spans.add(
        TextSpan(
          text: text.substring(matchIndex, matchIndex + _searchQuery.length),
          style: style?.copyWith(
            backgroundColor: isCurrentMatch ? Colors.orange : Colors.yellow,
            color: Colors.black,
          ),
        ),
      );

      lastIndex = matchIndex + _searchQuery.length;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: style));
    }

    return RichText(text: TextSpan(children: spans));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with controls
        Row(
          children: [
            Text(
              'Transcription',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),

            // Search button
            if (widget.enableSearch)
              IconButton(
                onPressed: _toggleSearch,
                icon: Icon(_showSearchBar ? Icons.search_off : Icons.search),
                tooltip: _showSearchBar ? 'Hide Search' : 'Search',
              ),

            // Copy button
            IconButton(
              onPressed: _copyToClipboard,
              icon: const Icon(Icons.copy),
              tooltip: 'Copy Text',
            ),
          ],
        ),

        // Search bar
        if (_showSearchBar) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search transcription...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixText: _searchMatches.isNotEmpty
                        ? '${_currentSearchIndex + 1} of ${_searchMatches.length}'
                        : null,
                  ),
                ),
              ),

              if (_searchMatches.isNotEmpty) ...[
                IconButton(
                  onPressed: _previousSearchResult,
                  icon: const Icon(Icons.keyboard_arrow_up),
                  tooltip: 'Previous Result',
                ),
                IconButton(
                  onPressed: _nextSearchResult,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  tooltip: 'Next Result',
                ),
              ],
            ],
          ),
        ],

        const SizedBox(height: 16),

        // Transcription content
        Expanded(child: _buildTranscriptionContent(theme)),
      ],
    );
  }

  /// Build transcription content based on format preference
  Widget _buildTranscriptionContent(ThemeData theme) {
    if (widget.result.segments.isNotEmpty &&
        (widget.showTimestamps || widget.showSpeakers)) {
      return _buildSegmentedView(theme);
    } else {
      return _buildPlainTextView(theme);
    }
  }

  /// Build segmented view with timestamps and speakers
  Widget _buildSegmentedView(ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.result.segments.length,
      itemBuilder: (context, index) {
        final segment = widget.result.segments[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with timestamp and speaker
              Row(
                children: [
                  if (widget.showTimestamps)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${_formatTimestamp(segment.start)} - ${_formatTimestamp(segment.end)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  if (widget.showSpeakers && segment.speakerId != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Speaker ${segment.speakerId}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],

                  if (widget.showConfidence) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getConfidenceColor(
                          segment.confidence,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${(segment.confidence * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _getConfidenceColor(segment.confidence),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 8),

              // Segment text
              _buildHighlightedText(
                segment.text,
                theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build plain text view
  Widget _buildPlainTextView(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: SelectableText.rich(
          TextSpan(
            children: [
              TextSpan(
                text: widget.result.text,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get confidence color based on confidence value
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.9) return Colors.green;
    if (confidence >= 0.7) return Colors.orange;
    return Colors.red;
  }
}
