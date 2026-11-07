-- Tarjoajaksi rekisteröityminen, tunnistus, kurssi, laskutuspalvelu, ylläpidon hyväksyntä
-- ja DAC7-raportoinnin tiedot.
--
-- Kulku: käyttäjä luo hakemuksen (draft) → täyttää tiedot, lataa välinekuvat, suorittaa
-- kurssin ja vahvan tunnistautumisen → lähettää (submitted) → ylläpito hyväksyy, jolloin
-- syntyy tarjoaja (status pending), omistajajäsenyys ja yksityistiedot. Tarjoaja julkaistaan
-- (active), kun palvelut ja aukioloajat on asetettu.

create type public.invoicing_service as enum ('none', 'ukko', 'eezy', 'other');

create table public.provider_applications (
  id uuid primary key default gen_random_uuid(),
  -- Oletusarvo kirjautunut käyttäjä: sovellus ei voi asettaa sitä itse (ei INSERT-oikeutta sarakkeeseen).
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  kind public.provider_kind not null,
  status public.application_status not null default 'draft',
  display_name text not null check (length(display_name) between 2 and 80),
  business_id text check (business_id is null or business_id ~ '^[0-9]{7}-[0-9]$'),
  city_id uuid not null references public.cities (id),
  district_id uuid references public.districts (id) on delete set null,
  location_types public.location_type[] not null default '{}',
  description text check (description is null or length(description) <= 2000),
  tools_description text check (tools_description is null or length(tools_description) <= 2000),
  contact_email text,
  contact_phone text,
  -- Vahva tunnistus (Signicat/Criipto) kirjataan Edge Functionista. Henkilötunnusta ei tallenneta
  -- tähän: vain välittäjän pseudonyymi tunniste ja täysi-ikäisyys.
  identity_provider text check (identity_provider is null or identity_provider in ('signicat', 'criipto')),
  identity_subject text,
  identity_verified_at timestamptz,
  is_adult boolean,
  course_version text,
  course_completed_at timestamptz,
  invoicing_service public.invoicing_service not null default 'none',
  invoicing_reference text,
  terms_version text,
  terms_accepted_at timestamptz,
  rejection_reason text,
  reviewed_by uuid references auth.users (id),
  reviewed_at timestamptz,
  provider_id uuid references public.providers (id) on delete set null,
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (kind = 'individual' or business_id is not null or status = 'draft'),
  check (status <> 'approved' or provider_id is not null)
);
-- Käyttäjällä yksi keskeneräinen hakemus kerrallaan.
create unique index provider_applications_one_open on public.provider_applications (user_id)
  where status in ('draft', 'submitted', 'in_review');
create index provider_applications_user_idx on public.provider_applications (user_id);
create index provider_applications_queue_idx on public.provider_applications (status, submitted_at)
  where status in ('submitted', 'in_review');
create index provider_applications_city_idx on public.provider_applications (city_id);
create index provider_applications_district_idx on public.provider_applications (district_id);
create index provider_applications_provider_idx on public.provider_applications (provider_id);
create index provider_applications_reviewed_by_idx on public.provider_applications (reviewed_by);
create trigger provider_applications_updated_at before update on public.provider_applications
  for each row execute function public.set_updated_at();

-- Liitteet Storagessa: bucket application-documents, polku <user_id>/<application_id>/<tiedosto>.
create table public.application_documents (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.provider_applications (id) on delete cascade,
  storage_path text not null unique,
  kind text not null check (kind in ('tools', 'insurance', 'other')),
  created_at timestamptz not null default now()
);
create index application_documents_application_idx on public.application_documents (application_id);

-- DAC7: alustan on raportoitava myyjien tiedot ja tulot Verohallinnolle vuosittain.
-- Arkaluonteinen: vain tarjoajan omistaja ja ylläpito näkevät.
create table public.provider_tax_info (
  provider_id uuid primary key references public.providers (id) on delete cascade,
  legal_name text not null,
  tax_id text,                 -- henkilötunnus tai Y-tunnus (TIN)
  vat_number text,
  birth_date date,
  street_address text,
  postal_code text,
  city text,
  country char(2) not null default 'FI',
  updated_at timestamptz not null default now()
);
create trigger provider_tax_info_updated_at before update on public.provider_tax_info
  for each row execute function public.set_updated_at();

alter table public.provider_applications enable row level security;
alter table public.application_documents enable row level security;
alter table public.provider_tax_info enable row level security;

create policy "provider_applications: oma luku" on public.provider_applications
  for select to authenticated using (user_id = (select auth.uid()) or (select private.is_admin()));
