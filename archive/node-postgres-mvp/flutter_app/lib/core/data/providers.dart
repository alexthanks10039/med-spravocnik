import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/medical_content.dart';
import 'medical_repository.dart';

final medicalRepositoryProvider = Provider<MedicalRepository>(
  (ref) => OfflineMedicalRepository(),
);
final searchQueryProvider = NotifierProvider<SearchQueryController, String>(
  SearchQueryController.new,
);

class SearchQueryController extends Notifier<String> {
  @override
  String build() => '';
  void update(String value) => state = value;
}

final searchResultsProvider = FutureProvider<List<MedicalItem>>((ref) {
  return ref
      .watch(medicalRepositoryProvider)
      .search(ref.watch(searchQueryProvider));
});

final referenceSearchProvider =
    FutureProvider.family<List<MedicalItem>, String>(
      (ref, query) => ref.watch(medicalRepositoryProvider).search(query),
    );

final recentItemsProvider = FutureProvider<List<MedicalItem>>(
  (ref) => ref.watch(medicalRepositoryProvider).recent(),
);
final itemsByTypeProvider =
    FutureProvider.family<List<MedicalItem>, ContentType>(
      (ref, type) => ref.watch(medicalRepositoryProvider).byType(type),
    );
final itemProvider = FutureProvider.family<MedicalItem?, String>(
  (ref, id) => ref.watch(medicalRepositoryProvider).getById(id),
);

final favoriteIdsProvider = NotifierProvider<FavoriteController, Set<String>>(
  FavoriteController.new,
);

class FavoriteController extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{'hypertension'};
  void toggle(String id) =>
      state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};
}
