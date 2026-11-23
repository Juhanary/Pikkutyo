import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/shared_preferences_provider.dart';

/// Vaalea, tumma vai laitteen mukaan. Valinta säilyy käynnistysten yli.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final name = ref.watch(sharedPreferencesProvider).getString(_key);
    return ThemeMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> select(ThemeMode mode) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (mode == ThemeMode.system) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, mode.name);
    }
    state = mode;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
