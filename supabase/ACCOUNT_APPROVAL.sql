-- =====================================================================
-- Forte Compass: account approval, biodata, and who may approve
--
-- Makes the approval queue real. Without this, a new account can sign in
-- the moment it is created, and the biodata collected at signup lives only
-- in the browser.
--
-- After this:
--   * every new account arrives as 'pending' and can see nothing but its
--     own pending notice
--   * the biodata captured at signup is stored against the person
--   * only HR, the Managing Director, the Chairman or an admin can approve
--   * approving is a single function call that is recorded, not a free edit
--
-- Run in the Supabase dashboard: SQL Editor, New query, Run.
-- Safe to re-run.
--
-- ORDER: run FIX_signup_rls_recursion.sql first, then
-- LINK_onboarding_to_accounts.sql, then this file.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Status and biodata on the profile
--
-- The profile is the record. A separate pending table would mean the same
-- person existing twice, and the two drifting apart.
-- ---------------------------------------------------------------------
-- Added in two steps on purpose. A column created with a default applies
-- that default to every existing row, which would mark the whole company
-- as waiting for approval and leave nobody able to approve anyone. So the
-- column is added empty, existing people are set active, and only then
-- does 'pending' become the default for accounts created afterwards.
alter table profiles add column if not exists status text;
update profiles set status = 'active' where status is null;
alter table profiles alter column status set default 'pending';
alter table profiles alter column status set not null;
alter table profiles add column if not exists biodata     jsonb;
alter table profiles add column if not exists approved_by uuid references auth.users on delete set null;
alter table profiles add column if not exists approved_at timestamptz;
alter table profiles add column if not exists decline_reason text;

-- Only three states are meaningful. Anything else is a bug, so refuse it.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_status_check') then
    alter table profiles add constraint profiles_status_check
      check (status in ('pending', 'active', 'declined'));
  end if;
end $$;

create index if not exists profiles_status_idx on profiles (status);


-- ---------------------------------------------------------------------
-- 2. Helpers
--
-- SECURITY DEFINER for the same reason as current_tenant(): these are
-- called from inside policies on profiles, so an ordinary read would
-- re-trigger the policy and recurse.
-- ---------------------------------------------------------------------

-- Is the caller a fully approved member of staff?
create or replace function is_active() returns boolean
language sql stable
security definer set search_path = public as $$
  select coalesce((select status = 'active' from profiles where id = auth.uid()), false)
$$;

-- May the caller approve other people's accounts?
create or replace function is_approver() returns boolean
language sql stable
security definer set search_path = public as $$
  select coalesce((
    select status = 'active' and role in ('hr', 'md', 'chairman', 'admin', 'superadmin')
    from profiles where id = auth.uid()
  ), false)
$$;


