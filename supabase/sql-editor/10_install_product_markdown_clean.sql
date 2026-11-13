-- COMPLETE incremental migration 012. Run once in a NEW DEVELOPMENT SQL Editor query.
-- No business records are rewritten. No DROP/TRUNCATE/DELETE is executed by installation.
-- ADD COLUMN and CREATE OR REPLACE replace definitions, preserving existing data and function owners.
-- DELETE/UPDATE inside the save function remain explicit, audited owner actions at runtime.
begin;
set local lock_timeout='5s';
set local statement_timeout='120s';
select pg_advisory_xact_lock(73523);
do $install_guard$ begin
 if not exists(select 1 from app_private.sql_editor_receipts where version='202610070011' and sha256='0a3d7c1ad1e67b09f876c3c43ea8c335f23e698d32bbc38eee0a595321975e52') or to_regprocedure('public.storefront_reviews(uuid,integer)') is null or to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,text)') is null then raise exception 'Apply and verify review migration 011 first'; end if;
 if exists(select 1 from information_schema.columns where table_schema='public' and table_name='products' and column_name='key_benefits') or to_regprocedure('public.admin_product_list(text,integer,text)') is not null or exists(select 1 from app_private.sql_editor_receipts where version='202610080012') then raise exception 'Product Markdown already or partly installed; inspect read-only preflight, do not rerun'; end if;
end $install_guard$;
-- Incremental product Markdown content. No existing content is rewritten.
-- Reuses description / usage; adds only optional key_benefits.
-- Replaces save/projection definitions, retaining authorization, idempotency,
-- optimistic revisions, visibility preservation, audited stock and public eligibility.
alter table public.products add column key_benefits text;
comment on column public.products.key_benefits is 'Optional Markdown benefits supplied by the owner; never inferred. Raw HTML and embedded images are disabled in rendering.';
create or replace function public.save_daily_product(p_product uuid,p_revision integer,p_data jsonb,p_key uuid,p_intent text default 'save')
returns jsonb language plpgsql security definer set search_path='' as $save_daily_product$
declare p public.products; variant_row public.variants; r jsonb; prior app_private.product_save_requests; request jsonb; result jsonb;
 ids uuid[]='{}'; vid uuid; old_count integer; counted integer; held integer; price bigint; blockers text[]; option_count integer; pos integer; issue_code text; target_status public.publication_status;
