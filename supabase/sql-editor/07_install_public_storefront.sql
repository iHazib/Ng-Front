-- CLEAN COMPLETE INSTALLER. Replace the entire query; never append or combine edits.
-- Run ONCE in a NEW empty DEVELOPMENT Supabase SQL Editor query after read-only preflight.
-- Source: supabase/migrations/202610070009_public_storefront.sql; source receipt SHA-256: f7d321de75bb11b75d6540eef0a5de4d69ddf6f44c6d0f9e4c45dce8594a6588
-- Adds public RPCs, approved aliases and private RLS search; no business data changes.
-- No DROP/TRUNCATE/reset. Private search-index upserts and new object creation only.
begin;
set local lock_timeout='5s';
set local statement_timeout='120s';
select pg_advisory_xact_lock(73524);
do $preflight$ begin
 if to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,text)') is null then raise exception 'Migration 008 is required'; end if;
 if to_regclass('app_private.sql_editor_receipts') is null then raise exception 'SQL Editor receipt registry required'; end if;
 if to_regclass('public.catalog_search_aliases') is not null
 or to_regclass('app_private.storefront_search') is not null
 or to_regclass('app_private.storefront_attributes') is not null
 or to_regclass('app_private.storefront_variants') is not null
 or exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where (n.nspname='public' and p.proname in('storefront_catalog','storefront_navigation'))
   or (n.nspname='app_private' and p.proname in('refresh_storefront_search','refresh_storefront_trigger','matches_storefront_query','storefront_filter_match')))
 or exists(select 1 from pg_trigger where tgname='refresh_storefront_search' and not tgisinternal)
 or exists(select 1 from app_private.sql_editor_receipts where version='202610070009')
 then raise exception 'Storefront objects or receipt already exist. Stop and inspect 07_preflight_public_storefront.sql; no existing objects or data were changed.'; end if;
END;
$preflight$;
-- Additive public storefront projection. No business rows are published/changed.
create table public.catalog_search_aliases (
 id uuid primary key default gen_random_uuid(), product_id uuid references public.products(id),
 category_id text references public.categories(id), brand_id text references public.brands(id),
 concern_id text references public.concerns(id), product_type_id text references public.product_types(id),
 alias text not null check(length(btrim(alias)) between 2 and 100),
 status public.review_status not null default 'pending', reviewed_by uuid references auth.users(id), reviewed_at timestamptz,
 check(num_nonnulls(product_id,category_id,brand_id,concern_id,product_type_id)=1),
 check(status<>'approved' or (reviewed_by is not null and reviewed_at is not null))
);
alter table public.catalog_search_aliases enable row level security;
revoke all on public.catalog_search_aliases from public,anon,authenticated;
grant select,insert,update,delete on public.catalog_search_aliases to authenticated;
create policy admin_access on public.catalog_search_aliases to authenticated using((select public.is_admin())) with check((select public.is_admin()));
create trigger audit_changes after insert or update or delete on public.catalog_search_aliases for each row execute function app_private.audit_change();
create index catalog_alias_product on public.catalog_search_aliases(product_id) where status='approved';
create index catalog_alias_category on public.catalog_search_aliases(category_id) where status='approved';
create index catalog_alias_concern on public.catalog_search_aliases(concern_id) where status='approved';

-- Only approved assignments backed by currently approved evidence enter filters/search.
create view app_private.storefront_attributes as
 select f.product_id,f.variant_id,f.facet_id as key,d.name as label,
 coalesce(f.option_id,f.integer_value::text,f.decimal_value::text,f.boolean_value::text)||coalesce(' '||f.unit,'') as value,
 coalesce(v.label,f.integer_value::text,f.decimal_value::text,f.boolean_value::text)||coalesce(' '||f.unit,'') as value_label
 from public.product_facets f join public.facet_definitions d on d.id=f.facet_id and d.active
 join public.evidence e on e.id=f.evidence_id and e.status='approved'
 left join public.facet_values v on v.id=f.option_id where f.status='approved'
 union all
 select f.product_id,null,'concern','Concern',c.id,c.name from public.product_concerns f
 join public.concerns c on c.id=f.concern_id and c.active
 join public.evidence e on e.id=f.evidence_id and e.status='approved' where f.status='approved';

