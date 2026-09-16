import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final bookmarkProvider = NotifierProvider<BookmarkController, Map<String, Set<String>>>(
  BookmarkController.new,
);

class BookmarkController extends Notifier<Map<String, Set<String>>> {
  static const _storageKey = 'document_section_bookmarks_v1';
  bool _disposed = false;

  @override
  Map<String, Set<String>> build() {
    ref.onDispose(() => _disposed = true);
    _load();
    return <String, Set<String>>{};
  }

  bool contains(String documentId, String section) =>
      state[documentId]?.contains(section) ?? false;

  void toggle(String documentId, String section) {
    final next = <String, Set<String>>{
      for (final entry in state.entries) entry.key: {...entry.value},
    };
    final sections = next.putIfAbsent(documentId, () => <String>{});
    if (!sections.add(section)) sections.remove(section);
    if (sections.isEmpty) next.remove(documentId);
    state = next;
    _save(next);
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (_disposed || raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      state = {
        for (final entry in decoded.entries)
          entry.key: (entry.value as List<dynamic>).cast<String>().toSet(),
      };
    } catch (_) {
      // Ignore corrupt local bookmark data and keep the empty state.
    }
  }

  Future<void> _save(Map<String, Set<String>> value) async {
    final encoded = {
      for (final entry in value.entries) entry.key: entry.value.toList()..sort(),
    };
    await (await SharedPreferences.getInstance()).setString(
      _storageKey,
      jsonEncode(encoded),
    );
  }
}
