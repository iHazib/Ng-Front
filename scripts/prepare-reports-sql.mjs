import {readFile,writeFile} from 'node:fs/promises';import {createHash} from 'node:crypto';
const hash=x=>createHash('sha256').update(x).digest('hex'),file='202610180020_reports_refunds_returns.sql',source=await readFile('supabase/migrations/'+file),sha=hash(source),prior=hash(await readFile('supabase/migrations/202610180019_media_policy_dispatch.sql'));
const verify=`-- READ ONLY. Before: prerequisite_019, history_complete and no_client_policies true;
-- new object/receipt/RLS/grant flags false. All flags true after installation.
select exists(select 1 from app_private.sql_editor_receipts where version='202610180019' and sha256='${prior}') prerequisite_019,
 not exists(select 1 from app_private.commerce_orders c where c.fulfilment='completed' and not exists(select 1 from app_private.order_events e where e.order_id=c.order_id and e.action='complete')) history_complete,
 to_regclass('app_private.completed_sales') is not null sales_present,
 to_regclass('app_private.refund_requests') is not null refunds_present,
 to_regclass('app_private.return_events') is not null returns_present,
 to_regprocedure('public.admin_order_finance(uuid)') is not null finance_present,
 to_regprocedure('public.admin_finance_action(uuid,integer,uuid,text,jsonb)') is not null action_present,
 to_regprocedure('public.admin_sales_report(date,date,text,integer,integer,boolean,boolean,boolean)') is not null reports_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610180020') receipt_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610180020' and sha256='${sha}') receipt_matches,
 (select count(*)=7 and bool_and(relrowsecurity and not relforcerowsecurity) from pg_class where oid in(to_regclass('app_private.receipt_dates'),to_regclass('app_private.completed_sales'),to_regclass('app_private.finance_versions'),to_regclass('app_private.refund_requests'),to_regclass('app_private.refund_events'),to_regclass('app_private.return_events'),to_regclass('app_private.finance_operations'))) private_rls,
 not exists(select 1 from pg_policies where schemaname='app_private' and tablename in('receipt_dates','completed_sales','finance_versions','refund_requests','refund_events','return_events','finance_operations')) no_client_policies,
 (select count(*)=7 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='app_private' and c.relname in('receipt_dates','completed_sales','finance_versions','refund_requests','refund_events','return_events','finance_operations')) and not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join (values('anon'),('authenticated'),('service_role'))roles(name) cross join (values('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),('REFERENCES'),('TRIGGER'))privileges(name) where n.nspname='app_private' and c.relname in('receipt_dates','completed_sales','finance_versions','refund_requests','refund_events','return_events','finance_operations') and has_table_privilege(roles.name,c.oid,privileges.name)) private_grants,
 (select count(*)=5 and bool_and(p.prosecdef and p.proowner='postgres'::regrole and p.proconfig @> array['search_path=\"\"'] and position('require_admin()' in p.prosrc)>0 and has_function_privilege('authenticated',p.oid,'EXECUTE') and not has_function_privilege('anon',p.oid,'EXECUTE') and not has_function_privilege('service_role',p.oid,'EXECUTE') and not exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where acl.grantee=0 and acl.privilege_type='EXECUTE')) from pg_proc p where p.oid in(to_regprocedure('public.admin_order_finance(uuid)'),to_regprocedure('public.admin_finance_action(uuid,integer,uuid,text,jsonb)'),to_regprocedure('public.admin_sales_report(date,date,text,integer,integer,boolean,boolean,boolean)'),to_regprocedure('public.admin_order_action(uuid,integer,text,uuid)'),to_regprocedure('public.review_manual_payment(uuid,integer,text,uuid,jsonb)'))) rpc_security,
 coalesce((select not has_function_privilege('anon',oid,'EXECUTE') and not has_function_privilege('service_role',oid,'EXECUTE') and has_function_privilege('authenticated',oid,'EXECUTE') and prosecdef and proowner='postgres'::regrole from pg_proc where oid=to_regprocedure('public.admin_finance_action(uuid,integer,uuid,text,jsonb)')),false) action_grants;
`;
const installer=`-- Complete incremental 020 only; do not rerun earlier installers.
-- Adds private ledgers/indexes/functions/trigger and reconstructs explicit historical Complete events.
-- No business rows deleted/reset. Revokes generic legacy sales/refund INSERT from authenticated.
begin;set local lock_timeout='5s';set local statement_timeout='120s';select pg_advisory_xact_lock(73525);
do $guard$ begin
 if not exists(select 1 from app_private.sql_editor_receipts where version='202610180019' and sha256='${prior}') then raise exception 'Verify canonical 019 first';end if;
 if exists(select 1 from app_private.sql_editor_receipts where version='202610180020') or to_regclass('app_private.completed_sales') is not null or to_regprocedure('public.admin_order_finance(uuid)') is not null then raise exception '020 already or partly installed. Inspect state; do not rerun';end if;
end $guard$;
${source.toString()}
insert into app_private.sql_editor_receipts(version,filename,sha256) values('202610180020','${file}','${sha}');notify pgrst,'reload schema';commit;
${verify}`;
const declarations=[...source.toString().matchAll(/^create (?:or replace )?function ([\w.]+)/gm)].map(x=>x[1]);if(new Set(declarations).size!==declarations.length)throw Error('Duplicate function declaration');
await writeFile('supabase/sql-editor/18_preflight_reports_refunds.sql',verify);await writeFile('supabase/sql-editor/18_install_reports_refunds_clean.sql',installer);await writeFile('docs/reports-installer-manifest.json',JSON.stringify({canonical:file,canonical_sha256:sha,installer_sha256:hash(installer),prior_019_sha256:prior},null,2)+'\n');console.log('Prepared clean incremental 020 installer and read-only preflight.');
