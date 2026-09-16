import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final accessibilityProvider = NotifierProvider<AccessibilityController, bool>(
  AccessibilityController.new,
);

class AccessibilityController extends Notifier<bool> {
  static const _key = 'accessibility_mode';

  @override
  bool build() {
    _restore();
    return false;
  }

  Future<void> _restore() async {
    final enabled = (await SharedPreferences.getInstance()).getBool(_key) ?? false;
    state = enabled;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await (await SharedPreferences.getInstance()).setBool(_key, enabled);
  }
}
