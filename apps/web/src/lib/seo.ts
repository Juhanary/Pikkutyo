import { defaultLocale, locales, type Locale } from "@pikkutyo/i18n";
import type { Metadata } from "next";
import { getPathname } from "@/i18n/navigation";
import { env } from "./env";

type Href = Parameters<typeof getPathname>[0]["href"];

export function absoluteUrl(path: string): string {
  return `${env.siteUrl}${path === "/" ? "" : path}` || env.siteUrl;
}

export function localizedUrl(locale: Locale, href: Href): string {
  return absoluteUrl(getPathname({ locale, href }));
}

/**
 * canonical + hreflang. `hrefFor` palauttaa saman sivun osoitteen kullekin kielelle
 * (esim. kaupungin slug voi olla eri kielillä eri).
 */
export function alternates(locale: Locale, hrefFor: (l: Locale) => Href): Metadata["alternates"] {
  const languages: Record<string, string> = {};
  for (const l of locales) languages[l] = localizedUrl(l, hrefFor(l));
  languages["x-default"] = localizedUrl(defaultLocale, hrefFor(defaultLocale));
  return { canonical: localizedUrl(locale, hrefFor(locale)), languages };
}

/** JSON-LD turvallisesti: estää </script>-katkaisun (Next.js:n json-ld-ohje). */
export function jsonLdHtml(data: unknown): { __html: string } {
  return { __html: JSON.stringify(data).replace(/</g, "\\u003c") };
}

export function breadcrumbList(items: { name: string; url: string }[]) {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: items.map((item, i) => ({
      "@type": "ListItem",
      position: i + 1,
      name: item.name,
      item: item.url,
    })),
  };
}
