import { locales } from "@vaihdarenkaat/i18n";
import type { MetadataRoute } from "next";
import { getPathname } from "@/i18n/navigation";
import { env } from "@/lib/env";

export default function robots(): MetadataRoute.Robots {
  // Kehitys- ja esikatseluympäristöjä ei indeksoida.
  const production = process.env.VERCEL_ENV === "production" || process.env.ALLOW_INDEXING === "true";
  if (!production) return { rules: { userAgent: "*", disallow: "/" } };

  return {
    rules: {
      userAgent: "*",
      allow: "/",
      disallow: ["/api/", "/admin", ...locales.map((locale) => getPathname({ locale, href: "/haku" }))],
    },
    sitemap: `${env.siteUrl}/sitemap.xml`,
  };
}
