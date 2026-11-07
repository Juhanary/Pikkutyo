// Maksupalvelun rajapinta ja kaksi toteutusta:
//   * FakeGateway: testimaksut, raha ei liiku. Oletus, kunnes PAYMENT_GATEWAY=stripe.
//   * StripeGateway: Stripe Connect (destination charge, capture_method = manual).
//
// Moduuli ei käytä Deno-globaaleja, joten sen voi testata myös Nodella.

export type PaymentStatus =
  | "pending"
  | "requires_action"
  | "authorized"
  | "captured"
  | "canceled"
  | "failed";

export type RefundStatus = "pending" | "succeeded" | "failed" | "canceled";

export interface AuthorizeInput {
  bookingId: string;
  amountCents: number;
  /** Alustan osuus: palkkio + asiakkaan palvelumaksu. */
  applicationFeeCents: number;
  /** Tarjoajan tili maksupalvelussa (Stripe: acct_...). */
  connectedAccountId: string | null;
  idempotencyKey: string;
}

export interface GatewayPayment {
  externalId: string;
  status: PaymentStatus;
  authorizedAt: string | null;
  authorizationExpiresAt: string | null;
  failureReason: string | null;
}

export interface GatewayRefund {
  externalId: string;
  status: RefundStatus;
}

export interface PaymentGateway {
  /** Arvo payments.payment_provider-sarakkeeseen. */
  readonly name: "fake" | "stripe";
  authorize(input: AuthorizeInput): Promise<GatewayPayment>;
  capture(externalId: string, idempotencyKey: string): Promise<GatewayPayment>;
  cancel(externalId: string, idempotencyKey: string): Promise<GatewayPayment>;
  refund(externalId: string, amountCents: number, idempotencyKey: string): Promise<GatewayRefund>;
}

export type Env = (name: string) => string | undefined;

// ---------------------------------------------------------------------------
// Testimaksupalvelu
// ---------------------------------------------------------------------------

/**
 * Testimaksut ilman maksupalvelua. FAKE_AUTHORIZE_RESULT valitsee, miten "asiakas" vastaa
 * maksupyyntöön: authorized (oletus), requires_action (jää odottamaan) tai failed.
 * Saman idempotenssiavaimen uusinta palauttaa saman tuloksen, kuten Stripessä.
 */
export class FakeGateway implements PaymentGateway {
  readonly name = "fake" as const;
  private readonly seen = new Map<string, GatewayPayment | GatewayRefund>();

  private readonly authorizeResult: "authorized" | "requires_action" | "failed";

  constructor(authorizeResult: "authorized" | "requires_action" | "failed" = "authorized") {
    this.authorizeResult = authorizeResult;
  }

  private once<T extends GatewayPayment | GatewayRefund>(key: string, make: () => T): T {
    const previous = this.seen.get(key);
    if (previous) return previous as T;
    const result = make();
    this.seen.set(key, result);
    return result;
  }

  authorize(input: AuthorizeInput): Promise<GatewayPayment> {
    return Promise.resolve(
      this.once(input.idempotencyKey, () => {
        const now = new Date();
        const authorized = this.authorizeResult === "authorized";
        return {
          externalId: `fake_pi_${crypto.randomUUID()}`,
          status: this.authorizeResult,
          authorizedAt: authorized ? now.toISOString() : null,
          authorizationExpiresAt: authorized ? new Date(now.getTime() + AUTHORIZATION_VALID_MS).toISOString() : null,
          failureReason: this.authorizeResult === "failed" ? "fake_declined" : null,
        };
      }),
    );
  }

  capture(externalId: string, idempotencyKey: string): Promise<GatewayPayment> {
    return Promise.resolve(
      this.once(idempotencyKey, () => ({
        externalId,
        status: "captured" as const,
        authorizedAt: null,
        authorizationExpiresAt: null,
        failureReason: null,
      })),
    );
  }

  cancel(externalId: string, idempotencyKey: string): Promise<GatewayPayment> {
    return Promise.resolve(
      this.once(idempotencyKey, () => ({
        externalId,
        status: "canceled" as const,
        authorizedAt: null,
        authorizationExpiresAt: null,
        failureReason: null,
      })),
    );
  }

  refund(_externalId: string, _amountCents: number, idempotencyKey: string): Promise<GatewayRefund> {
    return Promise.resolve(
      this.once(idempotencyKey, () => ({ externalId: `fake_re_${crypto.randomUUID()}`, status: "succeeded" as const })),
    );
  }
}

// ---------------------------------------------------------------------------
// Stripe (REST, ilman SDK:ta)
// ---------------------------------------------------------------------------

type StripePaymentIntent = {
  id: string;
  status: string;
  last_payment_error?: { message?: string } | null;
};

/** Stripen PaymentIntent-tila → payments.status. */
// pending = maksu luotu, asiakas ei ole vielä aloittanut (tai edellinen yritys hylättiin:
// Stripe palauttaa silloin tilan requires_payment_method). requires_action = asiakas on
// maksamassa (3D Secure, MobilePay-sovellus, käsittelyssä). Ero on tärkeä: vain
// requires_action suojaa varausta maksun määräajassa (enforce_payment_deadlines).
export function mapStripeStatus(status: string): PaymentStatus {
  switch (status) {
    case "requires_payment_method":
    case "requires_confirmation":
      return "pending";
    case "requires_action":
    case "processing":
      return "requires_action";
    case "requires_capture":
      return "authorized";
    case "succeeded":
      return "captured";
    case "canceled":
      return "canceled";
    default:
      return "failed";
  }
}

