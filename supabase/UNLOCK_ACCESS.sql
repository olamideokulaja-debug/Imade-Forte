-- =====================================================================
-- UNLOCK: restore access after the approval upgrade
--
-- Run this first, before anything else, if you cannot sign in.
--
-- What went wrong: the approval upgrade added a "status" column to
-- profiles with a default of 'pending'. A default applies to every
-- existing row as well as new ones, so every account that already
-- existed, including the Chairman's, was marked as waiting for approval.
-- Nobody was left who could approve anybody.
--
-- This file puts the existing accounts back to active. New accounts
-- created from now on still arrive pending, which is the intended
-- behaviour.
--
-- Safe to re-run.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Who is actually in the system?
--
-- Run this on its own first if you are not sure which account is yours.
-- It lists every account with its email, role and current state.
-- ---------------------------------------------------------------------
select
  email,
  name,
  role,
  status,
  created_at
from profiles
order by
  case role
    when 'chairman'   then 1
    when 'md'         then 2
    when 'hr'         then 3
    when 'accountant' then 4
    else 5
  end,
  created_at;


-- ---------------------------------------------------------------------
-- 2. Put every account that existed before today back to active
--
-- Anyone already in the system was, by definition, already approved.
-- Only accounts created after this point should have to wait.
-- ---------------------------------------------------------------------
update profiles
   set status = 'active'
 where status = 'pending'
   and created_at < now() - interval '1 minute';


-- ---------------------------------------------------------------------
-- 3. Make sure there is a Chairman, and that it is active
--
-- Replace the address below with the email you actually sign in with,
-- then run this block. If you are not sure, read the list from step 1.
-- ---------------------------------------------------------------------
update profiles
   set status = 'active',
       role   = 'chairman'
 where lower(email) = lower('CHANGE_ME@imadeforteholdings.com');


-- ---------------------------------------------------------------------
-- 4. Safety net
--
-- If after all of the above there is still nobody who can approve
-- accounts, promote the oldest account so the group is never locked out
-- of its own system.
-- ---------------------------------------------------------------------
do $$
declare
  promoted text;
begin
  if not exists (
    select 1 from profiles
    where status = 'active'
      and role in ('hr', 'md', 'chairman', 'admin', 'superadmin')
  ) then
    update profiles
       set status = 'active', role = 'admin'
     where id = (select id from profiles order by created_at asc limit 1)
    returning email into promoted;
    raise notice 'No approver existed. % has been made an admin.', promoted;
  end if;
end $$;


-- =====================================================================
-- Check it worked
-- =====================================================================

-- Every account and its state. Nobody who should be working should read
-- 'pending' here.
select email, role, status from profiles order by role, email;

-- Who can approve new accounts. This must not be empty.
select email, role from profiles
where status = 'active'
  and role in ('hr', 'md', 'chairman', 'admin', 'superadmin')
order by role;

-- =====================================================================
-- Then sign in again. If it still refuses, the account may simply not
-- exist yet in this project: create it through the normal sign-up, then
-- run step 3 with that address.
-- =====================================================================
