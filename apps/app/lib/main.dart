import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'providers/shared_preferences_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!AppConfig.isConfigured) {
    throw StateError(
      'SUPABASE_URL ja SUPABASE_PUBLISHABLE_KEY puuttuvat. '
      'Käynnistä: flutter run --dart-define-from-file=dart_defines.json',
    );
  }
  // Vain julkaistava (publishable) avain. Salaista avainta ei koskaan laiteta
  // sovellukseen.
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseKey,
  );
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const PikkutyoApp(),
    ),
  );
}
