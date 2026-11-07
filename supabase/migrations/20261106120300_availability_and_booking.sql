-- Vapaat ajat ja varauksen elinkaari.
-- Kaikki säännöt ovat täällä, jotta Next.js ja Flutter käyttävät täsmälleen samaa logiikkaa.
-- Virheet nostetaan koodilla P0001 ja koneluettavalla viestillä (esim. 'slot_unavailable'),
-- jonka clientit kääntävät käyttäjälle.

-- ---------------------------------------------------------------------------
-- Sisäiset apufunktiot (eivät näy rajapinnassa)
-- ---------------------------------------------------------------------------

-- Pyöristää ajan ylöspäin seuraavaan askeleeseen (oletus 15 min).
create or replace function public._ceil_to(p_ts timestamptz, p_step interval)
returns timestamptz
language sql
immutable
set search_path = ''
as $$
  select to_timestamp(ceil(extract(epoch from p_ts) / extract(epoch from p_step)) * extract(epoch from p_step));
$$;

-- Resurssin vapaa aika aikavälillä: aukioloajat + lisäajat − suljetut − pidot ja varaukset.
create or replace function public._resource_free(p_resource_id uuid, p_from timestamptz, p_to timestamptz)
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
                   and (b.status = 'confirmed'
                        or (b.status = 'held' and b.hold_expires_at > now()))), '{}'::tstzmultirange)
  ) * tstzmultirange(tstzrange(p_from, p_to));
$$;

