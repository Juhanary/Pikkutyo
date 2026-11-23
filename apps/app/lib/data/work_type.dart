/// Työlajit. Kanta tuntee toistaiseksi vain renkaanvaihdon; lumityö tulee,
/// kun kategoriat lisätään (suunnitelman askel 1). Siihen asti se näytetään
/// valinnassa "tulossa" eikä sitä voi valita.
enum WorkType {
  tireChange('tire_change', available: true),
  snowWork('snow_work', available: false);

  const WorkType(this.code, {required this.available});

  /// Palvelun koodi `search_providers`-funktiolle.
  final String code;

  /// Voiko työlajia jo hakea.
  final bool available;
}

/// Haun oletuspalvelu.
const defaultServiceCode = 'tire_change';
