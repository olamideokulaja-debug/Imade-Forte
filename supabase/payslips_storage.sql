-- =====================================================================
-- Payslip storage for Forte Compass
--
-- Creates a private bucket for payslip PDFs and restricts who may write to
-- it. Files are never public: the app hands each person a signed link that
-- expires, and the link is emailed to them individually.
--
-- Run once in the Supabase dashboard: SQL Editor, New query, Run.
-- Safe to re-run.
-- =====================================================================

-- Private bucket. public = false means no file is readable by URL alone.
insert into storage.buckets (id, name, public)
values ('payslips', 'payslips', false)
on conflict (id) do nothing;

-- Only payroll roles may write payslips into the bucket.
drop policy if exists payslips_write on storage.objects;
create policy payslips_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'payslips'
    and coalesce(my_role() in ('accountant', 'hr', 'admin', 'superadmin'), false)
  );

drop policy if exists payslips_update on storage.objects;
create policy payslips_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'payslips'
    and coalesce(my_role() in ('accountant', 'hr', 'admin', 'superadmin'), false)
  );

-- Payroll roles may list and read directly. Everyone else receives a signed
-- link instead, which does not require a read policy.
drop policy if exists payslips_read on storage.objects;
create policy payslips_read on storage.objects
  for select to authenticated
  using (
    bucket_id = 'payslips'
    and coalesce(my_role() in ('accountant', 'hr', 'admin', 'superadmin'), false)
  );

-- ---------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------

-- The bucket should exist and be private.
select id, public from storage.buckets where id = 'payslips';

-- Three policies should be listed.
select policyname from pg_policies
where schemaname = 'storage' and tablename = 'objects'
  and policyname like 'payslips%'
order by policyname;
