"use client";

// Selaimen Supabase-yhteys kirjautuneelle käyttäjälle (liitteiden lataus Storageen).
// Lukee saman session evästeistä kuin palvelin.
import { createBrowserClient } from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";
import { env } from "../env";

let client: SupabaseClient | null = null;

export function getSupabaseBrowserClient(): SupabaseClient {
  client ??= createBrowserClient(env.supabaseUrl, env.supabasePublishableKey);
  return client;
}
