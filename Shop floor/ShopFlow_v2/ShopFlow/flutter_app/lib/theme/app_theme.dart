import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// Central theme configuration for the ShopFlow application.
class AppTheme {
  AppTheme._();

  /// Resolves a value based on the widget's interaction [states], falling
  /// back to [normal] when none of the optional overrides apply.
  static T _resolve<T>(
    Set<WidgetState> states, {
    required T normal,
    T? disabled,
    T? pressed,
    T? hovered,
  }) {
    if (disabled != null && states.contains(WidgetState.disabled)) return disabled;
    if (pressed != null && states.contains(WidgetState.pressed)) return pressed;
    if (hovered != null && states.contains(WidgetState.hovered)) return hovered;
    return normal;
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: width),
      );

  /// Builds the shared [ThemeData] used by the entire application.
  static ThemeData buildTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppConstants.kPrimary,
      primary: AppConstants.kPrimary,
      secondary: AppConstants.kAccent,
      surface: AppConstants.kCard,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppConstants.kSurface,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: AppConstants.kPrimaryDark,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppConstants.kPrimaryDark,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppConstants.kPrimaryDark,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppConstants.kPrimaryDark,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          height: 1.45,
          color: AppConstants.kPrimaryDark,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: AppConstants.kMutedText,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppConstants.kCard,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppConstants.kBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppConstants.kCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: AppConstants.kMutedText),
        border: _inputBorder(AppConstants.kBorder),
        enabledBorder: _inputBorder(AppConstants.kBorder),
        focusedBorder: _inputBorder(AppConstants.kPrimary, width: 1.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size(96, 52)),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) => _resolve(
                states,
                normal: AppConstants.kPrimary,
                disabled: AppConstants.kPrimary.withValues(alpha: 0.45),
                pressed: AppConstants.kPrimaryDark,
                hovered: AppConstants.kPrimaryHover,
              )),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          elevation: WidgetStateProperty.resolveWith(
            (states) => _resolve(states, normal: 1, pressed: 0, hovered: 2),
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) => _resolve<Color?>(
                states,
                normal: null,
                pressed: Colors.white.withValues(alpha: 0.12),
                hovered: Colors.white.withValues(alpha: 0.06),
              )),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size(96, 52)),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          side: WidgetStateProperty.resolveWith((states) => _resolve(
                states,
                normal: const BorderSide(color: AppConstants.kPrimary, width: 1.1),
                pressed: const BorderSide(color: AppConstants.kPrimaryDark, width: 1.4),
                hovered: const BorderSide(color: AppConstants.kPrimaryHover, width: 1.2),
              )),
          foregroundColor: WidgetStateProperty.resolveWith((states) => _resolve(
                states,
                normal: AppConstants.kPrimary,
                disabled: AppConstants.kMutedText,
                pressed: AppConstants.kPrimaryDark,
              )),
          overlayColor: WidgetStateProperty.resolveWith((states) => _resolve<Color?>(
                states,
                normal: null,
                pressed: AppConstants.kPrimary.withValues(alpha: 0.08),
                hovered: AppConstants.kPrimary.withValues(alpha: 0.04),
              )),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppConstants.kAccentSoft,
        labelStyle: const TextStyle(
          color: AppConstants.kPrimaryDark,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        side: const BorderSide(color: AppConstants.kBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppConstants.kPrimaryDark,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppConstants.kBorder,
        thickness: 1,
        space: 24,
      ),
    );
  }
}
