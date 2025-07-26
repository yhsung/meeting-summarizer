import 'package:flutter/material.dart';

/// Represents contextual help for specific UI elements or user actions
class ContextualHelp {
  final String id;
  final String context; // Screen or widget identifier
  final String
  trigger; // What triggers this help (first visit, user action, etc.)
  final String title;
  final String content;
  final HelpTooltipType type;
  final HelpTooltipPosition position;
  final Duration? displayDuration;
  final bool isDismissible;
  final List<String>
  prerequisites; // Other help items that should be shown first
  final Map<String, dynamic>? customData;

  const ContextualHelp({
    required this.id,
    required this.context,
    required this.trigger,
    required this.title,
    required this.content,
    this.type = HelpTooltipType.tooltip,
    this.position = HelpTooltipPosition.auto,
    this.displayDuration,
    this.isDismissible = true,
    this.prerequisites = const [],
    this.customData,
  });

  ContextualHelp copyWith({
    String? id,
    String? context,
    String? trigger,
    String? title,
    String? content,
    HelpTooltipType? type,
    HelpTooltipPosition? position,
    Duration? displayDuration,
    bool? isDismissible,
    List<String>? prerequisites,
    Map<String, dynamic>? customData,
  }) {
    return ContextualHelp(
      id: id ?? this.id,
      context: context ?? this.context,
      trigger: trigger ?? this.trigger,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      position: position ?? this.position,
      displayDuration: displayDuration ?? this.displayDuration,
      isDismissible: isDismissible ?? this.isDismissible,
      prerequisites: prerequisites ?? this.prerequisites,
      customData: customData ?? this.customData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'context': context,
      'trigger': trigger,
      'title': title,
      'content': content,
      'type': type.name,
      'position': position.name,
      'displayDuration': displayDuration?.inMilliseconds,
      'isDismissible': isDismissible,
      'prerequisites': prerequisites,
      'customData': customData,
    };
  }

  factory ContextualHelp.fromJson(Map<String, dynamic> json) {
    return ContextualHelp(
      id: json['id'] as String,
      context: json['context'] as String,
      trigger: json['trigger'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      type: HelpTooltipType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => HelpTooltipType.tooltip,
      ),
      position: HelpTooltipPosition.values.firstWhere(
        (e) => e.name == json['position'],
        orElse: () => HelpTooltipPosition.auto,
      ),
      displayDuration: json['displayDuration'] != null
          ? Duration(milliseconds: json['displayDuration'] as int)
          : null,
      isDismissible: json['isDismissible'] as bool? ?? true,
      prerequisites: List<String>.from(json['prerequisites'] as List? ?? []),
      customData: json['customData'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContextualHelp && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ContextualHelp(id: $id, context: $context, type: $type)';
  }
}

/// Types of help tooltips available
enum HelpTooltipType { tooltip, overlay, popover, coach, spotlight }

/// Position preferences for help tooltips
enum HelpTooltipPosition { auto, top, bottom, left, right, center }

/// Help tour step for guided tutorials
class HelpTourStep {
  final String id;
  final String tourId;
  final int stepNumber;
  final String targetElementId; // Widget key or identifier to highlight
  final String title;
  final String content;
  final HelpTooltipPosition position;
  final bool showNext;
  final bool showPrevious;
  final bool showSkip;
  final String? actionButtonText;
  final VoidCallback? onAction;
  final Map<String, dynamic>? metadata;

  const HelpTourStep({
    required this.id,
    required this.tourId,
    required this.stepNumber,
    required this.targetElementId,
    required this.title,
    required this.content,
    this.position = HelpTooltipPosition.auto,
    this.showNext = true,
    this.showPrevious = true,
    this.showSkip = true,
    this.actionButtonText,
    this.onAction,
    this.metadata,
  });

  HelpTourStep copyWith({
    String? id,
    String? tourId,
    int? stepNumber,
    String? targetElementId,
    String? title,
    String? content,
    HelpTooltipPosition? position,
    bool? showNext,
    bool? showPrevious,
    bool? showSkip,
    String? actionButtonText,
    VoidCallback? onAction,
    Map<String, dynamic>? metadata,
  }) {
    return HelpTourStep(
      id: id ?? this.id,
      tourId: tourId ?? this.tourId,
      stepNumber: stepNumber ?? this.stepNumber,
      targetElementId: targetElementId ?? this.targetElementId,
      title: title ?? this.title,
      content: content ?? this.content,
      position: position ?? this.position,
      showNext: showNext ?? this.showNext,
      showPrevious: showPrevious ?? this.showPrevious,
      showSkip: showSkip ?? this.showSkip,
      actionButtonText: actionButtonText ?? this.actionButtonText,
      onAction: onAction ?? this.onAction,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tourId': tourId,
      'stepNumber': stepNumber,
      'targetElementId': targetElementId,
      'title': title,
      'content': content,
      'position': position.name,
      'showNext': showNext,
      'showPrevious': showPrevious,
      'showSkip': showSkip,
      'actionButtonText': actionButtonText,
      'metadata': metadata,
    };
  }

  factory HelpTourStep.fromJson(Map<String, dynamic> json) {
    return HelpTourStep(
      id: json['id'] as String,
      tourId: json['tourId'] as String,
      stepNumber: json['stepNumber'] as int,
      targetElementId: json['targetElementId'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      position: HelpTooltipPosition.values.firstWhere(
        (e) => e.name == json['position'],
        orElse: () => HelpTooltipPosition.auto,
      ),
      showNext: json['showNext'] as bool? ?? true,
      showPrevious: json['showPrevious'] as bool? ?? true,
      showSkip: json['showSkip'] as bool? ?? true,
      actionButtonText: json['actionButtonText'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HelpTourStep && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'HelpTourStep(id: $id, tourId: $tourId, stepNumber: $stepNumber)';
  }
}

/// Help tour containing multiple steps
class HelpTour {
  final String id;
  final String name;
  final String description;
  final List<HelpTourStep> steps;
  final bool isActive;
  final DateTime? lastShownAt;
  final int completionCount;
  final Map<String, dynamic>? metadata;

  const HelpTour({
    required this.id,
    required this.name,
    required this.description,
    required this.steps,
    this.isActive = true,
    this.lastShownAt,
    this.completionCount = 0,
    this.metadata,
  });

  HelpTour copyWith({
    String? id,
    String? name,
    String? description,
    List<HelpTourStep>? steps,
    bool? isActive,
    DateTime? lastShownAt,
    int? completionCount,
    Map<String, dynamic>? metadata,
  }) {
    return HelpTour(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      steps: steps ?? this.steps,
      isActive: isActive ?? this.isActive,
      lastShownAt: lastShownAt ?? this.lastShownAt,
      completionCount: completionCount ?? this.completionCount,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'steps': steps.map((step) => step.toJson()).toList(),
      'isActive': isActive,
      'lastShownAt': lastShownAt?.toIso8601String(),
      'completionCount': completionCount,
      'metadata': metadata,
    };
  }

  factory HelpTour.fromJson(Map<String, dynamic> json) {
    return HelpTour(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      steps: (json['steps'] as List)
          .map((step) => HelpTourStep.fromJson(step as Map<String, dynamic>))
          .toList(),
      isActive: json['isActive'] as bool? ?? true,
      lastShownAt: json['lastShownAt'] != null
          ? DateTime.parse(json['lastShownAt'] as String)
          : null,
      completionCount: json['completionCount'] as int? ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HelpTour && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'HelpTour(id: $id, name: $name, stepsCount: ${steps.length})';
  }
}
