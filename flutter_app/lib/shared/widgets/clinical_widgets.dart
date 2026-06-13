import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/medical_content.dart';

class ClinicalSearchField extends StatelessWidget {
  const ClinicalSearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.onTap,
    this.autofocus = false,
  });
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    autofocus: autofocus,
    readOnly: onTap != null,
    onTap: onTap,
    onChanged: onChanged,
    decoration: const InputDecoration(
      hintText: 'Заболевание, препарат или калькулятор',
      prefixIcon: Icon(Icons.search_rounded),
      suffixIcon: Icon(Icons.tune_rounded),
    ),
  );
}

class SearchShortcut {
  const SearchShortcut(this.label, {this.value, this.icon});

  final String label;
  final String? value;
  final IconData? icon;
}

class ReferenceSearchPanel extends StatelessWidget {
  const ReferenceSearchPanel({
    super.key,
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.shortcuts,
    this.hintText = 'Поиск по справочнику',
    this.onShortcut,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final List<SearchShortcut> shortcuts;
  final String hintText;
  final ValueChanged<SearchShortcut>? onShortcut;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Очистить поиск',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: shortcuts.map((shortcut) {
          final selected =
              shortcut.value != null &&
              shortcut.value!.toLowerCase() == query.trim().toLowerCase();
          return FilterChip(
            selected: selected,
            avatar: shortcut.icon == null
                ? null
                : Icon(shortcut.icon, size: 18),
            label: Text(shortcut.label),
            onSelected: (_) {
              if (onShortcut != null) {
                onShortcut!(shortcut);
                return;
              }
              final value = shortcut.value ?? shortcut.label;
              controller.text = value;
              controller.selection = TextSelection.collapsed(
                offset: value.length,
              );
              onChanged(value);
            },
          );
        }).toList(),
      ),
    ],
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
    ],
  );
}

class MedicalItemCard extends StatelessWidget {
  const MedicalItemCard(this.item, {super.key, this.trailing, this.onTap});
  final MedicalItem item;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap ?? () => context.push('/detail/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.icon,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (item.badge != null) _Badge(item.badge!),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.category,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

class AsyncContent<T> extends StatelessWidget {
  const AsyncContent({
    super.key,
    required this.value,
    required this.data,
    this.emptyText = 'Здесь пока ничего нет',
  });
  final AsyncSnapshotLike<T> value;
  final Widget Function(T data) data;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (value.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (value.error != null) {
      return StatePanel.error(onAction: value.retry);
    }
    return data(value.value as T);
  }
}

class AsyncSnapshotLike<T> {
  const AsyncSnapshotLike({
    this.value,
    this.error,
    this.isLoading = false,
    this.retry,
  });
  final T? value;
  final Object? error;
  final bool isLoading;
  final VoidCallback? retry;
}

class StatePanel extends StatelessWidget {
  const StatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  const StatePanel.empty({
    super.key,
    this.title = 'Ничего не найдено',
    this.message = 'Попробуйте изменить запрос или фильтры',
    this.actionLabel,
    this.onAction,
  }) : icon = Icons.search_off_rounded;
  const StatePanel.error({
    super.key,
    this.title = 'Не удалось загрузить данные',
    this.message =
        'Проверьте соединение. Сохранённые материалы доступны офлайн.',
    this.actionLabel = 'Повторить',
    this.onAction,
  }) : icon = Icons.cloud_off_rounded;
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
