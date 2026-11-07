-- Reklamaatiot ja niiden käsittely ylläpidossa.
--
-- Asiakas voi reklamoida, kun työ on merkitty valmiiksi (ennen automaattista kuittausta)
-- tai dispute_window_days kuluessa kuittauksesta. Tarjoaja voi ilmoittaa, ettei asiakas
-- ollut paikalla. Avoin reklamaatio ennen kuittausta pysäyttää automaattisen kuittauksen
-- ja veloituksen (varaus tilaan 'disputed'). Ylläpito ratkaisee, ja hyvitys tehdään
-- Edge Functionista outbox-tapahtuman perusteella.

create table public.disputes (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id) on delete restrict,
  opened_by uuid not null references auth.users (id),
  opened_by_role text not null check (opened_by_role in ('customer', 'provider')),
  reason public.dispute_reason not null,
  description text not null check (length(description) between 10 and 4000),
  status public.dispute_status not null default 'open',
  -- Varauksen tila avaushetkellä: peruttu reklamaatio palauttaa sen.
  booking_status_at_open public.booking_status not null,
  refund_cents integer check (refund_cents is null or refund_cents >= 0),
  resolution_note text,
  resolved_by uuid references auth.users (id),
  opened_at timestamptz not null default now(),
  resolved_at timestamptz,
  updated_at timestamptz not null default now()
);
-- Yksi avoin reklamaatio per varaus.
create unique index disputes_one_open_per_booking on public.disputes (booking_id)
  where status in ('open', 'in_review');
create index disputes_booking_idx on public.disputes (booking_id);
create index disputes_status_idx on public.disputes (status, opened_at) where status in ('open', 'in_review');
create index disputes_opened_by_idx on public.disputes (opened_by);
create index disputes_resolved_by_idx on public.disputes (resolved_by) where resolved_by is not null;
create trigger disputes_updated_at before update on public.disputes
  for each row execute function public.set_updated_at();

create table public.dispute_messages (
  id uuid primary key default gen_random_uuid(),
  dispute_id uuid not null references public.disputes (id) on delete cascade,
  author_id uuid not null references auth.users (id),
  body text not null check (length(body) between 1 and 4000),
  created_at timestamptz not null default now()
);
create index dispute_messages_dispute_idx on public.dispute_messages (dispute_id, created_at);
create index dispute_messages_author_idx on public.dispute_messages (author_id);

alter table public.refunds
  add constraint refunds_dispute_fk foreign key (dispute_id) references public.disputes (id) on delete set null;
create index refunds_dispute_idx on public.refunds (dispute_id) where dispute_id is not null;

alter table public.disputes enable row level security;
alter table public.dispute_messages enable row level security;

create policy "disputes: varauksen osapuolet" on public.disputes
  for select to authenticated using (private.booking_role(booking_id) is not null);
create policy "dispute_messages: varauksen osapuolet" on public.dispute_messages
  for select to authenticated
  using (exists (select 1 from public.disputes d
                  where d.id = dispute_id and private.booking_role(d.booking_id) is not null));

grant select on public.disputes, public.dispute_messages to authenticated;

-- ---------------------------------------------------------------------------
-- RPC:t
-- ---------------------------------------------------------------------------
create or replace function public.open_dispute(
  p_booking_id uuid,
  p_reason public.dispute_reason,
  p_description text
)
returns public.disputes
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
  v_role text := private.booking_role(p_booking_id);
  v_dispute public.disputes;
  v_window interval := make_interval(days => (private.settings()).dispute_window_days);
begin
  select * into v_booking from public.bookings where id = p_booking_id for update;
  -- Ulkopuoliselle v_role on null (ja "null not in (...)" on null): sama virhe kuin puuttuvalle.
  if not found or v_role is null or v_role not in ('customer', 'provider') then
    raise exception 'booking_not_found' using errcode = 'P0001';
  end if;

  if v_role = 'customer' then
    if p_reason = 'customer_no_show' then
      raise exception 'invalid_reason' using errcode = 'P0001';
    end if;
    -- Tarjoaja ei tullut: varatun ajan alettua, ennen kuin työ on aloitettu.
    if not (
      v_booking.status = 'work_done'
      or (v_booking.status = 'completed' and v_booking.completed_at > now() - v_window)
      or (p_reason = 'provider_no_show' and v_booking.status = 'confirmed' and lower(v_booking.during) < now())
    ) then
      raise exception 'dispute_not_allowed' using errcode = 'P0001';
    end if;
  else
    if p_reason <> 'customer_no_show'
       or v_booking.status not in ('confirmed', 'in_progress')
       or lower(v_booking.during) > now() then
      raise exception 'dispute_not_allowed' using errcode = 'P0001';
    end if;
  end if;

  insert into public.disputes (booking_id, opened_by, opened_by_role, reason, description, booking_status_at_open)
  values (p_booking_id, auth.uid(), v_role, p_reason, trim(p_description), v_booking.status)
  returning * into v_dispute;

  -- Ennen kuittausta avattu reklamaatio pysäyttää kuittauksen ja veloituksen.
  if v_booking.status in ('confirmed', 'in_progress', 'work_done') then
    update public.bookings set status = 'disputed' where id = p_booking_id;
  end if;

  perform private.enqueue('dispute.opened', v_dispute.id,
    jsonb_build_object('dispute_id', v_dispute.id, 'booking_id', p_booking_id,
                       'reason', p_reason, 'opened_by_role', v_role));
  return v_dispute;
