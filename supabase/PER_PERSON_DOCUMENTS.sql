-- =====================================================================
-- Per-person document storage
--
-- Fixes uploads that vanish. Until now the whole company shared a single
-- record, so when two people were onboarding at once, one browser saving
-- its copy could overwrite the other's freshly uploaded document. This
-- gives each person their own place to record documents and onboarding,
-- on their own profile row, which only they and HR can write.
--
-- Run in the Supabase dashboard: SQL Editor, New query, Run.
-- Safe to re-run.
--
-- Run staff_documents_storage.sql as well if you have not, so the files
-- themselves have a bucket to live in. This file records which documents
-- exist; that file stores the actual uploads.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Somewhere on each profile to keep documents and checklist
-- ---------------------------------------------------------------------
alter table profiles add column if not exists docs           jsonb default '{}'::jsonb;
alter table profiles add column if not exists onboarding      jsonb default '[]'::jsonb;
alter table profiles add column if not exists docs_exempt     boolean;


-- ---------------------------------------------------------------------
-- 2. A person may update their own documents; HR may update anyone's
--
-- The existing profile_self policy already lets a person write their own
-- row, and profile updates by HR are covered by is_approver in the
-- approval migration. Nothing further is needed here, but we make the
-- read explicit so HR can always see documents to verify them.
-- ---------------------------------------------------------------------
drop policy if exists profile_docs_read on profiles;
create policy profile_docs_read on profiles
  for select using (
    id = auth.uid()
    or coalesce(my_role() in ('hr', 'md', 'chairman', 'admin', 'superadmin'), false)
    or (is_active() and tenant_id = current_tenant())
  );


-- =====================================================================
-- Verification
-- =====================================================================

select column_name, data_type
from information_schema.columns
where table_name = 'profiles'
  and column_name in ('docs', 'onboarding', 'docs_exempt')
order by column_name;

-- Nobody should have lost anything. Every profile still present.
select count(*) as profiles from profiles;

-- =====================================================================
-- After running this, deploy the matching app build. The app then writes
-- each person's documents to their own row and merges everyone's back
-- together on load, so two people uploading at the same time can no
-- longer overwrite each other.
-- =====================================================================
