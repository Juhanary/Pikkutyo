// Maksutyöntekijä: hakee maksutapahtumat outbox-jonosta ja käsittelee ne (ks. handlers.ts).
//
// Kutsutaan secret-avaimella (apikey-otsake): pg_cron + pg_net minuutin välein tai käsin
// testatessa. Ks. supabase/functions/README.md.
import { withSupabase } from "npm:@supabase/server@1";
import { getGateway } from "../_shared/gateway.ts";
import { handle, PAYMENT_EVENT_TYPES, RetryLater, type OutboxEvent } from "./handlers.ts";

const BATCH = 25;

export default {
  fetch: withSupabase({ auth: "secret" }, async (_req, ctx) => {
    const db = ctx.supabaseAdmin;
    const gateway = getGateway((name) => Deno.env.get(name));

    const { data, error } = await db.rpc("worker_claim_outbox_events", {
      p_limit: BATCH,
      p_types: [...PAYMENT_EVENT_TYPES],
    });
    if (error) return Response.json({ error: error.message }, { status: 500 });

    // Tapahtuman tila jonoon. Jos kirjaus epäonnistuu, lukko vapautuu 2 minuutissa ja
    // tapahtuma ajetaan uudelleen (käsittelijät ovat idempotentteja), mutta siitä lokimerkintä.
    const complete = async (event: OutboxEvent, message: string | null) => {
      const { error: e } = await db.rpc("worker_complete_outbox_event", { p_id: event.id, p_error: message });
      if (e) console.error(`tapahtuman ${event.id} kirjaus epäonnistui:`, e.message);
    };

    const results = [];
    for (const event of (data ?? []) as OutboxEvent[]) {
      try {
        const outcome = await handle(db, gateway, event);
        await complete(event, null);
        results.push({ id: event.id, type: event.type, ...outcome });
      } catch (e) {
        // Virhe kirjataan tapahtumaan, ja jono yrittää uudelleen kasvavalla viiveellä
        // (enintään 10 kertaa, sitten failed_at). RetryLater on odotettu tilanne, ei vika.
        const message = e instanceof Error ? e.message : String(e);
        await complete(event, message);
        const exhausted = event.attempts >= 10;
        if (exhausted || !(e instanceof RetryLater)) {
          console.error(
            `maksutapahtuma ${event.id} (${event.type})${exhausted ? " – yritykset loppuivat, vaatii selvitystä" : ""}:`,
            message,
          );
        }
        results.push({
          id: event.id,
          type: event.type,
          action: exhausted ? "failed" : e instanceof RetryLater ? "retry" : "error",
          detail: message,
        });
      }
    }

    return Response.json({ gateway: gateway.name, processed: results.length, results });
  }),
};
