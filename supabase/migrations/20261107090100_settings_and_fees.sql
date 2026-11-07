-- Alustan asetukset, palkkiot ja varauksen elinkaaren aikaleimat.

-- ---------------------------------------------------------------------------
-- Alustan asetukset (yksi rivi)
-- ---------------------------------------------------------------------------
create table public.platform_settings (
  id boolean primary key default true check (id),
  -- Palkkio tarjoajalta peruspisteinä: 1000 = 10 %.
  default_commission_bps integer not null default 1000 check (default_commission_bps between 0 and 5000),
  -- Asiakkaan palvelumaksu varausta kohden (pilotissa 0).
  customer_service_fee_cents integer not null default 0 check (customer_service_fee_cents >= 0),
  -- Maksut päälle vasta, kun maksupalvelu on käytössä. Siihen asti varauksia ei peruta maksun puuttuessa.
  payments_enabled boolean not null default false,
  -- Alle näin monen päivän päähän tehty varaus maksetaan (varataan) heti.
  immediate_authorization_days integer not null default 5 check (immediate_authorization_days between 1 and 7),
  -- Kauempana olevassa varauksessa maksu pyydetään näin monta päivää ennen.
  authorization_lead_days integer not null default 2 check (authorization_lead_days between 1 and 6),
  -- Jos maksua ei ole varattu tätä ennen alkua, aika vapautuu.
  cancel_unpaid_hours integer not null default 24 check (cancel_unpaid_hours between 1 and 72),
  -- Asiakkaalla on maksupyynnön jälkeen vähintään näin kauan aikaa ennen kuin varaus perutaan.
  payment_grace_minutes integer not null default 60 check (payment_grace_minutes between 15 and 1440),
  auto_complete_hours integer not null default 24 check (auto_complete_hours between 1 and 168),
  dispute_window_days integer not null default 7 check (dispute_window_days between 1 and 60),
  review_window_days integer not null default 30 check (review_window_days between 1 and 365),
  retorque_reminder_days integer not null default 3 check (retorque_reminder_days between 1 and 30),
  updated_at timestamptz not null default now()
);
insert into public.platform_settings default values;

create trigger platform_settings_updated_at before update on public.platform_settings
  for each row execute function public.set_updated_at();

alter table public.platform_settings enable row level security;
create policy "platform_settings: luku" on public.platform_settings
  for select to anon, authenticated using (true);
create policy "platform_settings: admin" on public.platform_settings
  for update to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
grant select on public.platform_settings to anon, authenticated;
grant update on public.platform_settings to authenticated;

create or replace function private.settings()
returns public.platform_settings
language sql
stable
security definer
set search_path = ''
as $$
  select * from public.platform_settings where id;
$$;

-- ---------------------------------------------------------------------------
-- Tarjoajakohtainen palkkio (esim. 0 % ensimmäisen sesongin ajan)
-- ---------------------------------------------------------------------------
-- Omassa taulussaan, koska providers on julkisesti luettava: sovittu palkkio on
-- liikesalaisuus, jonka näkevät vain tarjoajan omistaja ja ylläpito.
create table public.provider_commission_overrides (
  provider_id uuid primary key references public.providers (id) on delete cascade,
  commission_bps integer not null check (commission_bps between 0 and 5000),
  -- Viimeinen päivä, jona sopimus pätee (null = toistaiseksi).
  valid_until date,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger provider_commission_overrides_updated_at before update on public.provider_commission_overrides
  for each row execute function public.set_updated_at();

alter table public.provider_commission_overrides enable row level security;
create policy "provider_commission_overrides: omistaja ja admin" on public.provider_commission_overrides
  for select to authenticated
  using (private.is_provider_member(provider_id, true) or (select private.is_admin()));
create policy "provider_commission_overrides: admin" on public.provider_commission_overrides
  for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
grant select, insert, update, delete on public.provider_commission_overrides to authenticated;

-- Palkkio, joka pätee tarjoajalle varauksen päivänä.
create or replace function private.effective_commission_bps(p_provider_id uuid, p_on date)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select o.commission_bps
       from public.provider_commission_overrides o
      where o.provider_id = p_provider_id
        and (o.valid_until is null or p_on <= o.valid_until)),
    (private.settings()).default_commission_bps);
$$;

-- ---------------------------------------------------------------------------
-- Varauksen uudet kentät
-- ---------------------------------------------------------------------------
alter table public.bookings
  -- Lukitaan pitohetkellä, kuten hinta. Palkkio on omassa taulussaan (booking_commissions).
  add column service_fee_cents integer not null default 0 check (service_fee_cents >= 0),
  add column customer_total_cents integer generated always as (price_cents + travel_fee_cents + service_fee_cents) stored,
  -- Milloin maksun varaus pyydetään asiakkaalta.
  add column payment_due_at timestamptz,
  add column payment_requested_at timestamptz,
  add column reminder_sent_at timestamptz,
  add column started_at timestamptz,
  add column work_done_at timestamptz,
  add column auto_complete_at timestamptz,
  add column completion_method public.completion_method,
  add column retorque_reminder_at timestamptz,
  add column retorque_reminder_sent_at timestamptz;

