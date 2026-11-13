-- COMPLETE incremental migration 013; new DEVELOPMENT SQL Editor query only.
-- Creates private derived indexes/reminders and authorized functions. No business rows are rewritten.
-- DELETE/UPDATE in reminder refresh/Restore touch only new derived/reminder tables, never catalog/stock.
begin;
set local lock_timeout='5s';set local statement_timeout='120s';
select pg_advisory_xact_lock(73523);
do $install_guard$ begin
 if not exists(select 1 from app_private.sql_editor_receipts where version='202610080012' and sha256='12038d5d88f52a014bca3050567d75e68e8d3066ac8771eb364b47d3f2381bc7') then raise exception 'Verify installed migration 012 first';end if;
 if exists(select 1 from app_private.sql_editor_receipts where version='202610090013') or to_regclass('app_private.admin_catalog_search') is not null or to_regclass('app_private.admin_reminder_issues') is not null or to_regclass('app_private.admin_reminder_dismissals') is not null or to_regprocedure('public.admin_catalog_list(text,jsonb,integer,integer)') is not null or to_regprocedure('public.admin_catalog_reminder(text,uuid,boolean)') is not null or to_regprocedure('public.admin_catalog_filter_options(text)') is not null or to_regprocedure('app_private.admin_current_issues(uuid)') is not null or to_regprocedure('app_private.refresh_admin_catalog(uuid)') is not null or to_regclass('app_private.admin_assigned_attributes') is not null or to_regclass('app_private.admin_category_membership') is not null or to_regclass('app_private.admin_list_options') is not null or to_regprocedure('app_private.refresh_admin_catalog_trigger()') is not null or to_regprocedure('app_private.admin_query_matches(uuid,text)') is not null or exists(select 1 from pg_trigger where tgname='zz_refresh_admin_catalog' and not tgisinternal) then raise exception 'Admin list already or partly installed; inspect read-only preflight, do not rerun';end if;
end $install_guard$;
-- Private admin search and reminders only. Does not change publication or business records.
-- Shared membership: primary/additional assignments and all their ancestors.
create view app_private.admin_category_membership as
 with recursive membership(product_id,category_id) as (
 select id,category_id from public.products where category_id is not null
 union select product_id,category_id from public.product_categories
 union select m.product_id,c.parent_id from membership m join public.categories c on c.id=m.category_id where c.parent_id is not null
 ) select product_id,category_id from membership;
-- Active options, one retained history option if all are archived, or a product-only
-- row if no option exists. Both listing and offered filters use this exact set.
create view app_private.admin_list_options as
 select p.id product_id,v.id variant_id from public.products p left join public.variants v on v.product_id=p.id
 where v.id is null or v.status<>'archived' or (
 not exists(select 1 from public.variants a where a.product_id=p.id and a.status<>'archived')
 and v.id=(select a.id from public.variants a where a.product_id=p.id order by a.original_sku,a.id limit 1));
create view app_private.admin_assigned_attributes as
 select f.product_id,f.variant_id,f.facet_id key,d.name label,
 coalesce(f.option_id,f.integer_value::text,f.decimal_value::text,f.boolean_value::text)||coalesce(' '||f.unit,'') value,
 coalesce(v.label,f.integer_value::text,f.decimal_value::text,f.boolean_value::text)||coalesce(' '||f.unit,'') value_label
 from public.product_facets f join public.facet_definitions d on d.id=f.facet_id
 left join public.facet_values v on v.id=f.option_id
 union all select a.product_id,null,'concern','Concern',c.id,c.name
 from public.product_concerns a join public.concerns c on c.id=a.concern_id;
create table app_private.admin_catalog_search (
 variant_id uuid primary key references public.variants(id) on delete cascade,
 document text not null, vector tsvector generated always as(to_tsvector('simple',document)) stored
);
alter table app_private.admin_catalog_search enable row level security;
create index admin_catalog_search_fts on app_private.admin_catalog_search using gin(vector);
create index admin_catalog_search_trgm on app_private.admin_catalog_search using gin(document extensions.gin_trgm_ops);
create table app_private.admin_reminder_issues (
 issue_key text primary key, product_id uuid not null references public.products(id) on delete cascade,
 variant_id uuid references public.variants(id) on delete cascade, code text not null,
 required boolean not null, episode uuid not null default gen_random_uuid(), active boolean not null default true
);
alter table app_private.admin_reminder_issues enable row level security;
create index admin_reminder_product on app_private.admin_reminder_issues(product_id,variant_id) where active;
create table app_private.admin_reminder_dismissals (
 issue_key text not null references app_private.admin_reminder_issues(issue_key) on delete cascade,
 episode uuid not null, actor_id uuid not null references auth.users(id), created_at timestamptz not null default now(),
 primary key(issue_key,episode)
);
alter table app_private.admin_reminder_dismissals enable row level security;
revoke all on app_private.admin_category_membership,app_private.admin_list_options,app_private.admin_assigned_attributes,app_private.admin_catalog_search,app_private.admin_reminder_issues,app_private.admin_reminder_dismissals from public,anon,authenticated;