create policy "provider_applications: oma luonnos" on public.provider_applications
  for insert to authenticated with check (user_id = (select auth.uid()) and status = 'draft');
create policy "provider_applications: oman luonnoksen muokkaus" on public.provider_applications
  for update to authenticated
  using (user_id = (select auth.uid()) and status = 'draft')
  with check (user_id = (select auth.uid()) and status = 'draft');

create policy "application_documents: oma tai admin" on public.application_documents
  for select to authenticated
  using (exists (select 1 from public.provider_applications a
                  where a.id = application_id
                    and (a.user_id = (select auth.uid()) or (select private.is_admin()))));
-- Polun on oltava hakijan oma <user_id>/<application_id>/... ja tiedoston on oltava jo
-- ladattu, jotta keksitty tai toisen käyttäjän polku ei kelpaa liitteeksi.
create policy "application_documents: oma luonnos" on public.application_documents
  for insert to authenticated
  with check (
    exists (select 1 from public.provider_applications a
             where a.id = application_id and a.user_id = (select auth.uid()) and a.status = 'draft')
    and storage_path like (select auth.uid())::text || '/' || application_id::text || '/_%'
    and exists (select 1 from storage.objects o
                 where o.bucket_id = 'application-documents' and o.name = storage_path)
  );
create policy "application_documents: poisto luonnoksesta" on public.application_documents
  for delete to authenticated
  using (exists (select 1 from public.provider_applications a
                  where a.id = application_id and a.user_id = (select auth.uid()) and a.status = 'draft'));

create policy "provider_tax_info: omistaja ja admin" on public.provider_tax_info
  for select to authenticated
  using (private.is_provider_member(provider_id, true) or (select private.is_admin()));
create policy "provider_tax_info: omistaja päivittää" on public.provider_tax_info
  for all to authenticated
  using (private.is_provider_member(provider_id, true))
  with check (private.is_provider_member(provider_id, true));

-- Käyttäjä muokkaa vain sisältökenttiä; tunnistus, kurssi, tila ja tarkastus kirjataan muualla.
grant select on public.provider_applications to authenticated;
grant insert (kind, display_name, business_id, city_id, district_id, location_types, description,
              tools_description, contact_email, contact_phone, invoicing_service, invoicing_reference)
  on public.provider_applications to authenticated;
grant update (kind, display_name, business_id, city_id, district_id, location_types, description,
              tools_description, contact_email, contact_phone, invoicing_service, invoicing_reference)
  on public.provider_applications to authenticated;
grant select, insert, delete on public.application_documents to authenticated;
grant select, insert, update on public.provider_tax_info to authenticated;

-- ---------------------------------------------------------------------------
-- Storage: application-documents (yksityinen)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('application-documents', 'application-documents', false, 10 * 1024 * 1024,
        array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf'])
on conflict (id) do nothing;

create policy "application-documents: oma tai admin luku" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'application-documents'
    and ((storage.foldername(name))[1] = (select auth.uid())::text or (select private.is_admin()))
  );
create policy "application-documents: oma lataus" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'application-documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- ---------------------------------------------------------------------------
-- RPC:t
-- ---------------------------------------------------------------------------
create or replace function public.accept_provider_terms(p_application_id uuid, p_terms_version text)
returns public.provider_applications
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_app public.provider_applications;
begin
  if coalesce(length(trim(p_terms_version)), 0) = 0 then
    raise exception 'terms_version_required' using errcode = 'P0001';
  end if;
  update public.provider_applications
     set terms_version = trim(p_terms_version), terms_accepted_at = now()
   where id = p_application_id and user_id = auth.uid() and status = 'draft'
  returning * into v_app;
  -- Ilman tätä väärä id tai jo lähetetty hakemus palauttaisi null "onnistuneena".
  if not found then
    raise exception 'application_not_found' using errcode = 'P0001';
  end if;
  return v_app;
end;
$$;

create or replace function public.submit_provider_application(p_application_id uuid)
returns public.provider_applications
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_app public.provider_applications;
  v_missing text[] := '{}';
