-- Tietoturvan kiristys Supabasen tarkistuslistan mukaan.
--   1. Apufunktiot (security definer, triggerit, sisäiset) siirretään private-skeemaan,
--      joka ei näy Data API:ssa. public-skeemaan jäävät vain tarkoitukselliset RPC:t.
--   2. Taulujen oikeudet annetaan eksplisiittisesti eikä luoteta Supabasen oletuksiin
--      (uudet taulut eivät välttämättä ole automaattisesti näkyvissä Data API:ssa).
--   3. RLS-politiikoissa auth.uid() ja apufunktiot kääritään (select ...)-lausekkeeseen,
--      jotta niitä ei arvioida joka riville.
--   4. Puuttuvat vierasavainindeksit.

-- ---------------------------------------------------------------------------
-- 1. private-skeema
-- ---------------------------------------------------------------------------
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated, service_role;

-- Funktiot, joiden runko viittaa vain tauluihin, voidaan siirtää sellaisenaan.
alter function public._ceil_to(timestamptz, interval) set schema private;
alter function public._resource_free(uuid, timestamptz, timestamptz) set schema private;
alter function public.handle_new_user() set schema private;
alter function public.refresh_provider_rating() set schema private;
alter function public.is_admin() set schema private;
alter function public.is_provider_member(uuid, boolean) set schema private;
alter function public.resource_provider(uuid) set schema private;
alter function public.expire_holds() set schema private;

-- _resource_slots viittaa muihin apufunktioihin nimellä, joten se luodaan uudelleen.
drop function public._resource_slots(uuid, timestamptz, timestamptz, interval, interval);

