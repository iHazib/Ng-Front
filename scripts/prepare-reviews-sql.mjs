import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const filename='202610070011_customer_reviews.sql',bytes=await readFile('supabase/migrations/'+filename),hash=createHash('sha256').update(bytes).digest('hex');
const sql=`-- CLEAN COMPLETE CUSTOMER REVIEWS INSTALLER. Apply ONCE to DEVELOPMENT, after 001–010.
-- Replaces the review public-read policy and media dispatcher; no business rows are changed.
-- DROP CONSTRAINT replaces the owner constraint with a stricter four-owner contract.
-- No DROP TABLE/TRUNCATE, automatic publication, catalog import or stock changes.
begin;
set local lock_timeout='5s';set local statement_timeout='120s';
select pg_advisory_xact_lock(73527);
do $install$ begin
 if to_regprocedure('public.storefront_articles(text,boolean,integer,integer)') is null or to_regclass('app_private.sql_editor_receipts') is null then raise exception 'Complete migrations 001–010 required';end if;
 if not exists(select 1 from app_private.sql_editor_receipts where version='202610070010' and sha256='fc887ea5842eaa16a3980a71c0960a6246cc9b5a4c99a2c90245dd22c2df7bc2') then raise exception 'Matching content CMS receipt required';end if;
 if to_regclass('public.review_media') is not null or to_regclass('app_private.review_limits') is not null or to_regclass('public.review_moderation_events') is not null or exists(select 1 from information_schema.columns where table_schema='public' and table_name='reviews' and column_name='submission_complete') or exists(select 1 from app_private.sql_editor_receipts where version='202610070011') then raise exception 'Reviews already or partly installed; stop and inspect, do not rerun';end if;
END; $install$;
${bytes.toString('utf8')}
insert into app_private.sql_editor_receipts(version,filename,sha256) values('202610070011','${filename}','${hash}');
commit;
select to_regprocedure('public.storefront_reviews(uuid,integer)') is not null as reviews_present,
 (select relrowsecurity from pg_class where oid='public.review_media'::regclass) as review_media_rls,
 (select relrowsecurity from pg_class where oid='app_private.review_limits'::regclass) as limits_rls,
 (select sha256='${hash}' from app_private.sql_editor_receipts where version='202610070011') as receipt_matches;
`;
// Each function and dollar quote comes from one canonical definition, never patch concatenation.
const names=[...sql.matchAll(/create(?: or replace)? function ([\w.]+)\(/gi)].map(m=>m[1]);
if(new Set(names).size!==names.length)throw Error('Duplicate function declaration');
const tags=[...sql.matchAll(/\$[a-z_]*\$/g)].map(m=>m[0]);for(const tag of new Set(tags))if(tags.filter(t=>t===tag).length%2)throw Error('Unbalanced dollar quote');
if((sql.match(/insert into app_private.sql_editor_receipts/g)||[]).length!==1)throw Error('Duplicate receipt');
await writeFile('supabase/sql-editor/09_install_customer_reviews_clean.sql',sql);
await writeFile('supabase/sql-editor/09_preflight_customer_reviews.sql',`-- READ ONLY. Stop if partial state exists; never rerun earlier installers.
select to_regprocedure('public.storefront_articles(text,boolean,integer,integer)') is not null as content_present,
 (select sha256='fc887ea5842eaa16a3980a71c0960a6246cc9b5a4c99a2c90245dd22c2df7bc2' from app_private.sql_editor_receipts where version='202610070010') as content_receipt_matches,
 to_regclass('public.review_media') is not null as review_media_present,
 to_regclass('app_private.review_limits') is not null as limits_present,
 exists(select 1 from information_schema.columns where table_schema='public' and table_name='reviews' and column_name='submission_complete') as review_columns_present,
 to_regprocedure('public.storefront_reviews(uuid,integer)') is not null as public_rpc_present,
 (select sha256='${hash}' from app_private.sql_editor_receipts where version='202610070011') as reviews_receipt_matches;
`);
await writeFile('docs/reviews-installer-structure.json',JSON.stringify({file:'supabase/sql-editor/09_install_customer_reviews_clean.sql',sha256:createHash('sha256').update(sql).digest('hex'),migration_receipt_sha256:hash,function_count:names.length,duplicate_functions:0,receipt_inserts:1},null,2)+'\n');
console.log('Generated one clean complete review installer and read-only preflight.');
