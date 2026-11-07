-- Tapahtumajono (outbox) ja ilmoitukset.
--
-- Tietokanta kirjaa tapahtumat outbox_events-tauluun samassa transaktiossa kuin muutoksen.
-- Edge Function -työntekijä hakee ne public.worker_claim_outbox_events()-funktiolla
-- (FOR UPDATE SKIP LOCKED, joten työntekijöitä voi olla useita) ja
--   * lähettää ilmoitukset (push, sähköposti, SMS) ja kirjaa ne notifications-tauluun,
--   * tekee maksupalvelun toimenpiteet (veloitus, vapautus, hyvitys),
--   * kutsuu sivuston revalidointia.
-- Näin ilmoitus tai veloitus ei katoa, vaikka ulkoinen palvelu olisi hetken alhaalla.

create table public.outbox_events (
  id bigint generated always as identity primary key,
  type text not null check (type ~ '^[a-z_]+\.[a-z_]+$'),
  aggregate_id uuid not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  available_at timestamptz not null default now(),
  attempts integer not null default 0,
  locked_until timestamptz,
  processed_at timestamptz,
  last_error text,
  -- Asetetaan, kun yritykset loppuvat (10): tapahtuma vaatii ihmisen selvitystä.
  failed_at timestamptz
);
create index outbox_events_pending_idx on public.outbox_events (available_at, id) where processed_at is null;
create index outbox_events_aggregate_idx on public.outbox_events (aggregate_id, created_at);
create index outbox_events_failed_idx on public.outbox_events (failed_at) where failed_at is not null;

-- Service_role (Edge Functions) käsittelee jonoa. Ylläpito näkee jonon, jotta
-- epäonnistuneet tapahtumat (failed_at) voi selvittää.
alter table public.outbox_events enable row level security;
create policy "outbox_events: admin luku" on public.outbox_events
  for select to authenticated using ((select private.is_admin()));
grant select on public.outbox_events to authenticated;

create or replace function private.enqueue(p_type text, p_aggregate_id uuid, p_payload jsonb default '{}'::jsonb)
returns bigint
language sql
volatile
security definer
set search_path = ''
as $$
  insert into public.outbox_events (type, aggregate_id, payload)
  values (p_type, p_aggregate_id, coalesce(p_payload, '{}'::jsonb))
  returning id;
$$;

-- Työntekijä (Edge Function, secret-avain → service_role) varaa erän tapahtumia käsittelyyn.
-- Lukko vapautuu itsestään, jos työntekijä kaatuu. Funktiot ovat public-skeemassa, jotta
-- ne ovat kutsuttavissa rajapinnan kautta, mutta suoritusoikeus on vain service_rolella.
-- p_types rajaa tapahtumatyypit: jokainen työntekijä (maksut, ilmoitukset, revalidointi)
-- varaa vain omansa, eikä merkitse muiden tapahtumia käsitellyiksi.
create or replace function public.worker_claim_outbox_events(
  p_limit integer default 50,
  p_lock interval default interval '2 minutes',
  p_types text[] default null
)
returns setof public.outbox_events
language sql
volatile
security invoker
set search_path = ''
as $$
  update public.outbox_events e
     set attempts = e.attempts + 1,
         locked_until = now() + p_lock
   where e.id in (
     select id
       from public.outbox_events
      where processed_at is null
        and available_at <= now()
        and (locked_until is null or locked_until < now())
        and attempts < 10
        and (p_types is null or type = any (p_types))
      order by available_at, id
      limit least(greatest(p_limit, 1), 500)
      for update skip locked
   )
  returning e.*;
$$;

create or replace function public.worker_complete_outbox_event(p_id bigint, p_error text default null)
returns void
language sql
volatile
security invoker
set search_path = ''
as $$
  update public.outbox_events
     set processed_at = case when p_error is null then now() end,
         last_error = p_error,
         failed_at = case when p_error is not null and attempts >= 10 then now() end,
         locked_until = null,
         -- Uusintayritys eksponentiaalisella viiveellä.
         available_at = case when p_error is null then available_at
                             else now() + make_interval(secs => least(3600, 30 * power(2, attempts)::int)) end
   where id = p_id;
$$;

-- Varauksen tilamuutokset jonoon automaattisesti: booking.confirmed, booking.work_done, ...
create or replace function private.on_booking_status_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is distinct from old.status and new.status <> 'expired' then
    perform private.enqueue(
      -- Peruttu reklamaatio palauttaa aiemman tilan. Sen tapahtuma (esim. booking.confirmed)
      -- on jo lähetetty, joten sitä ei lähetetä uudelleen.
      case when old.status = 'disputed' and new.status in ('confirmed', 'in_progress', 'work_done')
           then 'booking.dispute_withdrawn'
           else 'booking.' || new.status::text
      end,
      new.id,
      jsonb_build_object(
        'booking_id', new.id,
        'provider_id', new.provider_id,
        'customer_id', new.customer_id,
        'status', new.status,
        'previous_status', old.status,
        'starts_at', lower(new.during)
      )
    );
  end if;
  return null;
