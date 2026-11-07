-- Työn kulku: aloitus, tarkistuslista kuvineen, valmis, kuittaus (asiakas tai automaattinen) ja arvostelu.

-- ---------------------------------------------------------------------------
-- Tarkistuslistan kohdat (katalogi)
-- ---------------------------------------------------------------------------
create table public.checklist_items (
  code text primary key check (code ~ '^[a-z0-9_]+$'),
  label jsonb not null check (public.is_i18n_text(label)),
  help jsonb check (help is null or public.is_i18n_text(help)),
  requires_photo boolean not null default false,
  sort_order integer not null default 0,
  active boolean not null default true
);

insert into public.checklist_items (code, label, help, requires_photo, sort_order) values
  ('tread_depth',
   '{"fi": "Urasyvyys mitattu", "sv": "Mönsterdjup uppmätt", "en": "Tread depth measured"}',
   '{"fi": "Kirjaa pienin urasyvyys millimetreinä.", "sv": "Ange minsta mönsterdjup i millimeter.", "en": "Record the smallest tread depth in millimetres."}',
   false, 10),
  ('tyre_condition',
   '{"fi": "Renkaiden kunto tarkastettu", "sv": "Däckens skick kontrollerat", "en": "Tyre condition checked"}',
   '{"fi": "Halkeamat, pullistumat ja vauriot. Kuvaa vauriot.", "sv": "Sprickor, bulor och skador. Fotografera skador.", "en": "Cracks, bulges and damage. Photograph any damage."}',
   false, 20),
  ('tyre_pressure',
   '{"fi": "Rengaspaineet säädetty", "sv": "Däcktryck justerat", "en": "Tyre pressures set"}',
   '{"fi": "Valmistajan suosituksen mukaan.", "sv": "Enligt tillverkarens rekommendation.", "en": "To the manufacturer recommendation."}',
   false, 30),
  ('torque',
   '{"fi": "Pyöränpultit kiristetty momenttiavaimella", "sv": "Hjulbultar åtdragna med momentnyckel", "en": "Wheel bolts torqued with a torque wrench"}',
   '{"fi": "Kirjaa käytetty kiristysmomentti (Nm).", "sv": "Ange använt åtdragningsmoment (Nm).", "en": "Record the torque used (Nm)."}',
   false, 40),
  ('photos_after',
   '{"fi": "Kuvat valmiista työstä", "sv": "Foton av färdigt arbete", "en": "Photos of the finished work"}',
   '{"fi": "Kuva jokaisesta pyörästä.", "sv": "Foto på varje hjul.", "en": "A photo of each wheel."}',
   true, 50);

alter table public.checklist_items enable row level security;
create policy "checklist_items: luku" on public.checklist_items
  for select to anon, authenticated using (active or (select private.is_admin()));
create policy "checklist_items: admin" on public.checklist_items
  for all to authenticated using ((select private.is_admin())) with check ((select private.is_admin()));
grant select on public.checklist_items to anon, authenticated;
grant insert, update, delete on public.checklist_items to authenticated;

-- ---------------------------------------------------------------------------
-- Varauksen tarkistuslista ja kuvat
-- ---------------------------------------------------------------------------
create table public.booking_checklist (
  booking_id uuid not null references public.bookings (id) on delete cascade,
  item_code text not null references public.checklist_items (code),
  ok boolean not null,
  value text check (value is null or length(value) <= 200),
  note text check (note is null or length(note) <= 1000),
  checked_by uuid not null references auth.users (id),
  checked_at timestamptz not null default now(),
  primary key (booking_id, item_code)
);
create index booking_checklist_item_idx on public.booking_checklist (item_code);
create index booking_checklist_checked_by_idx on public.booking_checklist (checked_by);

