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

  String _path(ContentType type) => switch (type) {
        ContentType.disease => '/diseases',
        ContentType.drug => '/drugs',
        ContentType.article => '/articles',
        ContentType.calculator => throw ArgumentError('Calculators are local'),
      };

  @override
  Future<List<MedicalItem>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return recent();

    final responses = await Future.wait([
      _get('/diseases', {'q': q, 'limit': '30'}),
      _get('/drugs', {'q': q, 'limit': '30'}),
      _get('/articles', {'q': q, 'limit': '30'}),
    ]);
    final types = const [
      ContentType.disease,
      ContentType.drug,
      ContentType.article,
    ];
    final result = <MedicalItem>[];
    for (var i = 0; i < responses.length; i++) {
      final data = responses[i] as List<Object?>;
      result.addAll(
        data.whereType<Map<String, dynamic>>().map((x) => _map(types[i], x)),
      );
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
      result.add(_map(rawType, payload));
    }
    return result;
  }


  @override
  Future<List<MedicalItem>> recent() async {
    final lists = await Future.wait([
      _get('/diseases', {'limit': '2'}),
      _get('/drugs', {'limit': '2'}),
      _get('/articles', {'limit': '2'}),
    ]);
    final types = const [
      ContentType.disease,
      ContentType.drug,
      ContentType.article,
    ];
    final result = <MedicalItem>[];
    for (var i = 0; i < lists.length; i++) {
      final data = lists[i] as List<Object?>;
      result.addAll(
        data.whereType<Map<String, dynamic>>().map((x) => _map(types[i], x)),
      );
    }
    return result.take(6).toList(growable: false);
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
    List<MedicalItem> remoteItems;
    try {
      remoteItems = await remote.search(q);
    } catch (_) {
      return offline.search(q);
    }

    final localCalculators = await offline.search(q).then(
      (items) => items.where((item) => item.type == ContentType.calculator),
    );
    final ids = remoteItems.map((item) => item.id).toSet();
    return [
      ...remoteItems,
      ...localCalculators.where((item) => ids.add(item.id)),
    ];
  }

  @override
  Future<List<MedicalItem>> byType(ContentType t) {
    if (t == ContentType.calculator) return offline.byType(t);
    return _run(() => remote.byType(t), () => offline.byType(t));
  }

  @override
  Future<MedicalItem?> getById(String id) async {
    try {
      final remoteItem = await remote.getById(id);
      return remoteItem ?? await offline.getById(id);
    } catch (_) {
      return offline.getById(id);
    }
  }

  @override
  Future<List<MedicalItem>> recent() => _run(() => remote.recent(), () => offline.recent());
}
