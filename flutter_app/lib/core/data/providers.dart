import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medical_content.dart';
import 'api_medical_repository.dart';
import 'medical_repository.dart';

final medicalRepositoryProvider = Provider<MedicalRepository>((ref) {
  return ResilientMedicalRepository(ApiMedicalRepository(), OfflineMedicalRepository());
});

final searchQueryProvider = NotifierProvider<SearchQueryController, String>(SearchQueryController.new);

class SearchQueryController extends Notifier<String> {
  @override
  String build() => '';
  void update(String value) => state = value;
}

final searchResultsProvider = FutureProvider<List<MedicalItem>>((ref) => ref.watch(medicalRepositoryProvider).search(ref.watch(searchQueryProvider)));
final referenceSearchProvider = FutureProvider.family<List<MedicalItem>, String>((ref, query) => ref.watch(medicalRepositoryProvider).search(query));
final recentItemsProvider = FutureProvider<List<MedicalItem>>((ref) => ref.watch(medicalRepositoryProvider).recent());
final itemsByTypeProvider = FutureProvider.family<List<MedicalItem>, ContentType>((ref, type) => ref.watch(medicalRepositoryProvider).byType(type));
final itemProvider = FutureProvider.family<MedicalItem?, String>((ref, id) => ref.watch(medicalRepositoryProvider).getById(id));

final favoriteIdsProvider = NotifierProvider<FavoriteController, Set<String>>(FavoriteController.new);

class FavoriteController extends Notifier<Set<String>> {
  static const _storageKey = 'favorite_medical_item_ids';
  bool _disposed = false;

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
    state = next;
    _save(next);
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    if (_disposed) return;
    state = (preferences.getStringList(_storageKey) ?? const <String>[]).toSet();
  }

  Future<void> _save(Set<String> ids) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_storageKey, ids.toList()..sort());
  }
}
