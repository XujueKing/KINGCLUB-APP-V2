import 'package:flutter/material.dart';

abstract final class KingColors {
  static const canvas = Color(0xFF080706);
  static const surface = Color(0xFF141210);
  static const elevated = Color(0xFF1E1A16);
  static const brand = Color(0xFFC9B69E);
  static const brandStrong = Color(0xFFE2C8A6);
  static const onBrand = Color(0xFF15110D);
  static const textPrimary = Color(0xFFF7F3EE);
  static const textSecondary = Color(0xFFB9B1A8);
  static const textDisabled = Color(0xFF7C756E);
  static const border = Color(0xFF3A332C);
  static const success = Color(0xFF55C98A);
  static const warning = Color(0xFFF2B84B);
  static const danger = Color(0xFFFF646A);
  static const info = Color(0xFF78AFFF);
}

abstract final class KingTheme {
  static ThemeData get dark {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: KingColors.brand,
          brightness: Brightness.dark,
          surface: KingColors.surface,
          error: KingColors.danger,
        ).copyWith(
          primary: KingColors.brand,
          onPrimary: KingColors.onBrand,
          secondary: KingColors.brandStrong,
          surface: KingColors.surface,
          onSurface: KingColors.textPrimary,
          outline: KingColors.border,
        );

    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: KingColors.canvas,
      fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei'],
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: const TextStyle(
          fontSize: 32,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: KingColors.textPrimary,
        ),
        headlineMedium: const TextStyle(
          fontSize: 24,
          height: 1.34,
          fontWeight: FontWeight.w700,
          color: KingColors.textPrimary,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: KingColors.textPrimary,
        ),
        bodyLarge: const TextStyle(
          fontSize: 17,
          height: 1.53,
          color: KingColors.textPrimary,
        ),
        bodyMedium: const TextStyle(
          fontSize: 15,
          height: 1.6,
          color: KingColors.textPrimary,
        ),
        bodySmall: const TextStyle(
          fontSize: 13,
          height: 1.54,
          color: KingColors.textSecondary,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          height: 1.43,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KingColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: const TextStyle(color: KingColors.textSecondary),
        hintStyle: const TextStyle(color: KingColors.textDisabled),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: KingColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: KingColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: KingColors.brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: KingColors.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: KingColors.brand,
          foregroundColor: KingColors.onBrand,
          disabledBackgroundColor: KingColors.border,
          disabledForegroundColor: KingColors.textDisabled,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: KingColors.brandStrong,
          side: const BorderSide(color: KingColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: KingColors.canvas,
        foregroundColor: KingColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: KingColors.elevated,
        contentTextStyle: const TextStyle(color: KingColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: KingColors.border,
    );
  }
}