begin
  select * into v_app from public.provider_applications
   where id = p_application_id and user_id = auth.uid() and status = 'draft'
   for update;
  if not found then
    raise exception 'application_not_found' using errcode = 'P0001';
  end if;

  if cardinality(v_app.location_types) = 0 then v_missing := array_append(v_missing, 'location_types'); end if;
  if v_app.identity_verified_at is null then v_missing := array_append(v_missing, 'identity'); end if;
  if v_app.is_adult is not true then v_missing := array_append(v_missing, 'adult'); end if;
  if v_app.course_completed_at is null then v_missing := array_append(v_missing, 'course'); end if;
  if v_app.terms_accepted_at is null then v_missing := array_append(v_missing, 'terms'); end if;
  if v_app.kind = 'company' and v_app.business_id is null then v_missing := array_append(v_missing, 'business_id'); end if;
  if v_app.kind = 'individual' and v_app.invoicing_service = 'none' then
    v_missing := array_append(v_missing, 'invoicing_service');
  end if;
  if not exists (select 1 from public.application_documents d
                  where d.application_id = p_application_id and d.kind = 'tools') then
    v_missing := array_append(v_missing, 'tools_photos');
  end if;
  -- Vastuuvakuutus on pakollinen: alusta voi hyvittää enintään työn hinnan, joten
  -- isommat vahingot (esim. vanne tai auto) korvataan tekijän vakuutuksesta.
  if not exists (select 1 from public.application_documents d
                  where d.application_id = p_application_id and d.kind = 'insurance') then
    v_missing := array_append(v_missing, 'insurance');
  end if;
  if cardinality(v_missing) > 0 then
    raise exception 'application_incomplete' using errcode = 'P0001', detail = array_to_string(v_missing, ',');
  end if;

  update public.provider_applications
     set status = 'submitted', submitted_at = now()
   where id = p_application_id
  returning * into v_app;

  perform private.enqueue('provider_application.submitted', v_app.id,
                          jsonb_build_object('application_id', v_app.id));
  return v_app;
end;
$$;

create or replace function private.slugify(p_text text)
returns text
language sql
immutable
set search_path = ''
as $$
  select trim(both '-' from regexp_replace(
           translate(lower(p_text), 'åäöéèüß', 'aaoeeus'),
           '[^a-z0-9]+', '-', 'g'));
$$;

create or replace function public.admin_review_application(
  p_application_id uuid,
  p_approve boolean,
  p_reason text default null
)
returns public.provider_applications
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_app public.provider_applications;
  v_slug text;
  v_base text;
  v_n integer := 1;
  v_provider_id uuid;
  v_location extensions.geography;
begin
  if not private.is_admin() then
    raise exception 'forbidden' using errcode = 'P0001';
  end if;
  select * into v_app from public.provider_applications
   where id = p_application_id and status in ('submitted', 'in_review')
   for update;
  if not found then
    raise exception 'application_not_found' using errcode = 'P0001';
  end if;

  if not p_approve then
    if coalesce(length(trim(p_reason)), 0) = 0 then
      raise exception 'reason_required' using errcode = 'P0001';
    end if;
    update public.provider_applications
       set status = 'rejected', rejection_reason = trim(p_reason), reviewed_by = auth.uid(), reviewed_at = now()
     where id = p_application_id
    returning * into v_app;
    perform private.enqueue('provider_application.rejected', v_app.id,
                            jsonb_build_object('application_id', v_app.id, 'user_id', v_app.user_id));
    return v_app;
  end if;

  v_base := coalesce(nullif(private.slugify(v_app.display_name), ''), 'tarjoaja');
  v_slug := v_base;
  while exists (select 1 from public.providers where slug = v_slug) loop
    v_n := v_n + 1;
    v_slug := v_base || '-' || v_n;
  end loop;

  -- Julkinen sijainti: kaupunginosan tai kaupungin keskipiste (tarkka osoite on yksityinen).
  select coalesce(d.center, c.center) into v_location
    from public.cities c
    left join public.districts d on d.id = v_app.district_id
   where c.id = v_app.city_id;

  insert into public.providers (slug, kind, status, display_name, description, city_id, district_id, location)
  values (v_slug, v_app.kind, 'pending', v_app.display_name,
          case when v_app.description is not null then jsonb_build_object('fi', v_app.description) end,
          v_app.city_id, v_app.district_id, v_location)
  returning id into v_provider_id;

  insert into public.provider_members (provider_id, user_id, role) values (v_provider_id, v_app.user_id, 'owner');
  insert into public.provider_private (provider_id, business_id, contact_email, contact_phone)
  values (v_provider_id, v_app.business_id, v_app.contact_email, v_app.contact_phone);

  update public.provider_applications
     set status = 'approved', provider_id = v_provider_id, reviewed_by = auth.uid(), reviewed_at = now()
   where id = p_application_id
  returning * into v_app;

  perform private.enqueue('provider_application.approved', v_app.id,
    jsonb_build_object('application_id', v_app.id, 'user_id', v_app.user_id, 'provider_id', v_provider_id));
  return v_app;
