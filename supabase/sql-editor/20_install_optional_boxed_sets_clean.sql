-- Complete incremental 023. No previous installer rerun, no publication, no stock/content edits.
-- Only retired derived reminders change; original classifications/contents/history remain.
begin;
set local lock_timeout='5s';set local statement_timeout='120s';
select pg_advisory_xact_lock(73526);
do $guard$ begin
 if to_regclass('app_private.sql_editor_receipts') is null then raise exception 'Existing installation receipts required';end if;
 if exists(select 1 from app_private.sql_editor_receipts where version='202611230023') then raise exception '023 already installed; do not rerun';end if;
end $guard$;
-- 023: Owner-requested removal of boxed-set confirmation gates only.
-- Keep original set classification, contents, SKU identities, inventory and audit history.
-- Rewrite checked function definitions in place, preserving OIDs/ACLs/owners/settings.
do $boxed_gate$
declare definition text; signature text; needle text;
begin
 signature='app_private.publication_blockers(uuid)';
 definition=pg_get_functiondef(to_regprocedure(signature));
 if definition is null then raise exception 'Required function missing: %',signature;end if;
 needle=$fragment$ if exists(select 1 from public.variants where product_id=p_product and status<>'archived' and sellable_kind='unconfirmed_set') then missing=array_append(missing,'set_contents_missing'); end if;
$fragment$;
 if position(needle in definition)=0 then raise exception 'Unexpected function definition: %. Review before applying; no changes committed.',signature;end if;
 definition=replace(definition,needle,$fragment$$fragment$);
 needle=$fragment$ if exists(select 1 from public.variants v where v.product_id=p_product and v.status<>'archived' and v.sellable_kind='factory_set' and not exists(select 1 from public.factory_set_contents c where c.set_variant_id=v.id)) then missing=array_append(missing,'set_contents_missing'); end if;
$fragment$;
 if position(needle in definition)=0 then raise exception 'Unexpected function definition: %. Review before applying; no changes committed.',signature;end if;
 definition=replace(definition,needle,$fragment$$fragment$);
 execute definition;
 signature='public.variant_is_public(uuid)';
 definition=pg_get_functiondef(to_regprocedure(signature));
 if definition is null then raise exception 'Required function missing: %',signature;end if;
 needle=$fragment$and v.sellable_kind<>'unconfirmed_set' and p.approved$fragment$;
 if position(needle in definition)=0 then raise exception 'Unexpected function definition: %. Review before applying; no changes committed.',signature;end if;
 definition=replace(definition,needle,$fragment$and p.approved$fragment$);
 execute definition;
 signature='app_private.admin_current_issues(uuid)';
 definition=pg_get_functiondef(to_regprocedure(signature));
 if definition is null then raise exception 'Required function missing: %',signature;end if;
 needle=$fragment$,
 ('set_contents_missing',true,v.sellable_kind='unconfirmed_set' or (v.sellable_kind='factory_set' and not exists(select 1 from public.factory_set_contents s where s.set_variant_id=v.id)))$fragment$;
 if position(needle in definition)=0 then raise exception 'Unexpected function definition: %. Review before applying; no changes committed.',signature;end if;
 definition=replace(definition,needle,$fragment$$fragment$);
 execute definition;
 signature='app_private.daily_product_issues(uuid)';
 definition=pg_get_functiondef(to_regprocedure(signature));
 if definition is null then raise exception 'Required function missing: %',signature;end if;
 needle=$fragment$'factory_pack_and_contents_unconfirmed',$fragment$;
 if position(needle in definition)=0 then raise exception 'Unexpected function definition: %. Review before applying; no changes committed.',signature;end if;
 definition=replace(definition,needle,$fragment$$fragment$);
 execute definition;
end $boxed_gate$;
-- Retire only derived boxed-set reminders; retain dismissal/audit history.
update app_private.admin_reminder_issues set active=false where active and code in ('set_contents_missing','factory_pack_and_contents_unconfirmed');

insert into app_private.sql_editor_receipts(version,filename,sha256) values('202611230023','202611230023_optional_boxed_set_contents.sql','9249d60fa419ef50e017fe7b2e5ab5d92c5810f0d72bf4d77271e2d2b6cea8b3');
notify pgrst,'reload schema';
commit;
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
