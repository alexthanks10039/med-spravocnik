import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medical_content.dart';
import 'api_medical_repository.dart';
import 'medical_repository.dart';

final medicalRepositoryProvider = Provider<MedicalRepository>((ref) {
  final api = ApiMedicalRepository();
  ref.onDispose(api.close);
  return ResilientMedicalRepository(api, OfflineMedicalRepository());
});

final searchQueryProvider = NotifierProvider<SearchQueryController, String>(SearchQueryController.new);

class SearchQueryController extends Notifier<String> {
  @override
  String build() => '';
  void update(String value) => state = value;
}

final searchResultsProvider = FutureProvider.autoDispose<List<MedicalItem>>((ref) => ref.watch(medicalRepositoryProvider).search(ref.watch(searchQueryProvider)));
final referenceSearchProvider = FutureProvider.autoDispose.family<List<MedicalItem>, String>((ref, query) => ref.watch(medicalRepositoryProvider).search(query));
final itemsByTypeProvider = FutureProvider.autoDispose.family<List<MedicalItem>, ContentType>((ref, type) => ref.watch(medicalRepositoryProvider).byType(type));
final itemProvider = FutureProvider.autoDispose.family<MedicalItem?, String>((ref, id) => ref.watch(medicalRepositoryProvider).getById(id));

final favoriteIdsProvider = NotifierProvider<FavoriteController, Set<String>>(FavoriteController.new);

final favoriteItemsProvider = FutureProvider.autoDispose<List<MedicalItem>>((ref) async {
  final ids = ref.watch(favoriteIdsProvider);
  if (ids.isEmpty) return const [];

  final repository = ref.watch(medicalRepositoryProvider);
  final found = await repository.getByIds(ids);
  final byId = {for (final item in found) item.id: item};
  return ids
      .map((id) => byId[id])
      .whereType<MedicalItem>()
      .toList(growable: false);
});

final relatedItemsProvider =
    FutureProvider.autoDispose.family<List<MedicalItem>, String>((ref, idsKey) async {
  final ids = idsKey
      .split(',')
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  if (ids.isEmpty) return const [];

  final repository = ref.watch(medicalRepositoryProvider);
  final found = await repository.getByIds(ids);
  final byId = {for (final item in found) item.id: item};
  return ids
      .map((id) => byId[id])
      .whereType<MedicalItem>()
      .toList(growable: false);
});

class ClinicalNote {
  const ClinicalNote({required this.text, this.sourceId});

  final String text;
  final String? sourceId;

  Map<String, Object?> toJson() => {
        'text': text,
        'sourceId': sourceId,
      };

  static ClinicalNote? fromJson(Object? value) {
    if (value is! Map<String, Object?>) return null;
    final text = value['text'];
    if (text is! String || text.trim().isEmpty) return null;
    final sourceId = value['sourceId'];
    return ClinicalNote(
      text: text.trim(),
      sourceId: sourceId is String && sourceId.trim().isNotEmpty
          ? sourceId.trim()
          : null,
    );
  }
}

final notesProvider = NotifierProvider<NotesController, List<ClinicalNote>>(
  NotesController.new,
);

class NotesController extends Notifier<List<ClinicalNote>> {
  static const _storageKey = 'clinical_notes_v2';
  static const _legacyStorageKey = 'clinical_notes';
  bool _disposed = false;
  int _revision = 0;
  Future<void> _saveQueue = Future<void>.value();

  @override
  List<ClinicalNote> build() {
    ref.onDispose(() => _disposed = true);
    _load();
    return <ClinicalNote>[];
  }

  void add(String note, {String? sourceId}) {
    final value = note.trim();
    if (value.isEmpty) return;
    final normalizedSourceId = sourceId?.trim();
    final next = [
      ClinicalNote(
        text: value,
        sourceId: normalizedSourceId == null || normalizedSourceId.isEmpty
            ? null
            : normalizedSourceId,
      ),
      ...state,
    ];
    _revision++;
    state = next;
    _save(next);
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.length) return;
    final next = [...state]..removeAt(index);
    _revision++;
    state = next;
    _save(next);
  }

  Future<void> _load() async {
    final revision = _revision;
    final preferences = await SharedPreferences.getInstance();
    if (_disposed || revision != _revision) return;

    final raw = preferences.getString(_storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List<Object?>) {
          state = decoded
              .map(ClinicalNote.fromJson)
              .whereType<ClinicalNote>()
              .toList(growable: false);
          return;
        }
      } catch (_) {
        // Fall through to the legacy string-list format.
      }
    }

    final legacy = preferences.getStringList(_legacyStorageKey) ?? const <String>[];
    state = legacy
        .map((text) => ClinicalNote(text: text))
        .toList(growable: false);
    if (legacy.isNotEmpty) {
      _save(state);
    }
  }

  void _save(List<ClinicalNote> notes) {
    final snapshot = List<ClinicalNote>.unmodifiable(notes);
    _saveQueue = _saveQueue.then((_) async {
      if (_disposed) return;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _storageKey,
        jsonEncode(snapshot.map((note) => note.toJson()).toList()),
      );
    });
  }

}

final historyIdsProvider =
    NotifierProvider<HistoryController, List<String>>(HistoryController.new);
class HistoryController extends Notifier<List<String>> {
  static const _storageKey = 'clinical_history_v1';
  bool _disposed = false;
  int _revision = 0;
  Future<void> _saveQueue = Future<void>.value();

  @override
  List<String> build() {
    ref.onDispose(() => _disposed = true);
    _load();
    return <String>[];
  }

  void record(String id) {
    final normalized = id.trim();
    if (normalized.isEmpty) return;
    final next = [normalized, ...state.where((item) => item != normalized)]
        .take(20)
        .toList(growable: false);
    _revision++;
    state = next;
    _save(next);
  }

  void clear() {
    _revision++;
    state = <String>[];
    _save(const <String>[]);
  }

  Future<void> _load() async {
    final revision = _revision;
    final preferences = await SharedPreferences.getInstance();
    if (_disposed || revision != _revision) return;
    state = preferences.getStringList(_storageKey) ?? <String>[];
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

class FavoriteController extends Notifier<Set<String>> {
  static const _storageKey = 'favorite_medical_item_ids';
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
