-- ONE READ-ONLY QUERY. Run in a NEW development SQL Editor query.
-- Verifies installed state; never installs, reloads, grants, drops or edits rows.
with expected_relations(name,kind) as (values
 ('public.catalog_search_aliases','r'),('app_private.storefront_search','r'),
 ('app_private.storefront_attributes','v'),('app_private.storefront_variants','v')),
expected_functions(signature) as (values
 ('public.storefront_navigation()'),
 ('public.storefront_catalog(text,text[],text,jsonb,text,integer,integer,text,boolean)'),
 ('app_private.refresh_storefront_search()'),('app_private.refresh_storefront_trigger()'),
 ('app_private.matches_storefront_query(uuid,text)'),
 ('app_private.storefront_filter_match(jsonb,jsonb,text)')),
expected_triggers(tablename) as (values
 ('products'),('variants'),('brands'),('brand_aliases'),('sku_aliases'),('categories'),
 ('product_types'),('product_facets'),('product_concerns'),('facet_values'),
 ('facet_definitions'),('concerns'),('evidence'),('catalog_search_aliases')),
missing as (select coalesce(jsonb_agg(name),'[]') objects from (
 select name from expected_relations e where not exists(
  select 1 from pg_class c where c.oid=to_regclass(e.name) and c.relkind::text=e.kind)
 union all select signature from expected_functions where to_regprocedure(signature) is null
 union all select 'public.'||tablename||':refresh_storefront_search' from expected_triggers e
  where not exists(select 1 from pg_trigger t where t.tgrelid=to_regclass('public.'||e.tablename)
   and t.tgname='refresh_storefront_search' and not t.tgisinternal and t.tgenabled='O'
   and t.tgfoid=to_regprocedure('app_private.refresh_storefront_trigger()'))
 union all select indexname from (values ('app_private.storefront_search_fts'),('app_private.storefront_search_trgm')) i(indexname)
  where not exists(select 1 from pg_index x where x.indexrelid=to_regclass(i.indexname) and x.indrelid=to_regclass('app_private.storefront_search') and x.indisvalid)
) x), receipt as (select version,filename,sha256,applied_at from app_private.sql_editor_receipts where version='202610070009')
select
 to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,text)') is not null as prerequisite_008_present,
 (select row_to_json(r) from receipt r) as receipt_009,
 exists(select 1 from receipt where filename='202610070009_public_storefront.sql'
  and sha256='f7d321de75bb11b75d6540eef0a5de4d69ddf6f44c6d0f9e4c45dce8594a6588') as receipt_matches_canonical_migration,
 (select objects from missing) as missing_expected_objects,
 (select objects='[]'::jsonb from missing) as expected_objects_complete,
 (select relrowsecurity from pg_class where oid=to_regclass('public.catalog_search_aliases')) as aliases_rls,
 (select relrowsecurity and not relforcerowsecurity from pg_class where oid=to_regclass('app_private.storefront_search')) as search_rls_owner_access,
 (select count(*) from pg_policy where polrelid=to_regclass('app_private.storefront_search')) as search_policy_count,
 coalesce(not has_table_privilege('anon',to_regclass('app_private.storefront_search'),'SELECT')
  and not has_table_privilege('authenticated',to_regclass('app_private.storefront_search'),'SELECT'),false) as client_direct_search_revoked,
 (select count(*)=2 and bool_and(p.prosecdef and p.proowner=c.relowner)
  from pg_proc p cross join pg_class c where c.oid=to_regclass('app_private.storefront_search')
  and p.oid in(to_regprocedure('public.storefront_navigation()'),
   to_regprocedure('public.storefront_catalog(text,text[],text,jsonb,text,integer,integer,text,boolean)'))) as rpc_owner_security_definer,
 (select count(*)=2 and bool_and(has_function_privilege('anon',p.oid,'EXECUTE')
  and has_function_privilege('authenticated',p.oid,'EXECUTE')) from pg_proc p
  where p.oid in(to_regprocedure('public.storefront_navigation()'),
   to_regprocedure('public.storefront_catalog(text,text[],text,jsonb,text,integer,integer,text,boolean)'))) as public_rpc_grants;
