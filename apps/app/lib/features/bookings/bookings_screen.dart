import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/search_repository.dart';
import '../../l10n/generated/app_localizations.dart';

/// Omat varaukset. Lista kytketään, kun varaus ja maksu tehdään (askel 7).
class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final signedIn = ref.watch(sessionProvider).valueOrNull != null;
    return Scaffold(
      appBar: AppBar(title: Text(t.navBookings)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: signedIn
              ? Text(t.bookingsEmpty, textAlign: TextAlign.center)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.bookingsSignIn, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: () => context.go('/account'),
                      child: Text(t.signInTitle),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
