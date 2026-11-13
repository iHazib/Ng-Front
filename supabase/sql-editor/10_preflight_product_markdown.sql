-- Read-only installed-state check. No business records are returned.
select to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,text)') is not null as daily_editor_present,
 to_regprocedure('public.storefront_reviews(uuid,integer)') is not null as reviews_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610070011' and sha256='0a3d7c1ad1e67b09f876c3c43ea8c335f23e698d32bbc38eee0a595321975e52') as receipt_011_present,
 exists(select 1 from information_schema.columns where table_schema='public' and table_name='products' and column_name='key_benefits') as benefits_present,
 to_regprocedure('public.admin_product_list(text,integer,text)') is not null as product_list_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610080012') as receipt_012_present,
 (select sha256='12038d5d88f52a014bca3050567d75e68e8d3066ac8771eb364b47d3f2381bc7' from app_private.sql_editor_receipts where version='202610080012') as receipt_matches,
 (select relrowsecurity from pg_class where oid='public.products'::regclass) as products_rls;