create function app_private.admin_current_issues(p_product uuid default null) returns table(product_id uuid,variant_id uuid,code text,required boolean)
language sql stable security definer set search_path='' as $issues$
 with product_issues as (
 select p.id product_id,null::uuid variant_id,x.code,x.required from public.products p
 left join lateral(with recursive parents as(select id,parent_id,scope,0 depth from public.categories where id=p.category_id union all select c.id,c.parent_id,c.scope,a.depth+1 from public.categories c join parents a on c.id=a.parent_id) select scope from parents where scope is not null order by depth limit 1) c on true
 cross join lateral (values
 ('description_missing',true,coalesce(btrim(p.description),'')=''),
 ('slug_missing',true,p.slug is null),
 ('usage_missing',false,coalesce(btrim(p.usage),'')='' and coalesce(c.scope::text,'')<>'cutlery'),
 ('benefits_missing',false,coalesce(btrim(p.key_benefits),'')='' and coalesce(c.scope::text,'')<>'cutlery'),
 ('brand_missing',true,p.brand_id is null),
 ('category_type_missing',true,p.category_id is null or p.product_type_id is null),
 ('option_missing',true,not exists(select 1 from public.variants v where v.product_id=p.id and v.status<>'archived'))
 ) x(code,required,missing) where x.missing and (p_product is null or p.id=p_product)
 ), variant_issues as (
 select v.product_id,v.id,x.code,x.required from public.variants v
 left join public.variant_prices price on price.variant_id=v.id
 left join public.inventory_balances b on b.variant_id=v.id
 cross join lateral (select exists(select 1 from public.product_media pm join public.media_assets m on m.id=pm.media_id
 where pm.product_id=v.product_id and (pm.variant_id is null or pm.variant_id=v.id) and pm.is_primary and m.status='approved' and m.provider='cloudinary') approved,
 exists(select 1 from public.media_workflows w join public.media_assets m on m.id=w.media_id where w.product_id=v.product_id and (w.variant_id is null or w.variant_id=v.id) and m.width is not null and m.lifecycle in('private_pending','approved_for_publish','uploading','failed','linked'))
 or exists(select 1 from public.product_media pm where pm.product_id=v.product_id and (pm.variant_id is null or pm.variant_id=v.id)) present) image
 cross join lateral(values
 ('price_missing',true,price.amount_minor is null),('price_approval',true,price.amount_minor is not null and not price.approved),
 ('stock_count_missing',true,b.reconciled_at is null),
 ('out_of_stock',false,b.reconciled_at is not null and b.on_hand-b.reserved<=0),
 ('image_missing',true,not image.present and not image.approved),
 ('image_approval',true,image.present and not image.approved),
 ('set_contents_missing',true,v.sellable_kind='unconfirmed_set' or (v.sellable_kind='factory_set' and not exists(select 1 from public.factory_set_contents s where s.set_variant_id=v.id)))
 ) x(code,required,missing) where v.status<>'archived' and x.missing and (p_product is null or v.product_id=p_product)
 ), other_issues as (
 select p.id,null::uuid,flag,true from public.products p cross join lateral unnest(app_private.publication_blockers(p.id)) flag
 where (p_product is null or p.id=p_product) and flag not in('description_missing','brand_missing','category_type_missing','price_missing','stock_count_missing','approved_image_missing','set_contents_missing')
 and not(flag=any(app_private.daily_product_issues(p.id)))
 union
 select v.product_id,v.id,flag,true from public.import_records r join public.variants v on v.id=r.variant_id
 cross join lateral jsonb_array_elements_text(r.flags) flag where v.status<>'archived' and (p_product is null or v.product_id=p_product) and flag=any(app_private.daily_product_issues(v.product_id))
 ) select * from product_issues union select * from variant_issues union select * from other_issues;
$issues$;

