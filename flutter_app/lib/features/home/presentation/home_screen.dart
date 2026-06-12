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
    MedicalCategory(
      'Заболевания',
      'Структурированные клинические материалы',
      Icons.medical_information_outlined,
      Color(0xFF0A7F78),
    ),
    MedicalCategory(
      'Препараты',
      'Дозы, ограничения и взаимодействия',
      Icons.medication_outlined,
      Color(0xFF1768A3),
    ),
    MedicalCategory(
      'Калькуляторы',
      'Быстрые клинические расчёты',
      Icons.calculate_outlined,
      Color(0xFF6B5AA6),
    ),
    MedicalCategory(
      'Неотложная помощь',
      'Алгоритмы и красные флаги',
      Icons.emergency_outlined,
      Color(0xFFC54A55),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentItemsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100
        ? 4
        : width >= 620
        ? 2
        : 1;

    return ScreenFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Text(
            'Добрый день',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Что нужно уточнить?',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'Клиническая информация, препараты и расчёты в одном рабочем пространстве.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ClinicalSearchField(onTap: () => context.go('/search')),
          const SizedBox(height: 28),
          const SectionHeader('Быстрый доступ'),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: columns == 1 ? 3.25 : 1.7,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final routes = [
                '/diseases',
                '/drugs',
                '/calculators',
                '/catalog',
              ];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => context.go(routes[index]),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: category.color.withValues(alpha: .13),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(category.icon, color: category.color),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                category.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          SectionHeader(
            'Недавно открывали',
            action: 'История',
            onAction: () => context.go('/history'),
          ),
          const SizedBox(height: 12),
          recent.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const StatePanel.error(),
            data: (items) => Column(
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MedicalItemCard(item),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.download_done_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Офлайн-библиотека актуальна',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ключевые материалы доступны без подключения к сети.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
