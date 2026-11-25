from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1];p=root/'supabase/migrations/202611250024_product_discovery.sql';data=p.read_bytes();sha=hashlib.sha256(data).hexdigest();prior=hashlib.sha256((root/'supabase/migrations/202611230023_optional_boxed_set_contents.sql').read_bytes()).hexdigest()
verify=f"""-- Read only. Before: prerequisite_023/security true, all capability/receipt flags false. After: all true.
select exists(select 1 from app_private.sql_editor_receipts where version='202611230023' and sha256='{prior}') prerequisite_023,
 to_regprocedure('app_private.save_product_discovery(uuid,jsonb)') is not null discovery_present,
 coalesce((select position('discovery_editor_version' in prosrc)>0 from pg_proc where oid=to_regprocedure('public.publication_report(uuid)')),false) capability_present,
 coalesce((select position('save_product_discovery' in prosrc)>0 from pg_proc where oid=to_regprocedure('app_private.save_daily_product_016(uuid,integer,jsonb,uuid,text)')),false) save_hook_present,
 coalesce((select position('facets' in prosrc)>0 from pg_proc where oid=to_regprocedure('public.storefront_navigation()')),false) navigation_facets_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202611250024' and sha256='{sha}') receipt_matches,
 not has_function_privilege('anon','public.save_daily_product(uuid,integer,jsonb,uuid,text)','EXECUTE') and has_function_privilege('authenticated','public.save_daily_product(uuid,integer,jsonb,uuid,text)','EXECUTE') public_security_preserved,
 case when to_regprocedure('app_private.save_product_discovery(uuid,jsonb)') is null then true else not has_function_privilege('anon','app_private.save_product_discovery(uuid,jsonb)','EXECUTE') and not has_function_privilege('authenticated','app_private.save_product_discovery(uuid,jsonb)','EXECUTE') and not has_function_privilege('service_role','app_private.save_product_discovery(uuid,jsonb)','EXECUTE') end helper_private;
"""
installer=f"""-- Complete incremental 024 after owner-confirmed 023. No earlier installer rerun.
-- Adds inactive vocabulary; no product assignment/publication, stock or content rewrite.
begin;set local lock_timeout='5s';set local statement_timeout='120s';select pg_advisory_xact_lock(73526);
do $guard$ begin
 if not exists(select 1 from app_private.sql_editor_receipts where version='202611230023' and sha256='{prior}') then raise exception 'Confirm canonical 023 first';end if;
 if exists(select 1 from app_private.sql_editor_receipts where version='202611250024') or to_regprocedure('app_private.save_product_discovery(uuid,jsonb)') is not null then raise exception '024 already or partly installed; inspect before rerunning';end if;
end $guard$;
{data.decode()}
insert into app_private.sql_editor_receipts(version,filename,sha256) values('202611250024','{p.name}','{sha}');notify pgrst,'reload schema';commit;
{verify}"""
(root/'supabase/sql-editor/21_preflight_product_discovery.sql').write_text(verify,encoding='utf-8');(root/'supabase/sql-editor/21_install_product_discovery_clean.sql').write_text(installer,encoding='utf-8');(root/'docs/product-discovery-installer-manifest.json').write_text(json.dumps({'canonical_sha256':sha,'installer_sha256':hashlib.sha256((root/'supabase/sql-editor/21_install_product_discovery_clean.sql').read_bytes()).hexdigest(),'prerequisite_023_sha256':prior},indent=2)+'\n',encoding='utf-8')
