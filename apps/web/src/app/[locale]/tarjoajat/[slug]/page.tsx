import type { Locale } from "@vaihdarenkaat/i18n";
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { cache } from "react";
import { JsonLd } from "@/components/JsonLd";
import { SlotPicker, type SlotService } from "@/components/SlotPicker";
import { Breadcrumbs, PageHeader, Panel, Rating, Tags } from "@/components/ui";
import { Link } from "@/i18n/navigation";
import { getProviderBySlug, getReviews } from "@/lib/data";
import { formatPrice, formatRating, t as tr } from "@/lib/format";
import { alternates, breadcrumbList, localizedUrl } from "@/lib/seo";
import type { Provider } from "@/lib/types";
import styles from "./page.module.css";

export const revalidate = 3600;

type Props = { params: Promise<{ locale: Locale; slug: string }> };

const loadProvider = cache((slug: string) => getProviderBySlug(slug));

function lowestPrice(p: Provider): number | null {
  const prices = p.services.map((s) => s.price_cents + s.travel_fee_cents);
  return prices.length ? Math.min(...prices) : null;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale, slug } = await params;
  const provider = await loadProvider(slug);
  if (!provider) return {};
  const t = await getTranslations({ locale, namespace: "provider" });
  const city = tr(provider.city.name, locale);
  const price = lowestPrice(provider);
  return {
    title: t("metaTitle", { name: provider.display_name, city }),
    description:
      price != null
        ? t("metaDescription", { name: provider.display_name, city, price: formatPrice(price, locale) })
        : undefined,
    alternates: alternates(locale, () => ({ pathname: "/tarjoajat/[slug]", params: { slug } })),
  };
}

export default async function ProviderPage({ params }: Props) {
  const { locale, slug } = await params;
  setRequestLocale(locale);
  const provider = await loadProvider(slug);
  if (!provider) notFound();

  const [reviews, t, tc, tCity, tNav] = await Promise.all([
    getReviews(provider.id),
    getTranslations("provider"),
    getTranslations("common"),
    getTranslations("city"),
    getTranslations("nav"),
  ]);

  const city = tr(provider.city.name, locale);
  const url = localizedUrl(locale, { pathname: "/tarjoajat/[slug]", params: { slug } });
  const cityLink = { pathname: "/renkaanvaihto/[city]" as const, params: { city: provider.city.slugs[locale] } };
  const rating = formatRating(provider.rating_avg, locale);
  const locationLabel = (l: string) => (l === "mobile" ? tc("atHome") : tc("atWorkshop"));

  const slotServices: SlotService[] = provider.services.map((s) => ({
    code: s.service.code,
    label: `${tr(s.service.name, locale)} (${locationLabel(s.location_type)})`,
    locationType: s.location_type,
    totalCents: s.price_cents + s.travel_fee_cents,
  }));

  // Yrityksestä LocalBusiness, yksityisestä tekijästä palvelu, jonka tarjoaa henkilö
  // (ei kotiosoitetta tai tarkkaa sijaintia julkisesti).
  const offers = provider.services.map((s) => ({
    "@type": "Offer",
    price: ((s.price_cents + s.travel_fee_cents) / 100).toFixed(2),
    priceCurrency: "EUR",
    itemOffered: { "@type": "Service", name: `${tr(s.service.name, locale)} – ${locationLabel(s.location_type)}` },
  }));
  const aggregateRating =
    provider.rating_count > 0 && provider.rating_avg != null
      ? {
          "@type": "AggregateRating",
          ratingValue: provider.rating_avg,
          reviewCount: provider.rating_count,
          bestRating: 5,
          worstRating: 1,
        }
      : undefined;
  const structured =
    provider.kind === "company"
      ? {
          "@context": "https://schema.org",
          "@type": "AutoRepair",
          name: provider.display_name,
          url,
          address: {
            "@type": "PostalAddress",
            addressLocality: city,
            addressCountry: "FI",
          },
          makesOffer: offers,
          ...(aggregateRating && { aggregateRating }),
        }
      : {
          "@context": "https://schema.org",
          "@type": "Service",
          name: `${tCity("serviceType")} – ${provider.display_name}`,
          url,
          provider: { "@type": "Person", name: provider.display_name },
          areaServed: { "@type": "City", name: city },
          offers,
          ...(aggregateRating && { aggregateRating }),
        };

  return (
    <>
      <JsonLd data={structured} />
      <JsonLd
        data={breadcrumbList([
          { name: tNav("home"), url: localizedUrl(locale, "/") },
          { name: tCity("title", { city }), url: localizedUrl(locale, cityLink) },
          { name: provider.display_name, url },
        ])}
      />

      <div className="container page">
        <PageHeader
          before={
            <Breadcrumbs
              label={tNav("breadcrumb")}
              items={[
                { label: tNav("home"), href: "/" },
                { label: tCity("title", { city }), href: cityLink },
              ]}
            />
          }
          title={provider.display_name}
        >
          <Tags
            items={[
              provider.kind === "company" ? tc("company") : tc("individual"),
              provider.district ? `${tr(provider.district.name, locale)}, ${city}` : city,
              !!provider.service_radius_km && t("serviceArea", { km: provider.service_radius_km }),
            ]}
          />
          <Rating
            value={provider.rating_avg}
            text={rating ? tc("rating", { rating, count: provider.rating_count }) : tc("noRating")}
          />
        </PageHeader>

        <div className={styles.layout}>
          <div className={styles.main}>
            {provider.description && <p className={styles.description}>{tr(provider.description, locale)}</p>}

            <section aria-labelledby="services-title">
              <h2 id="services-title">{t("servicesTitle")}</h2>
              <table className={styles.services}>
                <thead className="visually-hidden">
                  <tr>
                    <th scope="col">{t("service")}</th>
                    <th scope="col">{t("duration")}</th>
                    <th scope="col">{t("price")}</th>
                  </tr>
                </thead>
                <tbody>
                  {provider.services.map((s) => (
                    <tr key={`${s.service.code}-${s.location_type}`}>
                      <th scope="row">
                        {tr(s.service.name, locale)}
                        <small>{locationLabel(s.location_type)}</small>
                      </th>
                      <td className="num">{tc("duration", { minutes: s.duration_min })}</td>
                      <td className={`num ${styles.price}`}>
                        {formatPrice(s.price_cents, locale)}
                        {s.travel_fee_cents > 0 && (
                          <small>{tc("travelFee", { price: formatPrice(s.travel_fee_cents, locale) })}</small>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </section>

            <section aria-labelledby="reviews-title">
              <h2 id="reviews-title">{t("reviewsTitle")}</h2>
              {reviews.length === 0 ? (
                <p className={styles.muted}>{t("noReviews")}</p>
              ) : (
                <ul className={styles.reviews}>
                  {reviews.map((r) => (
                    <li key={r.id}>
                      <Rating value={r.rating} text={t("reviewRating", { rating: r.rating })} />
                      {r.body && <p>{r.body}</p>}
                    </li>
                  ))}
                </ul>
              )}
            </section>

            <p>
              <Link href={cityLink}>{t("backToCity", { city })}</Link>
            </p>
          </div>

          <aside className={styles.aside} aria-labelledby="availability-title">
            <Panel raised>
              <h2 id="availability-title">{t("availabilityTitle")}</h2>
              <SlotPicker providerId={provider.id} services={slotServices} />
            </Panel>
          </aside>
        </div>
      </div>
    </>
  );
}
