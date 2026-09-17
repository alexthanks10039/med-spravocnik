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
  static ThemeData get lightHighContrast => _build(Brightness.light, highContrast: true);
  static ThemeData get darkHighContrast => _build(Brightness.dark, highContrast: true);

  static ThemeData _build(Brightness brightness, {bool highContrast = false}) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: brightness,
      primary: dark ? const Color(0xFF69D4D0) : AppColors.teal,
      secondary: dark ? const Color(0xFF63D4E0) : AppColors.cyan,
      surface: dark ? const Color(0xFF10191E) : Colors.white,
      error: dark ? const Color(0xFFFFB3BD) : AppColors.danger,
      contrastLevel: highContrast ? 1.0 : 0.0,
    );

    final radius = BorderRadius.circular(highContrast ? 12 : 18);
    final cardRadius = BorderRadius.circular(highContrast ? 14 : 20);
    final outline = highContrast
        ? (dark ? Colors.white70 : Colors.black87)
        : scheme.outlineVariant.withValues(alpha: .7);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF0B1216) : AppColors.canvas,
      fontFamily: 'Arial',
      visualDensity: highContrast ? VisualDensity.comfortable : VisualDensity.standard,
      textTheme: TextTheme(
        headlineLarge: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1),
        headlineMedium: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.5),
        titleLarge: const TextStyle(fontWeight: FontWeight.w700),
        titleMedium: const TextStyle(fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(height: 1.6, fontWeight: highContrast ? FontWeight.w600 : FontWeight.normal),
        bodyMedium: TextStyle(height: 1.55, fontWeight: highContrast ? FontWeight.w600 : FontWeight.normal),
      ),
      cardTheme: CardThemeData(
        elevation: highContrast ? 1 : 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: cardRadius, side: BorderSide(color: outline, width: highContrast ? 1.5 : 1)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF172228) : Colors.white,
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: outline, width: highContrast ? 1.5 : 1)),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: outline, width: highContrast ? 1.5 : 1)),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: highContrast ? 3 : 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: highContrast ? 2 : 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: highContrast ? 3 : 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: highContrast ? 19 : 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: highContrast ? 80 : 72,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: highContrast ? 13 : 12, fontWeight: FontWeight.w700, color: scheme.onSurface),
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
