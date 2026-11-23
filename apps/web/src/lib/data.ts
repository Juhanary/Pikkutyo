// Palvelinpuolen datahaut Supabasesta. Kaikki haut käyttävät publishable-avainta,
// joten RLS rajaa näkyvän datan samoin kuin selaimessa. Tulokset välimuistitetaan
// Next.js:n fetch-välimuistiin tageilla, joita revalidate-rajapinta mitätöi.
import type { Locale } from "@pikkutyo/i18n";
import { locales } from "@pikkutyo/i18n";
import { createClient } from "@supabase/supabase-js";
import { env } from "./env";
import type {
  City,
  CityStat,
  District,
  I18nText,
  LocationType,
  Provider,
  ProviderKind,
  ProviderService,
  Review,
  SearchResult,
} from "./types";

export const REVALIDATE_SECONDS = 3600;

export const tags = {
  cities: "cities",
  city: (id: string) => `city:${id}`,
  providers: "providers",
  provider: (id: string) => `provider:${id}`,
};

function db(cacheTags: string[], revalidate: number | false = REVALIDATE_SECONDS) {
  return createClient(env.supabaseUrl, env.supabasePublishableKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
    global: {
      fetch: (input, init) =>
        fetch(input, {
          ...init,
          ...(revalidate === 0
            ? { cache: "no-store" as const }
            : { cache: "force-cache" as const, next: { revalidate, tags: cacheTags } }),
        }),
    },
  });
}

function fail(what: string, error: { message: string } | null): never {
  throw new Error(`Supabase: ${what}: ${error?.message ?? "tuntematon virhe"}`);
}

type SlugRow = { locale: Locale; slug: string };

function slugMap(rows: SlugRow[]): Record<Locale, string> {
  const map = {} as Record<Locale, string>;
  for (const row of rows) map[row.locale] = row.slug;
  // Puuttuva käännös → suomenkielinen slug.
  for (const l of locales) map[l] ??= map.fi;
  return map;
}

type CityRow = { id: string; code: string; name: I18nText; timezone: string; city_slugs: SlugRow[] };

const CITY_COLUMNS = "id, code, name, timezone, city_slugs(locale, slug)";

function toCity(row: CityRow): City {
  return { id: row.id, code: row.code, name: row.name, timezone: row.timezone, slugs: slugMap(row.city_slugs) };
}

export async function getActiveCities(): Promise<City[]> {
  const { data, error } = await db([tags.cities])
    .from("cities")
    .select(CITY_COLUMNS)
    .eq("active", true)
    .order("code");
  if (error) fail("kaupungit", error);
  return (data as unknown as CityRow[]).map(toCity);
}

export async function getCityById(id: string): Promise<City | null> {
  const { data, error } = await db([tags.cities, tags.city(id)])
    .from("cities")
    .select(CITY_COLUMNS)
    .eq("id", id)
    .maybeSingle();
  if (error) fail("kaupunki", error);
  return data ? toCity(data as unknown as CityRow) : null;
}

/**
 * Hakee kaupungin slugilla. Jos kaupungilla ei ole slugia pyydetyllä kielellä,
 * suomenkielinen slug kelpaa (sama varakäytäntö kuin slugMap:ssa ja search_providersissa).
 */
export async function getCityBySlug(locale: Locale, slug: string): Promise<City | null> {
  const { data, error } = await db([tags.cities])
    .from("city_slugs")
    .select("city_id, locale")
    .eq("slug", slug)
    .in("locale", locale === "fi" ? ["fi"] : [locale, "fi"]);
  if (error) fail("kaupungin slug", error);
  const rows = data as { city_id: string; locale: Locale }[];
  const row = rows.find((r) => r.locale === locale) ?? rows.find((r) => r.locale === "fi");
  if (!row) return null;
  const city = await getCityById(row.city_id);
  // Suomenkielinen slug kelpaa vain, jos se on myös tämän kielen (vara)slug.
  return city && city.slugs[locale] === slug ? city : null;
}

export async function getCityStats(cityId: string): Promise<CityStat[]> {
  const { data, error } = await db([tags.city(cityId), tags.providers])
    .from("city_stats")
    .select("service_code, location_type, provider_count, min_price_cents, avg_rating")
    .eq("city_id", cityId);
  if (error) fail("kaupungin tilastot", error);
  return data as CityStat[];
}

/** Kaupunginosat, joilla on oma sivu (vähintään 3 aktiivista tarjoajaa). */
export async function getPublishedDistricts(cityId: string): Promise<District[]> {
  const client = db([tags.city(cityId), tags.providers]);
  const { data, error } = await client
    .from("published_districts")
    .select("district_id, code, name, provider_count")
    .eq("city_id", cityId)
    .order("code");
  if (error) fail("kaupunginosat", error);
  const rows = data as { district_id: string; code: string; name: I18nText; provider_count: number }[];
  if (rows.length === 0) return [];

  const { data: slugs, error: slugError } = await client
    .from("district_slugs")
    .select("district_id, locale, slug")
    .in("district_id", rows.map((r) => r.district_id));
  if (slugError) fail("kaupunginosien slugit", slugError);
  const byDistrict = new Map<string, SlugRow[]>();
  for (const s of slugs as (SlugRow & { district_id: string })[]) {
    byDistrict.set(s.district_id, [...(byDistrict.get(s.district_id) ?? []), s]);
  }

  return rows.map((r) => ({
    id: r.district_id,
    code: r.code,
    name: r.name,
    providerCount: r.provider_count,
    slugs: slugMap(byDistrict.get(r.district_id) ?? []),
  }));
}

