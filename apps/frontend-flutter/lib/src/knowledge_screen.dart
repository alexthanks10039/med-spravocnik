import 'package:flutter/material.dart';

import 'api_client.dart';
import 'models.dart';

class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({super.key, required this.client});

  final MedicalApiClient client;

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  final _controller = TextEditingController();
  late Future<_CatalogData> _catalogFuture;
  Future<List<KnowledgeEvidence>>? _searchFuture;
  String _category = '';

  @override
  void initState() {
    super.initState();
    _catalogFuture = _loadCatalog();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<_CatalogData> _loadCatalog() async {
    final results = await Future.wait([
      widget.client.clinicalCategories(),
      widget.client.clinicalDiseases(category: _category),
    ]);
    return _CatalogData(
      categories: results[0] as List<ClinicalCategory>,
      diseases: results[1] as List<ClinicalDiseaseSummary>,
    );
  }

  void _search() {
    final query = _controller.text.trim();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _searchFuture = query.length >= 2
          ? widget.client.searchKnowledge(query)
          : null;
    });
  }

  void _clearSearch() {
    _controller.clear();
    setState(() => _searchFuture = null);
  }

  void _selectCategory(String value) {
    setState(() {
      _category = value;
      _catalogFuture = _loadCatalog();
    });
  }

  void _openDocument(String docId) {
    if (docId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ProtocolDocumentScreen(client: widget.client, docId: docId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SearchBar(
            controller: _controller,
            hintText: 'Диагноз, критерий, препарат или МКБ-10',
            leading: const Icon(Icons.manage_search),
            trailing: [
              if (_searchFuture != null)
                IconButton(
                  tooltip: 'Очистить поиск',
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.close),
                ),
              IconButton(
                tooltip: 'Найти',
                onPressed: _search,
                icon: const Icon(Icons.arrow_forward),
              ),
            ],
            onSubmitted: (_) => _search(),
          ),
        ),
        Expanded(
          child: _searchFuture == null
              ? _CatalogView(
                  future: _catalogFuture,
                  selectedCategory: _category,
                  onCategorySelected: _selectCategory,
                  onOpen: _openDocument,
                  onRetry: () => setState(() {
                    _catalogFuture = _loadCatalog();
                  }),
                )
              : _SearchView(
                  future: _searchFuture!,
                  onOpen: _openDocument,
                  onRetry: _search,
                ),
        ),
      ],
    );
  }
}

class _CatalogData {
  const _CatalogData({required this.categories, required this.diseases});

  final List<ClinicalCategory> categories;
  final List<ClinicalDiseaseSummary> diseases;
}

class _CatalogView extends StatelessWidget {
  const _CatalogView({
    required this.future,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onOpen,
    required this.onRetry,
  });

  final Future<_CatalogData> future;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CatalogData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error, onRetry: onRetry);
        }
        final data = snapshot.data;
        if (data == null || data.diseases.isEmpty) {
          return const _EmptyState(
            icon: Icons.library_books_outlined,
            title: 'Документы не найдены',
            message: 'В выбранной категории пока нет доступных протоколов.',
          );
        }
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 54,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('Все'),
                        selected: selectedCategory.isEmpty,
                        onSelected: (_) => onCategorySelected(''),
                      ),
                    ),
                    for (final category in data.categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            '${category.title} · ${category.diseaseCount}',
                          ),
                          selected: selectedCategory == category.id,
                          onSelected: (_) => onCategorySelected(category.id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList.separated(
                itemCount: data.diseases.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = data.diseases[index];
                  return _DiseaseCard(item: item, onTap: () => onOpen(item.id));
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchView extends StatelessWidget {
  const _SearchView({
    required this.future,
    required this.onOpen,
    required this.onRetry,
  });

  final Future<List<KnowledgeEvidence>> future;
  final ValueChanged<String> onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<KnowledgeEvidence>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error, onRetry: onRetry);
        }
        final results = snapshot.data ?? const [];
        if (results.isEmpty) {
          return const _EmptyState(
            icon: Icons.search_off,
            title: 'Ничего не найдено',
            message: 'Попробуйте другой диагноз, показатель или код МКБ-10.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: results.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = results[index];
            return _EvidenceCard(item: item, onTap: () => onOpen(item.docId));
          },
        );
      },
    );
  }
}

class _DiseaseCard extends StatelessWidget {
  const _DiseaseCard({required this.item, required this.onTap});

