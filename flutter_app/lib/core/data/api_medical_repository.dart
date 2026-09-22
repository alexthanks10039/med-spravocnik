import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/medical_content.dart';
import 'medical_repository.dart';

class _ApiHttpException implements Exception {
  const _ApiHttpException(this.statusCode, this.uri);

  final int statusCode;
  final Uri uri;
}

class ApiMedicalRepository implements MedicalRepository {
  ApiMedicalRepository({String? baseUrl, http.Client? client})
      : baseUrl = (baseUrl ?? const String.fromEnvironment('MED_API_URL'))
            .trim()
            .replaceFirst(RegExp(r'/$'), ''),
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  void close() => _client.close();

  Future<Object?> _get(String path, [Map<String, String>? query]) async {
    if (baseUrl.isEmpty) {
      throw StateError('MED_API_URL is not configured');
    }

    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _ApiHttpException(response.statusCode, uri);
    }

    return jsonDecode(response.body);
  }

  Future<List<Object?>> _getListBestEffort(
    String path,
    Map<String, String> query,
  ) async {
    try {
      final data = await _get(path, query);
      if (data is! List<Object?>) {
        throw const FormatException('Invalid list response');
      }
      return data;
    } catch (_) {
      return const <Object?>[];
    }
  }

  String _path(ContentType type) => switch (type) {
        ContentType.disease => '/diseases',
        ContentType.drug => '/drugs',
        ContentType.article => '/articles',
        ContentType.calculator => throw ArgumentError('Calculators are local'),
      };

  @override
  Future<List<MedicalItem>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final responses = await Future.wait([
      _getListBestEffort('/diseases', {'q': q, 'limit': '30'}),
      _getListBestEffort('/drugs', {'q': q, 'limit': '30'}),
      _getListBestEffort('/articles', {'q': q, 'limit': '30'}),
    ]);
    final types = const [
      ContentType.disease,
      ContentType.drug,
      ContentType.article,
    ];
    final result = <MedicalItem>[];
    final seenIds = <String>{};
    for (var i = 0; i < responses.length; i++) {
      for (final raw in responses[i].whereType<Map<String, dynamic>>()) {
        final item = _map(types[i], raw);
        if (item.id.isNotEmpty && seenIds.add(item.id)) result.add(item);
      }
    }
    return result;
  }

  @override
  Future<List<MedicalItem>> byType(ContentType type) async {
    if (type == ContentType.calculator) return const [];
    final data = await _get(_path(type), {'limit': '100'}) as List<Object?>;
    return data
        .whereType<Map<String, dynamic>>()
        .map((x) => _map(type, x))
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<MedicalItem?> getById(String id) async {
    final items = await getByIds([id]);
    return items.isEmpty ? null : items.first;
  }

  @override
  Future<List<MedicalItem>> getByIds(Iterable<String> ids) async {
    final normalizedIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedIds.isEmpty) return const [];

    final data = await _get(
      '/content',
      {'ids': normalizedIds.join(',')},
    );

    if (data is! List<Object?>) {
      throw const FormatException('Invalid content batch response');
    }

    final result = <MedicalItem>[];
    final seenIds = <String>{};
    for (final item in data.whereType<Map<String, dynamic>>()) {
      final typeName = _s(item['type']);
      final rawType = switch (typeName) {
        'disease' => ContentType.disease,
        'drug' => ContentType.drug,
        'article' => ContentType.article,
        _ => null,
      };
      if (rawType == null) continue;

      final payload = Map<String, dynamic>.from(item)..remove('type');
      final mapped = _map(rawType, payload);
      if (mapped.id.isNotEmpty && seenIds.add(mapped.id)) result.add(mapped);
    }
    return result;
  }

  MedicalItem _map(ContentType type, Map<String, dynamic> d) {
    final id = _s(d['id']);
    final title = type == ContentType.article ? _s(d['title']) : _s(d['name']);
    final category = _s(
      d['category'],
      type == ContentType.drug ? 'Препараты' : 'Медицина',
    );

    if (type == ContentType.disease) {
      return MedicalItem(
        id: id,
        type: type,
        title: title,
        subtitle: _s(d['icd10']),
        category: category,
        icon: Icons.favorite_outline,
        badge: _n(d['icd10']),
        sections: _sections({
          'Симптомы': d['symptoms'],
          'Диагностика': d['diagnostics'],
          'Лечение': d['treatment'],
        }),
      );
    }

    if (type == ContentType.drug) {
      return MedicalItem(
        id: id,
        type: type,
        title: title,
        subtitle: _s(d['internationalName'], _s(d['form'])),
        category: category,
        icon: Icons.medication_outlined,
        badge: 'Rx',
        sections: _sections({
          'Форма': d['form'],
          'Дозирование': d['dosage'],
          'Показания': d['indications'],
          'Противопоказания': d['contraindications'],
          'Нежелательные реакции': d['sideEffects'],
        }),
      );
    }

    return MedicalItem(
      id: id,
      type: type,
      title: title,
      subtitle: _s(d['description']),
      category: category,
      icon: Icons.article_outlined,
      badge: 'Статья',
      sections: _sections({'Содержание': d['content']}),
    );
  }

  Map<String, String> _sections(Map<String, Object?> values) => {
        for (final entry in values.entries)
          if (_s(entry.value).isNotEmpty) entry.key: _s(entry.value),
      };

  String _s(Object? value, [String fallback = '']) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;

  String? _n(Object? value) => _s(value).isEmpty ? null : _s(value);
}

