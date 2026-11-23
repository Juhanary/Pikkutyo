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

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.text('Asetukset'));
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester) async {
  await tester.tap(find.text('Hae tekijöitä'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => appRouter.go('/home'));

  testWidgets('alapalkki ja koti suomeksi', (tester) async {
    await _pumpApp(tester);

    expect(find.text('Koti'), findsOneWidget);
    expect(find.text('Työt'), findsOneWidget);
    expect(find.text('Viestit'), findsOneWidget);
    expect(find.text('Asetukset'), findsOneWidget);
    expect(find.text('Mitä tehdään?'), findsOneWidget);
    expect(find.text('Renkaanvaihto'), findsOneWidget);
    expect(find.text('Lumityö'), findsOneWidget);
    expect(find.text('Tänään'), findsOneWidget);
  });

  testWidgets('haku näyttää tulokset', (tester) async {
    await _pumpApp(tester,
        rows: [_row('esimerkki-renkaat', 'Esimerkki Renkaat', 3500)]);
    await _search(tester);

    expect(find.text('Hae tekijä'), findsOneWidget);
    expect(find.text('Esimerkki Renkaat'), findsOneWidget);
    expect(find.text('Yritys'), findsOneWidget);
    expect(find.textContaining('35,00'), findsOneWidget);
  });

  testWidgets('tyhjä tulos kertoo siitä', (tester) async {
    await _pumpApp(tester);
    await _search(tester);

    expect(find.text('Tälle päivälle ei löytynyt tekijöitä.'), findsOneWidget);
  });

  testWidgets('tekijän valinta avaa varausnäkymän', (tester) async {
    await _pumpApp(tester,
        rows: [_row('esimerkki-renkaat', 'Esimerkki Renkaat', 3500)]);
    await _search(tester);

    await tester.tap(find.text('Esimerkki Renkaat'));
    await tester.pumpAndSettle();

    expect(find.text('Varaus'), findsOneWidget);
  });

  testWidgets('Tarjoa työtä näyttää tekijän askeleet', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Tarjoa työtä'));
    await tester.pumpAndSettle();

    expect(find.text('Tunnistaudu MobilePaylla'), findsOneWidget);
    expect(find.text('Hae tekijöitä'), findsNothing);
  });

  testWidgets('välilehdet vaihtuvat', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Työt'));
    await tester.pumpAndSettle();
    expect(find.text('Kirjaudu nähdäksesi varauksesi.'), findsOneWidget);
    expect(find.text('Tilaamani'), findsOneWidget);

    await tester.tap(find.text('Viestit'));
    await tester.pumpAndSettle();
    expect(find.text('Kirjaudu nähdäksesi viestisi.'), findsOneWidget);

    await _openSettings(tester);
    expect(find.text('Kirjaudu MobilePaylla'), findsOneWidget);
  });

  testWidgets('kielen vaihto näkyy heti ja tallentuu', (tester) async {
    final prefs = await _pumpApp(tester);
    await _openSettings(tester);

    await tester.tap(find.byType(DropdownButton<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Svenska').last);
    await tester.pumpAndSettle();

    // "Inställningar" on sekä otsikossa että alapalkissa.
    expect(find.text('Inställningar'), findsWidgets);
    expect(find.text('Hem'), findsOneWidget);
    expect(prefs.getString('locale'), 'sv');
  });

  testWidgets('tallennettu kieli otetaan käyttöön käynnistyksessä',
      (tester) async {
    await _pumpApp(tester, prefs: {'locale': 'en'});

    expect(find.text('What needs doing?'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('tumma ulkoasu tallentuu', (tester) async {
    final prefs = await _pumpApp(tester);
    await _openSettings(tester);

    await tester.tap(find.byType(DropdownButton<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tumma').last);
    await tester.pumpAndSettle();

    expect(prefs.getString('theme_mode'), 'dark');
    expect(
      Theme.of(tester.element(find.text('Asetukset').first)).brightness,
      Brightness.dark,
    );
  });
}