begin
 perform app_private.require_admin();
 if p_intent is null or p_intent not in ('save','draft','publish','hide') then raise exception 'Choose Save, Draft, Publish or Hide'; end if;
 if exists(select 1 from jsonb_each(p_data) x where x.key in ('description','usage','keyBenefits') and (jsonb_typeof(x.value) not in ('string','null') or length(x.value#>>'{}')>30000)) then raise exception 'Content must be text, up to 30000 characters per field'; end if;
 request=jsonb_build_object('product',p_product,'revision',p_revision,'data',p_data,'intent',p_intent);
 perform pg_advisory_xact_lock(hashtextextended(p_key::text,0));
 select * into prior from app_private.product_save_requests where id=p_key;
 if found then
  if prior.actor_id<>auth.uid() or prior.request<>request then raise exception 'Save request changed; reload and try again'; end if;
  return prior.result;
 end if;
 select * into p from public.products where id=p_product for update;
 if not found then raise exception 'Product not found'; end if;
 if p.revision<>p_revision then raise exception 'Product changed; reload before saving'; end if;
 if coalesce(btrim(p_data->>'name'),'')='' or length(p_data->>'name')>300 then raise exception 'Product name required'; end if;
 if jsonb_typeof(p_data->'options') is distinct from 'array' or jsonb_array_length(p_data->'options') not between 1 and 100 then raise exception 'One to 100 options required'; end if;
 option_count=jsonb_array_length(p_data->'options');
 -- Ordinary saves retain product and existing option visibility. Only explicit intent changes it.
 target_status=case p_intent when 'draft' then 'draft'::public.publication_status when 'publish' then 'published'::public.publication_status when 'hide' then 'archived'::public.publication_status else p.status end;
 for issue_code in select jsonb_array_elements_text(coalesce(p_data->'resolvedIssues','[]')) loop
  if issue_code=any(app_private.daily_product_issues(p_product)) or (issue_code='spf_label' and p_data->>'productType'='sunscreen') then
   insert into public.product_checks(product_id,code,approved,approved_by,approved_at) values(p_product,issue_code,true,auth.uid(),now())
    on conflict(product_id,code) do update set approved=true,approved_by=auth.uid(),approved_at=now();
  end if;
 end loop;
 -- The entire save is a transaction, including stock, variant removal and publication.
 begin
 update public.products set status=case when p_intent='publish' then p.status else target_status end,name=p_data->>'name',description=case when p_data ? 'description' then nullif(p_data->>'description','') else p.description end,
 usage=case when p_data ? 'usage' then nullif(p_data->>'usage','') else p.usage end,
 key_benefits=case when p_data ? 'keyBenefits' then nullif(p_data->>'keyBenefits','') else p.key_benefits end,
 brand_id=nullif(p_data->>'brand',''),category_id=nullif(p_data->>'category',''),product_type_id=nullif(p_data->>'productType',''),
 slug=coalesce(slug,'product-'||replace(p_product::text,'-','')) where id=p_product;
 exception when raise_exception then
  -- Existing BEFORE guards can reject missing copy/SPF or already invalid published dependencies.
  -- Translate those into the same actionable, atomic rejection; never silently hide the product.
  if p.status='published' and p_intent in ('save','publish') then
   blockers=app_private.publication_blockers(p_product);
   if coalesce(btrim(case when p_data ? 'description' then p_data->>'description' else p.description end),'')='' then blockers=array_append(blockers,'description_missing'); end if;
   if p_data->>'productType'='sunscreen' then blockers=array_append(blockers,'spf_label'); end if;
   if cardinality(blockers)>0 then raise exception 'Published edit would be invalid: %',array_to_string(blockers,','); end if;
  end if;
  raise;
 end;
 for r in select value from jsonb_array_elements(p_data->'options') loop
  vid=(r->>'id')::uuid;
  if vid=any(ids) then raise exception 'Duplicate option'; end if; ids=array_append(ids,vid);
  if coalesce(btrim(r->>'sku'),'')='' then raise exception 'Every option needs a SKU'; end if;
  if option_count>1 and coalesce(btrim(r->>'label'),'')='' then raise exception 'Add a shade or size for each option'; end if;
  select * into variant_row from public.variants where id=vid for update;
  if found then
   if variant_row.product_id<>p_product or variant_row.original_sku is distinct from r->>'sku' then raise exception 'Existing SKU cannot be changed or moved'; end if;
   if variant_row.status='archived' then raise exception 'Removed option cannot be restored through this save'; end if;
   update public.variants set label=nullif(r->>'label',''),status=case when p_intent='draft' then 'draft'::public.publication_status else variant_row.status end where id=vid;
  else insert into public.variants(id,product_id,original_sku,label) values(vid,p_product,r->>'sku',nullif(r->>'label',''));
  end if;
  price=(r->>'priceMinor')::bigint;
  if price is null then delete from public.variant_prices where variant_id=vid;
  else insert into public.variant_prices(variant_id,amount_minor,approved) values(vid,price,true)
   on conflict(variant_id) do update set amount_minor=excluded.amount_minor,approved=true,updated_at=now(); end if;
  if coalesce((r->>'countChanged')::boolean,false) then
   counted=(r->>'stock')::integer;
   if counted is null or counted<0 then raise exception 'Stock count must be zero or more'; end if;
   insert into public.inventory_balances(variant_id) values(vid) on conflict do nothing;
   select on_hand,reserved into old_count,held from public.inventory_balances where variant_id=vid for update;
   if old_count is distinct from (r->>'expectedStock')::integer then raise exception 'Stock changed; reload before entering the count again'; end if;
   if counted<held then raise exception 'Stock cannot be lower than units reserved for orders'; end if;
   if counted<>old_count then perform public.adjust_inventory(vid,counted-old_count,'Stock count entered in product editor',p_key::text||':'||vid::text);
   else update public.inventory_balances set reconciled_at=now() where variant_id=vid; end if;
   insert into public.inventory_counts(variant_id,previous_count,counted,actor_id,operation_id) values(vid,old_count,counted,auth.uid(),p_key);
  end if;
 end loop;
 -- Remove from sale without deleting SKU identity, stock, images, orders or history.
 if exists(select 1 from public.variants v join public.inventory_balances b on b.variant_id=v.id where v.product_id=p_product and v.status<>'archived' and not(v.id=any(ids)) and b.reserved>0) then raise exception 'An option reserved for an order cannot be removed'; end if;
 update public.variants set status='archived' where product_id=p_product and status<>'archived' and not(id=any(ids));
 -- The feature toggle chooses a free position internally; unrelated selections are untouched.
 perform pg_advisory_xact_lock(73524);
 if coalesce((p_data->>'featured')::boolean,false) then
  if not exists(select 1 from public.homepage_selections where product_id=p_product and section='products') then
   select coalesce(max(position),-1)+1 into pos from public.homepage_selections where section='products';
   insert into public.homepage_selections(section,position,product_id,status) values('products',pos,p_product,'draft');
  end if;
 else delete from public.homepage_selections where product_id=p_product and section='products'; end if;
 if target_status='published' then
  blockers=app_private.publication_blockers(p_product);
  if cardinality(blockers)>0 then
   if p.status='published' and p_intent='save' then raise exception 'Published edit would be invalid: %',array_to_string(blockers,','); end if;
   raise exception 'Missing publication information: %',array_to_string(blockers,',');
  end if;
  if p_intent='publish' then
  update public.products set identity_confirmed=true where id=p_product;
  update public.variants set status='published',identity_confirmed=true where product_id=p_product and status<>'archived';
  update public.brands set status='published' where id=(select brand_id from public.products where id=p_product);
  with recursive tree as (select id,parent_id from public.categories where id=(select category_id from public.products where id=p_product)
   union select c.id,c.parent_id from public.categories c join tree on c.id=tree.parent_id)
   update public.categories set status='published' where id in(select id from tree);
  update public.products set status='published' where id=p_product;
  end if;
  update public.homepage_selections set status='published' where product_id=p_product and section='products';
 end if;
 result=jsonb_build_object('ok',true,'revision',(select revision from public.products where id=p_product),'status',(select status from public.products where id=p_product));
 insert into app_private.product_save_requests(id,actor_id,product_id,request,result) values(p_key,auth.uid(),p_product,request,result);
 return result;
END;
$save_daily_product$;
create or replace view app_private.storefront_variants as
 select p.id as product_id,p.slug,p.name,p.description,p.usage,p.brand_id,b.name as brand,
 p.category_id,c.name as category,c.scope::text as scope,p.product_type_id,t.name as product_type,
 v.id as variant_id,v.original_sku,v.label,price.amount_minor,
 least(greatest(stock.on_hand-stock.reserved,0),99) as available,
 coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'variantId',pm.variant_id,'primary',pm.is_primary,'position',pm.position,
  'alt',coalesce(m.alt,p.name),'source',jsonb_build_object('kind','cloudinary','cloudName',m.cloudinary_cloud_name,
  'publicId',m.cloudinary_public_id,'version',m.cloudinary_version,'format',m.cloudinary_format,
  'publication','published','width',m.width,'height',m.height)) order by (pm.variant_id=v.id) desc,pm.is_primary desc,pm.position,m.id)
  from public.product_media pm join public.media_assets m on m.id=pm.media_id
  where pm.product_id=p.id and (pm.variant_id is null or pm.variant_id=v.id) and m.provider='cloudinary'
  and m.status='approved' and m.lifecycle='linked' and m.cloudinary_format in('jpg','png','webp')
  and m.cloudinary_cloud_name is not null and m.width>0 and m.height>0),'[]') as media,
 coalesce((select jsonb_agg(jsonb_build_object('key',a.key,'label',a.label,'value',a.value,'valueLabel',a.value_label))
  from app_private.storefront_attributes a where a.product_id=p.id and (a.variant_id is null or a.variant_id=v.id)),'[]') as attributes,p.key_benefits
 from public.products p join public.variants v on v.product_id=p.id
 join public.variant_prices price on price.variant_id=v.id and price.approved
 join public.inventory_balances stock on stock.variant_id=v.id and stock.reconciled_at is not null
 join public.categories c on c.id=p.category_id and c.status='published'
 join public.brands b on b.id=p.brand_id and b.status='published'
 join public.product_types t on t.id=p.product_type_id
 where p.status='published' and v.status='published' and public.product_is_public(p.id) and public.variant_is_public(v.id);
