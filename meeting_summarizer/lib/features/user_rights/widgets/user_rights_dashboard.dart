/// User rights dashboard for displaying access permissions and history
library;

import 'package:flutter/material.dart';
import '../../../core/models/user_rights/user_profile.dart';
import '../../../core/models/user_rights/access_audit_log.dart';
import '../../../core/models/user_rights/access_permission.dart';
import '../../../core/models/user_rights/rights_delegation.dart';
import '../../../core/enums/user_rights_enums.dart';
import '../../../core/services/enhanced_user_rights_service.dart';

/// Dashboard widget for displaying user rights information and access history
class UserRightsDashboard extends StatefulWidget {
  final String userId;

  const UserRightsDashboard({super.key, required this.userId});

  @override
  State<UserRightsDashboard> createState() => _UserRightsDashboardState();
}

class _UserRightsDashboardState extends State<UserRightsDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final EnhancedUserRightsService _userRightsService =
      EnhancedUserRightsService.instance;

  UserProfile? _userProfile;
  List<AccessPermission> _permissions = [];
  List<AccessAuditLog> _auditLogs = [];
  List<RightsDelegation> _delegationsFrom = [];
  List<RightsDelegation> _delegationsTo = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserRightsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRightsData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final futures = await Future.wait([
        _userRightsService.getUserProfile(widget.userId),
        _userRightsService.getUserPermissions(widget.userId),
        _userRightsService.getUserAccessHistory(widget.userId, limit: 100),
        _userRightsService.getDelegationsFromUser(widget.userId),
        _userRightsService.getDelegationsToUser(widget.userId),
      ]);

      setState(() {
        _userProfile = futures[0] as UserProfile?;
        _permissions = futures[1] as List<AccessPermission>;
        _auditLogs = futures[2] as List<AccessAuditLog>;
        _delegationsFrom = futures[3] as List<RightsDelegation>;
        _delegationsTo = futures[4] as List<RightsDelegation>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load user rights data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Rights Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Profile'),
            Tab(icon: Icon(Icons.security), text: 'Permissions'),
            Tab(icon: Icon(Icons.history), text: 'Access History'),
            Tab(icon: Icon(Icons.swap_horiz), text: 'Delegations'),
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
                _buildProfileTab(),
                _buildPermissionsTab(),
                _buildAccessHistoryTab(),
                _buildDelegationsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadUserRightsData,
        child: const Icon(Icons.refresh),
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
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Data',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error occurred',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadUserRightsData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    if (_userProfile == null) {
      return const Center(child: Text('User profile not found'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileInfoCard(),
          const SizedBox(height: 16),
          _buildAccountStatusCard(),
          const SizedBox(height: 16),
          _buildRolesCard(),
          if (_userProfile!.hasGuardians) ...[
            const SizedBox(height: 16),
            _buildGuardiansCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile Information',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Display Name', _userProfile!.displayName),
            _buildInfoRow('Email', _userProfile!.email),
            if (_userProfile!.fullName != _userProfile!.displayName)
              _buildInfoRow('Full Name', _userProfile!.fullName),
            if (_userProfile!.phoneNumber != null)
              _buildInfoRow('Phone', _userProfile!.phoneNumber!),
            _buildInfoRow('Member Since', _formatDate(_userProfile!.createdAt)),
            _buildInfoRow('Last Updated', _formatDate(_userProfile!.updatedAt)),
            if (_userProfile!.lastLoginAt != null)
              _buildInfoRow(
                'Last Login',
                _formatDate(_userProfile!.lastLoginAt!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountStatusCard() {
    final status = _userProfile!.status;
    final statusColor = _getStatusColor(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account Status',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  status.displayName,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (_userProfile!.isMinor) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.child_care, size: 16),
                  SizedBox(width: 8),
                  Text('Minor Account'),
                ],
              ),
            ],
            if (_userProfile!.requiresParentalConsent) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.family_restroom, size: 16),
                  SizedBox(width: 8),
                  Text('Requires Parental Consent'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRolesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assigned Roles',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (_userProfile!.roleIds.isEmpty)
              const Text('No roles assigned')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _userProfile!.roleIds
                    .map((roleId) => Chip(label: Text(roleId)))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuardiansCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Guardians', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            ...(_userProfile!.guardianIds.map(
              (guardianId) => ListTile(
                leading: const Icon(Icons.supervisor_account),
                title: Text('Guardian: $guardianId'),
                subtitle: const Text('Active'),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsTab() {
    return RefreshIndicator(
      onRefresh: _loadUserRightsData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _permissions.length,
        itemBuilder: (context, index) {
          final permission = _permissions[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                _getPermissionIcon(permission.resource),
                color: permission.isValid ? Colors.green : Colors.grey,
              ),
              title: Text(permission.resource),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Actions: ${permission.actions.map((a) => a.displayName).join(', ')}',
                  ),
                  if (permission.reason != null)
                    Text(
                      'Reason: ${permission.reason}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  Text(
                    'Granted: ${_formatDate(permission.grantedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (permission.expiresAt != null)
                    Text(
                      'Expires: ${_formatDate(permission.expiresAt!)}',
                      style: TextStyle(
                        color: permission.isExpired ? Colors.red : null,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              trailing: Icon(
                permission.isValid ? Icons.check_circle : Icons.cancel,
                color: permission.isValid ? Colors.green : Colors.red,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccessHistoryTab() {
    return RefreshIndicator(
      onRefresh: _loadUserRightsData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _auditLogs.length,
        itemBuilder: (context, index) {
          final log = _auditLogs[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                _getAuditActionIcon(log.action),
                color: log.success ? Colors.green : Colors.red,
              ),
              title: Text(log.action.displayName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resource: ${log.resource}'),
                  Text(log.description),
                  Text(
                    _formatDate(log.timestamp),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (log.ipAddress != null)
                    Text(
                      'IP: ${log.ipAddress}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              trailing: Chip(
                label: Text(
                  log.riskLevel.toUpperCase(),
                  style: const TextStyle(fontSize: 10),
                ),
                backgroundColor: _getRiskLevelColor(log.riskLevel),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDelegationsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Delegated By Me'),
              Tab(text: 'Delegated To Me'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDelegationsList(
                  _delegationsFrom,
                  isDelegatedByUser: true,
                ),
                _buildDelegationsList(_delegationsTo, isDelegatedByUser: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDelegationsList(
    List<RightsDelegation> delegations, {
    required bool isDelegatedByUser,
  }) {
    return RefreshIndicator(
      onRefresh: _loadUserRightsData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: delegations.length,
        itemBuilder: (context, index) {
          final delegation = delegations[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                delegation.isActive ? Icons.swap_horiz : Icons.block,
                color: delegation.isActive ? Colors.blue : Colors.grey,
              ),
              title: Text(
                isDelegatedByUser
                    ? 'To: ${delegation.toUserId}'
                    : 'From: ${delegation.fromUserId}',
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rights: ${delegation.delegatedRights.join(', ')}'),
                  Text(
                    'Status: ${delegation.status.displayName}',
                    style: TextStyle(
                      color: _getDelegationStatusColor(delegation.status),
                    ),
                  ),
                  Text(
                    'Expires: ${_formatDate(delegation.expiresAt)}',
                    style: TextStyle(
                      color: delegation.isExpired ? Colors.red : null,
                      fontSize: 12,
                    ),
                  ),
                  if (delegation.reason != null)
                    Text(
                      'Reason: ${delegation.reason}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(UserAccountStatus status) {
    switch (status) {
      case UserAccountStatus.active:
        return Colors.green;
      case UserAccountStatus.inactive:
        return Colors.orange;
      case UserAccountStatus.suspended:
        return Colors.red;
      case UserAccountStatus.blocked:
        return Colors.red;
      case UserAccountStatus.pending:
        return Colors.blue;
      case UserAccountStatus.deleted:
        return Colors.grey;
    }
  }

  IconData _getPermissionIcon(String resource) {
    switch (resource.toLowerCase()) {
      case 'personal_data':
        return Icons.person;
      case 'recordings':
        return Icons.mic;
      case 'summaries':
        return Icons.description;
      case 'settings':
        return Icons.settings;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.security;
    }
  }

  IconData _getAuditActionIcon(AccessAuditAction action) {
    switch (action) {
      case AccessAuditAction.login:
        return Icons.login;
      case AccessAuditAction.logout:
        return Icons.logout;
      case AccessAuditAction.dataAccess:
        return Icons.visibility;
      case AccessAuditAction.dataModification:
        return Icons.edit;
      case AccessAuditAction.permissionGranted:
        return Icons.add_circle;
      case AccessAuditAction.permissionRevoked:
        return Icons.remove_circle;
      case AccessAuditAction.adminAction:
        return Icons.admin_panel_settings;
      default:
        return Icons.info;
    }
  }

  Color _getRiskLevelColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'high':
      case 'critical':
        return Colors.red.withValues(alpha: 0.2);
      case 'medium':
      case 'warning':
        return Colors.orange.withValues(alpha: 0.2);
      case 'low':
      case 'info':
        return Colors.green.withValues(alpha: 0.2);
      default:
        return Colors.grey.withValues(alpha: 0.2);
    }
  }

  Color _getDelegationStatusColor(DelegationStatus status) {
    switch (status) {
      case DelegationStatus.active:
        return Colors.green;
      case DelegationStatus.expired:
        return Colors.orange;
      case DelegationStatus.revoked:
        return Colors.red;
      case DelegationStatus.suspended:
        return Colors.orange;
    }
  }
}
