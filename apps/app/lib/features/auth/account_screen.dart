import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/search_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/locale_provider.dart';
import '../../theme/theme_mode_provider.dart';
import '../../widgets/ui.dart';

/// Asetukset: profiili tai kirjautuminen ylimpänä, sen alla ryhmitellyt
/// asetukset. Vipps MobilePay Login Advanced kytketään askeleessa 12; sama
/// kirjautuminen tulee sivustolle.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider).valueOrNull;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, bottomBarClearance),
          children: [
            ScreenTitle(t.navSettings),
            const SizedBox(height: 16),
            if (session == null)
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(onPressed: null, child: Text(t.signInVipps)),
                    const SizedBox(height: 12),
                    Text(t.signInComingSoon, textAlign: TextAlign.center),
                  ],
                ),
              )
            else
              _ProfileCard(
                name: _displayName(session.user.userMetadata?['name']) ??
                    session.user.email ??
                    '',
              ),
            SectionLabel(t.settingsSectionApp),
            SettingsGroup(
              children: [
                SettingsRow(
                  icon: Icons.language,
                  title: t.settingsLanguage,
                  trailing: const _LanguageDropdown(),
                ),
                SettingsRow(
                  icon: Icons.dark_mode_outlined,
                  title: t.settingsTheme,
                  trailing: const _ThemeDropdown(),
                ),
              ],
            ),
            if (session != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(supabaseClientProvider).auth.signOut(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .error
                        .withValues(alpha: 0.4),
                  ),
                  shape: const StadiumBorder(),
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.logout),
                label: Text(t.signOut),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String? _displayName(Object? name) =>
    name is String && name.trim().isNotEmpty ? name.trim() : null;

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.10),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kieli. Laitteen kieli on oletus, ja valinta säilyy käynnistysten yli.
class _LanguageDropdown extends ConsumerWidget {
  const _LanguageDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final selected = ref.watch(localeProvider)?.languageCode;
    return DropdownButton<String?>(
      value: selected,
      underline: const SizedBox.shrink(),
      borderRadius: controlBorderRadius,
      onChanged: (code) => ref
          .read(localeProvider.notifier)
          .select(code == null ? null : Locale(code)),
      items: [
        DropdownMenuItem(value: null, child: Text(t.optionSystem)),
        for (final code in supportedLanguageCodes)
          DropdownMenuItem(value: code, child: Text(languageNames[code]!)),
      ],
    );
  }
}

/// Ulkoasu: laitteen mukaan, vaalea tai tumma.
class _ThemeDropdown extends ConsumerWidget {
  const _ThemeDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final labels = {
      ThemeMode.system: t.optionSystem,
      ThemeMode.light: t.themeLight,
      ThemeMode.dark: t.themeDark,
    };
    return DropdownButton<ThemeMode>(
      value: ref.watch(themeModeProvider),
      underline: const SizedBox.shrink(),
      borderRadius: controlBorderRadius,
      onChanged: (mode) => mode == null
          ? null
          : ref.read(themeModeProvider.notifier).select(mode),
      items: [
        for (final entry in labels.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
    );
  }
}
