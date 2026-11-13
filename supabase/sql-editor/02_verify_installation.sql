-- Read-only metadata and role smoke checks; no data writes.
select version,filename,sha256 from app_private.sql_editor_receipts order by version;
select c.relname,c.relrowsecurity,
 has_table_privilege('anon',c.oid,'SELECT') as anon_select,
 has_table_privilege('authenticated',c.oid,'SELECT') as authenticated_select
from pg_class c where c.relnamespace='public'::regnamespace and c.relname in ('brands','brand_aliases','categories','product_types','category_product_types','products','product_categories','variants','sku_aliases','variant_prices','option_axes','option_values','variant_options','facet_definitions','facet_scopes','facet_values','evidence','product_facets','concerns','product_concerns','collections','collection_products','media_assets','product_media','factory_set_contents','import_batches','import_records','product_checks','publication_requirements','audit_logs','orders','deals','deal_components','order_items','order_item_components','inventory_balances','inventory_movements','inventory_reservations','sales','refunds','shipments','shipment_items','reviews','review_private','articles','article_media','homepage_selections') order by c.relname;
select has_schema_privilege('anon','public','USAGE') as anon_public_usage,
 has_schema_privilege('authenticated','public','USAGE') as authenticated_public_usage,
 has_schema_privilege('anon','app_private','USAGE') as anon_private_usage,
 has_schema_privilege('authenticated','app_private','USAGE') as user_private_usage;
select schemaname,tablename,policyname,roles,cmd from pg_policies
where schemaname='public' and tablename in ('brands','brand_aliases','categories','product_types','category_product_types','products','product_categories','variants','sku_aliases','variant_prices','option_axes','option_values','variant_options','facet_definitions','facet_scopes','facet_values','evidence','product_facets','concerns','product_concerns','collections','collection_products','media_assets','product_media','factory_set_contents','import_batches','import_records','product_checks','publication_requirements','audit_logs','orders','deals','deal_components','order_items','order_item_components','inventory_balances','inventory_movements','inventory_reservations','sales','refunds','shipments','shipment_items','reviews','review_private','articles','article_media','homepage_selections') or schemaname='storage' and policyname like 'ng_private_%'
order by schemaname,tablename,policyname;
select id,public from storage.buckets where id='catalog-private';
begin;
set local role anon;
select count(*) as anonymous_visible_products from public.products;
select public.is_admin() as anonymous_is_admin;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000000',true);
select public.is_admin() as unprovisioned_is_admin;
select count(*) as unprovisioned_visible_products from public.products;
rollback;
-- Counts should be zero after schema-only installation. This is SQL role simulation,
-- not real Auth login, JWT validation or HTTP Storage verification.