create function app_private.refresh_admin_catalog(p_product uuid default null) returns void language plpgsql security definer set search_path='' as $refresh_admin$
begin
 perform pg_advisory_xact_lock(73526);
 insert into app_private.admin_catalog_search(variant_id,document)
 select v.id,lower(concat_ws(' ',p.name,v.original_sku,v.sku_key,v.label,b.name,t.name,regexp_replace(coalesce(b.name,''),'[^a-zA-Z0-9]','','g'),
 (select string_agg(alias,' ') from public.brand_aliases where brand_id=p.brand_id),
 (select string_agg(alias,' ') from public.sku_aliases where variant_id=v.id),
 (select string_agg(a.value_label,' ') from app_private.admin_assigned_attributes a where a.product_id=v.product_id and (a.variant_id is null or a.variant_id=v.id)),
 (select string_agg(concat_ws(' ',o.label,a.name),' ') from public.variant_options vo join public.option_values o on o.id=vo.value_id join public.option_axes a on a.id=vo.axis_id where vo.variant_id=v.id),
 (select string_agg(a.alias,' ') from public.catalog_search_aliases a where a.product_id=p.id or a.brand_id=p.brand_id or a.category_id=p.category_id or a.product_type_id=p.product_type_id or a.concern_id in(select value from app_private.admin_assigned_attributes x where x.product_id=p.id and x.key='concern')),
 (with recursive cats as (select c.id,c.parent_id,c.name from public.categories c where c.id=p.category_id or c.id in(select category_id from public.product_categories where product_id=p.id)
 union select c.id,c.parent_id,c.name from public.categories c join cats a on c.id=a.parent_id) select string_agg(name,' ') from cats)))
 from public.variants v join public.products p on p.id=v.product_id left join public.brands b on b.id=p.brand_id left join public.product_types t on t.id=p.product_type_id
 where p_product is null or p.id=p_product
 on conflict(variant_id) do update set document=excluded.document where admin_catalog_search.document is distinct from excluded.document;
 with current_issues as materialized(select * from app_private.admin_current_issues(p_product)), resolved as (
 update app_private.admin_reminder_issues i set active=false where i.active and (p_product is null or i.product_id=p_product) and not exists(select 1 from current_issues x where x.product_id=i.product_id and x.variant_id is not distinct from i.variant_id and x.code=i.code) returning issue_key)
 insert into app_private.admin_reminder_issues(issue_key,product_id,variant_id,code,required)
 select product_id::text||':'||coalesce(variant_id::text,'product')||':'||code,product_id,variant_id,code,required from current_issues
 on conflict(issue_key) do update set active=true,required=excluded.required,episode=case when admin_reminder_issues.active then admin_reminder_issues.episode else gen_random_uuid() end;
end $refresh_admin$;
create function app_private.refresh_admin_catalog_trigger() returns trigger language plpgsql security definer set search_path='' as $admin_trigger$
declare r jsonb;owner_id uuid;other_id uuid;begin
 if tg_level='STATEMENT' then perform app_private.refresh_admin_catalog();return null;end if;
 r=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
 if tg_table_name='products' then owner_id=(r->>'id')::uuid;
 elsif r ? 'product_id' then owner_id=(r->>'product_id')::uuid;
 elsif tg_table_name='media_assets' then
  for owner_id in select product_id from public.media_workflows where media_id=(r->>'id')::uuid and product_id is not null union select product_id from public.product_media where media_id=(r->>'id')::uuid loop perform app_private.refresh_admin_catalog(owner_id);end loop;return null;
 else select product_id into owner_id from public.variants where id=coalesce((r->>'variant_id')::uuid,(r->>'set_variant_id')::uuid);end if;
 if owner_id is not null then perform app_private.refresh_admin_catalog(owner_id);end if;
 if tg_op='UPDATE' then
  r=to_jsonb(old);
  if r ? 'product_id' then other_id=(r->>'product_id')::uuid;
  else select product_id into other_id from public.variants where id=coalesce((r->>'variant_id')::uuid,(r->>'set_variant_id')::uuid);end if;
  if other_id is not null and other_id is distinct from owner_id then perform app_private.refresh_admin_catalog(other_id);end if;
 end if;
 return null;
end $admin_trigger$;
-- Ordinary mutations refresh just their owning product. Infrequent taxonomy edits refresh the index set.
do $admin_triggers$ declare t text;begin
 foreach t in array array['brands','brand_aliases','categories','product_types','facet_values','facet_definitions','concerns','evidence','catalog_search_aliases','option_values','option_axes'] loop
 execute format('create trigger zz_refresh_admin_catalog after insert or update or delete on public.%I for each statement execute function app_private.refresh_admin_catalog_trigger()',t);
 end loop;
 foreach t in array array['products','variants','sku_aliases','product_categories','product_facets','product_concerns','variant_options','variant_prices','inventory_balances','product_media','media_assets','media_workflows','factory_set_contents','product_checks','import_records'] loop
 execute format('create trigger zz_refresh_admin_catalog after insert or update or delete on public.%I for each row execute function app_private.refresh_admin_catalog_trigger()',t);
 end loop;
