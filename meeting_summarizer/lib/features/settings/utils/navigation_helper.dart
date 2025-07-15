/// Navigation helper for API configuration
library;

import 'package:flutter/material.dart';
import '../presentation/screens/api_configuration_screen.dart';

/// Helper class for API configuration navigation
class ApiConfigurationNavigation {
  /// Navigate to API configuration screen
  static Future<void> navigateToApiConfig(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const ApiConfigurationScreen(),
      ),
    );
  }

  /// Show API configuration dialog
  static Future<void> showApiConfigDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(child: const ApiConfigurationScreen()),
    );
  }

  /// Show API key required snackbar with action to open settings
  static void showApiKeyRequiredSnackBar(
    BuildContext context,
    String provider,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$provider API key required for transcription'),
        action: SnackBarAction(
          label: 'Configure',
          onPressed: () => navigateToApiConfig(context),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
