# Pikkutyö – mobiilisovellus (Flutter)

Asiakkaan ja tekijän sovellus iOSille, Androidille ja webiin (app.pikkutyo.fi, ADR 0001). Sovellus kutsuu samoja
Supabase-funktioita kuin sivusto eikä laske hintoja tai aikoja itse. Haku näyttää tulokset
palvelimen järjestyksessä eikä pisteytä tekijöitä (ADR 0007).

Pino: Riverpod (tila), go_router (reitit), supabase_flutter, shared_preferences (asetukset),
gen-l10n (fi, sv, en).

## Tila (23.11.2026)

Runko on tehty ja tarkistukset menevät läpi (`flutter analyze`, 12 testiä). Mukana:

- Alustakansiot `android/`, `ios/` ja `web/` (Flutter 3.47, org `fi.pikkutyo`,
  paketti `pikkutyo_app`). Androidissa on INTERNET-lupa, ja näyttönimi on kaikkialla
  "Pikkutyö".
- Ulkoasu (23.11.2026, malli Tandemosta): vaalea tausta, pyöreäkulmaiset kortit ja kelluva
  alapalkki (Koti, Työt, Viestit, Asetukset). Yhteiset palat ovat `lib/widgets/ui.dart`:ssa.
- Koti: iso kysymys ja hakukortti, jossa vaihdetaan Etsi tekijä / Tarjoa työtä. Lumityö näkyy
  "tulossa", kunnes kategoriat ovat kannassa (askel 1).
- Hakutulokset (`/search?service=&date=`) koko näytölle `search_providers`-funktiolla, ja
  syvälinkki `/book/:slug` sivuston Varaa-napille.
- Työt ja Viestit: tyhjät tilat ja kirjautumiskehote, kunnes varaus ja maksu tehdään (askel 7).
- Kieli (laitteen mukaan, suomi, ruotsi, englanti) ja ulkoasu (laitteen mukaan, vaalea,
  tumma). Valinnat säilyvät laitteella.
- Kirjautumisen ja varauksen paikat sekä testit tietomallille ja sovelluksen rungolle.

Seuraavaksi:

- Kategoriat ja ilmoitukset (suunnitelman askel 1) hakuun ja varausnäkymään.
- Tekijän näkymät: ilmoituksen teko, ajat ja tilausten hyväksyntä.
- Maksuvirta (askel 7): maksutavan tallennus, varaus 24 h ennen työtä, kuittaus kuvalla.
- Vipps MobilePay Login Advanced (askel 12).

## Rakenne

```
lib/main.dart            käynnistys: Supabase, asetukset, ProviderScope
lib/app.dart             MaterialApp.router, teema ja kieli providereista
lib/config.dart          --dart-define-arvot (SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY)
lib/router/              reitit (go_router)
lib/theme/               vaalea ja tumma teema, ulkoasuvalinta
lib/providers/           shared_preferences, kielivalinta
lib/data/                Supabase-kutsut ja tietomalli (search_providers)
lib/widgets/             yhteiset palat: kortit, pillivalitsin, asetusrivit
lib/features/            näkymät: home, search, bookings, messages, auth
lib/l10n/                app_fi.arb, app_sv.arb, app_en.arb
lib/l10n/generated/      gen-l10n:n tuotos (ei gittiin)
```

Teema ja kieli ovat Riverpod-providereita (`themeModeProvider`, `localeProvider`), jotka
lukevat ja tallentavat valinnan `sharedPreferencesProvider`-kautta. Provider annetaan
käynnistyksessä (`main.dart`), ja testit antavat sille oman arvon.

## Käynnistys

```bash
cd apps/app
flutter pub get
cp dart_defines.example.json dart_defines.json   # lisää SUPABASE_PUBLISHABLE_KEY (.env:stä)
flutter run --dart-define-from-file=dart_defines.json
```

`dart_defines.json` ei mene gittiin. Sovellukseen laitetaan vain julkaistava (publishable)
avain, ei koskaan salaista avainta.

Alustakansiot ovat jo tehty. Jos ne pitää joskus luoda uudelleen (uusi alusta tai
vioittunut kansio), komento ei korvaa olemassa olevia tiedostoja:

```bash
flutter create --platforms=android,ios,web --org fi.pikkutyo --project-name pikkutyo_app .
```

Sen jälkeen tarkista, että `android/app/src/main/AndroidManifest.xml` sisältää yhä

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Ilman sitä julkaisuversio ei saa yhteyttä Supabaseen (debug-versiossa lupa on valmiina).

## Tarkistukset

```bash
flutter analyze
flutter test
```
