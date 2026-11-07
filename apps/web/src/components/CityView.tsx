import type { Locale } from "@vaihdarenkaat/i18n";
import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import { cityHref, locationSegment, minPrice, type CityPageData } from "@/lib/cityPage";
import { searchProviders } from "@/lib/data";
import { formatPrice, t as tr } from "@/lib/format";
import { alternates, breadcrumbList, localizedUrl } from "@/lib/seo";
import type { SearchResult } from "@/lib/types";
import styles from "./CityView.module.css";
import { JsonLd } from "./JsonLd";
import { ProviderList } from "./ProviderList";
import { Breadcrumbs, ButtonLink, PageHeader } from "./ui";

/** Kaupunkisivun rivit (tarjoaja × paikka). Loput näkyvät sivutetussa haussa. */
const CITY_LIMIT = 100;

async function loadResults(data: CityPageData, locale: Locale): Promise<SearchResult[]> {
  const citySlug = data.city.slugs[locale];
  const f = data.filter;
  return searchProviders({
    citySlug,
    locale,
    locationType: f.kind === "location" ? f.locationType : undefined,
    districtSlug: f.kind === "district" ? f.district.slugs[locale] : undefined,
    limit: CITY_LIMIT,
  });
}

/**
 * Halvin hinta sivun rajauksella. Kaupunginosasivulla kaupungin tilastot olisivat väärä
 * lähde (halvin hinta koko kaupungissa), joten hinta lasketaan kaupunginosan tuloksista.
 */
function lowestPrice(data: CityPageData, results: SearchResult[]): number | null {
  const f = data.filter;
  if (f.kind === "district") {
    return results.length ? Math.min(...results.map((r) => r.price_cents)) : null;
  }
  return minPrice(data.stats, f.kind === "location" ? f.locationType : undefined);
}

async function texts(data: CityPageData, locale: Locale, results: SearchResult[]) {
  const t = await getTranslations({ locale, namespace: "city" });
  const city = tr(data.city.name, locale);
  // Kokonaismäärä tulee kannasta: rivit on sivutettu, joten niistä laskettu määrä jäisi vajaaksi.
  const count = results[0]?.provider_count ?? 0;
  const f = data.filter;

  if (f.kind === "location") {
    const title = t(f.locationType === "mobile" ? "atHomeTitle" : "atWorkshopTitle", { city });
    const lead = t(f.locationType === "mobile" ? "atHomeLead" : "atWorkshopLead");
    return { title, lead, count, city };
  }
  if (f.kind === "district") {
    const district = tr(f.district.name, locale);
    return {
      title: t("districtTitle", { district, city }),
      lead: t("districtLead", { district, count }),
      count,
      city,
    };
  }
  const workshop = minPrice(data.stats, "workshop");
  const mobile = minPrice(data.stats, "mobile");
  let lead: string;
  if (count === 0) lead = t("leadEmpty", { city });
  else if (workshop != null && mobile != null)
    lead = t("lead", {
      city,
      count,
      workshopPrice: formatPrice(workshop, locale),
      mobilePrice: formatPrice(mobile, locale),
    });
  else if (workshop != null)
    lead = t("leadNoMobile", { city, count, workshopPrice: formatPrice(workshop, locale) });
  else if (mobile != null) lead = t("leadNoWorkshop", { city, count, mobilePrice: formatPrice(mobile, locale) });
  else lead = t("leadNoPrice", { city, count });
  return { title: t("title", { city }), lead, count, city };
}

export async function cityMetadata(data: CityPageData, locale: Locale): Promise<Metadata> {
  const t = await getTranslations({ locale, namespace: "city" });
  const results = await loadResults(data, locale);
  const { title, lead, count, city } = await texts(data, locale, results);
  const price = lowestPrice(data, results);
  const f = data.filter;
  const description =
    price == null
      ? lead
      : f.kind === "district"
        ? t("districtMetaDescription", {
            district: tr(f.district.name, locale),
            city,
            count,
            price: formatPrice(price, locale),
          })
        : t("metaDescription", { city, count, price: formatPrice(price, locale) });
  return {
    title: data.filter.kind === "none" ? t("metaTitle", { city }) : title,
    description,
    alternates: alternates(locale, (l) => cityHref(data, l)),
    // Tyhjää kaupunkisivua ei indeksoida (ohut sisältö).
    robots: count === 0 ? { index: false, follow: true } : undefined,
  };
}