export interface SearchParams {
  citySlug: string;
  locale: Locale;
  serviceCode?: string;
  locationType?: LocationType;
  providerKind?: ProviderKind;
  districtSlug?: string;
  date?: string;
  timeFrom?: string;
  timeTo?: string;
  limit?: number;
  offset?: number;
}

/**
 * Tarjoajahaku. Ilman päivämäärää tulos välimuistitetaan (kaupunkisivut),
 * päivämäärän kanssa haetaan aina tuoreena (vapaat ajat muuttuvat jatkuvasti).
 */
export async function searchProviders(p: SearchParams): Promise<SearchResult[]> {
  const fresh = Boolean(p.date);
  const { data, error } = await db([tags.providers], fresh ? 0 : REVALIDATE_SECONDS).rpc(
    "search_providers",
    // GET-kutsussa null muuttuisi merkkijonoksi "null": puuttuvat arvot jätetään
    // pois (undefined), jolloin funktion oletusarvot pätevät.
    {
      p_city_slug: p.citySlug,
      p_locale: p.locale,
      p_service_code: p.serviceCode ?? "tire_change",
      p_location_type: p.locationType,
      p_provider_kind: p.providerKind,
      p_district_slug: p.districtSlug,
      p_date: p.date,
      p_time_from: p.timeFrom,
      p_time_to: p.timeTo,
      p_limit: p.limit ?? 50,
      p_offset: p.offset ?? 0,
    },
    { get: true },
  );
  if (error) fail("haku", error);
  return data as SearchResult[];
}

type ProviderRow = {
  id: string;
  slug: string;
  kind: ProviderKind;
  display_name: string;
  description: I18nText | null;
  service_radius_km: number | null;
  rating_avg: number | null;
  rating_count: number;
  city_id: string;
  districts: { code: string; name: I18nText } | null;
  provider_services: (Omit<ProviderService, "service"> & {
    active: boolean;
    services: ProviderService["service"] | null;
  })[];
};

export async function getProviderBySlug(slug: string): Promise<Provider | null> {
  // Ensin slug → id, jotta varsinainen haku voidaan tagata tarjoajakohtaisesti
  // (provider:<id>): yhden tarjoajan muutos ei silloin vaadi koko providers-tagin mitätöintiä.
  const { data: idRow, error: idError } = await db([tags.providers])
    .from("providers")
    .select("id")
    .eq("slug", slug)
    .maybeSingle();
  if (idError) fail("tarjoajan slug", idError);
  if (!idRow) return null;
  const id = (idRow as { id: string }).id;

  const { data, error } = await db([tags.providers, tags.provider(id)])
    .from("providers")
    .select(
      `id, slug, kind, display_name, description, service_radius_km, rating_avg, rating_count, city_id,
       districts(code, name),
       provider_services(location_type, price_cents, travel_fee_cents, duration_min, active,
                         services(code, name, sort_order))`,
    )
    .eq("id", id)
    .eq("status", "active")
    .maybeSingle();
  if (error) fail("tarjoaja", error);
  if (!data) return null;

  const row = data as unknown as ProviderRow;
  const city = await getCityById(row.city_id);
  if (!city) return null;

  const services: ProviderService[] = row.provider_services
    .filter((s) => s.active && s.services)
    .map((s) => ({
      location_type: s.location_type,
      price_cents: s.price_cents,
      travel_fee_cents: s.travel_fee_cents,
      duration_min: s.duration_min,
      service: s.services!,
    }))
    .sort(
      (a, b) =>
        a.service.sort_order - b.service.sort_order || a.location_type.localeCompare(b.location_type),
    );

  return {
    id: row.id,
    slug: row.slug,
    kind: row.kind,
    display_name: row.display_name,
    description: row.description,
    service_radius_km: row.service_radius_km,
    rating_avg: row.rating_avg,
    rating_count: row.rating_count,
    city,
    district: row.districts,
    services,
  };
}

export async function getReviews(providerId: string, limit = 10): Promise<Review[]> {
  const { data, error } = await db([tags.provider(providerId)])
    .from("reviews")
    .select("id, rating, body, created_at")
    .eq("provider_id", providerId)
    .eq("published", true)
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) fail("arvostelut", error);
  return data as Review[];
}

export async function getActiveProviderSlugs(): Promise<{ slug: string; updated_at: string }[]> {
  const { data, error } = await db([tags.providers])
    .from("providers")
    .select("slug, updated_at")
    .eq("status", "active")
    .order("slug");
  if (error) fail("tarjoajalista", error);
  return data as { slug: string; updated_at: string }[];
}
