import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

class ThemeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';
  bool _disposed = false;
  int _revision = 0;

  @override
  ThemeMode build() {
    ref.onDispose(() => _disposed = true);
    _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    final revision = _revision;
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_key);
    if (_disposed || revision != _revision) return;
    state = switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    _revision++;
    state = mode;
    final preferences = await SharedPreferences.getInstance();
    if (_disposed) return;
    await preferences.setString(_key, mode.name);
  }
}
