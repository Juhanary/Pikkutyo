import { createServerClient, type CookieOptions } from "@supabase/ssr";
import createMiddleware from "next-intl/middleware";
import { NextResponse, type NextRequest } from "next/server";
import { routing } from "./i18n/routing";
import { env } from "./lib/env";

// Next.js 16: middleware.ts on nimetty proxy.ts:ksi.
const intl = createMiddleware(routing);

export default async function proxy(request: NextRequest) {
  // Supabase ohjaa kirjautumislinkin sivuston juureen, jos paluuosoitetta ei ole sallittu
  // (Auth → URL Configuration). Ohjataan koodi oikeaan käsittelijään.
  if (request.nextUrl.pathname === "/" && request.nextUrl.searchParams.has("code")) {
    const url = request.nextUrl.clone();
    url.pathname = "/api/auth/callback";
    return NextResponse.redirect(url);
  }

  // Session päivitys vain kirjautuneille (sb-*-evästeet): julkiset sivut eivät tee
  // ylimääräistä kutsua. getClaims uusii vanhentuneen tokenin. Uudet evästeet kirjoitetaan
  // ensin pyyntöön, jotta saman pyynnön Server Componentit näkevät päivitetyn session
  // (next-intl välittää pyynnön otsakkeet eteenpäin), ja sitten vastaukseen selaimelle.
  const refreshed: { name: string; value: string; options: CookieOptions }[] = [];
  if (request.cookies.getAll().some((c) => c.name.startsWith("sb-"))) {
    const supabase = createServerClient(env.supabaseUrl, env.supabasePublishableKey, {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (list) => {
          for (const cookie of list) {
            request.cookies.set(cookie.name, cookie.value);
            refreshed.push(cookie);
          }
        },
      },
    });
    await supabase.auth.getClaims();
  }

  const response = intl(request);
  for (const { name, value, options } of refreshed) response.cookies.set(name, value, options);
  return response;
}

export const config = {
  // Kaikki paitsi API, Next.js:n sisäiset polut ja tiedostot (sitemap.xml, robots.txt, kuvat).
  matcher: "/((?!api|_next|_vercel|.*\\..*).*)",
};
