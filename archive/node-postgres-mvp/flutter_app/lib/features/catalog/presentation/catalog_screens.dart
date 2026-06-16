import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/providers.dart';
import '../../../core/models/medical_content.dart';
import '../../../shared/widgets/clinical_widgets.dart';
import '../../../shared/widgets/screen_frame.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final search = TextEditingController();
  String query = '';

  static const entries = [
    (
      title: 'Заболевания',
      subtitle: 'По специальностям и системам органов',
      icon: Icons.medical_information_outlined,
      path: '/diseases',
    ),
    (
      title: 'Препараты',
      subtitle: 'Монографии, дозы и безопасность',
      icon: Icons.medication_outlined,
      path: '/drugs',
    ),
    (
      title: 'Калькуляторы',
      subtitle: 'Проверяемые клинические формулы',
      icon: Icons.calculate_outlined,
      path: '/calculators',
    ),
    (
      title: 'Рекомендации',
      subtitle: 'Короткие практические алгоритмы',
      icon: Icons.alt_route_rounded,
      path: '/articles',
    ),
  ];

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(referenceSearchProvider(query));
    return ScreenFrame(
      title: 'Справочник',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReferenceSearchPanel(
            controller: search,
            query: query,
            hintText: 'Поиск только по справочнику',
            onChanged: (value) => setState(() => query = value),
            shortcuts: const [
              SearchShortcut('Заболевания', icon: Icons.favorite_outline),
              SearchShortcut('Препараты', icon: Icons.medication_outlined),
              SearchShortcut('Калькуляторы', icon: Icons.calculate_outlined),
              SearchShortcut('Рекомендации', icon: Icons.alt_route_rounded),
            ],
            onShortcut: (shortcut) {
              final entry = entries.firstWhere(
                (item) => item.title == shortcut.label,
              );
              context.go(entry.path);
            },
          ),
          const SizedBox(height: 20),
          if (query.trim().isEmpty) ...[
            Text('Категории', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(18),
                    leading: CircleAvatar(radius: 24, child: Icon(entry.icon)),
                    title: Text(
                      entry.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(entry.subtitle),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.go(entry.path),
                  ),
                ),
              ),
            ),
          ] else
            results.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, _) => StatePanel.error(
                onAction: () => ref.invalidate(referenceSearchProvider(query)),
              ),
              data: (items) {
                final referenceItems = items
                    .where(
                      (item) =>
                          item.type == ContentType.disease ||
                          item.type == ContentType.drug ||
                          item.type == ContentType.calculator ||
                          item.type == ContentType.article,
                    )
                    .toList();
                if (referenceItems.isEmpty) {
                  return const StatePanel.empty(
                    title: 'В справочнике ничего не найдено',
                    message:
                        'Измените запрос или откройте один из быстрых разделов.',
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Результаты: ${referenceItems.length}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ...referenceItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: MedicalItemCard(item),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class ItemListScreen extends ConsumerStatefulWidget {
  const ItemListScreen({super.key, required this.type, required this.title});

  final ContentType type;
  final String title;

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen> {
  final search = TextEditingController();
  String query = '';

  List<SearchShortcut> get shortcuts => switch (widget.type) {
    ContentType.disease => const [
      SearchShortcut('Все', value: ''),
      SearchShortcut('Кардиология', value: 'кардиология'),
      SearchShortcut('Пульмонология', value: 'пульмонология'),
    ],
    ContentType.drug => const [
      SearchShortcut('Все', value: ''),
      SearchShortcut('Амлодипин', value: 'амлодипин'),
      SearchShortcut('Антибиотики', value: 'амоксициллин'),
    ],
    ContentType.article => const [
      SearchShortcut('Все', value: ''),
      SearchShortcut('Боль в груди', value: 'боли в груди'),
      SearchShortcut('Антибиотики', value: 'антибиотикотерапия'),
    ],
    ContentType.calculator => const [SearchShortcut('Все', value: '')],
  };

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemsByTypeProvider(widget.type));
    return ScreenFrame(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReferenceSearchPanel(
            controller: search,
            query: query,
            hintText: widget.type == ContentType.disease
                ? 'Поиск по заболеваниям'
                : widget.type == ContentType.drug
                ? 'Поиск по препаратам'
                : 'Поиск по рекомендациям',
            shortcuts: shortcuts,
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 20),
          items.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => StatePanel.error(
              onAction: () => ref.invalidate(itemsByTypeProvider(widget.type)),
            ),
            data: (data) {
              final normalized = query.trim().toLowerCase();
              final visible = data.where((item) {
                if (normalized.isEmpty) return true;
                final searchable = [
                  item.title,
                  item.subtitle,
                  item.category,
                  ...item.sections.values,
                ].join(' ').toLowerCase();
                return searchable.contains(normalized);
              }).toList();

              if (visible.isEmpty) {
                return StatePanel.empty(
                  title: '${widget.title}: ничего не найдено',
                  message:
                      'Попробуйте изменить запрос или выбрать быстрый фильтр.',
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Результаты: ${visible.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ...visible.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MedicalItemCard(item),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