end;
$$;

-- Ylläpito julkaisee, keskeyttää tai palauttaa tarjoajan. Julkaisu vaatii palvelut ja aukioloajat.
create or replace function public.admin_set_provider_status(p_provider_id uuid, p_status public.provider_status)
returns public.providers
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_provider public.providers;
begin
  if not private.is_admin() then
    raise exception 'forbidden' using errcode = 'P0001';
  end if;
  if p_status = 'active' and not (
       exists (select 1 from public.provider_services where provider_id = p_provider_id and active)
       and exists (select 1 from public.availability_rules ar
                     join public.provider_resources r on r.id = ar.resource_id
                    where r.provider_id = p_provider_id and r.active)) then
    raise exception 'provider_not_ready' using errcode = 'P0001';
  end if;
  -- Kun maksut ovat käytössä, tarjoaja tarvitsee maksutilin: muuten asiakkaalta ei voi
  -- pyytää maksua ja varaus jäisi jumiin.
  if p_status = 'active' and (private.settings()).payments_enabled and not exists (
       select 1 from public.provider_payout_accounts
        where provider_id = p_provider_id and charges_enabled) then
    raise exception 'payout_account_missing' using errcode = 'P0001';
  end if;

  update public.providers
     set status = p_status,
         published_at = case when p_status = 'active' then coalesce(published_at, now()) else published_at end
   where id = p_provider_id
  returning * into v_provider;
  if not found then
    raise exception 'provider_not_found' using errcode = 'P0001';
  end if;

  perform private.enqueue('provider.changed', p_provider_id,
                          jsonb_build_object('provider_id', p_provider_id, 'status', p_status));
  return v_provider;
end;
$$;

-- DAC7-vuosiraportti: myyjän tiedot, vastikkeet ja palkkiot neljännesvuosittain.
-- Vastike ja palkkio hyvitysten jälkeen (payment_settlements, suhteellinen jako).
create or replace function public.admin_dac7_report(p_year integer)
returns table (
  provider_id uuid,
  legal_name text,
  tax_id text,
  vat_number text,
  birth_date date,
  street_address text,
  postal_code text,
  city text,
  country char(2),
  iban text,
  q1_consideration_cents bigint, q1_activities integer,
  q2_consideration_cents bigint, q2_activities integer,
  q3_consideration_cents bigint, q3_activities integer,
  q4_consideration_cents bigint, q4_activities integer,
  fees_cents bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.is_admin() then
    raise exception 'forbidden' using errcode = 'P0001';
  end if;

  return query
  with done as (
    select s.provider_id,
           extract(quarter from s.captured_at at time zone 'Europe/Helsinki')::int as q,
           s.net_cents as net,
           s.commission_cents as fee
      from public.payment_settlements s
     where extract(year from s.captured_at at time zone 'Europe/Helsinki') = p_year
  )
  select pr.id, ti.legal_name, ti.tax_id, ti.vat_number, ti.birth_date,
         ti.street_address, ti.postal_code, ti.city, ti.country, pp.iban,
         coalesce(sum(d.net) filter (where d.q = 1), 0)::bigint, (count(*) filter (where d.q = 1))::int,
         coalesce(sum(d.net) filter (where d.q = 2), 0)::bigint, (count(*) filter (where d.q = 2))::int,
         coalesce(sum(d.net) filter (where d.q = 3), 0)::bigint, (count(*) filter (where d.q = 3))::int,
         coalesce(sum(d.net) filter (where d.q = 4), 0)::bigint, (count(*) filter (where d.q = 4))::int,
         coalesce(sum(d.fee), 0)::bigint
    from done d
    join public.providers pr on pr.id = d.provider_id
    left join public.provider_tax_info ti on ti.provider_id = pr.id
    left join public.provider_private pp on pp.provider_id = pr.id
   group by pr.id, ti.legal_name, ti.tax_id, ti.vat_number, ti.birth_date,
            ti.street_address, ti.postal_code, ti.city, ti.country, pp.iban
   order by ti.legal_name nulls last;
end;
$$;

-- Uudet private-funktiot eivät saa suoritusoikeuksia oletuksena (ks. lifecycle_enums).

grant execute on function public.accept_provider_terms(uuid, text) to authenticated;
grant execute on function public.submit_provider_application(uuid) to authenticated;
grant execute on function public.admin_review_application(uuid, boolean, text) to authenticated;
grant execute on function public.admin_set_provider_status(uuid, public.provider_status) to authenticated;
grant execute on function public.admin_dac7_report(integer) to authenticated;