-- Resurssin mahdolliset aloitusajat 15 minuutin ruudukossa.
create or replace function public._resource_slots(
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
    from unnest(public._resource_free(p_resource_id, p_from, p_to)) as fr(rng),
         lateral generate_series(public._ceil_to(lower(fr.rng), p_step),
                                 upper(fr.rng) - p_duration,
                                 p_step) as s;
$$;

-- ---------------------------------------------------------------------------
-- Julkiset RPC:t
-- ---------------------------------------------------------------------------

-- Vapaat aloitusajat tarjoajalle, palvelulle ja paikalle. Enintään 31 päivää kerralla.
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
    cross join lateral public._resource_slots(r.id, win.w_from, win.w_to, win.dur) sl
   where win.w_from < win.w_to
   group by sl.slot_start, win.dur
   order by sl.slot_start;
$$;

-- Haku kaupungin (ja valinnaisesti kaupunginosan) tarjoajista.
-- Yksi rivi per tarjoaja ja paikka (korjaamolla / kotipihalla). total_count on rivien
-- ja provider_count erillisten tarjoajien kokonaismäärä ennen sivutusta.
-- Puuttuva sv/en-slug korvautuu suomenkielisellä (kuten sovelluksen slugMap).
create or replace function public.search_providers(
  p_city_slug text,
  p_locale public.locale default 'fi',
  p_service_code text default 'tire_change',
  p_location_type public.location_type default null,
  p_provider_kind public.provider_kind default null,
  p_district_slug text default null,
  p_date date default null,
  p_time_from time default null,
  p_time_to time default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  provider_id uuid,
  slug text,
  display_name text,
  kind public.provider_kind,
  district_name text,
  rating_avg numeric,
  rating_count integer,
  location_type public.location_type,
  price_cents integer,
  travel_fee_cents integer,
  duration_min integer,
  distance_m double precision,
  free_slots integer,
  first_free_at timestamptz,
  total_count bigint,
  provider_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  with city as (
    select c.id, c.timezone
      from public.city_slugs cs
      join public.cities c on c.id = cs.city_id and c.active
     where cs.slug = p_city_slug
       and (cs.locale = p_locale
            or (cs.locale = 'fi'
                and not exists (select 1 from public.city_slugs x
                                 where x.city_id = cs.city_id and x.locale = p_locale)))
     order by (cs.locale = p_locale) desc
     limit 1
  ),
  district as (
    select ds.district_id
      from public.district_slugs ds
      join city on city.id = ds.city_id
     where p_district_slug is not null
       and ds.slug = p_district_slug
       and (ds.locale = p_locale
            or (ds.locale = 'fi'
                and not exists (select 1 from public.district_slugs x
                                 where x.district_id = ds.district_id and x.locale = p_locale)))
  ),
  origin as (
    select case when p_lat is not null and p_lng is not null
                then extensions.st_setsrid(extensions.st_makepoint(p_lng, p_lat), 4326)::extensions.geography
           end as pt
  ),
  candidates as (
    select p.id, p.slug, p.display_name, p.kind, p.district_id, p.rating_avg, p.rating_count,
           p.location, p.service_radius_km,
           ps.location_type, ps.price_cents, ps.travel_fee_cents, ps.duration_min
      from city
      join public.providers p on p.city_id = city.id and p.status = 'active'
      join public.provider_services ps on ps.provider_id = p.id and ps.active
      join public.services s on s.id = ps.service_id and s.code = p_service_code and s.active
     where (p_location_type is null or ps.location_type = p_location_type)
       and (p_provider_kind is null or p.kind = p_provider_kind)
       and (p_district_slug is null or p.district_id in (select district_id from district))
  ),
  located as (
    select c.*,
           case when o.pt is not null then extensions.st_distance(c.location, o.pt) end as dist
      from candidates c
      cross join origin o
     where c.location_type = 'workshop'
        or o.pt is null
        or c.service_radius_km is null
        or extensions.st_dwithin(c.location, o.pt, c.service_radius_km * 1000)
  ),
  -- Vapaat ajat lasketaan enintään 200 ehdokkaalle (järjestys etäisyys, arvosana, hinta).
  -- Laskenta on haun raskain osa ja anon voi kutsua hakua, joten kustannus on rajattu
  -- kutsua kohden riippumatta kaupungin tarjoajamäärästä. Rajan yli jäävät näkyvät
  -- ilman vapaiden aikojen tietoa tulosten lopussa.
  ranked as (
    select l.*,
           row_number() over (order by l.dist asc nulls last, l.rating_avg desc nulls last,
                                       l.price_cents asc, l.id) as rn
      from located l
  ),
  with_slots as (
    select l.*,
           sl.cnt,
           sl.first_at
      from ranked l
      left join lateral (
        select count(*)::integer as cnt, min(g.starts_at) as first_at
          from city,
               public.get_available_slots(l.id, p_service_code, l.location_type, p_date, p_date) g
         -- Ulomman rivin ehdot tässä (eivät ON-ehdossa), jolloin ne ovat kertaehtoja
         -- eikä funktiota kutsuta lainkaan rajan yli jääville.
         where p_date is not null
           and l.rn <= 200
           and (p_time_from is null or (g.starts_at at time zone city.timezone)::time >= p_time_from)
           and (p_time_to is null or (g.starts_at at time zone city.timezone)::time < p_time_to)
      ) sl on p_date is not null
  ),
  providers_total as (
    select count(distinct id) as n from located
  )
  select w.id, w.slug, w.display_name, w.kind,
         public.t(d.name, p_locale),
         w.rating_avg, w.rating_count, w.location_type, w.price_cents, w.travel_fee_cents,
         w.duration_min, w.dist, w.cnt, w.first_at,
         count(*) over (),
         pt.n
    from with_slots w
    cross join providers_total pt
    left join public.districts d on d.id = w.district_id
   order by (coalesce(w.cnt, 0) > 0) desc,
            w.dist asc nulls last,
            w.rating_avg desc nulls last,
            w.price_cents asc,
            w.id
   limit least(greatest(p_limit, 1), 100)
  offset greatest(p_offset, 0);
$$;

-- Pitää ajan 10 minuutiksi. Vaatii kirjautumisen (myös anonyymi kirjautuminen kelpaa).
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

  if (select count(*) from public.bookings
       where customer_id = v_uid and status = 'held' and hold_expires_at > now()) >= 2 then
    raise exception 'too_many_holds' using errcode = 'P0001';
  end if;

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

  -- Vanhentuneet pidot pois tieltä, jotta exclusion constraint ei estä uutta pitoa.
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
        from public._resource_slots(v_resource, p_starts_at, p_starts_at + v_dur, v_dur) s
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
        -- Joku ehti samaan aikaan ensin; kokeillaan seuraavaa resurssia.
        null;
      end;
    end if;
  end loop;

  raise exception 'slot_unavailable' using errcode = 'P0001';
end;
$$;

-- Jatkaa pitoa kerran 10 minuutilla.
create or replace function public.extend_hold(p_booking_id uuid)
returns public.bookings
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
begin
  update public.bookings
     set hold_expires_at = hold_expires_at + interval '10 minutes',
         hold_extended = true
   where id = p_booking_id
     and customer_id = auth.uid()
     and status = 'held'
     and hold_expires_at > now()
     and not hold_extended
  returning * into v_booking;

  if not found then
    raise exception 'hold_not_extendable' using errcode = 'P0001';
  end if;
  return v_booking;
end;
$$;

-- Vahvistaa pidetyn ajan. p_contact: {"name": ..., "email": ..., "phone": ...}
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
         customer_note = nullif(trim(p_note), '')
   where id = p_booking_id
  returning * into v_booking;

  return v_booking;
end;
$$;

-- Peruu pidon tai varauksen. Asiakas tai tarjoajan jäsen, ennen alkamisaikaa.
-- Vaiheessa 2 tähän lisätään peruutusehdot ja maksun vapautus.
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
                       or public.is_provider_member(v_booking.provider_id)) then
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

-- Ajastettu siivous (pg_cron). Vapaiden aikojen laskenta ei ole tästä riippuvainen,
-- koska vanhentuneet pidot ohitetaan jo kyselyssä.
create or replace function public.expire_holds()
returns integer
language sql
volatile
security definer
set search_path = ''
as $$
  with expired as (
    update public.bookings
       set status = 'expired'
     where status = 'held' and hold_expires_at <= now()
    returning 1
  )
  select count(*)::integer from expired;
$$;

-- ---------------------------------------------------------------------------
-- Oikeudet
-- ---------------------------------------------------------------------------
revoke execute on function public._ceil_to(timestamptz, interval) from public, anon, authenticated;
revoke execute on function public._resource_free(uuid, timestamptz, timestamptz) from public, anon, authenticated;
revoke execute on function public._resource_slots(uuid, timestamptz, timestamptz, interval, interval) from public, anon, authenticated;
revoke execute on function public.expire_holds() from public, anon, authenticated;

revoke execute on function public.hold_slot(uuid, text, public.location_type, timestamptz) from public, anon;
revoke execute on function public.extend_hold(uuid) from public, anon;
revoke execute on function public.confirm_booking(uuid, jsonb, text, uuid, text) from public, anon;
revoke execute on function public.cancel_booking(uuid, text) from public, anon;
grant execute on function public.hold_slot(uuid, text, public.location_type, timestamptz) to authenticated;
grant execute on function public.extend_hold(uuid) to authenticated;
grant execute on function public.confirm_booking(uuid, jsonb, text, uuid, text) to authenticated;
grant execute on function public.cancel_booking(uuid, text) to authenticated;

grant execute on function public.get_available_slots(uuid, text, public.location_type, date, date) to anon, authenticated;
grant execute on function public.search_providers(text, public.locale, text, public.location_type, public.provider_kind, text, date, time, time, double precision, double precision, integer, integer) to anon, authenticated;
