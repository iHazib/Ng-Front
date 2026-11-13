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
