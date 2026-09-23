import 'package:doctor_reference/core/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doctor_reference/core/data/medical_repository.dart';
import 'package:doctor_reference/core/data/api_medical_repository.dart';
import 'package:doctor_reference/core/models/medical_content.dart';

class _EmptyRemoteRepository implements MedicalRepository {
  @override
  Future<List<MedicalItem>> search(String query) async => const [];

  @override
  Future<List<MedicalItem>> byType(ContentType type) async => const [];

  @override
  Future<MedicalItem?> getById(String id) async => null;

  @override
  Future<List<MedicalItem>> getByIds(Iterable<String> ids) async => const [];
}

class _DuplicateRemoteRepository implements MedicalRepository {
  @override
  Future<List<MedicalItem>> search(String query) async {
    final item = MedicalItem(
      id: 'remote-1',
      type: ContentType.article,
      title: 'Повторяемая статья',
      subtitle: '',
      category: 'Медицина',
      icon: Icons.article_outlined,
      badge: 'Статья',
      sections: const {},
    );
    return [item, item];
  }

  @override
  Future<List<MedicalItem>> byType(ContentType type) async => const [];

  @override
  Future<MedicalItem?> getById(String id) async => null;

  @override
  Future<List<MedicalItem>> getByIds(Iterable<String> ids) async => const [];
}

class _UnorderedRemoteRepository implements MedicalRepository {
  @override
  Future<List<MedicalItem>> search(String query) async => [
        MedicalItem(
          id: 'article-1',
          type: ContentType.article,
          title: 'Поддерживающая терапия',
          subtitle: 'Обзор',
          category: 'Медицина',
          icon: Icons.article_outlined,
          badge: 'Статья',
          sections: const {},
        ),
        MedicalItem(
          id: 'article-2',
          type: ContentType.article,
          title: 'Гипертония',
          subtitle: 'Артериальное давление',
          category: 'Медицина',
          icon: Icons.article_outlined,
          badge: 'Статья',
          sections: const {},
        ),
      ];

  @override
  Future<List<MedicalItem>> byType(ContentType type) async => const [];

  @override
  Future<MedicalItem?> getById(String id) async => null;

  @override
  Future<List<MedicalItem>> getByIds(Iterable<String> ids) async => const [];
}

void main() {
  final repository = OfflineMedicalRepository();

  test('offline search includes section content', () async {
    final results = await repository.search('красные флаги');

    expect(
      results.map((item) => item.id),
      contains('hypertension'),
    );
  });

  test('batch lookup preserves requested order and ignores unknown ids', () async {
    final results = await repository.getByIds(
      const ['amoxicillin', 'hypertension', 'missing'],
    );

    expect(
      results.map((item) => item.id).toList(),
      ['amoxicillin', 'hypertension'],
    );
  });

  test('batch lookup supports local calculator records', () async {
    final results = await repository.getByIds(const ['bmi', 'egfr']);

    expect(
      results.map((item) => item.type),
      [ContentType.calculator, ContentType.calculator],
    );
  });

  test('resilient search falls back to local matches when remote is empty', () async {
    final resilient = ResilientMedicalRepository(
      _EmptyRemoteRepository(),
      OfflineMedicalRepository(),
    );

    final results = await resilient.search('индекс массы тела');

    expect(results.map((item) => item.id), contains('bmi'));
  });

  test('resilient search removes duplicate remote ids', () async {
    final resilient = ResilientMedicalRepository(
      _DuplicateRemoteRepository(),
      OfflineMedicalRepository(),
    );

    final results = await resilient.search('статья');

    expect(results.where((item) => item.id == 'remote-1'), hasLength(1));
  });

  test('resilient search ranks exact title matches before weaker matches', () async {
    final resilient = ResilientMedicalRepository(
      _UnorderedRemoteRepository(),
      OfflineMedicalRepository(),
    );

    final results = await resilient.search('гипертония');

    expect(results.first.id, 'article-2');
  });
  test('clinical note round-trip preserves the linked source', () {
    const note = ClinicalNote(
      text: 'Контролировать АД через неделю',
      sourceId: 'hypertension',
    );

    final restored = ClinicalNote.fromJson(note.toJson());

    expect(restored?.text, note.text);
    expect(restored?.sourceId, note.sourceId);
  });

}