create or replace function public.storefront_catalog(p_query text default '',p_scopes text[] default '{}',p_brand text default null,
 p_filters jsonb default '{}',p_sort text default 'relevance',p_page integer default 1,p_size integer default 24,
 p_slug text default null,p_home boolean default false) returns jsonb
language plpgsql stable security definer set search_path='' set statement_timeout='8s' as $catalog$
 declare result jsonb; begin
 if p_filters is null or p_page is null or p_size is null or p_sort is null or p_scopes is null
  or length(coalesce(p_query,''))>160 or jsonb_typeof(p_filters)<>'object' or
  (select count(*) from jsonb_each(p_filters))>16 or exists(select 1 from jsonb_each(p_filters) f where jsonb_typeof(f.value)<>'array' or jsonb_array_length(f.value)>20)
  or cardinality(p_scopes)>8 or p_page not between 1 and 10000 or p_size not between 1 and 48
  or p_sort not in('relevance','price-asc','price-desc','name') then raise exception 'Invalid catalog query' using errcode='22023'; end if;
 with base as materialized (
  select r.*,to_jsonb(r) row_data from app_private.storefront_variants r
  where (cardinality(p_scopes)=0 or r.scope=any(p_scopes)) and (p_brand is null or r.brand_id=p_brand)
  and (p_slug is null or r.slug=p_slug) and app_private.matches_storefront_query(r.variant_id,p_query)
  and (not p_home or exists(select 1 from public.homepage_selections h where h.section='products' and h.product_id=r.product_id and h.status='published'))
 ), matched as materialized(select * from base where app_private.storefront_filter_match(row_data,p_filters)),
 products as (
  select product_id,slug,name,brand_id,brand,category_id,category,scope,product_type_id,product_type,description,usage,key_benefits,min(amount_minor) as min_price,
  coalesce((select min(position) from public.homepage_selections h where h.product_id=m.product_id and h.section='products' and h.status='published'),2147483647) position,
  max(case when lower(name)=lower(p_query) then 100 when lower(name) like lower(p_query)||'%' then 50 else 0 end) relevance,
  jsonb_agg(jsonb_build_object('id',variant_id,'sku',original_sku,'label',coalesce(label,'Standard'),'priceMinor',amount_minor,'available',available,'media',media,'attributes',attributes) order by original_sku) variants
  from matched m group by product_id,slug,name,brand_id,brand,category_id,category,scope,product_type_id,product_type,description,usage,key_benefits
 ), paged as (
  select * from products order by case when p_home then position end,
   case when p_sort='price-asc' then min_price end asc,case when p_sort='price-desc' then min_price end desc,
   case when p_sort='relevance' then relevance end desc,name,product_id limit p_size offset (p_page-1)*p_size
 ), options as (
  select r.product_id,r.row_data,x.key,x.label,x.value,x.value_label from base r cross join lateral (
   select 'brand' key,'Brand' label,r.brand_id value,r.brand value_label union all
   select 'category','Category',r.category_id,r.category union all select 'type','Product type',r.product_type_id,r.product_type union all
   select 'availability','Availability',case when r.available>0 then 'in-stock' else 'out-of-stock' end,case when r.available>0 then 'In stock' else 'Out of stock' end union all
   select a->>'key',a->>'label',a->>'value',a->>'valueLabel' from jsonb_array_elements(r.attributes) a
  ) x
 ), counts as (
  select key,label,value,value_label,count(distinct product_id) count from options
  where app_private.storefront_filter_match(row_data,p_filters,key) group by key,label,value,value_label
 ), groups as (
  select key,label,jsonb_agg(jsonb_build_object('value',value,'label',value_label,'count',count) order by value_label) options
  from counts group by key,label
 ) select jsonb_build_object('version',1,'total',(select count(*) from products),'page',p_page,'size',p_size,
  'products',coalesce((select jsonb_agg(jsonb_build_object('id',product_id,'slug',slug,'name',name,'brandId',brand_id,'brand',brand,
   'categoryId',category_id,'category',category,'scope',scope,'type',product_type,'description',description,'usage',usage,'keyBenefits',key_benefits,'priceMinor',min_price,'variants',variants)) from paged),'[]'),
  'filters',coalesce((select jsonb_agg(jsonb_build_object('key',key,'label',label,'options',options) order by label) from groups),'[]')) into result;
 return result;