create function private._resource_slots(
  p_resource_id uuid,
  p_from timestamptz,
  p_to timestamptz,
  p_duration interval,
  p_step interval default interval '15 minutes'
)
returns table (slot_start timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select s
    from unnest(private._resource_free(p_resource_id, p_from, p_to)) as fr(rng),
         lateral generate_series(private._ceil_to(lower(fr.rng), p_step),
                                 upper(fr.rng) - p_duration,
                                 p_step) as s;
$$;

-- Politiikoissa käytettävät funktiot: anon ja authenticated tarvitsevat suoritusoikeuden,
-- mutta private-skeema ei ole Data API:ssa, joten niitä ei voi kutsua rajapinnan kautta.
revoke execute on all functions in schema private from public, anon, authenticated;
grant execute on function private.is_admin() to anon, authenticated;
grant execute on function private.is_provider_member(uuid, boolean) to anon, authenticated;
grant execute on function private.resource_provider(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- RPC:t, jotka viittasivat siirrettyihin funktioihin
-- ---------------------------------------------------------------------------

-- Pitojen raja (2 voimassa olevaa per käyttäjä). Yhteinen kaikille hold_slotin
-- versioille, jotta lukko ei katoa, kun funktio kirjoitetaan uudelleen.
-- Lukko sarjoittaa saman käyttäjän kutsut transaktion loppuun asti; laskenta on eri
-- lauseessa kuin lukko, joten se näkee edellisen kutsun sitoutuneen pidon.
create function private.assert_hold_limit(p_uid uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('hold_slot:' || p_uid::text, 0));
  if (select count(*) from public.bookings
       where customer_id = p_uid and status = 'held' and hold_expires_at > now()) >= 2 then
    raise exception 'too_many_holds' using errcode = 'P0001';
  end if;
end;
$$;
revoke execute on function private.assert_hold_limit(uuid) from public, anon, authenticated;

create or replace function public.get_available_slots(
  p_provider_id uuid,
  p_service_code text,
  p_location_type public.location_type,
  p_from date,
  p_to date
)
returns table (starts_at timestamptz, ends_at timestamptz, free_resources integer)
language sql
stable
security definer
set search_path = ''
as $$
  with ps as (
    select ps.duration_min, p.min_notice_minutes, p.max_days_ahead, c.timezone
      from public.provider_services ps
      join public.services s on s.id = ps.service_id and s.active
      join public.providers p on p.id = ps.provider_id and p.status = 'active'
      join public.cities c on c.id = p.city_id
     where ps.provider_id = p_provider_id
       and s.code = p_service_code
       and ps.location_type = p_location_type
       and ps.active
       and p_to >= p_from
       and p_to - p_from < 31  -- enintään 31 päivää (päivät mukaan lukien)
  ),
  win as (
    select greatest(p_from::timestamp at time zone ps.timezone,
                    now() + make_interval(mins => ps.min_notice_minutes)) as w_from,
           least((p_to + 1)::timestamp at time zone ps.timezone,
                 now() + make_interval(days => ps.max_days_ahead)) as w_to,
           make_interval(mins => ps.duration_min) as dur
      from ps
  )
  select sl.slot_start, sl.slot_start + win.dur, count(*)::integer
    from win
    join public.provider_resources r
      on r.provider_id = p_provider_id
     and r.active
     and r.location_type = p_location_type
    cross join lateral private._resource_slots(r.id, win.w_from, win.w_to, win.dur) sl
   where win.w_from < win.w_to
   group by sl.slot_start, win.dur
   order by sl.slot_start;
$$;

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
          customer_id, during, status, price_cents, travel_fee_cents, hold_expires_at
        ) values (
          p_provider_id, v_resource, v_ps.id, v_ps.service_id, p_location_type,
          v_uid, tstzrange(p_starts_at, p_starts_at + v_dur), 'held',
          v_ps.price_cents, v_ps.travel_fee_cents, now() + interval '10 minutes'
        )
        returning * into v_booking;
        return v_booking;
      exception when exclusion_violation then
        null;
      end;
    end if;
  end loop;

  raise exception 'slot_unavailable' using errcode = 'P0001';
end;
$$;

create or replace function public.cancel_booking(p_booking_id uuid, p_reason text default null)
returns public.bookings
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
begin
  select * into v_booking from public.bookings where id = p_booking_id for update;

  if not found or not (v_booking.customer_id = auth.uid()
                       or private.is_provider_member(v_booking.provider_id)) then
    raise exception 'booking_not_found' using errcode = 'P0001';
  end if;
  if v_booking.status not in ('held', 'confirmed') or lower(v_booking.during) <= now() then
    raise exception 'not_cancellable' using errcode = 'P0001';
  end if;

  update public.bookings
     set status = 'cancelled',
         cancelled_at = now(),
         cancel_reason = nullif(trim(p_reason), '')
   where id = p_booking_id
  returning * into v_booking;

  return v_booking;
end;
$$;

-- pg_cron-ajastus osoittamaan siirrettyyn funktioon.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('expire-holds', '* * * * *', 'select private.expire_holds()');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Eksplisiittiset oikeudet
-- ---------------------------------------------------------------------------
-- Tulevat taulut ja funktiot eivät saa oikeuksia automaattisesti: jokainen
-- rajapintaan tarkoitettu objekti saa oman GRANT-lauseensa migraatiossa.
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;

revoke all on all tables in schema public from anon, authenticated;

-- Julkinen katalogi
grant select on public.cities, public.city_slugs, public.districts, public.district_slugs,
                public.postal_codes, public.services, public.providers,
                public.provider_resources, public.provider_services, public.reviews,
                public.city_stats, public.published_districts
  to anon, authenticated;

-- Omat tiedot
grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.vehicles to authenticated;
grant select on public.bookings to authenticated;

-- Tarjoajan jäsenet (RLS rajaa omaan tarjoajaan)
grant update (display_name, description, district_id, location, service_radius_km,
              min_notice_minutes, max_days_ahead)
  on public.providers to authenticated;
grant select, update on public.provider_private to authenticated;
grant select on public.provider_members to authenticated;
grant insert, update, delete on public.provider_resources, public.provider_services to authenticated;
grant select, insert, update, delete on public.availability_rules,
                                        public.availability_exceptions to authenticated;

-- Ylläpito (RLS sallii vain app_metadata.app_role = 'admin'). Tarjoajien päivitys pysyy
-- yllä sarakerajattuna, jotta omistajat eivät voi muuttaa tilaa tai slugia; ne tehdään
-- service_rolella.
grant insert, update, delete on public.cities, public.services to authenticated;
grant insert, delete on public.providers to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Politiikat uudelleen tehokkaassa muodossa
-- ---------------------------------------------------------------------------
do $$
declare
  pol record;
begin
  for pol in select policyname, tablename from pg_policies where schemaname = 'public' loop
    execute format('drop policy %I on public.%I', pol.policyname, pol.tablename);
  end loop;
end;
$$;

-- Julkinen katalogi
create policy "cities: luku" on public.cities
  for select to anon, authenticated using (active or (select private.is_admin()));
create policy "cities: admin" on public.cities
  for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "city_slugs: luku" on public.city_slugs
  for select to anon, authenticated using (true);
create policy "districts: luku" on public.districts
  for select to anon, authenticated using (true);
create policy "district_slugs: luku" on public.district_slugs
  for select to anon, authenticated using (true);
create policy "postal_codes: luku" on public.postal_codes
  for select to anon, authenticated using (true);
create policy "services: luku" on public.services
  for select to anon, authenticated using (active or (select private.is_admin()));
create policy "services: admin" on public.services
  for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));

