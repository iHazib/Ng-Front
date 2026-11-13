-- Read-only development preflight. Only prerequisite_009 should be true before installation.
-- If any content object/column/receipt is present, STOP and inspect; do not rerun.
select to_regprocedure('public.storefront_navigation()') is not null as prerequisite_009,
 to_regclass('public.editorial_categories') is not null as categories_present,
 to_regclass('public.homepage_media') is not null as homepage_media_present,
 exists(select 1 from information_schema.columns where table_schema='public' and table_name='articles' and column_name='revision') as article_revision_present,
 to_regprocedure('public.save_article(uuid,integer,jsonb,text)') is not null as save_article_present,
 to_regprocedure('public.storefront_articles(text,boolean,integer,integer)') is not null as public_articles_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610070010') as receipt_010_present,
 (select row_to_json(r) from (select version,filename,sha256 from app_private.sql_editor_receipts where version='202610070010') r) as receipt_010;
