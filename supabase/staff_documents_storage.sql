-- =====================================================================
-- Staff document storage for Forte Compass
--
-- Creates a private bucket for employment documents: certificates, NYSC,
-- SSCE, IDs, guarantor forms and so on. These are sensitive personal
-- records, so nothing here is public and staff can only reach their own.
--
-- Run once in the Supabase dashboard: SQL Editor, New query, Run.
-- Safe to re-run.
--
-- Without this, onboarding still works: HR can mark a document as received
-- and track progress. Only the actual file upload needs the bucket.
-- =====================================================================

insert into storage.buckets (id, name, public)
values ('staff-docs', 'staff-docs', false)
on conflict (id) do nothing;

-- Files are stored under a folder named after the person's id, so the first
-- path segment identifies the owner.

-- A person may upload their own documents. HR and admin may upload for anyone.
drop policy if exists staffdocs_write on storage.objects;
create policy staffdocs_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'staff-docs'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or coalesce(my_role() in ('hr', 'admin', 'superadmin'), false)
    )
  );

drop policy if exists staffdocs_update on storage.objects;
create policy staffdocs_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'staff-docs'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or coalesce(my_role() in ('hr', 'admin', 'superadmin'), false)
    )
  );

-- A person may read their own documents. HR and admin may read all, because
-- they verify them. Nobody else can read anyone's records.
drop policy if exists staffdocs_read on storage.objects;
create policy staffdocs_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'staff-docs'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or coalesce(my_role() in ('hr', 'admin', 'superadmin'), false)
    )
  );

-- Only HR and admin may delete, so a record cannot be quietly removed by the
-- person it concerns.
drop policy if exists staffdocs_delete on storage.objects;
create policy staffdocs_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'staff-docs'
    and coalesce(my_role() in ('hr', 'admin', 'superadmin'), false)
  );

-- =====================================================================
-- Verification
-- =====================================================================

select id, public from storage.buckets where id = 'staff-docs';

select policyname from pg_policies
where schemaname = 'storage' and tablename = 'objects'
  and policyname like 'staffdocs%'
order by policyname;
