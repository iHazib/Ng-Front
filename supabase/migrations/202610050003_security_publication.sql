-- Optional concerns never enter this gate. Photo absence never prevents draft import/admin search.
insert into public.publication_requirements(scope,code,kind,description)
select s,code,'essential',description from unnest(enum_range(null::public.catalog_scope)) s
cross join (values
 ('identity','Exact family/variant/package identity and brand or approved unbranded status'),
 ('taxonomy','Category and product type reviewed'),
 ('content','Accurate name and category-appropriate description'),
 ('condition','Physical condition and applicable label requirements reviewed'),
 ('primary_media','Approved primary photo or explicitly approved neutral placeholder'),
 ('publication_review','Individual publication approval')
) rules(code,description);
insert into public.publication_requirements values
 ('skincare','cosmetic_label','essential','Net quantity, usage/warnings, batch/expiry or PAO applicability'),
 ('makeup','makeup_identity','essential','Shade/finish/size or explicit not-applicable for tools/accessories; cosmetic label review where applicable'),
 ('bath-body','body_scope','essential','Body/hand/nail application area, net size, usage and applicable expiry/PAO'),
 ('hair-care','hair_scope','essential','Hair use, net size, directions and applicable aerosol/safety/expiry labels'),
 ('personal-fragrance','fragrance_identity','essential','Edition, component sizes and applicable concentration/usage labels; no inferred longevity'),
 ('home-fragrance','home_use','essential','Component formats/sizes and applicable home-use safety instructions'),
 ('cutlery','cutlery_specification','essential','Piece count/types, material/coating, dimensions and approved care/food-contact information');
insert into public.publication_requirements(scope,code,kind,description)
select s,code,'optional',description from unnest(enum_range(null::public.catalog_scope)) s
cross join (values ('concerns','Evidence-backed concern assignments; research partially complete'),
 ('secondary_media','Genuine additional images'),('reviews','Approved customer reviews'),
 ('enrichment','Optional verified filters, collections and editorial links')) r(code,description);

create function app_private.publication_blockers(p_product uuid) returns text[]
language plpgsql stable security definer set search_path='' as $$
declare p public.products; product_scope public.catalog_scope; missing text[]; begin
  select * into p from public.products where id=p_product;
  if not found then return array['product_missing']; end if;
  select c.scope into product_scope from public.categories c where c.id=p.category_id;
  select coalesce(array_agg(r.code order by r.code),'{}') into missing
    from public.publication_requirements r where r.scope=product_scope and r.kind='essential'
    and not exists(select 1 from public.product_checks c where c.product_id=p_product and c.code=r.code and c.approved);
  if product_scope is null or p.product_type_id is null then missing=array_append(missing,'category_type_missing'); end if;
  if not p.identity_confirmed then missing=array_append(missing,'identity_not_confirmed'); end if;
  if p.product_type_id='sunscreen' and not exists(select 1 from public.product_checks c where c.product_id=p_product and c.code='spf_label' and c.approved) then missing=array_append(missing,'spf_label'); end if;
  if p.slug is null or p.description is null or btrim(p.description)='' then missing=array_append(missing,'public_copy_missing'); end if;
  if not exists(select 1 from public.categories c where c.id=p.category_id and c.status='published') then missing=array_append(missing,'category_not_published'); end if;
  if p.brand_id is not null and not exists(select 1 from public.brands b where b.id=p.brand_id and b.status='published') then missing=array_append(missing,'brand_not_published'); end if;
  if not exists(select 1 from public.product_media pm join public.media_assets m on m.id=pm.media_id where pm.product_id=p_product and pm.is_primary and m.status='approved' and m.provider='cloudinary') then missing=array_append(missing,'approved_primary_media_missing'); end if;
  if not exists(select 1 from public.variants v join public.variant_prices price on price.variant_id=v.id
    join public.inventory_balances b on b.variant_id=v.id where v.product_id=p_product and v.status='published'
    and v.identity_confirmed and price.approved and b.reconciled_at is not null) then missing=array_append(missing,'approved_variant_price_stock_missing'); end if;
  if exists(select 1 from public.variants v where v.product_id=p_product and v.status='published' and v.sellable_kind='unconfirmed_set') then missing=array_append(missing,'set_identity_pending'); end if;
  if exists(select 1 from public.variants v where v.product_id=p_product and v.status='published' and v.sellable_kind='factory_set'
    and not exists(select 1 from public.factory_set_contents c where c.set_variant_id=v.id)) then missing=array_append(missing,'set_contents_missing'); end if;
  return missing;
