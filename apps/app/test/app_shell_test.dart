import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikkutyo_app/app.dart';
import 'package:pikkutyo_app/data/provider_result.dart';
import 'package:pikkutyo_app/data/search_repository.dart';
import 'package:pikkutyo_app/providers/shared_preferences_provider.dart';
import 'package:pikkutyo_app/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

ProviderResult _row(String slug, String name, int priceCents) => ProviderResult(
      id: slug,
      slug: slug,
      displayName: name,
      kind: ProviderKind.business,
      priceCents: priceCents,
      travelFeeCents: 0,
      durationMin: 45,
      freeSlots: 2,
      ratingCount: 0,
    );

/// Pumppaa sovelluksen ilman verkkoa: haku palauttaa annetut rivit
/// `search_providers`-funktion sijaan ja käyttäjä on kirjautumaton.
/// Sovellus ei järjestä tuloksia uudelleen (ADR 0007), joten rivit näkyvät
/// siinä järjestyksessä kuin ne annetaan.
Future<SharedPreferences> _pumpApp(
  WidgetTester tester, {
  List<ProviderResult> rows = const [],
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  tester.platformDispatcher.localesTestValue = const [Locale('fi')];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        searchResultsProvider.overrideWith((ref, query) async => rows),
        sessionProvider.overrideWith((ref) => Stream<Session?>.value(null)),
      ],
      child: const PikkutyoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return preferences;
}

Future<void> _openAccount(WidgetTester tester) async {
  await tester.tap(find.text('Tili'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => appRouter.go('/search'));

  testWidgets('alanavigaatio ja haku suomeksi', (tester) async {
    await _pumpApp(tester,
        rows: [_row('esimerkki-renkaat', 'Esimerkki Renkaat', 3500)]);

    expect(find.text('Haku'), findsOneWidget);
    expect(find.text('Varaukset'), findsOneWidget);
    expect(find.text('Tili'), findsOneWidget);
    expect(find.text('Hae tekijä'), findsOneWidget);
    expect(find.text('Esimerkki Renkaat'), findsOneWidget);
    expect(find.textContaining('35,00'), findsOneWidget);
  });

  testWidgets('tyhjä tulos kertoo siitä', (tester) async {
    await _pumpApp(tester);

    expect(find.text('Tälle päivälle ei löytynyt tekijöitä.'), findsOneWidget);
  });

  testWidgets('tekijän valinta avaa varausnäkymän', (tester) async {
    await _pumpApp(tester,
        rows: [_row('esimerkki-renkaat', 'Esimerkki Renkaat', 3500)]);

    await tester.tap(find.text('Esimerkki Renkaat'));
    await tester.pumpAndSettle();

    expect(find.text('Varaus'), findsOneWidget);
  });

  testWidgets('välilehdet vaihtuvat', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Varaukset'));
    await tester.pumpAndSettle();
    expect(find.text('Kirjaudu nähdäksesi varauksesi.'), findsOneWidget);

    await _openAccount(tester);
    expect(find.text('Kirjaudu MobilePaylla'), findsOneWidget);
  });

  testWidgets('kielen vaihto näkyy heti ja tallentuu', (tester) async {
    final prefs = await _pumpApp(tester);
    await _openAccount(tester);

    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Svenska').last);
    await tester.pumpAndSettle();

    // "Konto" on sekä otsikossa että alanavigaatiossa.
    expect(find.text('Konto'), findsWidgets);
    expect(find.text('Sök'), findsOneWidget);
    expect(prefs.getString('locale'), 'sv');
  });

  testWidgets('tallennettu kieli otetaan käyttöön käynnistyksessä',
      (tester) async {
    await _pumpApp(tester, prefs: {'locale': 'en'});

    expect(find.text('Find a provider'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('tumma ulkoasu tallentuu', (tester) async {
    final prefs = await _pumpApp(tester);
    await _openAccount(tester);

    await tester.tap(find.byType(DropdownButton<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tumma').last);
    await tester.pumpAndSettle();

    expect(prefs.getString('theme_mode'), 'dark');
    expect(
      Theme.of(tester.element(find.text('Tili').first)).brightness,
      Brightness.dark,
    );
  });
}
