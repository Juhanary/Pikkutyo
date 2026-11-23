import 'package:intl/intl.dart';

/// Tekijän asema. Kanta käyttää vielä arvoja `company | individual`;
/// suunnitelman mukaiset `sole_trader` ja `private_person` tulevat askeleessa 4.
enum ProviderKind { business, privatePerson }

ProviderKind parseProviderKind(String? value) => switch (value) {
      'individual' || 'private_person' => ProviderKind.privatePerson,
      _ => ProviderKind.business,
    };

/// Yksi rivi `search_providers`-funktion tuloksesta.
class ProviderResult {
  const ProviderResult({
    required this.id,
    required this.slug,
    required this.displayName,
    required this.kind,
    required this.priceCents,
    required this.travelFeeCents,
    required this.durationMin,
    required this.freeSlots,
    required this.ratingCount,
    this.districtName,
    this.ratingAvg,
    this.distanceM,
    this.firstFreeAt,
  });

  factory ProviderResult.fromJson(Map<String, dynamic> json) {
    final firstFree = json['first_free_at'] as String?;
    return ProviderResult(
      id: json['provider_id'] as String,
      slug: json['slug'] as String,
      displayName: json['display_name'] as String,
      kind: parseProviderKind(json['kind'] as String?),
      districtName: json['district_name'] as String?,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble(),
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      priceCents: (json['price_cents'] as num).toInt(),
      travelFeeCents: (json['travel_fee_cents'] as num?)?.toInt() ?? 0,
      durationMin: (json['duration_min'] as num).toInt(),
      distanceM: (json['distance_m'] as num?)?.toDouble(),
      freeSlots: (json['free_slots'] as num?)?.toInt() ?? 0,
      firstFreeAt: firstFree == null ? null : DateTime.parse(firstFree),
    );
  }

  final String id;
  final String slug;
  final String displayName;
  final ProviderKind kind;
  final String? districtName;
  final double? ratingAvg;
  final int ratingCount;
  final int priceCents;
  final int travelFeeCents;
  final int durationMin;
  final double? distanceM;
  final int freeSlots;
  final DateTime? firstFreeAt;
}

/// Senttimäärä euroina käyttäjän kielellä, esim. "35,00 €".
String formatEuros(int cents, String locale) =>
    NumberFormat.currency(locale: locale, symbol: '€', decimalDigits: 2)
        .format(cents / 100);

/// Päivä muodossa YYYY-MM-DD (Postgresin `date`).
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
