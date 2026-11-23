import type { Locale } from "@pikkutyo/i18n";
import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { JsonLd } from "@/components/JsonLd";
import { SearchForm } from "@/components/SearchForm";
import { ButtonLink } from "@/components/ui";
import { Link } from "@/i18n/navigation";
import { getActiveCities } from "@/lib/data";
import { t as tr } from "@/lib/format";
import { absoluteUrl, alternates } from "@/lib/seo";
import styles from "./page.module.css";

export const revalidate = 3600;

type Props = { params: Promise<{ locale: Locale }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "home" });
  return {
    title: { absolute: t("metaTitle") },
    description: t("metaDescription"),
    alternates: alternates(locale, () => "/"),
  };
}

const STEPS = [1, 2, 3] as const;

export default async function HomePage({ params }: Props) {
  const { locale } = await params;
  setRequestLocale(locale);
  const [t, tb, cities] = await Promise.all([
    getTranslations("home"),
    getTranslations("becomeProvider"),
    getActiveCities(),
  ]);

  return (
    <>
      <JsonLd
        data={{
          "@context": "https://schema.org",
          "@type": "WebSite",
          name: "Pikkutyö",
          url: absoluteUrl("/"),
          inLanguage: locale,
        }}
      />

      <section className={styles.hero} aria-labelledby="hero-title">
        <div className="container">
          <h1 id="hero-title" className={styles.title}>
            {t("title")}
          </h1>
          <p className={styles.lead}>{t("lead")}</p>
          <div className={styles.searchCard}>
            <SearchForm locale={locale} cities={cities} variant="hero" />
          </div>
        </div>
      </section>

      <div className="container">
        <section className={styles.section} aria-labelledby="cities-title">
          <h2 id="cities-title">{t("citiesTitle")}</h2>
          <ul className={styles.cities}>
            {cities.map((city) => (
              <li key={city.id}>
                <Link
                  href={{ pathname: "/renkaanvaihto/[city]", params: { city: city.slugs[locale] } }}
                  className={styles.city}
                >
                  <span className={styles.cityName}>{tr(city.name, locale)}</span>
                  <span className={styles.cityHint}>{t("cityHint")}</span>
                </Link>
              </li>
            ))}
          </ul>
        </section>

        <section className={styles.section} aria-labelledby="how-title">
          <h2 id="how-title">{t("howTitle")}</h2>
          <ol className={styles.steps}>
            {STEPS.map((n) => (
              <li key={n} className={styles.step}>
                <h3 className={styles.stepTitle}>{t(`how${n}Title`)}</h3>
                <p>{t(`how${n}`)}</p>
              </li>
            ))}
          </ol>
        </section>

        <section className={styles.provider} aria-labelledby="provider-title">
          <div>
            <h2 id="provider-title">{tb("title")}</h2>
            <p>{tb("lead")}</p>
          </div>
          <ButtonLink href="/tarjoajaksi" variant="secondary">
            {tb("readMore")}
          </ButtonLink>
        </section>
      </div>
    </>
  );
}
