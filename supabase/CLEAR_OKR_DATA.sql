-- =====================================================================
-- Clear OKR data, keep everything else
--
-- Empties objectives, key results, check-ins, reviews, feedback and
-- performance scores so the cohort can start again.
--
-- Deliberately does NOT touch:
--   * the staff roster
--   * onboarding checklists and their progress
--   * uploaded documents, and the files themselves in storage
--   * salaries, payroll runs and payslips
--   * leave records
--   * account approvals and passwords
--
-- Run in the Supabase dashboard: SQL Editor, New query, Run.
--
-- Read section 1 before running anything else. It takes a backup, and
-- there is no undo without it.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Back up first
--
-- Forte Compass keeps its working data as a single record in the kv
-- table. This copies that record to a dated key, so the state before the
-- clear can always be recovered.
-- ---------------------------------------------------------------------
insert into kv (tenant_id, key, value, updated_at)
select
  tenant_id,
  'dataset_backup_' || to_char(now(), 'YYYYMMDD_HH24MI'),
  value,
  now()
from kv
where key = 'dataset';

-- Confirm the backup exists before going further. This must return at
-- least one row.
select key, updated_at from kv
where key like 'dataset_backup_%'
order by updated_at desc;


-- ---------------------------------------------------------------------
-- 2. Clear the OKR content
--
-- The five arrays are emptied, and every person's score, previous score
-- and RAG band are reset. Each staff record is merged rather than
-- replaced, so documents, onboarding, salary and placements survive
-- untouched inside it.
-- ---------------------------------------------------------------------
update kv
   set value = jsonb_set(
         value || '{
           "objectives": [],
           "checkins":   [],
           "reviews":    [],
           "feedback":   [],
           "hrActions":  []
         }'::jsonb,
         '{staff}',
         coalesce(
           (select jsonb_agg(person || '{"score": 0, "prev": 0, "band": "grey"}'::jsonb)
              from jsonb_array_elements(value->'staff') as person),
           '[]'::jsonb
         )
       ),
       updated_at = now()
 where key = 'dataset';


-- ---------------------------------------------------------------------
-- 3. Clear the dedicated OKR tables
--
-- These are only written to when the deployment sets VITE_USE_TABLES=on.
-- They are cleared regardless, so nothing is left behind if that is
-- switched on later. Key results are removed automatically with their
-- objective, but are deleted explicitly in case any were orphaned.
--
-- documents, salaries, leave_requests and profiles are not touched.
-- ---------------------------------------------------------------------
delete from key_results
 where objective_id in (select id from objectives);

delete from objectives;
delete from reviews;
delete from feedback;


-- =====================================================================
-- Verification
-- =====================================================================

-- All four should read 0.
select
  (select count(*) from objectives)  as objectives,
  (select count(*) from key_results) as key_results,
  (select count(*) from reviews)     as reviews,
  (select count(*) from feedback)    as feedback;

-- The working record should show empty OKR arrays, and the roster intact.
select
  jsonb_array_length(coalesce(value->'objectives', '[]'::jsonb)) as objectives,
  jsonb_array_length(coalesce(value->'checkins',   '[]'::jsonb)) as checkins,
  jsonb_array_length(coalesce(value->'reviews',    '[]'::jsonb)) as reviews,
  jsonb_array_length(coalesce(value->'feedback',   '[]'::jsonb)) as feedback,
  jsonb_array_length(coalesce(value->'staff',      '[]'::jsonb)) as staff_kept
from kv where key = 'dataset';

-- Nothing that should have survived is gone. Documents and salaries
-- should read the same as before the clear.
select
  (select count(*) from documents) as documents_kept,
  (select count(*) from salaries)  as salaries_kept;

-- Spot check one person: scores cleared, documents and onboarding kept.
select
  person->>'name'                                                as name,
  person->>'score'                                               as score,
  person->>'band'                                                as band,
  (select count(*) from jsonb_object_keys(coalesce(person->'docs', '{}'::jsonb))) as documents_on_file,
  jsonb_array_length(coalesce(person->'onboarding', '[]'::jsonb)) as checklist_items
from kv, jsonb_array_elements(value->'staff') as person
where key = 'dataset'
limit 5;


-- =====================================================================
-- If something went wrong
--
-- Put the backup back, replacing the date with the one from section 1:
--
--   update kv
--      set value = (select value from kv
--                   where key = 'dataset_backup_YYYYMMDD_HHMM'),
--          updated_at = now()
--    where key = 'dataset';
--
-- Backups are ordinary rows and cost nothing to keep. Tidy them up once
-- you are satisfied:
--
--   delete from kv where key like 'dataset_backup_%';
--
-- After running, everyone should sign out and back in, so the browser
-- picks up the cleared data rather than its own stored copy.
-- =====================================================================
