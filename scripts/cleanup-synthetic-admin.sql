-- ============================================================
-- Clean up all synthetic/test data from hosted Supabase
-- Run this in Supabase SQL Editor (https://app.supabase.com/project/_/sql)
-- ============================================================

-- Step 1: Drop orphaned FK constraints blocking deletion
-- The FK constraints are defined ON commerce_orders and product_save_requests
-- referencing orders and products. Since those tables aren't accessible via
-- PostgREST API, drop the constraints directly.

-- Drop FK constraint on commerce_orders referencing orders
DO $$
BEGIN
  ALTER TABLE IF EXISTS public.commerce_orders DROP CONSTRAINT IF EXISTS commerce_orders_order_id_fkey;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Could not drop commerce_orders_order_id_fkey: %', SQLERRM;
END $$;

-- Drop FK constraint on product_save_requests referencing products
DO $$
BEGIN
  ALTER TABLE IF EXISTS public.product_save_requests DROP CONSTRAINT IF EXISTS product_save_requests_product_id_fkey;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Could not drop product_save_requests_product_id_fkey: %', SQLERRM;
END $$;

-- Step 2: Delete synthetic orders (now unblocked)
DELETE FROM public.orders
WHERE id IN (
  'b0b287b3-62af-4bba-877b-8f9b1f0a05ae',
  'cc10303f-821e-4392-95de-019cd19fc5ab',
  '04258ba2-fba2-4b9d-bd03-a498451e85f7',
  '293ba7f3-f2ff-464f-bfed-575a1f6c27a4',
  '43993528-9703-454b-984f-fa41f77055fd',
  '468b846a-492d-411c-9555-59926b3d7688',
  '8b4695d8-e30c-4ce6-84c9-ed7107786ec6',
  '524c1fd4-d1d6-49f5-90ad-0f828427793c',
  'b4ed667c-ee56-4405-a99c-0385a11e1365',
  'fc033418-a906-4cf8-bb79-e7cb12176f12',
  'acfc642f-d4b0-419b-887c-1531b8a6ea30',
  '17a8f28e-2a58-49cb-b369-6f1dee5f7631',
  '84044568-0878-40de-b605-63002b929496',
  'b439f75b-894e-4e36-9853-2e5fff14aee6'
);

-- Step 3: Delete synthetic products (now unblocked)
DELETE FROM public.products
WHERE id IN (
  'e0956643-4628-42ba-85c8-67a225b1f080',
  'eb384ec9-8e0b-479c-996a-58f56c2ca876',
  '05c38735-6748-4a77-8738-ed68c30da69e',
  'a360ca3a-858e-4379-9aa8-5de971eeb1d6',
  '096999dc-8ace-49cf-b0a4-87b322dfedde',
  '1d7bc133-41fd-4246-8258-34eebcfee338'
);

-- Step 4: Verify nothing synthetic remains
SELECT 'products remaining' AS check_type, COUNT(*) AS count
FROM public.products
WHERE name ILIKE '%synthetic%' OR slug ILIKE '%synthetic%';

SELECT 'orders remaining' AS check_type, COUNT(*) AS count
FROM public.orders
WHERE delivery_name ILIKE '%synthetic%';

SELECT 'deals remaining' AS check_type, COUNT(*) AS count
FROM public.deals
WHERE title ILIKE '%synthetic%';

-- ============================================================
-- End
-- ============================================================
