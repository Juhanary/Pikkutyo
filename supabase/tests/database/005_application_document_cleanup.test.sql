-- Hakemusliitteet Storagessa: lataus vain omaan luonnokseen, poisto vain omasta kirjaamattomasta.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(10);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000005a1', 'hakija5@example.test'),
  ('00000000-0000-0000-0000-0000000005b1', 'muu5@example.test');

create temp table ctx (key text primary key, val text);
grant all on ctx to anon, authenticated;
create function pg_temp.v(k text) returns text language sql as $$ select val from ctx where key = k $$;
create function pg_temp.login(uid text, anon boolean default false) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated', 'is_anonymous', anon)::text, true);
$$;
grant execute on function pg_temp.v(text), pg_temp.login(text, boolean) to anon, authenticated;

insert into public.provider_applications (user_id, kind, display_name, city_id, location_types, invoicing_service)
values ('00000000-0000-0000-0000-0000000005a1', 'individual', 'Testi Viisi',
        (select id from public.cities where code = 'kuopio'), '{mobile}', 'ukko');
insert into ctx values
  ('app', (select id::text from public.provider_applications where user_id = '00000000-0000-0000-0000-0000000005a1')),
  ('own', '00000000-0000-0000-0000-0000000005a1/');
update ctx set val = val || pg_temp.v('app') || '/' where key = 'own';

insert into storage.objects (bucket_id, name) values
  ('application-documents', pg_temp.v('own') || 'orpo.jpg'),
  ('application-documents', pg_temp.v('own') || 'kirjattu.jpg');
insert into public.application_documents (application_id, storage_path, kind)
values (pg_temp.v('app')::uuid, pg_temp.v('own') || 'kirjattu.jpg', 'tools');

-- Storage estää suoran DELETE-kyselyn oletuksena; testissä sallitaan, jotta politiikka testataan.
set local storage.allow_delete_query = 'true';

set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000005b1');
delete from storage.objects where bucket_id = 'application-documents' and name = pg_temp.v('own') || 'orpo.jpg';
select pg_temp.login('00000000-0000-0000-0000-0000000005a1');
delete from storage.objects where bucket_id = 'application-documents' and name = pg_temp.v('own') || 'kirjattu.jpg';
reset role;

select is(
  (select count(*)::int from storage.objects where name = pg_temp.v('own') || 'orpo.jpg'),
  1, 'toinen käyttäjä ei voi poistaa hakijan tiedostoa'
);
select is(
  (select count(*)::int from storage.objects where name = pg_temp.v('own') || 'kirjattu.jpg'),
  1, 'liitteeksi kirjattua tiedostoa ei voi poistaa'
);

set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000005a1');
delete from storage.objects where bucket_id = 'application-documents' and name = pg_temp.v('own') || 'orpo.jpg';
reset role;
select is(
  (select count(*)::int from storage.objects where name = pg_temp.v('own') || 'orpo.jpg'),
  0, 'hakija voi poistaa oman luonnoksensa orvon tiedoston'
);

-- Lataukset: vain oma luonnos, ei anonyymiä istuntoa, ei keksittyä hakemusta.
set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000005a1');
select lives_ok(
  format($q$insert into storage.objects (bucket_id, name) values ('application-documents', %L)$q$,
         pg_temp.v('own') || 'uusi.jpg'),
  'hakija voi ladata oman luonnoksensa kansioon'
);
select throws_ok(
  format($q$insert into storage.objects (bucket_id, name) values ('application-documents', %L)$q$,
         '00000000-0000-0000-0000-0000000005a1/00000000-0000-0000-0000-00000000dead/x.jpg'),
  '42501', null, 'olemattomaan hakemukseen ei voi ladata'
);
select throws_ok(
  format($q$insert into storage.objects (bucket_id, name) values ('application-documents', %L)$q$,
         '00000000-0000-0000-0000-0000000005a1/x/x.jpg'),
  '42501', null, 'kansio ilman hakemustunnusta ei kelpaa'
);
select pg_temp.login('00000000-0000-0000-0000-0000000005a1', true);
select throws_ok(
  format($q$insert into storage.objects (bucket_id, name) values ('application-documents', %L)$q$,
         pg_temp.v('own') || 'anon.jpg'),
  '42501', null, 'anonyymi istunto ei voi ladata'
);
reset role;

-- Lähetetty hakemus: lataus estetty, mutta kirjaamattoman tiedoston saa poistaa.
insert into storage.objects (bucket_id, name) values ('application-documents', pg_temp.v('own') || 'myohassa.jpg');
update public.provider_applications set status = 'submitted', submitted_at = now() where id = pg_temp.v('app')::uuid;
set local role authenticated;
select pg_temp.login('00000000-0000-0000-0000-0000000005a1');
select throws_ok(
  format($q$insert into storage.objects (bucket_id, name) values ('application-documents', %L)$q$,
         pg_temp.v('own') || 'lahetetty.jpg'),
  '42501', null, 'lähetettyyn hakemukseen ei voi ladata'
);
delete from storage.objects where bucket_id = 'application-documents' and name = pg_temp.v('own') || 'myohassa.jpg';
delete from storage.objects where bucket_id = 'application-documents' and name = pg_temp.v('own') || 'kirjattu.jpg';
reset role;
select is(
  (select count(*)::int from storage.objects where name = pg_temp.v('own') || 'myohassa.jpg'),
  0, 'lähetetyn hakemuksen kirjaamattoman tiedoston voi poistaa'
);
select is(
  (select count(*)::int from storage.objects where name = pg_temp.v('own') || 'kirjattu.jpg'),
  1, 'lähetetyn hakemuksen liite säilyy'
);

select * from finish();
rollback;
