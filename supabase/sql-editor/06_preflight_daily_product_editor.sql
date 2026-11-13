-- READ ONLY. Run in a new SQL Editor query BEFORE considering file 06 again.
-- No installers, drops, resets, grants or business-data mutations occur here.
begin read only;
select
 to_regclass('public.media_workflows') is not null as media_service_present,
 to_regclass('public.inventory_counts') is not null as inventory_counts_present,
 to_regclass('app_private.product_save_requests') is not null as save_requests_present,
 to_regprocedure('app_private.daily_product_issues(uuid)') is not null as daily_issues_present,
 to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,text)') is not null as save_text_signature_present,
 to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,boolean)') is not null as save_old_boolean_signature_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610060008') as receipt_008_present,
 strpos(pg_get_functiondef('public.publication_report(uuid)'::regprocedure),'daily_editor_version')>0 as daily_report_present,
 strpos(pg_get_functiondef('app_private.publication_blockers(uuid)'::regprocedure),'daily_product_issues')>0 as daily_blockers_present;
-- Inventory of any overloads; this reads definitions/signatures, never executes a save.
select n.nspname as schema_name,p.proname as function_name,pg_get_function_identity_arguments(p.oid) as arguments
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where (n.nspname='public' and p.proname='save_daily_product')
 or (n.nspname='app_private' and p.proname='daily_product_issues');
commit;
-- Proceed with corrected file 06 only when media_service_present=true and EVERY other
-- boolean above is false. If any daily-editor boolean is true, stop and report the
-- result; do not drop objects or rerun prior installers. The installer also refuses
-- known existing/partial state without changing anything.
