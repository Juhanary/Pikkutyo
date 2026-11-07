-- Vaihe 2: palkkio, työn kulku, kuittaus, arvostelu, reklamaatio, maksujen näkyvyys ja tarjoajaksi hakeminen.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(43);

-- ---------------------------------------------------------------------------
-- Valmistelu
-- ---------------------------------------------------------------------------
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'asiakas@example.test'),
  ('00000000-0000-0000-0000-0000000000b1', 'muu@example.test'),
  ('00000000-0000-0000-0000-0000000000c1', 'hakija@example.test'),
  ('00000000-0000-0000-0000-0000000000d1', 'admin@example.test'),
  ('00000000-0000-0000-0000-0000000000e1', 'omistaja@example.test');

create temp table ctx (key text primary key, val text);
grant all on ctx to anon, authenticated;

insert into ctx values
  ('provider', (select id::text from public.providers where slug = 'esimerkki-autohuolto-jynkka')),
  ('monday', ((date_trunc('week', now() at time zone 'Europe/Helsinki'))::date + 7)::text);

insert into public.provider_members (provider_id, user_id, role)
values ((select val from ctx where key = 'provider')::uuid, '00000000-0000-0000-0000-0000000000e1', 'owner');

-- Vahvistettu varaus, joka alkaa tunnin päästä (työn voi aloittaa).
insert into public.bookings (provider_id, resource_id, provider_service_id, service_id, location_type,
                             customer_id, during, status, price_cents, contact, confirmed_at)
select ps.provider_id, r.id, ps.id, ps.service_id, 'workshop',
       '00000000-0000-0000-0000-0000000000a1',
       tstzrange(now() + interval '1 hour', now() + interval '90 minutes'),
       'confirmed', ps.price_cents, '{"name": "Testi", "email": "a@example.test"}', now()
  from public.provider_services ps
  join public.services s on s.id = ps.service_id and s.code = 'tire_change'
  join public.provider_resources r on r.provider_id = ps.provider_id
 where ps.provider_id = (select val from ctx where key = 'provider')::uuid
   and ps.location_type = 'workshop';
insert into ctx values ('job', (select id::text from public.bookings
                                 where customer_id = '00000000-0000-0000-0000-0000000000a1'));
-- Suoraan lisätty varaus: palkkiorivi itse (hold_slot tekee sen normaalisti).
insert into public.booking_commissions (booking_id, commission_cents)
select val::uuid, 0 from ctx where key = 'job';

create function pg_temp.v(k text) returns text language sql as $$ select val from ctx where key = k $$;
create function pg_temp.login(uid text, admin boolean default false) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated',
                      'app_metadata', case when admin then json_build_object('app_role', 'admin') end)::text,
    true);
$$;
grant execute on function pg_temp.v(text), pg_temp.login(text, boolean) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Palkkio lukitaan pidossa
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
insert into ctx
select 'hold1', (public.hold_slot(pg_temp.v('provider')::uuid, 'tire_change', 'workshop',
                 (pg_temp.v('monday')::date + time '10:00')::timestamp at time zone 'Europe/Helsinki')).id::text;
reset role;

select is(
  (select commission_cents from public.booking_commissions where booking_id = pg_temp.v('hold1')::uuid),
  (select round((price_cents + travel_fee_cents) * 0.10)::int from public.bookings where id = pg_temp.v('hold1')::uuid),
  'oletuspalkkio 10 % lukitaan pidossa'
);

-- Asiakas näkee oman varauksensa, mutta ei palkkiota (sopimus tarjoajan ja alustan välillä).
set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
select is((select count(*)::int from public.booking_commissions), 0, 'asiakas ei näe palkkiota');
select pg_temp.login('00000000-0000-0000-0000-0000000000e1');
select ok((select count(*) from public.booking_commissions) > 0, 'tarjoaja näkee varaustensa palkkiot');
reset role;

