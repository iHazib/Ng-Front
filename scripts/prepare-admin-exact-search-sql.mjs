import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const filename='202610120014_admin_exact_identifier_search.sql',version='202610120014';
const source=await readFile('supabase/migrations/'+filename);
const digest=b=>createHash('sha256').update(b).digest('hex');
const sha=digest(source),previous=digest(await readFile('supabase/migrations/202610090013_admin_catalog_list.sql'));
const verify=`-- READ ONLY: run before installation and again afterwards. No business data returned.
select exists(select 1 from app_private.sql_editor_receipts where version='202610090013' and sha256='${previous}') as prerequisite_013,
 to_regprocedure('public.admin_catalog_list(text,jsonb,integer,integer)') is not null as list_present,
 exists(select 1 from app_private.sql_editor_receipts where version='${version}') as receipt_014_present,
 exists(select 1 from app_private.sql_editor_receipts where version='${version}' and sha256='${sha}') as receipt_014_matches,
 coalesce(position('exact_identifiers as materialized' in pg_get_functiondef(to_regprocedure('public.admin_catalog_list(text,jsonb,integer,integer)')))>0,false) as exact_priority_present,
 (select p.prosecdef and (p.proconfig @> array['search_path='] or p.proconfig @> array['search_path=""']) and (p.proconfig @> array['statement_timeout=8s'] or p.proconfig @> array['statement_timeout=8000']) and position('require_admin()' in p.prosrc)>0 and pg_get_userbyid(p.proowner)='postgres' from pg_proc p where p.oid=to_regprocedure('public.admin_catalog_list(text,jsonb,integer,integer)')) as authorization_preserved,
 not has_function_privilege('anon','public.admin_catalog_list(text,jsonb,integer,integer)','execute') and has_function_privilege('authenticated','public.admin_catalog_list(text,jsonb,integer,integer)','execute') as rpc_grants_preserved,
 (select bool_and(relrowsecurity) from pg_class where oid in('app_private.admin_catalog_search'::regclass,'app_private.admin_reminder_issues'::regclass,'app_private.admin_reminder_dismissals'::regclass)) as private_rls,
 not exists(select 1 from pg_policies where schemaname='app_private' and tablename in('admin_catalog_search','admin_reminder_issues','admin_reminder_dismissals')) as no_client_policies;
`;
const sql=`-- COMPLETE incremental 014. Apply once in DEVELOPMENT after read-only preflight.
-- Replaces only the authorized admin list function; preserves catalog, stock and original SKUs.
-- No DROP, TRUNCATE, DELETE or business-row UPDATE. Existing migration 013 is untouched.
begin;
set local lock_timeout='5s';set local statement_timeout='120s';
select pg_advisory_xact_lock(73523);
do $install_guard$ begin
 if not exists(select 1 from app_private.sql_editor_receipts where version='202610090013' and sha256='${previous}') then raise exception 'Verify canonical installed migration 013 first';end if;
 if exists(select 1 from app_private.sql_editor_receipts where version='${version}') or position('exact_identifiers as materialized' in pg_get_functiondef(to_regprocedure('public.admin_catalog_list(text,jsonb,integer,integer)')))>0 then raise exception 'Exact search already or partly installed; inspect preflight, do not rerun';end if;
 if to_regprocedure('public.admin_catalog_list(text,jsonb,integer,integer)') is null then raise exception 'Admin list missing; inspect installed state';end if;
end $install_guard$;
${source.toString('utf8')}
insert into app_private.sql_editor_receipts(version,filename,sha256) values('${version}','${filename}','${sha}');
notify pgrst,'reload schema';
commit;
${verify}`;
if([...sql.matchAll(/^create or replace function /gm)].length!==1||[...sql.matchAll(/^insert into app_private.sql_editor_receipts/gm)].length!==1)throw Error('Invalid complete installer structure');
await writeFile('supabase/sql-editor/12_preflight_admin_exact_search.sql',verify);
await writeFile('supabase/sql-editor/12_install_admin_exact_search_clean.sql',sql);
await writeFile('docs/admin-exact-search-installer.json',JSON.stringify({canonical:filename,canonical_sha256:sha,installer_sha256:digest(sql),prerequisite_013_sha256:previous},null,2)+'\n');
console.log('Generated complete incremental 014 and read-only preflight.');
