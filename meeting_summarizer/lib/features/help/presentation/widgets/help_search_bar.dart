import 'package:flutter/material.dart';
import 'dart:async';

import '../../../../core/services/help_service.dart';

/// Search bar widget for help content
class HelpSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback? onClear;
  final HelpService helpService;
  final ValueChanged<String>? onSearchSubmitted;

  const HelpSearchBar({
    super.key,
    required this.controller,
    required this.helpService,
    this.onClear,
    this.onSearchSubmitted,
  });

  @override
  State<HelpSearchBar> createState() => _HelpSearchBarState();
}

class _HelpSearchBarState extends State<HelpSearchBar> {
  final FocusNode _focusNode = FocusNode();
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;

    // Cancel previous timer
    _debounceTimer?.cancel();

    if (text.isEmpty) {
      setState(() {
        _suggestions.clear();
        _showSuggestions = false;
      });
      return;
    }

    // Debounce suggestions loading
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _loadSuggestions(text);
    });
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // Delay hiding suggestions to allow for selection
      Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            _showSuggestions = false;
          });
        }
      });
    }
  }

  Future<void> _loadSuggestions(String query) async {
    if (query.length < 2) return;

    try {
      final suggestions = await widget.helpService.getSearchSuggestions(query);
      if (mounted && widget.controller.text == query) {
        setState(() {
          _suggestions = suggestions;
          _showSuggestions = suggestions.isNotEmpty && _focusNode.hasFocus;
        });
      }
    } catch (e) {
      // Ignore suggestion loading errors
    }
  }

  void _selectSuggestion(String suggestion) {
    widget.controller.text = suggestion;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );

    setState(() {
      _showSuggestions = false;
    });

    widget.onSearchSubmitted?.call(suggestion);
    _focusNode.unfocus();
  }

  void _onSubmitted(String value) {
    setState(() {
      _showSuggestions = false;
    });
    widget.onSearchSubmitted?.call(value);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Search help articles and FAQs...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      widget.controller.clear();
                      widget.onClear?.call();
                      _focusNode.unfocus();
                    },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _onSubmitted,
          onTap: () {
            if (widget.controller.text.isNotEmpty && _suggestions.isNotEmpty) {
              setState(() {
                _showSuggestions = true;
              });
            }
          },
        ),

        // Suggestions dropdown
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.search, size: 20),
                  title: Text(
                    suggestion,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}