insert into public.provider_commission_overrides (provider_id, commission_bps)
values (pg_temp.v('provider')::uuid, 0);
set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
insert into ctx
select 'hold2', (public.hold_slot(pg_temp.v('provider')::uuid, 'tire_change', 'workshop',
                 (pg_temp.v('monday')::date + time '11:00')::timestamp at time zone 'Europe/Helsinki')).id::text;
reset role;

select is(
  (select commission_cents from public.booking_commissions where booking_id = pg_temp.v('hold2')::uuid),
  0,
  'tarjoajakohtainen 0 % -palkkio (esim. ensimmäinen sesonki)'
);

set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
select ok(
  (public.confirm_booking(pg_temp.v('hold2')::uuid, '{"name": "Testi", "phone": "0401234567"}')).payment_due_at is not null,
  'vahvistus asettaa maksun eräpäivän'
);

-- ---------------------------------------------------------------------------
-- Työn kulku
-- ---------------------------------------------------------------------------
select throws_ok(
  format('select public.start_job(%L)', pg_temp.v('job')), 'P0001', 'booking_not_found',
  'asiakas ei voi aloittaa työtä'
);

select pg_temp.login('00000000-0000-0000-0000-0000000000e1');
select is((public.start_job(pg_temp.v('job')::uuid)).status::text, 'in_progress', 'tarjoaja aloittaa työn');
reset role;

select ok(
  exists (select 1 from public.outbox_events
           where aggregate_id = pg_temp.v('job')::uuid and type = 'booking.in_progress'),
  'tilamuutos kirjautuu tapahtumajonoon'
);

set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000e1');
select throws_ok(
  format('select public.complete_job(%L)', pg_temp.v('job')), 'P0001', 'checklist_incomplete',
  'työtä ei voi merkitä valmiiksi ilman tarkistuslistaa'
);

select public.save_checklist_item(pg_temp.v('job')::uuid, code, true, '5 mm')
  from (values ('tread_depth'), ('tyre_condition'), ('tyre_pressure'), ('torque'), ('photos_after')) v(code);

select throws_ok(
  format('select public.complete_job(%L)', pg_temp.v('job')), 'P0001', 'checklist_incomplete',
  'kuvaa vaativaan kohtaan tarvitaan kuva'
);

-- Kuva Storageen (tarjoaja saa ladata työn aikana) ja kirjaus varaukseen.
insert into storage.objects (bucket_id, name, owner)
values ('booking-photos', pg_temp.v('job') || '/pyora1.jpg', '00000000-0000-0000-0000-0000000000e1');
select lives_ok(
  format($$ select public.register_booking_photo(%L, %L, 'checklist', 'photos_after') $$,
         pg_temp.v('job'), pg_temp.v('job') || '/pyora1.jpg'),
  'tarjoaja kirjaa kuvan tarkistuslistaan'
);

select is((public.complete_job(pg_temp.v('job')::uuid)).status::text, 'work_done', 'työ valmis, odottaa kuittausta');

-- Ulkopuolinen ei näe tarkistuslistaa eikä voi ladata kuvia varaukseen.
select pg_temp.login('00000000-0000-0000-0000-0000000000b1');
select is((select count(*)::int from public.booking_checklist where booking_id = pg_temp.v('job')::uuid), 0,
          'ulkopuolinen ei näe tarkistuslistaa');
select throws_ok(
  format($$ insert into storage.objects (bucket_id, name) values ('booking-photos', %L) $$, pg_temp.v('job') || '/x.jpg'),
  '42501', null,
  'ulkopuolinen ei voi ladata kuvaa varaukseen'
);

-- ---------------------------------------------------------------------------
-- Reklamaatio pysäyttää automaattisen kuittauksen
-- ---------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
select throws_ok(
  format($$ select public.submit_review(%L, 5::smallint) $$, pg_temp.v('job')), 'P0001', 'review_not_allowed',
  'arvostelua ei voi antaa ennen kuittausta'
);
insert into ctx
select 'dispute1', (public.open_dispute(pg_temp.v('job')::uuid, 'quality', 'Pultit jäivät löysälle.')).id::text;
reset role;