exception when unique_violation then
  raise exception 'dispute_already_open' using errcode = 'P0001';
end;
$$;

create or replace function public.add_dispute_message(p_dispute_id uuid, p_body text)
returns public.dispute_messages
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_dispute public.disputes;
  v_message public.dispute_messages;
begin
  select * into v_dispute from public.disputes where id = p_dispute_id;
  if not found or private.booking_role(v_dispute.booking_id) is null then
    raise exception 'dispute_not_found' using errcode = 'P0001';
  end if;
  if v_dispute.status not in ('open', 'in_review') then
    raise exception 'dispute_closed' using errcode = 'P0001';
  end if;

  insert into public.dispute_messages (dispute_id, author_id, body)
  values (p_dispute_id, auth.uid(), trim(p_body))
  returning * into v_message;
  return v_message;
end;
$$;

create or replace function public.withdraw_dispute(p_dispute_id uuid)
returns public.disputes
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_dispute public.disputes;
begin
  update public.disputes
     set status = 'withdrawn', resolved_at = now(), resolved_by = auth.uid()
   where id = p_dispute_id and opened_by = auth.uid() and status in ('open', 'in_review')
  returning * into v_dispute;
  if not found then
    raise exception 'dispute_not_found' using errcode = 'P0001';
  end if;

  -- Pysäytetty varaus jatkaa siitä, mihin jäi (esim. valmis työ kuittautuu automaattisesti).
  update public.bookings
     set status = v_dispute.booking_status_at_open
   where id = v_dispute.booking_id and status = 'disputed';
  return v_dispute;
end;
$$;

-- Ylläpito ratkaisee: ei toimenpiteitä, osittainen hyvitys tai täysi hyvitys.
create or replace function public.admin_resolve_dispute(
  p_dispute_id uuid,
  p_outcome public.dispute_status,
  p_refund_cents integer default null,
  p_note text default null
)
returns public.disputes
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_dispute public.disputes;
  v_booking public.bookings;
begin
  if not private.is_admin() then
    raise exception 'forbidden' using errcode = 'P0001';
  end if;
  if p_outcome not in ('in_review', 'resolved_no_action', 'resolved_partial_refund', 'resolved_refund') then
    raise exception 'invalid_outcome' using errcode = 'P0001';
  end if;

  select * into v_dispute from public.disputes where id = p_dispute_id for update;
  if not found or v_dispute.status not in ('open', 'in_review') then
    raise exception 'dispute_not_found' using errcode = 'P0001';
  end if;
  select * into v_booking from public.bookings where id = v_dispute.booking_id for update;

  if p_outcome = 'in_review' then
    update public.disputes set status = 'in_review' where id = p_dispute_id returning * into v_dispute;
    return v_dispute;
  end if;

  if p_outcome = 'resolved_partial_refund'
     and (p_refund_cents is null or p_refund_cents <= 0 or p_refund_cents >= v_booking.customer_total_cents) then
    raise exception 'invalid_refund' using errcode = 'P0001';
  end if;

  update public.disputes
     set status = p_outcome,
         refund_cents = case p_outcome
                          when 'resolved_refund' then v_booking.customer_total_cents
                          when 'resolved_partial_refund' then p_refund_cents
                          else 0
                        end,
         resolution_note = nullif(trim(p_note), ''),
         resolved_by = auth.uid(),
         resolved_at = now()
   where id = p_dispute_id
  returning * into v_dispute;

  -- Pysäytetty varaus: täysi hyvitys perii varauksen, muuten se kuitataan ylläpidon toimesta.
  if v_booking.status = 'disputed' then
    if p_outcome = 'resolved_refund' then
      update public.bookings
         set status = 'cancelled', cancelled_at = now(), cancel_reason = 'dispute_refund'
       where id = v_booking.id;
    else
      perform private.mark_completed(v_booking.id, 'admin');
    end if;
  end if;

  perform private.enqueue('dispute.resolved', v_dispute.id,
    jsonb_build_object('dispute_id', v_dispute.id, 'booking_id', v_booking.id,
                       'outcome', p_outcome, 'refund_cents', v_dispute.refund_cents));
  return v_dispute;
end;
$$;

-- Uudet private-funktiot eivät saa suoritusoikeuksia oletuksena (ks. lifecycle_enums).

grant execute on function public.open_dispute(uuid, public.dispute_reason, text) to authenticated;
grant execute on function public.add_dispute_message(uuid, text) to authenticated;
grant execute on function public.withdraw_dispute(uuid) to authenticated;
grant execute on function public.admin_resolve_dispute(uuid, public.dispute_status, integer, text) to authenticated;
