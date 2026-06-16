import 'package:flutter/material.dart';

import 'api_client.dart';
import 'calculator_screen.dart';
import 'knowledge_screen.dart';
import 'settings_controller.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.settings});

  final SettingsController settings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  MedicalApiClient get _client => MedicalApiClient(
    calculatorBaseUrl: widget.settings.calculatorApiUrl,
    knowledgeBaseUrl: widget.settings.knowledgeApiUrl,
  );

  @override
  Widget build(BuildContext context) {
    final pages = [
      CalculatorCatalogScreen(client: _client),
      KnowledgeScreen(client: _client),
      SettingsScreen(settings: widget.settings),
    ];
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(switch (_index) {
            0 => 'Калькуляторы',
            1 => 'Протоколы',
            _ => 'Настройки',
          }),
        ),
        body: SafeArea(
          child: IndexedStack(index: _index, children: pages),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calculate_outlined),
              selectedIcon: Icon(Icons.calculate),
              label: 'Расчёты',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Протоколы',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Настройки',
            ),
          ],
        ),
      ),
    );
  }
}
