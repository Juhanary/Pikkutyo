import 'package:flutter_test/flutter_test.dart';
import 'package:pikkutyo_app/data/provider_result.dart';

void main() {
  group('ProviderResult.fromJson', () {
    test('lukee search_providers-rivin', () {
      final r = ProviderResult.fromJson({
        'provider_id': '7f0c8d5e-0000-0000-0000-000000000001',
        'slug': 'esimerkki-renkaat',
        'display_name': 'Esimerkki Renkaat',
        'kind': 'company',
        'district_name': 'Petonen',
        'rating_avg': 4.5,
        'rating_count': 12,
        'location_type': 'workshop',
        'price_cents': 3500,
        'travel_fee_cents': 0,
        'duration_min': 45,
        'distance_m': 1200,
        'free_slots': 3,
        'first_free_at': '2026-11-24T08:00:00+00:00',
        'total_count': 1,
        'provider_count': 1,
      });
      expect(r.slug, 'esimerkki-renkaat');
      expect(r.kind, ProviderKind.business);
      expect(r.ratingAvg, 4.5);
      expect(r.distanceM, 1200.0);
      expect(r.freeSlots, 3);
      expect(r.firstFreeAt, DateTime.utc(2026, 11, 24, 8));
    });

    test('sallii puuttuvat arvot', () {
      final r = ProviderResult.fromJson({
        'provider_id': 'x',
        'slug': 's',
        'display_name': 'Matti',
        'kind': 'individual',
        'rating_avg': null,
        'rating_count': 0,
        'price_cents': 2000,
        'travel_fee_cents': null,
        'duration_min': 60,
        'distance_m': null,
        'free_slots': null,
        'first_free_at': null,
      });
      expect(r.kind, ProviderKind.privatePerson);
      expect(r.ratingAvg, isNull);
      expect(r.travelFeeCents, 0);
      expect(r.freeSlots, 0);
    });
  });

  test('tekijätyypit', () {
    expect(parseProviderKind('private_person'), ProviderKind.privatePerson);
    expect(parseProviderKind('sole_trader'), ProviderKind.business);
  });

  test('isoDate', () {
    expect(isoDate(DateTime(2026, 1, 5)), '2026-01-05');
  });

  test('formatEuros suomeksi', () {
    final s = formatEuros(3550, 'fi');
    expect(s, contains('35,50'));
    expect(s, contains('€'));
  });
}
