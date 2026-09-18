import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/medical_content.dart';

abstract final class UiTokens {
  static const cardRadius = 18.0;
  static const iconRadius = 13.0;
  static const cardPadding = 16.0;
  static const compactGap = 8.0;
  static const contentGap = 14.0;
  static const pageGap = 28.0;
  static const motionFast = Duration(milliseconds: 160);
  static const motion = Duration(milliseconds: 240);
  static const motionSlow = Duration(milliseconds: 320);
}

class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: UiTokens.motionSlow + delay,
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(offset: Offset(0, (1 - value) * 24), child: child),
    ),
    child: child,
  );
}

class ClinicalSearchField extends StatefulWidget {
  const ClinicalSearchField({super.key, this.controller, this.onChanged, this.onTap, this.autofocus = false, this.hintText = 'Заболевание, препарат или калькулятор'});
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool autofocus;
  final String hintText;
  @override
  State<ClinicalSearchField> createState() => _ClinicalSearchFieldState();
}

class _ClinicalSearchFieldState extends State<ClinicalSearchField> {
  bool focused = false;
  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (value) => setState(() => focused = value),
    child: AnimatedContainer(
      duration: UiTokens.motion,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: focused ? [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: .12), blurRadius: 24, spreadRadius: 2)] : const [],
      ),
      child: TextField(
        controller: widget.controller,
        autofocus: widget.autofocus,
        readOnly: widget.onTap != null,
        onTap: widget.onTap,
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search_rounded, size: 23),
          suffixIcon: widget.onTap == null ? null : const Icon(Icons.arrow_forward_rounded),
        ),
      ),
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
  const ReferenceSearchPanel({super.key, required this.controller, required this.query, required this.onChanged, required this.shortcuts, this.hintText = 'Поиск по справочнику', this.onShortcut, this.autofocus = false});
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
      ClinicalSearchField(controller: controller, autofocus: autofocus, onChanged: onChanged, hintText: hintText),
      if (shortcuts.isNotEmpty) ...[
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: shortcuts.map((shortcut) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: shortcut.value != null && shortcut.value!.toLowerCase() == query.trim().toLowerCase(),
                avatar: shortcut.icon == null ? null : Icon(shortcut.icon, size: 17),
                label: Text(shortcut.label),
                onSelected: (_) {
                  if (onShortcut != null) { onShortcut!(shortcut); return; }
                  final value = shortcut.value ?? shortcut.label;
                  controller.text = value;
                  controller.selection = TextSelection.collapsed(offset: value.length);
                  onChanged(value);
                },
              ),
            )).toList(),
          ),
        ),
      ],
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
      Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
      if (action != null) TextButton.icon(onPressed: onAction, icon: const Icon(Icons.arrow_forward_rounded, size: 16), label: Text(action!)),
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
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? () => context.push('/detail/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(UiTokens.cardPadding),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(UiTokens.iconRadius)), child: Icon(item.icon, color: colors.onPrimaryContainer)),
            const SizedBox(width: UiTokens.contentGap),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(item.title, style: Theme.of(context).textTheme.titleMedium)),
                if (item.badge != null) _Badge(item.badge!),
              ]),
              const SizedBox(height: 5),
              Text(item.subtitle, style: TextStyle(color: colors.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 9),
              Text(item.category, style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
            ])),
            const SizedBox(width: 8),
            trailing ?? Icon(Icons.arrow_forward_ios_rounded, size: 15, color: colors.onSurfaceVariant),
          ]),
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
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(99)),
    child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
  );
}

class StatePanel extends StatelessWidget {
  const StatePanel({super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});
  const StatePanel.empty({super.key, this.title = 'Ничего не найдено', this.message = 'Попробуйте изменить запрос или фильтры', this.actionLabel, this.onAction}) : icon = Icons.search_off_rounded;
  const StatePanel.error({super.key, this.title = 'Не удалось загрузить данные', this.message = 'Проверьте соединение. Сохранённые материалы доступны офлайн.', this.actionLabel = 'Повторить', this.onAction}) : icon = Icons.cloud_off_rounded;
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ]),
      ),
    ),
  );
}
