// Ajo: node --test supabase/functions/_shared/*.test.ts
import assert from "node:assert/strict";
import { test } from "node:test";
import { ALLOWED_PREVIOUS, FakeGateway, getGateway, mapStripeStatus, StripeGateway } from "./gateway.ts";
import { computeSignature, verifyStripeSignature } from "./stripe-signature.ts";

const env = (vars: Record<string, string>) => (name: string) => vars[name];

test("oletuksena testimaksut", () => {
  assert.equal(getGateway(env({})).name, "fake");
});

test("oikea Stripe-avain vaatii erillisen luvan", () => {
  assert.throws(() => getGateway(env({ PAYMENT_GATEWAY: "stripe", STRIPE_SECRET_KEY: "sk_live_x" })), /ALLOW_LIVE/);
  assert.equal(
    getGateway(env({ PAYMENT_GATEWAY: "stripe", STRIPE_SECRET_KEY: "sk_live_x", ALLOW_LIVE_PAYMENTS: "true" })).name,
    "stripe",
  );
  assert.equal(getGateway(env({ PAYMENT_GATEWAY: "stripe", STRIPE_SECRET_KEY: "sk_test_x" })).name, "stripe");
  assert.throws(() => getGateway(env({ PAYMENT_GATEWAY: "stripe" })), /STRIPE_SECRET_KEY/);
});

test("testimaksu: varaus, veloitus ja idempotenssi", async () => {
  const g = new FakeGateway();
  const input = { bookingId: "b", amountCents: 4700, applicationFeeCents: 470, connectedAccountId: null, idempotencyKey: "k1" };
  const a = await g.authorize(input);
  assert.equal(a.status, "authorized");
  assert.ok(a.authorizationExpiresAt);
  assert.deepEqual(await g.authorize(input), a, "sama avain palauttaa saman maksun");
  assert.equal((await g.capture(a.externalId, "k2")).status, "captured");
  assert.equal((await g.refund(a.externalId, 1000, "k3")).status, "succeeded");
});

test("testimaksu: hylätty ja odottava", async () => {
  const input = { bookingId: "b", amountCents: 100, applicationFeeCents: 0, connectedAccountId: null, idempotencyKey: "k" };
  assert.equal((await new FakeGateway("failed").authorize(input)).status, "failed");
  assert.equal((await new FakeGateway("requires_action").authorize(input)).status, "requires_action");
});

test("Stripen tilat", () => {
  assert.equal(mapStripeStatus("requires_capture"), "authorized");
  assert.equal(mapStripeStatus("requires_payment_method"), "pending", "asiakas ei ole aloittanut");
  assert.equal(mapStripeStatus("requires_action"), "requires_action", "asiakas maksamassa");
  assert.equal(mapStripeStatus("succeeded"), "captured");
  assert.equal(mapStripeStatus("canceled"), "canceled");
});

test("Stripe: varaus lähettää oikeat kentät ja idempotenssiavaimen", async () => {
  let request: { url: string; init: RequestInit } | null = null;
  const fakeFetch = (async (url: string, init: RequestInit) => {
    request = { url, init };
    return new Response(JSON.stringify({ id: "pi_1", status: "requires_payment_method" }), { status: 200 });
  }) as unknown as typeof fetch;
  const g = new StripeGateway("sk_test_x", fakeFetch);
  const result = await g.authorize({
    bookingId: "b1", amountCents: 4700, applicationFeeCents: 470, connectedAccountId: "acct_1", idempotencyKey: "k1",
  });
  assert.equal(result.status, "pending");
  assert.ok(request);
  const { url, init } = request as { url: string; init: RequestInit };
  assert.equal(url, "https://api.stripe.com/v1/payment_intents");
  const body = new URLSearchParams(init.body as URLSearchParams);
  assert.equal(body.get("capture_method"), "manual");
  assert.equal(body.get("application_fee_amount"), "470");
  assert.equal(body.get("transfer_data[destination]"), "acct_1");
  assert.equal((init.headers as Record<string, string>)["Idempotency-Key"], "k1");
});

test("webhook ei vie maksua taaksepäin", () => {
  assert.ok(!ALLOWED_PREVIOUS.authorized.includes("captured"), "veloitettu → varattu estetty");
  assert.ok(!ALLOWED_PREVIOUS.pending.includes("authorized"), "varattu → odottaa estetty");
  assert.ok(ALLOWED_PREVIOUS.captured.includes("authorized"));
  for (const target of Object.keys(ALLOWED_PREVIOUS) as (keyof typeof ALLOWED_PREVIOUS)[]) {
    assert.ok(!ALLOWED_PREVIOUS[target].includes("canceled") || target === "canceled", `peruttu → ${target} estetty`);
  }
});

test("Stripe: ei varausta ilman tarjoajan tiliä", async () => {
  const g = new StripeGateway("sk_test_x", (() => { throw new Error("ei kutsuta"); }) as unknown as typeof fetch);
  await assert.rejects(
    g.authorize({ bookingId: "b", amountCents: 1, applicationFeeCents: 0, connectedAccountId: null, idempotencyKey: "k" }),
    /provider_payout_account_missing/,
  );
});

test("webhook-allekirjoitus", async () => {
  const secret = "whsec_test";
  const payload = '{"id":"evt_1"}';
  const now = Date.now();
  const t = String(Math.floor(now / 1000));
  const sig = await computeSignature(secret, t, payload);

  assert.equal(await verifyStripeSignature(payload, `t=${t},v1=${sig}`, secret, { now }), true);
  assert.equal(await verifyStripeSignature(payload, `t=${t},v1=${sig}`, "whsec_other", { now }), false, "väärä salaisuus");
  assert.equal(await verifyStripeSignature(payload + " ", `t=${t},v1=${sig}`, secret, { now }), false, "muutettu sisältö");
  assert.equal(
    await verifyStripeSignature(payload, `t=${t},v1=${sig}`, secret, { now: now + 10 * 60_000 }),
    false,
    "vanha aikaleima",
  );
  assert.equal(await verifyStripeSignature(payload, null, secret, { now }), false, "ei otsaketta");
  assert.equal(await verifyStripeSignature(payload, `t=${t},v1=bad,v1=${sig}`, secret, { now }), true, "useampi v1");
});
