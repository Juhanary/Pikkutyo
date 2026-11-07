import { locales, pathSegments, type Locale } from "@vaihdarenkaat/i18n";
import type { MetadataRoute } from "next";
import { getActiveCities, getActiveProviderSlugs, getCityStats, getPublishedDistricts } from "@/lib/data";
import { localizedUrl } from "@/lib/seo";

export const revalidate = 3600;

type Href = Parameters<typeof localizedUrl>[1];

function entry(hrefFor: (l: Locale) => Href, lastModified?: string): MetadataRoute.Sitemap[number][] {
  const languages = Object.fromEntries(locales.map((l) => [l, localizedUrl(l, hrefFor(l))]));
  return locales.map((l) => ({
    url: localizedUrl(l, hrefFor(l)),
    lastModified,
    alternates: { languages },
  }));
}

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const items: MetadataRoute.Sitemap = [...entry(() => "/"), ...entry(() => "/tarjoajaksi")];

  try {
    const [cities, providers] = await Promise.all([getActiveCities(), getActiveProviderSlugs()]);

    const perCity = await Promise.all(
      cities.map(async (city) => {
        const [stats, districts] = await Promise.all([getCityStats(city.id), getPublishedDistricts(city.id)]);
        return { city, stats, districts };
      }),
    );

    for (const { city, stats, districts } of perCity) {
      // Kaupunki ilman tarjoajia on noindex (ohut sisältö), joten sitä ei listata, eikä sen alasivuja.
      if (!stats.some((s) => s.provider_count > 0)) continue;
      items.push(...entry((l) => ({ pathname: "/renkaanvaihto/[city]", params: { city: city.slugs[l] } })));
      // Vain paikat, joilla on tarjoajia: tyhjä sivu on noindex, eikä sitä kuulu sivukarttaan.
      const segments = [
        ["atHome", "mobile"],
        ["atWorkshop", "workshop"],
      ] as const;
      for (const [seg, locationType] of segments) {
        const hasProviders = stats.some(
          (s) => s.service_code === "tire_change" && s.location_type === locationType && s.provider_count > 0,
        );
        if (!hasProviders) continue;
        items.push(
          ...entry((l) => ({
            pathname: "/renkaanvaihto/[city]/[filter]",
            params: { city: city.slugs[l], filter: pathSegments[seg][l] },
          })),
        );
      }
      // Vain kaupunginosat, joissa on vähintään 3 tarjoajaa.
      for (const d of districts) {
        items.push(
          ...entry((l) => ({
            pathname: "/renkaanvaihto/[city]/[filter]",
            params: { city: city.slugs[l], filter: d.slugs[l] },
          })),
        );
      }
    }

    for (const p of providers) {
      items.push(...entry(() => ({ pathname: "/tarjoajat/[slug]", params: { slug: p.slug } }), p.updated_at));
    }
  } catch (error) {
    // Tietokanta ei vastaa (esim. build ilman Supabasea): staattiset sivut riittävät,
    // ja sivukartta päivittyy seuraavalla revalidoinnilla.
    console.error("sitemap:", error);
  }

  return items;
}
