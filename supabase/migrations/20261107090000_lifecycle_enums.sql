-- Vaihe 2: uudet tilat ja tyypit.
-- Enum-arvot lisätään omassa migraatiossaan, koska ALTER TYPE ... ADD VALUE -arvoa ei voi
-- käyttää samassa transaktiossa, jossa se lisätään.
--
-- Varauksen elinkaari:
--   held → confirmed → in_progress → work_done → completed
--                                         ↘ disputed → completed / cancelled (ylläpito)
--   held → expired,  held/confirmed → cancelled

alter type public.booking_status add value if not exists 'in_progress' after 'confirmed';
alter type public.booking_status add value if not exists 'work_done' after 'in_progress';
alter type public.booking_status add value if not exists 'disputed' after 'completed';

create type public.completion_method as enum ('customer', 'auto', 'admin');

create type public.payment_status as enum (
  'pending',            -- maksu luotu, odottaa asiakkaan hyväksyntää
  'requires_action',    -- esim. MobilePay-sovelluksessa hyväksyttävänä
  'authorized',         -- summa varattu, ei veloitettu
  'captured',           -- veloitettu kuittauksen jälkeen
  'canceled',           -- varaus vapautettu ilman veloitusta
  'failed',
  'partially_refunded',
  'refunded'
);

create type public.dispute_reason as enum (
  'quality', 'damage', 'provider_no_show', 'customer_no_show', 'price', 'other'
);
create type public.dispute_status as enum (
  'open', 'in_review', 'resolved_no_action', 'resolved_partial_refund', 'resolved_refund', 'withdrawn'
);

create type public.application_status as enum (
  'draft', 'submitted', 'in_review', 'approved', 'rejected', 'withdrawn'
);

create type public.photo_kind as enum ('before', 'after', 'checklist', 'damage', 'dispute');
create type public.notification_channel as enum ('push', 'email', 'sms');
create type public.notification_status as enum ('pending', 'sent', 'failed', 'skipped');
create type public.device_platform as enum ('ios', 'android', 'web');

-- Uudet funktiot eivät saa oletuksena suoritusoikeutta kaikille (PUBLIC). Skeemakohtainen
-- ALTER DEFAULT PRIVILEGES ei voi poistaa PUBLIC-oletusta, joten tämä tehdään globaalisti.
-- Jokainen rajapintaan tarkoitettu funktio saa oman GRANT-lauseensa.
alter default privileges for role postgres revoke execute on functions from public;
