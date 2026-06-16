import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/models/medical_content.dart';
import '../features/calculators/presentation/calculators_screen.dart';
import '../features/catalog/presentation/catalog_screens.dart';
import '../features/details/presentation/medical_detail_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/personal/presentation/personal_screens.dart';
import '../features/search/presentation/search_screen.dart';
import '../shared/widgets/app_shell.dart';

NoTransitionPage<void> _tabPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}

final appRouter = GoRouter(
  initialLocation: '/',
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(),
    body: const Center(child: Text('Страница не найдена')),
  ),
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(path: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (_, state) => _tabPage(state, const HomeScreen()),
        ),
        GoRoute(
          path: '/search',
          pageBuilder: (_, state) => _tabPage(state, const SearchScreen()),
        ),
        GoRoute(
          path: '/catalog',
          pageBuilder: (_, state) => _tabPage(state, const CatalogScreen()),
        ),
        GoRoute(
          path: '/diseases',
          pageBuilder: (_, state) => _tabPage(
            state,
            const ItemListScreen(
              type: ContentType.disease,
              title: 'Заболевания',
            ),
          ),
        ),
        GoRoute(
          path: '/drugs',
          pageBuilder: (_, state) => _tabPage(
            state,
            const ItemListScreen(type: ContentType.drug, title: 'Препараты'),
          ),
        ),
        GoRoute(
          path: '/calculators',
          pageBuilder: (_, state) => _tabPage(state, const CalculatorsScreen()),
        ),
        GoRoute(
          path: '/calculators/category/:categoryId',
          pageBuilder: (_, state) => _tabPage(
            state,
            CalculatorCategoryScreen(
              categoryId: state.pathParameters['categoryId']!,
            ),
          ),
        ),
        GoRoute(
          path: '/articles',
          pageBuilder: (_, state) => _tabPage(
            state,
            const ItemListScreen(
              type: ContentType.article,
              title: 'Рекомендации',
            ),
          ),
        ),
        GoRoute(
          path: '/saved',
          pageBuilder: (_, state) => _tabPage(state, const SavedScreen()),
        ),
        GoRoute(
          path: '/history',
          pageBuilder: (_, state) => _tabPage(state, const HistoryScreen()),
        ),
        GoRoute(
          path: '/notes',
          pageBuilder: (_, state) => _tabPage(state, const NotesScreen()),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (_, state) => _tabPage(state, const ProfileScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (_, state) => _tabPage(state, const SettingsScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/detail/:id',
      builder: (_, state) =>
          MedicalDetailScreen(id: state.pathParameters['id']!),
    ),
  ],
);
