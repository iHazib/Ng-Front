/** Overwrite complete installers from ONE canonical migration; never append edits. */
import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const sourceFile='supabase/migrations/202610070009_public_storefront.sql';
const bytes=await readFile(sourceFile);
const source=bytes.toString('utf8');
const hash=createHash('sha256').update(bytes).digest('hex');
const sql=`-- CLEAN COMPLETE INSTALLER. Replace the entire query; never append or combine edits.
-- Run ONCE in a NEW empty DEVELOPMENT Supabase SQL Editor query after read-only preflight.
-- Source: ${sourceFile}; source receipt SHA-256: ${hash}
-- Adds public RPCs, approved aliases and private RLS search; no business data changes.
-- No DROP/TRUNCATE/reset. Private search-index upserts and new object creation only.
begin;
set local lock_timeout='5s';
set local statement_timeout='120s';
select pg_advisory_xact_lock(73524);
do $preflight$ begin
 if to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,text)') is null then raise exception 'Migration 008 is required'; end if;
 if to_regclass('app_private.sql_editor_receipts') is null then raise exception 'SQL Editor receipt registry required'; end if;
 if to_regclass('public.catalog_search_aliases') is not null
 or to_regclass('app_private.storefront_search') is not null
 or to_regclass('app_private.storefront_attributes') is not null
 or to_regclass('app_private.storefront_variants') is not null
 or exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where (n.nspname='public' and p.proname in('storefront_catalog','storefront_navigation'))
   or (n.nspname='app_private' and p.proname in('refresh_storefront_search','refresh_storefront_trigger','matches_storefront_query','storefront_filter_match')))
 or exists(select 1 from pg_trigger where tgname='refresh_storefront_search' and not tgisinternal)
 or exists(select 1 from app_private.sql_editor_receipts where version='202610070009')
 then raise exception 'Storefront objects or receipt already exist. Stop and inspect 07_preflight_public_storefront.sql; no existing objects or data were changed.'; end if;
END;
$preflight$;
${source}
insert into app_private.sql_editor_receipts(version,filename,sha256)
values('202610070009','202610070009_public_storefront.sql','${hash}');
commit;
select to_regprocedure('public.storefront_navigation()') is not null as storefront_present,
 (select relrowsecurity from pg_class where oid='public.catalog_search_aliases'::regclass) as aliases_rls,
 (select relrowsecurity from pg_class where oid='app_private.storefront_search'::regclass) as search_rls;
`;
const count=pattern=>[...sql.matchAll(pattern)].length;
const functions=[...sql.matchAll(/^\s*create function\s+([a-z_]+\.[a-z_]+)/gmi)].map(m=>m[1]);
const expected=['app_private.refresh_storefront_search','app_private.refresh_storefront_trigger','app_private.matches_storefront_query','app_private.storefront_filter_match','public.storefront_catalog','public.storefront_navigation'];
if(functions.length!==6||expected.some(name=>functions.filter(n=>n===name).length!==1))throw Error('Duplicate or unexpected function declaration.');
const delimiters=[...sql.matchAll(/\$[a-z_][a-z_0-9]*\$/gi)].map(m=>m[0]);
const tags=['$preflight$','$refresh$','$trigger$','$triggers$','$match$','$filters$','$catalog$','$navigation$'];
if(delimiters.length!==16||tags.some((tag,i)=>delimiters[2*i]!==tag||delimiters[2*i+1]!==tag))throw Error('Mismatched or duplicate dollar delimiters.');
const navigation=source.split('$navigation$')[1];
if(!navigation||[...navigation.matchAll(/'brands'\s*,/g)].length!==1)throw Error('Duplicate navigation brands entry.');
const counts={functions:functions.length,navigation_brands:1,receipt_inserts:count(/^insert into app_private\.sql_editor_receipts\b/gmi),receipt_values:count(/^values\('202610070009'/gmi),final_selects:count(/^select to_regprocedure\('public\.storefront_navigation/gmi),transactions:count(/^begin;/gmi),commits:count(/^commit;/gmi)};
if(Object.entries(counts).some(([key,value])=>value!==(key==='functions'?6:1)))throw Error('Duplicate installer section.');
const files=['supabase/sql-editor/07_install_public_storefront.sql','supabase/sql-editor/07_install_public_storefront_clean.sql'];
for(const file of files)await writeFile(file,sql);
await writeFile('docs/storefront-installer-structure.json',JSON.stringify({status:'passed',source:sourceFile,files,sha256:createHash('sha256').update(sql).digest('hex'),migration_receipt_sha256:hash,counts,function_declarations:functions,ordered_delimiters:delimiters},null,2)+'\n');
console.log('Regenerated two byte-identical COMPLETE files; six unique functions, one brands entry, one receipt VALUES, one final SELECT.');
