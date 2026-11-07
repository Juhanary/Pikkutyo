// Tietokannan muodot, joita sivusto käyttää. Kun `npm run db:types` on ajettu,
// nämä voidaan johtaa @vaihdarenkaat/db-types-paketista.
import type { Locale } from "@vaihdarenkaat/i18n";

export type I18nText = Partial<Record<Locale, string>> & { fi: string };
export type LocationType = "workshop" | "mobile";
export type ProviderKind = "company" | "individual";

export interface City {
  id: string;
  code: string;
  name: I18nText;
  timezone: string;
  /** Kaupungin slug jokaisella kielellä (hreflang-linkkejä varten). */
  slugs: Record<Locale, string>;
}

export interface District {
  id: string;
  code: string;
  name: I18nText;
  providerCount: number;
  slugs: Record<Locale, string>;
}

export interface CityStat {
  service_code: string;
  location_type: LocationType;
  provider_count: number;
  min_price_cents: number;
  avg_rating: number | null;
}

export interface SearchResult {
  provider_id: string;
  slug: string;
  display_name: string;
  kind: ProviderKind;
  district_name: string | null;
  rating_avg: number | null;
  rating_count: number;
  location_type: LocationType;
  price_cents: number;
  travel_fee_cents: number;
  duration_min: number;
  distance_m: number | null;
  free_slots: number | null;
  first_free_at: string | null;
  /** Rivien (tarjoaja × paikka) kokonaismäärä ennen sivutusta. */
  total_count: number;
  /** Erillisten tarjoajien kokonaismäärä ennen sivutusta. */
  provider_count: number;
}

export interface ProviderService {
  location_type: LocationType;
  price_cents: number;
  travel_fee_cents: number;
  duration_min: number;
  service: { code: string; name: I18nText; sort_order: number };
}

export interface Provider {
  id: string;
  slug: string;
  kind: ProviderKind;
  display_name: string;
  description: I18nText | null;
  service_radius_km: number | null;
  rating_avg: number | null;
  rating_count: number;
  city: City;
  district: { code: string; name: I18nText } | null;
  services: ProviderService[];
}

export interface Review {
  id: string;
  rating: number;
  body: string | null;
  created_at: string;
}

export interface Slot {
  starts_at: string;
  ends_at: string;
  free_resources: number;
}
