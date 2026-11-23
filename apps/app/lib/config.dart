/// Ajonaikaiset asetukset. Annetaan käynnistyksessä:
/// `flutter run --dart-define-from-file=dart_defines.json`.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Pilotin ainoa kaupunki.
  static const defaultCitySlug = 'kuopio';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
