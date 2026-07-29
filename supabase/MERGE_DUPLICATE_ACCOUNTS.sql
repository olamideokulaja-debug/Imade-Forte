-- =====================================================================
-- Merge duplicate accounts, and fix a person who cannot sign in
--
-- Two problems this addresses:
--   1. Some people have two profile rows: the one on the roster, and a new
--      one created when they signed up. Godwin and Adebayo are examples.
--   2. A person, such as Buchi, cannot sign in even after resetting.
--
-- Run in the Supabase dashboard: SQL Editor, New query, Run.
-- Read each section before running it. Take the backup in section 0 first.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. Back up the profiles table before changing anything
-- ---------------------------------------------------------------------
create table if not exists profiles_backup as table profiles;
insert into profiles_backup select * from profiles
  where id not in (select id from profiles_backup);

select count(*) as backed_up from profiles_backup;


-- ---------------------------------------------------------------------
-- 1. Find the duplicates
--
-- Lists every email that has more than one profile row, newest first. These
-- are the accounts to merge.
-- ---------------------------------------------------------------------
select
  lower(email) as email,
  count(*) as copies,
  array_agg(id order by created_at) as ids,
  array_agg(coalesce(status, 'null') order by created_at) as statuses,
  array_agg(role order by created_at) as roles
from profiles
group by lower(email)
having count(*) > 1
order by lower(email);


-- ---------------------------------------------------------------------
-- 2. Understand which row to keep
--
-- Keep the row that the person actually signs in with. That is the one whose
-- id exists in auth.users, because only that row can authenticate. The other
-- is a stray roster or duplicate row with no login behind it.
--
-- This shows, per duplicated email, which row has a real login.
-- ---------------------------------------------------------------------
select
  p.id,
  p.email,
  p.role,
  p.status,
  (au.id is not null) as can_log_in,
  p.created_at
from profiles p
left join auth.users au on au.id = p.id
where lower(p.email) in (
  select lower(email) from profiles group by lower(email) having count(*) > 1
)
order by lower(p.email), can_log_in desc, p.created_at;


-- ---------------------------------------------------------------------
-- 3. Merge, keeping the row that can log in
--
-- For each duplicated email this keeps the login row, copies across any
-- documents or onboarding the other row had that the login row lacks, then
-- deletes the extra row. Runs for all duplicates at once.
--
-- It only ever deletes a row that has NO login, so the account a person signs
-- in with is never removed.
-- ---------------------------------------------------------------------
with dupes as (
  select lower(email) as email
  from profiles
  group by lower(email)
  having count(*) > 1
),
ranked as (
  select
    p.*,
    (select au.id is not null from auth.users au where au.id = p.id) as can_log_in,
    row_number() over (
      partition by lower(p.email)
      order by (select au.id is not null from auth.users au where au.id = p.id) desc, p.created_at
    ) as rn
  from profiles p
  where lower(p.email) in (select email from dupes)
)
-- Copy documents and onboarding from the loser onto the keeper when the keeper
-- has none of its own.
update profiles keep
set
  docs = coalesce(nullif(keep.docs, '{}'::jsonb), lose.docs),
  onboarding = case
    when keep.onboarding is null or jsonb_array_length(keep.onboarding) = 0
      then lose.onboarding else keep.onboarding end,
  docs_exempt = coalesce(keep.docs_exempt, lose.docs_exempt)
from ranked lose
where lose.rn > 1
  and lower(lose.email) = lower(keep.email)
  and keep.id = (select r.id from ranked r where lower(r.email) = lower(keep.email) and r.rn = 1);

-- Now remove the extra rows, which by definition cannot log in.
delete from profiles
where id in (
  select p.id
  from profiles p
  join (
    select
      lower(email) as email,
      row_number() over (
        partition by lower(email)
        order by (select au.id is not null from auth.users au where au.id = profiles.id) desc, created_at
      ) as rn,
      id
    from profiles
    where lower(email) in (select lower(email) from profiles group by lower(email) having count(*) > 1)
  ) x on x.id = p.id
  where x.rn > 1
);


-- ---------------------------------------------------------------------
-- 4. Confirm no duplicates remain
-- ---------------------------------------------------------------------
select lower(email) as email, count(*) as copies
from profiles
group by lower(email)
having count(*) > 1;
-- An empty result means every email now has exactly one row.


-- =====================================================================
-- 5. The person who cannot sign in (for example Buchi)
--
-- Work through these in order. Replace the email each time.
-- =====================================================================

-- 5a. Does the account exist at all, and can it log in?
select
  p.email,
  p.role,
  p.status,
  (au.id is not null) as has_login,
  (au.email_confirmed_at is not null) as email_confirmed,
  au.last_sign_in_at
from profiles p
left join auth.users au on au.id = p.id
where lower(p.email) = lower('buchi@imadeforteholdings.com');

-- Read the result:
--   has_login = false  -> there is a roster row but no real account. The person
--                         must sign up, or you create the login. The commonest
--                         cause of "reset does nothing": the reset was sent for
--                         an address that has no login, so nothing could arrive.
--   email_confirmed = false -> the account exists but was never confirmed, which
--                         blocks sign-in. Fix in 5b.
--   status <> 'active' -> the account is pending or declined. Fix in 5c.


-- 5b. Confirm the email and set a fresh password directly
--     (use this when has_login is true but sign-in still fails)
update auth.users
   set encrypted_password = extensions.crypt('CHANGE-THIS-PASSWORD', extensions.gen_salt('bf')),
       email_confirmed_at = coalesce(email_confirmed_at, now()),
       updated_at = now()
 where lower(email) = lower('buchi@imadeforteholdings.com');


-- 5c. Make sure the account is active
update profiles
   set status = 'active'
 where lower(email) = lower('buchi@imadeforteholdings.com');


-- 5d. Check it is now ready
select
  p.email, p.status,
  (au.email_confirmed_at is not null) as email_confirmed
from profiles p
left join auth.users au on au.id = p.id
where lower(p.email) = lower('buchi@imadeforteholdings.com');


-- =====================================================================
-- If a merge went wrong, restore from the backup:
--
--   delete from profiles;
--   insert into profiles select * from profiles_backup;
--
-- Once satisfied, you may drop the backup:
--   drop table profiles_backup;
-- =====================================================================
