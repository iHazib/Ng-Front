/** Generate the exact, independently applicable SQL Editor package from migration 008. */
import {readFile, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const filename='202610060008_daily_product_editor.sql';
const bytes=await readFile(`supabase/migrations/${filename}`);
const hash=createHash('sha256').update(bytes).digest('hex');
const sql=`-- CLEAN COMPLETE INSTALLER: daily editor v2. Replace the entire SQL Editor query; do not append.
-- Run this entire file once in a NEW DEVELOPMENT Supabase SQL Editor query.
-- Installation preserves existing business records, source values, stock and audit history.
-- Adds audited counts and atomic saves; replaces blanket publication review requirements.
-- Corrected visibility contract: ordinary Save retains statuses; Draft/Publish/Hide are explicit intents.
-- Runtime functions may clear a price or homepage selection only when an admin explicitly saves that choice.
begin;
set local lock_timeout='5s';
set local statement_timeout='120s';
select pg_advisory_xact_lock(73523);
do $install_guard$ begin
 if to_regclass('public.media_workflows') is null then raise exception 'Media service migration required first'; end if;
 if to_regclass('public.inventory_counts') is not null
 or to_regclass('app_private.product_save_requests') is not null
 or to_regprocedure('app_private.daily_product_issues(uuid)') is not null
 or to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,text)') is not null
 or to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,boolean)') is not null
 or exists(select 1 from app_private.sql_editor_receipts where version='202610060008')
 or strpos(pg_get_functiondef('public.publication_report(uuid)'::regprocedure),'daily_editor_version')>0
 or strpos(pg_get_functiondef('app_private.publication_blockers(uuid)'::regprocedure),'daily_product_issues')>0
 then raise exception 'Daily editor objects already exist. Stop and inspect 06_preflight_daily_product_editor.sql; no existing objects or data were changed.'; end if;
END;
$install_guard$;
${bytes.toString('utf8')}
insert into app_private.sql_editor_receipts(version,filename,sha256) values('202610060008','${filename}','${hash}');
notify pgrst,'reload schema';
commit;
select to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,text)') is not null as daily_editor_installed,
 (select relrowsecurity from pg_class where oid='public.inventory_counts'::regclass) as count_audit_rls;
`;
// Reject a contaminated source/package before writing either complete artifact.
const declarations=[...sql.matchAll(/^\s*create(?:\s+or\s+replace)?\s+function\s+([a-z_]+\.[a-z_]+)/gmi)].map(match=>match[1]);
const expected=['app_private.daily_product_issues','app_private.publication_blockers','public.publication_report','public.save_daily_product'];
if(declarations.length!==expected.length||expected.some(name=>declarations.filter(n=>n===name).length!==1))throw new Error('Duplicate or unexpected function declaration.');
const delimiters=[...sql.matchAll(/\$[a-z_][a-z_0-9]*\$/gi)].map(match=>match[0]);
const tags=['$install_guard$','$daily_issues$','$publication_blockers$','$publication_report$','$save_daily_product$'];
if(delimiters.length!==10||tags.some((tag,i)=>delimiters[2*i]!==tag||delimiters[2*i+1]!==tag))throw new Error('Mismatched or duplicated dollar delimiters.');
const count=pattern=>[...sql.matchAll(pattern)].length;
const counts={functions:declarations.length,receipt_inserts:count(/^\s*insert into app_private\.sql_editor_receipts\b/gmi),final_selects:count(/^\s*select to_regprocedure\('public\.save_daily_product/gmi),transactions:count(/^begin;/gmi),commits:count(/^commit;/gmi),cache_reload_notifications:count(/^notify pgrst,/gmi)};
if(Object.entries(counts).some(([key,value])=>value!==(key==='functions'?4:1)))throw new Error('Duplicate installer section.');
await writeFile('supabase/sql-editor/06_install_daily_product_editor.sql',sql);
await writeFile('supabase/sql-editor/06_install_daily_product_editor_clean.sql',sql);
await writeFile('docs/daily-editor-installer-structure.json',JSON.stringify({status:'passed',source:filename,files:['supabase/sql-editor/06_install_daily_product_editor.sql','supabase/sql-editor/06_install_daily_product_editor_clean.sql'],sha256:createHash('sha256').update(sql).digest('hex'),counts,function_declarations:declarations,ordered_delimiters:delimiters},null,2)+'\n');
console.log('Regenerated complete installers from one source; four unique functions, five matched delimiter pairs, one receipt and one final SELECT.');
