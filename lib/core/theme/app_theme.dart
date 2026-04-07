import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'brand_tokens.dart';

class AppTheme {
  static ThemeData get lightTheme {
    const scheme = ColorScheme.light(
      primary: TravelBoxBrand.primaryBlue,
      secondary: TravelBoxBrand.copper,
      tertiary: TravelBoxBrand.primaryTeal,
      surface: TravelBoxBrand.surfaceSoft,
      onSurface: TravelBoxBrand.ink,
      onSurfaceVariant: TravelBoxBrand.textBody,
      error: Color(0xFFB42318),
    );
    final baseText = GoogleFonts.interTextTheme();

    return _themeFrom(scheme: scheme, textTheme: baseText, isDark: false);
  }

  static ThemeData get darkTheme {
    const scheme = ColorScheme.dark(
      primary: Color(0xFF7AA2FF),
      secondary: Color(0xFF9BB4FF),
      tertiary: Color(0xFF56CCFF),
      surface: Color(0xFF151A30),
      onSurface: Color(0xFFF3F6FF),
      onSurfaceVariant: Color(0xFFB3BED9),
      error: Color(0xFFF87171),
    );
    final baseText = GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );

    return _themeFrom(scheme: scheme, textTheme: baseText, isDark: true);
  }

  static ThemeData _themeFrom({
    required ColorScheme scheme,
    required TextTheme textTheme,
    required bool isDark,
  }) {
    final surface = isDark ? const Color(0xFF151A30) : Colors.white;
    final fieldFill = isDark ? const Color(0xFF1A213A) : const Color(0xFFF7F9FC);
    final borderColor = isDark
        ? const Color(0xFF29324D)
        : TravelBoxBrand.border;
    final scaffold = isDark ? const Color(0xFF101426) : TravelBoxBrand.surface;
    final warmShadow = isDark
        ? const Color(0x55000000)
        : const Color(0x163564C8);
    final headlineFont = GoogleFonts.inter();

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: headlineFont.copyWith(
          color: scheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      textTheme: textTheme.copyWith(
        displayLarge: headlineFont.copyWith(
          fontSize: 52,
          height: 1,
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        displayMedium: headlineFont.copyWith(
          fontSize: 44,
          height: 1,
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: headlineFont.copyWith(
          fontSize: 34,
          height: 1.05,
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontFamily: headlineFont.fontFamily,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.15,
          color: scheme.onSurface,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontFamily: headlineFont.fontFamily,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.1,
          color: scheme.onSurface,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          height: 1.42,
          color: scheme.onSurfaceVariant,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: isDark ? const Color(0xFFBDAF9C) : TravelBoxBrand.textMuted,
          height: 1.35,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.25,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: warmShadow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderColor),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.secondary, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: borderColor),
        backgroundColor: surface,
        selectedColor: isDark
            ? const Color(0xFF3B2C28)
            : const Color(0xFFF2E3D4),
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: borderColor)),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          side: BorderSide(color: borderColor),
          foregroundColor: scheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: isDark
            ? const Color(0xFF3A2D29)
            : const Color(0xFFF0E1D0),
        elevation: 0,
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: isDark
            ? const Color(0xFF3A2D29)
            : const Color(0xFFF0E1D0),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF19213D) : const Color(0xFF243B7A),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: borderColor),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontFamily: headlineFont.fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.primary,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
