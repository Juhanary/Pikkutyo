// Julkiset ympäristömuuttujat (next.config.ts välittää ne juuren .env:stä).
export const env = {
  supabaseUrl: process.env.NEXT_PUBLIC_SUPABASE_URL ?? "",
  supabasePublishableKey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "",
  siteUrl: (process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000").replace(/\/$/, ""),
  appUrl: (process.env.NEXT_PUBLIC_APP_URL ?? "http://localhost:8080").replace(/\/$/, ""),
};
