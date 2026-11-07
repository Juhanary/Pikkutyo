-- Maksut Stripe Connectilla.
--
-- Malli: asiakkaan maksu varataan (PaymentIntent, capture_method = manual) ja veloitetaan
-- vasta kuittauksen jälkeen. Rahat ohjataan tarjoajan Stripe-tilille (destination charge),
-- ja alustan palkkio on application_fee. Kaikki kirjoitukset tehdään Edge Functionsista
-- secret-avaimella (service_role); selaimet ja sovellukset vain lukevat omia rivejään.
-- Maksupalvelun tunnisteet ovat omissa sarakkeissaan, joten toinen palveluntarjoaja
-- voidaan lisätä myöhemmin payment_provider-arvolla.

-- 'fake' on testimaksupalvelu (supabase/functions/_shared/gateway.ts): raha ei liiku, ja
-- rivit erottuvat oikeista. Edge Functions käyttää sitä, kunnes PAYMENT_GATEWAY=stripe.
create type public.payment_provider as enum ('stripe', 'fake');

-- Tarjoajan tili maksupalvelussa (Stripe Connect Express).
create table public.provider_payout_accounts (
  provider_id uuid primary key references public.providers (id) on delete cascade,
  payment_provider public.payment_provider not null default 'stripe',
  external_account_id text not null unique,
  charges_enabled boolean not null default false,
  payouts_enabled boolean not null default false,
  details_submitted boolean not null default false,
  requirements jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger provider_payout_accounts_updated_at before update on public.provider_payout_accounts
  for each row execute function public.set_updated_at();

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id) on delete restrict,
  payment_provider public.payment_provider not null default 'stripe',
  external_id text not null,
  status public.payment_status not null default 'pending',
  amount_cents integer not null check (amount_cents > 0),
  application_fee_cents integer not null default 0 check (application_fee_cents >= 0),
  currency char(3) not null default 'EUR',
  method text,                       -- esim. 'mobilepay', 'card'
  authorized_at timestamptz,
  authorization_expires_at timestamptz,
  -- Milloin vanheneva varaus on käsitelty (veloitettu ajoissa tai pyydetty uudelleen).
  expiry_handled_at timestamptz,
  captured_at timestamptz,
  canceled_at timestamptz,
  failure_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (payment_provider, external_id),
  check (application_fee_cents <= amount_cents)
);
-- Varauksella voi olla vain yksi voimassa oleva maksu kerrallaan (uusi yritys epäonnistuneen jälkeen sallitaan).
create unique index payments_one_active_per_booking on public.payments (booking_id)
  where status in ('pending', 'requires_action', 'authorized', 'captured', 'partially_refunded');
create index payments_booking_idx on public.payments (booking_id);
create index payments_auth_expiry_idx on public.payments (authorization_expires_at) where status = 'authorized';
create trigger payments_updated_at before update on public.payments
  for each row execute function public.set_updated_at();

create table public.refunds (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payments (id) on delete restrict,
  external_id text not null,
  amount_cents integer not null check (amount_cents > 0),
  reason text,
  status text not null default 'pending' check (status in ('pending', 'succeeded', 'failed', 'canceled')),
  dispute_id uuid,                    -- viite lisätään disputes-migraatiossa
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (external_id)
);
create index refunds_payment_idx on public.refunds (payment_id);
create trigger refunds_updated_at before update on public.refunds
  for each row execute function public.set_updated_at();

