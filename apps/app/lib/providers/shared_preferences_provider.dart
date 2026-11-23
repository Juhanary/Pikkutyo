import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Laitteelle tallennetut asetukset (kieli ja ulkoasu). Arvo annetaan
/// käynnistyksessä (`main.dart`), jotta asetukset ovat valmiina ensimmäisessä
/// ruudussa. Testit antavat oman arvon `overrideWithValue`-kutsulla.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError(
    'sharedPreferencesProvider pitää ylikirjoittaa käynnistyksessä.',
  ),
);
