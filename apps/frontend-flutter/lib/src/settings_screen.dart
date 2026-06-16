import 'package:flutter/material.dart';

import 'api_client.dart';
import 'settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings});

  final SettingsController settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _calculatorController;
  late final TextEditingController _knowledgeController;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _calculatorController = TextEditingController(
      text: widget.settings.calculatorApiUrl,
    );
    _knowledgeController = TextEditingController(
      text: widget.settings.knowledgeApiUrl,
    );
  }

  @override
  void dispose() {
    _calculatorController.dispose();
    _knowledgeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final calculator = SettingsController.normalizeBaseUrl(
      _calculatorController.text,
    );
    final knowledge = SettingsController.normalizeBaseUrl(
      _knowledgeController.text,
    );
    if (Uri.tryParse(calculator)?.hasScheme != true ||
        Uri.tryParse(knowledge)?.hasScheme != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите полные адреса с http:// или https://.'),
        ),
      );
      return;
    }
    await widget.settings.save(
      calculatorUrl: calculator,
      knowledgeUrl: knowledge,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Настройки сохранены.')));
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final client = MedicalApiClient(
      calculatorBaseUrl: SettingsController.normalizeBaseUrl(
        _calculatorController.text,
      ),
      knowledgeBaseUrl: SettingsController.normalizeBaseUrl(
        _knowledgeController.text,
      ),
    );
    try {
      final results = await Future.wait([
        client.health(client.calculatorBaseUrl),
        client.health(client.knowledgeBaseUrl),
      ]);
      if (!mounted) return;
      final calculators = results[0]['calculators']?.toString() ?? 'доступен';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Оба API доступны. Калькуляторов: $calculators.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              'assets/logo.jpg',
              width: 132,
              height: 132,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Подключение',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Для реального iPhone используйте HTTPS-адрес сервера. 127.0.0.1 на телефоне указывает на сам телефон.',
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _calculatorController,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'API калькуляторов',
            hintText: 'https://api.example.kz',
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _knowledgeController,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'API базы протоколов',
            hintText: 'https://kb.example.kz',
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Сохранить'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _checking ? null : _check,
          icon: _checking
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.health_and_safety_outlined),
          label: const Text('Проверить подключение'),
        ),
        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'О приложении',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'МедСправочник для iPhone\nВерсия 0.0.0 (сборка 1)\nЗапрошенное обозначение релиза: 0.0.0.01',
        ),
        const SizedBox(height: 12),
        const Text(
          'Только для профессионального справочного использования. Не является медицинским изделием и не заменяет врача.',
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}
