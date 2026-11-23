import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/work_type.dart';
import '../features/auth/account_screen.dart';
import '../features/bookings/book_screen.dart';
import '../features/bookings/bookings_screen.dart';
import '../features/home/home_screen.dart';
import '../features/messages/messages_screen.dart';
import '../features/search/search_screen.dart';
import '../l10n/generated/app_localizations.dart';

/// Reitit. Alapalkissa on neljä välilehteä (Koti, Työt, Viestit, Asetukset).
/// Hakutulokset (`/search`) ja varaus (`/book/:slug`) avautuvat koko näytölle
/// ilman alapalkkia. `/book/:slug` on sivuston Varaa-napin syvälinkin kohde
/// (ADR 0001).
final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _Shell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/bookings', builder: (_, __) => const BookingsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/messages', builder: (_, __) => const MessagesScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/account', builder: (_, __) => const AccountScreen()),
        ]),
      ],
    ),
    GoRoute(
      path: '/search',
      builder: (_, state) {
        final params = state.uri.queryParameters;
        return SearchScreen(
          serviceCode: params['service'] ?? defaultServiceCode,
          date: DateTime.tryParse(params['date'] ?? ''),
        );
      },
    ),
    GoRoute(
      path: '/book/:slug',
      builder: (_, state) => BookScreen(slug: state.pathParameters['slug']!),
    ),
  ],
);

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final items = [
      (Icons.home_outlined, Icons.home, t.navHome),
      (Icons.work_outline, Icons.work, t.navJobs),
      (Icons.chat_bubble_outline, Icons.chat_bubble, t.navMessages),
      (Icons.settings_outlined, Icons.settings, t.navSettings),
    ];
    return Scaffold(
      // Sisältö jatkuu kelluvan palkin alle; näkymät jättävät listan loppuun
      // tilaa (bottomBarClearance).
      extendBody: true,
      body: shell,
      bottomNavigationBar: _FloatingNavBar(
        items: items,
        selected: shell.currentIndex,
        onSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}

/// Kelluva pillin muotoinen alapalkki. Valittu välilehti on täytetty
/// pääväriä.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<(IconData, IconData, String)> items;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Material(
        color: scheme.surface,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        shape: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: i == selected ? items[i].$2 : items[i].$1,
                    label: items[i].$3,
                    selected: i == selected,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.onPrimary : scheme.primary;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? scheme.primary : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 62,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
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
