import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final accessibilityProvider = NotifierProvider<AccessibilityController, bool>(
  AccessibilityController.new,
);

class AccessibilityController extends Notifier<bool> {
  static const _key = 'accessibility_mode';
  bool _disposed = false;
  int _revision = 0;
  Future<void> _saveQueue = Future<void>.value();

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
    final snapshot = enabled;
    _saveQueue = _saveQueue.then((_) async {
      if (_disposed) return;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_key, snapshot);
    });
  }
}
