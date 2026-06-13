import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/clinical_widgets.dart';
import '../../../shared/widgets/screen_frame.dart';
import '../data/calculator_catalog.dart';
import '../data/calculator_providers.dart';
import '../domain/calculator_models.dart';

class CalculatorsScreen extends ConsumerStatefulWidget {
  const CalculatorsScreen({super.key});

  @override
  ConsumerState<CalculatorsScreen> createState() => _CalculatorsScreenState();
}

class _CalculatorsScreenState extends ConsumerState<CalculatorsScreen> {
  final search = TextEditingController();
  String query = '';
  CalculatorCollection collection = CalculatorCollection.all;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(calculatorFavoriteIdsProvider);
    final recent = ref.watch(recentCalculatorIdsProvider);
    final normalizedQuery = query.trim().toLowerCase();
    final visibleCategories = calculatorCategories
        .where((category) {
          final calculators = calculatorsForCategory(category.id);
          final matchesQuery =
              normalizedQuery.isEmpty ||
              category.title.toLowerCase().contains(normalizedQuery) ||
              category.searchTerms.contains(normalizedQuery) ||
              calculators.any(
                (calculator) =>
                    calculator.title.toLowerCase().contains(normalizedQuery) ||
                    calculator.searchTerms.contains(normalizedQuery),
              );
          if (!matchesQuery) return false;

          return switch (collection) {
            CalculatorCollection.all => true,
            CalculatorCollection.popular => calculators.any(
              (calculator) => calculator.isPopular,
            ),
            CalculatorCollection.recent => calculators.any(
              (calculator) => recent.contains(calculator.id),
            ),
            CalculatorCollection.favorites => calculators.any(
              (calculator) => favorites.contains(calculator.id),
            ),
          };
        })
        .toList(growable: false);

