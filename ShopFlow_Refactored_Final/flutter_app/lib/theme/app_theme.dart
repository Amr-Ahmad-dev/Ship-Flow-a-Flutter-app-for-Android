import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// Central theme configuration for the ShopFlow application.
///
/// Keeping the visual system in one place makes it much easier for future
/// developers to update spacing, colors, and interaction feedback without
/// searching through every screen.
class AppTheme {
  AppTheme._();

  /// Builds the shared [used by the entire application.
  ///
  /// The button styles intentionally include hover and pressed feedback so the
  /// interface feels responsive on both touch devices and desktop targets.
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppConstants.kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppConstants.kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppConstants.kPrimary, width: 1.5),
        ),
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
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppConstants.kPrimary.withValues(alpha: 0.45);
            }
            if (states.contains(WidgetState.pressed)) {
              return AppConstants.kPrimaryDark;
            }
            if (states.contains(WidgetState.hovered)) {
              return AppConstants.kPrimaryHover;
            }
            return AppConstants.kPrimary;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return 0;
            }
            if (states.contains(WidgetState.hovered)) {
              return 2;
            }
            return 1;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.white.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered)) {
              return Colors.white.withValues(alpha: 0.06);
            }
            return null;
          }),
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
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return const BorderSide(color: AppConstants.kPrimaryDark, width: 1.4);
            }
            if (states.contains(WidgetState.hovered)) {
              return const BorderSide(color: AppConstants.kPrimaryHover, width: 1.2);
            }
            return const BorderSide(color: AppConstants.kPrimary, width: 1.1);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppConstants.kMutedText;
            }
            if (states.contains(WidgetState.pressed)) {
              return AppConstants.kPrimaryDark;
            }
            return AppConstants.kPrimary;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AppConstants.kPrimary.withValues(alpha: 0.08);
            }
            if (states.contains(WidgetState.hovered)) {
              return AppConstants.kPrimary.withValues(alpha: 0.04);
            }
            return null;
          }),
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
