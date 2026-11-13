-- Read-only prerequisites. Stop on any exception; never drop objects to bypass it.
do $preflight$ begin
  if current_setting('server_version_num')::integer < 150000 then raise exception 'PostgreSQL 15+ required'; end if;
  if current_setting('server_encoding') <> 'UTF8' then raise exception 'UTF8 required'; end if;
  if to_regclass('auth.users') is null or to_regprocedure('auth.uid()') is null
     or to_regclass('storage.buckets') is null or to_regclass('storage.objects') is null then
    raise exception 'Actual Supabase Auth/Storage schema prerequisites missing'; end if;
  if not exists(select 1 from pg_roles where rolname='anon') or not exists(select 1 from pg_roles where rolname='authenticated') then raise exception 'Supabase roles missing'; end if;
  if exists(select 1 from pg_namespace where nspname='app_private') then raise exception 'app_private already exists: stop and inspect; no automatic overwrite'; end if;
  if exists(select 1 from pg_class where relnamespace='public'::regnamespace and relname in ('brands','brand_aliases','categories','product_types','category_product_types','products','product_categories','variants','sku_aliases','variant_prices','option_axes','option_values','variant_options','facet_definitions','facet_scopes','facet_values','evidence','product_facets','concerns','product_concerns','collections','collection_products','media_assets','product_media','factory_set_contents','import_batches','import_records','product_checks','publication_requirements','audit_logs','orders','deals','deal_components','order_items','order_item_components','inventory_balances','inventory_movements','inventory_reservations','sales','refunds','shipments','shipment_items','reviews','review_private','articles','article_media','homepage_selections')) then raise exception 'Nook and Glow table name collision: stop; preserve existing data'; end if;
  if exists(select 1 from pg_type where typnamespace='public'::regnamespace and typname in ('publication_status','review_status','catalog_scope','facet_kind')) then raise exception 'Catalog type collision'; end if;
  if exists(select 1 from pg_proc where pronamespace='public'::regnamespace and proname in ('adjust_inventory','admin_search_catalog','concern_is_public','deal_is_public','facet_is_public','finish_reservation','import_catalog_drafts','is_admin','karachi_day_bounds','media_is_public','product_is_public','publication_report','reserve_order','search_published_catalog','set_primary_media','sku_collision_key','variant_is_public')) then raise exception 'Catalog function name collision'; end if;
  if exists(select 1 from pg_extension e join pg_namespace n on n.oid=e.extnamespace where e.extname='pg_trgm' and n.nspname<>'extensions') then raise exception 'pg_trgm installed outside extensions; review compatibility without relocating automatically'; end if;
  if exists(select 1 from storage.buckets where id='catalog-private') then raise exception 'catalog-private bucket already exists; stop without changing it'; end if;
  if exists(select 1 from pg_policies where schemaname='storage' and tablename='objects') then raise exception 'Existing Storage policies require manual scope review before adding this bucket; do not delete policies'; end if;
end $preflight$;
select 'PREFLIGHT PASSED; confirm this is your development project before installation' as result;
