import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final calculatorFavoriteIdsProvider =
    NotifierProvider<CalculatorFavoriteController, Set<String>>(
      CalculatorFavoriteController.new,
    );

class CalculatorFavoriteController extends Notifier<Set<String>> {
  static const _storageKey = 'calculator_favorites_v1';
  bool _disposed = false;
  int _revision = 0;
  Future<void> _saveQueue = Future<void>.value();

  @override
  Set<String> build() {
    ref.onDispose(() => _disposed = true);
    _load();
    return <String>{};
  }

  void toggle(String id) {
    final next = {...state};
    if (!next.add(id)) {
      next.remove(id);
    }
    _revision++;
    state = next;
    _save(next);
  }

  Future<void> _load() async {
    final revision = _revision;
    final preferences = await SharedPreferences.getInstance();
    if (_disposed || revision != _revision) return;
    state = (preferences.getStringList(_storageKey) ?? const <String>[]).toSet();
  }

  void _save(Set<String> ids) {
    final snapshot = [...ids]..sort();
    _saveQueue = _saveQueue.then((_) async {
      if (_disposed) return;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(_storageKey, snapshot);
    });
  }
}

final recentCalculatorIdsProvider =
    NotifierProvider<RecentCalculatorController, List<String>>(
      RecentCalculatorController.new,
    );

class RecentCalculatorController extends Notifier<List<String>> {
  static const _storageKey = 'recent_calculators_v1';
  bool _disposed = false;
  int _revision = 0;
  Future<void> _saveQueue = Future<void>.value();

  @override
  List<String> build() {
    ref.onDispose(() => _disposed = true);
    _load();
    return const [];
  }

  void add(String id) {
    final next =
        [id, ...state.where((item) => item != id)].take(6).toList(growable: false);
    _revision++;
    state = next;
    _save(next);
  }

  Future<void> _load() async {
    final revision = _revision;
    final preferences = await SharedPreferences.getInstance();
    if (_disposed || revision != _revision) return;
    state = preferences.getStringList(_storageKey) ?? const <String>[];
  }

  void _save(List<String> ids) {
    final snapshot = List<String>.unmodifiable(ids);
    _saveQueue = _saveQueue.then((_) async {
      if (_disposed) return;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(_storageKey, snapshot);
    });
  }
}
