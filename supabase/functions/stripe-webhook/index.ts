// Stripen webhook: maksun ja hyvityksen tilamuutokset kantaan.
//
// Stripe ei voi lähettää Supabasen avaimia, joten auth on 'none' ja kutsuja tunnistetaan
// allekirjoituksesta (STRIPE_WEBHOOK_SECRET). Sama tapahtuma käsitellään vain kerran
// (payment_events.external_event_id on uniikki).
import { withSupabase } from "npm:@supabase/server@1";
import { ALLOWED_PREVIOUS, AUTHORIZATION_VALID_MS, mapStripeStatus } from "../_shared/gateway.ts";
import { verifyStripeSignature } from "../_shared/stripe-signature.ts";

type StripeEvent = {
  id: string;
  type: string;
  data: { object: Record<string, unknown> };
};

export default {
  fetch: withSupabase({ auth: "none" }, async (req, ctx) => {
    const secret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
    if (!secret) return Response.json({ error: "STRIPE_WEBHOOK_SECRET puuttuu" }, { status: 500 });

    const body = await req.text();
    if (!(await verifyStripeSignature(body, req.headers.get("stripe-signature"), secret))) {
      return Response.json({ error: "invalid signature" }, { status: 401 });
    }
    const event = JSON.parse(body) as StripeEvent;
    const db = ctx.supabaseAdmin;

    // Kirjaus ensin: uusinta (sama id) ohitetaan.
    const { data: inserted, error: insertError } = await db
      .from("payment_events")
      .upsert(
        { payment_provider: "stripe", external_event_id: event.id, type: event.type, payload: event },
        { onConflict: "payment_provider,external_event_id", ignoreDuplicates: true },
      )
      .select("id");
    if (insertError) return Response.json({ error: insertError.message }, { status: 500 });
    let rowId = (inserted?.[0] as { id: number } | undefined)?.id;
    if (rowId == null) {
      // Sama tapahtuma on tullut aiemmin: ohitetaan, jos se käsiteltiin, muuten yritetään uudelleen.
      const { data: previous, error: e } = await db
        .from("payment_events")
        .select("id, processed_at")
        .eq("payment_provider", "stripe")
        .eq("external_event_id", event.id)
        .single();
      if (e) return Response.json({ error: e.message }, { status: 500 });
      const row = previous as { id: number; processed_at: string | null };
      if (row.processed_at) return Response.json({ received: true, duplicate: true });
      rowId = row.id;
    }

    let error: string | null = null;
    try {
      const object = event.data.object;
      if (event.type.startsWith("payment_intent.")) {
        const status = mapStripeStatus(String(object.status));
        const now = new Date().toISOString();
        const lastError = object.last_payment_error as { message?: string } | null | undefined;
        const { error: e } = await db
          .from("payments")
          .update({
            status,
            ...(status === "authorized" && {
              authorized_at: now,
              authorization_expires_at: new Date(Date.now() + AUTHORIZATION_VALID_MS).toISOString(),
            }),
            ...(status === "captured" && { captured_at: now }),
            ...(status === "canceled" && { canceled_at: now }),
            failure_reason: lastError?.message ?? null,
          })
          .eq("payment_provider", "stripe")
          .eq("external_id", String(object.id))
          // Vain sallitut siirtymät: väärässä järjestyksessä saapunut tapahtuma ei vie
          // maksua taaksepäin (esim. veloitettu → varattu).
          .in("status", ALLOWED_PREVIOUS[status]);
        if (e) throw new Error(e.message);
      } else if (event.type === "refund.created" || event.type === "refund.updated" || event.type === "refund.failed") {
        const status = String(object.status);
        const { error: e } = await db
          .from("refunds")
          .update({ status: ["succeeded", "failed", "canceled"].includes(status) ? status : "pending" })
          .eq("external_id", String(object.id));
        if (e) throw new Error(e.message);
      }
    } catch (e) {
      error = e instanceof Error ? e.message : String(e);
    }

    await db
      .from("payment_events")
      .update({ processed_at: error ? null : new Date().toISOString(), error })
      .eq("id", rowId);
    // 500 saa Stripen yrittämään uudelleen, ja käsittelemätön tapahtuma ajetaan silloin uudestaan.
    // Virhe jää payment_events-tauluun selvitettäväksi.
    return error ? Response.json({ error }, { status: 500 }) : Response.json({ received: true });
  }),
};
