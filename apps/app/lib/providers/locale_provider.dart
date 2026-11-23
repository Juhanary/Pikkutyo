import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'shared_preferences_provider.dart';

/// Sovelluksen kielet. Samat kuin sivustolla (`packages/i18n`).
const supportedLanguageCodes = ['fi', 'sv', 'en'];

/// Kielten omakieliset nimet valikkoon.
const languageNames = {'fi': 'Suomi', 'sv': 'Svenska', 'en': 'English'};

/// Valittu kieli. `null` tarkoittaa laitteen kieltä.
class LocaleController extends Notifier<Locale?> {
  static const _key = 'locale';

  @override
  Locale? build() {
    final code = ref.watch(sharedPreferencesProvider).getString(_key);
    return code != null && supportedLanguageCodes.contains(code)
        ? Locale(code)
        : null;
  }

  /// Vaihtaa kielen ja tallentaa valinnan. `null` palauttaa laitteen kielen.
  Future<void> select(Locale? locale) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
    state = locale;
  }
}

final localeProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);
