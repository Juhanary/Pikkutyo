import path from "node:path";
import { loadEnvConfig } from "@next/env";
import type { NextConfig } from "next";
import createNextIntlPlugin from "next-intl/plugin";

// Monorepossa on yksi .env repon juuressa. Ladataan se ja välitetään selaimelle
// VAIN julkiset arvot. SUPABASE_SECRET_KEY ei koskaan päädy tänne.
// forceReload: Next on jo ladannut apps/web-kansion env-tiedostot, ja ilman tätä
// loadEnvConfig palauttaisi välimuistin eikä lukisi juuren .env-tiedostoa.
loadEnvConfig(path.resolve(process.cwd(), "../.."), process.env.NODE_ENV !== "production", console, true);

const nextConfig: NextConfig = {
  // Cache Components jätetään myöhemmäksi: next-intl ja ISR-sivut toimivat
  // nyt aiemmalla välimuistimallilla (revalidate + fetch-tagit). Ks. docs/adr/0002.
  transpilePackages: ["@pikkutyo/i18n"],
  env: {
    NEXT_PUBLIC_SUPABASE_URL: process.env.SUPABASE_URL ?? "",
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: process.env.SUPABASE_PUBLISHABLE_KEY ?? "",
    NEXT_PUBLIC_SITE_URL: process.env.SITE_URL ?? "http://localhost:3000",
    NEXT_PUBLIC_APP_URL: process.env.APP_URL ?? "http://localhost:8080",
  },
  poweredByHeader: false,
};

export default createNextIntlPlugin("./src/i18n/request.ts")(nextConfig);
