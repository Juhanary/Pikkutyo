import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

/// Varausnäkymä. Ajat, kortin tallennus ja maksun varaus tulevat
/// askeleissa 1 ja 7.
class BookScreen extends StatelessWidget {
  const BookScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.bookTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(t.bookComingSoon, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
