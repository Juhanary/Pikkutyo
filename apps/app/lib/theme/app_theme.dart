import 'package:flutter/material.dart';

/// Sama pääväri kuin sivustolla (apps/web: --c-primary).
const brandPrimary = Color(0xFF0A4F9E);

/// Vaalea ja tumma teema. Värit tulevat samasta siemenväristä, joten
/// sovellus näyttää sivuston kanssa samalta molemmissa.
abstract final class AppTheme {
  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandPrimary,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 10),
    );
  }
}
