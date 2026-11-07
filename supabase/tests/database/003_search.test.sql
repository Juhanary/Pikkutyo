-- Haku: kaupunki, kaupunginosa, paikka, säde ja hyväksymättömät tarjoajat.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(6);

set local role anon;

select ok(
  (select count(*) from public.search_providers('kuopio')) > 0,
  'haku löytää Kuopion tarjoajia'
);

select is(
  (select count(*)::int from public.search_providers('tampere')),
  0,
  'tuntematon kaupunki palauttaa tyhjän tuloksen'
);

select is(
  (select count(*)::int from public.search_providers('kuopio') where slug = 'esimerkki-pekka'),
  0,
  'hyväksymätön tarjoaja ei näy haussa'
);

select is(
  (select array_agg(distinct district_name)
     from public.search_providers('kuopio', p_district_slug => 'petonen')),
  array['Petonen'],
  'kaupunginosasuodatin rajaa tulokset'
);

select ok(
  (select bool_and(location_type = 'mobile')
     from public.search_providers('kuopio', p_location_type => 'mobile')),
  'paikkasuodatin palauttaa vain kotipihapalvelut'
);

-- Aino (Puijonlaakso, säde 5 km) ei ylety Petoselle.
select is(
  (select count(*)::int
     from public.search_providers('kuopio', p_location_type => 'mobile', p_lat => 62.8380, p_lng => 27.6130)
    where slug = 'esimerkki-aino'),
  0,
  'kotipihapalvelu rajataan tarjoajan palvelualueeseen'
);

select * from finish();
rollback;