update public.bookings set auto_complete_at = now() - interval '1 minute' where id = pg_temp.v('job')::uuid;
select private.auto_complete_jobs();
select is((select status::text from public.bookings where id = pg_temp.v('job')::uuid), 'disputed',
          'avoin reklamaatio estää automaattisen kuittauksen');

set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
select public.withdraw_dispute(pg_temp.v('dispute1')::uuid);
reset role;
select is((select status::text from public.bookings where id = pg_temp.v('job')::uuid), 'work_done',
          'peruttu reklamaatio palauttaa varauksen tilan');
select is(
  (select array_agg(type order by id)::text from public.outbox_events
    where aggregate_id = pg_temp.v('job')::uuid and type like 'booking.%' and type <> 'booking.in_progress'),
  '{booking.work_done,booking.disputed,booking.dispute_withdrawn}',
  'peruttu reklamaatio ei lähetä booking.work_done-tapahtumaa uudelleen'
);

select private.auto_complete_jobs();
select is(
  (select status::text || '/' || completion_method::text from public.bookings where id = pg_temp.v('job')::uuid),
  'completed/auto',
  'kuittaus tapahtuu automaattisesti määräajan jälkeen'
);

-- ---------------------------------------------------------------------------
-- Arvostelu
-- ---------------------------------------------------------------------------
insert into ctx values ('rating_before', (select rating_count::text from public.providers where id = pg_temp.v('provider')::uuid));
set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
select lives_ok(
  format($$ select public.submit_review(%L, 5::smallint, 'Nopeasti ja siististi.') $$, pg_temp.v('job')),
  'asiakas arvostelee kuitatun työn'
);
select throws_ok(
  format($$ select public.submit_review(%L, 4::smallint) $$, pg_temp.v('job')), 'P0001', 'already_reviewed',
  'samasta varauksesta vain yksi arvostelu'
);
reset role;
select is(
  (select rating_count from public.providers where id = pg_temp.v('provider')::uuid),
  pg_temp.v('rating_before')::int + 1,
  'tarjoajan arvostelumäärä päivittyy'
);

-- ---------------------------------------------------------------------------
-- Kuittauksen jälkeinen reklamaatio ja ylläpidon ratkaisu
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
insert into ctx
select 'dispute2', (public.open_dispute(pg_temp.v('job')::uuid, 'damage', 'Vanteessa naarmu vaihdon jälkeen.')).id::text;

select pg_temp.login('00000000-0000-0000-0000-0000000000d1', true);
select is(
  (public.admin_resolve_dispute(pg_temp.v('dispute2')::uuid, 'resolved_partial_refund', 1000, 'Hyvitys naarmusta')).refund_cents,
  1000,
  'ylläpito ratkaisee osittaisella hyvityksellä'
);
reset role;
select is((select status::text from public.bookings where id = pg_temp.v('job')::uuid), 'completed',
          'kuitattu varaus pysyy kuitattuna');

set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000b1');
select throws_ok(
  format($$ select public.open_dispute(%L, 'quality', 'Ulkopuolisen reklamaatio.') $$, pg_temp.v('job')),
  'P0001', 'booking_not_found',
  'ulkopuolinen ei voi reklamoida eikä saa tietoa varauksesta'
);
reset role;

-- ---------------------------------------------------------------------------
-- Maksujen näkyvyys
-- ---------------------------------------------------------------------------
insert into public.payments (booking_id, external_id, status, amount_cents, captured_at)
values (pg_temp.v('job')::uuid, 'pi_test_1', 'captured', 4700, now());

set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
select is((select count(*)::int from public.payments), 1, 'asiakas näkee oman maksunsa');
select pg_temp.login('00000000-0000-0000-0000-0000000000b1');
select is((select count(*)::int from public.payments), 0, 'ulkopuolinen ei näe maksuja');
reset role;

select is(private.enforce_payment_deadlines(), 0, 'maksujen määräajat eivät peru mitään, kun maksut eivät ole käytössä');