create table app_private.storefront_search (
 variant_id uuid primary key references public.variants(id) on delete cascade,
 document text not null, vector tsvector generated always as(to_tsvector('simple',document)) stored
);
alter table app_private.storefront_search enable row level security;
-- No client-access policies: only the table-owning SECURITY DEFINER boundary
-- reads/maintains this projection. Client privileges remain revoked below.
create index storefront_search_fts on app_private.storefront_search using gin(vector);
create index storefront_search_trgm on app_private.storefront_search using gin(document extensions.gin_trgm_ops);
revoke all on app_private.storefront_search,app_private.storefront_attributes from public,anon,authenticated;

create function app_private.refresh_storefront_search() returns void language sql security definer set search_path='' as $refresh$
 insert into app_private.storefront_search(variant_id,document)
 select v.id,lower(concat_ws(' ',p.name,b.name,c.name,t.name,v.original_sku,v.sku_key,v.label,
  (with recursive parents as(select id,parent_id,name from public.categories where id=p.category_id
   union all select c.id,c.parent_id,c.name from public.categories c join parents a on c.id=a.parent_id)
   select string_agg(name,' ') from parents),
  regexp_replace(coalesce(b.name,''),'[^a-zA-Z0-9]','','g'),
  (select string_agg(a.alias,' ') from public.brand_aliases a where a.brand_id=b.id),
  (select string_agg(a.alias,' ') from public.sku_aliases a where a.variant_id=v.id),
  (select string_agg(a.value_label,' ') from app_private.storefront_attributes a where a.product_id=p.id and (a.variant_id is null or a.variant_id=v.id)),
  (select string_agg(a.alias,' ') from public.catalog_search_aliases a where a.status='approved' and
    (a.product_id=p.id or a.brand_id=p.brand_id or a.category_id=p.category_id or a.product_type_id=p.product_type_id
     or a.concern_id in(select x.value from app_private.storefront_attributes x where x.product_id=p.id and x.key='concern')))))
 from public.variants v join public.products p on p.id=v.product_id
 left join public.brands b on b.id=p.brand_id left join public.categories c on c.id=p.category_id
 left join public.product_types t on t.id=p.product_type_id
 on conflict(variant_id) do update set document=excluded.document where storefront_search.document is distinct from excluded.document;
$refresh$;
create function app_private.refresh_storefront_trigger() returns trigger language plpgsql security definer set search_path='' as $trigger$
 begin perform app_private.refresh_storefront_search(); return null; end;
$trigger$;
-- Small-store index refresh is one set-based statement, never one HTTP query per SKU.
do $triggers$ declare t text; begin
 foreach t in array array['products','variants','brands','brand_aliases','sku_aliases','categories','product_types','product_facets','product_concerns','facet_values','facet_definitions','concerns','evidence','catalog_search_aliases'] loop
 execute format('create trigger refresh_storefront_search after insert or update or delete on public.%I for each statement execute function app_private.refresh_storefront_trigger()',t);
 end loop;
end $triggers$;
select app_private.refresh_storefront_search();

create function app_private.matches_storefront_query(p_variant uuid,p_query text) returns boolean
language sql stable set search_path='' as $match$
 select coalesce((select bool_and(
  s.vector @@ plainto_tsquery('simple',token)
  or exists(select 1 from regexp_split_to_table(s.document,'[^a-z0-9-]+') word
    where word like token||'%' or (length(token)>=4 and extensions.similarity(word,token)>=0.45))
 ) from regexp_split_to_table(lower(left(btrim(coalesce(p_query,'')),160)),'[^a-z0-9-]+') token
 cross join app_private.storefront_search s where s.variant_id=p_variant
 and token<>'' and token not in('for','and','the','a','an','with','of','to')),true);
$match$;

-- JSON payload is an explicit public field allowlist. No evidence, costs, raw source,
-- internal stock/reservation records or Storage paths are returned even for admins.
create view app_private.storefront_variants as
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
  from app_private.storefront_attributes a where a.product_id=p.id and (a.variant_id is null or a.variant_id=v.id)),'[]') as attributes
 from public.products p join public.variants v on v.product_id=p.id
 join public.variant_prices price on price.variant_id=v.id and price.approved
 join public.inventory_balances stock on stock.variant_id=v.id and stock.reconciled_at is not null
 join public.categories c on c.id=p.category_id and c.status='published'
 join public.brands b on b.id=p.brand_id and b.status='published'
 join public.product_types t on t.id=p.product_type_id
 where p.status='published' and v.status='published' and public.product_is_public(p.id) and public.variant_is_public(v.id);
revoke all on app_private.storefront_variants from public,anon,authenticated;