end $catalog$;

revoke all on app_private.storefront_variants from public,anon,authenticated;
revoke all on function public.save_daily_product(uuid,integer,jsonb,uuid,text) from public,anon;
grant execute on function public.save_daily_product(uuid,integer,jsonb,uuid,text) to authenticated;

-- Daily list has a bounded page, server-side visibility filter and joined summary.
create function public.admin_product_list(p_query text default '',p_offset integer default 0,p_status text default '') returns jsonb
language plpgsql stable security definer set search_path='' set statement_timeout='8s' as $admin_list$
begin
 perform app_private.require_admin();
 if p_status is null or p_query is null or p_offset is null or p_status not in ('','draft','published','archived') or p_offset not between 0 and 100000 or length(p_query)>160 then raise exception 'Invalid product list query'; end if;
 return coalesce((select jsonb_agg(x order by x.original_sku) from (
 select p.id product_id,v.id variant_id,v.original_sku,p.name,case when p.status='published' then v.status else p.status end status,price.amount_minor price_minor,
 case when stock.reconciled_at is not null then stock.on_hand else null end stock,
 coalesce((select pm.media_id from public.product_media pm where pm.product_id=p.id and (pm.variant_id is null or pm.variant_id=v.id) order by pm.is_primary desc,pm.position limit 1),
 (select w.media_id from public.media_workflows w join public.media_assets m on m.id=w.media_id where w.product_id=p.id and (w.variant_id is null or w.variant_id=v.id) and m.lifecycle in ('private_pending','approved_for_publish','linked') order by w.created_at,w.media_id limit 1)) media_id
 from public.products p join public.variants v on v.product_id=p.id left join public.variant_prices price on price.variant_id=v.id left join public.inventory_balances stock on stock.variant_id=v.id
 where (p_status='' or (case when p.status='published' then v.status else p.status end)::text=p_status) and (p_query='' or v.original_sku ilike '%'||p_query||'%' or p.name ilike '%'||p_query||'%')
 order by v.original_sku limit 50 offset p_offset) x),'[]');
