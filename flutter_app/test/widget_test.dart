import 'package:doctor_reference/app/app.dart';
import 'package:doctor_reference/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home screen exposes the primary clinical search', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: DoctorReferenceApp()));
    await tester.pumpAndSettle();
    expect(find.text('Что нужно уточнить?'), findsOneWidget);
    expect(find.text('Заболевание, препарат или калькулятор'), findsOneWidget);
  });

  testWidgets('calculator catalog opens a medical category', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DoctorReferenceApp()));
    await tester.pumpAndSettle();

    appRouter.go('/calculators');
    await tester.pumpAndSettle();

    expect(find.text('Медицинские направления'), findsOneWidget);
    expect(find.text('Нефрология'), findsOneWidget);

    await tester.tap(find.text('Общая практика'));
    await tester.pumpAndSettle();

    expect(find.text('Индекс массы тела'), findsOneWidget);
    expect(find.text('Все направления'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -360));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Рассчитать'));
    await tester.pumpAndSettle();
    expect(find.text('Результат'), findsOneWidget);
    expect(find.textContaining('кг/м²'), findsOneWidget);
  });
}
