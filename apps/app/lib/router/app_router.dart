import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/account_screen.dart';
import '../features/bookings/book_screen.dart';
import '../features/bookings/bookings_screen.dart';
import '../features/search/search_screen.dart';
import '../l10n/generated/app_localizations.dart';

/// Reitit. `/book/:slug` on sivuston Varaa-napin syvälinkin kohde (ADR 0001).
final appRouter = GoRouter(
  initialLocation: '/search',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _Shell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/bookings', builder: (_, __) => const BookingsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/account', builder: (_, __) => const AccountScreen()),
        ]),
      ],
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
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.search), label: t.navSearch),
          NavigationDestination(
              icon: const Icon(Icons.event_note), label: t.navBookings),
          NavigationDestination(
              icon: const Icon(Icons.person_outline), label: t.navAccount),
        ],
      ),
    );
  }
}
