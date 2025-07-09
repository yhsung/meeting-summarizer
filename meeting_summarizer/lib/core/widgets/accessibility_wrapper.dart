/// Accessibility wrapper widget for enhanced accessibility features
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Wrapper widget that provides enhanced accessibility features
class AccessibilityWrapper extends StatelessWidget {
  /// Child widget to wrap
  final Widget child;

  /// Semantic label for screen readers
  final String? semanticLabel;

  /// Semantic hint for screen readers
  final String? semanticHint;

  /// Whether this widget is focusable
  final bool isFocusable;

  /// Whether this widget is enabled
  final bool isEnabled;

  /// Whether this widget is selected
  final bool isSelected;

  /// Whether this widget is a button
  final bool isButton;

  /// Whether this widget is a text field
  final bool isTextField;

  /// Whether this widget is a header
  final bool isHeader;

  /// Whether this widget is live region (announces changes)
  final bool isLiveRegion;

  /// Custom semantic actions
  final Map<CustomSemanticsAction, VoidCallback>? semanticActions;

  /// Callback when tapped
  final VoidCallback? onTap;

  /// Callback when long pressed
  final VoidCallback? onLongPress;

  /// Custom focus node
  final FocusNode? focusNode;

  /// Tooltip message
  final String? tooltip;

  const AccessibilityWrapper({
    super.key,
    required this.child,
    this.semanticLabel,
    this.semanticHint,
    this.isFocusable = true,
    this.isEnabled = true,
    this.isSelected = false,
    this.isButton = false,
    this.isTextField = false,
    this.isHeader = false,
    this.isLiveRegion = false,
    this.semanticActions,
    this.onTap,
    this.onLongPress,
    this.focusNode,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    Widget wrappedChild = child;

    // Add tooltip if provided
    if (tooltip != null) {
      wrappedChild = Tooltip(message: tooltip!, child: wrappedChild);
    }

    // Add focus handling
    if (isFocusable) {
      wrappedChild = Focus(focusNode: focusNode, child: wrappedChild);
    }

    // Add gesture detection
    if (onTap != null || onLongPress != null) {
      wrappedChild = GestureDetector(
        onTap: isEnabled ? onTap : null,
        onLongPress: isEnabled ? onLongPress : null,
        child: wrappedChild,
      );
    }

    // Add semantic annotations
    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      enabled: isEnabled,
      selected: isSelected,
      button: isButton,
      textField: isTextField,
      header: isHeader,
      liveRegion: isLiveRegion,
      focusable: isFocusable,
      focused: focusNode?.hasFocus ?? false,
      customSemanticsActions: semanticActions,
      child: wrappedChild,
    );
  }
}

/// Widget that provides accessibility announcements
class AccessibilityAnnouncement extends StatelessWidget {
  /// Message to announce
  final String message;

  /// Whether the announcement is polite (default) or assertive
  final bool isAssertive;

  /// Child widget (optional)
  final Widget? child;

  const AccessibilityAnnouncement({
    super.key,
    required this.message,
    this.isAssertive = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: child ?? const SizedBox.shrink(),
    );
  }

  /// Make an accessibility announcement
  static void announce(
    BuildContext context,
    String message, {
    bool isAssertive = false,
  }) {
    SemanticsService.announce(
      message,
      isAssertive ? Directionality.of(context) : Directionality.of(context),
    );
  }
}

/// Widget that provides high contrast support
class HighContrastWidget extends StatelessWidget {
  /// Child widget
  final Widget child;

  /// High contrast version of the child widget
  final Widget? highContrastChild;

  /// Whether to force high contrast mode
  final bool forceHighContrast;

  const HighContrastWidget({
    super.key,
    required this.child,
    this.highContrastChild,
    this.forceHighContrast = false,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isHighContrast =
        forceHighContrast ||
        mediaQuery.highContrast ||
        mediaQuery.accessibleNavigation;

    if (isHighContrast && highContrastChild != null) {
      return highContrastChild!;
    }

    return child;
  }
}

/// Widget that provides large text support
class LargeTextWidget extends StatelessWidget {
  /// Child widget
  final Widget child;

