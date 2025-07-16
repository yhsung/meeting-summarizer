/// API Configuration screen for managing transcription service API keys
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/services/api_key_service.dart';
import '../../../../core/services/transcription_provider_service.dart';
import '../../../../core/services/transcription_service_factory.dart';
import '../../../../core/services/local_whisper_service.dart';
import '../../../transcription/presentation/widgets/model_download_progress.dart';

/// Screen for configuring API keys for transcription services
class ApiConfigurationScreen extends StatefulWidget {
  const ApiConfigurationScreen({super.key});

  @override
  State<ApiConfigurationScreen> createState() => _ApiConfigurationScreenState();
}

class _ApiConfigurationScreenState extends State<ApiConfigurationScreen> {
  final ApiKeyService _apiKeyService = ApiKeyService();
  final TranscriptionProviderService _providerService =
      TranscriptionProviderService();
  final LocalWhisperService _localWhisperService =
      LocalWhisperService.getInstance();

  // Controllers for text inputs
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _isObscured = {};
  final Map<String, bool> _isLoading = {};

  // State
  List<ApiKeyInfo> _apiKeyInfos = [];
  bool _isLoadingInitial = true;
  TranscriptionProvider _selectedProvider = TranscriptionProvider.openaiWhisper;
  Map<TranscriptionProvider, bool> _providerAvailability = {};
  bool _forceLocalWhisperOverride = false;

  // Local Whisper initialization state
  bool _isWhisperInitializing = false;
  bool _isWhisperInitialized = false;
  double _whisperInitProgress = 0.0;
  String _whisperInitStatus = 'Not initialized';
  String? _whisperInitError;

