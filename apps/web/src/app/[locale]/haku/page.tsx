import type { Locale } from "@vaihdarenkaat/i18n";
import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { ProviderList } from "@/components/ProviderList";
import { SearchForm } from "@/components/SearchForm";
import { PageHeader, Pagination, Panel } from "@/components/ui";
import { getPathname, redirect } from "@/i18n/navigation";
import { firstParam } from "@/lib/auth";
import { getActiveCities, searchProviders } from "@/lib/data";
import { isoDate, isValidIsoDate } from "@/lib/format";
import type { LocationType, ProviderKind } from "@/lib/types";
import styles from "./page.module.css";

// Haku on aina tuore (vapaat ajat) eikä sitä indeksoida: hakukoneille on kaupunkisivut.
export const dynamic = "force-dynamic";

const PAGE_SIZE = 20;
// Syvälle sivutus ei ole järkevää käyttäjälle, ja se rajaa kantakuorman.
const MAX_PAGES = 25;

type Props = {
  params: Promise<{ locale: Locale }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export async function generateMetadata({ params, searchParams }: Props): Promise<Metadata> {
  const { locale } = await params;
  const city = firstParam((await searchParams).city);
  const t = await getTranslations({ locale, namespace: "search" });
  return {
    title: t("metaTitle"),
    robots: { index: false, follow: true },
    alternates: city
      ? { canonical: getPathname({ locale, href: { pathname: "/renkaanvaihto/[city]", params: { city } } }) }
      : undefined,
  };
}

export default async function SearchPage({ params, searchParams }: Props) {
  const { locale } = await params;
  setRequestLocale(locale);
  const sp = await searchParams;
  const t = await getTranslations("search");
  const cities = await getActiveCities();

  const citySlug = firstParam(sp.city) ?? cities[0]?.slugs[locale];
  const today = isoDate(new Date());
  const requested = firstParam(sp.date) ?? "";
  // Mahdoton päivä (2026-02-30) kaataisi kantakutsun, mennyt ei tuottaisi aikoja.
  const date = isValidIsoDate(requested) && requested >= today ? requested : today;
  const loc = firstParam(sp.loc);
  const kind = firstParam(sp.kind);
  const locationType: LocationType | undefined = loc === "mobile" || loc === "workshop" ? loc : undefined;
  const providerKind: ProviderKind | undefined = kind === "company" || kind === "individual" ? kind : undefined;

  const requestedPage = Number.parseInt(firstParam(sp.page) ?? "1", 10);
  const page = Number.isFinite(requestedPage) ? Math.min(Math.max(requestedPage, 1), MAX_PAGES) : 1;
  const results = citySlug
    ? await searchProviders({
        citySlug,
        locale,
        date,
        locationType,
        providerKind,
        limit: PAGE_SIZE,
        offset: (page - 1) * PAGE_SIZE,
      })
    : [];
  const query = {
    city: citySlug ?? "",
    date,
    ...(locationType && { loc: locationType }),
    ...(providerKind && { kind: providerKind }),
  };
  // Sivu tulosten ohi (esim. vanha linkki): kokonaismäärää ei saada tyhjältä sivulta, joten alkuun.
  if (page > 1 && results.length === 0) redirect({ href: { pathname: "/haku", query }, locale });
  const total = results[0]?.total_count ?? 0;
  const pageCount = Math.min(Math.ceil(total / PAGE_SIZE), MAX_PAGES);

  return (
    <div className="container page">
      <PageHeader title={t("title")} />
      <Panel aria-label={t("title")}>
        <SearchForm
          locale={locale}
          cities={cities}
          minDate={today}
          defaults={{ citySlug, date, locationType, providerKind }}
        />
      </Panel>
      <h2 className={styles.results} aria-live="polite">
        {t("results", { count: total })}
      </h2>
      <ProviderList results={results} locale={locale} />
      <Pagination
        page={page}
        pageCount={pageCount}
        hrefFor={(p) => ({ pathname: "/haku", query: p > 1 ? { ...query, page: String(p) } : query })}
        labels={{
          nav: t("pages"),
          previous: t("previous"),
          next: t("next"),
          status: t("showing", {
            from: (page - 1) * PAGE_SIZE + 1,
            to: (page - 1) * PAGE_SIZE + results.length,
            total,
          }),
        }}
      />
    </div>
  );
}
