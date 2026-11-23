import type { Locale } from "@pikkutyo/i18n";
import { getTranslations } from "next-intl/server";
import { getPathname } from "@/i18n/navigation";
import { t as tr } from "@/lib/format";
import type { City, LocationType, ProviderKind } from "@/lib/types";
import { Button, Field } from "./ui";
import styles from "./SearchForm.module.css";

export interface SearchDefaults {
  citySlug?: string;
  date?: string;
  locationType?: LocationType;
  providerKind?: ProviderKind;
}

/**
 * Hakulomake (GET → /haku). Toimii ilman JavaScriptiä. Etusivulla (variant="hero") päivä jää
 * tyhjäksi, koska sivu on välimuistissa: haku käyttää silloin tätä päivää.
 */
export async function SearchForm({
  locale,
  cities,
  defaults = {},
  minDate,
  variant = "page",
}: {
  locale: Locale;
  cities: City[];
  defaults?: SearchDefaults;
  minDate?: string;
  variant?: "hero" | "page";
}) {
  const t = await getTranslations({ locale, namespace: "search" });
  const tc = await getTranslations({ locale, namespace: "common" });
  const hero = variant === "hero";

  return (
    <form
      method="get"
      action={getPathname({ locale, href: "/haku" })}
      className={[styles.form, hero && styles.hero].filter(Boolean).join(" ")}
      role="search"
    >
      <Field label={t("city")}>
        <select name="city" defaultValue={defaults.citySlug ?? cities[0]?.slugs[locale]}>
          {cities.map((c) => (
            <option key={c.id} value={c.slugs[locale]}>
              {tr(c.name, locale)}
            </option>
          ))}
        </select>
      </Field>
      <Field label={t("date")}>
        <input type="date" name="date" defaultValue={defaults.date} min={minDate} />
      </Field>
      <Field label={t("location")}>
        <select name="loc" defaultValue={defaults.locationType ?? ""}>
          <option value="">{tc("anyLocation")}</option>
          <option value="workshop">{tc("atWorkshop")}</option>
          <option value="mobile">{tc("atHome")}</option>
        </select>
      </Field>
      {!hero && (
        <Field label={t("kind")}>
          <select name="kind" defaultValue={defaults.providerKind ?? ""}>
            <option value="">{tc("anyProvider")}</option>
            <option value="company">{tc("company")}</option>
            <option value="individual">{tc("individual")}</option>
          </select>
        </Field>
      )}
      <Button type="submit" variant={hero ? "marking" : "primary"} className={styles.submit}>
        {t("submit")}
      </Button>
    </form>
  );
}
