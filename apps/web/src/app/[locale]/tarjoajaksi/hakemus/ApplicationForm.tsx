import type { Locale } from "@vaihdarenkaat/i18n";
import { getTranslations } from "next-intl/server";
import { Button, Choice, ChoiceGroup, Field } from "@/components/ui";
import type { ProviderApplication } from "@/lib/auth";
import { t as tr } from "@/lib/format";
import type { City, I18nText } from "@/lib/types";
import { saveApplication } from "./actions";
import styles from "./page.module.css";

export interface DistrictOption {
  id: string;
  city_id: string;
  name: I18nText;
}

/** Hakemuksen perustiedot. Ilman hakemusta lomake luo uuden luonnoksen. */
export async function ApplicationForm({
  app,
  locale,
  cities,
  districts,
  email,
}: {
  app: ProviderApplication | null;
  locale: Locale;
  cities: City[];
  districts: DistrictOption[];
  email: string | null;
}) {
  const t = await getTranslations({ locale, namespace: "application" });

  return (
    <form action={saveApplication} className={styles.form}>
      <input type="hidden" name="locale" value={locale} />
      {app && <input type="hidden" name="application_id" value={app.id} />}

      <ChoiceGroup legend={t("form.kind")}>
        {(["individual", "company"] as const).map((k) => (
          <Choice key={k}>
            <input type="radio" name="kind" value={k} defaultChecked={(app?.kind ?? "individual") === k} />
            {t(`form.kinds.${k}`)}
          </Choice>
        ))}
      </ChoiceGroup>

      <div className={styles.grid}>
        <Field label={t("form.displayName")} hint={t("form.displayNameHelp")}>
          <input name="display_name" required minLength={2} maxLength={80} defaultValue={app?.display_name ?? ""} />
        </Field>
        <Field label={t("form.businessId")}>
          <input
            name="business_id"
            pattern="[0-9]{7}-[0-9]"
            placeholder="1234567-8"
            inputMode="numeric"
            defaultValue={app?.business_id ?? ""}
          />
        </Field>
        <Field label={t("form.city")}>
          <select name="city_id" required defaultValue={app?.city_id ?? cities[0]?.id}>
            {cities.map((c) => (
              <option key={c.id} value={c.id}>
                {tr(c.name, locale)}
              </option>
            ))}
          </select>
        </Field>
        <Field label={t("form.district")}>
          <select name="district_id" defaultValue={app?.district_id ?? ""}>
            <option value="">{t("form.districtNone")}</option>
            {cities.map((c) => (
              <optgroup key={c.id} label={tr(c.name, locale)}>
                {districts
                  .filter((d) => d.city_id === c.id)
                  .map((d) => (
                    <option key={d.id} value={d.id}>
                      {tr(d.name, locale)}
                    </option>
                  ))}
              </optgroup>
            ))}
          </select>
        </Field>
      </div>

      <ChoiceGroup legend={t("form.locationTypes")}>
        {(["workshop", "mobile"] as const).map((l) => (
          <Choice key={l}>
            <input type="checkbox" name="location_types" value={l} defaultChecked={app?.location_types.includes(l)} />
            {t(`form.locations.${l}`)}
          </Choice>
        ))}
      </ChoiceGroup>

      <Field label={t("form.description")}>
        <textarea name="description" maxLength={2000} rows={4} defaultValue={app?.description ?? ""} />
      </Field>
      <Field label={t("form.toolsDescription")}>
        <textarea name="tools_description" maxLength={2000} rows={3} defaultValue={app?.tools_description ?? ""} />
      </Field>

      <div className={styles.grid}>
        <Field label={t("form.contactEmail")}>
          <input type="email" name="contact_email" autoComplete="email" defaultValue={app?.contact_email ?? email ?? ""} />
        </Field>
        <Field label={t("form.contactPhone")}>
          <input type="tel" name="contact_phone" autoComplete="tel" defaultValue={app?.contact_phone ?? ""} />
        </Field>
        <Field label={t("form.invoicing")} hint={t("form.invoicingHelp")}>
          <select name="invoicing_service" defaultValue={app?.invoicing_service ?? "none"}>
            {(["none", "ukko", "eezy", "other"] as const).map((s) => (
              <option key={s} value={s}>
                {t(`form.invoicingOptions.${s}`)}
              </option>
            ))}
          </select>
        </Field>
        <Field label={t("form.invoicingReference")}>
          <input name="invoicing_reference" maxLength={200} defaultValue={app?.invoicing_reference ?? ""} />
        </Field>
      </div>

      <div>
        <Button type="submit">{app ? t("form.save") : t("form.create")}</Button>
      </div>
    </form>
  );
}