  /// Text scale factor threshold for large text
  final double largeTextThreshold;

  /// Large text version of the child widget
  final Widget? largeTextChild;

  const LargeTextWidget({
    super.key,
    required this.child,
    this.largeTextThreshold = 1.3,
    this.largeTextChild,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLargeText = mediaQuery.textScaler.scale(1.0) >= largeTextThreshold;

    if (isLargeText && largeTextChild != null) {
      return largeTextChild!;
    }

    return child;
  }
}

/// Widget that provides motion reduction support
class MotionReducedWidget extends StatelessWidget {
  /// Child widget with animations
  final Widget child;

  /// Static version of the child widget (no animations)
  final Widget? staticChild;

  /// Whether to force motion reduction
  final bool forceMotionReduction;

  const MotionReducedWidget({
    super.key,
    required this.child,
    this.staticChild,
    this.forceMotionReduction = false,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isMotionReduced =
        forceMotionReduction ||
        mediaQuery.disableAnimations ||
        mediaQuery.accessibleNavigation;

    if (isMotionReduced && staticChild != null) {
      return staticChild!;
    }

    return child;
  }
}

/// Widget that provides enhanced focus indicators
class FocusIndicatorWidget extends StatelessWidget {
  /// Child widget
  final Widget child;

  /// Focus indicator color
  final Color? focusColor;

  /// Focus indicator width
  final double focusWidth;

  /// Focus node
  final FocusNode? focusNode;

  const FocusIndicatorWidget({
    super.key,
    required this.child,
    this.focusColor,
    this.focusWidth = 2.0,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveFocusColor = focusColor ?? theme.focusColor;

    return Focus(
      focusNode: focusNode,
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              border: isFocused
                  ? Border.all(color: effectiveFocusColor, width: focusWidth)
                  : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: child,
          );
        },
      ),
    );
  }
}

/// Accessibility utilities
class AccessibilityUtils {
  /// Check if high contrast mode is enabled
  static bool isHighContrastMode(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.highContrast;
  }

  /// Check if large text is enabled
  static bool isLargeTextEnabled(
    BuildContext context, {
    double threshold = 1.3,
  }) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.textScaler.scale(1.0) >= threshold;
  }

  /// Check if animations are disabled
  static bool areAnimationsDisabled(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.disableAnimations;
  }

  /// Check if accessible navigation is enabled
  static bool isAccessibleNavigationEnabled(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.accessibleNavigation;
  }

  /// Get appropriate text scale factor for accessibility
  static double getAccessibleTextScaleFactor(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.textScaler.scale(1.0).clamp(0.8, 2.0);
  }

  /// Get appropriate animation duration for accessibility
  static Duration getAccessibleAnimationDuration(
    BuildContext context,
    Duration defaultDuration,
  ) {
    if (areAnimationsDisabled(context)) {
      return Duration.zero;
    }
    return defaultDuration;
  }

  /// Get appropriate spacing for accessibility
  static double getAccessibleSpacing(
    BuildContext context,
    double defaultSpacing,
  ) {
    final textScaleFactor = getAccessibleTextScaleFactor(context);
    return defaultSpacing * textScaleFactor;
  }

  /// Get appropriate border radius for accessibility
  static double getAccessibleBorderRadius(
    BuildContext context,
    double defaultRadius,
  ) {
    final textScaleFactor = getAccessibleTextScaleFactor(context);
    return defaultRadius * textScaleFactor;
  }

  /// Get appropriate icon size for accessibility
  static double getAccessibleIconSize(
    BuildContext context,
    double defaultSize,
  ) {
    final textScaleFactor = getAccessibleTextScaleFactor(context);
    return defaultSize * textScaleFactor;
  }

  /// Get appropriate minimum tap target size for accessibility
  static double getAccessibleMinTapTargetSize(BuildContext context) {
    final textScaleFactor = getAccessibleTextScaleFactor(context);
    return (48.0 * textScaleFactor).clamp(44.0, 64.0);
  }
}
