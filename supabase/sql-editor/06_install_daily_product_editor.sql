-- CLEAN COMPLETE INSTALLER: daily editor v2. Replace the entire SQL Editor query; do not append.
-- Run this entire file once in a NEW DEVELOPMENT Supabase SQL Editor query.
-- Installation preserves existing business records, source values, stock and audit history.
-- Adds audited counts and atomic saves; replaces blanket publication review requirements.
-- Corrected visibility contract: ordinary Save retains statuses; Draft/Publish/Hide are explicit intents.
-- Runtime functions may clear a price or homepage selection only when an admin explicitly saves that choice.
begin;
set local lock_timeout='5s';
set local statement_timeout='120s';
select pg_advisory_xact_lock(73523);
do $install_guard$ begin
 if to_regclass('public.media_workflows') is null then raise exception 'Media service migration required first'; end if;
 if to_regclass('public.inventory_counts') is not null
 or to_regclass('app_private.product_save_requests') is not null
 or to_regprocedure('app_private.daily_product_issues(uuid)') is not null
 or to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,text)') is not null
 or to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,boolean)') is not null
 or exists(select 1 from app_private.sql_editor_receipts where version='202610060008')
 or strpos(pg_get_functiondef('public.publication_report(uuid)'::regprocedure),'daily_editor_version')>0
 or strpos(pg_get_functiondef('app_private.publication_blockers(uuid)'::regprocedure),'daily_product_issues')>0
 then raise exception 'Daily editor objects already exist. Stop and inspect 06_preflight_daily_product_editor.sql; no existing objects or data were changed.'; end if;
END;
$install_guard$;
-- Daily product editor. Preserve source records, claims, SKU identities and audit history.
create table public.inventory_counts (
 id uuid primary key default gen_random_uuid(), variant_id uuid not null references public.variants(id),
 previous_count integer not null, counted integer not null check(counted>=0),
 actor_id uuid not null references auth.users(id), recorded_at timestamptz not null default now(),
 operation_id uuid not null, unique(operation_id,variant_id)
);
alter table public.inventory_counts enable row level security;
revoke all on public.inventory_counts from public,anon,authenticated;
grant select on public.inventory_counts to authenticated;
create policy admin_read on public.inventory_counts for select to authenticated using((select public.is_admin()));
create trigger audit_changes after insert on public.inventory_counts for each row execute function app_private.audit_change();
create table app_private.product_save_requests (
 id uuid primary key, actor_id uuid not null references auth.users(id), product_id uuid not null references public.products(id),
 request jsonb not null, result jsonb not null, created_at timestamptz not null default now()
);
alter table app_private.product_save_requests enable row level security;
revoke all on app_private.product_save_requests from public,anon,authenticated;

-- Specific unresolved package/identity issues only; generic import/research flags are not publication gates.
create function app_private.daily_product_issues(p_product uuid) returns text[] language sql stable security definer set search_path='' as $daily_issues$
 select coalesce(array_agg(distinct flag order by flag),'{}') from public.import_records r
 join public.variants v on v.id=r.variant_id cross join lateral jsonb_array_elements_text(r.flags) f(flag)
 where v.product_id=p_product and v.status<>'archived' and flag in (
 'brand_and_set_formats_unresolved','brand_missing_do_not_assign_store_brand','dior_generation_and_identity_pending',
 'eye_cream_unit_review','factory_pack_and_contents_unconfirmed','fruit_variant_and_size_unconfirmed',
 'identity_and_application_area_unresolved','kit_contents_and_scope_unresolved','net_weight_needs_package_check',
 'regional_formula_and_face_body_scope_unresolved','shade_code_name_conflict','shade_missing','size_missing',
 'size_or_component_quantity_unresolved','spf_and_exact_sunscreen_variant_missing')
 and not exists(select 1 from public.product_checks c where c.product_id=p_product and c.code=flag and c.approved)