create function app_private.storefront_filter_match(row_data jsonb,filters jsonb,ignore_key text default '') returns boolean
language sql immutable set search_path='' as $filters$
 select not exists(select 1 from jsonb_each(filters) f(key,vals) where key<>ignore_key and not (
   case key when 'brand' then vals ? (row_data->>'brand_id')
   when 'category' then vals ? (row_data->>'category_id')
   when 'variant' then vals ? (row_data->>'variant_id')
   when 'type' then vals ? (row_data->>'product_type_id')
   when 'availability' then vals ? (case when (row_data->>'available')::integer>0 then 'in-stock' else 'out-of-stock' end)
   else exists(select 1 from jsonb_array_elements(row_data->'attributes') a where a->>'key'=key and vals ? (a->>'value')) end));
$filters$;
create function public.storefront_catalog(p_query text default '',p_scopes text[] default '{}',p_brand text default null,
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
  select product_id,slug,name,brand_id,brand,category_id,category,scope,product_type_id,product_type,description,usage,min(amount_minor) as min_price,
  coalesce((select min(position) from public.homepage_selections h where h.product_id=m.product_id and h.section='products' and h.status='published'),2147483647) position,
  max(case when lower(name)=lower(p_query) then 100 when lower(name) like lower(p_query)||'%' then 50 else 0 end) relevance,
  jsonb_agg(jsonb_build_object('id',variant_id,'sku',original_sku,'label',coalesce(label,'Standard'),'priceMinor',amount_minor,'available',available,'media',media,'attributes',attributes) order by original_sku) variants
  from matched m group by product_id,slug,name,brand_id,brand,category_id,category,scope,product_type_id,product_type,description,usage
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
   'categoryId',category_id,'category',category,'scope',scope,'type',product_type,'description',description,'usage',usage,'priceMinor',min_price,'variants',variants)) from paged),'[]'),
  'filters',coalesce((select jsonb_agg(jsonb_build_object('key',key,'label',label,'options',options) order by label) from groups),'[]')) into result;
 return result;
end $catalog$;

create function public.storefront_navigation() returns jsonb language sql stable security definer set search_path='' set statement_timeout='8s' as $navigation$
 with eligible as materialized(select distinct product_id,brand_id,brand,category_id,category,scope,product_type_id,product_type from app_private.storefront_variants),
 ancestors as (with recursive tree as(select c.id,c.parent_id,c.name,c.scope from public.categories c where c.id in(select category_id from eligible)
  union select c.id,c.parent_id,c.name,c.scope from public.categories c join tree t on c.id=t.parent_id where c.status='published') select * from tree)
 select jsonb_build_object('version',1,
  'brands',coalesce((select jsonb_agg(x order by x.name) from(select brand_id id,brand name,count(distinct product_id) count,array_agg(distinct scope) scopes from eligible group by brand_id,brand) x),'[]'),
  'categories',coalesce((select jsonb_agg(x order by x.name) from(select id,parent_id,name,scope from ancestors) x),'[]'),
  'types',coalesce((select jsonb_agg(x) from(select scope,product_type_id id,product_type name,count(distinct product_id) count from eligible group by scope,product_type_id,product_type) x),'[]'),
  'concerns',coalesce((select jsonb_agg(x) from(select a.value id,a.value_label name,count(distinct a.product_id) count from app_private.storefront_attributes a join eligible e on e.product_id=a.product_id where a.key='concern' group by a.value,a.value_label) x),'[]'));
$navigation$;
revoke all on function public.storefront_catalog(text,text[],text,jsonb,text,integer,integer,text,boolean),public.storefront_navigation() from public,anon,authenticated;
grant execute on function public.storefront_catalog(text,text[],text,jsonb,text,integer,integer,text,boolean),public.storefront_navigation() to anon,authenticated;
revoke all on all functions in schema app_private from public,anon,authenticated;
notify pgrst,'reload schema';

insert into app_private.sql_editor_receipts(version,filename,sha256)
values('202610070009','202610070009_public_storefront.sql','f7d321de75bb11b75d6540eef0a5de4d69ddf6f44c6d0f9e4c45dce8594a6588');
commit;
select to_regprocedure('public.storefront_navigation()') is not null as storefront_present,
 (select relrowsecurity from pg_class where oid='public.catalog_search_aliases'::regclass) as aliases_rls,
 (select relrowsecurity from pg_class where oid='app_private.storefront_search'::regclass) as search_rls;
