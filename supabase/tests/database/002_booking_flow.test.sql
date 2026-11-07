-- Vapaat ajat ja varauksen elinkaari. Nojaa Kuopion siemendataan (supabase/seed.sql).
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(19);

-- ---------------------------------------------------------------------------
-- Valmistelu (postgres-roolina)
-- ---------------------------------------------------------------------------
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.test'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.test'),
  ('00000000-0000-0000-0000-00000000000c', 'c@example.test');

create temp table ctx (key text primary key, val text);
grant all on ctx to anon, authenticated;

-- Seuraavan viikon maanantai klo 10 Helsingin aikaa: aina vähintään 3 päivän päässä.
insert into ctx values
  ('monday', ((date_trunc('week', now() at time zone 'Europe/Helsinki'))::date + 7)::text),
  ('one_lift', (select id::text from public.providers where slug = 'esimerkki-autohuolto-jynkka')),
  ('two_lifts', (select id::text from public.providers where slug = 'esimerkki-rengaspiste-keskusta'));
insert into ctx values
  ('slot', ((select val from ctx where key = 'monday')::date + time '10:00')::timestamp
             at time zone 'Europe/Helsinki' || '');

create function pg_temp.v(k text) returns text language sql as $$ select val from ctx where key = k $$;
create function pg_temp.login(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;
-- Uusilla funktioilla ei ole oletuksena PUBLIC-suoritusoikeutta.
grant execute on function pg_temp.v(text), pg_temp.login(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Vapaat ajat
-- ---------------------------------------------------------------------------
select ok(
  exists (select 1 from public.get_available_slots(pg_temp.v('one_lift')::uuid, 'tire_change', 'workshop',
                                                   pg_temp.v('monday')::date, pg_temp.v('monday')::date)
           where starts_at = pg_temp.v('slot')::timestamptz),
  'maanantai klo 10 on vapaana'
);

select is(
  (select count(*)::int from public.get_available_slots(pg_temp.v('one_lift')::uuid, 'tire_change', 'workshop',
                                                        pg_temp.v('monday')::date + 6, pg_temp.v('monday')::date + 6)),
  0,
  'korjaamo on suljettu sunnuntaina'
);

select is(
  (select max(starts_at at time zone 'Europe/Helsinki')::time
     from public.get_available_slots(pg_temp.v('one_lift')::uuid, 'tire_change', 'workshop',
                                     pg_temp.v('monday')::date, pg_temp.v('monday')::date)),
  time '16:30',
  '30 minuutin vaihdon viimeinen aloitus on 16:30, kun ovet sulkeutuvat 17'
);

-- ---------------------------------------------------------------------------
-- Pito ja tuplavarauksen esto
-- ---------------------------------------------------------------------------
set local role anon;
select throws_ok(
  format($$ select public.hold_slot(%L, 'tire_change', 'workshop', %L) $$, pg_temp.v('one_lift'), pg_temp.v('slot')),
  '42501', null,
  'anonyymi rooli ei voi pitää aikaa ilman kirjautumista'
);
reset role;

set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-00000000000a');
insert into ctx
select 'a_booking', (public.hold_slot(pg_temp.v('one_lift')::uuid, 'tire_change', 'workshop', pg_temp.v('slot')::timestamptz)).id::text;

select is(
  (select status::text from public.bookings where id = pg_temp.v('a_booking')::uuid),
  'held',
  'A saa ajan pitoon'
);

select pg_temp.login('00000000-0000-0000-0000-00000000000b');
select throws_ok(
  format($$ select public.hold_slot(%L, 'tire_change', 'workshop', %L) $$, pg_temp.v('one_lift'), pg_temp.v('slot')),
  'P0001', 'slot_unavailable',
  'B ei saa samaa aikaa yhden nostimen korjaamolta'
);

select ok(
  not exists (select 1 from public.get_available_slots(pg_temp.v('one_lift')::uuid, 'tire_change', 'workshop',
                                                       pg_temp.v('monday')::date, pg_temp.v('monday')::date)
               where starts_at = pg_temp.v('slot')::timestamptz),
  'pidetty aika ei näy vapaana'
);

select is(
  (select count(*)::int from public.bookings where id = pg_temp.v('a_booking')::uuid),
  0,
  'B ei näe A:n varausta'
);

select throws_ok(
  format($$ select public.hold_slot(%L, 'tire_change', 'workshop', %L) $$,
         pg_temp.v('one_lift'), (pg_temp.v('slot')::timestamptz + interval '5 minutes')::text),
  'P0001', 'slot_unavailable',
  '15 minuutin ruudukosta poikkeava alkuaika hylätään'
);

-- Kahden nostimen korjaamo: kaksi asiakasta samaan aikaan, kolmas ei mahdu.
select pg_temp.login('00000000-0000-0000-0000-00000000000a');
select lives_ok(
  format($$ select public.hold_slot(%L, 'tire_change', 'workshop', %L) $$, pg_temp.v('two_lifts'), pg_temp.v('slot')),
  'A pitää ajan kahden nostimen korjaamolta'
);
select pg_temp.login('00000000-0000-0000-0000-00000000000b');
select lives_ok(
  format($$ select public.hold_slot(%L, 'tire_change', 'workshop', %L) $$, pg_temp.v('two_lifts'), pg_temp.v('slot')),
  'B saa saman ajan toiselta nostimelta'
);
select pg_temp.login('00000000-0000-0000-0000-00000000000c');
select throws_ok(
  format($$ select public.hold_slot(%L, 'tire_change', 'workshop', %L) $$, pg_temp.v('two_lifts'), pg_temp.v('slot')),
  'P0001', 'slot_unavailable',
  'C ei mahdu, kun molemmat nostimet ovat pidossa'
);

select pg_temp.login('00000000-0000-0000-0000-00000000000a');
select throws_ok(
  format($$ select public.hold_slot(%L, 'tire_change', 'workshop', %L) $$,
         pg_temp.v('two_lifts'), (pg_temp.v('slot')::timestamptz + interval '1 hour')::text),
  'P0001', 'too_many_holds',
  'samalla käyttäjällä voi olla enintään 2 pitoa'
);

-- ---------------------------------------------------------------------------
-- Vahvistus
-- ---------------------------------------------------------------------------
select throws_ok(
  format($$ select public.confirm_booking(%L, '{"name": "Testi"}') $$, pg_temp.v('a_booking')),
  'P0001', 'contact_required',
  'vahvistus vaatii sähköpostin tai puhelinnumeron'
);
select is(
  (public.confirm_booking(pg_temp.v('a_booking')::uuid, '{"name": "Testi Asiakas", "email": "a@example.test"}')).status::text,
  'confirmed',
  'A vahvistaa varauksen'
);
reset role;

select throws_ok(
  format($$ insert into public.bookings (provider_id, resource_id, provider_service_id, service_id, location_type,
                                         customer_id, during, status, price_cents)
            select provider_id, resource_id, provider_service_id, service_id, location_type,
                   '00000000-0000-0000-0000-00000000000b', during, 'confirmed', price_cents
              from public.bookings where id = %L $$, pg_temp.v('a_booking')),
  '23P01', null,
  'tietokanta estää päällekkäisen varauksen myös suoralla kirjoituksella'
);

-- ---------------------------------------------------------------------------
-- Vanhentunut pito vapauttaa ajan
-- ---------------------------------------------------------------------------
update public.bookings
   set hold_expires_at = now() - interval '1 minute'
 where status = 'held' and provider_id = pg_temp.v('two_lifts')::uuid
   and customer_id = '00000000-0000-0000-0000-00000000000b';

select is(
  (select free_resources from public.get_available_slots(pg_temp.v('two_lifts')::uuid, 'tire_change', 'workshop',
                                                         pg_temp.v('monday')::date, pg_temp.v('monday')::date)
    where starts_at = pg_temp.v('slot')::timestamptz),
  1,
  'vanhentunut pito vapauttaa nostimen'
);

-- ---------------------------------------------------------------------------
-- Aikasiirtymä: aukiolo 8:00 paikallista aikaa molemmin puolin seuraavaa siirtymää.
-- Siirtymä lasketaan ajohetkestä (maaliskuun tai lokakuun viimeinen sunnuntai), jotta testi
-- ei vanhene. Odotetut ajat annetaan UTC:nä, jotta ne eivät riipu testattavasta laskennasta.
-- ---------------------------------------------------------------------------
update public.providers set max_days_ahead = 365 where id = pg_temp.v('one_lift')::uuid;

insert into ctx
select kv.k, kv.v
  from (
    select t.s - 2 as fri, t.s + 1 as mon, t.before_h, t.after_h
      from generate_series(extract(year from now())::int, extract(year from now())::int + 1) as y,
           lateral (values
             (make_date(y, 3, 31) - (extract(isodow from make_date(y, 3, 31))::int % 7), 2, 3),
             (make_date(y, 10, 31) - (extract(isodow from make_date(y, 10, 31))::int % 7), 3, 2)
           ) as t(s, before_h, after_h)
     where t.s - 2 > (now() at time zone 'Europe/Helsinki')::date + 1
     order by t.s
     limit 1
  ) nxt,
  lateral (values ('dst_fri', nxt.fri::text), ('dst_mon', nxt.mon::text),
                  ('dst_before_h', nxt.before_h::text), ('dst_after_h', nxt.after_h::text)) as kv(k, v);

select is(
  (select min(starts_at) from public.get_available_slots(pg_temp.v('one_lift')::uuid, 'tire_change', 'workshop',
                                                         pg_temp.v('dst_fri')::date, pg_temp.v('dst_fri')::date)),
  (pg_temp.v('dst_fri')::date + make_interval(hours => 8 - pg_temp.v('dst_before_h')::int)) at time zone 'UTC',
  'perjantaina ennen siirtymää ensimmäinen aika on 8:00 paikallista aikaa'
);
select is(
  (select min(starts_at) from public.get_available_slots(pg_temp.v('one_lift')::uuid, 'tire_change', 'workshop',
                                                         pg_temp.v('dst_mon')::date, pg_temp.v('dst_mon')::date)),
  (pg_temp.v('dst_mon')::date + make_interval(hours => 8 - pg_temp.v('dst_after_h')::int)) at time zone 'UTC',
  'maanantaina siirtymän jälkeen ensimmäinen aika on 8:00 paikallista aikaa'
);

select * from finish();
rollback;
