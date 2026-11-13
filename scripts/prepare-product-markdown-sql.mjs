import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const filename='202610080012_product_markdown.sql';
const bytes=await readFile('supabase/migrations/'+filename),hash=createHash('sha256').update(bytes).digest('hex');
const previousHash=createHash('sha256').update(await readFile('supabase/migrations/202610070011_customer_reviews.sql')).digest('hex');
const preflight=`-- Read-only installed-state check. No business records are returned.
select to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,text)') is not null as daily_editor_present,
 to_regprocedure('public.storefront_reviews(uuid,integer)') is not null as reviews_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610070011' and sha256='${previousHash}') as receipt_011_present,
 exists(select 1 from information_schema.columns where table_schema='public' and table_name='products' and column_name='key_benefits') as benefits_present,
 to_regprocedure('public.admin_product_list(text,integer,text)') is not null as product_list_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610080012') as receipt_012_present,
 (select sha256='${hash}' from app_private.sql_editor_receipts where version='202610080012') as receipt_matches,
 (select relrowsecurity from pg_class where oid='public.products'::regclass) as products_rls;
`;
const sql=`-- COMPLETE incremental migration 012. Run once in a NEW DEVELOPMENT SQL Editor query.
-- No business records are rewritten. No DROP/TRUNCATE/DELETE is executed by installation.
-- ADD COLUMN and CREATE OR REPLACE replace definitions, preserving existing data and function owners.
-- DELETE/UPDATE inside the save function remain explicit, audited owner actions at runtime.
begin;
set local lock_timeout='5s';
set local statement_timeout='120s';
select pg_advisory_xact_lock(73523);
do $install_guard$ begin
 if not exists(select 1 from app_private.sql_editor_receipts where version='202610070011' and sha256='${previousHash}') or to_regprocedure('public.storefront_reviews(uuid,integer)') is null or to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,text)') is null then raise exception 'Apply and verify review migration 011 first'; end if;
 if exists(select 1 from information_schema.columns where table_schema='public' and table_name='products' and column_name='key_benefits') or to_regprocedure('public.admin_product_list(text,integer,text)') is not null or exists(select 1 from app_private.sql_editor_receipts where version='202610080012') then raise exception 'Product Markdown already or partly installed; inspect read-only preflight, do not rerun'; end if;
end $install_guard$;
${bytes.toString('utf8')}
insert into app_private.sql_editor_receipts(version,filename,sha256) values('202610080012','${filename}','${hash}');
notify pgrst,'reload schema';
commit;
${preflight}`;
const declarations=[...sql.matchAll(/^create(?: or replace)? (?:function|view) ([\w.]+)/gm)].map(m=>m[1]);
if(new Set(declarations).size!==4||declarations.length!==4)throw Error('Duplicate declarations');
const tags=[...sql.matchAll(/\$[a-z_]+\$/g)].map(m=>m[0]);
for(let i=0;i<tags.length;i+=2)if(tags[i]!==tags[i+1])throw Error('Mismatched dollar quotes');
if([...sql.matchAll(/^insert into app_private.sql_editor_receipts/gm)].length!==1)throw Error('Duplicate receipt');
await writeFile('supabase/sql-editor/10_preflight_product_markdown.sql',preflight);
await writeFile('supabase/sql-editor/10_install_product_markdown_clean.sql',sql);
await writeFile('docs/product-markdown-installer-structure.json',JSON.stringify({source:filename,canonical_sha256:hash,installer_sha256:createHash('sha256').update(sql).digest('hex'),declarations,matched_dollar_quotes:true},null,2)+'\n');
console.log('Generated one clean migration 012 installer and read-only preflight.');
