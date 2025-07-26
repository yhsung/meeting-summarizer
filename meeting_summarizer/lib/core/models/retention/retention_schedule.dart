/// Retention schedule model for upcoming data lifecycle events
library;

import 'retention_policy.dart';

/// Represents a scheduled retention operation
class RetentionSchedule {
  /// Start date of the schedule period
  final DateTime startDate;

  /// End date of the schedule period
  final DateTime endDate;

  /// List of scheduled retention actions
  final List<ScheduledRetentionAction> scheduledActions;

  const RetentionSchedule({
    required this.startDate,
    required this.endDate,
    required this.scheduledActions,
  });

  /// Get total number of scheduled actions
  int get totalActions => scheduledActions.length;

  /// Get actions scheduled for a specific date
  List<ScheduledRetentionAction> getActionsForDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);

    return scheduledActions.where((action) {
      final actionDate = DateTime(
        action.scheduledDate.year,
        action.scheduledDate.month,
        action.scheduledDate.day,
      );
      return actionDate.isAtSameMomentAs(targetDate);
    }).toList();
  }

  /// Get actions scheduled for today
  List<ScheduledRetentionAction> get todaysActions =>
      getActionsForDate(DateTime.now());

  /// Get actions scheduled for tomorrow
  List<ScheduledRetentionAction> get tomorrowsActions {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return getActionsForDate(tomorrow);
  }

  /// Get actions scheduled for next 7 days
  List<ScheduledRetentionAction> get nextWeekActions {
    final nextWeek = DateTime.now().add(const Duration(days: 7));
    return scheduledActions
        .where(
          (action) =>
              action.scheduledDate.isBefore(nextWeek) &&
              action.scheduledDate.isAfter(DateTime.now()),
        )
        .toList();
  }

  /// Get overdue actions
  List<ScheduledRetentionAction> get overdueActions {
    final now = DateTime.now();
    return scheduledActions
        .where((action) => action.scheduledDate.isBefore(now))
        .toList();
  }

  /// Get actions grouped by date
  Map<DateTime, List<ScheduledRetentionAction>> get actionsByDate {
    final grouped = <DateTime, List<ScheduledRetentionAction>>{};

    for (final action in scheduledActions) {
      final date = DateTime(
        action.scheduledDate.year,
        action.scheduledDate.month,
        action.scheduledDate.day,
      );

      grouped.putIfAbsent(date, () => []).add(action);
    }

    return grouped;
  }

  /// Get summary statistics
  RetentionScheduleSummary get summary {
    final actionCounts = <RetentionActionType, int>{};
    final policyCounts = <String, int>{};

    for (final action in scheduledActions) {
      final actionType = action.item.action;
      actionCounts[actionType] = (actionCounts[actionType] ?? 0) + 1;

      final policyId = action.policy.id;
      policyCounts[policyId] = (policyCounts[policyId] ?? 0) + 1;
    }

    return RetentionScheduleSummary(
      totalActions: totalActions,
      todaysActionCount: todaysActions.length,
      nextWeekActionCount: nextWeekActions.length,
      overdueActionCount: overdueActions.length,
      actionsByType: actionCounts,
      actionsByPolicy: policyCounts,
    );
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'totalActions': totalActions,
      'scheduledActions':
          scheduledActions.map((action) => action.toJson()).toList(),
      'summary': summary.toJson(),
    };
  }

  /// Create from JSON representation
  factory RetentionSchedule.fromJson(Map<String, dynamic> json) {
    return RetentionSchedule(
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      scheduledActions: (json['scheduledActions'] as List)
          .map(
            (actionJson) => ScheduledRetentionAction.fromJson(
              actionJson as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  @override
  String toString() {
    return 'RetentionSchedule(period: ${startDate.toLocal()} to ${endDate.toLocal()}, '
        'actions: $totalActions)';
  }
}

/// Represents a scheduled retention action
class ScheduledRetentionAction {
  /// When the action is scheduled to execute
  final DateTime scheduledDate;

  /// The data item to be processed
  final DataRetentionItem item;

  /// The retention policy that triggered this action
  final RetentionPolicy policy;

  /// Optional priority level
  final ScheduledActionPriority priority;

  /// Whether the action has been executed
  final bool isExecuted;

  /// When the action was actually executed
  final DateTime? executedAt;

  /// Execution result if available
  final String? executionResult;

  const ScheduledRetentionAction({
    required this.scheduledDate,
    required this.item,
    required this.policy,
    this.priority = ScheduledActionPriority.normal,
    this.isExecuted = false,
    this.executedAt,
    this.executionResult,
  });

  /// Check if this action is overdue
  bool get isOverdue => DateTime.now().isAfter(scheduledDate) && !isExecuted;

  /// Get days until execution
  int get daysUntilExecution {
    final diff = scheduledDate.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Get hours until execution
  int get hoursUntilExecution {
    final diff = scheduledDate.difference(DateTime.now()).inHours;
    return diff > 0 ? diff : 0;
  }

  /// Create copy with execution details
  ScheduledRetentionAction copyWithExecution({
    bool? isExecuted,
    DateTime? executedAt,
    String? executionResult,
  }) {
    return ScheduledRetentionAction(
      scheduledDate: scheduledDate,
      item: item,
      policy: policy,
      priority: priority,
      isExecuted: isExecuted ?? this.isExecuted,
      executedAt: executedAt ?? this.executedAt,
      executionResult: executionResult ?? this.executionResult,
    );
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    return {
      'scheduledDate': scheduledDate.toIso8601String(),
      'item': item.toJson(),
      'policy': policy.toJson(),
      'priority': priority.value,
      'isExecuted': isExecuted,
      'executedAt': executedAt?.toIso8601String(),
      'executionResult': executionResult,
    };
  }

  /// Create from JSON representation
  factory ScheduledRetentionAction.fromJson(Map<String, dynamic> json) {
    return ScheduledRetentionAction(
      scheduledDate: DateTime.parse(json['scheduledDate'] as String),
      item: DataRetentionItem.fromJson(json['item'] as Map<String, dynamic>),
      policy: RetentionPolicy.fromJson(json['policy'] as Map<String, dynamic>),
      priority: ScheduledActionPriority.fromString(
        json['priority'] as String? ?? 'normal',
      ),
      isExecuted: json['isExecuted'] as bool? ?? false,
      executedAt: json['executedAt'] != null
          ? DateTime.parse(json['executedAt'] as String)
          : null,
      executionResult: json['executionResult'] as String?,
    );
  }

  @override
  String toString() {
    return 'ScheduledRetentionAction(date: ${scheduledDate.toLocal()}, '
        'action: ${item.action}, item: ${item.id}, policy: ${policy.name})';
  }
}

/// Priority levels for scheduled actions
enum ScheduledActionPriority {
  low('low', 'Low'),
  normal('normal', 'Normal'),
  high('high', 'High'),
  urgent('urgent', 'Urgent');

  const ScheduledActionPriority(this.value, this.displayName);

  final String value;
  final String displayName;

  static ScheduledActionPriority fromString(String value) {
    return ScheduledActionPriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => ScheduledActionPriority.normal,
    );
  }
}

/// Action types for retention scheduling
enum RetentionActionType {
  archive('archive', 'Archive'),
  delete('delete', 'Delete'),
  anonymize('anonymize', 'Anonymize'),
  notify('notify', 'Notify');

  const RetentionActionType(this.value, this.displayName);

  final String value;
  final String displayName;

  static RetentionActionType fromString(String value) {
    return RetentionActionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => RetentionActionType.delete,
    );
  }
}

/// Summary statistics for a retention schedule
class RetentionScheduleSummary {
  final int totalActions;
  final int todaysActionCount;
  final int nextWeekActionCount;
  final int overdueActionCount;
  final Map<RetentionActionType, int> actionsByType;
  final Map<String, int> actionsByPolicy;

  const RetentionScheduleSummary({
    required this.totalActions,
    required this.todaysActionCount,
    required this.nextWeekActionCount,
    required this.overdueActionCount,
    required this.actionsByType,
    required this.actionsByPolicy,
  });

  /// Get percentage of actions that are overdue
  double get overduePercentage {
    if (totalActions == 0) return 0.0;
    return (overdueActionCount / totalActions) * 100;
  }

  /// Get most common action type
  RetentionActionType? get mostCommonActionType {
    if (actionsByType.isEmpty) return null;

    var maxCount = 0;
    RetentionActionType? mostCommon;

    for (final entry in actionsByType.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        mostCommon = entry.key;
      }
    }

    return mostCommon;
  }

  /// Get policy with most scheduled actions
  String? get busiestPolicyId {
    if (actionsByPolicy.isEmpty) return null;

    var maxCount = 0;
    String? busiestPolicy;

    for (final entry in actionsByPolicy.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        busiestPolicy = entry.key;
      }
    }

    return busiestPolicy;
  }

  /// Convert to JSON representation
  Map<String, dynamic> toJson() {
    return {
      'totalActions': totalActions,
      'todaysActionCount': todaysActionCount,
      'nextWeekActionCount': nextWeekActionCount,
      'overdueActionCount': overdueActionCount,
      'overduePercentage': overduePercentage,
      'actionsByType': actionsByType.map(
        (key, value) => MapEntry(key.value, value),
      ),
      'actionsByPolicy': actionsByPolicy,
      'mostCommonActionType': mostCommonActionType?.value,
      'busiestPolicyId': busiestPolicyId,
    };
  }
}

/// Data retention item placeholder - simplified for schedule
class DataRetentionItem {
  final String id;
  final RetentionActionType action;
  final DateTime createdAt;

  const DataRetentionItem({
    required this.id,
    required this.action,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action.value,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DataRetentionItem.fromJson(Map<String, dynamic> json) {
    return DataRetentionItem(
      id: json['id'] as String,
      action: RetentionActionType.fromString(json['action'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
