-- Rivitason tietoturva (RLS).
-- Periaatteet:
--   * Julkinen katalogi (kaupungit, palvelut, aktiiviset tarjoajat ja hinnat) on luettavissa kaikille.
--   * Henkilötiedot näkyvät vain omistajalle, tarjoajan jäsenille ja ylläpidolle.
--   * Varauksiin kirjoitetaan vain RPC-funktioiden kautta (ei INSERT/UPDATE-politiikkoja).
--   * Ylläpitäjä tunnistetaan app_metadata.app_role = 'admin' -claimista (käyttäjä ei voi muuttaa sitä itse).

-- ---------------------------------------------------------------------------
-- Apufunktiot politiikkoja varten
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'app_role') = 'admin', false);
$$;

-- security definer, jotta funktio voi lukea provider_members-taulua ilman rekursiivista RLS:ää.
create or replace function public.is_provider_member(p_provider_id uuid, p_owner_only boolean default false)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.provider_members m
     where m.provider_id = p_provider_id
       and m.user_id = auth.uid()
       and (not p_owner_only or m.role = 'owner')
  );
$$;

create or replace function public.resource_provider(p_resource_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select provider_id from public.provider_resources where id = p_resource_id;
$$;

-- ---------------------------------------------------------------------------
-- RLS päälle kaikkiin tauluihin
-- ---------------------------------------------------------------------------
alter table public.cities enable row level security;
alter table public.city_slugs enable row level security;
alter table public.districts enable row level security;
alter table public.district_slugs enable row level security;
alter table public.postal_codes enable row level security;
alter table public.services enable row level security;
alter table public.profiles enable row level security;
alter table public.vehicles enable row level security;
alter table public.providers enable row level security;
alter table public.provider_private enable row level security;
alter table public.provider_members enable row level security;
alter table public.provider_resources enable row level security;
alter table public.provider_services enable row level security;
alter table public.availability_rules enable row level security;
alter table public.availability_exceptions enable row level security;
alter table public.bookings enable row level security;
alter table public.reviews enable row level security;

-- ---------------------------------------------------------------------------
-- Julkinen katalogi
-- ---------------------------------------------------------------------------
create policy "cities: julkinen luku" on public.cities
  for select to anon, authenticated using (active or public.is_admin());
create policy "city_slugs: julkinen luku" on public.city_slugs
  for select to anon, authenticated using (true);
create policy "districts: julkinen luku" on public.districts
  for select to anon, authenticated using (true);
create policy "district_slugs: julkinen luku" on public.district_slugs
  for select to anon, authenticated using (true);
create policy "postal_codes: julkinen luku" on public.postal_codes
  for select to anon, authenticated using (true);
create policy "services: julkinen luku" on public.services
  for select to anon, authenticated using (active or public.is_admin());

create policy "admin: kaupungit" on public.cities
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admin: palvelut" on public.services
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- Profiilit ja autot
-- ---------------------------------------------------------------------------
create policy "profiles: oma luku" on public.profiles
  for select to authenticated using (id = auth.uid() or public.is_admin());
create policy "profiles: oma päivitys" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy "vehicles: omat" on public.vehicles
  for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Tarjoajat
-- ---------------------------------------------------------------------------
create policy "providers: aktiiviset julkisia" on public.providers
  for select to anon, authenticated
  using (status = 'active' or public.is_provider_member(id) or public.is_admin());
create policy "providers: omistaja päivittää" on public.providers
  for update to authenticated
  using (public.is_provider_member(id, true))
  with check (public.is_provider_member(id, true));
create policy "admin: tarjoajat" on public.providers
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Omistaja saa muuttaa vain sisältösarakkeita; tila, slug ja arvosanat ovat ylläpidon.
revoke update on public.providers from authenticated;
grant update (display_name, description, district_id, location, service_radius_km,
              min_notice_minutes, max_days_ahead)
  on public.providers to authenticated;

create policy "provider_private: jäsenet ja admin" on public.provider_private
  for select to authenticated
  using (public.is_provider_member(provider_id) or public.is_admin());
create policy "provider_private: omistaja päivittää" on public.provider_private
  for update to authenticated
  using (public.is_provider_member(provider_id, true))
  with check (public.is_provider_member(provider_id, true));

create policy "provider_members: oma jäsenyys" on public.provider_members
  for select to authenticated
  using (user_id = auth.uid() or public.is_provider_member(provider_id, true) or public.is_admin());

create policy "provider_resources: julkinen luku" on public.provider_resources
  for select to anon, authenticated using (active or public.is_provider_member(provider_id));
create policy "provider_resources: jäsenet hallitsevat" on public.provider_resources
  for all to authenticated
  using (public.is_provider_member(provider_id))
  with check (public.is_provider_member(provider_id));

create policy "provider_services: julkinen luku" on public.provider_services
  for select to anon, authenticated
  using (
    (active and exists (select 1 from public.providers p where p.id = provider_id and p.status = 'active'))
    or public.is_provider_member(provider_id)
    or public.is_admin()
  );
create policy "provider_services: jäsenet hallitsevat" on public.provider_services
  for all to authenticated
  using (public.is_provider_member(provider_id))
  with check (public.is_provider_member(provider_id));

-- Aukioloajat eivät ole julkisia rivitasolla: vapaat ajat luetaan get_available_slots-funktiolla.
create policy "availability_rules: jäsenet" on public.availability_rules
  for all to authenticated
  using (public.is_provider_member(public.resource_provider(resource_id)))
  with check (public.is_provider_member(public.resource_provider(resource_id)));
create policy "availability_exceptions: jäsenet" on public.availability_exceptions
  for all to authenticated
  using (public.is_provider_member(public.resource_provider(resource_id)))
  with check (public.is_provider_member(public.resource_provider(resource_id)));

-- ---------------------------------------------------------------------------
-- Varaukset: vain luku RLS:llä, kirjoitukset RPC:llä
-- ---------------------------------------------------------------------------
create policy "bookings: asiakas, tarjoaja, admin" on public.bookings
  for select to authenticated
  using (customer_id = auth.uid() or public.is_provider_member(provider_id) or public.is_admin());

revoke insert, update, delete on public.bookings from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Arvostelut
-- ---------------------------------------------------------------------------
create policy "reviews: julkaistut julkisia" on public.reviews
  for select to anon, authenticated
  using (published or author_id = auth.uid() or public.is_admin());

revoke insert, update, delete on public.reviews from anon, authenticated;

-- Apufunktiot eivät ole PostgREST-rajapintaa.
-- resource_provider tarvitaan politiikoissa, joten kirjautuneet saavat suorittaa sen.
revoke execute on function public.resource_provider(uuid) from public, anon;
grant execute on function public.resource_provider(uuid) to authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.refresh_provider_rating() from public, anon, authenticated;
