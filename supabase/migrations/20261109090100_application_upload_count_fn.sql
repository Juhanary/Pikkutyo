-- Latauspolitiikan tiedostomäärän laskenta storage.objectsista aiheutti RLS-rekursion
-- (42P17), joten se tehdään security definer -funktiossa, joka ohittaa politiikat.
create or replace function private.application_document_count(p_folder text)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
    from storage.objects o
   where o.bucket_id = 'application-documents'
     and o.name like p_folder || '/%'
$$;
revoke execute on function private.application_document_count(text) from public, anon;
grant execute on function private.application_document_count(text) to authenticated;

drop policy "application-documents: lataus omaan luonnokseen" on storage.objects;
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
    and private.application_document_count((select auth.uid())::text || '/' || (storage.foldername(name))[2]) < 20
  );