-- Profiilit ja autot
create policy "profiles: oma luku" on public.profiles
  for select to authenticated using (id = (select auth.uid()) or (select private.is_admin()));
create policy "profiles: oma päivitys" on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy "vehicles: omat" on public.vehicles
  for all to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));

-- Tarjoajat
create policy "providers: luku" on public.providers
  for select to anon, authenticated
  using (status = 'active' or private.is_provider_member(id) or (select private.is_admin()));
create policy "providers: omistaja päivittää" on public.providers
  for update to authenticated
  using (private.is_provider_member(id, true))
  with check (private.is_provider_member(id, true));
create policy "providers: admin" on public.providers
  for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));

create policy "provider_private: luku" on public.provider_private
  for select to authenticated
  using (private.is_provider_member(provider_id) or (select private.is_admin()));
create policy "provider_private: omistaja päivittää" on public.provider_private
  for update to authenticated
  using (private.is_provider_member(provider_id, true))
  with check (private.is_provider_member(provider_id, true));

create policy "provider_members: luku" on public.provider_members
  for select to authenticated
  using (user_id = (select auth.uid())
         or private.is_provider_member(provider_id, true)
         or (select private.is_admin()));

create policy "provider_resources: luku" on public.provider_resources
  for select to anon, authenticated using (active or private.is_provider_member(provider_id));
create policy "provider_resources: jäsenet lisäävät" on public.provider_resources
  for insert to authenticated with check (private.is_provider_member(provider_id));
create policy "provider_resources: jäsenet muokkaavat" on public.provider_resources
  for update to authenticated
  using (private.is_provider_member(provider_id)) with check (private.is_provider_member(provider_id));
create policy "provider_resources: jäsenet poistavat" on public.provider_resources
  for delete to authenticated using (private.is_provider_member(provider_id));

create policy "provider_services: luku" on public.provider_services
  for select to anon, authenticated
  using (
    (active and exists (select 1 from public.providers p where p.id = provider_id and p.status = 'active'))
    or private.is_provider_member(provider_id)
    or (select private.is_admin())
  );
create policy "provider_services: jäsenet lisäävät" on public.provider_services
  for insert to authenticated with check (private.is_provider_member(provider_id));
create policy "provider_services: jäsenet muokkaavat" on public.provider_services
  for update to authenticated
  using (private.is_provider_member(provider_id)) with check (private.is_provider_member(provider_id));
create policy "provider_services: jäsenet poistavat" on public.provider_services
  for delete to authenticated using (private.is_provider_member(provider_id));

create policy "availability_rules: jäsenet" on public.availability_rules
  for all to authenticated
  using (private.is_provider_member(private.resource_provider(resource_id)))
  with check (private.is_provider_member(private.resource_provider(resource_id)));
create policy "availability_exceptions: jäsenet" on public.availability_exceptions
  for all to authenticated
  using (private.is_provider_member(private.resource_provider(resource_id)))
  with check (private.is_provider_member(private.resource_provider(resource_id)));

-- Varaukset (kirjoitukset vain RPC:llä)
create policy "bookings: luku" on public.bookings
  for select to authenticated
  using (customer_id = (select auth.uid())
         or private.is_provider_member(provider_id)
         or (select private.is_admin()));

-- Arvostelut
create policy "reviews: luku" on public.reviews
  for select to anon, authenticated
  using (published or author_id = (select auth.uid()) or (select private.is_admin()));

-- ---------------------------------------------------------------------------
-- 4. Vierasavainindeksit
-- ---------------------------------------------------------------------------
create index if not exists bookings_provider_service_idx on public.bookings (provider_service_id);
create index if not exists bookings_service_idx on public.bookings (service_id);
create index if not exists bookings_vehicle_idx on public.bookings (vehicle_id) where vehicle_id is not null;
create index if not exists provider_services_service_idx on public.provider_services (service_id);
create index if not exists providers_district_all_idx on public.providers (district_id);
create index if not exists postal_codes_district_idx on public.postal_codes (district_id);
create index if not exists reviews_author_idx on public.reviews (author_id);
create index if not exists provider_resources_provider_all_idx on public.provider_resources (provider_id);
