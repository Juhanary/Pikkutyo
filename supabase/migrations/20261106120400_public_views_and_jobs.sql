-- Julkiset näkymät sivuston SEO-sivuille ja ajastetut työt.
-- Näkymät ovat security_invoker-tilassa, joten ne noudattavat taulujen RLS-politiikkoja.

-- Kaupungin tilastot kaupunkisivun tekstiin: tarjoajien määrä ja halvin hinta paikoittain.
create or replace view public.city_stats
with (security_invoker = true)
as
select c.id as city_id,
       s.code as service_code,
       ps.location_type,
       count(distinct p.id)::integer as provider_count,
       min(ps.price_cents) as min_price_cents,
       round(avg(p.rating_avg), 2) as avg_rating
  from public.cities c
  join public.providers p on p.city_id = c.id and p.status = 'active'
  join public.provider_services ps on ps.provider_id = p.id and ps.active
  join public.services s on s.id = ps.service_id and s.active
 group by c.id, s.code, ps.location_type;

-- Kaupunginosat, joilla on oma sivu: vähintään 3 aktiivista tarjoajaa.
-- Raja on tässä yhdessä paikassa; sivusto ja sitemap lukevat vain tätä näkymää.
create or replace view public.published_districts
with (security_invoker = true)
as
select d.id as district_id,
       d.city_id,
       d.code,
       d.name,
       count(p.id)::integer as provider_count
  from public.districts d
  join public.providers p on p.district_id = d.id and p.status = 'active'
 group by d.id
having count(p.id) >= 3;

grant select on public.city_stats to anon, authenticated;
grant select on public.published_districts to anon, authenticated;

-- Vanhentuneiden pitojen siivous minuutin välein, jos pg_cron on käytettävissä
-- (Supabasessa on; paikallisessa testikannassa ei välttämättä).
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    perform cron.schedule('expire-holds', '* * * * *', 'select public.expire_holds()');
  else
    raise notice 'pg_cron puuttuu: expire-holds-ajastus ohitettu';
  end if;
end;
$$;