end;
$$;

create trigger bookings_status_outbox
  after update of status on public.bookings
  for each row execute function private.on_booking_status_change();

-- ---------------------------------------------------------------------------
-- Ilmoitukset ja laitteet
-- ---------------------------------------------------------------------------
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  channel public.notification_channel not null,
  template text not null,
  payload jsonb not null default '{}'::jsonb,
  booking_id uuid references public.bookings (id) on delete set null,
  outbox_event_id bigint references public.outbox_events (id) on delete set null,
  status public.notification_status not null default 'pending',
  sent_at timestamptz,
  read_at timestamptz,
  error text,
  created_at timestamptz not null default now(),
  -- Sama tapahtuma ei lähetä samaa ilmoitusta kahdesti, vaikka työntekijä yrittäisi uudelleen.
  unique (outbox_event_id, user_id, channel)
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);
create index notifications_booking_idx on public.notifications (booking_id) where booking_id is not null;

create table public.user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  platform public.device_platform not null,
  push_token text not null unique,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
create index user_devices_user_idx on public.user_devices (user_id);

create table public.notification_preferences (
  user_id uuid primary key references auth.users (id) on delete cascade,
  push boolean not null default true,
  email boolean not null default true,
  sms boolean not null default true,
  marketing boolean not null default false,
  updated_at timestamptz not null default now()
);
create trigger notification_preferences_updated_at before update on public.notification_preferences
  for each row execute function public.set_updated_at();

alter table public.notifications enable row level security;
alter table public.user_devices enable row level security;
alter table public.notification_preferences enable row level security;

create policy "notifications: omat" on public.notifications
  for select to authenticated using (user_id = (select auth.uid()));
-- Käyttäjä saa merkitä omat ilmoituksensa luetuiksi.
create policy "notifications: luettu" on public.notifications
  for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "user_devices: omat" on public.user_devices
  for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create policy "notification_preferences: omat" on public.notification_preferences
  for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

grant select on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;
-- Laitteet rekisteröidään register_device-RPC:llä: sama push-token voi siirtyä toiselle
-- käyttäjälle (uloskirjautuminen ja toinen tili samalla laitteella), mitä RLS ei salli.
grant select, delete on public.user_devices to authenticated;
grant select, insert, update on public.notification_preferences to authenticated;

-- ---------------------------------------------------------------------------
-- Ajastetut muistutukset (pg_cron, ks. 20261107090700_jobs.sql)
-- ---------------------------------------------------------------------------
create or replace function private.enqueue_reminders()
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_count integer := 0;
  v_row record;
begin
  -- Varausmuistutus noin vuorokautta ennen.
  for v_row in
    update public.bookings
       set reminder_sent_at = now()
     where status = 'confirmed'
       and reminder_sent_at is null
       and lower(during) between now() and now() + interval '24 hours'
    returning id, provider_id, customer_id, lower(during) as starts_at
  loop
    perform private.enqueue('booking.reminder', v_row.id,
      jsonb_build_object('booking_id', v_row.id, 'provider_id', v_row.provider_id,
                         'customer_id', v_row.customer_id, 'starts_at', v_row.starts_at));
    v_count := v_count + 1;
  end loop;

  -- Jälkikiristysmuistutus muutaman päivän päästä vaihdosta.
  for v_row in
    update public.bookings
       set retorque_reminder_sent_at = now()
     where status = 'completed'
       and retorque_reminder_sent_at is null
       and retorque_reminder_at <= now()
    returning id, customer_id
  loop
    perform private.enqueue('booking.retorque_reminder', v_row.id,
      jsonb_build_object('booking_id', v_row.id, 'customer_id', v_row.customer_id));
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

create or replace function public.register_device(p_platform public.device_platform, p_push_token text)
returns public.user_devices
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_device public.user_devices;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;
  if coalesce(length(trim(p_push_token)), 0) = 0 then
    raise exception 'invalid_push_token' using errcode = 'P0001';
  end if;

  -- Token kuuluu laitteelle, ei käyttäjälle: viimeksi kirjautunut käyttäjä saa sen.
  insert into public.user_devices (user_id, platform, push_token)
  values (v_uid, p_platform, trim(p_push_token))
  on conflict (push_token) do update
     set user_id = excluded.user_id,
         platform = excluded.platform,
         last_seen_at = now()
  returning * into v_device;
  return v_device;
end;
$$;
grant execute on function public.register_device(public.device_platform, text) to authenticated;

-- Uudet private-funktiot eivät saa suoritusoikeuksia oletuksena (ks. lifecycle_enums).
revoke execute on function public.worker_claim_outbox_events(integer, interval, text[]) from public, anon, authenticated;
revoke execute on function public.worker_complete_outbox_event(bigint, text) from public, anon, authenticated;
grant execute on function public.worker_claim_outbox_events(integer, interval, text[]) to service_role;
grant execute on function public.worker_complete_outbox_event(bigint, text) to service_role;
