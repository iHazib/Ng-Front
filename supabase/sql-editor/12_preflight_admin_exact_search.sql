-- READ ONLY: run before installation and again afterwards. No business data returned.
select exists(select 1 from app_private.sql_editor_receipts where version='202610090013' and sha256='de9272e1f837c654aa613e84fbabc8e1e12fc6248475764573a6a153d46e51b0') as prerequisite_013,
 to_regprocedure('public.admin_catalog_list(text,jsonb,integer,integer)') is not null as list_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610120014') as receipt_014_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610120014' and sha256='3f771bd8309cd0c1de097e93b6aaf76963d7a18c1f26029fb7047ec2c86e53c3') as receipt_014_matches,
 coalesce(position('exact_identifiers as materialized' in pg_get_functiondef(to_regprocedure('public.admin_catalog_list(text,jsonb,integer,integer)')))>0,false) as exact_priority_present,
 (select p.prosecdef and (p.proconfig @> array['search_path='] or p.proconfig @> array['search_path=""']) and (p.proconfig @> array['statement_timeout=8s'] or p.proconfig @> array['statement_timeout=8000']) and position('require_admin()' in p.prosrc)>0 and pg_get_userbyid(p.proowner)='postgres' from pg_proc p where p.oid=to_regprocedure('public.admin_catalog_list(text,jsonb,integer,integer)')) as authorization_preserved,
 not has_function_privilege('anon','public.admin_catalog_list(text,jsonb,integer,integer)','execute') and has_function_privilege('authenticated','public.admin_catalog_list(text,jsonb,integer,integer)','execute') as rpc_grants_preserved,
 (select bool_and(relrowsecurity) from pg_class where oid in('app_private.admin_catalog_search'::regclass,'app_private.admin_reminder_issues'::regclass,'app_private.admin_reminder_dismissals'::regclass)) as private_rls,
 not exists(select 1 from pg_policies where schemaname='app_private' and tablename in('admin_catalog_search','admin_reminder_issues','admin_reminder_dismissals')) as no_client_policies;
