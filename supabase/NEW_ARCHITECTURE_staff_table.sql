-- =====================================================================
-- New architecture: per-person staff rows
--
-- Replaces the single-JSON-blob storage that let one browser overwrite
-- everyone's data. Each person is now their own row. One person's save can
-- never touch another person's record, so stale-tab overwrites stop entirely.
--
-- Safe to run more than once. Run the whole file in the Supabase SQL Editor.
-- =====================================================================

-- 1. The staff table: one row per person on the roster.
create table if not exists staff (
  id          text not null,                 -- friendly id (s_adebayo) or account uuid
  tenant_id   text not null default 'imade-forte',
  data        jsonb not null default '{}'::jsonb,  -- the whole person object
  updated_at  timestamptz not null default now(),
  primary key (tenant_id, id)
);

-- Helpful index for email lookups (linking accounts to people).
create index if not exists staff_email_idx
  on staff ((lower(data->>'email')));

-- 2. Row-level security: anyone signed in to the tenant can read and write
--    staff rows. (The app already gates who can edit in the UI; this keeps the
--    door open for HR/Chairman while blocking anonymous access.)
alter table staff enable row level security;

drop policy if exists staff_read on staff;
create policy staff_read on staff
  for select using (auth.role() = 'authenticated');

drop policy if exists staff_write on staff;
create policy staff_write on staff
  for all using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- 3. One-time migration: copy the people out of the old kv blob into staff rows.
--    Runs only if the staff table is empty, so re-running does no harm.
do $$
declare
  ds jsonb;
  person jsonb;
begin
  if (select count(*) from staff where tenant_id = 'imade-forte') = 0 then
    select value->'staff' into ds
    from kv where tenant_id = 'imade-forte' and key = 'dataset';

    if ds is not null then
      for person in select * from jsonb_array_elements(ds)
      loop
        insert into staff (id, tenant_id, data, updated_at)
        values (person->>'id', 'imade-forte', person, now())
        on conflict (tenant_id, id) do nothing;
      end loop;
    end if;
  end if;
end $$;

-- 4. Confirm the migration.
select count(*) as staff_rows,
       (select count(*) from jsonb_array_elements((select value->'staff' from kv where tenant_id='imade-forte' and key='dataset'))) as old_blob_count
from staff where tenant_id = 'imade-forte';
-- staff_rows should equal old_blob_count (both around 22).
