-- Laajennukset. Supabasessa laajennukset asennetaan extensions-skeemaan.
create schema if not exists extensions;

create extension if not exists postgis with schema extensions;
-- btree_gist tarvitaan exclusion constraintiin (uuid = ja tstzrange &&).
create extension if not exists btree_gist with schema extensions;
-- pg_net: tietokanta kutsuu Edge Functioneita (maksutyöntekijän ajastus).
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net with schema extensions;
  end if;
end;
$$;
