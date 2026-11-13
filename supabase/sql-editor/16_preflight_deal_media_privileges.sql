-- READ ONLY. New permission correction only; never rerun 017.
select exists(select 1 from app_private.sql_editor_receipts where version='202610160017' and sha256='dfdae129e62884b12d58e0bb43f628a7b9dece652dc413c789af3a381db8c7e7') prerequisite_017,
 exists(select 1 from app_private.sql_editor_receipts where version='202610180018') correction_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610180018' and sha256='6bcb154fd582e4809cefbdb89d2c054e127f12fb3daf38ce7715ea36597958a3') correction_receipt_matches,
 (select relrowsecurity and not relforcerowsecurity from pg_class where oid='public.deal_media'::regclass) media_rls_unchanged,
 (select count(*)=2 from pg_policies where schemaname='public' and tablename='deal_media' and cmd='SELECT' and policyname in('admin_read','public_read')) media_read_policies_present,
 has_table_privilege('anon','public.deal_media','SELECT') and has_table_privilege('authenticated','public.deal_media','SELECT') public_select_preserved,
 not exists(select 1 from (values('anon'),('authenticated')) r(role_name) cross join (values('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),('REFERENCES'),('TRIGGER')) p(priv) where has_table_privilege(r.role_name,'public.deal_media',p.priv)) no_extra_client_privileges;