end $$;
create function public.publication_report(p_product uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$ begin
  perform app_private.require_admin();
  return jsonb_build_object('essential_blockers',app_private.publication_blockers(p_product),'concern_research','partially_complete','optional_enrichment',jsonb_build_array('concerns','secondary_media','reviews','verified_extra_facets'));
end $$;
create function public.product_is_public(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.products where id=p_id and status='published') and cardinality(app_private.publication_blockers(p_id))=0
$$;
create function public.variant_is_public(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.variants v join public.variant_prices p on p.variant_id=v.id
    join public.inventory_balances b on b.variant_id=v.id where v.id=p_id and v.status='published' and v.identity_confirmed
    and v.sellable_kind<>'unconfirmed_set' and p.approved and b.reconciled_at is not null and public.product_is_public(v.product_id))
$$;
create function app_private.guard_publication() returns trigger language plpgsql set search_path='' as $$
declare missing text[]; begin
  if new.status='published' then
    -- BEFORE trigger checks existing row for dependent state; NEW fields are checked separately.
    if not new.identity_confirmed or new.slug is null or new.description is null then raise exception 'Publication identity/copy incomplete'; end if;
    missing=app_private.publication_blockers(new.id);
    if cardinality(missing)>0 then raise exception 'Publication requirements incomplete: %',array_to_string(missing,','); end if;
  end if;
  new.updated_at=now(); new.revision=old.revision+1;
  return new;
end $$;
create trigger guard_publication before update on public.products for each row execute function app_private.guard_publication();

create function app_private.validate_facet() returns trigger language plpgsql set search_path='' as $$ begin
  if not exists(select 1 from public.products p join public.categories c on c.id=p.category_id
    join public.facet_scopes s on s.scope=c.scope and s.facet_id=new.facet_id where p.id=new.product_id) then raise exception 'Facet outside category scope'; end if;
  if new.status='approved' and not exists(select 1 from public.evidence where id=new.evidence_id and status='approved') then raise exception 'Approved evidence required'; end if;
  return new;
end $$;
create trigger validate_facet before insert or update on public.product_facets for each row execute function app_private.validate_facet();
create function app_private.validate_concern() returns trigger language plpgsql set search_path='' as $$ begin
  if not exists(select 1 from public.products p join public.categories c on c.id=p.category_id where p.id=new.product_id and c.scope='skincare') then raise exception 'Concern outside skincare scope'; end if;
  if new.status='approved' and not exists(select 1 from public.evidence where id=new.evidence_id and status='approved') then raise exception 'Approved product-specific evidence required'; end if;
  return new;
end $$;
create trigger validate_concern before insert or update on public.product_concerns for each row execute function app_private.validate_concern();

create function public.media_is_public(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.media_assets m where m.id=p_id and m.provider='cloudinary' and m.status='approved') and (
    exists(select 1 from public.product_media pm where pm.media_id=p_id and public.product_is_public(pm.product_id) and (pm.variant_id is null or public.variant_is_public(pm.variant_id)))
    or exists(select 1 from public.article_media am join public.articles a on a.id=am.article_id where am.media_id=p_id and a.status='published' and a.published_at<=now())
    or exists(select 1 from public.homepage_selections h where h.media_id=p_id and h.status='published' and h.section='hero')
  )
$$;
create function public.deal_is_public(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.deals where id=p_id and status='published' and price_minor is not null)
    and exists(select 1 from public.deal_components where deal_id=p_id)
    and not exists(select 1 from public.deal_components where deal_id=p_id and not public.variant_is_public(variant_id))
$$;

-- Explicit grants plus policies. No user metadata is trusted for administrator membership.
do $$ declare t record; begin
  for t in select tablename from pg_tables where schemaname='public' and tablename in ('brands','brand_aliases','categories','product_types','category_product_types','products','product_categories','variants','sku_aliases','variant_prices','option_axes','option_values','variant_options','facet_definitions','facet_scopes','facet_values','evidence','product_facets','concerns','product_concerns','collections','collection_products','media_assets','product_media','factory_set_contents','import_batches','import_records','product_checks','publication_requirements','audit_logs','orders','deals','deal_components','order_items','order_item_components','inventory_balances','inventory_movements','inventory_reservations','sales','refunds','shipments','shipment_items','reviews','review_private','articles','article_media','homepage_selections') loop
    execute format('alter table public.%I enable row level security',t.tablename);
    execute format('revoke all on public.%I from anon, authenticated',t.tablename);
    execute format('grant select,insert,update,delete on public.%I to authenticated',t.tablename);
    execute format('create policy admin_access on public.%I to authenticated using ((select public.is_admin())) with check ((select public.is_admin()))',t.tablename);
  end loop;
end $$;
grant usage on schema public,extensions to anon,authenticated;
grant usage,select on sequence public.audit_logs_id_seq to authenticated;

do $$ declare t text; begin
  foreach t in array array['brands','brand_aliases','categories','product_types','category_product_types','products','product_categories','variants','variant_prices','option_axes','option_values','variant_options','facet_definitions','facet_scopes','facet_values','product_facets','concerns','product_concerns','collections','collection_products','media_assets','product_media','factory_set_contents','deals','deal_components','reviews','articles','article_media','homepage_selections'] loop
    execute format('grant select on public.%I to anon',t);
  end loop;
end $$;
create policy public_read on public.products for select to anon,authenticated using(public.product_is_public(id));
create policy public_read on public.variants for select to anon,authenticated using(public.variant_is_public(id));
create policy public_read on public.variant_prices for select to anon,authenticated using(approved and public.variant_is_public(variant_id));
create policy public_read on public.brands for select to anon,authenticated using(status='published' and exists(select 1 from public.products p where p.brand_id=brands.id));
create policy public_read on public.brand_aliases for select to anon,authenticated using(exists(select 1 from public.brands b where b.id=brand_id));
create policy public_read on public.categories for select to anon,authenticated using(status='published');
create policy public_read on public.product_types for select to anon,authenticated using(exists(select 1 from public.products p where p.product_type_id=product_types.id));
create policy public_read on public.category_product_types for select to anon,authenticated using(exists(select 1 from public.products p where p.category_id=category_product_types.category_id and p.product_type_id=category_product_types.product_type_id));
create policy public_read on public.product_categories for select to anon,authenticated using(public.product_is_public(product_id));
create policy public_read on public.variant_options for select to anon,authenticated using(public.variant_is_public(variant_id));
create policy public_read on public.option_values for select to anon,authenticated using(exists(select 1 from public.variant_options o where o.value_id=option_values.id));
create policy public_read on public.option_axes for select to anon,authenticated using(exists(select 1 from public.variant_options o where o.axis_id=option_axes.id));
create policy public_read on public.product_facets for select to anon,authenticated using(status='approved' and public.product_is_public(product_id) and (variant_id is null or public.variant_is_public(variant_id)));
create policy public_read on public.facet_definitions for select to anon,authenticated using(active and exists(select 1 from public.product_facets f where f.facet_id=facet_definitions.id));
create policy public_read on public.facet_scopes for select to anon,authenticated using(exists(select 1 from public.facet_definitions f where f.id=facet_id));
create policy public_read on public.facet_values for select to anon,authenticated using(exists(select 1 from public.product_facets f where f.option_id=facet_values.id));
create policy public_read on public.product_concerns for select to anon,authenticated using(status='approved' and public.product_is_public(product_id));
create policy public_read on public.concerns for select to anon,authenticated using(active and exists(select 1 from public.product_concerns p where p.concern_id=concerns.id));
create policy public_read on public.collections for select to anon,authenticated using(status='published');
create policy public_read on public.collection_products for select to anon,authenticated using(public.product_is_public(product_id) and exists(select 1 from public.collections c where c.id=collection_id));
create policy public_read on public.media_assets for select to anon,authenticated using(public.media_is_public(id));
create policy public_read on public.product_media for select to anon,authenticated using(public.media_is_public(media_id) and public.product_is_public(product_id) and (variant_id is null or public.variant_is_public(variant_id)));
create policy public_read on public.factory_set_contents for select to anon,authenticated using(public.variant_is_public(set_variant_id));
create policy public_read on public.deals for select to anon,authenticated using(public.deal_is_public(id));
create policy public_read on public.deal_components for select to anon,authenticated using(public.deal_is_public(deal_id));
create policy public_read on public.reviews for select to anon,authenticated using(status='approved' and public.product_is_public(product_id));
create policy public_read on public.articles for select to anon,authenticated using(status='published' and published_at<=now());
create policy public_read on public.article_media for select to anon,authenticated using(public.media_is_public(media_id) and exists(select 1 from public.articles a where a.id=article_id));
create policy public_read on public.homepage_selections for select to anon,authenticated using(status='published'
  and (product_id is null or public.product_is_public(product_id))
  and (article_id is null or exists(select 1 from public.articles a where a.id=article_id))
  and (category_id is null or exists(select 1 from public.categories c where c.id=category_id))
  and (brand_id is null or exists(select 1 from public.brands b where b.id=brand_id))
  and (media_id is null or public.media_is_public(media_id)));

-- Financial/stock history is append-only; stock RPCs alone mutate balances/reservations.
revoke insert,update,delete on public.inventory_balances,public.inventory_movements,public.inventory_reservations,public.order_item_components,public.audit_logs from authenticated;
revoke update,delete on public.sales,public.refunds,public.import_batches,public.import_records from authenticated;
revoke all on all functions in schema app_private from public,anon,authenticated;
do $$ declare f record; begin
  for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('is_admin','sku_collision_key','karachi_day_bounds','adjust_inventory','reserve_order','finish_reservation','publication_report','product_is_public','variant_is_public','media_is_public','deal_is_public') loop
    execute format('revoke all on function %s from public,anon,authenticated',f.signature);
  end loop;
end $$;
grant execute on function public.is_admin(),public.sku_collision_key(text),public.product_is_public(uuid),public.variant_is_public(uuid),public.media_is_public(uuid),public.deal_is_public(uuid),public.karachi_day_bounds(date) to anon,authenticated;
grant execute on function public.publication_report(uuid),public.adjust_inventory(uuid,integer,text,text),public.reserve_order(uuid,text,timestamptz),public.finish_reservation(uuid,boolean) to authenticated;

create function app_private.audit_change() returns trigger language plpgsql security definer set search_path='' as $$
declare data jsonb; fields text[]; begin
  data=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
  if tg_op='UPDATE' then
    select array_agg(key order by key) into fields from jsonb_each(data) where value is distinct from to_jsonb(old)->key;
  else select array_agg(key order by key) into fields from jsonb_each(data); end if;
  insert into public.audit_logs(actor_id,table_name,record_key,operation,changed_columns)
    values(auth.uid(),tg_table_name,coalesce(data->>'id',data->>'variant_id',data->>'product_id'),tg_op,coalesce(fields,'{}'));
  if tg_op='DELETE' then return old; end if; return new;
end $$;
revoke all on function app_private.audit_change() from public,anon,authenticated;
do $$ declare t record; begin
  for t in select tablename from pg_tables where schemaname='public' and tablename<>'audit_logs' and tablename in ('brands','brand_aliases','categories','product_types','category_product_types','products','product_categories','variants','sku_aliases','variant_prices','option_axes','option_values','variant_options','facet_definitions','facet_scopes','facet_values','evidence','product_facets','concerns','product_concerns','collections','collection_products','media_assets','product_media','factory_set_contents','import_batches','import_records','product_checks','publication_requirements','audit_logs','orders','deals','deal_components','order_items','order_item_components','inventory_balances','inventory_movements','inventory_reservations','sales','refunds','shipments','shipment_items','reviews','review_private','articles','article_media','homepage_selections') loop
    execute format('create trigger audit_changes after insert or update or delete on public.%I for each row execute function app_private.audit_change()',t.tablename);
  end loop;
  -- Index every foreign-key column sequence, including private order/media relations.
  for t in select c.conrelid::regclass rel,c.conname,array_to_string(array_agg(quote_ident(a.attname) order by u.ord),',') cols
    from pg_constraint c cross join lateral unnest(c.conkey) with ordinality u(num,ord)
    join pg_attribute a on a.attrelid=c.conrelid and a.attnum=u.num
    where c.contype='f' and c.connamespace='public'::regnamespace and c.conrelid in (select oid from pg_class where relnamespace='public'::regnamespace and relname in ('brands','brand_aliases','categories','product_types','category_product_types','products','product_categories','variants','sku_aliases','variant_prices','option_axes','option_values','variant_options','facet_definitions','facet_scopes','facet_values','evidence','product_facets','concerns','product_concerns','collections','collection_products','media_assets','product_media','factory_set_contents','import_batches','import_records','product_checks','publication_requirements','audit_logs','orders','deals','deal_components','order_items','order_item_components','inventory_balances','inventory_movements','inventory_reservations','sales','refunds','shipments','shipment_items','reviews','review_private','articles','article_media','homepage_selections')) group by c.oid loop
    execute format('create index on %s (%s)',t.rel,t.cols);
  end loop;
end $$;