/**
 * Tilat, joista maksu saa siirtyä annettuun tilaan. Webhookit voivat saapua väärässä
 * järjestyksessä: myöhästynyt "requires_capture" ei saa palauttaa veloitettua maksua
 * varatuksi, eikä veloitettu, peruttu tai hyvitetty maksu muutu enää webhookista.
 */
export const ALLOWED_PREVIOUS: Record<PaymentStatus, PaymentStatus[]> = {
  pending: ["pending", "requires_action", "failed"],
  requires_action: ["pending", "requires_action", "failed"],
  failed: ["pending", "requires_action", "failed"],
  authorized: ["pending", "requires_action", "failed", "authorized"],
  captured: ["pending", "requires_action", "authorized", "captured"],
  canceled: ["pending", "requires_action", "failed", "authorized", "canceled"],
};

/** Maksuvarauksen arvioitu voimassaolo (Stripe: korttivaraus 7 päivää). */
export const AUTHORIZATION_VALID_MS = 7 * 86_400_000;

export class StripeGateway implements PaymentGateway {
  readonly name = "stripe" as const;

  private readonly secretKey: string;
  private readonly fetchImpl: typeof fetch;

  constructor(secretKey: string, fetchImpl: typeof fetch = fetch) {
    this.secretKey = secretKey;
    this.fetchImpl = fetchImpl;
  }

  private async post<T>(path: string, params: Record<string, string>, idempotencyKey: string): Promise<T> {
    const response = await this.fetchImpl(`https://api.stripe.com/v1${path}`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.secretKey}`,
        "Content-Type": "application/x-www-form-urlencoded",
        "Idempotency-Key": idempotencyKey,
      },
      body: new URLSearchParams(params),
    });
    const body = await response.json();
    if (!response.ok) {
      throw new Error(`stripe ${path}: ${body?.error?.message ?? response.status}`);
    }
    return body as T;
  }

  private toPayment(pi: StripePaymentIntent): GatewayPayment {
    const status = mapStripeStatus(pi.status);
    return {
      externalId: pi.id,
      status,
      authorizedAt: status === "authorized" ? new Date().toISOString() : null,
      // Arvio; maksun määräaikojen tarkistus reagoi vuorokautta ennen tätä.
      authorizationExpiresAt:
        status === "authorized" ? new Date(Date.now() + AUTHORIZATION_VALID_MS).toISOString() : null,
      failureReason: pi.last_payment_error?.message ?? null,
    };
  }

  async authorize(input: AuthorizeInput): Promise<GatewayPayment> {
    if (!input.connectedAccountId) throw new Error("provider_payout_account_missing");
    const pi = await this.post<StripePaymentIntent>(
      "/payment_intents",
      {
        amount: String(input.amountCents),
        currency: "eur",
        capture_method: "manual",
        "automatic_payment_methods[enabled]": "true",
        application_fee_amount: String(input.applicationFeeCents),
        "transfer_data[destination]": input.connectedAccountId,
        "metadata[booking_id]": input.bookingId,
      },
      input.idempotencyKey,
    );
    return this.toPayment(pi);
  }

  async capture(externalId: string, idempotencyKey: string): Promise<GatewayPayment> {
    return this.toPayment(
      await this.post<StripePaymentIntent>(`/payment_intents/${externalId}/capture`, {}, idempotencyKey),
    );
  }

  async cancel(externalId: string, idempotencyKey: string): Promise<GatewayPayment> {
    return this.toPayment(
      await this.post<StripePaymentIntent>(`/payment_intents/${externalId}/cancel`, {}, idempotencyKey),
    );
  }

  async refund(externalId: string, amountCents: number, idempotencyKey: string): Promise<GatewayRefund> {
    // Suhteellinen jako (docs/adr/0003-ansaintamalli.md): Stripe palauttaa alustan palkkiosta
    // saman osuuden ja perii tarjoajan osuuden takaisin tämän tililtä.
    const refund = await this.post<{ id: string; status: string }>(
      "/refunds",
      {
        payment_intent: externalId,
        amount: String(amountCents),
        refund_application_fee: "true",
        reverse_transfer: "true",
        reason: "requested_by_customer",
      },
      idempotencyKey,
    );
    const status: RefundStatus =
      refund.status === "succeeded" || refund.status === "failed" || refund.status === "canceled"
        ? refund.status
        : "pending";
    return { externalId: refund.id, status };
  }
}

/**
 * Valitsee maksupalvelun ympäristömuuttujista. Oletus on testimaksut. Oikea Stripe-avain
 * (sk_live_) vaatii lisäksi ALLOW_LIVE_PAYMENTS=true, jotta raha ei liiku vahingossa.
 */
export function getGateway(env: Env): PaymentGateway {
  const kind = env("PAYMENT_GATEWAY") ?? "fake";
  if (kind === "fake") {
    const result = env("FAKE_AUTHORIZE_RESULT") ?? "authorized";
    if (result !== "authorized" && result !== "requires_action" && result !== "failed") {
      throw new Error(`FAKE_AUTHORIZE_RESULT: tuntematon arvo ${result}`);
    }
    return new FakeGateway(result);
  }
  if (kind === "stripe") {
    const key = env("STRIPE_SECRET_KEY");
    if (!key) throw new Error("STRIPE_SECRET_KEY puuttuu");
    if (key.startsWith("sk_live_") && env("ALLOW_LIVE_PAYMENTS") !== "true") {
      throw new Error("Oikea Stripe-avain vaatii ALLOW_LIVE_PAYMENTS=true");
    }
    return new StripeGateway(key);
  }
  throw new Error(`PAYMENT_GATEWAY: tuntematon arvo ${kind}`);
}
