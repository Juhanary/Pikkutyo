-- Hakemusliitteiden siivous: hakija saa poistaa Storagesta oman luonnoksensa tiedoston,
-- jota mikään liitekirjaus ei enää käytä. Tarvitaan, kun
--   1) hakija poistaa liitteen (kirjaus poistetaan ensin, sitten tiedosto), ja
--   2) lataus onnistui mutta kirjaus epäonnistui (selain poistaa orvon tiedoston).
-- Kirjattua tiedostoa ei voi poistaa, joten lähetetyn hakemuksen liitteet säilyvät.

create policy "application-documents: orvon poisto omasta luonnoksesta" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'application-documents'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1
        from public.provider_applications a
       where a.id = private.try_uuid((storage.foldername(name))[2])
         and a.user_id = (select auth.uid())
         and a.status = 'draft'
    )
    and not exists (select 1 from public.application_documents d where d.storage_path = name)
  );
