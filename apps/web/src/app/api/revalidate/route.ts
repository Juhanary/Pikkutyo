import { revalidateTag } from "next/cache";
import type { NextRequest } from "next/server";
import { timingSafeEqual } from "node:crypto";

// Kutsutaan Supabasen revalidate-web-funktiosta, kun tarjoaja, hinta tai kaupunki muuttuu.
// Body: { "tags": ["provider:<id>", "providers", "city:<id>"] }
// Header: Authorization: Bearer <REVALIDATE_SECRET>

const TAG = /^(cities|providers|city:[0-9a-f-]{36}|provider:[0-9a-f-]{36})$/;

function authorized(request: NextRequest): boolean {
  const secret = process.env.REVALIDATE_SECRET;
  const header = request.headers.get("authorization") ?? "";
  if (!secret) return false;
  const expected = Buffer.from(`Bearer ${secret}`);
  const given = Buffer.from(header);
  return given.length === expected.length && timingSafeEqual(given, expected);
}

export async function POST(request: NextRequest) {
  if (!authorized(request)) return Response.json({ error: "unauthorized" }, { status: 401 });

  const body = (await request.json().catch(() => null)) as { tags?: unknown } | null;
  const tags = Array.isArray(body?.tags) ? body.tags.filter((t): t is string => typeof t === "string") : [];
  const valid = tags.filter((t) => TAG.test(t)).slice(0, 50);
  if (valid.length === 0) return Response.json({ error: "no valid tags" }, { status: 400 });

  // expire: 0 = vanhentuu heti; "max" vain merkitsisi vanhaksi (stale-while-revalidate),
  // jolloin seuraava kävijä näkisi vielä vanhat hinnat.
  for (const tag of valid) revalidateTag(tag, { expire: 0 });
  return Response.json({ revalidated: valid });
}
