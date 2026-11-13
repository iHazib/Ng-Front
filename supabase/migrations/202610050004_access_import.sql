create function public.admin_search_catalog(p_query text default '',p_limit integer default 50,p_offset integer default 0)
returns table(product_id uuid,variant_id uuid,original_sku text,name text,status public.publication_status)
language plpgsql stable security definer set search_path='' as $$ begin
  perform app_private.require_admin();
  return query select p.id,v.id,v.original_sku,p.name,p.status from public.products p join public.variants v on v.product_id=p.id
    where coalesce(p_query,'')='' or p.search_vector @@ websearch_to_tsquery('simple',left(p_query,160))
      or v.original_sku ilike '%'||left(p_query,160)||'%' or p.name ilike '%'||left(p_query,160)||'%'
      or extensions.similarity(p.name,left(p_query,160))>0.25
    order by v.original_sku limit least(greatest(p_limit,1),200) offset greatest(p_offset,0);
end $$;
create function public.search_published_catalog(p_query text,p_limit integer default 30)
returns table(product_id uuid,name text,slug text) language sql stable set search_path='' as $$
  select p.id,p.name,p.slug from public.products p where p.search_vector @@ websearch_to_tsquery('simple',left(p_query,160))
    or extensions.similarity(p.name,left(p_query,160))>0.25 order by p.name limit least(greatest(p_limit,1),100)
$$;

create function public.import_catalog_drafts(p_source_hash text,p_contract_hash text,p_version text,p_records jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare batch uuid; r jsonb; vid uuid; pid uuid; existing uuid; previous jsonb; result_state text; rows_count integer=0; quarantine_count integer=0;
begin
  perform app_private.require_admin();
  if jsonb_typeof(p_records)<>'array' or jsonb_array_length(p_records)>5000 then raise exception 'Expected bounded record array'; end if;
  insert into public.import_batches(source_sha256,contract_sha256,contract_version,created_by)
    values(p_source_hash,p_contract_hash,p_version,auth.uid()) on conflict(source_sha256,contract_sha256) do nothing returning id into batch;
  if batch is null then
    select id into batch from public.import_batches where source_sha256=p_source_hash and contract_sha256=p_contract_hash;
    return jsonb_build_object('batch_id',batch,'state','unchanged');
  end if;
  for r in select value from jsonb_array_elements(p_records) loop
    begin
      if coalesce(r->>'original_sku','')='' then raise exception 'Missing SKU'; end if;
      if (select count(*) from jsonb_array_elements(p_records) x where public.sku_collision_key(x->>'original_sku')=public.sku_collision_key(r->>'original_sku'))>1 then raise exception 'Batch SKU collision'; end if;
      if jsonb_array_length(coalesce(r->'blocking_import_errors','[]'))>0 then raise exception 'Source row quarantined'; end if;
      select v.id,v.product_id into vid,pid from public.variants v where v.original_sku=r->>'original_sku';
      if not found then
        pid=(r->>'product_id')::uuid; vid=(r->>'variant_id')::uuid;
        -- New source identity cannot commandeer another product/variant UUID.
        if exists(select 1 from public.products where id=pid) or exists(select 1 from public.variants where id=vid) then raise exception 'Identity UUID already used'; end if;
        insert into public.products(id,name,brand_id,category_id,product_type_id)
          values(pid,r->'raw_source_fields'->>'Product Name',r->>'normalized_brand_id',r->>'proposed_category',r->>'product_type');
        insert into public.variants(id,product_id,original_sku,sellable_kind)
          values(vid,pid,r->>'original_sku',case when r->>'sellable_kind'='factory_set_candidate' then 'unconfirmed_set' else 'single' end);
        insert into public.inventory_balances(variant_id) values(vid);
        if (r->>'source_target_minor')::bigint>0 then
          insert into public.variant_prices(variant_id,amount_minor) values(vid,(r->>'source_target_minor')::bigint);
        end if;
        result_state='staged';
      else
        select ir.raw_fields into previous from public.import_records ir join public.import_batches b on b.id=ir.batch_id
          where ir.variant_id=vid order by b.created_at desc,ir.id limit 1;
        result_state=case when previous=r->'raw_source_fields' then 'unchanged' else 'needs_review' end;
        -- No update of live product, price, stock, media, approval or admin-owned values.
      end if;
      insert into public.import_records(batch_id,source_row,original_sku,variant_id,raw_fields,mapping,source_quantity,
        source_cost_minor,source_target_minor,source_minimum_minor,source_market_minor,state,flags)
        values(batch,(r->'source'->>'row')::integer,r->>'original_sku',vid,r->'raw_source_fields',r,(r->>'source_stock_units')::integer,
          (r->>'source_cost_minor')::bigint,(r->>'source_target_minor')::bigint,(r->>'source_minimum_minor')::bigint,(r->>'source_market_minor')::bigint,result_state,coalesce(r->'unresolved_flags','[]'));
      rows_count=rows_count+1;
    exception when others then
      -- Savepoint rolls back only this record. Do not leak SQL/customer payload in logs.
      quarantine_count=quarantine_count+1;
      insert into public.import_records(batch_id,source_row,original_sku,raw_fields,mapping,state,flags)
        values(batch,(r->'source'->>'row')::integer,r->>'original_sku',coalesce(r->'raw_source_fields','{}'),r,'quarantined',jsonb_build_array('record_validation_failed',SQLSTATE));
    end;
  end loop;
  return jsonb_build_object('batch_id',batch,'accepted',rows_count,'quarantined',quarantine_count);
end $$;

create function public.set_primary_media(p_product uuid,p_variant uuid,p_media uuid) returns void
language plpgsql security definer set search_path='' as $$ begin
  perform app_private.require_admin();
  perform 1 from public.products where id=p_product for update;
  if not exists(select 1 from public.product_media where product_id=p_product and variant_id is not distinct from p_variant and media_id=p_media) then raise exception 'Media association missing'; end if;
  update public.product_media set is_primary=false where product_id=p_product and variant_id is not distinct from p_variant and is_primary;
  update public.product_media set is_primary=true where product_id=p_product and variant_id is not distinct from p_variant and media_id=p_media;
end $$;

-- Supabase owns storage tables; only our private bucket/policies are managed here.
insert into storage.buckets(id,name,public) values('catalog-private','catalog-private',false) on conflict(id) do update set public=false;
create policy ng_private_admin_read on storage.objects for select to authenticated using(bucket_id='catalog-private' and (select public.is_admin()));
create policy ng_private_admin_insert on storage.objects for insert to authenticated with check(bucket_id='catalog-private' and (select public.is_admin()));
create policy ng_private_admin_update on storage.objects for update to authenticated using(bucket_id='catalog-private' and (select public.is_admin())) with check(bucket_id='catalog-private' and (select public.is_admin()));
create policy ng_private_admin_delete on storage.objects for delete to authenticated using(bucket_id='catalog-private' and (select public.is_admin()));
revoke all on function public.admin_search_catalog(text,integer,integer),public.search_published_catalog(text,integer),public.import_catalog_drafts(text,text,text,jsonb),public.set_primary_media(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.admin_search_catalog(text,integer,integer),public.import_catalog_drafts(text,text,text,jsonb),public.set_primary_media(uuid,uuid,uuid) to authenticated;
grant execute on function public.search_published_catalog(text,integer) to anon,authenticated;
alter function app_private.guard_publication() security definer;
