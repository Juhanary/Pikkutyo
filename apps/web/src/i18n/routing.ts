import { defaultLocale, locales } from "@vaihdarenkaat/i18n";
import { defineRouting } from "next-intl/routing";

// Sisäiset reittiavaimet ovat suomeksi ja vastaavat app/[locale]/-kansioita.
// Käännetyt polut pidetään samoina kuin packages/i18n/src/index.ts:n pathSegments
// (routing.test.ts tarkistaa tämän).
export const routing = defineRouting({
  locales,
  defaultLocale,
  localePrefix: "as-needed",
  // Ei automaattista kieliohjausta: hakukone ja käyttäjä näkevät aina URL:n kielen.
  localeDetection: false,
  // hreflang tehdään metadataan, koska kaupunkien slugit vaihtelevat kielittäin.
  alternateLinks: false,
  pathnames: {
    "/": "/",
    "/renkaanvaihto/[city]": {
      fi: "/renkaanvaihto/[city]",
      sv: "/dackbyte/[city]",
      en: "/tyre-change/[city]",
    },
    "/renkaanvaihto/[city]/[filter]": {
      fi: "/renkaanvaihto/[city]/[filter]",
      sv: "/dackbyte/[city]/[filter]",
      en: "/tyre-change/[city]/[filter]",
    },
    "/tarjoajat/[slug]": {
      fi: "/tarjoajat/[slug]",
      sv: "/leverantorer/[slug]",
      en: "/providers/[slug]",
    },
    "/haku": { fi: "/haku", sv: "/sok", en: "/search" },
    "/tarjoajaksi": { fi: "/tarjoajaksi", sv: "/bli-leverantor", en: "/become-a-provider" },
    "/tarjoajaksi/hakemus": {
      fi: "/tarjoajaksi/hakemus",
      sv: "/bli-leverantor/ansokan",
      en: "/become-a-provider/application",
    },
    "/kirjaudu": { fi: "/kirjaudu", sv: "/logga-in", en: "/sign-in" },
  },
});

export type AppPathname = keyof typeof routing.pathnames;
