-- READ ONLY. Run in a NEW development SQL Editor query BEFORE installation.
-- Missing PostgREST endpoints do not prove these private objects are absent.
-- If ANY storefront object/receipt is present, stop; do not run installer 07.
select
 to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,text)') is not null as prerequisite_008_present,
 to_regclass('public.catalog_search_aliases') is not null as aliases_present,
 to_regclass('app_private.storefront_attributes') is not null as attributes_present,
 to_regclass('app_private.storefront_search') is not null as search_present,
 to_regclass('app_private.storefront_variants') is not null as variants_projection_present,
 to_regprocedure('public.storefront_navigation()') is not null as navigation_present,
 to_regprocedure('public.storefront_catalog(text,text[],text,jsonb,text,integer,integer,text,boolean)') is not null as catalog_present,
 exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='app_private' and p.proname in('refresh_storefront_search','refresh_storefront_trigger','matches_storefront_query','storefront_filter_match')) as private_functions_present,
 exists(select 1 from pg_trigger where tgname='refresh_storefront_search' and not tgisinternal) as search_triggers_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610070009') as receipt_009_present,
 (select jsonb_build_object('version',version,'filename',filename,'sha256',sha256,'applied_at',applied_at)
   from app_private.sql_editor_receipts where version='202610070009') as receipt_009,
 (select relrowsecurity from pg_class where oid=to_regclass('app_private.storefront_search')) as search_rls,
 (select count(*) from pg_policy where polrelid=to_regclass('app_private.storefront_search')) as search_policy_count,
 (select relrowsecurity from pg_class where oid=to_regclass('public.catalog_search_aliases')) as aliases_rls;
