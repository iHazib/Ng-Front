-- READ ONLY. Stop if partial state exists; never rerun earlier installers.
select to_regprocedure('public.storefront_articles(text,boolean,integer,integer)') is not null as content_present,
 (select sha256='fc887ea5842eaa16a3980a71c0960a6246cc9b5a4c99a2c90245dd22c2df7bc2' from app_private.sql_editor_receipts where version='202610070010') as content_receipt_matches,
 to_regclass('public.review_media') is not null as review_media_present,
 to_regclass('app_private.review_limits') is not null as limits_present,
 exists(select 1 from information_schema.columns where table_schema='public' and table_name='reviews' and column_name='submission_complete') as review_columns_present,
 to_regprocedure('public.storefront_reviews(uuid,integer)') is not null as public_rpc_present,
 (select sha256='0a3d7c1ad1e67b09f876c3c43ea8c335f23e698d32bbc38eee0a595321975e52' from app_private.sql_editor_receipts where version='202610070011') as reviews_receipt_matches;
