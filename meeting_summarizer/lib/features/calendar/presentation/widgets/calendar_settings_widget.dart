import 'package:flutter/material.dart';
import '../../../../core/enums/calendar_provider.dart';
import '../../../../core/services/calendar_integration_service.dart';

/// Widget for managing calendar integration settings
class CalendarSettingsWidget extends StatefulWidget {
  final CalendarIntegrationService calendarService;
  final VoidCallback? onSettingsChanged;

  const CalendarSettingsWidget({
    super.key,
    required this.calendarService,
    this.onSettingsChanged,
  });

  @override
  State<CalendarSettingsWidget> createState() => _CalendarSettingsWidgetState();
}

class _CalendarSettingsWidgetState extends State<CalendarSettingsWidget> {
  Map<CalendarProvider, bool> _authStatus = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAuthStatus();
  }

  Future<void> _loadAuthStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final status = widget.calendarService.getAuthenticationStatus();
      setState(() {
        _authStatus = status;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading calendar status: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _configureProvider(CalendarProvider provider) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final config = await _showConfigurationDialog(provider);
      if (config != null) {
        final success = await widget.calendarService.configureProvider(
          provider: provider,
          config: config,
        );

        if (success) {
          await _loadAuthStatus();
          widget.onSettingsChanged?.call();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('${provider.displayName} configured successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to configure ${provider.displayName}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error configuring ${provider.displayName}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _disconnectProvider(CalendarProvider provider) async {
    final confirmed = await _showDisconnectDialog(provider);
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.calendarService.disconnectProvider(provider);
      await _loadAuthStatus();
      widget.onSettingsChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Disconnected from ${provider.displayName}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error disconnecting ${provider.displayName}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _showConfigurationDialog(
    CalendarProvider provider,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controllers = <String, TextEditingController>{};

    // Get configuration requirements
    final requirements = widget.calendarService
        .getAuthenticationStatus(); // This should be a separate method to get config requirements

    // Create controllers for required fields
    switch (provider) {
      case CalendarProvider.googleCalendar:
        controllers['client_id'] = TextEditingController();
        controllers['client_secret'] = TextEditingController();
        break;
      case CalendarProvider.outlookCalendar:
        controllers['client_id'] = TextEditingController();
        controllers['client_secret'] = TextEditingController();
        controllers['tenant_id'] = TextEditingController();
        break;
      case CalendarProvider.appleCalendar:
      case CalendarProvider.deviceCalendar:
        // No configuration required
        return {};
    }

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Configure ${provider.displayName}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: controllers.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: TextFormField(
                  controller: entry.value,
                  decoration: InputDecoration(
                    labelText: _formatFieldLabel(entry.key),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: entry.key.contains('secret') ||
                      entry.key.contains('password'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'This field is required';
                    }
                    return null;
                  },
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final config = <String, dynamic>{};
                for (final entry in controllers.entries) {
                  config[entry.key] = entry.value.text;
                }
                Navigator.of(context).pop(config);
              }
            },
            child: const Text('Configure'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDisconnectDialog(CalendarProvider provider) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Calendar'),
        content: Text(
          'Are you sure you want to disconnect from ${provider.displayName}? '
          'You will need to reconfigure the connection to use this calendar again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  String _formatFieldLabel(String fieldKey) {
    switch (fieldKey) {
      case 'client_id':
        return 'Client ID';
      case 'client_secret':
        return 'Client Secret';
      case 'tenant_id':
        return 'Tenant ID';
      default:
        return fieldKey
            .split('_')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  Widget _buildProviderTile(CalendarProvider provider) {
    final isAuthenticated = _authStatus[provider] ?? false;

    return ListTile(
      leading: Icon(
        _getProviderIcon(provider),
        color: isAuthenticated ? Colors.green : Colors.grey,
      ),
      title: Text(provider.displayName),
      subtitle: Text(
        isAuthenticated ? 'Connected' : 'Not connected',
        style: TextStyle(
          color: isAuthenticated ? Colors.green : Colors.grey,
        ),
      ),
      trailing: isAuthenticated
          ? IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              onPressed: () => _disconnectProvider(provider),
              tooltip: 'Disconnect',
            )
          : IconButton(
              icon: const Icon(Icons.add, color: Colors.blue),
              onPressed: () => _configureProvider(provider),
              tooltip: 'Connect',
            ),
    );
  }

  IconData _getProviderIcon(CalendarProvider provider) {
    switch (provider) {
      case CalendarProvider.googleCalendar:
        return Icons.calendar_today;
      case CalendarProvider.outlookCalendar:
        return Icons.calendar_month;
      case CalendarProvider.appleCalendar:
        return Icons.calendar_view_month;
      case CalendarProvider.deviceCalendar:
        return Icons.smartphone;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today),
                const SizedBox(width: 8),
                Text(
                  'Calendar Integration',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Connect your calendar accounts to enable automatic meeting detection and summary distribution.',
            ),
            const SizedBox(height: 16),
            ...CalendarProvider.values.map(_buildProviderTile),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _loadAuthStatus,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Status'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
