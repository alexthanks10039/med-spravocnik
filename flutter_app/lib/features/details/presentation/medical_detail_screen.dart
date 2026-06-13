import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/providers.dart';
import '../../../core/models/medical_content.dart';
import '../../../shared/widgets/clinical_widgets.dart';

class MedicalDetailScreen extends ConsumerWidget {
  const MedicalDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(itemProvider(id));
    final favorites = ref.watch(favoriteIdsProvider);
    return item.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        appBar: AppBar(),
        body: StatePanel.error(
          onAction: () => ref.invalidate(itemProvider(id)),
        ),
      ),
      data: (data) {
        if (data == null) {
          return const Scaffold(
            body: StatePanel.empty(
              title: 'Материал не найден',
              message: 'Возможно, он был удалён или ещё не загружен офлайн.',
            ),
          );
        }
        final isDrug = data.type == ContentType.drug;
        final pageTitle = switch (data.type) {
          ContentType.drug => 'Препарат',
          ContentType.article => 'Рекомендация',
          ContentType.calculator => 'Калькулятор',
          ContentType.disease => 'Заболевание',
        };
        final favorite = favorites.contains(data.id);
        return Scaffold(
          appBar: AppBar(
            title: Text(pageTitle),
            actions: [
              IconButton(
                tooltip: 'Скопировать',
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(
                      text:
                          '${data.title}\n${data.sections.entries.map((e) => '${e.key}: ${e.value}').join('\n')}',
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Фрагмент скопирован')),
                  );
                },
                icon: const Icon(Icons.content_copy_rounded),
              ),
              IconButton(
                tooltip: 'В избранное',
                onPressed: () =>
                    ref.read(favoriteIdsProvider.notifier).toggle(data.id),
                icon: Icon(
                  favorite
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                ),
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(data.icon, size: 30),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      data.subtitle,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (data.badge != null) ...[
                                      const SizedBox(height: 10),
                                      Chip(label: Text(data.badge!)),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (!isDrug)
                            _ClinicalAlert(
                              text: data.sections['Красные флаги'],
                            ),
                          ...data.sections.entries.map(
                            (section) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                child: ExpansionTile(
                                  initiallyExpanded:
                                      section.key == 'Кратко' ||
                                      section.key == 'Дозирование',
                                  title: Text(
                                    section.key,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  childrenPadding: const EdgeInsets.fromLTRB(
                                    18,
                                    0,
                                    18,
                                    18,
                                  ),
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        section.value,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  context.push('/notes?source=${data.id}'),
                              icon: const Icon(Icons.note_add_outlined),
                              label: const Text('Добавить заметку'),
                            ),
                          ),
                          if (data.relatedIds.isNotEmpty) ...[
                            const SizedBox(height: 28),
                            Text(
                              'Связанные материалы',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            ...data.relatedIds.map(
                              (relatedId) => _RelatedItem(id: relatedId),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Text(
                            'Информация предназначена для медицинских специалистов и не заменяет клиническое решение.',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ClinicalAlert extends StatelessWidget {
  const _ClinicalAlert({this.text});
  final String? text;
  @override
  Widget build(BuildContext context) {
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Красные флаги',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(text!),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelatedItem extends ConsumerWidget {
  const _RelatedItem({required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(itemProvider(id))
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const SizedBox.shrink(),
        data: (item) => item == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MedicalItemCard(item),
              ),
      );
}
