import 'package:flutter_test/flutter_test.dart';
import 'package:medical_reference_app/src/app.dart';
import 'package:medical_reference_app/src/models.dart';
import 'package:medical_reference_app/src/settings_controller.dart';

void main() {
  testWidgets('shows the main medical navigation', (tester) async {
    await tester.pumpWidget(
      MedicalReferenceApp(settings: SettingsController()),
    );
    await tester.pump();

    expect(find.text('Калькуляторы'), findsOneWidget);
    expect(find.text('Расчёты'), findsOneWidget);
    expect(find.text('Протоколы'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
  });

  test('parses calculator result payload', () {
    final result = CalculationResult.fromJson({
      'success': true,
      'result': {
        'score_name': 'CKD-EPI 2021',
        'value': 50.2,
        'unit': 'mL/min/1.73m²',
        'interpretation': {
          'summary': 'G3a',
          'severity': 'mild',
          'recommendation': 'Monitor kidney function',
        },
        'component_scores': {'equation': 'CKD-EPI 2021'},
      },
    });

    expect(result.success, isTrue);
    expect(result.value, 50.2);
    expect(result.summary, 'G3a');
    expect(result.components['equation'], 'CKD-EPI 2021');
  });

  test('normalizes API base URL', () {
    expect(
      SettingsController.normalizeBaseUrl(' https://api.example.kz/// '),
      'https://api.example.kz',
    );
  });

  test('parses presentation document and structured table', () {
    final document = ProtocolDocument.fromJson({
      'document': {
        'doc_id': 'doc1',
        'title': 'HELLP-синдром',
        'icd10_codes': ['O14.2'],
      },
      'sections': [
        {
          'id': 'sec1',
          'title': 'Критерии',
          'path': 'Диагностика > Критерии',
          'blocks': [
            {
              'type': 'table',
              'table_id': 'table1',
              'title': 'Лабораторные значения',
              'render_mode': 'structured',
              'columns': ['Показатель', 'Значение'],
              'rows': [
                ['ЛДГ', '> 600 МЕ/л'],
              ],
            },
          ],
        },
      ],
      'empty': false,
    });

    expect(document.title, 'HELLP-синдром');
    expect(document.icd10Codes, ['O14.2']);
    expect(document.sections.single.blocks.single.table?.isStructured, isTrue);
  });
}
