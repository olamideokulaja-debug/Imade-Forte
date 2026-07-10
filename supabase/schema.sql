-- Forte Compass — Supabase schema and tenant row-level security.
-- Run this once in the Supabase SQL editor when you connect a real backend.
-- Until then the app runs in seeded demo mode and needs none of this.

-- Organisations (tenants). Imade Forte is tenant one.
create table if not exists organisations (
  id text primary key,
  name text not null,
  brand jsonb default '{}'::jsonb,
  priorities jsonb default '[]'::jsonb,
  rubric jsonb default '{}'::jsonb,
  rag jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

-- Profiles. One per signed-in user, bound to a tenant.
create table if not exists profiles (
  id uuid primary key references auth.users on delete cascade,
  tenant_id text references organisations(id),
  name text,
  role text,          -- chairman | md | lead | staff | hr | admin | superadmin
  subsidiary text,
  cadence_tier text,  -- ops | leadership
  photo text,
  created_at timestamptz default now()
);

-- Per-tenant application data, stored as keyed JSON documents (objectives, key_results,
-- scores, cycles). A single table keeps row-level security simple and robust.
create table if not exists kv (
  tenant_id text references organisations(id),
  key text not null,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz default now(),
  primary key (tenant_id, key)
);

alter table organisations enable row level security;
alter table profiles enable row level security;
alter table kv enable row level security;

-- Helper: the tenant of the current user.
create or replace function current_tenant() returns text
language sql stable as $$
  select tenant_id from profiles where id = auth.uid()
$$;

-- A user reads and writes only their own profile, and reads peers in the same tenant.
drop policy if exists profile_self on profiles;
create policy profile_self on profiles
  for all using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists profile_peers_read on profiles;
create policy profile_peers_read on profiles
  for select using (tenant_id = current_tenant());

-- A user reads and writes only rows for their own tenant. No query crosses tenants.
drop policy if exists kv_tenant on kv;
create policy kv_tenant on kv
  for all using (tenant_id = current_tenant()) with check (tenant_id = current_tenant());

-- A user reads only their own organisation record.
drop policy if exists org_read on organisations;
create policy org_read on organisations
  for select using (id = current_tenant());

-- Seed the two tenants.
insert into organisations (id, name, brand) values
  ('imade-forte', 'Imade Forte Holdings Ltd.',
   '{"navy":"#0E2240","gold":"#B8924A","font":"Lora"}'::jsonb)
on conflict (id) do nothing;

insert into organisations (id, name, brand) values
  ('demo', 'Demo Company',
   '{"navy":"#1B2A3A","gold":"#7C8AA0","font":"Lora"}'::jsonb)
on conflict (id) do nothing;


-- =====================================================================
-- Server-enforced permissions.
-- The section above runs the app in the simple kv model. The tables and
-- policies below are the normalised, production model where role- and
-- subsidiary-based visibility is enforced by Postgres row-level security,
-- not just by the interface. Wire the client to these tables to switch on
-- database-enforced permissions.
-- =====================================================================

-- Reporting line and pay live on the profile / a protected table.
alter table profiles add column if not exists manager_id uuid references profiles(id);

-- Who is the caller?
create or replace function my_role() returns text language sql stable as $$
  select role from profiles where id = auth.uid() $$;
create or replace function my_sub() returns text language sql stable as $$
  select subsidiary from profiles where id = auth.uid() $$;
create or replace function is_oversight() returns boolean language sql stable as $$
  select coalesce(my_role() in ('chairman','md','hr','admin','superadmin'), false) $$;
create or replace function manages(target uuid) returns boolean language sql stable as $$
  select exists (select 1 from profiles p where p.id = target and p.manager_id = auth.uid()) $$;

-- Cycles: everyone in the tenant reads; oversight manages.
create table if not exists cycles (
  id uuid primary key default gen_random_uuid(),
  tenant_id text references organisations(id) default current_tenant(),
  name text not null, status text default 'active', created_at timestamptz default now());
alter table cycles enable row level security;
drop policy if exists cyc_read on cycles;
create policy cyc_read on cycles for select using (tenant_id = current_tenant());
drop policy if exists cyc_manage on cycles;
create policy cyc_manage on cycles for all
  using (tenant_id = current_tenant() and my_role() in ('md','hr','admin'))
  with check (tenant_id = current_tenant() and my_role() in ('md','hr','admin'));

-- Objectives: owner manages own; leads see their subsidiary; oversight sees all.
create table if not exists objectives (
  id uuid primary key default gen_random_uuid(),
  tenant_id text references organisations(id) default current_tenant(),
  owner_id uuid references profiles(id), subsidiary text, priority text, cycle text,
  status text default 'draft', title text, description text, score jsonb,
  created_at timestamptz default now());
alter table objectives enable row level security;
drop policy if exists obj_read on objectives;
create policy obj_read on objectives for select using (
  tenant_id = current_tenant() and (is_oversight() or owner_id = auth.uid()
  or (my_role() = 'lead' and subsidiary = my_sub())));
drop policy if exists obj_write_own on objectives;
create policy obj_write_own on objectives for all
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid() and tenant_id = current_tenant());
drop policy if exists obj_manage on objectives;
create policy obj_manage on objectives for update
  using (tenant_id = current_tenant() and (is_oversight() or (my_role() = 'lead' and subsidiary = my_sub())))
  with check (tenant_id = current_tenant());

