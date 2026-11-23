import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/search_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/ui.dart';
import '../bookings/bookings_screen.dart';

/// Viestit asiakkaan ja tekijän välillä. Viestit kuuluvat tilaukseen, joten
/// ne kytketään varauksen kanssa (askel 7).
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final signedIn = ref.watch(sessionProvider).valueOrNull != null;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, bottomBarClearance),
          children: [
            ScreenTitle(t.navMessages),
            const SizedBox(height: 16),
            if (!signedIn)
              SignInPrompt(text: t.messagesSignIn)
            else
              EmptyCard(text: t.messagesEmpty),
          ],
        ),
      ),
    );
  }
}
