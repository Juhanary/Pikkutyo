import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/search_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/ui.dart';

/// Työt: asiakkaana tilatut ja tekijänä tehtävät työt. Listat kytketään, kun
/// varaus ja maksu tehdään (askel 7).
class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final signedIn = ref.watch(sessionProvider).valueOrNull != null;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, bottomBarClearance),
          children: [
            ScreenTitle(t.navJobs),
            const SizedBox(height: 16),
            PillTabs(
              labels: [t.jobsOrdered, t.jobsDoing],
              selected: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 16),
            if (!signedIn)
              SignInPrompt(text: t.bookingsSignIn)
            else
              EmptyCard(text: _tab == 0 ? t.bookingsEmpty : t.jobsDoingEmpty),
          ],
        ),
      ),
    );
  }
}

/// Kirjautumiskehote kortissa. Vie Asetukset-välilehdelle.
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return EmptyCard(
      text: text,
      action: TextButton(
        onPressed: () => context.go('/account'),
        child: Text(t.signInTitle),
      ),
    );
  }
}
