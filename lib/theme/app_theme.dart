import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Study Buddy brand palette, matching the visual design pass in ST-33/ST-34
/// (deep pine + warm gold, wireframe-derived).
abstract final class AppColors {
  static const pine900 = Color(0xFF16302B);
  static const pine800 = Color(0xFF1B3A33);
  static const gold500 = Color(0xFFE0A83E);
  static const green600 = Color(0xFF3F9142);
  static const cream50 = Color(0xFFFCF3EF);

  static const white = Color(0xFFFFFFFF);
  static const neutral100 = Color(0xFFF5F2EE);
  static const neutral150 = Color(0xFFF1EEE9);
  static const neutral200 = Color(0xFFECE7E2);
  static const neutral300 = Color(0xFFA8B3AE);
  static const neutral400 = Color(0xFF8A9994);
  static const neutral500 = Color(0xFF6B7A76);

  static const warnBg = Color(0xFFFBF6EE);
  static const warnBorder = Color(0xFFF1E3C4);
  static const warnText = Color(0xFF8A5A17);
  static const warnStrike = Color(0xFFB8AA95);

  static const errorRed = Color(0xFFC4634B);
}

abstract final class AppTheme {
  static ThemeData get light {
    final baseTextTheme = TextTheme(
      headlineLarge: GoogleFonts.baloo2(fontWeight: FontWeight.w800, fontSize: 32, color: AppColors.pine900),
      headlineMedium: GoogleFonts.baloo2(fontWeight: FontWeight.w700, fontSize: 24, color: AppColors.pine900),
      headlineSmall: GoogleFonts.baloo2(fontWeight: FontWeight.w700, fontSize: 20, color: AppColors.pine900),
      titleLarge: GoogleFonts.baloo2(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.pine900),
      titleMedium: GoogleFonts.baloo2(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.pine900),
      titleSmall: GoogleFonts.baloo2(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.pine900),
      labelLarge: GoogleFonts.baloo2(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.white),
      bodyLarge: GoogleFonts.manrope(fontWeight: FontWeight.w400, fontSize: 15, color: AppColors.pine900),
      bodyMedium: GoogleFonts.manrope(fontWeight: FontWeight.w400, fontSize: 14, color: AppColors.pine900),
      bodySmall: GoogleFonts.manrope(fontWeight: FontWeight.w500, fontSize: 12, color: AppColors.neutral500),
      labelMedium: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.neutral500),
      labelSmall: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 10, color: AppColors.neutral400),
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.pine800,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.pine800,
      onPrimary: AppColors.white,
      secondary: AppColors.gold500,
      onSecondary: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.pine900,
      error: AppColors.errorRed,
      errorContainer: AppColors.warnBg,
      onErrorContainer: AppColors.warnText,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.white,
      textTheme: baseTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.pine900,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.baloo2(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: AppColors.pine900,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        indicatorColor: Colors.transparent,
        height: 76,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.pine800 : AppColors.neutral400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? AppColors.pine800 : AppColors.neutral400, size: 22);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pine800,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.neutral200,
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.baloo2(fontWeight: FontWeight.w700, fontSize: 16),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.green600,
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: AppColors.neutral100,
          foregroundColor: AppColors.pine900,
          disabledForegroundColor: AppColors.neutral300,
          shape: const CircleBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.neutral200, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.neutral200, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.pine800, width: 1.5),
        ),
        labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.neutral500),
        hintStyle: GoogleFonts.manrope(fontWeight: FontWeight.w400, fontSize: 14, color: AppColors.neutral400),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.neutral200, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.neutral150, thickness: 1, space: 1),
    );
  }
}