  // Supported providers
  final List<String> _supportedProviders = [
    'openai',
    'anthropic',
    'google',
    'azure',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadApiKeyInfo();
    _initializeLocalWhisper();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllers() {
    for (final provider in _supportedProviders) {
      _controllers[provider] = TextEditingController();
      _isObscured[provider] = true;
      _isLoading[provider] = false;
    }
  }

  Future<void> _loadApiKeyInfo() async {
    setState(() {
      _isLoadingInitial = true;
    });

    try {
      final infos = await _apiKeyService.getAllApiKeyInfo();
      final selectedProvider = await _providerService.getSelectedProvider();
      final providerAvailability = await _providerService
          .getAvailableProviders();
      final forceLocalWhisperOverride = await _providerService
          .getForceLocalWhisperOverride();

      setState(() {
        _apiKeyInfos = infos;
        _selectedProvider = selectedProvider;
        _providerAvailability = providerAvailability;
        _forceLocalWhisperOverride = forceLocalWhisperOverride;
        _isLoadingInitial = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingInitial = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load API key information: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateProviderAvailability() async {
    try {
      final providerAvailability = await _providerService
          .getAvailableProviders();
      debugPrint('Updated provider availability: $providerAvailability');
      setState(() {
        _providerAvailability = providerAvailability;
      });
    } catch (e) {
      debugPrint('Failed to update provider availability: $e');
    }
  }

  Future<void> _initializeLocalWhisper() async {
    debugPrint('Settings: Checking if LocalWhisperService is available...');

    // Check if already initialized
    if (await _localWhisperService.isServiceAvailable()) {
      debugPrint('Settings: LocalWhisperService is already available');
      setState(() {
        _isWhisperInitialized = true;
        _whisperInitStatus = 'Service ready';
        _whisperInitProgress = 1.0;
      });
      await _updateProviderAvailability();
      return;
    }

    debugPrint('Settings: LocalWhisperService not available, initializing...');

    setState(() {
      _isWhisperInitializing = true;
      _whisperInitError = null;
      _whisperInitProgress = 0.0;
      _whisperInitStatus = 'Initializing...';
    });

    try {
      await _localWhisperService.initialize(
        onProgress: (progress, status) {
          setState(() {
            _whisperInitProgress = progress;
            _whisperInitStatus = status;
          });
        },
      );

      setState(() {
        _isWhisperInitializing = false;
        _isWhisperInitialized = true;
        _whisperInitStatus = 'Service ready';
        _whisperInitProgress = 1.0;
      });

      // Update provider availability after successful initialization
      await _updateProviderAvailability();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Local Whisper service initialized successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isWhisperInitializing = false;
        _isWhisperInitialized = false;
        _whisperInitError = e.toString();
        _whisperInitStatus = 'Initialization failed';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize Local Whisper: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveApiKey(String provider) async {
    final controller = _controllers[provider];
    if (controller == null) return;

    final apiKey = controller.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an API key'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading[provider] = true;
    });

    try {
      // Validate format first
      if (!_apiKeyService.validateApiKeyFormat(provider, apiKey)) {
        throw Exception('Invalid API key format for $provider');
      }

      // Save the API key
      await _apiKeyService.setApiKey(provider, apiKey);

      // Test the API key
      final isValid = await _apiKeyService.testApiKey(provider, apiKey);
      if (!isValid) {
        throw Exception('API key test failed');
      }

      // Clear the input
      controller.clear();

      // Reload info
      await _loadApiKeyInfo();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'API key saved successfully for ${_getProviderDisplayName(provider)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save API key: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading[provider] = false;
      });
    }
  }

  Future<void> _removeApiKey(String provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove API Key'),
        content: Text(
          'Are you sure you want to remove the API key for ${_getProviderDisplayName(provider)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiKeyService.removeApiKey(provider);
        await _loadApiKeyInfo();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'API key removed for ${_getProviderDisplayName(provider)}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove API key: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _getProviderDisplayName(String provider) {
    switch (provider.toLowerCase()) {
      case 'openai':
        return 'OpenAI';
      case 'anthropic':
        return 'Anthropic';
      case 'google':
        return 'Google';
      case 'azure':
        return 'Azure';
      default:
        return provider.toUpperCase();
    }
  }

  String _getProviderDescription(String provider) {
    switch (provider.toLowerCase()) {
      case 'openai':
        return 'Required for OpenAI Whisper transcription service';
      case 'anthropic':
        return 'Required for Anthropic Claude summarization';
      case 'google':
        return 'Required for Google Speech-to-Text';
      case 'azure':
        return 'Required for Azure Cognitive Services';
      default:
        return 'API key for $provider services';
    }
  }

  String _getProviderInstructions(String provider) {
    switch (provider.toLowerCase()) {
      case 'openai':
        return 'Get your API key from https://platform.openai.com/api-keys\nFormat: sk-...';
      case 'anthropic':
        return 'Get your API key from https://console.anthropic.com/\nFormat: sk-ant-...';
      case 'google':
        return 'Get your API key from Google Cloud Console\nEnable Speech-to-Text API';
      case 'azure':
        return 'Get your API key from Azure Portal\nCognitive Services resource';
      default:
        return 'Check the provider documentation for API key format';
    }
  }

  ApiKeyInfo _getApiKeyInfo(String provider) {
    try {
      return _apiKeyInfos.firstWhere((info) => info.provider == provider);
    } catch (e) {
      return ApiKeyInfo(
        provider: provider,
        isConfigured: false,
        isValidFormat: false,
        keyLength: 0,
        keyPrefix: '',
        lastUpdated: DateTime.now(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('API Configuration'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: _isLoadingInitial
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'API Configuration',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Configure API keys for transcription and summarization services. '
                          'These keys are stored securely on your device using the system keychain when available, '
                          'or encrypted local storage as a fallback.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildForceLocalWhisperCard(),
                const SizedBox(height: 16),
                _buildLocalWhisperInitializationCard(),
                const SizedBox(height: 16),
                _buildProviderSelectionCard(),
                const SizedBox(height: 16),
                ..._supportedProviders.map(
                  (provider) => _buildProviderCard(provider),
                ),
              ],
            ),
    );
  }

  Widget _buildForceLocalWhisperCard() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.offline_bolt, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Force Local Processing',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'When enabled, all transcriptions will use Local Whisper processing regardless of your selected provider. '
              'This ensures complete offline operation and privacy.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Force Local Whisper'),
              subtitle: Text(
                _forceLocalWhisperOverride
                    ? 'All transcriptions will use Local Whisper (offline)'
                    : 'Normal provider selection will be used',
              ),
              value: _forceLocalWhisperOverride,
              onChanged: _toggleForceLocalWhisper,
              secondary: Icon(
                _forceLocalWhisperOverride ? Icons.security : Icons.cloud_off,
                color: _forceLocalWhisperOverride ? Colors.green : Colors.grey,
              ),
            ),
            if (_forceLocalWhisperOverride) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Override active: Local Whisper will be used for all transcriptions',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleForceLocalWhisper(bool value) async {
    try {
      await _providerService.setForceLocalWhisperOverride(value);
      setState(() {
        _forceLocalWhisperOverride = value;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Force Local Whisper enabled - all transcriptions will use offline processing'
                  : 'Force Local Whisper disabled - normal provider selection restored',
            ),
            backgroundColor: value ? Colors.green : Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update setting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildLocalWhisperInitializationCard() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isWhisperInitialized
                      ? Icons.check_circle
                      : _isWhisperInitializing
                      ? Icons.hourglass_empty
                      : Icons.download,
                  color: _isWhisperInitialized
                      ? Colors.green
                      : _isWhisperInitializing
                      ? Colors.orange
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Local Whisper Service',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Local Whisper provides offline speech-to-text processing. '
              'This service downloads and initializes the necessary models for local transcription.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Status and progress display
            if (_isWhisperInitializing) ...[
              ModelDownloadProgress(
                progress: _whisperInitProgress,
                status: _whisperInitStatus,
                modelName: 'Whisper Base',
                isDownloading: _isWhisperInitializing,
              ),
            ] else if (_isWhisperInitialized) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Service Ready',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Local Whisper is initialized and ready for offline transcription',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_whisperInitError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Initialization Failed',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _whisperInitError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        await _initializeLocalWhisper();
                      },
                      child: const Text('Retry Initialization'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Not Initialized',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Click below to initialize the Local Whisper service and download the required model.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        await _initializeLocalWhisper();
                      },
                      child: const Text('Initialize Service'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProviderSelectionCard() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Transcription Provider',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Select your preferred transcription service provider. The selected provider will be used for all transcription tasks.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ...TranscriptionProvider.values.map(
              (provider) => _buildProviderOption(provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderOption(TranscriptionProvider provider) {
    final theme = Theme.of(context);
    final displayName = TranscriptionServiceFactory.getProviderDisplayName(
      provider,
    );
    final description = TranscriptionServiceFactory.getProviderDescription(
      provider,
    );
    final capabilities = TranscriptionServiceFactory.getServiceCapabilities(
      provider,
    );
    final requirements = TranscriptionProviderService.getProviderRequirements(
      provider,
    );
    final isAvailable = _providerAvailability[provider] ?? false;
    final isSelected = _selectedProvider == provider;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.1)
          : null,
      child: RadioListTile<TranscriptionProvider>(
        title: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            _buildProviderStatusBadge(isAvailable),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(description, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildFeatureChip(
                  '${capabilities.supportedLanguages}+ languages',
                  Icons.language,
                  theme,
                ),
                _buildFeatureChip(
                  capabilities.costPerMinute == 0
                      ? 'Free'
                      : '\$${capabilities.costPerMinute.toStringAsFixed(3)}/min',
                  capabilities.costPerMinute == 0
                      ? Icons.free_breakfast
                      : Icons.attach_money,
                  theme,
                ),
                _buildFeatureChip(
                  requirements['internet_required'] ? 'Online' : 'Offline',
                  requirements['internet_required']
                      ? Icons.cloud
                      : Icons.offline_bolt,
                  theme,
                ),
              ],
            ),
          ],
        ),
        value: provider,
        groupValue: _selectedProvider,
        onChanged: isAvailable
            ? (TranscriptionProvider? value) {
                if (value != null) {
                  _selectProvider(value);
                }
              }
            : null,
      ),
    );
  }

  Widget _buildProviderStatusBadge(bool isAvailable) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAvailable
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAvailable ? Icons.check_circle : Icons.error,
            size: 12,
            color: isAvailable ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            isAvailable ? 'Available' : 'Setup Required',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isAvailable ? Colors.green : Colors.red,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String label, IconData icon, ThemeData theme) {
    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 14), const SizedBox(width: 4), Text(label)],
      ),
      labelStyle: theme.textTheme.bodySmall,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _selectProvider(TranscriptionProvider provider) async {
    try {
      await _providerService.setSelectedProvider(provider);
      setState(() {
        _selectedProvider = provider;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Selected ${TranscriptionServiceFactory.getProviderDisplayName(provider)} as transcription provider',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select provider: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildProviderCard(String provider) {
    final theme = Theme.of(context);
    final controller = _controllers[provider]!;
    final isObscured = _isObscured[provider]!;
    final isLoading = _isLoading[provider]!;
    final apiKeyInfo = _getApiKeyInfo(provider);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getProviderDisplayName(provider),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getProviderDescription(provider),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _buildStatusIndicator(apiKeyInfo),
              ],
            ),
            const SizedBox(height: 16),
            if (apiKeyInfo.isConfigured) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Configured: ${apiKeyInfo.keyPrefix}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _removeApiKey(provider),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            ExpansionTile(
              title: Text(
                apiKeyInfo.isConfigured ? 'Update API Key' : 'Set API Key',
                style: theme.textTheme.titleSmall,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getProviderInstructions(provider),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: controller,
                        obscureText: isObscured,
                        decoration: InputDecoration(
                          labelText: 'API Key',
                          hintText:
                              'Enter your ${_getProviderDisplayName(provider)} API key',
                          border: const OutlineInputBorder(),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isObscured
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isObscured[provider] = !isObscured;
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.content_paste),
                                onPressed: () async {
                                  final clipboardData = await Clipboard.getData(
                                    Clipboard.kTextPlain,
                                  );
                                  if (clipboardData?.text != null) {
                                    controller.text = clipboardData!.text!;
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Spacer(),
                          TextButton(
                            onPressed: () => controller.clear(),
                            child: const Text('Clear'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () => _saveApiKey(provider),
                            child: isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(ApiKeyInfo info) {
    final theme = Theme.of(context);

    Color indicatorColor;
    IconData indicatorIcon;
    String statusText;

    if (info.isConfigured) {
      if (info.isValidFormat) {
        indicatorColor = Colors.green;
        indicatorIcon = Icons.check_circle;
        statusText = 'Configured';
      } else {
        indicatorColor = Colors.orange;
        indicatorIcon = Icons.warning;
        statusText = 'Invalid Format';
      }
    } else {
      indicatorColor = Colors.red;
      indicatorIcon = Icons.error;
      statusText = 'Not Configured';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: indicatorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(indicatorIcon, size: 16, color: indicatorColor),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: indicatorColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
