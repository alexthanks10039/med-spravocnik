import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/widgets/clinical_widgets.dart';
import '../../../shared/widgets/screen_frame.dart';

class CalculatorsScreen extends StatefulWidget {
  const CalculatorsScreen({super.key});
  @override
  State<CalculatorsScreen> createState() => _CalculatorsScreenState();
}

class _CalculatorsScreenState extends State<CalculatorsScreen> {
  final weight = TextEditingController(text: '70');
  final height = TextEditingController(text: '175');
  final age = TextEditingController(text: '45');
  final creatinine = TextEditingController(text: '1.0');
  final search = TextEditingController();
  String sex = 'female';
  String query = '';
  String? bmiResult;
  String? egfrResult;

  @override
  void dispose() {
    for (final controller in [weight, height, age, creatinine, search]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 780;
    final calculators = [
      (searchText: 'индекс массы тела bmi вес рост', card: _bmiCard(context)),
      (
        searchText: 'egfr ckd epi функция почек креатинин скф',
        card: _egfrCard(context),
      ),
    ];
    final normalizedQuery = query.trim().toLowerCase();
    final visible = calculators
        .where(
          (calculator) =>
              normalizedQuery.isEmpty ||
              calculator.searchText.contains(normalizedQuery),
        )
        .toList();

    return ScreenFrame(
      title: 'Калькуляторы',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReferenceSearchPanel(
            controller: search,
            query: query,
            onChanged: (value) => setState(() => query = value),
            hintText: 'Найти калькулятор',
            shortcuts: const [
              SearchShortcut('Все', value: ''),
              SearchShortcut('BMI', value: 'bmi'),
              SearchShortcut('eGFR', value: 'egfr'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            visible.isEmpty
                ? 'Нет совпадений'
                : 'Доступно калькуляторов: ${visible.length}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          if (visible.isEmpty)
            const StatePanel.empty(
              title: 'Калькулятор не найден',
              message: 'Попробуйте другое название или медицинский термин.',
            )
          else if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < visible.length; index++) ...[
                  if (index > 0) const SizedBox(width: 14),
                  Expanded(child: visible[index].card),
                ],
              ],
            )
          else
            Column(
              children: [
                for (var index = 0; index < visible.length; index++) ...[
                  if (index > 0) const SizedBox(height: 14),
                  visible[index].card,
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _bmiCard(BuildContext context) => _CalculatorCard(
    title: 'Индекс массы тела',
    subtitle: 'BMI',
    icon: Icons.straighten,
    initiallyExpanded: true,
    result: bmiResult,
    fields: [
      TextField(
        controller: weight,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Вес, кг'),
      ),
      TextField(
        controller: height,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Рост, см'),
      ),
    ],
    onCalculate: () {
      final w = double.tryParse(weight.text.replaceAll(',', '.'));
      final h = double.tryParse(height.text.replaceAll(',', '.'));
      if (w == null || h == null || w <= 0 || h <= 0)
        return setState(() => bmiResult = 'Проверьте введённые значения');
      final bmi = w / math.pow(h / 100, 2);
      final category = bmi < 18.5
          ? 'ниже нормы'
          : bmi < 25
          ? 'норма'
          : bmi < 30
          ? 'избыточная масса'
          : 'ожирение';
      setState(() => bmiResult = '${bmi.toStringAsFixed(1)} кг/м² · $category');
    },
  );

  Widget _egfrCard(BuildContext context) => _CalculatorCard(
    title: 'eGFR CKD-EPI 2021',
    subtitle: 'Функция почек',
    icon: Icons.water_drop_outlined,
    initiallyExpanded: false,
    result: egfrResult,
    fields: [
      TextField(
        controller: age,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Возраст'),
      ),
      TextField(
        controller: creatinine,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Креатинин, мг/дл'),
      ),
      DropdownButtonFormField<String>(
        initialValue: sex,
        decoration: const InputDecoration(labelText: 'Пол'),
        items: const [
          DropdownMenuItem(value: 'female', child: Text('Женский')),
          DropdownMenuItem(value: 'male', child: Text('Мужской')),
        ],
        onChanged: (value) => setState(() => sex = value!),
      ),
    ],
    onCalculate: () {
      final years = int.tryParse(age.text);
      final cr = double.tryParse(creatinine.text.replaceAll(',', '.'));
      if (years == null || cr == null || years < 18 || cr <= 0)
        return setState(() => egfrResult = 'Проверьте введённые значения');
      final k = sex == 'female' ? .7 : .9;
      final alpha = sex == 'female' ? -.241 : -.302;
      final ratio = cr / k;
      final value =
          142 *
          math.pow(math.min(ratio, 1), alpha) *
          math.pow(math.max(ratio, 1), -1.2) *
          math.pow(.9938, years) *
          (sex == 'female' ? 1.012 : 1);
      setState(() => egfrResult = '${value.round()} мл/мин/1,73 м²');
    },
  );
}

class _CalculatorCard extends StatefulWidget {
  const _CalculatorCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.fields,
    required this.onCalculate,
    required this.initiallyExpanded,
    this.result,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> fields;
  final VoidCallback onCalculate;
  final bool initiallyExpanded;
  final String? result;

  @override
  State<_CalculatorCard> createState() => _CalculatorCardState();
}

class _CalculatorCardState extends State<_CalculatorCard> {
  late bool expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => expanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  CircleAvatar(child: Icon(widget.icon)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? .5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 240),
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                ...widget.fields.expand(
                  (field) => [field, const SizedBox(height: 12)],
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.onCalculate,
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('Рассчитать'),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: widget.result == null
                      ? const SizedBox.shrink()
                      : Padding(
                          key: ValueKey(widget.result),
                          padding: const EdgeInsets.only(top: 14),
                          child: Card(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.analytics_outlined,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Результат',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelLarge,
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          widget.result!,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Используйте результат вместе с клинической оценкой.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