end $admin_list$;
revoke all on function public.admin_product_list(text,integer,text) from public,anon;
grant execute on function public.admin_product_list(text,integer,text) to authenticated;

insert into app_private.sql_editor_receipts(version,filename,sha256) values('202610080012','202610080012_product_markdown.sql','12038d5d88f52a014bca3050567d75e68e8d3066ac8771eb364b47d3f2381bc7');
notify pgrst,'reload schema';
commit;
-- Read-only installed-state check. No business records are returned.
select to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,text)') is not null as daily_editor_present,
 to_regprocedure('public.storefront_reviews(uuid,integer)') is not null as reviews_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610070011' and sha256='0a3d7c1ad1e67b09f876c3c43ea8c335f23e698d32bbc38eee0a595321975e52') as receipt_011_present,
 exists(select 1 from information_schema.columns where table_schema='public' and table_name='products' and column_name='key_benefits') as benefits_present,
 to_regprocedure('public.admin_product_list(text,integer,text)') is not null as product_list_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610080012') as receipt_012_present,
 (select sha256='12038d5d88f52a014bca3050567d75e68e8d3066ac8771eb364b47d3f2381bc7' from app_private.sql_editor_receipts where version='202610080012') as receipt_matches,
 (select relrowsecurity from pg_class where oid='public.products'::regclass) as products_rls;