-- Kuvat ovat Storagessa (bucket booking-photos, polku <booking_id>/<tiedosto>).
-- Tämä taulu kertoo, mihin varaukseen ja kohtaan kuva liittyy.
create table public.booking_photos (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id) on delete cascade,
  storage_path text not null unique,
  kind public.photo_kind not null,
  item_code text references public.checklist_items (code),
  uploaded_by uuid not null references auth.users (id),
  created_at timestamptz not null default now(),
  check (storage_path like booking_id::text || '/%')
);
create index booking_photos_booking_idx on public.booking_photos (booking_id);
create index booking_photos_item_idx on public.booking_photos (item_code) where item_code is not null;
create index booking_photos_uploaded_by_idx on public.booking_photos (uploaded_by);

-- ---------------------------------------------------------------------------
-- Apufunktiot
-- ---------------------------------------------------------------------------
create or replace function private.try_uuid(p_text text)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
begin
  return p_text::uuid;
exception when invalid_text_representation then
  return null;
end;
$$;

-- Kirjautuneen käyttäjän rooli varauksessa: 'customer', 'provider', 'admin' tai null.
create or replace function private.booking_role(p_booking_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
           when b.customer_id = auth.uid() then 'customer'
           when private.is_provider_member(b.provider_id) then 'provider'
           when private.is_admin() then 'admin'
         end
    from public.bookings b
   where b.id = p_booking_id;
$$;

alter table public.booking_checklist enable row level security;
alter table public.booking_photos enable row level security;

create policy "booking_checklist: osapuolet" on public.booking_checklist
  for select to authenticated using (private.booking_role(booking_id) is not null);
create policy "booking_photos: osapuolet" on public.booking_photos
  for select to authenticated using (private.booking_role(booking_id) is not null);

-- Kirjoitukset RPC:llä.
grant select on public.booking_checklist, public.booking_photos to authenticated;

-- ---------------------------------------------------------------------------
-- Storage: booking-photos (yksityinen)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('booking-photos', 'booking-photos', false, 10 * 1024 * 1024,
        array['image/jpeg', 'image/png', 'image/webp', 'image/heic'])
on conflict (id) do nothing;

-- Tarjoaja lataa kuvia työn aikana, asiakas reklamaation yhteydessä.
create or replace function private.can_upload_booking_photo(p_booking_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.bookings b
     where b.id = p_booking_id
       and (
         (private.is_provider_member(b.provider_id) and b.status in ('in_progress', 'work_done'))
         or (b.customer_id = auth.uid() and b.status in ('work_done', 'completed', 'disputed'))
       )
  );
$$;

create policy "booking-photos: osapuolet lukevat" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'booking-photos'
    and private.booking_role(private.try_uuid((storage.foldername(name))[1])) is not null
  );
create policy "booking-photos: lataus työn aikana" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'booking-photos'
    and private.can_upload_booking_photo(private.try_uuid((storage.foldername(name))[1]))
  );

-- ---------------------------------------------------------------------------
-- RPC:t
-- ---------------------------------------------------------------------------

-- Tarjoaja aloittaa työn (aikaisintaan 2 h ennen ja viimeistään 12 h jälkeen varatun ajan).
create or replace function public.start_job(p_booking_id uuid)
returns public.bookings
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
begin
  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found or not private.is_provider_member(v_booking.provider_id) then
    raise exception 'booking_not_found' using errcode = 'P0001';
  end if;
  if v_booking.status <> 'confirmed' then
    raise exception 'invalid_status' using errcode = 'P0001';
  end if;
  if now() < lower(v_booking.during) - interval '2 hours'
     or now() > upper(v_booking.during) + interval '12 hours' then
    raise exception 'outside_job_window' using errcode = 'P0001';
  end if;
  if (private.settings()).payments_enabled and not exists (
       select 1 from public.payments p
        where p.booking_id = v_booking.id and p.status = 'authorized') then
    raise exception 'payment_not_authorized' using errcode = 'P0001';
  end if;

  update public.bookings
     set status = 'in_progress', started_at = now()
   where id = p_booking_id
  returning * into v_booking;
  return v_booking;
end;
$$;

