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
    (title: 'Заболевания', subtitle: 'Диагностика и ведение по системам органов', icon: Icons.medical_information_outlined, path: '/diseases'),
    (title: 'Препараты', subtitle: 'Монографии, дозы, взаимодействия и безопасность', icon: Icons.medication_outlined, path: '/drugs'),
    (title: 'Калькуляторы', subtitle: 'Проверяемые клинические формулы и шкалы', icon: Icons.calculate_outlined, path: '/calculators'),
    (title: 'Рекомендации', subtitle: 'Короткие практические алгоритмы', icon: Icons.alt_route_rounded, path: '/articles'),
  ];

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final results = ref.watch(referenceSearchProvider(query));
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1050 ? 2 : 1;

    return ScreenFrame(
      title: 'Справочник',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primaryContainer, colors.surfaceContainerLow],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.outlineVariant.withValues(alpha: .5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('База знаний', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.onPrimaryContainer)),
                  const SizedBox(height: 7),
                  Text('Найти нужное.', style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 6),
                  Text('Заболевания, препараты, расчёты и рекомендации в одном рабочем пространстве.',
                    style: TextStyle(color: colors.onSurfaceVariant, height: 1.45)),
                  const SizedBox(height: 18),
                  ReferenceSearchPanel(
                    controller: search,
                    query: query,
                    hintText: 'Поиск по справочнику',
                    onChanged: (value) => setState(() => query = value),
                    shortcuts: const [
                      SearchShortcut('Заболевания', icon: Icons.medical_information_outlined),
                      SearchShortcut('Препараты', icon: Icons.medication_outlined),
                      SearchShortcut('Калькуляторы', icon: Icons.calculate_outlined),
                      SearchShortcut('Рекомендации', icon: Icons.alt_route_rounded),
                    ],
                    onShortcut: (shortcut) {
                      final entry = entries.firstWhere((item) => item.title == shortcut.label);
                      context.go(entry.path);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: UiTokens.pageGap),
          if (query.trim().isEmpty) ...[
            Text('Разделы', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: columns == 2 ? 1.9 : 3.4,
              ),
              itemBuilder: (context, index) => FadeSlideIn(
                delay: Duration(milliseconds: index * 55),
                child: _CatalogTile(
                  title: entries[index].title,
                  subtitle: entries[index].subtitle,
                  icon: entries[index].icon,
                  index: index,
                  onTap: () => context.go(entries[index].path),
                ),
              ),
            ),
          ] else
            results.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(36), child: CircularProgressIndicator())),
              error: (_, _) => StatePanel.error(onAction: () => ref.invalidate(referenceSearchProvider(query))),
              data: (items) {
                final visible = items.where((item) =>
                  item.type == ContentType.disease ||
                  item.type == ContentType.drug ||
                  item.type == ContentType.calculator ||
                  item.type == ContentType.article).toList();
                if (visible.isEmpty) {
                  return const StatePanel.empty(title: 'В справочнике ничего не найдено', message: 'Измените запрос или откройте один из разделов.');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Результаты: ${visible.length}', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    ...visible.asMap().entries.map(
                      (entry) => FadeSlideIn(
                        delay: Duration(milliseconds: entry.key * 30),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: MedicalItemCard(entry.value),
                        ),
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

class _CatalogTile extends StatefulWidget {
  const _CatalogTile({required this.title, required this.subtitle, required this.icon, required this.index, required this.onTap});

  final String title;
  final String subtitle;
  final IconData icon;
  final int index;
  final VoidCallback onTap;

  @override
  State<_CatalogTile> createState() => _CatalogTileState();
}

class _CatalogTileState extends State<_CatalogTile> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accents = [colors.primary, const Color(0xFF1768A3), const Color(0xFF6B5AA6), const Color(0xFFC54A55)];
    final accent = accents[widget.index % accents.length];

    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: AnimatedContainer(
        duration: UiTokens.motionFast,
        transform: Matrix4.translationValues(0, hovered ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: hovered ? accent.withValues(alpha: .55) : colors.outlineVariant.withValues(alpha: .65)),
          boxShadow: hovered ? [BoxShadow(color: accent.withValues(alpha: .10), blurRadius: 22, offset: const Offset(0, 10))] : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: UiTokens.motionFast,
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: hovered ? .18 : .10),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(widget.icon, color: accent, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 5),
                        Text(widget.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.onSurfaceVariant, height: 1.35)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedContainer(
                    duration: UiTokens.motionFast,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: hovered ? accent.withValues(alpha: .10) : colors.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_forward_rounded, size: 18, color: hovered ? accent : colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
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
    ContentType.disease => const [SearchShortcut('Все', value: ''), SearchShortcut('Кардиология', value: 'кардиология'), SearchShortcut('Пульмонология', value: 'пульмонология')],
    ContentType.drug => const [SearchShortcut('Все', value: ''), SearchShortcut('Амлодипин', value: 'амлодипин'), SearchShortcut('Антибиотики', value: 'амоксициллин')],
    ContentType.article => const [SearchShortcut('Все', value: ''), SearchShortcut('Боль в груди', value: 'боли в груди'), SearchShortcut('Антибиотики', value: 'антибиотикотерапия')],
    ContentType.calculator => const [SearchShortcut('Все', value: '')],
  };

  @override
  void dispose() { search.dispose(); super.dispose(); }

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
            hintText: widget.type == ContentType.disease ? 'Поиск по заболеваниям' : widget.type == ContentType.drug ? 'Поиск по препаратам' : 'Поиск по рекомендациям',
            shortcuts: shortcuts,
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 20),
          items.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => StatePanel.error(onAction: () => ref.invalidate(itemsByTypeProvider(widget.type))),
            data: (data) {
              final normalized = query.trim().toLowerCase();
              final visible = data.where((item) {
                if (normalized.isEmpty) return true;
                final searchable = [item.title, item.subtitle, item.category, ...item.sections.values].join(' ').toLowerCase();
                return searchable.contains(normalized);
              }).toList();
              if (visible.isEmpty) return StatePanel.empty(title: '${widget.title}: ничего не найдено', message: 'Попробуйте изменить запрос или выбрать быстрый фильтр.');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Результаты: ${visible.length}', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ...visible.asMap().entries.map((entry) => FadeSlideIn(
                    delay: Duration(milliseconds: entry.key * 25),
                    child: Padding(padding: const EdgeInsets.only(bottom: 10), child: MedicalItemCard(entry.value)),
                  )),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
