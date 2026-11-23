import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../../theme/theme_mode_provider.dart';

/// Tili: kirjautuminen ja sovelluksen asetukset. Vipps MobilePay Login
/// Advanced kytketään askeleessa 12; sama kirjautuminen tulee sivustolle.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.accountTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(onPressed: null, child: Text(t.signInVipps)),
                const SizedBox(height: 12),
                Text(t.signInComingSoon, textAlign: TextAlign.center),
              ],
            ),
          ),
          const Divider(height: 1),
          _LanguageTile(),
          _ThemeTile(),
        ],
      ),
    );
  }
}

/// Kieli. Laitteen kieli on oletus, ja valinta säilyy käynnistysten yli.
class _LanguageTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final selected = ref.watch(localeProvider)?.languageCode;
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(t.settingsLanguage),
      trailing: DropdownButton<String?>(
        value: selected,
        onChanged: (code) => ref
            .read(localeProvider.notifier)
            .select(code == null ? null : Locale(code)),
        items: [
          DropdownMenuItem(value: null, child: Text(t.optionSystem)),
          for (final code in supportedLanguageCodes)
            DropdownMenuItem(value: code, child: Text(languageNames[code]!)),
        ],
      ),
    );
  }
}

/// Ulkoasu: laitteen mukaan, vaalea tai tumma.
class _ThemeTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final labels = {
      ThemeMode.system: t.optionSystem,
      ThemeMode.light: t.themeLight,
      ThemeMode.dark: t.themeDark,
    };
    return ListTile(
      leading: const Icon(Icons.brightness_6_outlined),
      title: Text(t.settingsTheme),
      trailing: DropdownButton<ThemeMode>(
        value: ref.watch(themeModeProvider),
        onChanged: (mode) => mode == null
            ? null
            : ref.read(themeModeProvider.notifier).select(mode),
        items: [
          for (final entry in labels.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
      ),
    );
  }
}