-- Osittainen hyvitys jaetaan suhteessa: 1000 / 4700 maksusta palautetaan, joten tarjoajan
-- osuudesta jää 3700 / 4700 (tämän varauksen palkkio on 0).
insert into public.refunds (payment_id, external_id, amount_cents, status)
select id, 're_test_1', 1000, 'succeeded' from public.payments where external_id = 'pi_test_1';
update public.payments set status = 'partially_refunded' where external_id = 'pi_test_1';
select is(
  (select net_cents from public.provider_earnings where provider_id = pg_temp.v('provider')::uuid),
  (select round((price_cents + travel_fee_cents) * 3700 / 4700.0)::bigint
     from public.bookings where id = pg_temp.v('job')::uuid),
  'hyvitys pienentää tarjoajan tienestejä suhteessa'
);

-- Maksut käytössä: lähellä alkava varaus saa armonajan maksulle.
update public.platform_settings set payments_enabled = true;
update public.bookings
   set during = tstzrange(now() + interval '3 hours', now() + interval '210 minutes'),
       payment_due_at = now(), payment_requested_at = null
 where id = pg_temp.v('hold2')::uuid;
select private.enforce_payment_deadlines();
select is((select status::text from public.bookings where id = pg_temp.v('hold2')::uuid), 'confirmed',
          'varausta ei peruta samalla ajolla, jolla maksu pyydetään');

update public.bookings set payment_requested_at = now() - interval '2 hours' where id = pg_temp.v('hold2')::uuid;
insert into public.payments (booking_id, external_id, status, amount_cents)
values (pg_temp.v('hold2')::uuid, 'pi_test_2', 'requires_action', 4700);
select private.enforce_payment_deadlines();
select is((select status::text from public.bookings where id = pg_temp.v('hold2')::uuid), 'confirmed',
          'kesken oleva maksu (esim. MobilePay) ei peru varausta');

update public.payments set status = 'failed' where external_id = 'pi_test_2';
select private.enforce_payment_deadlines();
select is((select status::text || '/' || cancel_reason from public.bookings where id = pg_temp.v('hold2')::uuid),
          'cancelled/payment_not_authorized',
          'maksamaton varaus perutaan armonajan jälkeen');

-- Maksupyyntö ei mennyt perille (maksuriviä ei syntynyt, esim. tarjoajalta puuttuu maksutili):
-- asiakkaan varausta ei peruta.
update public.bookings
   set status = 'confirmed', cancelled_at = null, cancel_reason = null,
       payment_requested_at = now() - interval '2 hours'
 where id = pg_temp.v('hold1')::uuid;
update public.bookings set during = tstzrange(now() + interval '5 hours', now() + interval '330 minutes')
 where id = pg_temp.v('hold1')::uuid;
select private.enforce_payment_deadlines();
select is((select status::text from public.bookings where id = pg_temp.v('hold1')::uuid), 'confirmed',
          'varausta ei peruta, jos maksupyyntö ei ole mennyt asiakkaalle');

-- Vanheneva maksuvaraus ennen työtä: pyydetään uudelleen.
insert into public.payments (booking_id, external_id, status, amount_cents, authorized_at, authorization_expires_at)
values (pg_temp.v('hold1')::uuid, 'pi_test_3', 'authorized', 4700, now() - interval '6 days', now() + interval '2 hours');
select private.enforce_payment_deadlines();
select ok(
  exists (select 1 from public.outbox_events
           where aggregate_id = pg_temp.v('hold1')::uuid and type = 'payment.reauthorize_due'),
  'vanheneva maksuvaraus ennen työtä pyydetään uudelleen'
);
update public.platform_settings set payments_enabled = false;

-- Jonon tapahtuma, jonka yritykset loppuvat, merkitään epäonnistuneeksi.
insert into ctx
select 'dead', private.enqueue('payment.capture_due', pg_temp.v('hold1')::uuid)::text;
update public.outbox_events set attempts = 10 where id = pg_temp.v('dead')::bigint;
select public.worker_complete_outbox_event(pg_temp.v('dead')::bigint, 'testivirhe');
select ok((select failed_at is not null from public.outbox_events where id = pg_temp.v('dead')::bigint),
          'loppuun yritetty tapahtuma merkitään epäonnistuneeksi');

