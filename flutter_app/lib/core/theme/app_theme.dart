import 'package:flutter/material.dart';

abstract final class AppColors {
  static const teal = Color(0xFF087F7A);
  static const tealDark = Color(0xFF05625F);
  static const tealSoft = Color(0xFFE4F3F1);
  static const cyan = Color(0xFF37B9C6);
  static const warning = Color(0xFFC77A12);
  static const danger = Color(0xFFC43F52);
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
      primary: dark ? const Color(0xFF73D8D2) : AppColors.teal,
      onPrimary: dark ? const Color(0xFF003735) : Colors.white,
      primaryContainer: dark ? const Color(0xFF16413F) : AppColors.tealSoft,
      onPrimaryContainer: dark ? const Color(0xFFB5F0EA) : AppColors.tealDark,
      secondary: dark ? const Color(0xFF7DDCE5) : AppColors.cyan,
      surface: dark ? const Color(0xFF111A1E) : Colors.white,
      surfaceContainerLow: dark ? const Color(0xFF151F23) : const Color(0xFFF9FBFB),
      surfaceContainer: dark ? const Color(0xFF19252A) : const Color(0xFFF1F5F5),
      error: dark ? const Color(0xFFFFB3BD) : AppColors.danger,
      contrastLevel: highContrast ? 1.0 : 0.0,
    );
    final outline = highContrast
        ? (dark ? Colors.white70 : Colors.black87)
        : scheme.outlineVariant.withValues(alpha: .65);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF0B1114) : const Color(0xFFF6F8F8),
      visualDensity: highContrast ? VisualDensity.comfortable : VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      textTheme: TextTheme(
        displaySmall: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.4, height: 1.05),
        headlineLarge: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.1),
        headlineMedium: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.7),
        titleLarge: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -.2),
        titleMedium: const TextStyle(fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(height: 1.55, fontWeight: highContrast ? FontWeight.w600 : FontWeight.w400),
        bodyMedium: TextStyle(height: 1.5, fontWeight: highContrast ? FontWeight.w600 : FontWeight.w400),
        labelLarge: const TextStyle(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: outline, width: highContrast ? 1.5 : 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF172328) : Colors.white,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: .8)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: outline)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: highContrast ? 3 : 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: highContrast ? 19 : 15),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: highContrast ? 13 : 12, fontWeight: FontWeight.w700, color: scheme.onSurface),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        selectedLabelTextStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