export async function CityView({ data, locale }: { data: CityPageData; locale: Locale }) {
  const t = await getTranslations({ locale, namespace: "city" });
  const tCommon = await getTranslations({ locale, namespace: "common" });
  const tNav = await getTranslations({ locale, namespace: "nav" });
  const results = await loadResults(data, locale);
  const { title, lead, city } = await texts(data, locale, results);
  const citySlug = data.city.slugs[locale];
  const f = data.filter;

  const cityLink = { pathname: "/renkaanvaihto/[city]" as const, params: { city: citySlug } };
  const crumbs = [
    { name: tNav("home"), url: localizedUrl(locale, "/") },
    { name: t("title", { city }), url: localizedUrl(locale, cityLink) },
  ];
  if (f.kind !== "none") crumbs.push({ name: title, url: localizedUrl(locale, cityHref(data, locale)) });

  const workshop = results.filter((r) => r.location_type === "workshop");
  const mobile = results.filter((r) => r.location_type === "mobile");
  const lowest = lowestPrice(data, results);
  const areaServed =
    f.kind === "district"
      ? {
          "@type": "Place",
          name: `${tr(f.district.name, locale)}, ${city}`,
          containedInPlace: { "@type": "City", name: city },
        }
      : { "@type": "City", name: city };

  return (
    <>
      <JsonLd data={breadcrumbList(crumbs)} />
      <JsonLd
        data={{
          "@context": "https://schema.org",
          "@type": "Service",
          name: title,
          serviceType: t("serviceType"),
          areaServed,
          ...(lowest != null && {
            offers: {
              "@type": "AggregateOffer",
              priceCurrency: "EUR",
              lowPrice: (lowest / 100).toFixed(2),
              offerCount: results[0]?.total_count ?? 0,
            },
          }),
        }}
      />
      <JsonLd
        data={{
          "@context": "https://schema.org",
          "@type": "ItemList",
          itemListElement: results.map((r, i) => ({
            "@type": "ListItem",
            position: i + 1,
            url: localizedUrl(locale, { pathname: "/tarjoajat/[slug]", params: { slug: r.slug } }),
            name: r.display_name,
          })),
        }}
      />

      <div className="container page">
        <PageHeader
          before={
            <Breadcrumbs
              label={tNav("breadcrumb")}
              items={[
                { label: tNav("home"), href: "/" },
                ...(f.kind !== "none" ? [{ label: t("title", { city }), href: cityLink }] : []),
              ]}
            />
          }
          title={title}
          lead={lead}
        >
          {/* Ei päivämäärää: sivu on välimuistissa, ja /haku käyttää oletuksena tätä päivää. */}
          <ButtonLink href={{ pathname: "/haku", query: { city: citySlug } }} rel="nofollow">
            {t("searchCta")}
          </ButtonLink>
        </PageHeader>

        {f.kind === "none" ? (
          <>
            <nav aria-label={t("filtersLabel")}>
              <ul className={styles.chips}>
                {(["mobile", "workshop"] as const).map((l) => (
                  <li key={l}>
                    <Link
                      className={styles.chip}
                      href={{
                        pathname: "/renkaanvaihto/[city]/[filter]",
                        params: { city: citySlug, filter: locationSegment(l, locale) },
                      }}
                    >
                      {t(l === "mobile" ? "atHomeTitle" : "atWorkshopTitle", { city })}
                    </Link>
                  </li>
                ))}
              </ul>
            </nav>
            <section aria-labelledby="workshop-title">
              <h2 id="workshop-title">{tCommon("atWorkshop")}</h2>
              <ProviderList results={workshop} locale={locale} />
            </section>
            <section aria-labelledby="mobile-title">
              <h2 id="mobile-title">{tCommon("atHome")}</h2>
              <ProviderList results={mobile} locale={locale} />
            </section>
          </>
        ) : (
          <section aria-labelledby="providers-title">
            <h2 id="providers-title">{t("providersTitle")}</h2>
            <ProviderList results={results} locale={locale} />
          </section>
        )}

        {results.length < (results[0]?.total_count ?? 0) && (
          <p>
            {/* Kaupunkisivu näyttää enintään CITY_LIMIT riviä; loput löytyvät sivutetusta hausta. */}
            <Link href={{ pathname: "/haku", query: { city: citySlug } }} rel="nofollow">
              {t("seeAll", { count: results[0]?.total_count ?? 0 })}
            </Link>
          </p>
        )}

        {data.districts.length > 0 && (
          <section aria-labelledby="districts-title">
            <h2 id="districts-title">{t("districtsTitle")}</h2>
            <ul className={styles.chips}>
              {data.districts.map((d) => (
                <li key={d.id}>
                  <Link
                    className={styles.chip}
                    aria-current={f.kind === "district" && f.district.id === d.id ? "page" : undefined}
                    href={{
                      pathname: "/renkaanvaihto/[city]/[filter]",
                      params: { city: citySlug, filter: d.slugs[locale] },
                    }}
                  >
                    {/* Koko nimi linkkitekstinä: kertoo hakukoneelle, mihin sivu vie. */}
                    {t("districtTitle", { district: tr(d.name, locale), city })}
                  </Link>
                </li>
              ))}
            </ul>
          </section>
        )}
      </div>
    </>
  );
}
