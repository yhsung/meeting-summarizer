import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/services/onboarding_service.dart';

/// Widget for handling permission setup during onboarding
class PermissionSetupWidget extends StatefulWidget {
  const PermissionSetupWidget({super.key});

  @override
  State<PermissionSetupWidget> createState() => _PermissionSetupWidgetState();
}

class _PermissionSetupWidgetState extends State<PermissionSetupWidget> {
  final OnboardingService _onboardingService = OnboardingService.instance;

  Map<Permission, PermissionStatus> _permissionStatuses = {};
  bool _isLoading = false;

  final List<PermissionInfo> _requiredPermissions = [
    PermissionInfo(
      permission: Permission.microphone,
      title: "Microphone Access",
      description: "Required for recording meetings and audio",
      icon: Icons.mic,
      isRequired: true,
    ),
    PermissionInfo(
      permission: Permission.storage,
      title: "Storage Access",
      description: "Needed to save recordings and transcriptions",
      icon: Icons.folder,
      isRequired: true,
    ),
    PermissionInfo(
      permission: Permission.notification,
      title: "Notifications",
      description: "Get updates on transcription and sync progress",
      icon: Icons.notifications,
      isRequired: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ..._requiredPermissions.map(
          (permissionInfo) => _buildPermissionItem(permissionInfo),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _requestAllPermissions,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Grant Permissions'),
          ),
        ),
        const SizedBox(height: 12),
        if (_allRequiredPermissionsGranted())
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
                    'All required permissions granted!',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'You can manage these permissions later in your device settings.',
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

  Widget _buildPermissionItem(PermissionInfo permissionInfo) {
    final status = _permissionStatuses[permissionInfo.permission];
    final isGranted = status == PermissionStatus.granted;
    final isDenied = status == PermissionStatus.denied;
    final isPermanentlyDenied = status == PermissionStatus.permanentlyDenied;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isGranted) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Granted';
    } else if (isPermanentlyDenied) {
      statusColor = Colors.red;
      statusIcon = Icons.block;
      statusText = 'Denied';
    } else if (isDenied) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'Required';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.help_outline;
      statusText = 'Unknown';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: isGranted
              ? Colors.green.withOpacity(0.3)
              : Theme.of(context).dividerColor,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isGranted ? Colors.green.withOpacity(0.05) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              permissionInfo.icon,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      permissionInfo.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (permissionInfo.isRequired) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  permissionInfo.description,
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
          Column(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(height: 2),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);

    try {
      final statuses = <Permission, PermissionStatus>{};

      for (final permissionInfo in _requiredPermissions) {
        statuses[permissionInfo.permission] =
            await permissionInfo.permission.status;
      }

      setState(() {
        _permissionStatuses = statuses;
      });

      // Update onboarding service if all required permissions are granted
      if (_allRequiredPermissionsGranted()) {
        await _onboardingService.markPermissionsGranted();
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestAllPermissions() async {
    setState(() => _isLoading = true);

    try {
      final permissions = _requiredPermissions
          .map((p) => p.permission)
          .toList();
      final statuses = await permissions.request();

      setState(() {
        _permissionStatuses = statuses;
      });

      // Check for permanently denied permissions
      final permanentlyDenied = statuses.entries
          .where((entry) => entry.value == PermissionStatus.permanentlyDenied)
          .toList();

      if (permanentlyDenied.isNotEmpty && mounted) {
        _showPermissionDeniedDialog(permanentlyDenied);
      }

      // Update onboarding service
      if (_allRequiredPermissionsGranted()) {
        await _onboardingService.markPermissionsGranted();
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _allRequiredPermissionsGranted() {
    final requiredPerms = _requiredPermissions
        .where((p) => p.isRequired)
        .map((p) => p.permission);

    return requiredPerms.every(
      (permission) =>
          _permissionStatuses[permission] == PermissionStatus.granted,
    );
  }

  void _showPermissionDeniedDialog(
    List<MapEntry<Permission, PermissionStatus>> deniedPermissions,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Some permissions were denied. To use all features of the app, you can grant them in your device settings.',
            ),
            const SizedBox(height: 16),
            ...deniedPermissions.map((entry) {
              final permissionInfo = _requiredPermissions.firstWhere(
                (p) => p.permission == entry.key,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(permissionInfo.icon, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(permissionInfo.title)),
                  ],
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

/// Information about a permission needed for the app
class PermissionInfo {
  final Permission permission;
  final String title;
  final String description;
  final IconData icon;
  final bool isRequired;

  const PermissionInfo({
    required this.permission,
    required this.title,
    required this.description,
    required this.icon,
    required this.isRequired,
  });
}
