import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/providers.dart';
import '../../../core/data/bookmark_controller.dart';
import '../../../shared/widgets/clinical_widgets.dart';
import '../../../shared/widgets/screen_frame.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarkProvider);
    final ids = bookmarks.keys.toList();
    if (ids.isEmpty) {
      return const ScreenFrame(
        title: 'Закладки',
        child: StatePanel.empty(
          title: 'Закладок пока нет',
          message: 'Откройте документ и сохраните нужные разделы, чтобы быстро возвращаться к ним.',
        ),
      );
    }

    return ScreenFrame(
      title: 'Закладки',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: ids.map((id) {
          final sections = bookmarks[id]!.toList()..sort();
          return ref.watch(itemProvider(id)).when(
            loading: () => const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (item) => item == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(item.title),
                            subtitle: Text('${sections.length} сохранённых раздела'),
                            leading: const Icon(Icons.menu_book_outlined),
                          ),
                          const Divider(height: 1),
                          ...sections.map(
                            (section) => ListTile(
                              leading: const Icon(Icons.bookmark_rounded),
                              title: Text(section),
                              trailing: IconButton(
                                tooltip: 'Удалить закладку',
                                onPressed: () => ref
                                    .read(bookmarkProvider.notifier)
                                    .toggle(id, section),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                              onTap: () => context.push(
                                '/detail/$id?section=${Uri.encodeComponent(section)}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          );
        }).toList(),
      ),
    );
  }
}
