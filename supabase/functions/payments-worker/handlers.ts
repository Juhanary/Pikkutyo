// Maksutapahtumien käsittely. Kanta kirjaa tapahtumat outbox-jonoon (ks. migraatiot),
// ja tämä tiedosto tekee niiden perusteella maksupalvelun toimenpiteet:
//
//   payment.authorization_due → maksun varaus (summa varataan, ei veloiteta)
//   booking.completed         → veloitus (capture) kuittauksen jälkeen
//   booking.cancelled         → varauksen vapautus ilman veloitusta
//   dispute.resolved          → hyvitys (osittainen tai täysi), jos raha on jo veloitettu
//   payment.capture_due       → veloitus ennen kuin maksuvaraus vanhenee (työ tehty tai kesken)
//   payment.reauthorize_due   → vanheneva varaus vapautetaan, ja maksu pyydetään uudelleen
//
// Jokainen käsittelijä on idempotentti: sama tapahtuma voidaan ajaa uudelleen (esim. jos
// työntekijä kaatuu kesken), eikä se tee toista varausta, veloitusta tai hyvitystä.
// Maksupalvelun idempotenssiavain johdetaan tapahtuman id:stä, joten myös palvelun puolella
// uusinta palauttaa saman tuloksen.

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { PaymentGateway } from "../_shared/gateway.ts";

export interface OutboxEvent {
  id: number;
  type: string;
  aggregate_id: string;
  payload: Record<string, unknown>;
  attempts: number;
}

export const PAYMENT_EVENT_TYPES = [
  "payment.authorization_due",
  "booking.completed",
  "booking.cancelled",
  "dispute.resolved",
  "payment.capture_due",
  "payment.reauthorize_due",
] as const;

/** Tulos lokiin ja vastaukseen: mitä tapahtumalle tehtiin. */
export type Outcome = { action: string; detail?: string };

/** Virhe, jonka jälkeen tapahtuma yritetään uudelleen myöhemmin (esim. odotetaan toista tapahtumaa). */
export class RetryLater extends Error {}

const ACTIVE = ["pending", "requires_action", "authorized", "captured", "partially_refunded"];

type PaymentRow = {
  id: string;
  external_id: string;
  status: string;
  amount_cents: number;
  payment_provider: string;
};

function check<T>(what: string, result: { data: T; error: { message: string } | null }): T {
  if (result.error) throw new Error(`${what}: ${result.error.message}`);
  return result.data;
}

async function activePayment(db: SupabaseClient, bookingId: string): Promise<PaymentRow | null> {
  const rows = check(
    "maksu",
    await db
      .from("payments")
      .select("id, external_id, status, amount_cents, payment_provider")
      .eq("booking_id", bookingId)
      .in("status", ACTIVE)
      .limit(1),
  ) as PaymentRow[];
  return rows[0] ?? null;
}

async function paymentsEnabled(db: SupabaseClient): Promise<boolean> {
  const row = check(
    "asetukset",
    await db.from("platform_settings").select("payments_enabled").single(),
  ) as { payments_enabled: boolean };
  return row.payments_enabled;
}

/** Testimaksua ei voi veloittaa Stripestä eikä päinvastoin (esim. kun PAYMENT_GATEWAY vaihtuu). */
function assertSameGateway(payment: PaymentRow, gateway: PaymentGateway): void {
  if (payment.payment_provider !== gateway.name) {
    throw new Error(`maksu ${payment.id} on tehty palvelulla ${payment.payment_provider}, nyt käytössä ${gateway.name}`);
  }
}

function key(event: OutboxEvent, step: string): string {
  return `vaihdarenkaat:${event.id}:${step}`;
}

// ---------------------------------------------------------------------------

