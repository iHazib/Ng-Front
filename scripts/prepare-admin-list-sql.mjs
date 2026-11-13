import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const file='202610090013_admin_catalog_list.sql',version='202610090013';
const source=await readFile('supabase/migrations/'+file),hash=createHash('sha256').update(source).digest('hex');
const previous=createHash('sha256').update(await readFile('supabase/migrations/202610080012_product_markdown.sql')).digest('hex');
const verify=`-- READ ONLY. No business records or credentials returned.
select exists(select 1 from app_private.sql_editor_receipts where version='202610080012' and sha256='${previous}') as prerequisite_012,
 to_regclass('app_private.admin_catalog_search') is not null as search_present,
 to_regclass('app_private.admin_reminder_issues') is not null as issues_present,
 to_regclass('app_private.admin_reminder_dismissals') is not null as dismissals_present,
 to_regclass('app_private.admin_category_membership') is not null as category_membership_present,
 to_regclass('app_private.admin_list_options') is not null as list_options_present,
 to_regclass('app_private.admin_assigned_attributes') is not null as attributes_present,
 to_regprocedure('app_private.refresh_admin_catalog_trigger()') is not null as refresh_trigger_present,
 to_regprocedure('app_private.refresh_admin_catalog(uuid)') is not null as refresh_present,
 to_regprocedure('app_private.admin_current_issues(uuid)') is not null as current_issues_present,
 to_regprocedure('app_private.admin_query_matches(uuid,text)') is not null as query_matches_present,
 to_regprocedure('public.admin_catalog_list(text,jsonb,integer,integer)') is not null as list_present,
 to_regprocedure('public.admin_catalog_filter_options(text)') is not null as filters_present,
 to_regprocedure('public.admin_catalog_reminder(text,uuid,boolean)') is not null as reminder_present,
 exists(select 1 from app_private.sql_editor_receipts where version='${version}') as receipt_present,
 exists(select 1 from app_private.sql_editor_receipts where version='${version}' and sha256='${hash}') as receipt_matches,
 (select bool_and(c.relrowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='app_private' and c.relname in('admin_catalog_search','admin_reminder_issues','admin_reminder_dismissals')) as private_rls,
 (select count(*) from pg_policies where schemaname='app_private' and tablename in('admin_catalog_search','admin_reminder_issues','admin_reminder_dismissals'))=0 as no_client_policies,
 (select count(*)=26 from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and t.tgname='zz_refresh_admin_catalog' and not t.tgisinternal and t.tgenabled='O' and t.tgfoid=to_regprocedure('app_private.refresh_admin_catalog_trigger()')) as refresh_triggers_installed;
`;
const guard=`do $install_guard$ begin
 if not exists(select 1 from app_private.sql_editor_receipts where version='202610080012' and sha256='${previous}') then raise exception 'Verify installed migration 012 first';end if;
 if exists(select 1 from app_private.sql_editor_receipts where version='${version}') or to_regclass('app_private.admin_catalog_search') is not null or to_regclass('app_private.admin_reminder_issues') is not null or to_regclass('app_private.admin_reminder_dismissals') is not null or to_regprocedure('public.admin_catalog_list(text,jsonb,integer,integer)') is not null or to_regprocedure('public.admin_catalog_reminder(text,uuid,boolean)') is not null or to_regprocedure('public.admin_catalog_filter_options(text)') is not null or to_regprocedure('app_private.admin_current_issues(uuid)') is not null or to_regprocedure('app_private.refresh_admin_catalog(uuid)') is not null or to_regclass('app_private.admin_assigned_attributes') is not null or to_regclass('app_private.admin_category_membership') is not null or to_regclass('app_private.admin_list_options') is not null or to_regprocedure('app_private.refresh_admin_catalog_trigger()') is not null or to_regprocedure('app_private.admin_query_matches(uuid,text)') is not null or exists(select 1 from pg_trigger where tgname='zz_refresh_admin_catalog' and not tgisinternal) then raise exception 'Admin list already or partly installed; inspect read-only preflight, do not rerun';end if;
end $install_guard$;`;
const sql=`-- COMPLETE incremental migration 013; new DEVELOPMENT SQL Editor query only.
-- Creates private derived indexes/reminders and authorized functions. No business rows are rewritten.
-- DELETE/UPDATE in reminder refresh/Restore touch only new derived/reminder tables, never catalog/stock.
begin;
set local lock_timeout='5s';set local statement_timeout='120s';
select pg_advisory_xact_lock(73523);
${guard}
${source.toString('utf8')}
insert into app_private.sql_editor_receipts(version,filename,sha256) values('${version}','${file}','${hash}');
notify pgrst,'reload schema';
commit;
${verify}`;
const functions=[...sql.matchAll(/^create function ([\w.]+)/gm)].map(x=>x[1]);
if(new Set(functions).size!==functions.length)throw Error('Duplicate declarations');
const tags=[...sql.matchAll(/\$[a-z_]+\$/g)].map(x=>x[0]);for(let i=0;i<tags.length;i+=2)if(tags[i]!==tags[i+1])throw Error('Mismatched function terminator');
if([...sql.matchAll(/^insert into app_private.sql_editor_receipts/gm)].length!==1)throw Error('Duplicate receipts');
await writeFile('supabase/sql-editor/11_preflight_admin_catalog_list.sql',verify);
await writeFile('supabase/sql-editor/11_install_admin_catalog_list_clean.sql',sql);
await writeFile('docs/admin-list-installer-structure.json',JSON.stringify({source:file,canonical_sha256:hash,installer_sha256:createHash('sha256').update(sql).digest('hex'),functions,matched_dollar_quotes:true},null,2)+'\n');
console.log('Generated single clean incremental admin-list installer and read-only preflight.');