-- ---------------------------------------------------------------------
-- 3. New accounts arrive pending, carrying their biodata
--
-- If HR has already onboarded the person (staff_invites), the account is
-- activated straight away: HR entering their details IS the approval, and
-- asking for it twice only creates a queue nobody clears.
-- ---------------------------------------------------------------------
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  inv  staff_invites%rowtype;
  addr text := lower(trim(new.email));
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  select * into inv from staff_invites
  where lower(trim(email)) = addr and claimed_at is null
  limit 1;

  insert into profiles (
    id, tenant_id, name, role, subsidiary, email, title,
    salary, rent, start_date, biodata, status
  )
  values (
    new.id,
    coalesce(inv.tenant_id, meta->>'tenant_id', 'imade-forte'),
    coalesce(inv.name, meta->>'name', new.email),
    coalesce(inv.role, meta->>'role', 'staff'),
    coalesce(inv.subsidiary, meta->>'subsidiary'),
    new.email,
    coalesce(inv.title, meta->>'title'),
    coalesce(inv.salary, 0),
    coalesce(inv.rent, 0),
    inv.start_date,
    nullif(meta->'biodata', 'null'::jsonb),
    case when inv.email is not null then 'active' else 'pending' end
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


-- ---------------------------------------------------------------------
-- 4. What a pending account can reach: its own row, and nothing else
--
-- The existing profile_self policy already covers a person's own row.
-- profile_peers_read is replaced so that seeing colleagues requires being
-- approved, and so approvers can see everyone waiting.
-- ---------------------------------------------------------------------
drop policy if exists profile_peers_read on profiles;
create policy profile_peers_read on profiles
  for select using (
    id = auth.uid()
    or (is_active() and tenant_id = current_tenant())
    or is_approver()
  );

-- A person may edit their own row, but must never set their own status or
-- role. Approval is the approver's act, not a self-service field.
drop policy if exists profile_self on profiles;
create policy profile_self on profiles
  for update using (id = auth.uid())
  with check (
    id = auth.uid()
    and status  is not distinct from (select p.status from profiles p where p.id = auth.uid())
    and role    is not distinct from (select p.role   from profiles p where p.id = auth.uid())
    and salary  is not distinct from (select p.salary from profiles p where p.id = auth.uid())
  );

drop policy if exists profile_insert_self on profiles;
create policy profile_insert_self on profiles
  for insert with check (id = auth.uid());


-- ---------------------------------------------------------------------
-- 5. Approving and declining
--
-- Done through functions rather than a direct update, so the rule about
-- who may approve lives in one place and every decision is stamped.
-- ---------------------------------------------------------------------
create or replace function approve_account(target uuid, new_role text default null)
returns profiles
language plpgsql security definer set search_path = public as $$
declare
  out_row profiles%rowtype;
begin
  if not is_approver() then
    raise exception 'Only HR, the Managing Director, the Chairman or an admin can approve accounts.'
      using errcode = '42501';
  end if;
  if target = auth.uid() then
    raise exception 'You cannot approve your own account.' using errcode = '42501';
  end if;

  update profiles
     set status = 'active',
         role = coalesce(nullif(new_role, ''), role),
         approved_by = auth.uid(),
         approved_at = now(),
         decline_reason = null
   where id = target
  returning * into out_row;

  if out_row.id is null then
    raise exception 'No such account.' using errcode = 'P0002';
  end if;
  return out_row;
end $$;

create or replace function decline_account(target uuid, reason text default null)
returns profiles
language plpgsql security definer set search_path = public as $$
declare
  out_row profiles%rowtype;
begin
  if not is_approver() then
    raise exception 'Only HR, the Managing Director, the Chairman or an admin can decline accounts.'
      using errcode = '42501';
  end if;

  update profiles
     set status = 'declined',
         approved_by = auth.uid(),
         approved_at = now(),
         decline_reason = reason
   where id = target
  returning * into out_row;

  if out_row.id is null then
    raise exception 'No such account.' using errcode = 'P0002';
  end if;
  return out_row;
end $$;

revoke all on function approve_account(uuid, text) from public;
revoke all on function decline_account(uuid, text) from public;
grant execute on function approve_account(uuid, text) to authenticated;
grant execute on function decline_account(uuid, text) to authenticated;


-- ---------------------------------------------------------------------
-- 6. The first approvers
--
-- Everyone starts pending, including the first person to sign up, so
-- without this nobody could ever approve anybody. Set the accounts that
-- should be live from the start.
--
-- Edit the addresses below to the real ones before running, then run this
-- block again after those people have created their accounts.
-- ---------------------------------------------------------------------
update profiles
   set status = 'active',
       role = case lower(email)
                when 'olamide@imadeforteholdings.com' then 'chairman'
                when 'jennifer@imadeforteholdings.com' then 'md'
                when 'hr@imadeforteholdings.com' then 'hr'
                when 'accounts@imadeforteholdings.com' then 'accountant'
                else role
              end
 where lower(email) in (
   'olamide@imadeforteholdings.com',
   'jennifer@imadeforteholdings.com',
   'hr@imadeforteholdings.com',
   'accounts@imadeforteholdings.com'
 );

-- Safety net: if no active approver exists at all, promote the oldest
-- account so the group is never locked out of its own system.
do $$
begin
  if not exists (
    select 1 from profiles
    where status = 'active' and role in ('hr', 'md', 'chairman', 'admin', 'superadmin')
  ) then
    update profiles
       set status = 'active', role = 'admin'
     where id = (select id from profiles order by created_at asc limit 1);
    raise notice 'No approver existed. The oldest account has been made an admin so approvals can begin.';
  end if;
end $$;


-- =====================================================================
-- Verification
-- =====================================================================

-- Accounts by state.
select status, count(*) from profiles group by status order by status;

-- Who can approve. This must not be empty.
select email, role, status from profiles
where status = 'active' and role in ('hr', 'md', 'chairman', 'admin', 'superadmin')
order by role;

-- Anyone waiting.
select email, name, role, subsidiary, created_at
from profiles where status = 'pending' order by created_at;

-- The five functions should all report prosecdef = true.
select proname, prosecdef from pg_proc
where proname in ('is_active', 'is_approver', 'approve_account', 'decline_account', 'handle_new_user')
order by proname;


-- =====================================================================
-- How to test
--
-- 1. Sign up with an address you control. You should land on the pending
--    notice and be able to see nothing else.
-- 2. Sign in as an approver. The account should appear in Approvals with
--    the biodata attached.
-- 3. Approve it. The first account should now reach the workspace.
-- 4. Confirm a pending account still cannot read the staff list:
--       select count(*) from profiles;
--    signed in as the pending user should return 1, their own row.
-- =====================================================================
