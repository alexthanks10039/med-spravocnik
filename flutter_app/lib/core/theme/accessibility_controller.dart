import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final accessibilityProvider = NotifierProvider<AccessibilityController, bool>(
  AccessibilityController.new,
);

class AccessibilityController extends Notifier<bool> {
  static const _key = 'accessibility_mode';
  bool _disposed = false;
  int _revision = 0;

  @override
  bool build() {
    ref.onDispose(() => _disposed = true);
    _restore();
    return false;
  }

  Future<void> _restore() async {
    final revision = _revision;
    final preferences = await SharedPreferences.getInstance();
    if (_disposed || revision != _revision) return;
    state = preferences.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    _revision++;
    state = enabled;
    final preferences = await SharedPreferences.getInstance();
    if (_disposed) return;
    await preferences.setBool(_key, enabled);
  }
}
