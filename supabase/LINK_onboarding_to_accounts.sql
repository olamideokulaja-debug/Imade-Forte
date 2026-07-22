-- =====================================================================
-- Link onboarding to Forte Compass accounts
--
-- Problem this solves:
-- HR onboards someone and records their role, subsidiary and salary. Later
-- that person creates their own Forte Compass account. Without this, the two
-- are separate records: the new account arrives with no role, no subsidiary
-- and no salary, and the person never appears in payroll.
--
-- After this, HR's onboarding record is held against the person's email
-- address. When they sign up with that address, their account picks up
-- everything HR entered, automatically.
--
-- Run once in the Supabase dashboard: SQL Editor, New query, Run.
-- Safe to re-run.
--
-- Run FIX_signup_rls_recursion.sql first if you have not already.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Where HR's onboarding details wait until the person signs up
-- ---------------------------------------------------------------------
create table if not exists staff_invites (
  email       text primary key,
  tenant_id   text references organisations(id),
  name        text,
  title       text,
  role        text,
  subsidiary  text,
  salary      numeric default 0,
  rent        numeric default 0,
  start_date  date,
  created_by  uuid references auth.users on delete set null,
  created_at  timestamptz default now(),
  claimed_at  timestamptz
);

alter table staff_invites enable row level security;

-- Only HR and admin may prepare or read onboarding records.
drop policy if exists invites_manage on staff_invites;
create policy invites_manage on staff_invites
  for all to authenticated
  using (coalesce(my_role() in ('hr', 'admin', 'superadmin', 'md'), false))
  with check (coalesce(my_role() in ('hr', 'admin', 'superadmin', 'md'), false));

-- ---------------------------------------------------------------------
-- 2. Salary belongs on the profile, so payroll can read it
-- ---------------------------------------------------------------------
alter table profiles add column if not exists email      text;
alter table profiles add column if not exists title      text;
alter table profiles add column if not exists salary     numeric default 0;
alter table profiles add column if not exists rent       numeric default 0;
alter table profiles add column if not exists start_date date;

-- ---------------------------------------------------------------------
-- 3. On signup, claim the matching onboarding record
--
-- Matching is on email, lowercased and trimmed, so a stray capital letter or
-- trailing space does not silently break the link. If HR has not onboarded
-- the person, signup still works exactly as before and simply creates an
-- ordinary profile.
-- ---------------------------------------------------------------------
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  inv staff_invites%rowtype;
  addr text := lower(trim(new.email));
begin
  select * into inv from staff_invites
  where lower(trim(email)) = addr and claimed_at is null
  limit 1;

  insert into profiles (id, tenant_id, name, role, subsidiary, email, title, salary, rent, start_date)
  values (
    new.id,
    coalesce(inv.tenant_id, new.raw_user_meta_data->>'tenant_id', 'imade-forte'),
    coalesce(inv.name, new.raw_user_meta_data->>'name', new.email),
    coalesce(inv.role, new.raw_user_meta_data->>'role'),
    coalesce(inv.subsidiary, new.raw_user_meta_data->>'subsidiary'),
    new.email,
    inv.title,
    coalesce(inv.salary, 0),
    coalesce(inv.rent, 0),
    inv.start_date
  )
  on conflict (id) do nothing;

  if inv.email is not null then
    update staff_invites set claimed_at = now() where email = inv.email;
  end if;

  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- =====================================================================
-- Verification
-- =====================================================================

-- The table should exist.
select count(*) as invites_waiting from staff_invites where claimed_at is null;

-- The profile columns should be listed.
select column_name from information_schema.columns
where table_name = 'profiles'
  and column_name in ('email', 'title', 'salary', 'rent', 'start_date')
order by column_name;

-- The trigger should still be attached.
select tgname from pg_trigger where tgname = 'on_auth_user_created';

-- =====================================================================
-- How to test it end to end
--
-- 1. Sign in as HR, onboard a test person with a real email you control
--    and a salary
-- 2. Open that mailbox, go to the site, and create an account with the
--    same address
-- 3. Sign in. The account should already carry the right role, subsidiary
--    and salary, and the person should appear in Payroll
-- =====================================================================