  final ClinicalDiseaseSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.description_outlined),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        item.category,
                        if (item.icd10Codes.isNotEmpty)
                          'МКБ-10: ${item.icd10Codes.join(', ')}',
                      ].where((value) => value.isNotEmpty).join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (item.approvalDate.isNotEmpty ||
                        item.version.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          item.version,
                          item.approvalDate,
                        ].where((value) => value.isNotEmpty).join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.item, required this.onTap});

  final KnowledgeEvidence item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (item.sectionPath.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.sectionPath,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(item.text, maxLines: 7, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        item.version,
                        item.approvalDate,
                      ].where((value) => value.isNotEmpty).join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const Text('Открыть документ'),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
              if (item.versionWarning.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.versionWarning,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ProtocolDocumentScreen extends StatefulWidget {
  const ProtocolDocumentScreen({
    super.key,
    required this.client,
    required this.docId,
  });

  final MedicalApiClient client;
  final String docId;

  @override
  State<ProtocolDocumentScreen> createState() => _ProtocolDocumentScreenState();
}

class _ProtocolDocumentScreenState extends State<ProtocolDocumentScreen> {
  late Future<ProtocolDocument> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.client.protocolDocument(widget.docId);
  }

  void _retry() {
    setState(() => _future = widget.client.protocolDocument(widget.docId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Клинический протокол')),
      body: FutureBuilder<ProtocolDocument>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error, onRetry: _retry);
          }
          final document = snapshot.data;
          if (document == null || document.empty || document.sections.isEmpty) {
            return const _EmptyState(
              icon: Icons.description_outlined,
              title: 'Документ без данных',
              message:
                  'Для этого протокола не найдено пригодных для показа разделов.',
            );
          }
          return SelectionArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _DocumentHeader(document: document),
                const SizedBox(height: 16),
                for (final section in document.sections) ...[
                  _ProtocolSectionCard(section: section),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DocumentHeader extends StatelessWidget {
  const _DocumentHeader({required this.document});

  final ProtocolDocument document;

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      if (document.icd10Codes.isNotEmpty)
        'МКБ-10: ${document.icd10Codes.join(', ')}',
      if (document.protocolNumber.isNotEmpty)
        'Протокол №${document.protocolNumber}',
      if (document.version.isNotEmpty) document.version,
      if (document.approvalDate.isNotEmpty) document.approvalDate,
    ];
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              document.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (metadata.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in metadata) Chip(label: Text(value)),
                ],
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Сведения показаны по локальному документу. Перед клиническим применением проверьте актуальность версии.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ProtocolSectionCard extends StatelessWidget {
  const _ProtocolSectionCard({required this.section});

  final ProtocolSection section;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(section.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            for (var index = 0; index < section.blocks.length; index++) ...[
              _PresentationBlockView(block: section.blocks[index]),
              if (index != section.blocks.length - 1)
                const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _PresentationBlockView extends StatelessWidget {
  const _PresentationBlockView({required this.block});

  final PresentationBlock block;

  @override
  Widget build(BuildContext context) {
    if (block.table != null) return _TableView(table: block.table!);
    if (block.type == 'bullet_list') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in block.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(Icons.circle, size: 7),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      );
    }

    final style = _blockStyle(context, block.type);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (style.label.isNotEmpty) ...[
          Row(
            children: [
              Icon(style.icon, size: 19, color: style.foreground),
              const SizedBox(width: 8),
              Text(
                style.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: style.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Text(block.text),
        if (block.references.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Источники в документе: ${block.references.map((value) => '[$value]').join(', ')}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
    if (!style.highlighted) return content;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: style.foreground.withValues(alpha: 0.28)),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: content),
    );
  }
}

class _BlockStyle {
  const _BlockStyle({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.highlighted,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
  final bool highlighted;
}

_BlockStyle _blockStyle(BuildContext context, String type) {
  final colors = Theme.of(context).colorScheme;
  return switch (type) {
    'warning' => _BlockStyle(
      label: 'Важное предупреждение',
      icon: Icons.warning_amber_rounded,
      foreground: colors.error,
      background: colors.errorContainer.withValues(alpha: 0.45),
      highlighted: true,
    ),
    'criteria' => _BlockStyle(
      label: 'Критерии',
      icon: Icons.rule,
      foreground: colors.primary,
      background: colors.primaryContainer.withValues(alpha: 0.4),
      highlighted: true,
    ),
    'lab_value' => _BlockStyle(
      label: 'Лабораторные значения',
      icon: Icons.biotech_outlined,
      foreground: colors.tertiary,
      background: colors.tertiaryContainer.withValues(alpha: 0.42),
      highlighted: true,
    ),
    'drug_card' => _BlockStyle(
      label: 'Лекарственная терапия',
      icon: Icons.medication_outlined,
      foreground: colors.secondary,
      background: colors.secondaryContainer.withValues(alpha: 0.42),
      highlighted: true,
    ),
    'definition' => _BlockStyle(
      label: 'Определение',
      icon: Icons.info_outline,
      foreground: colors.primary,
      background: colors.primaryContainer.withValues(alpha: 0.3),
      highlighted: true,
    ),
    'references' => _BlockStyle(
      label: 'Источники',
      icon: Icons.format_quote,
      foreground: colors.onSurfaceVariant,
      background: colors.surfaceContainerHighest,
      highlighted: true,
    ),
    _ => _BlockStyle(
      label: '',
      icon: Icons.notes,
      foreground: colors.onSurface,
      background: colors.surface,
      highlighted: false,
    ),
  };
}

class _TableView extends StatelessWidget {
  const _TableView({required this.table});

  final PresentationTable table;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.table_chart_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    table.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!table.isStructured)
              _TableFallback(table: table)
            else
              LayoutBuilder(
                builder: (context, constraints) => constraints.maxWidth < 680
                    ? _MobileTable(table: table)
                    : _DesktopTable(table: table),
              ),
          ],
        ),
      ),
    );
  }
}

class _DesktopTable extends StatelessWidget {
  const _DesktopTable({required this.table});

  final PresentationTable table;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        columns: [
          for (final column in table.columns) DataColumn(label: Text(column)),
        ],
        rows: [
          for (final row in table.rows)
            DataRow(
              cells: [
                for (final cell in row)
                  DataCell(SizedBox(width: 240, child: Text(cell))),
              ],
            ),
        ],
      ),
    );
  }
}

class _MobileTable extends StatelessWidget {
  const _MobileTable({required this.table});

  final PresentationTable table;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var rowIndex = 0; rowIndex < table.rows.length; rowIndex++)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < table.columns.length; index++) ...[
                  Text(
                    table.columns[index],
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(table.rows[rowIndex][index]),
                  if (index != table.columns.length - 1)
                    const SizedBox(height: 8),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _TableFallback extends StatelessWidget {
  const _TableFallback({required this.table});

  final PresentationTable table;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                table.message.isEmpty
                    ? 'Таблица не распознана.'
                    : table.message,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          table.fallbackText.isEmpty
              ? 'Текстовое содержимое таблицы отсутствует.'
              : table.fallbackText,
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 54,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              'Не удалось загрузить данные',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
