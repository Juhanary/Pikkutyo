import 'package:flutter/material.dart';

/// Sama pääväri kuin sivustolla (apps/web: --c-primary).
const brandPrimary = Color(0xFF0A4F9E);

/// Taustat samoina kuin sivustolla (--c-bg ja --c-surface).
const _lightBackground = Color(0xFFF3F5F7);
const _darkBackground = Color(0xFF161B21);
const _darkSurface = Color(0xFF1F262E);
const _darkPrimary = Color(0xFF6AA5EC);

/// Kortin ja painikkeiden pyöristykset. Ulkoasu: vaalea tausta, valkoiset
/// pyöreäkulmaiset kortit ja kelluva alapalkki.
const cardRadius = 24.0;
const controlRadius = 16.0;

/// Vaalea ja tumma teema. Värit tulevat samasta siemenväristä, joten
/// sovellus näyttää sivuston kanssa samalta molemmissa.
abstract final class AppTheme {
  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: brandPrimary,
      brightness: brightness,
      primary: dark ? _darkPrimary : brandPrimary,
      surface: dark ? _darkSurface : Colors.white,
    );
    final background = dark ? _darkBackground : _lightBackground;
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(controlRadius),
    );
    const buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
    const buttonSize = Size(64, 52);

    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: controlShape,
          textStyle: buttonText,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: buttonText),
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 10),
    );
  }
}
