-- Read only. Before: prerequisite_023/security true, all capability/receipt flags false. After: all true.
select exists(select 1 from app_private.sql_editor_receipts where version='202611230023' and sha256='9249d60fa419ef50e017fe7b2e5ab5d92c5810f0d72bf4d77271e2d2b6cea8b3') prerequisite_023,
 to_regprocedure('app_private.save_product_discovery(uuid,jsonb)') is not null discovery_present,
 coalesce((select position('discovery_editor_version' in prosrc)>0 from pg_proc where oid=to_regprocedure('public.publication_report(uuid)')),false) capability_present,
 coalesce((select position('save_product_discovery' in prosrc)>0 from pg_proc where oid=to_regprocedure('app_private.save_daily_product_016(uuid,integer,jsonb,uuid,text)')),false) save_hook_present,
 coalesce((select position('facets' in prosrc)>0 from pg_proc where oid=to_regprocedure('public.storefront_navigation()')),false) navigation_facets_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202611250024' and sha256='fc3f75f9d2d06217fa65dc7c66b2f0cdf0d6ca8d8db952a518cd3212d38d7cf7') receipt_matches,
 not has_function_privilege('anon','public.save_daily_product(uuid,integer,jsonb,uuid,text)','EXECUTE') and has_function_privilege('authenticated','public.save_daily_product(uuid,integer,jsonb,uuid,text)','EXECUTE') public_security_preserved,
 case when to_regprocedure('app_private.save_product_discovery(uuid,jsonb)') is null then true else not has_function_privilege('anon','app_private.save_product_discovery(uuid,jsonb)','EXECUTE') and not has_function_privilege('authenticated','app_private.save_product_discovery(uuid,jsonb)','EXECUTE') and not has_function_privilege('service_role','app_private.save_product_discovery(uuid,jsonb)','EXECUTE') end helper_private;
