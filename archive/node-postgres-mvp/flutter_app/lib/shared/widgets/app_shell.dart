import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.path, required this.child});
  final String path;
  final Widget child;

  static const _destinations = [
    (
      label: 'Главная',
      icon: Icons.home_outlined,
      selected: Icons.home_rounded,
      path: '/',
    ),
    (
      label: 'Поиск',
      icon: Icons.search_outlined,
      selected: Icons.search_rounded,
      path: '/search',
    ),
    (
      label: 'Справочник',
      icon: Icons.menu_book_outlined,
      selected: Icons.menu_book_rounded,
      path: '/catalog',
    ),
    (
      label: 'Сохранённое',
      icon: Icons.bookmark_border,
      selected: Icons.bookmark_rounded,
      path: '/saved',
    ),
    (
      label: 'Профиль',
      icon: Icons.person_outline,
      selected: Icons.person_rounded,
      path: '/profile',
    ),
  ];

  int get _index {
    if (path.startsWith('/search')) {
      return 1;
    }
    if (path.startsWith('/catalog') ||
        path.startsWith('/diseases') ||
        path.startsWith('/drugs') ||
        path.startsWith('/articles') ||
        path.startsWith('/calculators')) {
      return 2;
    }
    if (path.startsWith('/saved') ||
        path.startsWith('/notes') ||
        path.startsWith('/history')) {
      return 3;
    }
    if (path.startsWith('/profile') || path.startsWith('/settings')) {
      return 4;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    void select(int index) => context.go(_destinations[index].path);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1180,
              selectedIndex: _index,
              onDestinationSelected: select,
              leading: const Padding(
                padding: EdgeInsets.fromLTRB(8, 22, 8, 28),
                child: _Brand(compact: false),
              ),
              destinations: _destinations
                  .map(
                    (item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selected),
                      label: Text(item.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: _BubbleNavigationBar(
        selectedIndex: _index,
        onSelected: select,
        destinations: _destinations
            .map(
              (item) => _BubbleDestination(
                icon: item.icon,
                selectedIcon: item.selected,
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _BubbleDestination {
  const _BubbleDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _BubbleNavigationBar extends StatelessWidget {
  const _BubbleNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<_BubbleDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: .2),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  flex: selectedIndex == index ? 3 : 1,
                  child: _BubbleNavigationItem(
                    destination: destinations[index],
                    selected: selectedIndex == index,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BubbleNavigationItem extends StatelessWidget {
  const _BubbleNavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _BubbleDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: EdgeInsets.symmetric(horizontal: selected ? 12 : 8),
            decoration: BoxDecoration(
              color: selected ? colors.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: selected ? 1.08 : 1,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    size: 23,
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                  ),
                ),
                Flexible(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    child: selected
                        ? Padding(
                            padding: const EdgeInsets.only(left: 7),
                            child: Text(
                              destination.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: TextStyle(
                                color: colors.onPrimaryContainer,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          Icons.add_rounded,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      if (!compact) ...[
        const SizedBox(width: 11),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MED SPRAVOCHNIK',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            Text('Клинический справочник', style: TextStyle(fontSize: 11)),
          ],
        ),
      ],
    ],
  );
}
