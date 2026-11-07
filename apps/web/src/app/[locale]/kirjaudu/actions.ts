"use server";

import type { Locale } from "@vaihdarenkaat/i18n";
import { redirect } from "next/navigation";
import { getPathname } from "@/i18n/navigation";
import { localeOf, safeNext } from "@/lib/auth";
import { env } from "@/lib/env";
import { createSupabaseServerClient } from "@/lib/supabase/server";

function signInPath(locale: Locale, params: Record<string, string>): string {
  const query = new URLSearchParams(params).toString();
  return `${getPathname({ locale, href: "/kirjaudu" })}${query ? `?${query}` : ""}`;
}

/** Lähettää kirjautumislinkin sähköpostiin. Uusi käyttäjä luodaan samalla. */
export async function sendSignInLink(formData: FormData) {
  const locale = localeOf(formData);
  const next = safeNext(String(formData.get("next") ?? ""));
  const email = String(formData.get("email") ?? "").trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    redirect(signInPath(locale, { next, error: "email" }));
  }

  const supabase = await createSupabaseServerClient();
  const callback = new URL("/api/auth/callback", env.siteUrl);
  callback.searchParams.set("next", next);
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: { emailRedirectTo: callback.toString(), shouldCreateUser: true },
  });
  if (error) {
    // Supabase rajoittaa lähetyksiä (esim. yksi linkki minuutissa samaan osoitteeseen).
    const code = error.status === 429 ? "rate_limit" : "send";
    redirect(signInPath(locale, { next, error: code }));
  }
  redirect(signInPath(locale, { next, sent: "1" }));
}

export async function signOut(formData: FormData) {
  const locale = localeOf(formData);
  const supabase = await createSupabaseServerClient();
  await supabase.auth.signOut();
  redirect(getPathname({ locale, href: "/" }));
}
