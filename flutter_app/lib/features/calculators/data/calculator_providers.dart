import 'package:flutter_riverpod/flutter_riverpod.dart';

final calculatorFavoriteIdsProvider =
    NotifierProvider<CalculatorFavoriteController, Set<String>>(
      CalculatorFavoriteController.new,
    );

class CalculatorFavoriteController extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void toggle(String id) {
    state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};
  }
}

final recentCalculatorIdsProvider =
    NotifierProvider<RecentCalculatorController, List<String>>(
      RecentCalculatorController.new,
    );

class RecentCalculatorController extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void add(String id) {
    state = [id, ...state.where((item) => item != id)].take(6).toList();
  }
}
