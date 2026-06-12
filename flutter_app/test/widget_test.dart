import 'package:doctor_reference/app/app.dart';
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
}
