// Stripen webhook-allekirjoituksen tarkistus (Stripe-Signature: t=...,v1=...).
// Allekirjoitus on HMAC-SHA256(salaisuus, "<t>.<raw body>"). Ilman SDK:ta, WebCryptolla.

const encoder = new TextEncoder();

function toHex(buffer: ArrayBuffer): string {
  return Array.from(new Uint8Array(buffer), (b) => b.toString(16).padStart(2, "0")).join("");
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export async function computeSignature(secret: string, timestamp: string, payload: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", encoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, [
    "sign",
  ]);
  return toHex(await crypto.subtle.sign("HMAC", key, encoder.encode(`${timestamp}.${payload}`)));
}

/**
 * Palauttaa true, jos jokin v1-allekirjoituksista täsmää ja aikaleima on enintään
 * toleranceSeconds vanha (estää vanhan viestin uudelleenlähetyksen).
 */
export async function verifyStripeSignature(
  payload: string,
  header: string | null,
  secret: string,
  { toleranceSeconds = 300, now = Date.now() }: { toleranceSeconds?: number; now?: number } = {},
): Promise<boolean> {
  if (!header) return false;
  const parts = header.split(",").map((p) => p.trim().split("=") as [string, string]);
  const timestamp = parts.find(([k]) => k === "t")?.[1];
  const signatures = parts.filter(([k]) => k === "v1").map(([, v]) => v);
  if (!timestamp || signatures.length === 0 || !/^\d+$/.test(timestamp)) return false;
  if (Math.abs(now / 1000 - Number(timestamp)) > toleranceSeconds) return false;

  const expected = await computeSignature(secret, timestamp, payload);
  return signatures.some((s) => timingSafeEqual(s, expected));
}