-- ---------------------------------------------------------------------------
-- Laitteet: sama push-token siirtyy uudelle käyttäjälle
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000a1');
select public.register_device('ios', 'tok-test-1');
select pg_temp.login('00000000-0000-0000-0000-0000000000b1');
select public.register_device('ios', 'tok-test-1');
reset role;
select is(
  (select user_id::text from public.user_devices where push_token = 'tok-test-1'),
  '00000000-0000-0000-0000-0000000000b1',
  'laitteen token siirtyy uudelle kirjautujalle'
);

-- ---------------------------------------------------------------------------
-- Tarjoajaksi hakeminen
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000c1');
insert into public.provider_applications (kind, display_name, city_id, location_types, invoicing_service)
values ('individual', 'Testi Tekijä', (select id from public.cities where code = 'kuopio'), '{mobile}', 'ukko');
insert into ctx values ('app', (select id::text from public.provider_applications));
select throws_ok(
  format('select public.submit_provider_application(%L)', pg_temp.v('app')), 'P0001', 'application_incomplete',
  'hakemusta ei voi lähettää ilman tunnistusta, kurssia ja välinekuvia'
);
select throws_ok(
  format($$ select public.accept_provider_terms(%L, '1') $$, gen_random_uuid()), 'P0001', 'application_not_found',
  'ehtojen hyväksyntä väärälle hakemukselle on virhe, ei hiljainen null'
);
select throws_ok(
  format($$ insert into public.application_documents (application_id, storage_path, kind) values (%L, %L, 'tools') $$,
         pg_temp.v('app'), '00000000-0000-0000-0000-0000000000c1/' || pg_temp.v('app') || '/ei-ladattu.jpg'),
  '42501', null,
  'liitteeksi ei kelpaa polku, jota ei ole ladattu'
);
reset role;

update public.provider_applications
   set identity_provider = 'criipto', identity_subject = 'sub-123', identity_verified_at = now(), is_adult = true,
       course_version = '2027-1', course_completed_at = now(), terms_version = '1', terms_accepted_at = now()
 where id = pg_temp.v('app')::uuid;
insert into public.application_documents (application_id, storage_path, kind)
values (pg_temp.v('app')::uuid, '00000000-0000-0000-0000-0000000000c1/' || pg_temp.v('app') || '/tunkki.jpg', 'tools');

set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000c1');
select throws_ok(
  format('select public.submit_provider_application(%L)', pg_temp.v('app')), 'P0001', 'application_incomplete',
  'hakemusta ei voi lähettää ilman vastuuvakuutusta'
);
reset role;
insert into public.application_documents (application_id, storage_path, kind)
values (pg_temp.v('app')::uuid, '00000000-0000-0000-0000-0000000000c1/' || pg_temp.v('app') || '/vakuutus.pdf', 'insurance');

set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000000c1');
select is((public.submit_provider_application(pg_temp.v('app')::uuid)).status::text, 'submitted', 'hakemus lähetetty');

select pg_temp.login('00000000-0000-0000-0000-0000000000d1', true);
insert into ctx
select 'new_provider', (public.admin_review_application(pg_temp.v('app')::uuid, true)).provider_id::text;
select throws_ok(
  format($$ select public.admin_set_provider_status(%L, 'active') $$, pg_temp.v('new_provider')),
  'P0001', 'provider_not_ready',
  'tarjoajaa ei julkaista ilman palveluita ja aukioloaikoja'
);
reset role;

select is(
  (select p.status::text || '/' || m.role::text
     from public.providers p
     join public.provider_members m on m.provider_id = p.id
    where p.id = pg_temp.v('new_provider')::uuid),
  'pending/owner',
  'hyväksytystä hakemuksesta syntyy odottava tarjoaja ja omistajajäsenyys'
);

select * from finish();
rollback;