-- Key results follow the visibility of their parent objective.
create table if not exists key_results (
  id uuid primary key default gen_random_uuid(),
  objective_id uuid references objectives(id) on delete cascade,
  statement text, kr_type text, measure text, baseline text, target text, unit text,
  current text, confidence int, due date, checkins jsonb default '[]'::jsonb);
alter table key_results enable row level security;
drop policy if exists kr_read on key_results;
create policy kr_read on key_results for select using (exists (
  select 1 from objectives o where o.id = objective_id and (is_oversight()
  or o.owner_id = auth.uid() or (my_role() = 'lead' and o.subsidiary = my_sub()))));
drop policy if exists kr_write on key_results;
create policy kr_write on key_results for all
  using (exists (select 1 from objectives o where o.id = objective_id and o.owner_id = auth.uid()))
  with check (exists (select 1 from objectives o where o.id = objective_id and o.owner_id = auth.uid()));
drop policy if exists kr_manage on key_results;
create policy kr_manage on key_results for update using (exists (
  select 1 from objectives o where o.id = objective_id
  and (is_oversight() or (my_role() = 'lead' and o.subsidiary = my_sub()))));

-- Reviews: the subject reads and acknowledges own; the reviewer and managers write.
create table if not exists reviews (
  id uuid primary key default gen_random_uuid(),
  tenant_id text references organisations(id) default current_tenant(),
  subject_id uuid references profiles(id), reviewer_id uuid references profiles(id),
  cycle text, rating text, summary text, strengths text, improvements text,
  ack boolean default false, response text, created_at timestamptz default now());
alter table reviews enable row level security;
drop policy if exists rev_read on reviews;
create policy rev_read on reviews for select using (
  tenant_id = current_tenant() and (subject_id = auth.uid() or reviewer_id = auth.uid()
  or is_oversight() or manages(subject_id)));
drop policy if exists rev_write on reviews;
create policy rev_write on reviews for insert with check (
  tenant_id = current_tenant() and reviewer_id = auth.uid()
  and (is_oversight() or manages(subject_id)));
drop policy if exists rev_update on reviews;
create policy rev_update on reviews for update using (
  subject_id = auth.uid() or reviewer_id = auth.uid() or is_oversight());

-- Feedback: recipient and author read; anyone in the tenant can send.
create table if not exists feedback (
  id uuid primary key default gen_random_uuid(),
  tenant_id text references organisations(id) default current_tenant(),
  to_id uuid references profiles(id), from_id uuid references profiles(id),
  text text, created_at timestamptz default now());
alter table feedback enable row level security;
drop policy if exists fb_read on feedback;
create policy fb_read on feedback for select using (
  tenant_id = current_tenant() and (to_id = auth.uid() or from_id = auth.uid() or is_oversight()));
drop policy if exists fb_write on feedback;
create policy fb_write on feedback for insert
  with check (tenant_id = current_tenant() and from_id = auth.uid());

-- Leave: the requester manages own; the MD (with HR and admin) approves.
create table if not exists leave_requests (
  id uuid primary key default gen_random_uuid(),
  tenant_id text references organisations(id) default current_tenant(),
  staff_id uuid references profiles(id), type text, start_date date, end_date date,
  days int, reason text, status text default 'pending',
  decided_by uuid references profiles(id), decided_at date, note text,
  created_at timestamptz default now());
alter table leave_requests enable row level security;
drop policy if exists lv_read on leave_requests;
create policy lv_read on leave_requests for select using (
  tenant_id = current_tenant() and (staff_id = auth.uid() or my_role() in ('md','hr','admin')));
drop policy if exists lv_request on leave_requests;
create policy lv_request on leave_requests for insert
  with check (tenant_id = current_tenant() and staff_id = auth.uid());
drop policy if exists lv_decide on leave_requests;
create policy lv_decide on leave_requests for update
  using (tenant_id = current_tenant() and my_role() in ('md','hr','admin'));

-- Pay: only the MD, HR and admin; a person may read their own line.
create table if not exists salaries (
  staff_id uuid primary key references profiles(id),
  tenant_id text references organisations(id) default current_tenant(),
  gross_monthly numeric default 0, annual_rent numeric default 0,
  updated_at timestamptz default now());
alter table salaries enable row level security;
drop policy if exists sal_self on salaries;
create policy sal_self on salaries for select using (staff_id = auth.uid());
drop policy if exists sal_manage on salaries;
create policy sal_manage on salaries for all
  using (tenant_id = current_tenant() and my_role() in ('md','hr','admin'))
  with check (tenant_id = current_tenant() and my_role() in ('md','hr','admin'));

-- Documents: the subject reads own; the MD, HR and admin manage all.
create table if not exists documents (
  id uuid primary key default gen_random_uuid(),
  tenant_id text references organisations(id) default current_tenant(),
  staff_id uuid references profiles(id), name text, category text, storage_path text,
  size bigint, uploaded_by uuid references profiles(id), uploaded_at timestamptz default now());
alter table documents enable row level security;
drop policy if exists doc_read on documents;
create policy doc_read on documents for select using (
  tenant_id = current_tenant() and (staff_id = auth.uid() or my_role() in ('md','hr','admin')));
drop policy if exists doc_manage on documents;
create policy doc_manage on documents for all
  using (tenant_id = current_tenant() and my_role() in ('md','hr','admin'))
  with check (tenant_id = current_tenant() and my_role() in ('md','hr','admin'));
