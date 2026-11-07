import type { Locale } from "@vaihdarenkaat/i18n";
import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { ButtonLink, PageHeader } from "@/components/ui";
import { alternates } from "@/lib/seo";
import styles from "./page.module.css";

type Props = { params: Promise<{ locale: Locale }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "becomeProvider" });
  return {
    title: t("metaTitle"),
    description: t("metaDescription"),
    alternates: alternates(locale, () => "/tarjoajaksi"),
  };
}

const BENEFITS = ["b1", "b2", "b3"] as const;
const STEPS = ["s1", "s2", "s3", "s4"] as const;

export default async function BecomeProviderPage({ params }: Props) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations("becomeProvider");
  return (
    <div className="container page">
      <PageHeader title={t("title")} lead={t("lead")}>
        <ButtonLink href="/tarjoajaksi/hakemus" rel="nofollow">
          {t("cta")}
        </ButtonLink>
      </PageHeader>

      <div className={styles.columns}>
        <section aria-labelledby="benefits-title">
          <h2 id="benefits-title">{t("benefitsTitle")}</h2>
          <ul className={styles.benefits}>
            {BENEFITS.map((b) => (
              <li key={b}>{t(b)}</li>
            ))}
          </ul>
        </section>
        <section aria-labelledby="steps-title">
          <h2 id="steps-title">{t("stepsTitle")}</h2>
          <ol className={styles.steps}>
            {STEPS.map((s) => (
              <li key={s}>{t(s)}</li>
            ))}
          </ol>
        </section>
      </div>
    </div>
  );
}
