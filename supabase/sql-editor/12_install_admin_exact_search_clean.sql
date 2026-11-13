-- COMPLETE incremental 014. Apply once in DEVELOPMENT after read-only preflight.
-- Replaces only the authorized admin list function; preserves catalog, stock and original SKUs.
-- No DROP, TRUNCATE, DELETE or business-row UPDATE. Existing migration 013 is untouched.
begin;
set local lock_timeout='5s';set local statement_timeout='120s';
select pg_advisory_xact_lock(73523);
do $install_guard$ begin
 if not exists(select 1 from app_private.sql_editor_receipts where version='202610090013' and sha256='de9272e1f837c654aa613e84fbabc8e1e12fc6248475764573a6a153d46e51b0') then raise exception 'Verify canonical installed migration 013 first';end if;
 if exists(select 1 from app_private.sql_editor_receipts where version='202610120014') or position('exact_identifiers as materialized' in pg_get_functiondef(to_regprocedure('public.admin_catalog_list(text,jsonb,integer,integer)')))>0 then raise exception 'Exact search already or partly installed; inspect preflight, do not rerun';end if;
 if to_regprocedure('public.admin_catalog_list(text,jsonb,integer,integer)') is null then raise exception 'Admin list missing; inspect installed state';end if;
end $install_guard$;
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

insert into app_private.sql_editor_receipts(version,filename,sha256) values('202610120014','202610120014_admin_exact_identifier_search.sql','3f771bd8309cd0c1de097e93b6aaf76963d7a18c1f26029fb7047ec2c86e53c3');
notify pgrst,'reload schema';
commit;
-- READ ONLY: run before installation and again afterwards. No business data returned.
select exists(select 1 from app_private.sql_editor_receipts where version='202610090013' and sha256='de9272e1f837c654aa613e84fbabc8e1e12fc6248475764573a6a153d46e51b0') as prerequisite_013,
 to_regprocedure('public.admin_catalog_list(text,jsonb,integer,integer)') is not null as list_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610120014') as receipt_014_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610120014' and sha256='3f771bd8309cd0c1de097e93b6aaf76963d7a18c1f26029fb7047ec2c86e53c3') as receipt_014_matches,
 coalesce(position('exact_identifiers as materialized' in pg_get_functiondef(to_regprocedure('public.admin_catalog_list(text,jsonb,integer,integer)')))>0,false) as exact_priority_present,
 (select p.prosecdef and (p.proconfig @> array['search_path='] or p.proconfig @> array['search_path=""']) and (p.proconfig @> array['statement_timeout=8s'] or p.proconfig @> array['statement_timeout=8000']) and position('require_admin()' in p.prosrc)>0 and pg_get_userbyid(p.proowner)='postgres' from pg_proc p where p.oid=to_regprocedure('public.admin_catalog_list(text,jsonb,integer,integer)')) as authorization_preserved,
 not has_function_privilege('anon','public.admin_catalog_list(text,jsonb,integer,integer)','execute') and has_function_privilege('authenticated','public.admin_catalog_list(text,jsonb,integer,integer)','execute') as rpc_grants_preserved,
 (select bool_and(relrowsecurity) from pg_class where oid in('app_private.admin_catalog_search'::regclass,'app_private.admin_reminder_issues'::regclass,'app_private.admin_reminder_dismissals'::regclass)) as private_rls,
 not exists(select 1 from pg_policies where schemaname='app_private' and tablename in('admin_catalog_search','admin_reminder_issues','admin_reminder_dismissals')) as no_client_policies;
