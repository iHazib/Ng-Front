-- Apply ONCE. Incremental 018 fixes observed hosted default table privileges.
-- Keeps service_role, owners, data, RLS, policies and all installed 017 functions unchanged.
begin;
set local lock_timeout='5s';
do $guard$ begin
 if not exists(select 1 from app_private.sql_editor_receipts where version='202610160017' and sha256='dfdae129e62884b12d58e0bb43f628a7b9dece652dc413c789af3a381db8c7e7') then raise exception 'Confirm canonical 017 first';end if;
 if exists(select 1 from app_private.sql_editor_receipts where version='202610180018') then raise exception '018 already installed; inspect state, do not rerun';end if;
end $guard$;
-- 018 permission-only correction for the 017 media table. No data/RLS/policy changes.
revoke all on table public.deal_media from anon,authenticated;
grant select on table public.deal_media to anon,authenticated;

insert into app_private.sql_editor_receipts(version,filename,sha256) values('202610180018','202610180018_deal_media_privileges.sql','6bcb154fd582e4809cefbdb89d2c054e127f12fb3daf38ce7715ea36597958a3');
notify pgrst,'reload schema';
commit;
-- READ ONLY. New permission correction only; never rerun 017.
select exists(select 1 from app_private.sql_editor_receipts where version='202610160017' and sha256='dfdae129e62884b12d58e0bb43f628a7b9dece652dc413c789af3a381db8c7e7') prerequisite_017,
 exists(select 1 from app_private.sql_editor_receipts where version='202610180018') correction_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610180018' and sha256='6bcb154fd582e4809cefbdb89d2c054e127f12fb3daf38ce7715ea36597958a3') correction_receipt_matches,
 (select relrowsecurity and not relforcerowsecurity from pg_class where oid='public.deal_media'::regclass) media_rls_unchanged,
 (select count(*)=2 from pg_policies where schemaname='public' and tablename='deal_media' and cmd='SELECT' and policyname in('admin_read','public_read')) media_read_policies_present,
 has_table_privilege('anon','public.deal_media','SELECT') and has_table_privilege('authenticated','public.deal_media','SELECT') public_select_preserved,
 not exists(select 1 from (values('anon'),('authenticated')) r(role_name) cross join (values('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),('REFERENCES'),('TRIGGER')) p(priv) where has_table_privilege(r.role_name,'public.deal_media',p.priv)) no_extra_client_privileges;
