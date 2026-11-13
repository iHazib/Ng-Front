-- Incremental 014: exact SKU/approved SKU alias priority; no catalog data changes.
create or replace function public.admin_catalog_list(p_query text default '',p_filters jsonb default '{}',p_offset integer default 0,p_limit integer default 25)
returns jsonb language plpgsql stable security definer set search_path='' set statement_timeout='8s' as $list$
declare result jsonb;begin
 perform app_private.require_admin();
 if p_query is null or length(p_query)>160 or p_offset is null or p_offset not between 0 and 100000 or p_limit is null or p_limit not between 1 and 50 or p_filters is null or jsonb_typeof(p_filters)<>'object' or length(p_filters::text)>10000 then raise exception 'Invalid list request';end if;
 if coalesce(p_filters->>'status','') not in('','draft','published','archived') or coalesce(p_filters->>'mode','any') not in('any','all') or coalesce(p_filters->>'reminders','') not in('','ignored') then raise exception 'Invalid filters';end if;
 if jsonb_typeof(coalesce(p_filters->'issues','[]'))<>'array' or jsonb_typeof(coalesce(p_filters->'facets','{}'))<>'object' then raise exception 'Invalid filters';end if;
 if jsonb_array_length(coalesce(p_filters->'issues','[]'))>12 or exists(select 1 from jsonb_each(coalesce(p_filters->'facets','{}')) x where jsonb_typeof(x.value)<>'array' or jsonb_array_length(x.value)>30) then raise exception 'Too many filters';end if;
 -- Resolve identifiers globally BEFORE filters or active-option eligibility.
 -- Existing admin-managed sku_aliases are approved identifiers, not fuzzy catalog aliases.
 with exact_identifiers as materialized (
 select v.id from public.variants v where v.sku_key=public.sku_collision_key(regexp_replace(p_query,'^\s+|\s+$','','g'))
 union
 select a.variant_id from public.sku_aliases a where a.collision_key=public.sku_collision_key(regexp_replace(p_query,'^\s+|\s+$','','g'))
 ), candidates as (
 select p.id product_id,v.id variant_id,v.original_sku,p.name,p.status,v.label variant_label,v.status variant_status,price.amount_minor price_minor,
 case when b.reconciled_at is not null then b.on_hand else null end stock,b.reserved,
 coalesce((select pm.media_id from public.product_media pm where pm.product_id=p.id and (pm.variant_id is null or pm.variant_id=v.id) order by pm.is_primary desc,pm.position,pm.id limit 1),
 (select w.media_id from public.media_workflows w join public.media_assets m on m.id=w.media_id where w.product_id=p.id and (w.variant_id is null or w.variant_id=v.id) and m.width is not null and m.lifecycle in('private_pending','approved_for_publish','uploading','failed','linked') order by w.created_at,w.media_id limit 1)) media_id,
 coalesce((select jsonb_agg(jsonb_build_object('key',i.issue_key,'episode',i.episode,'code',i.code,'required',i.required,'variantId',i.variant_id,'ignored',d.issue_key is not null) order by i.required desc,i.code) from app_private.admin_reminder_issues i left join app_private.admin_reminder_dismissals d on d.issue_key=i.issue_key and d.episode=i.episode where i.active and i.product_id=p.id and (i.variant_id is null or i.variant_id=v.id)),'[]') issues
 from app_private.admin_list_options o join public.products p on p.id=o.product_id left join public.variants v on v.id=o.variant_id left join public.variant_prices price on price.variant_id=v.id left join public.inventory_balances b on b.variant_id=v.id
 where (coalesce(p_filters->>'status','')='' or p.status::text=p_filters->>'status')
 and (coalesce(p_filters->>'brand','')='' or p.brand_id=p_filters->>'brand')
 and (coalesce(p_filters->>'category','')='' or exists(select 1 from app_private.admin_category_membership m where m.product_id=p.id and m.category_id=p_filters->>'category'))
 and (coalesce(p_filters->>'type','')='' or p.product_type_id=p_filters->>'type')
 and (case when exists(select 1 from exact_identifiers) then v.id in(select id from exact_identifiers)
 else (btrim(p_query)='' or (v.id is not null and app_private.admin_query_matches(v.id,p_query)) or (v.id is null and p.name ilike '%'||replace(replace(replace(btrim(p_query),'\','\\'),'%','\%'),'_','\_')||'%')) end)
 and not exists(select 1 from jsonb_each(coalesce(p_filters->'facets','{}')) f where jsonb_array_length(f.value)>0 and not exists(select 1 from app_private.admin_assigned_attributes a where a.product_id=p.id and (a.variant_id is null or a.variant_id=v.id) and a.key=f.key and a.value in(select jsonb_array_elements_text(f.value))))
 ), filtered as(select * from candidates x where
 (coalesce(p_filters->>'reminders','')<>'ignored' or exists(select 1 from jsonb_array_elements(x.issues) i where (i->>'ignored')::boolean))
 and (jsonb_array_length(coalesce(p_filters->'issues','[]'))=0 or
 case when coalesce(p_filters->>'mode','any')='all' then not exists(select 1 from jsonb_array_elements_text(p_filters->'issues') wanted where not exists(select 1 from jsonb_array_elements(x.issues) i where i->>'code'=wanted or (wanted='publication_blockers' and (i->>'required')::boolean)))
 else exists(select 1 from jsonb_array_elements_text(p_filters->'issues') wanted cross join jsonb_array_elements(x.issues) i where i->>'code'=wanted or (wanted='publication_blockers' and (i->>'required')::boolean)) end)
 ) select jsonb_build_object('rows',coalesce((select jsonb_agg(x order by x.original_sku,x.variant_id) from (select * from filtered order by original_sku,variant_id limit p_limit offset p_offset) x),'[]'),'total',(select count(*) from filtered),'skus',(select count(variant_id) from filtered),'products',(select count(distinct product_id) from filtered),'limit',p_limit,'offset',p_offset) into result;
 return result;
end $list$;

revoke all on function public.admin_catalog_list(text,jsonb,integer,integer) from public,anon;
grant execute on function public.admin_catalog_list(text,jsonb,integer,integer) to authenticated;
