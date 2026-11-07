-- Vaihdarenkaat: perustietomalli.
-- Periaatteet:
--   * aikaleimat timestamptz, toistuvat aukioloajat paikallisaikana (Europe/Helsinki)
--   * rahat sentteinä (integer), hinnat sisältävät alv:n
--   * käännettävä sisältö jsonb-muodossa {"fi": ..., "sv": ..., "en": ...}
--   * URL-slugit omissa tauluissaan kielittäin, jotta uusi kieli tai kaupunki ei vaadi koodimuutosta

set search_path = public, extensions;

-- ---------------------------------------------------------------------------
-- Tyypit
-- ---------------------------------------------------------------------------
create type public.locale as enum ('fi', 'sv', 'en');
create type public.provider_kind as enum ('company', 'individual');
create type public.provider_status as enum ('pending', 'active', 'suspended');
create type public.location_type as enum ('workshop', 'mobile');
create type public.member_role as enum ('owner', 'staff');
create type public.exception_kind as enum ('closed', 'open');
create type public.booking_status as enum ('held', 'confirmed', 'completed', 'cancelled', 'expired');

-- ---------------------------------------------------------------------------
-- Apufunktiot
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Tarkistaa, että i18n-kentässä on vähintään suomenkielinen arvo.
create or replace function public.is_i18n_text(value jsonb)
returns boolean
language sql
immutable
as $$
  select jsonb_typeof(value) = 'object'
     and coalesce(length(value ->> 'fi'), 0) > 0;
$$;

-- Palauttaa käännöksen pyydetyllä kielellä, muuten suomeksi.
create or replace function public.t(value jsonb, lang public.locale)
returns text
language sql
immutable
as $$
  select coalesce(nullif(value ->> lang::text, ''), value ->> 'fi');
$$;

-- ---------------------------------------------------------------------------
-- Maantiede
-- ---------------------------------------------------------------------------
create table public.cities (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9-]+$'),
  name jsonb not null check (public.is_i18n_text(name)),
  center extensions.geography(point, 4326) not null,
  timezone text not null default 'Europe/Helsinki',
  active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.city_slugs (
  city_id uuid not null references public.cities (id) on delete cascade,
  locale public.locale not null,
  slug text not null check (slug ~ '^[a-z0-9-]+$'),
  primary key (city_id, locale),
  unique (locale, slug)
);

create table public.districts (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null references public.cities (id) on delete cascade,
  code text not null check (code ~ '^[a-z0-9-]+$'),
  name jsonb not null check (public.is_i18n_text(name)),
  center extensions.geography(point, 4326),
  created_at timestamptz not null default now(),
  unique (city_id, code)
);

create table public.district_slugs (
  district_id uuid not null references public.districts (id) on delete cascade,
  locale public.locale not null,
  city_id uuid not null references public.cities (id) on delete cascade,
  slug text not null check (slug ~ '^[a-z0-9-]+$'),
  primary key (district_id, locale),
  unique (city_id, locale, slug)
);

create table public.postal_codes (
  code text primary key check (code ~ '^[0-9]{5}$'),
  city_id uuid not null references public.cities (id) on delete cascade,
  district_id uuid references public.districts (id) on delete set null,
  center extensions.geography(point, 4326) not null
);
create index postal_codes_city_idx on public.postal_codes (city_id);

-- ---------------------------------------------------------------------------
-- Palvelukatalogi
-- ---------------------------------------------------------------------------
create table public.services (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z0-9_]+$'),
  name jsonb not null check (public.is_i18n_text(name)),
  description jsonb check (description is null or public.is_i18n_text(description)),
  default_duration_min integer not null check (default_duration_min > 0 and default_duration_min % 15 = 0),
  sort_order integer not null default 0,
  active boolean not null default true
);

-- ---------------------------------------------------------------------------
-- Käyttäjät
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  phone text,
  locale public.locale not null default 'fi',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Profiili luodaan automaattisesti uudelle käyttäjälle (myös anonyymille).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data ->> 'full_name')
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  nickname text,
  plate text check (plate is null or plate ~ '^[A-ZÅÄÖ0-9-]{2,10}$'),
  tire_size text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index vehicles_owner_idx on public.vehicles (owner_id);

