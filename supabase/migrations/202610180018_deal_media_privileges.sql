-- 018 permission-only correction for the 017 media table. No data/RLS/policy changes.
revoke all on table public.deal_media from anon,authenticated;
grant select on table public.deal_media to anon,authenticated;