$daily_issues$;
create or replace function app_private.publication_blockers(p_product uuid) returns text[] language plpgsql stable security definer set search_path='' as $publication_blockers$
declare p public.products; missing text[]='{}'; begin
 select * into p from public.products where id=p_product;
 if not found then return array['product_missing']; end if;
 if btrim(p.name)='' then missing=array_append(missing,'name_missing'); end if;
 if p.brand_id is null then missing=array_append(missing,'brand_missing'); end if;
 if p.category_id is null or p.product_type_id is null then missing=array_append(missing,'category_type_missing'); end if;
 if p.slug is null or coalesce(btrim(p.description),'')='' then missing=array_append(missing,'description_missing'); end if;
 if not exists(select 1 from public.variants where product_id=p_product and status<>'archived') then missing=array_append(missing,'option_missing'); end if;
 if exists(select 1 from public.variants v left join public.variant_prices price on price.variant_id=v.id where v.product_id=p_product and v.status<>'archived' and (price.amount_minor is null or not price.approved)) then missing=array_append(missing,'price_missing'); end if;
 if exists(select 1 from public.variants v left join public.inventory_balances b on b.variant_id=v.id where v.product_id=p_product and v.status<>'archived' and b.reconciled_at is null) then missing=array_append(missing,'stock_count_missing'); end if;
 if exists(select 1 from public.variants v where v.product_id=p_product and v.status<>'archived' and not exists(
   select 1 from public.product_media pm join public.media_assets m on m.id=pm.media_id
   where pm.product_id=p_product and (pm.variant_id is null or pm.variant_id=v.id) and pm.is_primary and m.status='approved' and m.provider='cloudinary'
 )) then missing=array_append(missing,'approved_image_missing'); end if;
 if exists(select 1 from public.variants where product_id=p_product and status<>'archived' and sellable_kind='unconfirmed_set') then missing=array_append(missing,'set_contents_missing'); end if;
 if exists(select 1 from public.variants v where v.product_id=p_product and v.status<>'archived' and v.sellable_kind='factory_set' and not exists(select 1 from public.factory_set_contents c where c.set_variant_id=v.id)) then missing=array_append(missing,'set_contents_missing'); end if;
 if p.product_type_id='sunscreen' and not exists(select 1 from public.product_checks where product_id=p_product and code='spf_label' and approved) then missing=array_append(missing,'spf_label'); end if;
 return missing||app_private.daily_product_issues(p_product);
END;
$publication_blockers$;
create or replace function public.publication_report(p_product uuid) returns jsonb language plpgsql stable security definer set search_path='' as $publication_report$ begin
 perform app_private.require_admin();
 return jsonb_build_object('essential_blockers',app_private.publication_blockers(p_product),'specific_issues',app_private.daily_product_issues(p_product),'optional_enrichment',jsonb_build_array('concerns','secondary_media','reviews'),'concern_research','partially_complete','daily_editor_version',2);
END;
$publication_report$;

create function public.save_daily_product(p_product uuid,p_revision integer,p_data jsonb,p_key uuid,p_intent text default 'save')
returns jsonb language plpgsql security definer set search_path='' as $save_daily_product$
declare p public.products; variant_row public.variants; r jsonb; prior app_private.product_save_requests; request jsonb; result jsonb;
 ids uuid[]='{}'; vid uuid; old_count integer; counted integer; held integer; price bigint; blockers text[]; option_count integer; pos integer; issue_code text; target_status public.publication_status;
begin
 perform app_private.require_admin();
 if p_intent is null or p_intent not in ('save','draft','publish','hide') then raise exception 'Choose Save, Draft, Publish or Hide'; end if;
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
 update public.products set status=case when p_intent='publish' then p.status else target_status end,name=p_data->>'name',description=nullif(p_data->>'description',''),
 brand_id=nullif(p_data->>'brand',''),category_id=nullif(p_data->>'category',''),product_type_id=nullif(p_data->>'productType',''),
 slug=coalesce(slug,'product-'||replace(p_product::text,'-','')) where id=p_product;
 exception when raise_exception then
  -- Existing BEFORE guards can reject missing copy/SPF or already invalid published dependencies.
  -- Translate those into the same actionable, atomic rejection; never silently hide the product.
  if p.status='published' and p_intent in ('save','publish') then
   blockers=app_private.publication_blockers(p_product);
   if coalesce(btrim(p_data->>'description'),'')='' then blockers=array_append(blockers,'description_missing'); end if;
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
revoke all on function app_private.daily_product_issues(uuid) from public,anon,authenticated;
revoke all on function public.save_daily_product(uuid,integer,jsonb,uuid,text) from public,anon,authenticated;
grant execute on function public.save_daily_product(uuid,integer,jsonb,uuid,text) to authenticated;

insert into app_private.sql_editor_receipts(version,filename,sha256) values('202610060008','202610060008_daily_product_editor.sql','0e9c481792f93592a8a1c49d04fdf70051e4ef6142a59d4b707ef86b7b583a92');
notify pgrst,'reload schema';
commit;
select to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,text)') is not null as daily_editor_installed,
 (select relrowsecurity from pg_class where oid='public.inventory_counts'::regclass) as count_audit_rls;
