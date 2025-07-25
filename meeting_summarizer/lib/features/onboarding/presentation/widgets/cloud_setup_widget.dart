import 'package:flutter/material.dart';

import '../../data/services/onboarding_service.dart';

/// Widget for setting up cloud storage during onboarding
class CloudSetupWidget extends StatefulWidget {
  const CloudSetupWidget({super.key});

  @override
  State<CloudSetupWidget> createState() => _CloudSetupWidgetState();
}

class _CloudSetupWidgetState extends State<CloudSetupWidget> {
  final OnboardingService _onboardingService = OnboardingService.instance;

  String? _selectedProvider;
  bool _isConnecting = false;
  bool _isConnected = false;

  final List<CloudProvider> _cloudProviders = [
    CloudProvider(
      id: 'icloud',
      name: 'iCloud',
      description: 'Apple\'s cloud storage service',
      icon: Icons.cloud,
      color: Colors.blue,
      isAvailable: true,
    ),
    CloudProvider(
      id: 'google_drive',
      name: 'Google Drive',
      description: 'Google\'s cloud storage and file sharing',
      icon: Icons.storage,
      color: Colors.green,
      isAvailable: true,
    ),
    CloudProvider(
      id: 'onedrive',
      name: 'OneDrive',
      description: 'Microsoft\'s cloud storage service',
      icon: Icons.cloud_circle,
      color: Colors.indigo,
      isAvailable: true,
    ),
    CloudProvider(
      id: 'dropbox',
      name: 'Dropbox',
      description: 'Popular cloud storage and collaboration',
      icon: Icons.folder_shared,
      color: Colors.deepPurple,
      isAvailable: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ..._cloudProviders.map((provider) => _buildCloudProviderItem(provider)),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _skipCloudSetup,
                child: const Text('Skip for Now'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _selectedProvider != null && !_isConnecting
                    ? _connectToCloud
                    : null,
                child: _isConnecting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Connect'),
              ),
            ),
          ],
        ),
        if (_isConnected) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cloud storage connected successfully!',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Cloud storage is optional but recommended for backup and cross-device sync.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).textTheme.bodySmall?.color?.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCloudProviderItem(CloudProvider provider) {
    final isSelected = _selectedProvider == provider.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: provider.isAvailable
            ? () => setState(() => _selectedProvider = provider.id)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? provider.color.withOpacity(0.5)
                  : Theme.of(context).dividerColor,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? provider.color.withOpacity(0.05) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: provider.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(provider.icon, color: provider.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.description,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (!provider.isAvailable)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Coming Soon',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else if (isSelected)
                Icon(Icons.check_circle, color: provider.color, size: 24)
              else
                Icon(
                  Icons.radio_button_unchecked,
                  color: Theme.of(context).dividerColor,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _connectToCloud() async {
    if (_selectedProvider == null) return;

    setState(() => _isConnecting = true);

    try {
      // Simulate cloud connection process
      await Future.delayed(const Duration(seconds: 2));

      // In a real implementation, this would integrate with the actual cloud providers
      final selectedProvider = _cloudProviders.firstWhere(
        (p) => p.id == _selectedProvider,
      );

      // Show connection dialog or handle authentication
      final connected = await _showCloudConnectionDialog(selectedProvider);

      if (connected) {
        setState(() => _isConnected = true);
        await _onboardingService.markCloudSetupComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to cloud storage: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  Future<bool> _showCloudConnectionDialog(CloudProvider provider) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Connect to ${provider.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(provider.icon, size: 64, color: provider.color),
                const SizedBox(height: 16),
                Text(
                  'This will open ${provider.name} authentication in your browser. '
                  'After signing in, you\'ll be able to sync your meeting data securely.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _skipCloudSetup() async {
    final shouldSkip = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Cloud Setup?'),
        content: const Text(
          'You can set up cloud storage later in Settings. Your recordings will be stored locally until then.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Go Back'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Skip'),
          ),
        ],
      ),
    );

    if (shouldSkip == true) {
      await _onboardingService.markCloudSetupComplete();
    }
  }
}

/// Information about a cloud storage provider
class CloudProvider {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool isAvailable;

  const CloudProvider({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.isAvailable,
  });
}
