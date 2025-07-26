/// Comprehensive settings management screen
library;

import 'dart:developer';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/database/app_settings.dart';
import '../../../../core/services/settings_service.dart';
import '../widgets/settings_widgets.dart';
import '../../../feedback/data/services/feedback_service_provider.dart';

/// Main settings management screen with categorized settings and search
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final SettingsService _settingsService = SettingsService.instance;

  List<AppSettings> _allSettings = [];
  List<AppSettings> _filteredSettings = [];
  Map<SettingCategory, List<AppSettings>> _categorizedSettings = {};
  String _searchQuery = '';
  bool _isLoading = true;
  String? _error;

  late TabController _tabController;
  final List<SettingCategory> _categories = SettingCategory.values;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length + 1, vsync: this);
    _initializeSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Ensure settings service is initialized
      await _settingsService.initialize();

      // Load all settings
      await _loadSettings();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      log('SettingsScreen: Error initializing settings: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = _settingsService.getAllSettings();

      setState(() {
        _allSettings = settings;
        _filteredSettings = settings;
        _categorizedSettings = _groupSettingsByCategory(settings);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Map<SettingCategory, List<AppSettings>> _groupSettingsByCategory(
    List<AppSettings> settings,
  ) {
    final grouped = <SettingCategory, List<AppSettings>>{};

    for (final category in _categories) {
      grouped[category] = settings
          .where((setting) => setting.category == category)
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
    }

    return grouped;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredSettings = _allSettings;
        _categorizedSettings = _groupSettingsByCategory(_allSettings);
      } else {
        _filteredSettings = _settingsService.searchSettings(query);
        _categorizedSettings = _groupSettingsByCategory(_filteredSettings);
      }
    });
  }

  Future<void> _onSettingChanged(String key, dynamic value) async {
    try {
      // Validate the new value
      if (!_settingsService.validateSetting(key, value)) {
        _showSnackBar('Invalid value for $key', isError: true);
        return;
      }

      // Update the setting
      await _settingsService.setSetting(key, value);

      // Reload settings to reflect changes
      await _loadSettings();

      log('SettingsScreen: Updated setting $key = $value');
      _showSnackBar('Setting updated successfully');
    } catch (e) {
      log('SettingsScreen: Error updating setting $key: $e');
      _showSnackBar('Failed to update setting: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  Future<void> _resetAllSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Settings'),
        content: const Text(
          'Are you sure you want to reset all settings to their default values? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _settingsService.resetAllSettings();
        await _loadSettings();
        _showSnackBar('All settings reset to defaults');
      } catch (e) {
        _showSnackBar('Failed to reset settings: $e', isError: true);
      }
    }
  }

  Future<void> _exportSettings() async {
    try {
      final exportData = _settingsService.exportSettings();
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      await Clipboard.setData(ClipboardData(text: jsonString));
      _showSnackBar('Settings exported to clipboard');
    } catch (e) {
      _showSnackBar('Failed to export settings: $e', isError: true);
    }
  }

  Future<void> _importSettings() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text == null) {
      _showSnackBar('No data found in clipboard', isError: true);
      return;
    }

    try {
      final data = json.decode(clipboardData!.text!) as Map<String, dynamic>;
      final importedCount = await _settingsService.importSettings(data);

      await _loadSettings();
      _showSnackBar('Imported $importedCount settings successfully');
    } catch (e) {
      _showSnackBar('Failed to import settings: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportSettings();
                  break;
                case 'import':
                  _importSettings();
                  break;
                case 'reset':
                  _resetAllSettings();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.upload),
                    SizedBox(width: 8),
                    Text('Export Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Import Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restore, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Reset All', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(icon: Icon(Icons.search), text: 'Search'),
            ..._categories.map(
              (category) => Tab(
                icon: Icon(_getCategoryIcon(category)),
                text: category.displayName.split(' ').first,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSearchTab(),
                    ..._categories
                        .map((category) => _buildCategoryTab(category)),
                  ],
                ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load settings',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _initializeSettings,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        SettingsSearchWidget(
          onSearchChanged: _onSearchChanged,
          initialQuery: _searchQuery,
        ),
        Expanded(
          child: _searchQuery.isEmpty
              ? _buildWelcomeWidget()
              : _filteredSettings.isEmpty
                  ? _buildNoResultsWidget()
                  : _buildSettingsList(_filteredSettings),
        ),
      ],
    );
  }

  Widget _buildWelcomeWidget() {
    final theme = Theme.of(context);
    final settingsCounts = _settingsService.getSettingsCountByCategory();
    final totalSettings = settingsCounts.values.fold(
      0,
      (sum, count) => sum + count,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.settings,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Settings Management',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Configure your app preferences and behavior.\n'
              'Search above or browse by category.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Total Settings: $totalSettings',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...settingsCounts.entries
                        .where((entry) => entry.value > 0)
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getCategoryIcon(entry.key),
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(entry.key.displayName),
                                  ],
                                ),
                                Text(
                                  entry.value.toString(),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Add feedback section
            FeedbackUIHelper.buildFeedbackSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsWidget() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text('No settings found', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search terms or browse by category.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTab(SettingCategory category) {
    final settings = _categorizedSettings[category] ?? [];

    if (settings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getCategoryIcon(category),
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No ${category.displayName.toLowerCase()}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Settings in this category will appear here when configured.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return _buildSettingsList(settings, showCategoryHeaders: false);
  }

  Widget _buildSettingsList(
    List<AppSettings> settings, {
    bool showCategoryHeaders = true,
  }) {
    if (showCategoryHeaders) {
      // Group settings by category for display
      final grouped = _groupSettingsByCategory(settings);
      final widgets = <Widget>[];

      for (final category in _categories) {
        final categorySettings = grouped[category] ?? [];
        if (categorySettings.isEmpty) continue;

        widgets.add(
          SettingsCategoryHeader(
            category: category,
            settingsCount: categorySettings.length,
          ),
        );

        for (final setting in categorySettings) {
          widgets.add(
            createSettingWidget(setting, onChanged: _onSettingChanged),
          );
          widgets.add(const Divider(height: 1));
        }
      }

      return ListView(children: widgets);
    } else {
      // Simple list without category headers
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: settings.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          return createSettingWidget(
            settings[index],
            onChanged: _onSettingChanged,
          );
        },
      );
    }
  }

  IconData _getCategoryIcon(SettingCategory category) {
    switch (category) {
      case SettingCategory.audio:
        return Icons.volume_up;
      case SettingCategory.transcription:
        return Icons.transcribe;
      case SettingCategory.summary:
        return Icons.summarize;
      case SettingCategory.ui:
        return Icons.palette;
      case SettingCategory.general:
        return Icons.settings;
      case SettingCategory.security:
        return Icons.security;
      case SettingCategory.storage:
        return Icons.storage;
    }
  }
}
