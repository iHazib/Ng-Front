-- Run ONLY in the development project's owner-controlled SQL Editor.
-- This is not an installer migration. It creates one membership, not an Auth user.
-- Replace both placeholders locally after checking the Auth user in Dashboard.
begin;
do $bootstrap$
declare
  candidate uuid := '7e9cf9d1-015f-4334-a812-a29bf4f7a51b'::uuid;
  expected_email text := 'mhs@ng.com.pk';
begin
  perform pg_advisory_xact_lock(73524);
  if exists(select 1 from app_private.admin_members where active) then
    raise exception 'An active admin already exists; stop and review membership instead of bootstrapping again';
  end if;
  if not exists(select 1 from auth.users where id=candidate
    and lower(email)=lower(expected_email) and email_confirmed_at is not null
    and deleted_at is null) then
    raise exception 'User UUID/email must match a confirmed, non-deleted Auth account';
  end if;
  insert into app_private.admin_members(user_id,active,reason)
    values(candidate,true,'First administrator provisioned by project owner in SQL Editor');
end $bootstrap$;
commit;
select count(*) as active_admin_count from app_private.admin_members where active;
-- Expected: 1. Do not expose app_private or grant clients INSERT on admin_members.