    return ScreenFrame(
      title: 'Калькуляторы',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: search,
            onChanged: (value) => setState(() => query = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Найти калькулятор или направление',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Очистить поиск',
                      onPressed: () {
                        search.clear();
                        setState(() => query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          _QuickAccessBar(
            selected: collection,
            onSelected: (value) => setState(() => collection = value),
          ),
          const SizedBox(height: 24),
          SectionHeader(
            _collectionTitle(collection),
            action: collection == CalculatorCollection.all ? null : 'Все',
            onAction: () =>
                setState(() => collection = CalculatorCollection.all),
          ),
          const SizedBox(height: 12),
          if (visibleCategories.isEmpty)
            StatePanel.empty(
              title: _emptyTitle(collection),
              message: normalizedQuery.isNotEmpty
                  ? 'Измените поисковый запрос или выберите другой фильтр.'
                  : 'Используйте калькулятор или добавьте его в избранное.',
              actionLabel: 'Показать все',
              onAction: () => setState(() {
                collection = CalculatorCollection.all;
                query = '';
                search.clear();
              }),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1000
                    ? 3
                    : constraints.maxWidth >= 640
                    ? 2
                    : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleCategories.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: columns == 1 ? 1.65 : 1.55,
                  ),
                  itemBuilder: (context, index) {
                    final category = visibleCategories[index];
                    return _CategoryCard(
                      category: category,
                      calculatorCount: calculatorsForCategory(
                        category.id,
                      ).length,
                      onTap: () =>
                          context.push('/calculators/category/${category.id}'),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  String _collectionTitle(CalculatorCollection value) => switch (value) {
    CalculatorCollection.all => 'Медицинские направления',
    CalculatorCollection.popular => 'Популярные направления',
    CalculatorCollection.recent => 'Недавно использованные',
    CalculatorCollection.favorites => 'Избранные калькуляторы',
  };

  String _emptyTitle(CalculatorCollection value) => switch (value) {
    CalculatorCollection.all => 'Ничего не найдено',
    CalculatorCollection.popular => 'Популярных калькуляторов нет',
    CalculatorCollection.recent => 'История пока пуста',
    CalculatorCollection.favorites => 'В избранном пока пусто',
  };
}

class CalculatorCategoryScreen extends ConsumerStatefulWidget {
  const CalculatorCategoryScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  ConsumerState<CalculatorCategoryScreen> createState() =>
      _CalculatorCategoryScreenState();
}

class _CalculatorCategoryScreenState
    extends ConsumerState<CalculatorCategoryScreen> {
  final search = TextEditingController();
  final weight = TextEditingController(text: '70');
  final height = TextEditingController(text: '175');
  final age = TextEditingController(text: '45');
  final creatinine = TextEditingController(text: '1.0');
  String sex = 'female';
  String query = '';
  CalculationResult? bmiResult;
  CalculationResult? egfrResult;

  @override
  void dispose() {
    for (final controller in [search, weight, height, age, creatinine]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final category = calculatorCategoryById(widget.categoryId);
    if (category == null) {
      return ScreenFrame(
        title: 'Калькуляторы',
        child: StatePanel.error(
          title: 'Раздел не найден',
          message: 'Вернитесь к списку медицинских направлений.',
          actionLabel: 'К категориям',
          onAction: () => context.go('/calculators'),
        ),
      );
    }

    final favorites = ref.watch(calculatorFavoriteIdsProvider);
    final normalizedQuery = query.trim().toLowerCase();
    final calculators = calculatorsForCategory(category.id)
        .where(
          (calculator) =>
              normalizedQuery.isEmpty ||
              calculator.title.toLowerCase().contains(normalizedQuery) ||
              calculator.searchTerms.contains(normalizedQuery),
        )
        .toList(growable: false);

    return ScreenFrame(
      title: category.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/calculators'),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Все направления'),
          ),
          const SizedBox(height: 8),
          _CategoryHero(category: category),
          const SizedBox(height: 20),
          ReferenceSearchPanel(
            controller: search,
            query: query,
            onChanged: (value) => setState(() => query = value),
            hintText: 'Поиск в разделе «${category.title}»',
            shortcuts: const [],
          ),
          const SizedBox(height: 20),
          Text(
            calculators.isEmpty
                ? 'Калькуляторы не найдены'
                : 'Калькуляторов: ${calculators.length}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          if (calculators.isEmpty)
            StatePanel.empty(
              title: normalizedQuery.isEmpty
                  ? 'Раздел готовится'
                  : 'Калькулятор не найден',
              message: normalizedQuery.isEmpty
                  ? 'Новые проверенные формулы появятся здесь в следующих обновлениях.'
                  : 'Попробуйте другое название или медицинский термин.',
              actionLabel: normalizedQuery.isEmpty ? null : 'Очистить поиск',
              onAction: normalizedQuery.isEmpty
                  ? null
                  : () => setState(() {
                      query = '';
                      search.clear();
                    }),
            )
          else
            ...calculators.indexed.expand((entry) {
              final (index, calculator) = entry;
              return [
                if (index > 0) const SizedBox(height: 14),
                _buildCalculatorCard(
                  calculator,
                  favorites.contains(calculator.id),
                ),
              ];
            }),
        ],
      ),
    );
  }

  Widget _buildCalculatorCard(
    CalculatorDefinition calculator,
    bool isFavorite,
  ) {
    void toggleFavorite() {
      ref.read(calculatorFavoriteIdsProvider.notifier).toggle(calculator.id);
    }

    return switch (calculator.id) {
      'bmi' => _CalculatorCard(
        title: calculator.title,
        subtitle: calculator.subtitle,
        icon: calculator.icon,
        initiallyExpanded: true,
        isFavorite: isFavorite,
        onFavorite: toggleFavorite,
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
        onCalculate: _calculateBmi,
      ),
      'egfr-ckd-epi-2021' => _CalculatorCard(
        title: calculator.title,
        subtitle: calculator.subtitle,
        icon: calculator.icon,
        initiallyExpanded: true,
        isFavorite: isFavorite,
        onFavorite: toggleFavorite,
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
            onChanged: (value) => setState(() => sex = value ?? sex),
          ),
        ],
        onCalculate: _calculateEgfr,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  void _calculateBmi() {
    ref.read(recentCalculatorIdsProvider.notifier).add('bmi');
    final valueWeight = double.tryParse(weight.text.replaceAll(',', '.'));
    final valueHeight = double.tryParse(height.text.replaceAll(',', '.'));
    if (valueWeight == null ||
        valueHeight == null ||
        valueWeight <= 0 ||
        valueHeight <= 0) {
      setState(
        () => bmiResult = const CalculationResult(
          value: 'Проверьте значения',
          interpretation: 'Вес и рост должны быть положительными числами.',
        ),
      );
      return;
    }
    final bmi = valueWeight / math.pow(valueHeight / 100, 2);
    final interpretation = bmi < 18.5
        ? 'Масса тела ниже рекомендуемого диапазона.'
        : bmi < 25
        ? 'Значение находится в стандартном диапазоне.'
        : bmi < 30
        ? 'Избыточная масса тела.'
        : 'Значение соответствует диапазону ожирения.';
    setState(
      () => bmiResult = CalculationResult(
        value: '${bmi.toStringAsFixed(1)} кг/м²',
        interpretation: interpretation,
      ),
    );
  }

  void _calculateEgfr() {
    ref.read(recentCalculatorIdsProvider.notifier).add('egfr-ckd-epi-2021');
    final years = int.tryParse(age.text);
    final cr = double.tryParse(creatinine.text.replaceAll(',', '.'));
    if (years == null || cr == null || years < 18 || cr <= 0) {
      setState(
        () => egfrResult = const CalculationResult(
          value: 'Проверьте значения',
          interpretation:
              'Формула применяется у взрослых; креатинин должен быть больше нуля.',
        ),
      );
      return;
    }
    final k = sex == 'female' ? .7 : .9;
    final alpha = sex == 'female' ? -.241 : -.302;
    final ratio = cr / k;
    final value =
        142 *
        math.pow(math.min(ratio, 1), alpha) *
        math.pow(math.max(ratio, 1), -1.2) *
        math.pow(.9938, years) *
        (sex == 'female' ? 1.012 : 1);
    final rounded = value.round();
    final interpretation = rounded >= 90
        ? 'Сохранённая или высокая расчётная фильтрация.'
        : rounded >= 60
        ? 'Незначительное снижение расчётной фильтрации.'
        : rounded >= 30
        ? 'Умеренное снижение расчётной фильтрации.'
        : rounded >= 15
        ? 'Выраженное снижение расчётной фильтрации.'
        : 'Критически низкая расчётная фильтрация.';
    setState(
      () => egfrResult = CalculationResult(
        value: '$rounded мл/мин/1,73 м²',
        interpretation: interpretation,
      ),
    );
  }
}

class CalculationResult {
  const CalculationResult({required this.value, required this.interpretation});

  final String value;
  final String interpretation;
}

class _QuickAccessBar extends StatelessWidget {
  const _QuickAccessBar({required this.selected, required this.onSelected});

  final CalculatorCollection selected;
  final ValueChanged<CalculatorCollection> onSelected;

  static const items = [
    (CalculatorCollection.all, 'Все', Icons.grid_view_rounded),
    (CalculatorCollection.popular, 'Популярные', Icons.bolt_rounded),
    (CalculatorCollection.recent, 'Недавние', Icons.history_rounded),
    (CalculatorCollection.favorites, 'Избранные', Icons.bookmark_outline),
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final (value, label, icon) in items) ...[
          if (value != CalculatorCollection.all) const SizedBox(width: 8),
          ChoiceChip(
            selected: selected == value,
            showCheckmark: false,
            avatar: Icon(icon, size: 18),
            label: Text(label),
            onSelected: (_) => onSelected(value),
          ),
        ],
      ],
    ),
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.calculatorCount,
    required this.onTap,
  });

  final CalculatorCategory category;
  final int calculatorCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              right: -34,
              top: -40,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: category.accent.withValues(alpha: .09),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: category.accent.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(category.icon, color: category.accent),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    category.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    category.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    calculatorCount == 0
                        ? 'Скоро появятся'
                        : 'Калькуляторов: $calculatorCount',
                    style: TextStyle(
                      color: category.accent,
                      fontWeight: FontWeight.w800,
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
}

class _CategoryHero extends StatelessWidget {
  const _CategoryHero({required this.category});

  final CalculatorCategory category;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          category.accent.withValues(alpha: .20),
          category.accent.withValues(alpha: .06),
        ],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: category.accent.withValues(alpha: .24)),
    ),
    child: Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: category.accent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(category.icon, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                category.subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
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
    required this.isFavorite,
    required this.onFavorite,
    this.result,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> fields;
  final VoidCallback onCalculate;
  final bool initiallyExpanded;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final CalculationResult? result;

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
                  IconButton(
                    tooltip: widget.isFavorite
                        ? 'Удалить из избранного'
                        : 'Добавить в избранное',
                    onPressed: widget.onFavorite,
                    icon: Icon(
                      widget.isFavorite
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
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
                      : _ResultCard(
                          key: ValueKey(
                            '${widget.result!.value}${widget.result!.interpretation}',
                          ),
                          result: widget.result!,
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

class _ResultCard extends StatelessWidget {
  const _ResultCard({super.key, required this.result});

  final CalculationResult result;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Card(
        margin: EdgeInsets.zero,
        color: colors.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics_outlined, color: colors.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Результат',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                result.value,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 7),
              Text(result.interpretation),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: colors.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Используйте результат вместе с клинической оценкой.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
