/// Component theme definitions for the Meeting Summarizer application
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Component themes for the application
class AppComponentThemes {
  /// Private constructor to prevent instantiation
  AppComponentThemes._();

  // Light theme component styles

  /// Light theme app bar
  static final AppBarTheme lightAppBarTheme = AppBarTheme(
    centerTitle: true,
    elevation: 0,
    scrolledUnderElevation: 1,
    backgroundColor: Color(0xFFFFFBFE),
    foregroundColor: Color(0xFF1C1B1F),
    shadowColor: Color(0xFF000000),
    surfaceTintColor: Color(0xFF1976D2),
    titleTextStyle: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 22.0,
      fontWeight: FontWeight.w500,
      color: Color(0xFF1C1B1F),
    ),
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  /// Light theme card
  static const CardThemeData lightCardTheme = CardThemeData(
    elevation: 2,
    shadowColor: Color(0xFF000000),
    surfaceTintColor: Color(0xFF1976D2),
    color: Color(0xFFFFFBFE),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    margin: EdgeInsets.all(8),
  );

  /// Light theme elevated button
  static final ElevatedButtonThemeData lightElevatedButtonTheme =
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Color(0xFFFFFFFF),
          backgroundColor: Color(0xFF1976D2),
          disabledForegroundColor: Color(0xFF1C1B1F).withValues(alpha: 0.38),
          disabledBackgroundColor: Color(0xFF1C1B1F).withValues(alpha: 0.12),
          shadowColor: Color(0xFF000000),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      );

  /// Light theme outlined button
  static final OutlinedButtonThemeData lightOutlinedButtonTheme =
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Color(0xFF1976D2),
          disabledForegroundColor: Color(0xFF1C1B1F).withValues(alpha: 0.38),
          side: BorderSide(color: Color(0xFF79747E), width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      );

  /// Light theme text button
  static final TextButtonThemeData lightTextButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: Color(0xFF1976D2),
      disabledForegroundColor: Color(0xFF1C1B1F).withValues(alpha: 0.38),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      textStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 14.0,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
    ),
  );

  /// Light theme floating action button
  static const FloatingActionButtonThemeData lightFloatingActionButtonTheme =
      FloatingActionButtonThemeData(
        foregroundColor: Color(0xFFFFFFFF),
        backgroundColor: Color(0xFF1976D2),
        elevation: 6,
        focusElevation: 8,
        hoverElevation: 8,
        highlightElevation: 12,
        disabledElevation: 0,
        shape: CircleBorder(),
      );

  /// Light theme bottom navigation bar
  static const BottomNavigationBarThemeData lightBottomNavigationBarTheme =
      BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFFFFBFE),
        selectedItemColor: Color(0xFF1976D2),
        unselectedItemColor: Color(0xFF49454F),
        type: BottomNavigationBarType.fixed,
        elevation: 3,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12.0,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12.0,
          fontWeight: FontWeight.w500,
        ),
      );

  /// Light theme switch
  static final SwitchThemeData lightSwitchTheme = SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith<Color>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.selected)) {
        return Color(0xFF1976D2);
      }
      return Color(0xFFFFFFFF);
    }),
    trackColor: WidgetStateProperty.resolveWith<Color>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.selected)) {
        return Color(0xFF1976D2).withValues(alpha: 0.5);
      }
      return Color(0xFF79747E).withValues(alpha: 0.38);
    }),
  );

  /// Light theme segmented button
  static final SegmentedButtonThemeData lightSegmentedButtonTheme =
      SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith<Color>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return Color(0xFF1976D2);
            }
            return Color(0xFF49454F);
          }),
          backgroundColor: WidgetStateProperty.resolveWith<Color>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return Color(0xFFBBDEFB);
            }
            return Color(0xFFFFFBFE);
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          side: WidgetStateProperty.all(
            BorderSide(color: Color(0xFF79747E), width: 1),
          ),
        ),
      );

  /// Light theme slider
  static final SliderThemeData lightSliderTheme = SliderThemeData(
    activeTrackColor: Color(0xFF1976D2),
    inactiveTrackColor: Color(0xFF79747E).withValues(alpha: 0.38),
    thumbColor: Color(0xFF1976D2),
    overlayColor: Color(0xFF1976D2).withValues(alpha: 0.12),
    valueIndicatorColor: Color(0xFF1976D2),
    valueIndicatorTextStyle: TextStyle(
      color: Color(0xFFFFFFFF),
      fontFamily: 'Roboto',
      fontSize: 14.0,
      fontWeight: FontWeight.w500,
    ),
  );

  /// Light theme progress indicator
  static const ProgressIndicatorThemeData lightProgressIndicatorTheme =
      ProgressIndicatorThemeData(
        color: Color(0xFF1976D2),
        linearTrackColor: Color(0xFF79747E),
        circularTrackColor: Color(0xFF79747E),
        refreshBackgroundColor: Color(0xFFFFFBFE),
      );

  /// Light theme divider
  static const DividerThemeData lightDividerTheme = DividerThemeData(
    color: Color(0xFF79747E),
    thickness: 1,
    space: 1,
  );

  /// Light theme dialog
  static const DialogThemeData lightDialogTheme = DialogThemeData(
    backgroundColor: Color(0xFFFFFBFE),
    surfaceTintColor: Color(0xFF1976D2),
    elevation: 6,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(28)),
    ),
    titleTextStyle: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 24.0,
      fontWeight: FontWeight.w400,
      color: Color(0xFF1C1B1F),
    ),
    contentTextStyle: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 14.0,
      fontWeight: FontWeight.w400,
      color: Color(0xFF49454F),
    ),
  );

  /// Light theme snack bar
  static const SnackBarThemeData lightSnackBarTheme = SnackBarThemeData(
    backgroundColor: Color(0xFF313033),
    contentTextStyle: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 14.0,
      fontWeight: FontWeight.w400,
      color: Color(0xFFF4EFF4),
    ),
    actionTextColor: Color(0xFF90CAF9),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
    behavior: SnackBarBehavior.floating,
  );

  /// Light theme tooltip
  static const TooltipThemeData lightTooltipTheme = TooltipThemeData(
    decoration: BoxDecoration(
      color: Color(0xFF313033),
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
    textStyle: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 12.0,
      fontWeight: FontWeight.w400,
      color: Color(0xFFF4EFF4),
    ),
    margin: EdgeInsets.symmetric(horizontal: 16),
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    preferBelow: true,
    verticalOffset: 24,
  );

  // Dark theme component styles

  /// Dark theme app bar
  static final AppBarTheme darkAppBarTheme = AppBarTheme(
    centerTitle: true,
    elevation: 0,
    scrolledUnderElevation: 1,
    backgroundColor: Color(0xFF1C1B1F),
    foregroundColor: Color(0xFFE6E1E5),
    shadowColor: Color(0xFF000000),
    surfaceTintColor: Color(0xFF90CAF9),
    titleTextStyle: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 22.0,
      fontWeight: FontWeight.w500,
      color: Color(0xFFE6E1E5),
    ),
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  /// Dark theme card
  static const CardThemeData darkCardTheme = CardThemeData(
    elevation: 2,
    shadowColor: Color(0xFF000000),
    surfaceTintColor: Color(0xFF90CAF9),
    color: Color(0xFF1C1B1F),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    margin: EdgeInsets.all(8),
  );

  /// Dark theme elevated button
  static final ElevatedButtonThemeData darkElevatedButtonTheme =
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Color(0xFF0D47A1),
          backgroundColor: Color(0xFF90CAF9),
          disabledForegroundColor: Color(0xFFE6E1E5).withValues(alpha: 0.38),
          disabledBackgroundColor: Color(0xFFE6E1E5).withValues(alpha: 0.12),
          shadowColor: Color(0xFF000000),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      );

  /// Dark theme outlined button
  static final OutlinedButtonThemeData darkOutlinedButtonTheme =
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Color(0xFF90CAF9),
          disabledForegroundColor: Color(0xFFE6E1E5).withValues(alpha: 0.38),
          side: BorderSide(color: Color(0xFF938F99), width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14.0,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      );

  /// Dark theme text button
  static final TextButtonThemeData darkTextButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: Color(0xFF90CAF9),
      disabledForegroundColor: Color(0xFFE6E1E5).withValues(alpha: 0.38),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      textStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 14.0,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
    ),
  );

  /// Dark theme floating action button
  static const FloatingActionButtonThemeData darkFloatingActionButtonTheme =
      FloatingActionButtonThemeData(
        foregroundColor: Color(0xFF0D47A1),
        backgroundColor: Color(0xFF90CAF9),
        elevation: 6,
        focusElevation: 8,
        hoverElevation: 8,
        highlightElevation: 12,
        disabledElevation: 0,
        shape: CircleBorder(),
      );

  /// Dark theme bottom navigation bar
  static const BottomNavigationBarThemeData darkBottomNavigationBarTheme =
      BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1C1B1F),
        selectedItemColor: Color(0xFF90CAF9),
        unselectedItemColor: Color(0xFFCAC4D0),
        type: BottomNavigationBarType.fixed,
        elevation: 3,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12.0,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12.0,
          fontWeight: FontWeight.w500,
        ),
      );

  /// Dark theme switch
  static final SwitchThemeData darkSwitchTheme = SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith<Color>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.selected)) {
        return Color(0xFF90CAF9);
      }
      return Color(0xFF1C1B1F);
    }),
    trackColor: WidgetStateProperty.resolveWith<Color>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.selected)) {
        return Color(0xFF90CAF9).withValues(alpha: 0.5);
      }
      return Color(0xFF938F99).withValues(alpha: 0.38);
    }),
  );

  /// Dark theme segmented button
  static final SegmentedButtonThemeData darkSegmentedButtonTheme =
      SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith<Color>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return Color(0xFF90CAF9);
            }
            return Color(0xFFCAC4D0);
          }),
          backgroundColor: WidgetStateProperty.resolveWith<Color>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return Color(0xFF1565C0);
            }
            return Color(0xFF1C1B1F);
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          side: WidgetStateProperty.all(
            BorderSide(color: Color(0xFF938F99), width: 1),
          ),
        ),
      );

  /// Dark theme slider
  static final SliderThemeData darkSliderTheme = SliderThemeData(
    activeTrackColor: Color(0xFF90CAF9),
    inactiveTrackColor: Color(0xFF938F99).withValues(alpha: 0.38),
    thumbColor: Color(0xFF90CAF9),
    overlayColor: Color(0xFF90CAF9).withValues(alpha: 0.12),
    valueIndicatorColor: Color(0xFF90CAF9),
    valueIndicatorTextStyle: TextStyle(
      color: Color(0xFF0D47A1),
      fontFamily: 'Roboto',
      fontSize: 14.0,
      fontWeight: FontWeight.w500,
    ),
  );

  /// Dark theme progress indicator
  static const ProgressIndicatorThemeData darkProgressIndicatorTheme =
      ProgressIndicatorThemeData(
        color: Color(0xFF90CAF9),
        linearTrackColor: Color(0xFF938F99),
        circularTrackColor: Color(0xFF938F99),
        refreshBackgroundColor: Color(0xFF1C1B1F),
      );

  /// Dark theme divider
  static const DividerThemeData darkDividerTheme = DividerThemeData(
    color: Color(0xFF938F99),
    thickness: 1,
    space: 1,
  );

  /// Dark theme dialog
  static const DialogThemeData darkDialogTheme = DialogThemeData(
    backgroundColor: Color(0xFF1C1B1F),
    surfaceTintColor: Color(0xFF90CAF9),
    elevation: 6,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(28)),
    ),
    titleTextStyle: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 24.0,
      fontWeight: FontWeight.w400,
      color: Color(0xFFE6E1E5),
    ),
    contentTextStyle: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 14.0,
      fontWeight: FontWeight.w400,
      color: Color(0xFFCAC4D0),
    ),
  );

  /// Dark theme snack bar
  static const SnackBarThemeData darkSnackBarTheme = SnackBarThemeData(
    backgroundColor: Color(0xFFE6E1E5),
    contentTextStyle: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 14.0,
      fontWeight: FontWeight.w400,
      color: Color(0xFF313033),
    ),
    actionTextColor: Color(0xFF1976D2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
    behavior: SnackBarBehavior.floating,
  );

  /// Dark theme tooltip
  static const TooltipThemeData darkTooltipTheme = TooltipThemeData(
    decoration: BoxDecoration(
      color: Color(0xFFE6E1E5),
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
    textStyle: TextStyle(
      fontFamily: 'Roboto',
      fontSize: 12.0,
      fontWeight: FontWeight.w400,
      color: Color(0xFF313033),
    ),
    margin: EdgeInsets.symmetric(horizontal: 16),
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    preferBelow: true,
    verticalOffset: 24,
  );
}
