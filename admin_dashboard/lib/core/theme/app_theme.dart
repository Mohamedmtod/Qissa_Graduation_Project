import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color surface = Color(0xFFFBF9F5);
  static const Color surfaceBright = Color(0xFFFBF9F5);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF5F3EF);
  static const Color surfaceContainer = Color(0xFFF0EEEA);
  static const Color surfaceContainerHigh = Color(0xFFEAE8E4);
  static const Color surfaceContainerHighest = Color(0xFFE4E2DE);
  static const Color outline = Color(0xFF857374);
  static const Color outlineVariant = Color(0xFFD7C1C3);

  static const Color primary = Color(0xFF6E313C);
  static const Color primaryContainer = Color(0xFF8A4853);
  static const Color primaryFixed = Color(0xFFFFD9DD);
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color secondary = Color(0xFF8C4F10);
  static const Color secondaryContainer = Color(0xFFFDAD67);
  static const Color tertiary = Color(0xFF114F2D);
  static const Color tertiaryFixed = Color(0xFFB3F1C3);

  static const Color onSurface = Color(0xFF1B1C1A);
  static const Color onSurfaceVariant = Color(0xFF524345);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryContainer],
  );

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        onSecondary: Colors.white,
        error: Color(0xFFBA1A1A),
        onError: Colors.white,
        surface: surface,
        onSurface: onSurface,
      ),
    );

    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.notoSerif(
        color: onSurface,
        fontSize: 56,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: GoogleFonts.notoSerif(
        color: onSurface,
        fontSize: 44,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: GoogleFonts.notoSerif(
        color: onSurface,
        fontSize: 32,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.notoSerif(
        color: onSurface,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.notoSerif(
        color: onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: GoogleFonts.manrope(
        color: onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.55,
      ),
      bodyMedium: GoogleFonts.manrope(
        color: onSurfaceVariant,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.55,
      ),
      labelLarge: GoogleFonts.manrope(
        color: onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: GoogleFonts.manrope(
        color: onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      labelSmall: GoogleFonts.manrope(
        color: onSurfaceVariant,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      dividerColor: outlineVariant.withValues(alpha: 0.32),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLowest,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: onSurfaceVariant.withValues(alpha: 0.82),
        ),
        prefixIconColor: onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: outlineVariant.withValues(alpha: 0.24)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: outlineVariant.withValues(alpha: 0.24)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 1.2),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceContainerHighest,
        selectedColor: primary.withValues(alpha: 0.12),
        labelStyle: textTheme.labelMedium,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: onSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: surface),
        behavior: SnackBarBehavior.floating,
      ),
      cardTheme: CardThemeData(
        color: surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
