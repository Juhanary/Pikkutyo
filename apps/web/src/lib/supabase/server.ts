// Kirjautuneen käyttäjän Supabase-yhteys palvelimella (Server Components, Server Actions,
// Route Handlers). Sessio on evästeissä (@supabase/ssr), ja proxy.ts päivittää sen.
// Kaikki haut tehdään käyttäjän oikeuksilla, joten RLS rajaa datan.
import { createServerClient } from "@supabase/ssr";
import { createAdminClient } from "@supabase/server/core";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Locale } from "@pikkutyo/i18n";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { getPathname } from "@/i18n/navigation";
import { env } from "../env";

export async function createSupabaseServerClient(): Promise<SupabaseClient> {
  const cookieStore = await cookies();
  return createServerClient(env.supabaseUrl, env.supabasePublishableKey, {
    cookies: {
      getAll: () => cookieStore.getAll(),
      setAll: (list) => {
        try {
          for (const { name, value, options } of list) cookieStore.set(name, value, options);
        } catch {
          // Server Component ei voi kirjoittaa evästeitä; proxy.ts päivittää session.
        }
      },
    },
  });
}

export interface AuthContext {
  supabase: SupabaseClient;
  userId: string;
  email: string | null;
}

/**
 * Kirjautunut käyttäjä tai null. getClaims tarkistaa JWT:n allekirjoituksen (JWKS),
 * joten evästeeseen ei luoteta sellaisenaan.
 */
export async function getAuthContext(): Promise<AuthContext | null> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.auth.getClaims();
  const claims = data?.claims;
  if (error || !claims?.sub || claims.is_anonymous) return null;
  return { supabase, userId: claims.sub, email: typeof claims.email === "string" ? claims.email : null };
}

/**
 * Kirjautunut käyttäjä tai ohjaus kirjautumiseen. Kirjautumisen jälkeen palataan
 * tarjoajahakemukseen samalla kielellä.
 */
export async function requireUser(locale: Locale): Promise<AuthContext> {
  const auth = await getAuthContext();
  if (auth) return auth;
  const next = getPathname({ locale, href: "/tarjoajaksi/hakemus" });
  redirect(`${getPathname({ locale, href: "/kirjaudu" })}?next=${encodeURIComponent(next)}`);
}

/**
 * Testikytkimet (tunnistus ja kurssi ilman oikeaa palvelua). Vain kun ALLOW_TEST_SHORTCUTS=true,
 * eikä koskaan Vercelin tuotannossa.
 */
export function testShortcutsEnabled(): boolean {
  return process.env.ALLOW_TEST_SHORTCUTS === "true" && process.env.VERCEL_ENV !== "production";
}

/** Ylläpitoyhteys (ohittaa RLS:n). Käytetään vain testikytkimissä. */
export function createSupabaseAdmin(): SupabaseClient {
  const secretKey = process.env.SUPABASE_SECRET_KEY;
  if (!secretKey) throw new Error("SUPABASE_SECRET_KEY puuttuu");
  return createAdminClient({
    env: { url: env.supabaseUrl, publishableKeys: {}, secretKeys: { default: secretKey }, jwks: null },
  }) as unknown as SupabaseClient;
}