create or replace function public.save_checklist_item(
  p_booking_id uuid,
  p_item_code text,
  p_ok boolean,
  p_value text default null,
  p_note text default null
)
returns public.booking_checklist
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
  v_row public.booking_checklist;
begin
  select * into v_booking from public.bookings where id = p_booking_id;
  if not found or not private.is_provider_member(v_booking.provider_id) then
    raise exception 'booking_not_found' using errcode = 'P0001';
  end if;
  if v_booking.status <> 'in_progress' then
    raise exception 'invalid_status' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.checklist_items where code = p_item_code and active) then
    raise exception 'unknown_checklist_item' using errcode = 'P0001';
  end if;

  insert into public.booking_checklist (booking_id, item_code, ok, value, note, checked_by)
  values (p_booking_id, p_item_code, p_ok, nullif(trim(p_value), ''), nullif(trim(p_note), ''), auth.uid())
  on conflict (booking_id, item_code) do update
    set ok = excluded.ok, value = excluded.value, note = excluded.note,
        checked_by = excluded.checked_by, checked_at = now()
  returning * into v_row;
  return v_row;
end;
$$;

-- Kuva ladataan ensin Storageen, sitten kirjataan tällä.
create or replace function public.register_booking_photo(
  p_booking_id uuid,
  p_storage_path text,
  p_kind public.photo_kind,
  p_item_code text default null
)
returns public.booking_photos
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_row public.booking_photos;
begin
  if not private.can_upload_booking_photo(p_booking_id) then
    raise exception 'booking_not_found' using errcode = 'P0001';
  end if;
  if p_storage_path not like p_booking_id::text || '/%'
     or not exists (select 1 from storage.objects o
                     where o.bucket_id = 'booking-photos' and o.name = p_storage_path) then
    raise exception 'photo_not_uploaded' using errcode = 'P0001';
  end if;
  if private.booking_role(p_booking_id) = 'customer' and p_kind not in ('dispute', 'damage') then
    raise exception 'invalid_photo_kind' using errcode = 'P0001';
  end if;

  insert into public.booking_photos (booking_id, storage_path, kind, item_code, uploaded_by)
  values (p_booking_id, p_storage_path, p_kind, p_item_code, auth.uid())
  returning * into v_row;
  return v_row;
end;
$$;

-- Tarjoaja merkitsee työn valmiiksi. Kaikki aktiiviset kohdat on täytettävä,
-- ja kuvaa vaativiin kohtiin on liitettävä vähintään yksi kuva.
create or replace function public.complete_job(p_booking_id uuid)
returns public.bookings
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
  v_missing text[];
begin
  select * into v_booking from public.bookings where id = p_booking_id for update;
  if not found or not private.is_provider_member(v_booking.provider_id) then
    raise exception 'booking_not_found' using errcode = 'P0001';
  end if;
  if v_booking.status <> 'in_progress' then
    raise exception 'invalid_status' using errcode = 'P0001';
  end if;

  select array_agg(ci.code order by ci.sort_order) into v_missing
    from public.checklist_items ci
   where ci.active
     and (
       not exists (select 1 from public.booking_checklist bc
                    where bc.booking_id = p_booking_id and bc.item_code = ci.code)
       or (ci.requires_photo and not exists (
             select 1 from public.booking_photos bp
              where bp.booking_id = p_booking_id and bp.item_code = ci.code))
     );
  if v_missing is not null then
    raise exception 'checklist_incomplete' using errcode = 'P0001', detail = array_to_string(v_missing, ',');
  end if;

  update public.bookings
     set status = 'work_done',
         work_done_at = now(),
         auto_complete_at = now() + make_interval(hours => (private.settings()).auto_complete_hours)
   where id = p_booking_id
  returning * into v_booking;
  return v_booking;
end;
$$;

