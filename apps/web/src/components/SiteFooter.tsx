import { locales, type Locale } from "@pikkutyo/i18n";
import { getTranslations } from "next-intl/server";
import { Link } from "@/i18n/navigation";
import styles from "./SiteFooter.module.css";

const languageNames: Record<Locale, string> = { fi: "Suomi", sv: "Svenska", en: "English" };

export async function SiteFooter({ locale }: { locale: Locale }) {
  const t = await getTranslations("nav");
  const tc = await getTranslations("common");
  return (
    <footer className={styles.footer}>
      <div className={`container ${styles.inner}`}>
        <p>{tc("tagline")}</p>
        <nav aria-label={t("language")} className={styles.languages}>
          <ul>
            {locales.map((l) => (
              <li key={l}>
                {/* Kaupunkien ja tarjoajien polut ovat kielikohtaisia, joten vaihto vie etusivulle. */}
                <Link href="/" locale={l} hrefLang={l} lang={l} aria-current={l === locale ? "true" : undefined}>
                  {languageNames[l]}
                </Link>
              </li>
            ))}
          </ul>
        </nav>
      </div>
    </footer>
  );
}
