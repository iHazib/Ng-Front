-- READ ONLY. Before: prerequisites/security true, correction/receipt flags false. After: all true.
select to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,text)') is not null
 and to_regprocedure('app_private.admin_current_issues(uuid)') is not null prerequisites_present,
 coalesce((select position('set_contents_missing' in prosrc)=0 from pg_proc where oid=to_regprocedure('app_private.publication_blockers(uuid)')),false) boxed_gate_removed,
 coalesce((select position('unconfirmed_set' in prosrc)=0 from pg_proc where oid=to_regprocedure('public.variant_is_public(uuid)')),false) boxed_visibility_gate_removed,
 coalesce((select position($needle$'set_contents_missing',true$needle$ in prosrc)=0 from pg_proc where oid=to_regprocedure('app_private.admin_current_issues(uuid)')),false) boxed_reminder_removed,
 coalesce((select position('factory_pack_and_contents_unconfirmed' in prosrc)=0 from pg_proc where oid=to_regprocedure('app_private.daily_product_issues(uuid)')),false) boxed_import_gate_removed,
 exists(select 1 from app_private.sql_editor_receipts where version='202611230023' and sha256='9249d60fa419ef50e017fe7b2e5ab5d92c5810f0d72bf4d77271e2d2b6cea8b3') receipt_matches,
 not has_function_privilege('anon','public.save_daily_product(uuid,integer,jsonb,uuid,text)','EXECUTE')
 and has_function_privilege('authenticated','public.save_daily_product(uuid,integer,jsonb,uuid,text)','EXECUTE') admin_write_grants_preserved;
