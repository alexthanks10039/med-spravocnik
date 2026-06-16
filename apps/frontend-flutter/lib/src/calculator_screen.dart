import 'package:flutter/material.dart';

import 'api_client.dart';
import 'models.dart';

class CalculatorCatalogScreen extends StatefulWidget {
  const CalculatorCatalogScreen({super.key, required this.client});

  final MedicalApiClient client;

  @override
  State<CalculatorCatalogScreen> createState() =>
      _CalculatorCatalogScreenState();
}

class _CalculatorCatalogScreenState extends State<CalculatorCatalogScreen> {
  final _searchController = TextEditingController();
  late Future<List<CalculatorSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.client.calculators();
  }

  @override
  void didUpdateWidget(covariant CalculatorCatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client.calculatorBaseUrl != widget.client.calculatorBaseUrl) {
      _reload();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload([String? query]) {
    setState(
      () => _future = widget.client.calculators(
        query: query ?? _searchController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            sliver: SliverToBoxAdapter(
              child: SearchBar(
                controller: _searchController,
                hintText: 'Шкала, заболевание или специальность',
                leading: const Icon(Icons.search),
                trailing: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _reload('');
                      },
                      icon: const Icon(Icons.clear),
                    ),
                ],
                onChanged: (_) => setState(() {}),
                onSubmitted: _reload,
              ),
            ),
          ),
          FutureBuilder<List<CalculatorSummary>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorState(
                    message: snapshot.error.toString(),
                    onRetry: _reload,
                  ),
                );
              }
              final calculators = snapshot.data ?? const [];
              if (calculators.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Ничего не найдено.')),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: calculators.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final calculator = calculators[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: const Icon(Icons.monitor_heart_outlined),
                        ),
                        title: Text(
                          calculator.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            calculator.purpose.isEmpty
                                ? calculator.outputType
                                : calculator.purpose,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CalculatorFormScreen(
                              client: widget.client,
                              calculator: calculator,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class CalculatorFormScreen extends StatefulWidget {
  const CalculatorFormScreen({
    super.key,
    required this.client,
    required this.calculator,
  });

  final MedicalApiClient client;
  final CalculatorSummary calculator;

  @override
  State<CalculatorFormScreen> createState() => _CalculatorFormScreenState();
}

class _CalculatorFormScreenState extends State<CalculatorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, Object?> _values = {};
  late Future<List<CalculatorField>> _schema;
  bool _submitting = false;
  CalculationResult? _result;

  @override
  void initState() {
    super.initState();
    _schema = widget.client.calculatorSchema(widget.calculator.toolId);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(CalculatorField field) {
    return _controllers.putIfAbsent(
      field.id,
      () => TextEditingController(text: field.defaultValue?.toString() ?? ''),
    );
  }

  Future<void> _calculate(List<CalculatorField> fields) async {
    if (!_formKey.currentState!.validate()) return;
    final params = <String, dynamic>{};
    for (final field in fields) {
      if (field.type == 'boolean' || field.type == 'select') {
        if (_values[field.id] != null) params[field.id] = _values[field.id];
        continue;
      }
      final value = _controller(field).text.trim();
      if (value.isEmpty) continue;
      final normalizedNumber = value.replaceAll(',', '.');
      params[field.id] = switch (field.type) {
        'integer' => num.parse(normalizedNumber).toInt(),
        'number' => double.parse(normalizedNumber),
        _ => value,
      };
    }
    setState(() {
      _submitting = true;
      _result = null;
    });
    try {
      final result = await widget.client.calculate(
        widget.calculator.toolId,
        params,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Расчёт')),
      body: FutureBuilder<List<CalculatorField>>(
        future: _schema,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onRetry: () => setState(
                () => _schema = widget.client.calculatorSchema(
                  widget.calculator.toolId,
                ),
              ),
            );
          }
          final fields = snapshot.data ?? const [];
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.calculator.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.calculator.purpose,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                ...fields.map(
                  (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _field(field),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _submitting ? null : () => _calculate(fields),
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.calculate),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Рассчитать'),
                  ),
                ),
                if (_result != null) ...[
                  const SizedBox(height: 20),
                  _ResultCard(result: _result!),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Результат является справочным и не заменяет клиническое решение специалиста.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _field(CalculatorField field) {
    if (field.type == 'boolean') {
      final current =
          (_values[field.id] ?? field.defaultValue ?? false) == true;
      _values[field.id] = current;
      return SwitchListTile(
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(_label(field)),
        subtitle: field.description.isEmpty ? null : Text(field.description),
        value: current,
        onChanged: (value) => setState(() => _values[field.id] = value),
      );
    }
    if (field.type == 'select') {
      _values[field.id] ??= field.defaultValue;
      return DropdownButtonFormField<Object?>(
        initialValue: _values[field.id],
        decoration: InputDecoration(
          labelText: _label(field),
          helperText: field.description.isEmpty ? null : field.description,
        ),
        items: field.options
            .map(
              (option) => DropdownMenuItem(
                value: option,
                child: Text(option.toString()),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _values[field.id] = value),
        validator: (value) =>
            field.required && value == null ? 'Выберите значение' : null,
      );
    }
    return TextFormField(
      controller: _controller(field),
      decoration: InputDecoration(
        labelText: _label(field),
        helperText: _helper(field),
        helperMaxLines: 3,
      ),
      keyboardType: field.type == 'integer' || field.type == 'number'
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      validator: (value) {
        final text = value?.trim() ?? '';
        if (field.required && text.isEmpty) {
          return 'Обязательное поле';
        }
        if (text.isEmpty ||
            (field.type != 'integer' && field.type != 'number')) {
          return null;
        }
        final number = num.tryParse(text.replaceAll(',', '.'));
        if (number == null) {
          return 'Введите число';
        }
        if (field.minimum != null && number < field.minimum!) {
          return 'Минимум: ${field.minimum}';
        }
        if (field.maximum != null && number > field.maximum!) {
          return 'Максимум: ${field.maximum}';
        }
        if (field.type == 'integer' && number % 1 != 0) {
          return 'Введите целое число';
        }
        return null;
      },
    );
  }

  String _label(CalculatorField field) =>
      '${field.label}${field.required ? ' *' : ''}';

  String? _helper(CalculatorField field) {
    final range = field.minimum == null && field.maximum == null
        ? ''
        : 'Диапазон: ${field.minimum ?? '...'}–${field.maximum ?? '...'}';
    return [
      field.description,
      range,
      if (field.unit.isNotEmpty) 'Единицы: ${field.unit}',
    ].where((part) => part.isNotEmpty).join('\n');
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final CalculationResult result;

  @override
  Widget build(BuildContext context) {
    if (!result.success) {
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(result.error),
        ),
      );
    }
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Результат',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${result.value ?? '—'} ${result.unit}'.trim(),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            if (result.summary.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                result.summary,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            if (result.recommendation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(result.recommendation),
            ],
            if (result.components.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: result.components.entries
                    .map(
                      (entry) =>
                          Chip(label: Text('${entry.key}: ${entry.value}')),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 52),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
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
