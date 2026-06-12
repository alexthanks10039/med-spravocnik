import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/providers.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/clinical_widgets.dart';
import '../../../shared/widgets/screen_frame.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(favoriteIdsProvider);
    final allItems = ref.watch(searchResultsProvider);
    return ScreenFrame(
      title: 'Сохранённое',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Shortcut(
                  icon: Icons.history_rounded,
                  title: 'История',
                  onTap: () => context.go('/history'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Shortcut(
                  icon: Icons.note_alt_outlined,
                  title: 'Заметки',
                  onTap: () => context.go('/notes'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Избранное', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          allItems.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const StatePanel.error(),
            data: (items) {
              final saved = items
                  .where((item) => ids.contains(item.id))
                  .toList();
              if (saved.isEmpty)
                return const StatePanel.empty(
                  title: 'Избранное пусто',
                  message:
                      'Сохраняйте материалы, чтобы они были доступны здесь и офлайн.',
                );
              return Column(
                children: saved
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: MedicalItemCard(
                          item,
                          trailing: IconButton(
                            icon: const Icon(Icons.bookmark_rounded),
                            onPressed: () => ref
                                .read(favoriteIdsProvider.notifier)
                                .toggle(item.id),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ScreenFrame(
    title: 'История',
    actions: [TextButton(onPressed: () {}, child: const Text('Очистить'))],
    child: ref
        .watch(recentItemsProvider)
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const StatePanel.error(),
          data: (items) => Column(
            children: items
                .asMap()
                .entries
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MedicalItemCard(
                      entry.value,
                      trailing: Text(
                        entry.key < 2 ? 'Сегодня' : 'Вчера',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
  );
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final controller = TextEditingController();
  final notes = <String>['Уточнить локальный протокол по антибиотикотерапии.'];
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScreenFrame(
    title: 'Заметки',
    child: Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Новая клиническая заметка...',
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (controller.text.trim().isEmpty) return;
                      setState(() {
                        notes.insert(0, controller.text.trim());
                        controller.clear();
                      });
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Сохранить'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (notes.isEmpty)
          const StatePanel.empty(
            title: 'Заметок пока нет',
            message:
                'Добавьте личную заметку к материалу или создайте её здесь.',
          ),
        ...notes.map(
          (note) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: Text(note),
                subtitle: const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Сохранено на устройстве'),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => ScreenFrame(
    title: 'Профиль',
    child: Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 32,
                  child: Text(
                    'ДТ',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Доктор Тестовый',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      const Text('Терапевт · Алматы'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Настройки'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/settings'),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.workspace_premium_outlined),
                title: Text('Профессиональный профиль'),
                subtitle: Text('Специальность и интересы'),
                trailing: Icon(Icons.chevron_right),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('О приложении'),
                subtitle: Text('Версия 1.0.0 MVP'),
                trailing: Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeControllerProvider);
    return ScreenFrame(
      title: 'Настройки',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Внешний вид', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: ThemeMode.values
                  .map(
                    (item) => RadioListTile<ThemeMode>(
                      value: item,
                      groupValue: mode,
                      onChanged: (value) => ref
                          .read(themeControllerProvider.notifier)
                          .setMode(value!),
                      title: Text(
                        {
                          ThemeMode.system: 'Как в системе',
                          ThemeMode.light: 'Светлая тема',
                          ThemeMode.dark: 'Тёмная тема',
                        }[item]!,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Офлайн и данные',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          const Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: true,
                  onChanged: null,
                  title: Text('Автоматическое обновление'),
                  subtitle: Text('Только по Wi-Fi'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.storage_outlined),
                  title: Text('Офлайн-библиотека'),
                  subtitle: Text('24,6 МБ · обновлено сегодня'),
                  trailing: Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: true,
                  onChanged: null,
                  title: Text('Предупреждения о безопасности'),
                ),
                Divider(height: 1),
                SwitchListTile(
                  value: false,
                  onChanged: null,
                  title: Text('Аналитика использования'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    ),
  );
}
