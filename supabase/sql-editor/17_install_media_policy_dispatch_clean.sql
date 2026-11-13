-- Apply ONCE: incremental 019 only. Do not rerun 017 or 018.
-- ALTER POLICY rebinds the helper while preserving each complete existing predicate.
-- No destructive data statements; no grant expansion or RLS bypass.
begin;
set local lock_timeout='5s';
do $guard$ begin
 if not exists(select 1 from app_private.sql_editor_receipts where version='202610180018' and sha256='6bcb154fd582e4809cefbdb89d2c054e127f12fb3daf38ce7715ea36597958a3') then raise exception 'Confirm canonical 018 first';end if;
 if exists(select 1 from app_private.sql_editor_receipts where version='202610180019') then raise exception '019 already installed; do not rerun';end if;
end $guard$;
-- 019: rebind existing policy OIDs after 017 renamed the legacy helper.
-- No rows, grants, RLS settings, roles or visibility predicates are changed.
do $rebind$
declare p record; expression text; changed integer=0;
begin
 for p in select pol.oid,pol.polname,pol.polrelid,pg_get_expr(pol.polqual,pol.polrelid) predicate
 from pg_policy pol join pg_depend d on d.classid='pg_policy'::regclass and d.objid=pol.oid
 where d.refclassid='pg_proc'::regclass and d.refobjid='app_private.media_is_public_016(uuid)'::regprocedure
 loop
  if p.polname<>'public_read' or p.polrelid not in('public.product_media'::regclass,'public.article_media'::regclass,'public.homepage_selections'::regclass,'public.homepage_media'::regclass,'public.review_media'::regclass) then
   raise exception 'Unexpected legacy media policy dependency; inspect before proceeding';
  end if;
  expression=replace(p.predicate,'app_private.media_is_public_016(', 'public.media_is_public(');
  if expression=p.predicate then raise exception 'Unrecognized legacy policy expression';end if;
  execute format('alter policy %I on %s using (%s)',p.polname,p.polrelid::regclass,expression);
  changed=changed+1;
 end loop;
 if changed<>5 then raise exception 'Expected exactly five legacy media policies, found %',changed;end if;
end $rebind$;

insert into app_private.sql_editor_receipts(version,filename,sha256) values('202610180019','202610180019_media_policy_dispatch.sql','19ee24e376d66ad9dca4e09cc5bec42b1a703e3dfb69011849eef0dd8796623c');
notify pgrst,'reload schema';
commit;
-- READ ONLY. Before installation: prerequisite_018 and helper/privacy flags true;
-- correction flags false, legacy_policy_count=5, dispatcher_policy_count=0.
select exists(select 1 from app_private.sql_editor_receipts where version='202610180018' and sha256='6bcb154fd582e4809cefbdb89d2c054e127f12fb3daf38ce7715ea36597958a3') prerequisite_018,
 exists(select 1 from app_private.sql_editor_receipts where version='202610180019') correction_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610180019' and sha256='19ee24e376d66ad9dca4e09cc5bec42b1a703e3dfb69011849eef0dd8796623c') receipt_matches,
 (select count(*) from pg_depend d join pg_policy p on d.classid='pg_policy'::regclass and d.objid=p.oid where d.refclassid='pg_proc'::regclass and d.refobjid='app_private.media_is_public_016(uuid)'::regprocedure) legacy_policy_count,
 (select count(*) from pg_depend d join pg_policy p on d.classid='pg_policy'::regclass and d.objid=p.oid where d.refclassid='pg_proc'::regclass and d.refobjid='public.media_is_public(uuid)'::regprocedure and p.polname='public_read' and p.polrelid in('public.product_media'::regclass,'public.article_media'::regclass,'public.homepage_selections'::regclass,'public.homepage_media'::regclass,'public.review_media'::regclass)) dispatcher_policy_count,
 not exists(select 1 from (values('anon'),('authenticated'),('service_role')) r(role_name) where has_function_privilege(r.role_name,'app_private.media_is_public_016(uuid)','EXECUTE')) legacy_helper_private,
 has_function_privilege('anon','public.media_is_public(uuid)','EXECUTE') and has_function_privilege('authenticated','public.media_is_public(uuid)','EXECUTE') public_helper_accessible,
 (select bool_and(relrowsecurity and not relforcerowsecurity) from pg_class where oid in('public.product_media'::regclass,'public.article_media'::regclass,'public.homepage_selections'::regclass,'public.homepage_media'::regclass,'public.review_media'::regclass)) five_tables_rls_enabled;
