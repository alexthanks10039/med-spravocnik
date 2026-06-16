import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/providers.dart';
import '../../../shared/widgets/clinical_widgets.dart';
import '../../../shared/widgets/screen_frame.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController controller;
  Timer? debounce;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: ref.read(searchQueryProvider));
  }

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    return ScreenFrame(
      title: 'Глобальный поиск',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReferenceSearchPanel(
            controller: controller,
            query: ref.watch(searchQueryProvider),
            autofocus: true,
            shortcuts: const [
              SearchShortcut('Гипертензия', value: 'гипертензия'),
              SearchShortcut('Амоксициллин', value: 'амоксициллин'),
              SearchShortcut('eGFR', value: 'egfr'),
            ],
            onChanged: (value) {
              debounce?.cancel();
              debounce = Timer(
                const Duration(milliseconds: 280),
                () => ref.read(searchQueryProvider.notifier).update(value),
              );
            },
          ),
          const SizedBox(height: 24),
          results.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, _) => StatePanel.error(
              onAction: () => ref.invalidate(searchResultsProvider),
            ),
            data: (items) => items.isEmpty
                ? const StatePanel.empty()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Результаты: ${items.length}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      ...items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: MedicalItemCard(item),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