async function authorizationDue(db: SupabaseClient, gateway: PaymentGateway, event: OutboxEvent): Promise<Outcome> {
  const booking = check(
    "varaus",
    await db
      .from("bookings")
      .select("id, status, provider_id, customer_total_cents, service_fee_cents, booking_commissions(commission_cents)")
      .eq("id", event.aggregate_id)
      .maybeSingle(),
  ) as {
    id: string;
    status: string;
    provider_id: string;
    customer_total_cents: number;
    service_fee_cents: number;
    booking_commissions: { commission_cents: number } | null;
  } | null;

  if (!booking || booking.status !== "confirmed") return { action: "skip", detail: `status ${booking?.status}` };
  if (booking.customer_total_cents <= 0) return { action: "skip", detail: "maksuton varaus" };
  if (await activePayment(db, booking.id)) return { action: "skip", detail: "maksu on jo olemassa" };
  const applicationFeeCents = (booking.booking_commissions?.commission_cents ?? 0) + booking.service_fee_cents;

  const account = check(
    "tarjoajan tili",
    await db
      .from("provider_payout_accounts")
      .select("external_account_id, charges_enabled")
      .eq("provider_id", booking.provider_id)
      .maybeSingle(),
  ) as { external_account_id: string; charges_enabled: boolean } | null;

  const result = await gateway.authorize({
    bookingId: booking.id,
    amountCents: booking.customer_total_cents,
    applicationFeeCents,
    connectedAccountId: account?.charges_enabled ? account.external_account_id : null,
    idempotencyKey: key(event, "authorize"),
  });

  check(
    "maksun kirjaus",
    await db.from("payments").insert({
      booking_id: booking.id,
      payment_provider: gateway.name,
      external_id: result.externalId,
      status: result.status,
      amount_cents: booking.customer_total_cents,
      application_fee_cents: applicationFeeCents,
      authorized_at: result.authorizedAt,
      authorization_expires_at: result.authorizationExpiresAt,
      failure_reason: result.failureReason,
    }),
  );
  return { action: "authorize", detail: result.status };
}

async function capture(db: SupabaseClient, gateway: PaymentGateway, event: OutboxEvent, payment: PaymentRow): Promise<Outcome> {
  assertSameGateway(payment, gateway);
  const result = await gateway.capture(payment.external_id, key(event, "capture"));
  check(
    "veloituksen kirjaus",
    await db
      .from("payments")
      .update({ status: result.status, captured_at: result.status === "captured" ? new Date().toISOString() : null })
      .eq("id", payment.id),
  );
  return { action: "capture", detail: result.status };
}

async function bookingCompleted(db: SupabaseClient, gateway: PaymentGateway, event: OutboxEvent): Promise<Outcome> {
  const payment = await activePayment(db, event.aggregate_id);
  if (!payment) {
    // Pilotissa maksut eivät ole käytössä: kuittaus ilman maksua on normaali tilanne.
    if (!(await paymentsEnabled(db))) return { action: "skip", detail: "maksut eivät ole käytössä" };
    // Maksua ei ole koskaan pyydetty (maksuton varaus, tai varaus tehtiin ennen kuin maksut
    // otettiin käyttöön): odottaminen ei auta.
    const booking = check(
      "varaus",
      await db.from("bookings").select("payment_requested_at").eq("id", event.aggregate_id).maybeSingle(),
    ) as { payment_requested_at: string | null } | null;
    if (!booking?.payment_requested_at) return { action: "skip", detail: "maksua ei ole pyydetty" };
    throw new RetryLater("kuitatulla varauksella ei ole maksua");
  }
  if (payment.status === "captured" || payment.status === "partially_refunded") {
    return { action: "skip", detail: "jo veloitettu" };
  }
  if (payment.status !== "authorized") throw new RetryLater(`maksu ei ole varattu (${payment.status})`);
  return capture(db, gateway, event, payment);
}

/** Maksuvaraus vanhenee pian, ja työ on tehty tai kesken: veloitetaan nyt. */
async function captureDue(db: SupabaseClient, gateway: PaymentGateway, event: OutboxEvent): Promise<Outcome> {
  const payment = await activePayment(db, event.aggregate_id);
  if (!payment || payment.status !== "authorized") return { action: "skip", detail: `maksu ${payment?.status}` };
  return capture(db, gateway, event, payment);
}

/**
 * Maksuvaraus vanhenee ennen työtä: vapautetaan vanha ja pyydetään uusi. Maksun määräajat
 * (enforce_payment_deadlines) lähettävät uuden pyynnön seuraavalla ajolla.
 */
async function reauthorizeDue(db: SupabaseClient, gateway: PaymentGateway, event: OutboxEvent): Promise<Outcome> {
  const payment = await activePayment(db, event.aggregate_id);
  if (!payment || payment.status !== "authorized") return { action: "skip", detail: `maksu ${payment?.status}` };
  assertSameGateway(payment, gateway);
  await gateway.cancel(payment.external_id, key(event, "cancel"));
  check(
    "vanhan varauksen vapautus",
    await db.from("payments").update({ status: "canceled", canceled_at: new Date().toISOString() }).eq("id", payment.id),
  );
  check(
    "uusi maksupyyntö",
    await db
      .from("bookings")
      .update({ payment_requested_at: null, payment_due_at: new Date().toISOString() })
      .eq("id", event.aggregate_id)
      .eq("status", "confirmed"),
  );
  return { action: "reauthorize", detail: "uusi pyyntö seuraavalla ajolla" };
}

