import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'provider_result.dart';

/// Hakuehdot. Record, jotta Riverpodin family vertaa arvoja.
typedef SearchQuery = ({
  String citySlug,
  String serviceCode,
  String date,
  String locale,
});

/// Haku kutsuu samaa RPC:tä kuin sivusto. Sovellus ei järjestä tuloksia
/// uudelleen eikä pisteytä tekijöitä (ADR 0007).
class SearchRepository {
  SearchRepository(this._client);

  final SupabaseClient _client;

  Future<List<ProviderResult>> search(SearchQuery q) async {
    final rows = await _client.rpc('search_providers', params: {
      'p_city_slug': q.citySlug,
      'p_locale': q.locale,
      'p_service_code': q.serviceCode,
      'p_date': q.date,
    });
    return (rows as List)
        .map((r) => ProviderResult.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}

final supabaseClientProvider =
    Provider<SupabaseClient>((ref) => Supabase.instance.client);

final searchRepositoryProvider = Provider<SearchRepository>(
    (ref) => SearchRepository(ref.watch(supabaseClientProvider)));

final searchResultsProvider = FutureProvider.autoDispose
    .family<List<ProviderResult>, SearchQuery>(
        (ref, q) => ref.watch(searchRepositoryProvider).search(q));

/// Kirjautumistila. Kirjautuminen vaihtuu Vipps MobilePay Loginiin (askel 12).
final sessionProvider = StreamProvider<Session?>((ref) async* {
  final auth = ref.watch(supabaseClientProvider).auth;
  yield auth.currentSession;
  await for (final state in auth.onAuthStateChange) {
    yield state.session;
  }
});