-- Varauksen palkkio. Omassa taulussaan, koska asiakas näkee oman varausrivinsä (RLS ja
-- RPC:iden paluuarvot) eikä sovittu palkkio saa näkyä hänelle. Tarjoajan osuus on
-- hinta + matkalisä − palkkio (lasketaan näkymässä payment_settlements).
create table public.booking_commissions (
  booking_id uuid primary key references public.bookings (id) on delete cascade,
  commission_cents integer not null check (commission_cents >= 0),
  created_at timestamptz not null default now()
);
alter table public.booking_commissions enable row level security;
create policy "booking_commissions: tarjoaja ja admin" on public.booking_commissions
  for select to authenticated
  using (
    exists (select 1 from public.bookings b
             where b.id = booking_id and private.is_provider_member(b.provider_id))
    or (select private.is_admin())
  );
-- Kirjoitukset vain hold_slotista (security definer).
grant select on public.booking_commissions to authenticated;

create index bookings_auto_complete_idx on public.bookings (auto_complete_at) where status = 'work_done';
create index bookings_payment_due_idx on public.bookings (payment_due_at) where status = 'confirmed';
create index bookings_start_confirmed_idx on public.bookings (lower(during)) where status = 'confirmed';
create index bookings_retorque_idx on public.bookings (retorque_reminder_at)
  where status = 'completed' and retorque_reminder_sent_at is null;

-- Aika on varattu kaikissa tiloissa paitsi peruttu ja vanhentunut.
alter table public.bookings drop constraint bookings_no_overlap;
alter table public.bookings add constraint bookings_no_overlap exclude using gist (
  resource_id with =,
  during with &&
) where (status not in ('cancelled', 'expired'));

-- Vapaan ajan laskenta samalla säännöllä.
create or replace function private._resource_free(p_resource_id uuid, p_from timestamptz, p_to timestamptz)
returns tstzmultirange
language sql
stable
security definer
set search_path = ''
as $$
  with tz as (
    select c.timezone
      from public.provider_resources r
      join public.providers p on p.id = r.provider_id
      join public.cities c on c.id = p.city_id
     where r.id = p_resource_id
  ),
  days as (
    select g::date as day, tz.timezone
      from tz,
           generate_series((p_from at time zone tz.timezone)::date - 1,
                           (p_to at time zone tz.timezone)::date,
                           interval '1 day') g
  ),
  open_ranges as (
    select tstzrange((d.day + r.start_time) at time zone d.timezone,
                     (d.day + r.end_time) at time zone d.timezone) as rng
      from days d
      join public.availability_rules r
        on r.resource_id = p_resource_id
       and r.weekday = extract(isodow from d.day)
       and (r.valid_from is null or d.day >= r.valid_from)
       and (r.valid_to is null or d.day <= r.valid_to)
    union all
    select e.during
      from public.availability_exceptions e
     where e.resource_id = p_resource_id
       and e.kind = 'open'
       and e.during && tstzrange(p_from, p_to)
  )
  select (
      coalesce((select range_agg(o.rng) from open_ranges o), '{}'::tstzmultirange)
    - coalesce((select range_agg(e.during)
                  from public.availability_exceptions e
                 where e.resource_id = p_resource_id
                   and e.kind = 'closed'
                   and e.during && tstzrange(p_from, p_to)), '{}'::tstzmultirange)
    - coalesce((select range_agg(b.during)
                  from public.bookings b
                 where b.resource_id = p_resource_id
                   and b.during && tstzrange(p_from, p_to)
                   and b.status not in ('cancelled', 'expired')
                   and (b.status <> 'held' or b.hold_expires_at > now())), '{}'::tstzmultirange)
  ) * tstzmultirange(tstzrange(p_from, p_to));
$$;

