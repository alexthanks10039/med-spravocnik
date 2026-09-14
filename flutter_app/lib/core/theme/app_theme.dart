import 'package:flutter/material.dart';

abstract final class AppColors {
  static const navy = Color(0xFF092B3C);
  static const teal = Color(0xFF087F7A);
  static const cyan = Color(0xFF37B9C6);
  static const ice = Color(0xFFE8F4F5);
  static const graphite = Color(0xFF172127);
  static const canvas = Color(0xFFF4F7F7);
  static const warning = Color(0xFFD68A19);
  static const danger = Color(0xFFC63D4F);
}

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: brightness,
      primary: dark ? const Color(0xFF69D4D0) : AppColors.teal,
      secondary: dark ? const Color(0xFF63D4E0) : AppColors.cyan,
      surface: dark ? const Color(0xFF10191E) : Colors.white,
      error: dark ? const Color(0xFFFFB3BD) : AppColors.danger,
    );

    final radius = BorderRadius.circular(18);
    final cardRadius = BorderRadius.circular(20);
    final outline = scheme.outlineVariant.withValues(alpha: .7);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF0B1216) : AppColors.canvas,
      fontFamily: 'Arial',
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1),
        headlineMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.5),
        titleLarge: TextStyle(fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(height: 1.55),
        bodyMedium: TextStyle(height: 1.5),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: cardRadius, side: BorderSide(color: outline)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF172228) : Colors.white,
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: outline)),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurface),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: dark ? const Color(0xFF10191E) : Colors.white,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        selectedLabelTextStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}
