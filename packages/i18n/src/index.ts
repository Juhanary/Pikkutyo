// Kielet ja niiden URL-etuliitteet. Suomi on oletus ilman etuliitettä.
// Uusi kieli: lisää tähän, messages/<locale>.json ja käännökset tietokantaan
// (city_slugs, district_slugs, jsonb-kentät).
export const locales = ["fi", "sv", "en"] as const;
export type Locale = (typeof locales)[number];
export const defaultLocale: Locale = "fi";

// Staattisten polkujen käännökset. Kaupunkien ja kaupunginosien
// slugit tulevat tietokannasta, ei täältä.
export const pathSegments = {
  tireChange: { fi: "renkaanvaihto", sv: "dackbyte", en: "tyre-change" },
  providers: { fi: "tarjoajat", sv: "leverantorer", en: "providers" },
  becomeProvider: { fi: "tarjoajaksi", sv: "bli-leverantor", en: "become-a-provider" },
  application: { fi: "hakemus", sv: "ansokan", en: "application" },
  signIn: { fi: "kirjaudu", sv: "logga-in", en: "sign-in" },
  help: { fi: "ohjeet", sv: "hjalp", en: "help" },
  search: { fi: "haku", sv: "sok", en: "search" },
  atHome: { fi: "kotipihalla", sv: "hemma", en: "at-home" },
  atWorkshop: { fi: "korjaamolla", sv: "pa-verkstad", en: "at-workshop" },
} as const satisfies Record<string, Record<Locale, string>>;

export type PathSegment = keyof typeof pathSegments;

export function isLocale(value: string): value is Locale {
  return (locales as readonly string[]).includes(value);
}