async function bookingCancelled(db: SupabaseClient, gateway: PaymentGateway, event: OutboxEvent): Promise<Outcome> {
  const payment = await activePayment(db, event.aggregate_id);
  if (!payment) return { action: "skip", detail: "ei maksua" };
  if (payment.status === "captured" || payment.status === "partially_refunded") {
    // Peruutus ei veloitetun maksun jälkeen tapahdu tavallisesti; hyvitys tehdään reklamaation kautta.
    return { action: "skip", detail: "jo veloitettu" };
  }

  assertSameGateway(payment, gateway);
  const result = await gateway.cancel(payment.external_id, key(event, "cancel"));
  check(
    "vapautuksen kirjaus",
    await db
      .from("payments")
      .update({ status: result.status, canceled_at: new Date().toISOString() })
      .eq("id", payment.id),
  );
  return { action: "cancel", detail: result.status };
}

async function disputeResolved(db: SupabaseClient, gateway: PaymentGateway, event: OutboxEvent): Promise<Outcome> {
  const disputeId = String(event.payload.dispute_id ?? event.aggregate_id);
  const bookingId = String(event.payload.booking_id);
  const refundCents = Number(event.payload.refund_cents ?? 0);
  if (!(refundCents > 0)) return { action: "skip", detail: "ei hyvitystä" };

  const existing = check(
    "aiempi hyvitys",
    await db.from("refunds").select("id").eq("dispute_id", disputeId).limit(1),
  ) as { id: string }[];
  if (existing.length > 0) return { action: "skip", detail: "hyvitys on jo tehty" };

  const payment = await activePayment(db, bookingId);
  if (!payment) {
    // Täysi hyvitys ennen veloitusta perii varauksen: booking.cancelled vapauttaa maksun.
    return { action: "skip", detail: "ei veloitettua maksua" };
  }
  if (payment.status === "authorized" || payment.status === "pending" || payment.status === "requires_action") {
    // Ylläpidon kuittaus (booking.completed) veloittaa ensin; hyvitys sen jälkeen.
    throw new RetryLater("maksua ei ole vielä veloitettu");
  }

  const refunded = check(
    "hyvitykset",
    await db.from("refunds").select("amount_cents").eq("payment_id", payment.id).in("status", ["pending", "succeeded"]),
  ) as { amount_cents: number }[];
  const alreadyRefunded = refunded.reduce((sum, r) => sum + r.amount_cents, 0);
  const amount = Math.min(refundCents, payment.amount_cents - alreadyRefunded);
  if (amount <= 0) return { action: "skip", detail: "maksu on jo hyvitetty kokonaan" };

  assertSameGateway(payment, gateway);
  const result = await gateway.refund(payment.external_id, amount, key(event, "refund"));
  check(
    "hyvityksen kirjaus",
    await db.from("refunds").insert({
      payment_id: payment.id,
      external_id: result.externalId,
      amount_cents: amount,
      reason: "dispute",
      status: result.status,
      dispute_id: disputeId,
    }),
  );
  check(
    "maksun tila",
    await db
      .from("payments")
      .update({ status: alreadyRefunded + amount >= payment.amount_cents ? "refunded" : "partially_refunded" })
      .eq("id", payment.id),
  );
  return { action: "refund", detail: `${amount} snt, ${result.status}` };
}

export function handle(db: SupabaseClient, gateway: PaymentGateway, event: OutboxEvent): Promise<Outcome> {
  switch (event.type) {
    case "payment.authorization_due":
      return authorizationDue(db, gateway, event);
    case "booking.completed":
      return bookingCompleted(db, gateway, event);
    case "booking.cancelled":
      return bookingCancelled(db, gateway, event);
    case "dispute.resolved":
      return disputeResolved(db, gateway, event);
    case "payment.capture_due":
      return captureDue(db, gateway, event);
    case "payment.reauthorize_due":
      return reauthorizeDue(db, gateway, event);
    default:
      return Promise.resolve({ action: "skip", detail: `tuntematon tyyppi ${event.type}` });
  }
}
