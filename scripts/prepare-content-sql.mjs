import {readFile,writeFile} from 'node:fs/promises';import {createHash} from 'node:crypto';
const file='202610070010_content_cms.sql',bytes=await readFile('supabase/migrations/'+file),hash=createHash('sha256').update(bytes).digest('hex');
const sql=`-- CLEAN COMPLETE CONTENT CMS INSTALLER. Run once in a NEW empty DEVELOPMENT query.
-- Requires 001–009; never rerun previous installers or reset an existing database.
-- Additive columns/tables and function replacements. Replaces one public article policy.
-- No table DROP/TRUNCATE, stock reset or business-row writes during installation.
-- Runtime article deletion is confirmed soft deletion; association removal is audited.
begin;
set local lock_timeout='5s';set local statement_timeout='120s';
select pg_advisory_xact_lock(73526);
do $install$ begin
 if to_regprocedure('public.storefront_navigation()') is null or to_regclass('app_private.sql_editor_receipts') is null then raise exception 'Migration 009 and SQL Editor receipts required'; end if;
 if to_regclass('public.homepage_media') is not null or to_regprocedure('public.save_article(uuid,integer,jsonb,text)') is not null or exists(select 1 from app_private.sql_editor_receipts where version='202610070010') then raise exception 'Content CMS already or partly installed; stop and inspect, do not rerun'; end if;
END; $install$;
${bytes.toString('utf8')}
insert into app_private.sql_editor_receipts(version,filename,sha256) values('202610070010','${file}','${hash}');
commit;
select to_regprocedure('public.storefront_articles(text,boolean,integer,integer)') is not null as content_present,
 (select relrowsecurity from pg_class where oid='public.homepage_media'::regclass) as homepage_media_rls,
 (select sha256='${hash}' from app_private.sql_editor_receipts where version='202610070010') as receipt_matches;
`;
await writeFile('supabase/sql-editor/08_install_content_cms_clean.sql',sql);
await writeFile('docs/content-installer-structure.json',JSON.stringify({file:'supabase/sql-editor/08_install_content_cms_clean.sql',sha256:createHash('sha256').update(sql).digest('hex'),migration_receipt_sha256:hash},null,2)+'\n');
console.log('Generated complete additive content CMS installer.');
