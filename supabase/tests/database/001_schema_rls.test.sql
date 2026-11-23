-- Rakenne ja RLS: jokaisessa public-taulussa on RLS, ja yksityinen data ei vuoda.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(14);

select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  0,
  'jokaisessa public-taulussa on RLS päällä'
);

select ok(
  exists (select 1 from pg_constraint where conname = 'bookings_no_overlap' and contype = 'x'),
  'bookings-taulussa on exclusion constraint'
);

select is(
  (select array_agg(p.proname::text order by p.proname)
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and has_function_privilege('anon', p.oid, 'execute')
      and p.prorettype <> 'trigger'::regtype),
  array['get_available_slots', 'is_i18n_text', 'search_providers', 't'],
  'anon saa suorittaa vain julkiset haut ja tarkistusten apufunktiot'
);

select is(
  (select array_agg(p.proname::text order by p.proname)
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef),
  array['accept_provider_terms', 'add_dispute_message', 'admin_dac7_report', 'admin_resolve_dispute',
        'admin_review_application', 'admin_set_provider_status', 'cancel_booking', 'complete_job',
        'confirm_booking', 'confirm_job_completion', 'extend_hold', 'get_available_slots', 'hold_slot',
        'open_dispute', 'register_booking_photo', 'register_device', 'save_checklist_item', 'search_providers',
        'start_job',
        'submit_provider_application', 'submit_review', 'withdraw_dispute'],
  'public-skeemassa on security definer -funktioina vain tarkoitukselliset RPC:t'
);

select is(
  (select array_agg(p.proname::text order by p.proname)
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private'
      and (has_function_privilege('anon', p.oid, 'execute')
           or has_function_privilege('authenticated', p.oid, 'execute'))),
  array['application_document_count', 'booking_role', 'can_upload_booking_photo', 'is_admin', 'is_provider_member', 'resource_provider', 'try_uuid'],
  'private-skeemassa API-roolit saavat suorittaa vain RLS-politiikoiden apufunktioita'
);

-- Anonyymi käyttäjä
set local role anon;
select set_config('request.jwt.claims', '', true);

select is(
  (select count(*)::int from public.providers where slug = 'esimerkki-pekka'),
  0,
  'hyväksymätön tarjoaja ei näy julkisesti'
);
select ok(
  (select count(*) from public.providers) > 0,
  'aktiiviset tarjoajat näkyvät julkisesti'
);
select throws_ok('select * from public.provider_private', '42501', null, 'provider_private ei ole anonyymin luettavissa');
select throws_ok('select * from public.provider_commission_overrides', '42501', null,
                 'sovitut palkkiot eivät ole anonyymin luettavissa');
select throws_ok('select * from public.availability_rules', '42501', null, 'aukioloajat eivät ole anonyymin luettavissa');
select throws_ok(
  $$ insert into public.bookings (provider_id, resource_id, provider_service_id, service_id, location_type,
                                  customer_id, during, price_cents, hold_expires_at)
     values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 'workshop',
             gen_random_uuid(), tstzrange(now(), now() + interval '1 hour'), 0, now()) $$,
  '42501',
  null,
  'varausta ei voi lisätä suoraan tauluun'
);

reset role;

-- Tarjoajan jäsen näkee vain oman tarjoajansa aukioloajat.
insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000f1', 'owner@example.test');
insert into public.provider_members (provider_id, user_id, role)
select id, '00000000-0000-0000-0000-0000000000f1', 'owner'
  from public.providers where slug = 'esimerkki-autohuolto-jynkka';

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-0000000000f1", "role": "authenticated"}', true);

select ok(
  (select count(*) from public.availability_rules) > 0,
  'jäsen näkee oman tarjoajansa aukioloajat'
);
select is(
  (select count(distinct pr.provider_id)::int
     from public.availability_rules ar
     join public.provider_resources pr on pr.id = ar.resource_id),
  1,
  'jäsen ei näe muiden tarjoajien aukioloaikoja'
);

reset role;

select is(
  (select array_agg(code order by code) from public.published_districts),
  array['petonen'],
  'vain kaupunginosa, jossa on vähintään 3 aktiivista tarjoajaa, julkaistaan'
);

select * from finish();
rollback;