-- ---------------------------------------------------------------------------
-- Pito lukitsee myös palkkion ja palvelumaksun
-- ---------------------------------------------------------------------------
create or replace function public.hold_slot(
  p_provider_id uuid,
  p_service_code text,
  p_location_type public.location_type,
  p_starts_at timestamptz
)
returns public.bookings
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_ps record;
  v_dur interval;
  v_resource uuid;
  v_settings public.platform_settings := private.settings();
  v_commission integer;
  v_booking public.bookings;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  perform private.assert_hold_limit(v_uid);

  select ps.id, ps.service_id, ps.duration_min, ps.price_cents, ps.travel_fee_cents,
         p.min_notice_minutes, p.max_days_ahead
    into v_ps
    from public.provider_services ps
    join public.services s on s.id = ps.service_id and s.active
    join public.providers p on p.id = ps.provider_id and p.status = 'active'
   where ps.provider_id = p_provider_id
     and s.code = p_service_code
     and ps.location_type = p_location_type
     and ps.active;

  if not found then
    raise exception 'service_not_available' using errcode = 'P0001';
  end if;

  if p_starts_at < now() + make_interval(mins => v_ps.min_notice_minutes)
     or p_starts_at > now() + make_interval(days => v_ps.max_days_ahead) then
    raise exception 'slot_out_of_range' using errcode = 'P0001';
  end if;

  v_dur := make_interval(mins => v_ps.duration_min);
  v_commission := round((v_ps.price_cents + v_ps.travel_fee_cents)
                        * private.effective_commission_bps(p_provider_id, (p_starts_at at time zone 'Europe/Helsinki')::date)
                        / 10000.0);

  update public.bookings
     set status = 'expired'
   where provider_id = p_provider_id
     and status = 'held'
     and hold_expires_at <= now();

  for v_resource in
    select r.id
      from public.provider_resources r
     where r.provider_id = p_provider_id
       and r.active
       and r.location_type = p_location_type
     order by r.created_at, r.id
  loop
    if exists (
      select 1
        from private._resource_slots(v_resource, p_starts_at, p_starts_at + v_dur, v_dur) s
       where s.slot_start = p_starts_at
    ) then
      begin
        insert into public.bookings (
          provider_id, resource_id, provider_service_id, service_id, location_type,
          customer_id, during, status, price_cents, travel_fee_cents,
          service_fee_cents, hold_expires_at
        ) values (
          p_provider_id, v_resource, v_ps.id, v_ps.service_id, p_location_type,
          v_uid, tstzrange(p_starts_at, p_starts_at + v_dur), 'held',
          v_ps.price_cents, v_ps.travel_fee_cents,
          v_settings.customer_service_fee_cents, now() + interval '10 minutes'
        )
        returning * into v_booking;
        insert into public.booking_commissions (booking_id, commission_cents)
        values (v_booking.id, v_commission);
        return v_booking;
      exception when exclusion_violation then
        null;
      end;
    end if;
  end loop;

  raise exception 'slot_unavailable' using errcode = 'P0001';
end;
$$;

-- Vahvistus asettaa myös maksun eräpäivän:
-- lähellä oleva varaus maksetaan heti, kauempana oleva authorization_lead_days ennen.
create or replace function public.confirm_booking(
  p_booking_id uuid,
  p_contact jsonb,
  p_address text default null,
  p_vehicle_id uuid default null,
  p_note text default null
)
returns public.bookings
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
  v_settings public.platform_settings := private.settings();
begin
  select * into v_booking
    from public.bookings
   where id = p_booking_id and customer_id = auth.uid()
   for update;

  if not found then
    raise exception 'booking_not_found' using errcode = 'P0001';
  end if;
  if v_booking.status <> 'held' or v_booking.hold_expires_at <= now() then
    raise exception 'hold_expired' using errcode = 'P0001';
  end if;
  if coalesce(length(trim(p_contact ->> 'name')), 0) = 0
     or (coalesce(length(trim(p_contact ->> 'email')), 0) = 0
         and coalesce(length(trim(p_contact ->> 'phone')), 0) = 0) then
    raise exception 'contact_required' using errcode = 'P0001';
  end if;
  if v_booking.location_type = 'mobile' and coalesce(length(trim(p_address)), 0) = 0 then
    raise exception 'address_required' using errcode = 'P0001';
  end if;
  if p_vehicle_id is not null and not exists (
       select 1 from public.vehicles where id = p_vehicle_id and owner_id = auth.uid()) then
    raise exception 'vehicle_not_found' using errcode = 'P0001';
  end if;

  update public.bookings
     set status = 'confirmed',
         confirmed_at = now(),
         contact = jsonb_strip_nulls(jsonb_build_object(
           'name', trim(p_contact ->> 'name'),
           'email', nullif(trim(p_contact ->> 'email'), ''),
           'phone', nullif(trim(p_contact ->> 'phone'), ''))),
         address = nullif(trim(p_address), ''),
         vehicle_id = p_vehicle_id,
         customer_note = nullif(trim(p_note), ''),
         payment_due_at = case
           when lower(v_booking.during) - now() < make_interval(days => v_settings.immediate_authorization_days)
             then now()
           else lower(v_booking.during) - make_interval(days => v_settings.authorization_lead_days)
         end
   where id = p_booking_id
  returning * into v_booking;

  return v_booking;
end;
$$;

-- Uudet private-funktiot eivät saa suoritusoikeuksia oletuksena (ks. lifecycle_enums).
