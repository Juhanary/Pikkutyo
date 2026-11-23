import { pathSegments, type Locale } from "@pikkutyo/i18n";
import { getCityBySlug, getCityStats, getPublishedDistricts } from "./data";
import type { City, CityStat, District, LocationType } from "./types";

export type CityFilter =
  | { kind: "none" }
  | { kind: "location"; locationType: LocationType }
  | { kind: "district"; district: District };

export interface CityPageData {
  city: City;
  filter: CityFilter;
  districts: District[];
  stats: CityStat[];
}

export function locationSegment(locationType: LocationType, locale: Locale): string {
  return pathSegments[locationType === "mobile" ? "atHome" : "atWorkshop"][locale];
}

/** Tulkitsee kaupunkisivun toisen polkuosan: paikka (kotipihalla/korjaamolla) tai kaupunginosa. */
export function parseFilter(segment: string | undefined, locale: Locale, districts: District[]): CityFilter | null {
  if (segment == null) return { kind: "none" };
  if (segment === pathSegments.atHome[locale]) return { kind: "location", locationType: "mobile" };
  if (segment === pathSegments.atWorkshop[locale]) return { kind: "location", locationType: "workshop" };
  const district = districts.find((d) => d.slugs[locale] === segment);
  return district ? { kind: "district", district } : null;
}

export async function loadCityPage(
  locale: Locale,
  citySlug: string,
  filterSegment?: string,
): Promise<CityPageData | null> {
  const city = await getCityBySlug(locale, citySlug);
  if (!city) return null;
  const [districts, stats] = await Promise.all([getPublishedDistricts(city.id), getCityStats(city.id)]);
  const filter = parseFilter(filterSegment, locale, districts);
  if (!filter) return null;
  return { city, filter, districts, stats };
}

/** Saman sivun osoite toisella kielellä (hreflang). */
export function cityHref(data: CityPageData, l: Locale) {
  const city = data.city.slugs[l];
  switch (data.filter.kind) {
    case "none":
      return { pathname: "/renkaanvaihto/[city]" as const, params: { city } };
    case "location":
      return {
        pathname: "/renkaanvaihto/[city]/[filter]" as const,
        params: { city, filter: locationSegment(data.filter.locationType, l) },
      };
    case "district":
      return {
        pathname: "/renkaanvaihto/[city]/[filter]" as const,
        params: { city, filter: data.filter.district.slugs[l] },
      };
  }
}

export function minPrice(stats: CityStat[], locationType?: LocationType): number | null {
  const prices = stats
    .filter((s) => s.service_code === "tire_change" && (!locationType || s.location_type === locationType))
    .map((s) => s.min_price_cents);
  return prices.length ? Math.min(...prices) : null;
}