-- ---------------------------------------------------------------------------
-- Tarjoajat
-- ---------------------------------------------------------------------------
create table public.providers (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
  kind public.provider_kind not null,
  status public.provider_status not null default 'pending',
  display_name text not null check (length(display_name) between 2 and 80),
  description jsonb check (description is null or public.is_i18n_text(description)),
  city_id uuid not null references public.cities (id),
  district_id uuid references public.districts (id) on delete set null,
  -- Julkinen sijainti: korjaamon osoite tai yksityisen tekijän likimääräinen alue.
  -- Tarkka kotiosoite on provider_private-taulussa.
  location extensions.geography(point, 4326) not null,
  service_radius_km numeric(5, 1) check (service_radius_km is null or service_radius_km between 0 and 200),
  min_notice_minutes integer not null default 120 check (min_notice_minutes >= 0),
  max_days_ahead integer not null default 60 check (max_days_ahead between 1 and 365),
  rating_avg numeric(3, 2),
  rating_count integer not null default 0,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index providers_city_status_idx on public.providers (city_id, status);
create index providers_district_idx on public.providers (district_id) where status = 'active';
create index providers_location_idx on public.providers using gist (location);

create table public.provider_private (
  provider_id uuid primary key references public.providers (id) on delete cascade,
  business_id text check (business_id is null or business_id ~ '^[0-9]{7}-[0-9]$'),
  street_address text,
  postal_code text,
  exact_location extensions.geography(point, 4326),
  contact_email text,
  contact_phone text,
  iban text,
  updated_at timestamptz not null default now()
);

create table public.provider_members (
  provider_id uuid not null references public.providers (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role public.member_role not null default 'staff',
  created_at timestamptz not null default now(),
  primary key (provider_id, user_id)
);
create index provider_members_user_idx on public.provider_members (user_id);

-- Kapasiteetin yksikkö: nostin, asentaja tai pakettiauto.
create table public.provider_resources (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers (id) on delete cascade,
  name text not null,
  location_type public.location_type not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create index provider_resources_provider_idx on public.provider_resources (provider_id) where active;

create table public.provider_services (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers (id) on delete cascade,
  service_id uuid not null references public.services (id),
  location_type public.location_type not null,
  price_cents integer not null check (price_cents >= 0),
  travel_fee_cents integer not null default 0 check (travel_fee_cents >= 0),
  duration_min integer not null check (duration_min > 0 and duration_min % 15 = 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider_id, service_id, location_type),
  check (location_type = 'mobile' or travel_fee_cents = 0)
);
create index provider_services_lookup_idx
  on public.provider_services (service_id, location_type) where active;

-- Toistuva viikkorytmi paikallisaikana. weekday: 1 = maanantai ... 7 = sunnuntai (ISO).
create table public.availability_rules (
  id uuid primary key default gen_random_uuid(),
  resource_id uuid not null references public.provider_resources (id) on delete cascade,
  weekday smallint not null check (weekday between 1 and 7),
  start_time time not null,
  end_time time not null,
  valid_from date,
  valid_to date,
  check (start_time < end_time),
  check (valid_from is null or valid_to is null or valid_from <= valid_to)
);
create index availability_rules_resource_idx on public.availability_rules (resource_id, weekday);

create table public.availability_exceptions (
  id uuid primary key default gen_random_uuid(),
  resource_id uuid not null references public.provider_resources (id) on delete cascade,
  kind public.exception_kind not null,
  during tstzrange not null check (not isempty(during) and lower_inc(during) and not upper_inc(during)),
  note text
);
create index availability_exceptions_resource_idx
  on public.availability_exceptions using gist (resource_id, during);

-- ---------------------------------------------------------------------------
-- Varaukset
-- ---------------------------------------------------------------------------
create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers (id),
  resource_id uuid not null references public.provider_resources (id),
  provider_service_id uuid not null references public.provider_services (id),
  service_id uuid not null references public.services (id),
  location_type public.location_type not null,
  customer_id uuid not null references auth.users (id),
  during tstzrange not null check (not isempty(during) and lower_inc(during) and not upper_inc(during)),
  status public.booking_status not null default 'held',
  -- Hinta lukitaan varaushetkellä, jotta myöhemmät hinnanmuutokset eivät vaikuta.
  price_cents integer not null check (price_cents >= 0),
  travel_fee_cents integer not null default 0 check (travel_fee_cents >= 0),
  total_cents integer generated always as (price_cents + travel_fee_cents) stored,
  contact jsonb,
  address text,
  address_location extensions.geography(point, 4326),
  vehicle_id uuid references public.vehicles (id) on delete set null,
  customer_note text check (customer_note is null or length(customer_note) <= 500),
  hold_expires_at timestamptz,
  hold_extended boolean not null default false,
  cancel_reason text,
  confirmed_at timestamptz,
  cancelled_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (status <> 'held' or hold_expires_at is not null),
  check (location_type = 'workshop' or status <> 'confirmed' or address is not null),
  -- Kaksoisvarauksen esto: sama resurssi ei voi olla pidossa tai varattuna päällekkäin.
  constraint bookings_no_overlap exclude using gist (
    resource_id with =,
    during with &&
  ) where (status in ('held', 'confirmed'))
);
create index bookings_customer_idx on public.bookings (customer_id, created_at desc);
create index bookings_provider_time_idx on public.bookings using gist (provider_id, during);
create index bookings_held_expiry_idx on public.bookings (hold_expires_at) where status = 'held';

-- ---------------------------------------------------------------------------
-- Arvostelut
-- ---------------------------------------------------------------------------
create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings (id) on delete cascade,
  provider_id uuid not null references public.providers (id) on delete cascade,
  author_id uuid not null references auth.users (id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  body text check (body is null or length(body) <= 2000),
  locale public.locale not null default 'fi',
  published boolean not null default true,
  created_at timestamptz not null default now()
);
create index reviews_provider_idx on public.reviews (provider_id, created_at desc) where published;

create or replace function public.refresh_provider_rating()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target uuid := coalesce(new.provider_id, old.provider_id);
begin
  update public.providers p
     set rating_avg = s.avg_rating,
         rating_count = s.cnt
    from (
      select round(avg(r.rating)::numeric, 2) as avg_rating, count(*)::int as cnt
        from public.reviews r
       where r.provider_id = target and r.published
    ) s
   where p.id = target;
  return null;
end;
$$;

create trigger reviews_refresh_rating
  after insert or update or delete on public.reviews
  for each row execute function public.refresh_provider_rating();

-- ---------------------------------------------------------------------------
-- updated_at-triggerit
-- ---------------------------------------------------------------------------
create trigger cities_updated_at before update on public.cities
  for each row execute function public.set_updated_at();
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger vehicles_updated_at before update on public.vehicles
  for each row execute function public.set_updated_at();
create trigger providers_updated_at before update on public.providers
  for each row execute function public.set_updated_at();
create trigger provider_private_updated_at before update on public.provider_private
  for each row execute function public.set_updated_at();
create trigger provider_services_updated_at before update on public.provider_services
  for each row execute function public.set_updated_at();
create trigger bookings_updated_at before update on public.bookings
  for each row execute function public.set_updated_at();
