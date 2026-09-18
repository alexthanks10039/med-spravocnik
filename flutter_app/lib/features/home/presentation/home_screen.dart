import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/providers.dart';
import '../../../core/models/medical_content.dart';
import '../../../shared/widgets/clinical_widgets.dart';
import '../../../shared/widgets/screen_frame.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const categories = [
    MedicalCategory('Заболевания', 'Диагностика и ведение', Icons.medical_information_outlined, Color(0xFF0A7F78)),
    MedicalCategory('Препараты', 'Дозы и безопасность', Icons.medication_outlined, Color(0xFF1768A3)),
    MedicalCategory('Калькуляторы', 'Быстрые расчёты', Icons.calculate_outlined, Color(0xFF6B5AA6)),
    MedicalCategory('Неотложная помощь', 'Алгоритмы и red flags', Icons.emergency_outlined, Color(0xFFC54A55)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentItemsProvider);
    final colors = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1050 ? 4 : width >= 650 ? 2 : 1;

    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primaryContainer, colors.surfaceContainerLow],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: colors.outlineVariant.withValues(alpha: .45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Медицинский справочник', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.onPrimaryContainer)),
                  const SizedBox(height: 8),
                  Text('Что нужно уточнить?', style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 8),
                  Text('Ищите клиническую информацию, препараты и расчёты без лишних переходов.', style: TextStyle(color: colors.onSurfaceVariant, height: 1.45)),
                  const SizedBox(height: 18),
                  ClinicalSearchField(onTap: () => context.go('/search')),
                ],
              ),
            ),
          ),
          const SizedBox(height: UiTokens.pageGap),
          SectionHeader('Быстрый доступ'),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: columns == 1 ? 4.0 : 1.45,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final routes = ['/diseases', '/drugs', '/calculators', '/catalog'];
              return FadeSlideIn(
                delay: Duration(milliseconds: 45 * index),
                child: _CategoryTile(category: category, onTap: () => context.go(routes[index])),
              );
            },
          ),
          const SizedBox(height: UiTokens.pageGap),
          SectionHeader('Недавно открывали', action: 'История', onAction: () => context.go('/history')),
          const SizedBox(height: 12),
          recent.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (_, _) => const StatePanel.error(),
            data: (items) => items.isEmpty
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(children: [
                        Icon(Icons.history_rounded, color: colors.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Открытые материалы появятся здесь.', style: TextStyle(color: colors.onSurfaceVariant))),
                      ]),
                    ),
                  )
                : Column(children: items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: MedicalItemCard(item),
                  )).toList()),
          ),
          const SizedBox(height: 18),
          Card(
            color: colors.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.offline_bolt_rounded, color: colors.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Офлайн-доступ включён', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text('Ключевые материалы доступны без сети.', style: TextStyle(color: colors.onSurfaceVariant)),
                ])),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});
  final MedicalCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: category.color.withValues(alpha: .11), borderRadius: BorderRadius.circular(13)),
                child: Icon(category.icon, color: category.color),
              ),
              const SizedBox(width: 13),
              Expanded(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(category.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5)),
                ],
              )),
              Icon(Icons.arrow_forward_rounded, size: 18, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
