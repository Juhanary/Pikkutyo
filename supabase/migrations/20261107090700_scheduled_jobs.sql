-- Ajastetut työt (pg_cron). Ohitetaan, jos pg_cron ei ole käytettävissä (paikallinen testikanta).

create or replace function private.cleanup_outbox()
returns integer
language sql
volatile
security definer
set search_path = ''
as $$
  with deleted as (
    delete from public.outbox_events
     where processed_at < now() - interval '30 days'
    returning 1
  )
  select count(*)::integer from deleted;
$$;
revoke execute on function private.cleanup_outbox() from public, anon, authenticated;

-- Maksutyöntekijän kutsu. Osoite ja secret-avain luetaan Vaultista (ks.
-- supabase/functions/README.md). Ilman niitä, tai kun maksut eivät ole käytössä, ei tee mitään,
-- joten ajastus voidaan luoda migraatiossa ja se säilyy kannan tyhjennyksen yli.
create or replace function private.invoke_payments_worker()
returns bigint
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_key text;
begin
  if not (private.settings()).payments_enabled
     or not exists (select 1 from pg_extension where extname = 'pg_net') then
    return null;
  end if;
  select decrypted_secret into v_url from vault.decrypted_secrets where name = 'payments_worker_url';
  select decrypted_secret into v_key from vault.decrypted_secrets where name = 'payments_worker_key';
  if v_url is null or v_key is null then
    return null;
  end if;
  return net.http_post(
    url := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'apikey', v_key));
end;
$$;
revoke execute on function private.invoke_payments_worker() from public, anon, authenticated;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('auto-complete-jobs', '*/5 * * * *', 'select private.auto_complete_jobs()');
    perform cron.schedule('enqueue-reminders', '*/15 * * * *', 'select private.enqueue_reminders()');
    perform cron.schedule('payment-deadlines', '*/15 * * * *', 'select private.enforce_payment_deadlines()');
    perform cron.schedule('cleanup-outbox', '17 3 * * *', 'select private.cleanup_outbox()');
    perform cron.schedule('payments-worker', '* * * * *', 'select private.invoke_payments_worker()');
  else
    raise notice 'pg_cron puuttuu: ajastukset ohitettu';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Suoritusoikeuksien tarkistus: anon saa kutsua vain julkisia hakuja.
-- (Aiemmin luoduilla funktioilla on PUBLIC-oletusoikeus, joka poistetaan tässä.)
-- ---------------------------------------------------------------------------
revoke execute on all functions in schema public from public, anon;
grant execute on function public.search_providers(text, public.locale, text, public.location_type, public.provider_kind, text, date, time, time, double precision, double precision, integer, integer) to anon;
grant execute on function public.get_available_slots(uuid, text, public.location_type, date, date) to anon;
-- Tarkistusrajoitteissa käytetyt apufunktiot.
grant execute on function public.is_i18n_text(jsonb) to anon, authenticated;
grant execute on function public.t(jsonb, public.locale) to anon, authenticated;
