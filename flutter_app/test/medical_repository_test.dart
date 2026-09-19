import 'package:flutter_test/flutter_test.dart';

import 'package:doctor_reference/core/data/medical_repository.dart';
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

void main() {
  const repository = OfflineMedicalRepository();

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
    const resilient = ResilientMedicalRepository(
      _EmptyRemoteRepository(),
      OfflineMedicalRepository(),
    );

    final results = await resilient.search('индекс массы тела');

    expect(results.map((item) => item.id), contains('bmi'));
  });
}