end $admin_triggers$;
select app_private.refresh_admin_catalog();

create function app_private.admin_query_matches(p_variant uuid,p_query text) returns boolean language sql stable set search_path='' as $admin_match$
 select coalesce((select bool_and(s.vector @@ plainto_tsquery('simple',token) or exists(select 1 from regexp_split_to_table(s.document,'[^a-z0-9-]+') word where word like token||'%' or (length(token)>=4 and extensions.similarity(word,token)>=0.45)))
 from regexp_split_to_table(lower(btrim(p_query)),'[^a-z0-9-]+') token cross join app_private.admin_catalog_search s where s.variant_id=p_variant and token<>'' and token not in('for','and','the','a','an','with','of','to')),true);
$admin_match$;
create function public.admin_catalog_list(p_query text default '',p_filters jsonb default '{}',p_offset integer default 0,p_limit integer default 25)
returns jsonb language plpgsql stable security definer set search_path='' set statement_timeout='8s' as $list$
declare result jsonb;begin
 perform app_private.require_admin();
 if p_query is null or length(p_query)>160 or p_offset is null or p_offset not between 0 and 100000 or p_limit is null or p_limit not between 1 and 50 or p_filters is null or jsonb_typeof(p_filters)<>'object' or length(p_filters::text)>10000 then raise exception 'Invalid list request';end if;
 if coalesce(p_filters->>'status','') not in('','draft','published','archived') or coalesce(p_filters->>'mode','any') not in('any','all') or coalesce(p_filters->>'reminders','') not in('','ignored') then raise exception 'Invalid filters';end if;
 if jsonb_typeof(coalesce(p_filters->'issues','[]'))<>'array' or jsonb_typeof(coalesce(p_filters->'facets','{}'))<>'object' then raise exception 'Invalid filters';end if;
 if jsonb_array_length(coalesce(p_filters->'issues','[]'))>12 or exists(select 1 from jsonb_each(coalesce(p_filters->'facets','{}')) x where jsonb_typeof(x.value)<>'array' or jsonb_array_length(x.value)>30) then raise exception 'Too many filters';end if;
 with candidates as (
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
 and (btrim(p_query)='' or (v.id is not null and app_private.admin_query_matches(v.id,p_query)) or (v.id is null and p.name ilike '%'||replace(replace(replace(btrim(p_query),'\','\\'),'%','\%'),'_','\_')||'%'))
 and not exists(select 1 from jsonb_each(coalesce(p_filters->'facets','{}')) f where jsonb_array_length(f.value)>0 and not exists(select 1 from app_private.admin_assigned_attributes a where a.product_id=p.id and (a.variant_id is null or a.variant_id=v.id) and a.key=f.key and a.value in(select jsonb_array_elements_text(f.value))))
 ), filtered as(select * from candidates x where
 (coalesce(p_filters->>'reminders','')<>'ignored' or exists(select 1 from jsonb_array_elements(x.issues) i where (i->>'ignored')::boolean))
 and (jsonb_array_length(coalesce(p_filters->'issues','[]'))=0 or
 case when coalesce(p_filters->>'mode','any')='all' then not exists(select 1 from jsonb_array_elements_text(p_filters->'issues') wanted where not exists(select 1 from jsonb_array_elements(x.issues) i where i->>'code'=wanted or (wanted='publication_blockers' and (i->>'required')::boolean)))
 else exists(select 1 from jsonb_array_elements_text(p_filters->'issues') wanted cross join jsonb_array_elements(x.issues) i where i->>'code'=wanted or (wanted='publication_blockers' and (i->>'required')::boolean)) end)
 ) select jsonb_build_object('rows',coalesce((select jsonb_agg(x order by x.original_sku,x.variant_id) from (select * from filtered order by original_sku,variant_id limit p_limit offset p_offset) x),'[]'),'total',(select count(*) from filtered),'skus',(select count(variant_id) from filtered),'products',(select count(distinct product_id) from filtered),'limit',p_limit,'offset',p_offset) into result;
 return result;
end $list$;

create function public.admin_catalog_filter_options(p_category text default '') returns jsonb language plpgsql stable security definer set search_path='' as $options$
begin
 perform app_private.require_admin();if p_category is null or length(p_category)>120 then raise exception 'Invalid category';end if;
 return(with assigned as(select distinct a.key,a.label,a.value,a.value_label from app_private.admin_assigned_attributes a join app_private.admin_list_options o on o.product_id=a.product_id and (a.variant_id is null or a.variant_id=o.variant_id) where
 (p_category='' or exists(select 1 from app_private.admin_category_membership m where m.product_id=o.product_id and m.category_id=p_category))),
 groups as(select key,label,jsonb_agg(jsonb_build_object('value',value,'label',value_label) order by value_label,value) "values" from assigned group by key,label)
 select coalesce(jsonb_agg(x order by x.label),'[]') from (select * from groups order by label limit 60) x);
end $options$;

create function public.admin_catalog_reminder(p_key text,p_episode uuid,p_ignore boolean) returns void language plpgsql security definer set search_path='' as $reminder$
declare i app_private.admin_reminder_issues;begin
 perform app_private.require_admin();perform pg_advisory_xact_lock(73526);
 select * into i from app_private.admin_reminder_issues where issue_key=p_key and episode=p_episode and active for update;
 if not found or p_ignore is null then raise exception 'Reminder changed; refresh the list';end if;
 if p_ignore then insert into app_private.admin_reminder_dismissals(issue_key,episode,actor_id) values(p_key,p_episode,auth.uid()) on conflict do nothing;
 else delete from app_private.admin_reminder_dismissals where issue_key=p_key and episode=p_episode;end if;
 insert into public.audit_logs(actor_id,operation,table_name,record_key,changed_columns) values(auth.uid(),case when p_ignore then 'IGNORE' else 'RESTORE' end,'admin_reminder_dismissals',i.issue_key,array['episode']);
end $reminder$;
revoke all on function public.admin_catalog_list(text,jsonb,integer,integer),public.admin_catalog_filter_options(text),public.admin_catalog_reminder(text,uuid,boolean) from public,anon;
grant execute on function public.admin_catalog_list(text,jsonb,integer,integer),public.admin_catalog_filter_options(text),public.admin_catalog_reminder(text,uuid,boolean) to authenticated;
revoke all on function app_private.admin_current_issues(uuid),app_private.refresh_admin_catalog(uuid),app_private.refresh_admin_catalog_trigger(),app_private.admin_query_matches(uuid,text) from public,anon,authenticated;

insert into app_private.sql_editor_receipts(version,filename,sha256) values('202610090013','202610090013_admin_catalog_list.sql','de9272e1f837c654aa613e84fbabc8e1e12fc6248475764573a6a153d46e51b0');
notify pgrst,'reload schema';
commit;
-- READ ONLY. No business records or credentials returned.
select exists(select 1 from app_private.sql_editor_receipts where version='202610080012' and sha256='12038d5d88f52a014bca3050567d75e68e8d3066ac8771eb364b47d3f2381bc7') as prerequisite_012,
 to_regclass('app_private.admin_catalog_search') is not null as search_present,
 to_regclass('app_private.admin_reminder_issues') is not null as issues_present,
 to_regclass('app_private.admin_reminder_dismissals') is not null as dismissals_present,
 to_regclass('app_private.admin_category_membership') is not null as category_membership_present,
 to_regclass('app_private.admin_list_options') is not null as list_options_present,
 to_regclass('app_private.admin_assigned_attributes') is not null as attributes_present,
 to_regprocedure('app_private.refresh_admin_catalog_trigger()') is not null as refresh_trigger_present,
 to_regprocedure('app_private.refresh_admin_catalog(uuid)') is not null as refresh_present,
 to_regprocedure('app_private.admin_current_issues(uuid)') is not null as current_issues_present,
 to_regprocedure('app_private.admin_query_matches(uuid,text)') is not null as query_matches_present,
 to_regprocedure('public.admin_catalog_list(text,jsonb,integer,integer)') is not null as list_present,
 to_regprocedure('public.admin_catalog_filter_options(text)') is not null as filters_present,
 to_regprocedure('public.admin_catalog_reminder(text,uuid,boolean)') is not null as reminder_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610090013') as receipt_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610090013' and sha256='de9272e1f837c654aa613e84fbabc8e1e12fc6248475764573a6a153d46e51b0') as receipt_matches,
 (select bool_and(c.relrowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='app_private' and c.relname in('admin_catalog_search','admin_reminder_issues','admin_reminder_dismissals')) as private_rls,
 (select count(*) from pg_policies where schemaname='app_private' and tablename in('admin_catalog_search','admin_reminder_issues','admin_reminder_dismissals'))=0 as no_client_policies,
 (select count(*)=26 from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and t.tgname='zz_refresh_admin_catalog' and not t.tgisinternal and t.tgenabled='O' and t.tgfoid=to_regprocedure('app_private.refresh_admin_catalog_trigger()')) as refresh_triggers_installed;
