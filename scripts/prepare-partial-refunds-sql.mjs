import {readFile,writeFile} from 'node:fs/promises';import {createHash} from 'node:crypto';
const hash=x=>createHash('sha256').update(x).digest('hex'),file='202610200021_partial_refund_values.sql',bytes=await readFile('supabase/migrations/'+file),sha=hash(bytes),prior=hash(await readFile('supabase/migrations/202610180020_reports_refunds_returns.sql'));
const verify=`-- Read only. Before: prerequisite_020, private_rls and permissions_preserved true;
-- value_contract, view_contract and receipt flags false. All seven flags true after.
select exists(select 1 from app_private.sql_editor_receipts where version='202610180020' and sha256='${prior}') prerequisite_020,
 coalesce((select position('chosen' in prosrc)>0 and position('amountMinor' in prosrc)>0 from pg_proc where oid=to_regprocedure('app_private.refund_quote(uuid,jsonb,uuid)')),false) value_contract,
 coalesce((select position('partialAmountsSupported' in prosrc)>0 and position('remainingAmountMinor' in prosrc)>0 from pg_proc where oid=to_regprocedure('public.admin_order_finance(uuid)')),false) view_contract,
 exists(select 1 from app_private.sql_editor_receipts where version='202610200021') receipt_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610200021' and sha256='${sha}') receipt_matches,
 (select count(*)=7 and bool_and(relrowsecurity and not relforcerowsecurity) from pg_class where oid in(to_regclass('app_private.completed_sales'),to_regclass('app_private.receipt_dates'),to_regclass('app_private.finance_versions'),to_regclass('app_private.refund_requests'),to_regclass('app_private.refund_events'),to_regclass('app_private.return_events'),to_regclass('app_private.finance_operations'))) private_rls,
 (select prosecdef and proowner='postgres'::regrole and has_function_privilege('authenticated',oid,'EXECUTE') and not has_function_privilege('anon',oid,'EXECUTE') and not has_function_privilege('service_role',oid,'EXECUTE') from pg_proc where oid=to_regprocedure('public.admin_order_finance(uuid)')) and not has_function_privilege('authenticated','app_private.refund_quote(uuid,jsonb,uuid)','EXECUTE') permissions_preserved;
`;
const installer=`-- Complete incremental 021 AFTER 020; do not rerun 020 or any prior installer.
-- Replaces only two function bodies, preserving their identities/grants. No row rewrites/deletes.
begin;set local lock_timeout='5s';set local statement_timeout='120s';select pg_advisory_xact_lock(73525);
do $guard$ begin
 if not exists(select 1 from app_private.sql_editor_receipts where version='202610180020' and sha256='${prior}') then raise exception 'Confirm canonical 020 first';end if;
 if exists(select 1 from app_private.sql_editor_receipts where version='202610200021') then raise exception '021 already installed; inspect state, do not rerun';end if;
end $guard$;
${bytes.toString()}
insert into app_private.sql_editor_receipts(version,filename,sha256) values('202610200021','${file}','${sha}');notify pgrst,'reload schema';commit;
${verify}`;
await writeFile('supabase/sql-editor/19_preflight_partial_refunds.sql',verify);await writeFile('supabase/sql-editor/19_install_partial_refunds_clean.sql',installer);await writeFile('docs/partial-refunds-installer-manifest.json',JSON.stringify({canonical:file,canonical_sha256:sha,installer_sha256:hash(installer),prerequisite_020_sha256:prior},null,2)+'\n');console.log('Prepared separate 021; frozen 020 unchanged.');
