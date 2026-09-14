import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/medical_content.dart';
import 'medical_repository.dart';

class ApiMedicalRepository implements MedicalRepository {
  ApiMedicalRepository({String? baseUrl}) : baseUrl = (baseUrl ?? const String.fromEnvironment('MED_API_URL', defaultValue: 'http://localhost:4000/api')).replaceFirst(RegExp(r'/$'), '');

  final String baseUrl;

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) throw HttpException('HTTP ${response.statusCode}');
      return jsonDecode(body);
    } finally {
      client.close(force: true);
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
    if (query.trim().isEmpty) return recent();
    final q = query.trim();
    final responses = await Future.wait([
      _get('/diseases', {'q': q}),
      _get('/drugs', {'q': q}),
      _get('/articles', {'q': q}),
    ]);
    final types = const [ContentType.disease, ContentType.drug, ContentType.article];
    final result = <MedicalItem>[];
    for (var i = 0; i < responses.length; i++) {
      final data = responses[i] as List<dynamic>;
      result.addAll(data.map((x) => _map(types[i], x as Map<String, dynamic>)));
    }
    return result;
  }

  @override
  Future<List<MedicalItem>> byType(ContentType type) async {
    if (type == ContentType.calculator) return const [];
    final data = await _get(_path(type)) as List<dynamic>;
    return data.map((x) => _map(type, x as Map<String, dynamic>)).toList();
  }

  @override
  Future<MedicalItem?> getById(String id) async {
    for (final type in const [ContentType.disease, ContentType.drug, ContentType.article]) {
      try {
        return _map(type, await _get('${_path(type)}/$id') as Map<String, dynamic>);
      } on HttpException {
        // Try the next content type.
      }
    }
    return null;
  }

  @override
  Future<List<MedicalItem>> recent() async {
    final lists = await Future.wait([
      byType(ContentType.disease),
      byType(ContentType.drug),
      byType(ContentType.article),
    ]);
    return lists.expand((x) => x).take(6).toList();
  }

  MedicalItem _map(ContentType type, Map<String, dynamic> d) {
    final id = _s(d['id']);
    final title = type == ContentType.article ? _s(d['title']) : _s(d['name']);
    final category = _s(d['category'], type == ContentType.drug ? 'Препараты' : 'Медицина');
    if (type == ContentType.disease) {
      return MedicalItem(id: id, type: type, title: title, subtitle: _s(d['icd10']), category: category, icon: Icons.favorite_outline, badge: _n(d['icd10']), sections: _sections({'Симптомы': d['symptoms'], 'Диагностика': d['diagnostics'], 'Лечение': d['treatment']}));
    }
    if (type == ContentType.drug) {
      return MedicalItem(id: id, type: type, title: title, subtitle: _s(d['internationalName'], _s(d['form'])), category: category, icon: Icons.medication_outlined, badge: 'Rx', sections: _sections({'Форма': d['form'], 'Дозирование': d['dosage'], 'Показания': d['indications'], 'Противопоказания': d['contraindications'], 'Нежелательные реакции': d['sideEffects']}));
    }
    return MedicalItem(id: id, type: type, title: title, subtitle: _s(d['description']), category: category, icon: Icons.article_outlined, badge: 'Статья', sections: _sections({'Содержание': d['content']}));
  }

  Map<String, String> _sections(Map<String, dynamic> values) => {
        for (final entry in values.entries)
          if (_s(entry.value).isNotEmpty) entry.key: _s(entry.value),
      };

  String _s(dynamic value, [String fallback = '']) => value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  String? _n(dynamic value) => _s(value).isEmpty ? null : _s(value);
}

class ResilientMedicalRepository implements MedicalRepository {
  const ResilientMedicalRepository(this.remote, this.offline);
  final MedicalRepository remote;
  final MedicalRepository offline;

  Future<T> _run<T>(Future<T> Function() action, Future<T> Function() fallback) async {
    try { return await action(); } catch (_) { return fallback(); }
  }

  @override
  Future<List<MedicalItem>> search(String q) => _run(() => remote.search(q), () => offline.search(q));
  @override
  Future<List<MedicalItem>> byType(ContentType t) => _run(() => remote.byType(t), () => offline.byType(t));
  @override
  Future<MedicalItem?> getById(String id) => _run(() => remote.getById(id), () => offline.getById(id));
  @override
  Future<List<MedicalItem>> recent() => _run(() => remote.recent(), () => offline.recent());
}