class ResilientMedicalRepository implements MedicalRepository {
  const ResilientMedicalRepository(this.remote, this.offline);

  final MedicalRepository remote;
  final MedicalRepository offline;

  Future<T> _run<T>(Future<T> Function() action, Future<T> Function() fallback) async {
    try {
      return await action();
    } catch (_) {
      return fallback();
    }
  }

  @override
  Future<List<MedicalItem>> search(String q) async {
    final normalizedQuery = q.trim();
    if (normalizedQuery.isEmpty) return offline.search(q);

    List<MedicalItem> remoteItems;
    try {
      remoteItems = await remote.search(q);
    } catch (_) {
      return offline.search(q);
    }

    final localMatches = await offline.search(q);
    final result = <MedicalItem>[];
    final seenIds = <String>{};

    void addUnique(Iterable<MedicalItem> items) {
      for (final item in items) {
        if (item.id.isNotEmpty && seenIds.add(item.id)) result.add(item);
      }
    }

    if (remoteItems.isEmpty) {
      addUnique(localMatches);
      return _rank(normalizedQuery, result);
    }

    addUnique(remoteItems);
    addUnique(
      localMatches.where((item) => item.type == ContentType.calculator),
    );
    return _rank(normalizedQuery, result);
  }

  List<MedicalItem> _rank(String query, List<MedicalItem> items) {
    final needle = query.toLowerCase();
    int score(MedicalItem item) {
      final title = item.title.toLowerCase();
      final subtitle = item.subtitle.toLowerCase();
      final category = item.category.toLowerCase();
      if (title == needle) return 0;
      if (title.startsWith(needle)) return 1;
      if (title.contains(needle)) return 2;
      if (subtitle.contains(needle)) return 3;
      if (category.contains(needle)) return 4;
      return 5;
    }

    final ranked = [...items];
    ranked.sort((a, b) => score(a).compareTo(score(b)));
    return ranked;
  }

  @override
  Future<List<MedicalItem>> byType(ContentType t) {
    if (t == ContentType.calculator) return offline.byType(t);
    return _run(() => remote.byType(t), () => offline.byType(t));
  }

  @override
  Future<MedicalItem?> getById(String id) async {
    final items = await getByIds([id]);
    return items.isEmpty ? null : items.first;
  }

  @override
  Future<List<MedicalItem>> getByIds(Iterable<String> ids) async {
    final normalizedIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (normalizedIds.isEmpty) return const [];

    try {
      final remoteItems = await remote.getByIds(normalizedIds);
      final remoteIds = remoteItems.map((item) => item.id).toSet();
      final missingIds = normalizedIds.where((id) => !remoteIds.contains(id));
      if (missingIds.isEmpty) return remoteItems;

      final localItems = await offline.getByIds(missingIds);
      return [...remoteItems, ...localItems];
    } catch (_) {
      return offline.getByIds(normalizedIds);
    }
  }
}
