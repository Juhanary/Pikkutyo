-- 1) service_rolen oikeudet eksplisiittisesti. Supabase ei enää anna uusille tauluille oikeuksia
--    automaattisesti (uudet projektit), joten maksutyöntekijä, Stripe-webhook ja testikytkimet
--    eivät saa riippua kannan oletusoikeuksista. service_role ohittaa RLS:n; sitä käyttävät vain
--    palvelinpuolen koodit secret-avaimella.
grant select, insert, update, delete on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to service_role;
alter default privileges for role postgres in schema public
  grant select, insert, update, delete on tables to service_role;
alter default privileges for role postgres in schema public
  grant usage, select on sequences to service_role;

-- 2) Hakemusliitteen lataus vain omaan luonnokseen (polku <uid>/<hakemus>/...), ei anonyymeille
--    istunnoille, ja enintään 20 tiedostoa hakemusta kohden. Aiemmin kelpasi mikä tahansa
--    <uid>/...-polku, joten kuka tahansa kirjautunut (myös anonyymi) pystyi täyttämään Storagen
--    tiedostoilla, joita ei voinut kirjata eikä poistaa.
drop policy "application-documents: oma lataus" on storage.objects;
create policy "application-documents: lataus omaan luonnokseen" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'application-documents'
    and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1
        from public.provider_applications a
       where a.id = private.try_uuid((storage.foldername(name))[2])
         and a.user_id = (select auth.uid())
         and a.status = 'draft'
    )
    and (
      select count(*)
        from storage.objects o
       where o.bucket_id = 'application-documents'
         and (storage.foldername(o.name))[1] = (storage.foldername(name))[1]
         and (storage.foldername(o.name))[2] = (storage.foldername(name))[2]
    ) < 20
  );

-- 3) Kirjaamattoman (orvon) tiedoston saa poistaa omasta hakemuksesta tilasta riippumatta.
--    Kirjaamaton tiedosto ei ole osa hakemusta, joten poisto ei hävitä mitään. Tämä kattaa
--    tapauksen, jossa hakemus lähetettiin toisessa välilehdessä kesken latauksen.
drop policy "application-documents: orvon poisto omasta luonnoksesta" on storage.objects;
create policy "application-documents: orvon poisto omasta hakemuksesta" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'application-documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1
        from public.provider_applications a
       where a.id = private.try_uuid((storage.foldername(name))[2])
         and a.user_id = (select auth.uid())
    )
    and not exists (select 1 from public.application_documents d where d.storage_path = name)
  );
