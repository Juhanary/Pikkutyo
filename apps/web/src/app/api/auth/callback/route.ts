import { NextResponse, type NextRequest } from "next/server";
import { safeNext } from "@/lib/auth";
import { createSupabaseServerClient } from "@/lib/supabase/server";

// Kirjautumislinkin paluu: vaihtaa koodin sessioksi (PKCE) ja ohjaa takaisin.
// Linkki on avattava samassa selaimessa, jossa se pyydettiin.
export async function GET(request: NextRequest) {
  const code = request.nextUrl.searchParams.get("code");
  const next = safeNext(request.nextUrl.searchParams.get("next"));

  if (code) {
    const supabase = await createSupabaseServerClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) return NextResponse.redirect(new URL(next, request.nextUrl.origin));
  }
  const failed = new URL("/kirjaudu", request.nextUrl.origin);
  failed.searchParams.set("error", "link");
  return NextResponse.redirect(failed);
}