create or replace function private.mark_completed(p_booking_id uuid, p_method public.completion_method)
returns public.bookings
language sql
volatile
security definer
set search_path = ''
as $$
  update public.bookings
     set status = 'completed',
         completed_at = now(),
         completion_method = p_method,
         retorque_reminder_at = now() + make_interval(days => (private.settings()).retorque_reminder_days)
   where id = p_booking_id
  returning *;
$$;

-- Asiakas kuittaa työn. Kuittaus käynnistää veloituksen (outbox: booking.completed).
create or replace function public.confirm_job_completion(p_booking_id uuid)
returns public.bookings
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
begin
  select * into v_booking from public.bookings
   where id = p_booking_id and customer_id = auth.uid()
   for update;
  if not found then
    raise exception 'booking_not_found' using errcode = 'P0001';
  end if;
  if v_booking.status <> 'work_done' then
    raise exception 'invalid_status' using errcode = 'P0001';
  end if;
  return private.mark_completed(p_booking_id, 'customer');
end;
$$;

-- Automaattinen kuittaus, jos asiakas ei kuittaa eikä reklamoi (pg_cron).
create or replace function private.auto_complete_jobs()
returns integer
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_count integer := 0;
begin
  for v_id in
    select id from public.bookings
     where status = 'work_done' and auto_complete_at <= now()
     order by auto_complete_at
     limit 500
     for update skip locked
  loop
    perform private.mark_completed(v_id, 'auto');
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- Arvostelu vain kuitatusta varauksesta, kerran, review_window_days kuluessa.
create or replace function public.submit_review(
  p_booking_id uuid,
  p_rating smallint,
  p_body text default null,
  p_locale public.locale default 'fi'
)
returns public.reviews
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
  v_review public.reviews;
begin
  select * into v_booking from public.bookings where id = p_booking_id and customer_id = auth.uid();
  if not found then
    raise exception 'booking_not_found' using errcode = 'P0001';
  end if;
  if v_booking.status <> 'completed'
     or v_booking.completed_at < now() - make_interval(days => (private.settings()).review_window_days) then
    raise exception 'review_not_allowed' using errcode = 'P0001';
  end if;
  if p_rating is null or p_rating not between 1 and 5 then
    raise exception 'invalid_rating' using errcode = 'P0001';
  end if;

  insert into public.reviews (booking_id, provider_id, author_id, rating, body, locale)
  values (p_booking_id, v_booking.provider_id, auth.uid(), p_rating, nullif(trim(p_body), ''), p_locale)
  returning * into v_review;
  return v_review;
exception when unique_violation then
  raise exception 'already_reviewed' using errcode = 'P0001';
end;
$$;

-- Arvostelu muuttaa tarjoajan sivua: sivuston revalidointi.
create or replace function private.on_review_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.enqueue('provider.changed', coalesce(new.provider_id, old.provider_id),
                          jsonb_build_object('provider_id', coalesce(new.provider_id, old.provider_id)));
  return null;
end;
$$;
create trigger reviews_outbox
  after insert or update or delete on public.reviews
  for each row execute function private.on_review_change();

-- ---------------------------------------------------------------------------
-- Oikeudet
-- ---------------------------------------------------------------------------
-- Uudet private-funktiot eivät saa suoritusoikeuksia oletuksena (ks. lifecycle_enums);
-- RLS-politiikoissa käytettävät apufunktiot saavat oikeuden tässä, kerran.
grant execute on function private.booking_role(uuid) to authenticated;
grant execute on function private.try_uuid(text) to authenticated;
grant execute on function private.can_upload_booking_photo(uuid) to authenticated;

grant execute on function public.start_job(uuid) to authenticated;
grant execute on function public.save_checklist_item(uuid, text, boolean, text, text) to authenticated;
grant execute on function public.register_booking_photo(uuid, text, public.photo_kind, text) to authenticated;
grant execute on function public.complete_job(uuid) to authenticated;
grant execute on function public.confirm_job_completion(uuid) to authenticated;
grant execute on function public.submit_review(uuid, smallint, text, public.locale) to authenticated;
