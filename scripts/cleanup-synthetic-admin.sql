-- ============================================================
-- Synthetic/test data cleanup for hosted Supabase
-- Run in the Supabase SQL Editor (connects as `postgres`, which can see the
-- non-exposed app_private schema).
-- ============================================================
--
-- WHY THE ORIGINAL VERSION FAILED
--   The blocking foreign keys are:
--     app_private.commerce_orders.order_id        -> public.orders(id)
--     app_private.product_save_requests.product_id -> public.products(id)
--   Those tables live in app_private, not public. The original script ran
--   `ALTER TABLE public.commerce_orders ... IF EXISTS`, which silently did
--   nothing, so the DELETE later failed with 23503
--   (commerce_orders_order_id_fkey).
--
-- The script is idempotent: each step is safe to re-run on a clean database.
-- ============================================================

-- ---------------------------------------------
-- Stage 1 — catalog, orders, media (TRUNCATE)
-- ---------------------------------------------
-- Done. TRUNCATE ... CASCADE removes every dependent row in public *and*
-- app_private (commerce_orders, order_events, manual_payments, payment_*,
-- refund_*, return_events, completed_sales, finance_*, product_save_requests,
-- inventory_*, order_items, sales, shipments, variants, prices, sku aliases,
-- deal components, media_workflows, ...).
--
--   truncate table public.orders       cascade;
--   truncate table public.products     cascade;
--   truncate table public.deals        cascade;
--   truncate table public.media_assets cascade;

-- ---------------------------------------------
-- Stage 2 — content
-- ---------------------------------------------
-- Done. article_tags / article_media first, then the articles themselves.
--
--   delete from public.article_tags;
--   delete from public.article_media;
--   delete from public.articles;

-- ---------------------------------------------
-- Stage 3 — synthetic taxonomy (run this)
-- ---------------------------------------------
begin;

-- Aliases pointing at synthetic brands
delete from public.brand_aliases
 where brand_id in (select id from public.brands where name ~* 'synthetic');

-- Synthetic brands (e.g. "CeraVe synthetic <uuid>", "Synthetic commerce ...")
delete from public.brands where name ~* 'synthetic';

-- Synthetic concerns (e.g. "Dry skin synthetic <uuid>")
delete from public.concerns
 where id ~ '^(sfdaae73|al-dry-)';

-- Category/product-type links belonging to synthetic categories
delete from public.category_product_types
 where category_id ~ '^(usability-|al-(cat|parent|extra|dry)-|ex-cat-|co-cat-|dl-cat-|sfdaae73)';

-- Synthetic categories. Parent and child are removed by the same statement,
-- so the self-referencing FK is satisfied.
delete from public.categories
 where id ~ '^(usability-|al-(cat|parent|extra|dry)-|ex-cat-|co-cat-|dl-cat-|sfdaae73)';

commit;

-- ---------------------------------------------
-- Verification — synthetic counts must all be 0
-- ---------------------------------------------
select 'synthetic brands'  as check_name, count(*) as remaining from public.brands       where name ~* 'synthetic'
union all select 'synthetic aliases',   count(*) from public.brand_aliases
         where brand_id in (select id from public.brands where name ~* 'synthetic')
union all select 'synthetic categories',count(*) from public.categories
         where id ~ '^(usability-|al-(cat|parent|extra|dry)-|ex-cat-|co-cat-|dl-cat-|sfdaae73)'
union all select 'synthetic concerns',  count(*) from public.concerns
         where id ~ '^(sfdaae73|al-dry-)'
union all select 'synthetic articles',  count(*) from public.articles where title ~* 'synthetic'
union all select 'catalog products',    count(*) from public.products
union all select 'catalog orders',      count(*) from public.orders
union all select 'media assets',        count(*) from public.media_assets
order by 1;

-- Remaining real reference data (expected, keep these)
select 'real brands'     as kept, count(*) from public.brands     where name !~* 'synthetic'
union all select 'real categories', count(*) from public.categories
         where id !~ '^(usability-|al-(cat|parent|extra|dry)-|ex-cat-|co-cat-|dl-cat-|sfdaae73)'
union all select 'real concerns',   count(*) from public.concerns
         where id !~ '^(sfdaae73|al-dry-)'
order by 1;

-- ============================================================
-- End
-- ============================================================
