# Edge Functions

| Funktio | Mitä tekee | Kuka kutsuu |
|---|---|---|
| `payments-worker` | Maksun varaus, veloitus, vapautus ja hyvitys outbox-jonon tapahtumista | pg_cron minuutin välein tai käsin (secret-avain) |
| `stripe-webhook` | Stripen tilamuutokset (maksu hyväksytty, epäonnistui, hyvitys valmis) kantaan | Stripe (allekirjoitus) |

## Rahan kulku

1. Asiakas vahvistaa varauksen. Kanta laskee maksun eräpäivän.
2. Eräpäivänä `enforce_payment_deadlines` (pg_cron) kirjaa jonoon `payment.authorization_due`.
3. `payments-worker` varaa summan asiakkaalta. Rahaa ei vielä veloiteta.
4. Kun työ on kuitattu (`booking.completed`), worker veloittaa varatun summan.
   Jos maksuvaraus on vanhenemassa (kortilla noin 7 päivää) ennen kuittausta, se veloitetaan
   jo aiemmin (`payment.capture_due`), tai ennen työtä vapautetaan ja pyydetään uudelleen
   (`payment.reauthorize_due`).
5. Peruttu varaus (`booking.cancelled`) vapauttaa varauksen ilman veloitusta.
6. Reklamaation hyvitys (`dispute.resolved`) palauttaa rahaa jo veloitetusta maksusta.
   Palkkio pienenee samassa suhteessa (ks. `docs/adr/0003-ansaintamalli.md`).

## Testimaksut (oletus)

Ilman asetuksia käytössä on `PAYMENT_GATEWAY=fake`: maksut kirjataan kantaan
`payment_provider = 'fake'` -arvolla, eikä mihinkään palveluun oteta yhteyttä.
`FAKE_AUTHORIZE_RESULT` valitsee, miten "asiakas" vastaa maksupyyntöön:

- `authorized` (oletus): maksu varataan heti
- `requires_action`: jää odottamaan (esim. MobilePay-sovelluksessa)
- `failed`: kortti hylätään

Maksujen käsittely vaatii myös, että alustan asetus on päällä:

```sql
update public.platform_settings set payments_enabled = true;
```

## Käyttöönotto

```bash
npx supabase functions deploy payments-worker
npx supabase functions deploy stripe-webhook
```

Ajastus on migraatiossa (`20261107090700_scheduled_jobs.sql`): pg_cron kutsuu
`private.invoke_payments_worker()`-funktiota minuutin välein, ja se kutsuu workeria
pg_netillä. Funktio ei tee mitään, ellei maksut ole käytössä ja Vaultissa ole osoitetta
ja avainta. Ne lisätään kerran SQL-editorissa (ei koodiin):

```sql
select vault.create_secret('https://<projekti>.supabase.co/functions/v1/payments-worker', 'payments_worker_url');
select vault.create_secret('sb_secret_...', 'payments_worker_key');
```

Huom: kannan tyhjennys (`npm run db:seed`) poistaa myös Vaultin salaisuudet, joten ne
lisätään sen jälkeen uudelleen.

Käsin testatessa:

```bash
curl -X POST https://<projekti>.supabase.co/functions/v1/payments-worker -H "apikey: sb_secret_..."
```

Vastaus kertoo jokaisen käsitellyn tapahtuman ja mitä sille tehtiin.

Jos tapahtuman käsittely epäonnistuu 10 kertaa, se merkitään epäonnistuneeksi
(`outbox_events.failed_at`) eikä sitä enää yritetä. Ylläpito näkee ne:

```sql
select id, type, aggregate_id, last_error, failed_at from public.outbox_events
 where failed_at is not null order by failed_at desc;
```

## Stripe myöhemmin

1. Stripe-tili ja Connect (Express) tarjoajille. Tarjoajan tili kirjataan
   `provider_payout_accounts`-tauluun. Kun maksut ovat käytössä, tarjoajaa ei voi julkaista
   ilman tiliä (`payout_account_missing`).
2. `supabase secrets set PAYMENT_GATEWAY=stripe STRIPE_SECRET_KEY=sk_test_... STRIPE_WEBHOOK_SECRET=whsec_...`
3. Webhook Stripessä osoitteeseen `.../functions/v1/stripe-webhook`. Tapahtumat:
   `payment_intent.*`, `refund.created`, `refund.updated`, `refund.failed`.
4. Oikea avain (`sk_live_`) vaatii lisäksi `ALLOW_LIVE_PAYMENTS=true`.

Vielä puuttuu: asiakkaan maksunäkymä. Stripessä asiakas hyväksyy varauksen
sovelluksessa (Payment Element / MobilePay), mikä vaatii funktion, joka antaa
kirjautuneelle asiakkaalle maksun `client_secret`-arvon. Testimaksuissa tätä ei tarvita.

## Testit

```bash
node --test supabase/functions/_shared/*.test.ts
```