-- Tilitykset tarjoajan pankkitilille (Stripe payout -tapahtumista).
create table public.payouts (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers (id) on delete restrict,
  external_id text not null unique,
  amount_cents integer not null,
  currency char(3) not null default 'EUR',
  status text not null check (status in ('pending', 'in_transit', 'paid', 'failed', 'canceled')),
  arrival_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index payouts_provider_idx on public.payouts (provider_id, created_at desc);
create trigger payouts_updated_at before update on public.payouts
  for each row execute function public.set_updated_at();

-- Maksupalvelun webhook-tapahtumat: sama tapahtuma käsitellään vain kerran.
create table public.payment_events (
  id bigint generated always as identity primary key,
  payment_provider public.payment_provider not null default 'stripe',
  external_event_id text not null,
  type text not null,
  payload jsonb not null,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  error text,
  unique (payment_provider, external_event_id)
);
create index payment_events_unprocessed_idx on public.payment_events (received_at) where processed_at is null;

-- ---------------------------------------------------------------------------
-- RLS: luku osapuolille, kirjoitus vain service_rolelle
-- ---------------------------------------------------------------------------
alter table public.provider_payout_accounts enable row level security;
alter table public.payments enable row level security;
alter table public.refunds enable row level security;
alter table public.payouts enable row level security;
alter table public.payment_events enable row level security;

create policy "provider_payout_accounts: jäsenet ja admin" on public.provider_payout_accounts
  for select to authenticated
  using (private.is_provider_member(provider_id) or (select private.is_admin()));

create policy "payments: varauksen osapuolet" on public.payments
  for select to authenticated using (private.booking_role(booking_id) is not null);

create policy "refunds: varauksen osapuolet" on public.refunds
  for select to authenticated
  using (exists (select 1 from public.payments p
                  where p.id = payment_id and private.booking_role(p.booking_id) is not null));

create policy "payouts: jäsenet ja admin" on public.payouts
  for select to authenticated
  using (private.is_provider_member(provider_id) or (select private.is_admin()));

-- payment_events: ei politiikkoja → vain service_role.

grant select on public.provider_payout_accounts, public.refunds, public.payouts to authenticated;
-- application_fee_cents (alustan osuus) paljastaisi palkkion asiakkaalle, joten sitä ei
-- anneta. Sovellusten on listattava sarakkeet (select=* ei toimi tähän tauluun).
grant select (id, booking_id, payment_provider, external_id, status, amount_cents, currency, method,
              authorized_at, authorization_expires_at, captured_at, canceled_at, failure_reason,
              created_at, updated_at)
  on public.payments to authenticated;

-- ---------------------------------------------------------------------------
-- Tarjoajan tienestit kuukausittain (Tienestit-näkymä)
-- ---------------------------------------------------------------------------
-- Hyvitys jaetaan suhteessa (ks. docs/adr/0003-ansaintamalli.md): jos asiakkaalle
-- palautetaan 20 % maksusta, sekä tarjoajan osuus että alustan palkkio pienenevät 20 %.
-- Tämä näkymä on ainoa paikka, jossa sääntö lasketaan; tienestit ja DAC7-raportti lukevat sitä.
create or replace view public.payment_settlements
with (security_invoker = true)
as
select p.id as payment_id,
       p.booking_id,
       b.provider_id,
       p.captured_at,
       r.refunded_cents,
       g.gross_cents,
       g.commission_cents,
       g.gross_cents - g.commission_cents as net_cents
  from public.payments p
  join public.bookings b on b.id = p.booking_id
  -- Inner join: asiakas ei näe palkkiorivejä (RLS), joten hän ei näe tätä näkymää lainkaan.
  join public.booking_commissions bc on bc.booking_id = b.id
  cross join lateral (
    select coalesce(sum(x.amount_cents), 0)::bigint as refunded_cents
      from public.refunds x
     where x.payment_id = p.id and x.status = 'succeeded'
  ) r
  -- Osuus maksusta, joka jäi asiakkaalta veloitetuksi (0–1).
  cross join lateral (
    select greatest(1 - r.refunded_cents::numeric / p.amount_cents, 0) as kept
  ) k
  cross join lateral (
    select round((b.price_cents + b.travel_fee_cents) * k.kept)::bigint as gross_cents,
           round(bc.commission_cents * k.kept)::bigint as commission_cents
  ) g
 where p.status in ('captured', 'partially_refunded');

create or replace view public.provider_earnings
with (security_invoker = true)
as
select s.provider_id,
       date_trunc('month', s.captured_at at time zone 'Europe/Helsinki')::date as month,
       count(*)::integer as job_count,
       sum(s.gross_cents)::bigint as gross_cents,
       sum(s.commission_cents)::bigint as commission_cents,
       sum(s.refunded_cents)::bigint as refunded_cents,
       sum(s.net_cents)::bigint as net_cents
  from public.payment_settlements s
 group by s.provider_id, date_trunc('month', s.captured_at at time zone 'Europe/Helsinki');

grant select on public.payment_settlements, public.provider_earnings to authenticated;

-- ---------------------------------------------------------------------------
-- Maksun määräajat (pg_cron). Toimii vain, kun platform_settings.payments_enabled = true.
-- ---------------------------------------------------------------------------
create or replace function private.enforce_payment_deadlines()
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_settings public.platform_settings := private.settings();
  v_row record;
  v_count integer := 0;
  v_cancelled integer := 0;
begin
  if not v_settings.payments_enabled then
    return 0;
  end if;

  -- 0. Maksuvaraus vanhenee (kortilla noin 7 päivää). Vuorokautta ennen:
  --    työ tehty tai kesken → veloitetaan heti (mahdollinen hyvitys reklamaation kautta),
  --    työ vasta tulossa → vanha varaus vapautetaan ja maksu pyydetään uudelleen.
  for v_row in
    update public.payments p
       set expiry_handled_at = now()
      from public.bookings b
     where b.id = p.booking_id
       and p.status = 'authorized'
       and p.expiry_handled_at is null
       and p.authorization_expires_at <= now() + interval '24 hours'
       and b.status in ('confirmed', 'in_progress', 'work_done', 'disputed')
    returning p.id as payment_id, b.id as booking_id, b.status::text as booking_status
  loop
    perform private.enqueue(
      case when v_row.booking_status = 'confirmed' then 'payment.reauthorize_due' else 'payment.capture_due' end,
      v_row.booking_id,
      jsonb_build_object('booking_id', v_row.booking_id, 'payment_id', v_row.payment_id));
    v_count := v_count + 1;
  end loop;

  -- 1. Pyydä maksun varaus, kun eräpäivä on tullut. Maksuton varaus ei tarvitse maksua.
  for v_row in
    update public.bookings b
       set payment_requested_at = now()
     where b.status = 'confirmed'
       and b.payment_due_at <= now()
       and b.payment_requested_at is null
       and b.customer_total_cents > 0
       and not exists (select 1 from public.payments p
                        where p.booking_id = b.id and p.status in ('authorized', 'captured'))
    returning b.id, b.customer_id, b.customer_total_cents
  loop
    perform private.enqueue('payment.authorization_due', v_row.id,
      jsonb_build_object('booking_id', v_row.id, 'customer_id', v_row.customer_id,
                         'amount_cents', v_row.customer_total_cents));
    v_count := v_count + 1;
  end loop;

  -- 2. Vapauta aika, jos asiakas ei ole maksanut ajoissa:
  --    * asiakkaalla on aina vähintään payment_grace_minutes aikaa maksupyynnöstä,
  --    * maksupyyntö on oikeasti mennyt perille (maksurivi on olemassa). Jos pyyntö jäi
  --      alustan päähän (esim. tarjoajalta puuttuu maksutili), asiakasta ei rangaista,
  --    * kesken oleva maksu (requires_action, esim. MobilePay-sovelluksessa) suojaa varausta,
  --      mutta vain niin kauan kuin se etenee (päivitetty armonajan sisällä).
  --    pending = maksu luotu, asiakas ei ole aloittanut: ei suojaa.
  update public.bookings b
     set status = 'cancelled',
         cancelled_at = now(),
         cancel_reason = 'payment_not_authorized'
   where b.status = 'confirmed'
     and lower(b.during) <= now() + make_interval(hours => v_settings.cancel_unpaid_hours)
     and b.payment_requested_at <= now() - make_interval(mins => v_settings.payment_grace_minutes)
     and exists (select 1 from public.payments p where p.booking_id = b.id)
     and not exists (select 1 from public.payments p
                      where p.booking_id = b.id
                        and (p.status in ('authorized', 'captured')
                             or (p.status = 'requires_action'
                                 and p.updated_at > now() - make_interval(mins => v_settings.payment_grace_minutes))));
  get diagnostics v_cancelled = row_count;

  return v_count + v_cancelled;
end;
$$;

-- Uudet private-funktiot eivät saa suoritusoikeuksia oletuksena (ks. lifecycle_enums),
-- joten erillistä revoke-lohkoa ei tarvita.
