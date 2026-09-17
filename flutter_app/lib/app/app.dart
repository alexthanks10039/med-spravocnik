import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/accessibility_controller.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import 'router.dart';

class DoctorReferenceApp extends ConsumerWidget {
  const DoctorReferenceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final accessibility = ref.watch(accessibilityProvider);
    return MaterialApp.router(
      title: 'MED SPRAVOCHNIK',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      highContrastTheme: AppTheme.lightHighContrast,
      highContrastDarkTheme: AppTheme.darkHighContrast,
      themeMode: themeMode,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: accessibility
                ? media.textScaler.clamp(minScaleFactor: 1.15, maxScaleFactor: 2.0)
                : media.textScaler,
          ),
          child: Semantics(
            container: true,
            label: accessibility ? 'Режим доступности включён' : null,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      routerConfig: appRouter,
    );
  }
}
