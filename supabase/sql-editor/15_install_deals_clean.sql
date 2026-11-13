-- Complete incremental 017; apply ONCE after confirmed 016. No earlier installers.
-- No business data reset/delete at installation. Adds columns/tables and replaces guards.
-- Drops/replaces only two media CHECK constraints; existing owner rules are retained.
begin;set local lock_timeout='5s';set local statement_timeout='120s';
select pg_advisory_xact_lock(73525);
do $guard$ begin
 if not exists(select 1 from app_private.sql_editor_receipts where version='202610150016' and sha256='d0e29a69895ac34b808371c40c126235f7b7d019ee77874b218b3a65cbfdb612') then raise exception 'Verify canonical 016 receipt first';end if;
 if exists(select 1 from app_private.sql_editor_receipts where version='202610160017') or to_regclass('app_private.deal_settings') is not null or to_regclass('app_private.deal_pools') is not null or to_regclass('public.deal_media') is not null or to_regprocedure('public.save_deal(uuid,integer,uuid,text,jsonb)') is not null then raise exception 'Deals already or partly installed; inspect state, do not rerun';end if;
end $guard$;
-- 017 assembled deals. No catalog families, existing orders or physical counts are rewritten.
alter table public.deals add column description text,add column starts_at timestamptz,add column ends_at timestamptz,
 add constraint deal_window check(ends_at is null or starts_at is null or ends_at>starts_at);
create table app_private.deal_settings(deal_id uuid primary key references public.deals(id),revision integer not null default 1,generation integer not null default 1,set_aside integer not null default 0 check(set_aside between 0 and 10000));
create table app_private.deal_pools(deal_id uuid references public.deals(id),variant_id uuid references public.variants(id),quantity integer not null check(quantity>0),generation integer not null,primary key(deal_id,variant_id));
create table app_private.deal_operations(id uuid primary key,deal_id uuid not null references public.deals(id),request_hash text not null,actor_id uuid not null references auth.users(id),created_at timestamptz not null default now());
create table app_private.deal_allocation_events(id bigint generated always as identity primary key,deal_id uuid not null references public.deals(id),variant_id uuid not null references public.variants(id),delta integer not null check(delta<>0),reason text not null,order_id uuid references public.orders(id),actor_id uuid references auth.users(id),at timestamptz not null default now());
create table app_private.order_component_snapshots(order_item_id uuid references public.order_items(id),variant_id uuid references public.variants(id),quantity integer not null check(quantity>0),sku text not null,product_name text not null,option_name text not null,standalone_minor bigint not null check(standalone_minor>0),attributed_minor bigint not null check(attributed_minor>=0),primary key(order_item_id,variant_id));
create table app_private.order_pool_sources(order_id uuid references public.orders(id),deal_id uuid references public.deals(id),variant_id uuid references public.variants(id),generation integer not null,quantity integer not null check(quantity>0),returned boolean not null default false,primary key(order_id,deal_id,variant_id));
create index deal_pools_variant on app_private.deal_pools(variant_id);
create index order_pool_sources_variant on app_private.order_pool_sources(variant_id);
create index deal_allocation_history on app_private.deal_allocation_events(deal_id,at);
create index deal_window_active on public.deals(status,ends_at,starts_at);
create table public.deal_media(id uuid primary key default gen_random_uuid(),deal_id uuid not null references public.deals(id),media_id uuid not null references public.media_assets(id),position integer not null check(position>=0),is_primary boolean not null default false,unique(deal_id,position),unique(deal_id,media_id));
create unique index deal_media_primary on public.deal_media(deal_id) where is_primary;
alter table public.homepage_selections add column deal_id uuid references public.deals(id);
alter table public.homepage_selections add constraint homepage_deal_owner check(deal_id is null or (section='products' and num_nonnulls(product_id,article_id,category_id,brand_id)=0));
create index homepage_deal_owner on public.homepage_selections(deal_id);
alter table public.media_workflows add column deal_id uuid references public.deals(id);
alter table public.media_workflows drop constraint media_exact_owner,drop constraint media_content_owner_kind;
alter table public.media_workflows add constraint media_exact_owner check(num_nonnulls(product_id,article_id,homepage_id,review_id,payment_order_id,deal_id)=1),
 add constraint media_content_owner_kind check((product_id is not null and content_kind is null) or (article_id is not null and content_kind in('cover','inline')) or (homepage_id is not null and content_kind='slide') or (review_id is not null and content_kind is null) or (payment_order_id is not null and content_kind is null) or (deal_id is not null and content_kind is null));
create index deal_workflow_owner on public.media_workflows(deal_id);
create function app_private.deal_history_immutable() returns trigger language plpgsql set search_path='' as $$ begin raise exception 'Deal and order history is append only';end $$;
do $$ declare t text;begin
 foreach t in array array['deal_settings','deal_pools','deal_operations','deal_allocation_events','order_component_snapshots','order_pool_sources'] loop
 execute format('alter table app_private.%I enable row level security',t);execute format('revoke all on app_private.%I from public,anon,authenticated,service_role',t);end loop;
 foreach t in array array['deal_operations','deal_allocation_events','order_component_snapshots'] loop execute format('create trigger immutable before update or delete on app_private.%I for each row execute function app_private.deal_history_immutable()',t);end loop;
end $$;
alter table public.deal_media enable row level security;
grant select on public.deal_media to anon,authenticated;
create policy admin_read on public.deal_media for select to authenticated using((select public.is_admin()));
revoke insert,update,delete on public.deals,public.deal_components from authenticated;
create trigger media_reference_guard before insert or update on public.deal_media for each row execute function app_private.guard_media_reference();
create trigger audit_changes after insert or update or delete on public.deal_media for each row execute function app_private.audit_change();
create function app_private.deal_pool_open(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.deals d where d.id=p_id and d.status='published' and d.price_minor>0 and d.slug is not null and length(btrim(d.name))>0 and (d.ends_at is null or d.ends_at>now()))
 and exists(select 1 from public.deal_components where deal_id=p_id)
 and not exists(select 1 from public.deal_components c where c.deal_id=p_id and (not public.variant_is_public(c.variant_id) or not public.product_is_public((select product_id from public.variants where id=c.variant_id))))
 and exists(select 1 from public.deal_media dm join public.media_assets a on a.id=dm.media_id where dm.deal_id=p_id and a.provider='cloudinary' and a.status='approved' and a.lifecycle='linked' and length(btrim(a.alt))>0 and a.cloudinary_cloud_name is not null and a.cloudinary_version>0 and a.width>0 and a.height>0);
$$;
create or replace function public.deal_is_public(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$ select app_private.deal_pool_open(p_id) and exists(select 1 from public.deals where id=p_id and (starts_at is null or starts_at<=now()));$$;
create policy public_read on public.deal_media for select to anon,authenticated using(public.deal_is_public(deal_id));
alter function public.media_is_public(uuid) rename to media_is_public_016;
alter function public.media_is_public_016(uuid) set schema app_private;
create function public.media_is_public(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$ select app_private.media_is_public_016(p_id) or exists(select 1 from public.deal_media dm join public.media_assets a on a.id=dm.media_id where dm.media_id=p_id and public.deal_is_public(dm.deal_id) and a.status='approved' and a.provider='cloudinary' and a.lifecycle='linked');$$;
-- Pool deltas alter reserved, never on_hand. All writers take the same transaction gate first.
create function app_private.release_deal_pool(p_id uuid,p_reason text) returns void language plpgsql set search_path='' as $$ declare r record;begin
 for r in select * from app_private.deal_pools where deal_id=p_id order by variant_id for update loop
 update public.inventory_balances set reserved=reserved-r.quantity where variant_id=r.variant_id;
 insert into app_private.deal_allocation_events(deal_id,variant_id,delta,reason,actor_id) values(p_id,r.variant_id,-r.quantity,p_reason,auth.uid());end loop;
 delete from app_private.deal_pools where deal_id=p_id;
end $$;
create function public.expire_deal_allocations(p_limit integer default 100) returns integer language plpgsql security definer set search_path='' as $$ declare d uuid;n integer=0;begin
 if p_limit not between 1 and 500 then raise exception 'Invalid batch limit';end if;
 perform pg_advisory_xact_lock(73525);
 for d in select distinct p.deal_id from app_private.deal_pools p where not app_private.deal_pool_open(p.deal_id) order by p.deal_id limit p_limit loop perform app_private.release_deal_pool(d,'deal ended or became ineligible');n=n+1;end loop;return n;
end $$;
create function public.admin_deals(p_id uuid default null,p_query text default '',p_offset integer default 0) returns jsonb language plpgsql stable security definer set search_path='' as $$ begin
 perform app_private.require_admin();if length(p_query)>120 or p_offset not between 0 and 100000 then raise exception 'Invalid deal filters';end if;
 return(with matched as(select d.* from public.deals d where (p_id is null or d.id=p_id) and (btrim(p_query)='' or position(lower(p_query) in lower(d.name||' '||coalesce(d.slug,'')))>0)),page as(select * from matched order by name,id limit 25 offset p_offset)
 select jsonb_build_object('total',(select count(*) from matched),'rows',coalesce(jsonb_agg(to_jsonb(page)||jsonb_build_object('revision',coalesce(s.revision,1),'setAside',coalesce(s.set_aside,0),'idle',coalesce((select jsonb_agg(jsonb_build_object('variant',p.variant_id,'quantity',p.quantity)) from app_private.deal_pools p where p.deal_id=page.id),'[]'),'homepage',exists(select 1 from public.homepage_selections h where h.deal_id=page.id and h.status='published' and h.retired_at is null),'homePosition',(select position from public.homepage_selections where deal_id=page.id and retired_at is null limit 1),'components',coalesce((select jsonb_agg(jsonb_build_object('id',v.id,'sku',v.original_sku,'name',p.name,'label',coalesce(v.label,''),'quantity',c.quantity,'eligible',public.variant_is_public(v.id) and public.product_is_public(p.id))) from public.deal_components c join public.variants v on v.id=c.variant_id join public.products p on p.id=v.product_id where c.deal_id=page.id),'[]'),'uploads',coalesce((select jsonb_agg(to_jsonb(a)||jsonb_build_object('reviewed',w.reviewed_at is not null)) from public.media_workflows w join public.media_assets a on a.id=w.media_id where w.deal_id=page.id and a.lifecycle not in('deleted','retired','linked')),'[]'),'media',coalesce((select jsonb_agg(to_jsonb(dm)||jsonb_build_object('asset',to_jsonb(a)) order by dm.is_primary desc,dm.position) from public.deal_media dm join public.media_assets a on a.id=dm.media_id where dm.deal_id=page.id),'[]'))),'[]')) from page left join app_private.deal_settings s on s.deal_id=page.id);
end $$;
create function public.save_deal(p_id uuid,p_revision integer,p_key uuid,p_intent text,p_data jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
 declare d public.deals;s app_private.deal_settings;prior app_private.deal_operations;rh text;c record;target integer;state public.publication_status;pos integer;selection uuid;begin
 perform app_private.require_admin();perform pg_advisory_xact_lock(73525);
 if p_id is null or p_key is null or p_revision is null or p_revision<0 or coalesce(p_intent,'') not in('save','draft','publish','hide') or p_data is null or jsonb_typeof(p_data)<>'object' or length(p_data::text)>30000 then raise exception 'Invalid deal save';end if;
 rh=encode(sha256(convert_to(jsonb_build_array(p_id,p_revision,p_intent,p_data)::text,'UTF8')),'hex');select * into prior from app_private.deal_operations where id=p_key;
 if found then if prior.request_hash<>rh then raise exception 'Save retry differs';end if;return public.admin_deals(p_id);end if;
 if length(btrim(coalesce(p_data->>'title',''))) not between 1 and 300 or length(coalesce(p_data->>'description',''))>20000 or coalesce(p_data->>'slug','') !~ '^[a-z0-9]+(-[a-z0-9]+)*$' or length(p_data->>'slug')>180 then raise exception 'Add a title and unique lowercase slug';end if;
 if p_data->>'priceMinor' is not null and (p_data->>'priceMinor' !~ '^[0-9]{1,16}$' or (p_data->>'priceMinor')::numeric not between 1 and 9007199254740991) then raise exception 'Enter a valid PKR price';end if;
 if jsonb_typeof(p_data->'components') is distinct from 'array' or jsonb_array_length(p_data->'components')>20 then raise exception 'Choose at most 20 component rows';end if;
 if exists(select 1 from jsonb_array_elements(p_data->'components') x where coalesce(x->>'id','') !~ '^[a-f0-9-]{36}$' or coalesce(x->>'quantity','') !~ '^[0-9]{1,4}$' or (x->>'quantity')::int not between 1 and 1000) then raise exception 'Check component options and quantities';end if;
 if exists(select 1 from jsonb_array_elements(p_data->'components') x group by (x->>'id')::uuid having sum((x->>'quantity')::int)>10000) then raise exception 'Check combined quantity: maximum 10000 per SKU';end if;
 if coalesce(p_data->>'setAside','0') !~ '^[0-9]{1,5}$' or coalesce(p_data->>'setAside','0')::int not between 0 and 10000 then raise exception 'Check set aside quantity';end if;target=coalesce(p_data->>'setAside','0')::int;
 select * into d from public.deals where id=p_id for update;
 if not found then if p_revision<>0 then raise exception 'Deal not found';end if;
 insert into public.deals(id,name) values(p_id,p_data->>'title') returning * into d;insert into app_private.deal_settings(deal_id) values(p_id);
 elsif coalesce((select revision from app_private.deal_settings where deal_id=p_id),1)<>p_revision then raise exception 'Deal changed. Refresh before saving';end if;
 insert into app_private.deal_settings(deal_id) values(p_id) on conflict do nothing;
 perform app_private.release_deal_pool(p_id,'allocation replaced by explicit deal save');
 state=case p_intent when 'draft' then 'draft'::public.publication_status when 'hide' then 'archived'::public.publication_status when 'publish' then 'published'::public.publication_status else d.status end;
 update public.deals set name=btrim(p_data->>'title'),slug=p_data->>'slug',description=nullif(p_data->>'description',''),price_minor=(p_data->>'priceMinor')::bigint,starts_at=nullif(p_data->>'startsAt','')::timestamptz,ends_at=nullif(p_data->>'endsAt','')::timestamptz,status=state where id=p_id;
 delete from public.deal_components where deal_id=p_id;
 insert into public.deal_components(deal_id,variant_id,quantity) select p_id,(x->>'id')::uuid,sum((x->>'quantity')::int)::int from jsonb_array_elements(p_data->'components') x group by (x->>'id')::uuid;
 if state='published' and not app_private.deal_pool_open(p_id) then raise exception 'Before publishing: add a price, eligible exact component options and an approved image; check the end date';end if;
 update app_private.deal_settings set revision=revision+1,generation=generation+1,set_aside=case when state='published' then target else 0 end where deal_id=p_id returning * into s;
 if state='published' and target>0 then
 for c in select * from public.deal_components where deal_id=p_id order by variant_id loop
 update public.inventory_balances set reserved=reserved+c.quantity*target where variant_id=c.variant_id and reconciled_at is not null and on_hand-reserved>=c.quantity*target;
 if not found then raise exception 'Not enough unreserved stock to set aside. Reduce the allocation';end if;
 insert into app_private.deal_pools values(p_id,c.variant_id,c.quantity*target,s.generation);
 insert into app_private.deal_allocation_events(deal_id,variant_id,delta,reason,actor_id) values(p_id,c.variant_id,c.quantity*target,'explicit deal stock allocation',auth.uid());end loop;
 end if;
 if p_data->>'homepage'='true' and state='published' then
 if (select count(*) from public.homepage_selections where section='products' and status='published' and retired_at is null and deal_id is distinct from p_id)>=12 then raise exception 'Choose at most 12 homepage products and deals. Edit Homepage selections first';end if;
 if coalesce(p_data->>'homePosition','') !~ '^[0-9]{1,4}$' then raise exception 'Choose a homepage position';end if;pos=(p_data->>'homePosition')::int;
 if exists(select 1 from public.homepage_selections where section='products' and position=pos and deal_id is distinct from p_id) then raise exception 'Homepage position is occupied. Choose a free position; existing selections are preserved';end if;
 select id into selection from public.homepage_selections where deal_id=p_id order by retired_at nulls first,position desc limit 1;
 if selection is not null then update public.homepage_selections set position=pos,status='published',retired_at=null where id=selection;
 else insert into public.homepage_selections(section,position,status,deal_id) values('products',pos,'published',p_id);end if;
 else update public.homepage_selections set status='draft' where deal_id=p_id;end if;
 insert into app_private.deal_operations values(p_key,p_id,rh,auth.uid(),now());return public.admin_deals(p_id);
end $$;
create function app_private.deal_public_view(p_id uuid) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('id',d.id,'slug',d.slug,'title',d.name,'description',d.description,'priceMinor',d.price_minor,'revision',coalesce(s.revision,1),
 'homePosition',(select position from public.homepage_selections where deal_id=d.id and status='published' and retired_at is null limit 1),
 'available',coalesce((select min(floor((greatest(case when b.reconciled_at is null then 0 else coalesce(b.on_hand-b.reserved,0) end,0)+coalesce(pool.quantity,0))::numeric/c.quantity))::int from public.deal_components c left join public.inventory_balances b on b.variant_id=c.variant_id left join app_private.deal_pools pool on pool.deal_id=c.deal_id and pool.variant_id=c.variant_id where c.deal_id=d.id),0),
 'standaloneMinor',(select sum(pr.amount_minor::numeric*c.quantity) from public.deal_components c join public.variant_prices pr on pr.variant_id=c.variant_id where c.deal_id=d.id),
 'components',(select jsonb_agg(jsonb_build_object('id',v.id,'sku',v.original_sku,'name',p.name,'label',coalesce(v.label,''),'slug',p.slug,'quantity',c.quantity) order by v.original_sku) from public.deal_components c join public.variants v on v.id=c.variant_id join public.products p on p.id=v.product_id where c.deal_id=d.id),
 'media',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'alt',a.alt,'source',jsonb_build_object('kind','cloudinary','cloudName',a.cloudinary_cloud_name,'publicId',a.cloudinary_public_id,'version',a.cloudinary_version,'format',a.cloudinary_format,'publication','published','width',a.width,'height',a.height)) order by dm.is_primary desc,dm.position) from public.deal_media dm join public.media_assets a on a.id=dm.media_id where dm.deal_id=d.id and a.provider='cloudinary' and a.status='approved' and a.lifecycle='linked'),'[]'))
 from public.deals d left join app_private.deal_settings s on s.deal_id=d.id where d.id=p_id and public.deal_is_public(d.id);
$$;
create function public.storefront_deals(p_slug text default null,p_ids uuid[] default '{}',p_page integer default 1,p_home boolean default false) returns jsonb language plpgsql stable security definer set search_path='' as $$ begin
 if length(p_slug)>180 or cardinality(p_ids)>20 or p_page not between 1 and 10000 then raise exception 'Invalid deal query';end if;
 return(with eligible as(select d.id,d.name,(select min(position) from public.homepage_selections where deal_id=d.id and status='published' and retired_at is null) pos from public.deals d where public.deal_is_public(d.id) and (p_slug is null or d.slug=p_slug) and (cardinality(p_ids)=0 or d.id=any(p_ids)) and (not p_home or exists(select 1 from public.homepage_selections where deal_id=d.id and status='published' and retired_at is null)))
 select jsonb_build_object('total',(select count(*) from eligible),'page',p_page,'homeOrder',case when p_home then (select coalesce(jsonb_agg(jsonb_build_object('id',coalesce(h.product_id,h.deal_id),'kind',case when h.deal_id is not null then 'deal' else 'product' end,'position',h.position) order by h.position),'[]') from public.homepage_selections h where h.section='products' and h.status='published' and h.retired_at is null and ((h.deal_id is not null and public.deal_is_public(h.deal_id)) or (h.product_id is not null and public.product_is_public(h.product_id)))) else '[]'::jsonb end,'deals',coalesce((select jsonb_agg(app_private.deal_public_view(id) order by pos nulls last,name,id) from(select * from eligible order by pos nulls last,name,id limit 24 offset (p_page-1)*24) page),'[]')));
end $$;
create or replace function app_private.commerce_lines(p_lines jsonb) returns void language plpgsql set search_path='' as $$ begin
 if p_lines is null or jsonb_typeof(p_lines)<>'array' or jsonb_array_length(p_lines) not between 1 and 20 or length(p_lines::text)>16000 then raise exception 'Invalid cart';end if;
 if exists(select 1 from jsonb_array_elements(p_lines) x where jsonb_typeof(x)<>'object' or coalesce(x->>'id','') !~ '^[a-f0-9-]{36}$' or coalesce(x->>'kind','variant') not in('variant','deal') or coalesce(x->>'quantity','') !~ '^[0-9]{1,2}$' or (x->>'quantity')::int not between 1 and 99) then raise exception 'Invalid cart line';end if;
 if (select count(distinct coalesce(x->>'kind','variant')||':'||(x->>'id')) from jsonb_array_elements(p_lines) x)<>jsonb_array_length(p_lines) then raise exception 'Duplicate cart line';end if;
end $$;
create function app_private.cart_components(p_lines jsonb) returns table(line_key text,deal_id uuid,variant_id uuid,quantity integer) language sql stable set search_path='' as $$
 with r as(select (x->>'id')::uuid id,coalesce(x->>'kind','variant') kind,(x->>'quantity')::int n from jsonb_array_elements(p_lines) x)
 select id::text,null::uuid,id,n from r where kind='variant'
 union all select 'deal:'||r.id,r.id,c.variant_id,c.quantity*r.n from r join public.deal_components c on c.deal_id=r.id where r.kind='deal';
$$;
create or replace function public.commerce_quote(p_lines jsonb) returns jsonb language plpgsql stable security definer set search_path='' as $$ declare result jsonb;begin
 perform app_private.commerce_lines(p_lines);
 with requested as(select (x->>'id')::uuid uid,coalesce(x->>'kind','variant') kind,(x->>'quantity')::int quantity,x->>'expectedPriceMinor' expected,x->>'expectedDealRevision' revision from jsonb_array_elements(p_lines) x),
 components as(select * from app_private.cart_components(p_lines)),
 demand as(select c.variant_id,sum(c.quantity-least(c.quantity,coalesce(dp.quantity,0))) need from components c left join app_private.deal_pools dp on dp.deal_id=c.deal_id and dp.variant_id=c.variant_id group by c.variant_id),
 short as(select d.variant_id from demand d left join public.inventory_balances b on b.variant_id=d.variant_id where coalesce(b.on_hand-b.reserved,0)<d.need),
 eligible as(select r.*,case when r.kind='deal' then 'deal:'||r.uid else r.uid::text end id,
 case when r.kind='deal' then d.name else p.name end name,case when r.kind='deal' then 'Assembled deal' else coalesce(v.label,'') end label,v.original_sku sku,
 case when r.kind='deal' then d.slug else p.slug end slug,b.name brand,case when r.kind='deal' then d.price_minor else pr.amount_minor end price_minor,
 case when r.kind='deal' then (app_private.deal_public_view(d.id)->>'available')::int else case when ib.reconciled_at is null then 0 else coalesce(ib.on_hand-ib.reserved,0) end end available,
 case when r.kind='deal' then public.deal_is_public(r.uid) else public.variant_is_public(r.uid) and public.product_is_public(p.id) end ok,coalesce(ds.revision,1) deal_revision
 from requested r left join public.deals d on r.kind='deal' and d.id=r.uid left join app_private.deal_settings ds on ds.deal_id=d.id
 left join public.variants v on r.kind='variant' and v.id=r.uid left join public.products p on p.id=v.product_id left join public.brands b on b.id=p.brand_id left join public.variant_prices pr on pr.variant_id=v.id left join public.inventory_balances ib on ib.variant_id=v.id),
 lines as(select e.id,e.kind,e.quantity,case when e.ok then e.name end name,case when e.ok then e.label end label,case when e.ok then e.sku end sku,case when e.ok then e.slug end slug,case when e.ok then e.brand end brand,case when e.ok then e.price_minor end price_minor,case when e.ok then e.available end available,coalesce(e.ok,false) eligible,
 coalesce(e.ok,false) and e.available>=e.quantity and not exists(select 1 from components c join short s using(variant_id) where c.line_key=e.id) valid,
 case when not coalesce(e.ok,false) then 'unavailable' when e.available<e.quantity or exists(select 1 from components c join short s using(variant_id) where c.line_key=e.id) then 'stock_changed' when e.expected is not null and e.expected<>e.price_minor::text then 'price_changed' when e.kind='deal' and e.revision is not null and e.revision<>e.deal_revision::text then 'deal_changed' else null end issue,
 case when e.kind='deal' and e.ok then e.deal_revision end "dealRevision",
 case when e.kind='deal' and e.ok then app_private.deal_public_view(e.uid)->'components' else null end components
 from eligible e)
 select jsonb_build_object('lines',jsonb_agg(l order by l.id),'valid',bool_and(l.valid),'subtotal_minor',coalesce(sum(l.price_minor::numeric*l.quantity),0)) into result from lines l;
 if (result->>'subtotal_minor')::numeric>9007199254740991 then raise exception 'Cart total too large';end if;return result;
end $$;
-- A global gate is deliberate for this small store; row locks remain sorted by UUID.
-- It serializes inventory/deal transitions and avoids pool/order lock inversion.
create function app_private.snapshot_deal_components(p_item uuid) returns void language plpgsql set search_path='' as $$ declare item public.order_items;begin
 select * into item from public.order_items where id=p_item;
 insert into public.order_item_components(order_item_id,variant_id,quantity)
 select item.id,v.id,case when item.deal_id is null then item.quantity else dc.quantity*item.quantity end from public.variants v left join public.deal_components dc on dc.variant_id=v.id and dc.deal_id=item.deal_id where (item.variant_id=v.id or dc.deal_id is not null);
 -- Largest-remainder apportionment is exact in paisa, deterministic by variant UUID.
 with weighted as(select c.*,v.original_sku,p.name,coalesce(v.label,'') label,pr.amount_minor,pr.amount_minor::numeric*c.quantity weight from public.order_item_components c join public.variants v on v.id=c.variant_id join public.products p on p.id=v.product_id join public.variant_prices pr on pr.variant_id=v.id where c.order_item_id=item.id),
 shares as(select w.*,item.line_total_minor::numeric*weight/sum(weight) over() exact from weighted w),
 floors as(select sh.*,floor(exact)::bigint base,row_number() over(order by exact-floor(exact) desc,variant_id) priority from shares sh),
 final as(select f.*,item.line_total_minor-sum(base) over() remainder from floors f)
 insert into app_private.order_component_snapshots select order_item_id,variant_id,quantity,original_sku,name,label,amount_minor,base+case when priority<=remainder then 1 else 0 end from final;
end $$;
alter function app_private.reserve_inventory(uuid,text,timestamptz) rename to reserve_inventory_016;
create function app_private.reserve_inventory(p_order uuid,p_key text,p_expires timestamptz) returns void language plpgsql security definer set search_path='' as $$ declare r record;taken integer;begin
 perform pg_advisory_xact_lock(73525);
 if not exists(select 1 from app_private.order_component_snapshots s join public.order_items i on i.id=s.order_item_id where i.order_id=p_order) then perform app_private.reserve_inventory_016(p_order,p_key,p_expires);return;end if;
 perform 1 from public.orders where id=p_order and status in('draft','placed') for update;if not found then raise exception 'Order is not reservable';end if;
 if exists(select 1 from public.inventory_reservations where order_id=p_order) then raise exception 'Order already reserved';end if;
 if p_expires<=now() or p_expires>now()+interval '7 days' then raise exception 'Invalid expiry';end if;
 perform 1 from public.inventory_balances b where b.variant_id in(select c.variant_id from public.order_item_components c join public.order_items i on i.id=c.order_item_id where i.order_id=p_order) order by b.variant_id for update;
 for r in select i.deal_id,c.variant_id,sum(c.quantity)::int qty,ds.generation from public.order_items i join public.order_item_components c on c.order_item_id=i.id join app_private.deal_settings ds on ds.deal_id=i.deal_id where i.order_id=p_order group by i.deal_id,c.variant_id,ds.generation order by c.variant_id,i.deal_id loop
 select least(quantity,r.qty) into taken from app_private.deal_pools where deal_id=r.deal_id and variant_id=r.variant_id and generation=r.generation for update;
 if coalesce(taken,0)>0 then
 update public.inventory_balances set reserved=reserved-taken where variant_id=r.variant_id;
 if taken=(select quantity from app_private.deal_pools where deal_id=r.deal_id and variant_id=r.variant_id) then delete from app_private.deal_pools where deal_id=r.deal_id and variant_id=r.variant_id;
 else update app_private.deal_pools set quantity=quantity-taken where deal_id=r.deal_id and variant_id=r.variant_id;end if;
 insert into app_private.order_pool_sources values(p_order,r.deal_id,r.variant_id,r.generation,taken,false);
 insert into app_private.deal_allocation_events(deal_id,variant_id,delta,reason,order_id,actor_id) values(r.deal_id,r.variant_id,-taken,'allocation transferred into order reservation',p_order,auth.uid());end if;
 end loop;
 for r in select c.variant_id,sum(c.quantity)::int qty from public.order_item_components c join public.order_items i on i.id=c.order_item_id where i.order_id=p_order group by c.variant_id order by c.variant_id loop
 update public.inventory_balances set reserved=reserved+r.qty where variant_id=r.variant_id and reconciled_at is not null and on_hand-reserved>=r.qty;
 if not found then raise exception 'Insufficient shared stock';end if;
 insert into public.inventory_reservations(order_id,variant_id,quantity,expires_at,idempotency_key) values(p_order,r.variant_id,r.qty,p_expires,p_key||':'||r.variant_id);end loop;
end $$;
alter function app_private.finish_inventory(uuid,boolean) rename to finish_inventory_016;
create function app_private.finish_inventory(p_order uuid,p_consume boolean) returns void language plpgsql security definer set search_path='' as $$ declare r record;begin
 perform pg_advisory_xact_lock(73525);perform app_private.finish_inventory_016(p_order,p_consume);
 if not p_consume then
 for r in select * from app_private.order_pool_sources where order_id=p_order and not returned order by variant_id,deal_id for update loop
 if app_private.deal_pool_open(r.deal_id) and exists(select 1 from app_private.deal_settings where deal_id=r.deal_id and generation=r.generation) then
 update public.inventory_balances set reserved=reserved+r.quantity where variant_id=r.variant_id;
 insert into app_private.deal_pools values(r.deal_id,r.variant_id,r.quantity,r.generation) on conflict(deal_id,variant_id) do update set quantity=app_private.deal_pools.quantity+excluded.quantity;
 insert into app_private.deal_allocation_events(deal_id,variant_id,delta,reason,order_id,actor_id) values(r.deal_id,r.variant_id,r.quantity,'cancelled/expired order returned transferred allocation',p_order,auth.uid());end if;
 update app_private.order_pool_sources set returned=true where order_id=p_order and deal_id=r.deal_id and variant_id=r.variant_id;
 end loop;end if;
end $$;

create or replace function app_private.assert_order_allocation(p_order uuid,p_state text,p_allow_expired boolean default false)
returns void language plpgsql set search_path='' as $allocation$
begin
 if p_state not in('active','consumed') or not exists(select 1 from public.order_items where order_id=p_order) then raise exception 'Order allocation is incomplete';end if;
 if exists(select 1 from app_private.order_component_snapshots s join public.order_items i on i.id=s.order_item_id where i.order_id=p_order) then
 if exists(with actual as(select c.* from public.order_item_components c join public.order_items i on i.id=c.order_item_id where i.order_id=p_order),expected as(select s.* from app_private.order_component_snapshots s join public.order_items i on i.id=s.order_item_id where i.order_id=p_order) select 1 from actual a full join expected e using(order_item_id,variant_id) where a.quantity is distinct from e.quantity)
 or exists(select 1 from public.order_items i where i.order_id=p_order and (not exists(select 1 from app_private.order_component_snapshots where order_item_id=i.id) or i.line_total_minor<>(select sum(attributed_minor) from app_private.order_component_snapshots where order_item_id=i.id))) then raise exception 'Immutable component snapshot mismatch';end if;
 else
 if exists(select 1 from public.order_items i left join public.order_item_components c on c.order_item_id=i.id and c.variant_id=i.variant_id where i.order_id=p_order and (i.variant_id is null or c.quantity is distinct from i.quantity))
 or exists(select 1 from public.order_item_components c join public.order_items i on i.id=c.order_item_id where i.order_id=p_order and c.variant_id is distinct from i.variant_id) then raise exception 'Order component allocation is incomplete';end if;
 end if;
 -- Same deterministic inventory-lock order as the shared reservation primitive.
 perform 1 from public.inventory_balances b where b.variant_id in(select c.variant_id from public.order_item_components c join public.order_items i on i.id=c.order_item_id where i.order_id=p_order) order by b.variant_id for update;
 perform 1 from public.inventory_reservations where order_id=p_order order by variant_id,id for update;
 if exists(
 with expected as(select c.variant_id,sum(c.quantity) qty from public.order_item_components c join public.order_items i on i.id=c.order_item_id where i.order_id=p_order group by c.variant_id),
 actual as(select variant_id,sum(quantity) qty,count(*) copies,bool_and(state=p_state) states_ok from public.inventory_reservations where order_id=p_order group by variant_id)
 select 1 from expected e full join actual r on r.variant_id=e.variant_id where e.variant_id is null or r.variant_id is null or e.qty<>r.qty or r.copies<>1 or not r.states_ok
 ) then raise exception 'Order reservation is missing, partial or inconsistent. Reconcile before proceeding';end if;
 if exists(select 1 from public.order_items i join public.order_item_components comp on comp.order_item_id=i.id left join public.inventory_balances b on b.variant_id=comp.variant_id where i.order_id=p_order and (b.variant_id is null or b.reconciled_at is null)) then raise exception 'Counted inventory is missing';end if;
 if exists(select 1 from public.inventory_balances b where b.variant_id in(select c.variant_id from public.order_item_components c join public.order_items i on i.id=c.order_item_id where i.order_id=p_order) and b.reserved<>(select coalesce(sum(r.quantity),0) from public.inventory_reservations r where r.variant_id=b.variant_id and r.state='active')+coalesce((select sum(quantity) from app_private.deal_pools where variant_id=b.variant_id),0)) then raise exception 'Reserved inventory does not match active allocations. Reconcile before proceeding';end if;
 if p_state='active' then
 if not p_allow_expired and exists(select 1 from public.inventory_reservations where order_id=p_order and expires_at<=now()) then raise exception 'Order hold expired';end if;
 if exists(select 1 from public.inventory_reservations r join app_private.commerce_orders c on c.order_id=r.order_id where r.order_id=p_order and ((c.allocation='accepted' and r.expires_at<>'infinity'::timestamptz) or (c.allocation='temporary' and r.expires_at is distinct from c.hold_expires_at))) then raise exception 'Order reservation lifecycle is inconsistent';end if;
 else
 if exists(select 1 from public.inventory_reservations r left join public.inventory_movements m on m.idempotency_key='reservation:'||r.id::text where r.order_id=p_order and (m.id is null or m.order_id is distinct from r.order_id or m.variant_id<>r.variant_id or m.delta<>-r.quantity)) then raise exception 'Dispatch consumption history is incomplete';end if;
 end if;
end $allocation$;


create or replace function app_private.reacquire_payment_stock(p_order uuid) returns boolean language plpgsql set search_path='' as $$ declare r record;src record;taken integer;begin
 perform 1 from public.inventory_balances where variant_id in(select c.variant_id from public.order_item_components c join public.order_items i on i.id=c.order_item_id where i.order_id=p_order) order by variant_id for update;
 if exists(with e as(select c.variant_id,sum(c.quantity) qty from public.order_item_components c join public.order_items i on i.id=c.order_item_id where i.order_id=p_order group by c.variant_id),a as(select variant_id,count(*) n,sum(quantity) qty,bool_and(state='released') ok from public.inventory_reservations where order_id=p_order group by variant_id) select 1 from e full join a using(variant_id) where e.variant_id is null or a.variant_id is null or a.n<>1 or a.qty<>e.qty or not a.ok) then raise exception 'Released allocation is incomplete';end if;
 for src in select os.* from app_private.order_pool_sources os join app_private.deal_settings ds on ds.deal_id=os.deal_id and ds.generation=os.generation where os.order_id=p_order and os.returned and app_private.deal_pool_open(os.deal_id) order by os.variant_id,os.deal_id loop
 select least(quantity,src.quantity) into taken from app_private.deal_pools where deal_id=src.deal_id and variant_id=src.variant_id and generation=src.generation for update;
 if coalesce(taken,0)>0 then
 update public.inventory_balances set reserved=reserved-taken where variant_id=src.variant_id;
 update app_private.deal_pools set quantity=quantity-taken where deal_id=src.deal_id and variant_id=src.variant_id and quantity>taken;
 if not found then delete from app_private.deal_pools where deal_id=src.deal_id and variant_id=src.variant_id;end if;
 update app_private.order_pool_sources set returned=false,quantity=taken where order_id=p_order and deal_id=src.deal_id and variant_id=src.variant_id;
 insert into app_private.deal_allocation_events(deal_id,variant_id,delta,reason,order_id,actor_id) values(src.deal_id,src.variant_id,-taken,'late order reclaimed its returned allocation',p_order,auth.uid());end if;end loop;
 for r in select * from public.inventory_reservations where order_id=p_order order by variant_id for update loop
 update public.inventory_balances set reserved=reserved+r.quantity where variant_id=r.variant_id and reconciled_at is not null and on_hand-reserved>=r.quantity;
 if not found then raise exception 'Stock unavailable' using errcode='P0409';end if;
 update public.inventory_reservations set state='active',expires_at='infinity' where id=r.id;
 end loop;return true;
 exception when sqlstate 'P0409' then return false;
 end $$;

create or replace function app_private.place_guest_order_015(p_id uuid,p_session text,p_token text,p_lines jsonb,p_customer jsonb,p_shipping jsonb,p_payment jsonb,p_config jsonb) returns jsonb
language plpgsql security definer set search_path='' set statement_timeout='15s' as $place$
declare prior app_private.commerce_orders;rh text;q jsonb;l jsonb;shipping bigint;total bigint;expiry timestamptz;allocation text;number text;item_id uuid;begin
 if p_id is null or p_session is null or p_session !~ '^[a-f0-9]{64}$' or p_token is null or p_token !~ '^[a-f0-9]{64}$' then raise exception 'Invalid ownership';end if;
 perform app_private.commerce_lines(p_lines);
 if p_customer is null or jsonb_typeof(p_customer)<>'object' or length(p_customer::text)>3000 or length(btrim(coalesce(p_customer->>'name',''))) not between 2 and 120 or coalesce(p_customer->>'phone','') !~ '^\+923[0-9]{9}$' or length(btrim(coalesce(p_customer->>'address',''))) not between 5 and 500 or length(btrim(coalesce(p_customer->>'city',''))) not between 2 and 100 or length(coalesce(p_customer->>'email',''))>254 or (coalesce(p_customer->>'email','')<>'' and p_customer->>'email' !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$') or length(coalesce(p_customer->>'note',''))>1000 then raise exception 'Check delivery details';end if;
 if p_shipping is null or p_payment is null or p_config is null or length((p_shipping||p_payment||p_config)::text)>5000 or p_config->>'mode' not in('development','approved') or p_config->>'version' is null or coalesce(p_shipping->>'feeMinor','') !~ '^[0-9]{1,12}$' or p_payment->>'allocation' not in('accepted','temporary') then raise exception 'Checkout settings incomplete';end if;
 shipping=(p_shipping->>'feeMinor')::bigint;
 rh=encode(pg_catalog.sha256(convert_to(jsonb_build_array(p_lines,p_customer,p_shipping,p_payment,p_config)::text,'UTF8')),'hex');
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,715));
 select * into prior from app_private.commerce_orders where order_id=p_id;
 if found then
 if prior.session_hash<>p_session or prior.token_hash<>p_token or prior.request_hash<>rh then raise exception 'Idempotency conflict';end if;
 return app_private.commerce_view(p_id);
 end if;
 perform 1 from public.deals where id in(select (x->>'id')::uuid from jsonb_array_elements(p_lines) x where x->>'kind'='deal') order by id for share;
 -- Stable locks also prevent visibility/price/physical-count changes during placement.
 perform 1 from public.products where id in(select v.product_id from public.variants v where v.id in(select variant_id from app_private.cart_components(p_lines))) order by id for share;
 perform 1 from public.variants where id in(select variant_id from app_private.cart_components(p_lines)) order by id for share;
 perform 1 from public.variant_prices where variant_id in(select variant_id from app_private.cart_components(p_lines)) order by variant_id for share;
 q=public.commerce_quote(p_lines);
 if not (q->>'valid')::boolean then raise exception 'Availability changed. Review your bag';end if;
 if exists(select 1 from jsonb_array_elements(q->'lines') x where x->>'issue' in('price_changed','deal_changed')) or exists(select 1 from jsonb_array_elements(p_lines) x where x->>'expectedPriceMinor' is null) then raise exception 'Prices changed. Review your bag';end if;
 if exists(select 1 from jsonb_array_elements(p_lines) x where x->>'kind'='deal' and x->>'expectedDealRevision' is null) then raise exception 'Review current deal contents before ordering';end if;
 total=(q->>'subtotal_minor')::bigint+shipping;
 if total>9007199254740991 then raise exception 'Order total too large';end if;
 insert into public.orders(id,delivery_name,contact_phone,contact_email,address) values(p_id,p_customer->>'name',p_customer->>'phone',nullif(p_customer->>'email',''),jsonb_build_object('country','PK','address',p_customer->>'address','city',p_customer->>'city'));
 for l in select value from jsonb_array_elements(q->'lines') loop
 insert into public.order_items(order_id,variant_id,deal_id,name_snapshot,sku_snapshot,quantity,unit_price_minor,line_total_minor)
 values(p_id,case when l->>'kind'='deal' then null else (l->>'id')::uuid end,case when l->>'kind'='deal' then substring(l->>'id' from 6)::uuid else null end,l->>'name'||case when coalesce(l->>'label','')<>'' then ' - '||(l->>'label') else '' end,l->>'sku',(l->>'quantity')::int,(l->>'price_minor')::bigint,(l->>'price_minor')::bigint*(l->>'quantity')::int) returning id into item_id;
 perform app_private.snapshot_deal_components(item_id);
 end loop;
 allocation=p_payment->>'allocation';expiry=now()+interval '20 minutes';
 perform app_private.reserve_inventory(p_id,p_id::text,expiry);
 if allocation='accepted' then update public.inventory_reservations set expires_at='infinity' where order_id=p_id;end if;
 number='NG-'||lpad(nextval('app_private.order_numbers')::text,8,'0');
 insert into app_private.commerce_orders(order_id,order_number,session_hash,token_hash,request_hash,fulfilment,payment_status,allocation,payment_snapshot,shipping_snapshot,configuration_snapshot,note,hold_expires_at)
 values(p_id,number,p_session,p_token,rh,'placed',case when allocation='accepted' then 'due_on_delivery' else 'awaiting_payment' end,allocation,p_payment,p_shipping,p_config,nullif(p_customer->>'note',''),case when allocation='temporary' then expiry else null end);
 update public.orders set status='placed',subtotal_minor=(q->>'subtotal_minor')::bigint,shipping_minor=shipping,total_minor=total,updated_at=now() where id=p_id;
 perform app_private.assert_order_allocation(p_id,'active');
 insert into app_private.order_events(order_id,operation_key,action,revision) values(p_id,p_id,'placed',1);
 return app_private.commerce_view(p_id);
end $place$;


alter function public.place_guest_order(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb) rename to place_guest_order_016;
alter function public.place_guest_order_016(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb) set schema app_private;
revoke all on function app_private.place_guest_order_016(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb) from public,anon,authenticated,service_role;
create function public.place_guest_order(p_id uuid,p_session text,p_token text,p_lines jsonb,p_customer jsonb,p_shipping jsonb,p_payment jsonb,p_config jsonb) returns jsonb language plpgsql security definer set search_path='' as $$ begin perform pg_advisory_xact_lock(73525);perform public.expire_deal_allocations(100);return app_private.place_guest_order_016(p_id,p_session,p_token,p_lines,p_customer,p_shipping,p_payment,p_config);end $$;
revoke all on function public.place_guest_order(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.place_guest_order(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb) to service_role;

alter function public.admin_order_action(uuid,integer,text,uuid) rename to admin_order_action_016;
alter function public.admin_order_action_016(uuid,integer,text,uuid) set schema app_private;
revoke all on function app_private.admin_order_action_016(uuid,integer,text,uuid) from public,anon,authenticated,service_role;
create function public.admin_order_action(p_id uuid,p_revision integer,p_action text,p_key uuid) returns jsonb language plpgsql security definer set search_path='' as $$ begin perform pg_advisory_xact_lock(73525);return app_private.admin_order_action_016(p_id,p_revision,p_action,p_key);end $$;
revoke all on function public.admin_order_action(uuid,integer,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.admin_order_action(uuid,integer,text,uuid) to authenticated;

alter function public.review_manual_payment(uuid,integer,text,uuid,jsonb) rename to review_manual_payment_016;
alter function public.review_manual_payment_016(uuid,integer,text,uuid,jsonb) set schema app_private;
revoke all on function app_private.review_manual_payment_016(uuid,integer,text,uuid,jsonb) from public,anon,authenticated,service_role;
create function public.review_manual_payment(p_order uuid,p_revision integer,p_action text,p_key uuid,p_data jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$ begin perform pg_advisory_xact_lock(73525);return app_private.review_manual_payment_016(p_order,p_revision,p_action,p_key,p_data);end $$;
revoke all on function public.review_manual_payment(uuid,integer,text,uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.review_manual_payment(uuid,integer,text,uuid,jsonb) to authenticated;

alter function public.expire_commerce_holds(integer) rename to expire_commerce_holds_016;
alter function public.expire_commerce_holds_016(integer) set schema app_private;
revoke all on function app_private.expire_commerce_holds_016(integer) from public,anon,authenticated,service_role;
create function public.expire_commerce_holds(p_limit integer default 100) returns integer language plpgsql security definer set search_path='' as $$ begin perform pg_advisory_xact_lock(73525);perform public.expire_deal_allocations(100);return app_private.expire_commerce_holds_016(p_limit);end $$;
revoke all on function public.expire_commerce_holds(integer) from public,anon,authenticated,service_role;
grant execute on function public.expire_commerce_holds(integer) to service_role;

alter function public.adjust_inventory(uuid,integer,text,text) rename to adjust_inventory_016;
alter function public.adjust_inventory_016(uuid,integer,text,text) set schema app_private;
revoke all on function app_private.adjust_inventory_016(uuid,integer,text,text) from public,anon,authenticated,service_role;
create function public.adjust_inventory(p_variant uuid,p_delta integer,p_reason text,p_key text) returns uuid language plpgsql security definer set search_path='' as $$ begin perform pg_advisory_xact_lock(73525);return app_private.adjust_inventory_016(p_variant,p_delta,p_reason,p_key);end $$;
revoke all on function public.adjust_inventory(uuid,integer,text,text) from public,anon,authenticated,service_role;
grant execute on function public.adjust_inventory(uuid,integer,text,text) to authenticated;

alter function public.save_daily_product(uuid,integer,jsonb,uuid,text) rename to save_daily_product_016;
alter function public.save_daily_product_016(uuid,integer,jsonb,uuid,text) set schema app_private;
revoke all on function app_private.save_daily_product_016(uuid,integer,jsonb,uuid,text) from public,anon,authenticated,service_role;
create function public.save_daily_product(p_product uuid,p_revision integer,p_data jsonb,p_key uuid,p_intent text default 'save') returns jsonb language plpgsql security definer set search_path='' as $$ begin perform pg_advisory_xact_lock(73525);return app_private.save_daily_product_016(p_product,p_revision,p_data,p_key,p_intent);end $$;
revoke all on function public.save_daily_product(uuid,integer,jsonb,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.save_daily_product(uuid,integer,jsonb,uuid,text) to authenticated;

alter function public.reserve_order(uuid,text,timestamptz) rename to reserve_order_016;
alter function public.reserve_order_016(uuid,text,timestamptz) set schema app_private;
revoke all on function app_private.reserve_order_016(uuid,text,timestamptz) from public,anon,authenticated,service_role;
create function public.reserve_order(p_order uuid,p_key text,p_expires timestamptz) returns void language plpgsql security definer set search_path='' as $$ begin perform pg_advisory_xact_lock(73525);perform app_private.reserve_order_016(p_order,p_key,p_expires);return;end $$;
revoke all on function public.reserve_order(uuid,text,timestamptz) from public,anon,authenticated,service_role;
grant execute on function public.reserve_order(uuid,text,timestamptz) to authenticated;

alter function public.finish_reservation(uuid,boolean) rename to finish_reservation_016;
alter function public.finish_reservation_016(uuid,boolean) set schema app_private;
revoke all on function app_private.finish_reservation_016(uuid,boolean) from public,anon,authenticated,service_role;
create function public.finish_reservation(p_order uuid,p_consume boolean) returns void language plpgsql security definer set search_path='' as $$ begin perform pg_advisory_xact_lock(73525);perform app_private.finish_reservation_016(p_order,p_consume);return;end $$;
revoke all on function public.finish_reservation(uuid,boolean) from public,anon,authenticated,service_role;
grant execute on function public.finish_reservation(uuid,boolean) to authenticated;

create or replace function public.commerce_reconciliation() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('balanceMismatches',(select count(*) from public.inventory_balances b where b.reserved<>(select coalesce(sum(quantity),0) from public.inventory_reservations where variant_id=b.variant_id and state='active')+coalesce((select sum(quantity) from app_private.deal_pools where variant_id=b.variant_id),0)),
 'overdueHolds',(select count(*) from app_private.commerce_orders where allocation='temporary' and fulfilment='placed' and hold_expires_at<=now()),'endedDealAllocations',(select count(distinct deal_id) from app_private.deal_pools where not app_private.deal_pool_open(deal_id)));
$$;
alter function app_private.commerce_view(uuid) rename to commerce_view_016;
create function app_private.commerce_view(p_order uuid) returns jsonb language sql stable set search_path='' as $$
 select app_private.commerce_view_016(p_order)||jsonb_build_object('items',(select jsonb_agg(jsonb_build_object('name',i.name_snapshot,'sku',i.sku_snapshot,'quantity',i.quantity,'unitPriceMinor',i.unit_price_minor,'totalMinor',i.line_total_minor,'kind',case when i.deal_id is null then 'variant' else 'deal' end,'components',coalesce((select jsonb_agg(jsonb_build_object('sku',s.sku,'name',s.product_name,'label',s.option_name,'quantity',s.quantity,'attributedMinor',s.attributed_minor) order by s.sku) from app_private.order_component_snapshots s where s.order_item_id=i.id),'[]')) order by i.id) from public.order_items i where i.order_id=p_order));
$$;

create function public.create_deal_upload(p_id uuid,p_deal uuid,p_environment text,p_cloud text,
 p_hash text,p_bytes bigint,p_alt text,p_replace uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare m public.media_assets; w public.media_workflows; path text; begin
 perform app_private.require_admin();
 if p_environment not in ('development','staging','production') or p_cloud !~ '^[a-zA-Z0-9_-]+$'
 or p_hash !~ '^[a-f0-9]{64}$' or p_bytes not between 1 and 10485760
 or length(btrim(p_alt)) not between 1 and 500 then raise exception 'Invalid upload intent'; end if;
 perform 1 from public.deals where id=p_deal for update;
 if not found then raise exception 'Deal missing'; end if;
 select * into m from public.media_assets where id=p_id for update;
 if found then
  select * into w from public.media_workflows where media_id=p_id;
  if w.media_id is null or w.deal_id is distinct from p_deal
   or m.content_sha256<>p_hash or m.byte_size<>p_bytes or m.alt<>p_alt or m.media_environment<>p_environment
   or m.cloudinary_cloud_name<>p_cloud or w.replace_association_id is distinct from p_replace then raise exception 'Idempotency identity mismatch'; end if;
  return jsonb_build_object('media_id',m.id,'lifecycle',m.lifecycle,'private_path',w.private_path);
 end if;
 if (select count(*) from public.media_workflows wf join public.media_assets a on a.id=wf.media_id where wf.deal_id=p_deal and a.lifecycle not in('deleted','retired'))>=100 then raise exception 'Keep at most 100 active deal images; remove unused uploads first';end if;
 if p_replace is not null and not exists(select 1 from public.deal_media where id=p_replace and deal_id=p_deal) then raise exception 'Replacement association mismatch'; end if;
 path='media/'||p_environment||'/'||p_id::text||'/original';
 insert into public.media_assets(id,provider,private_bucket,private_path,alt,media_environment,cloudinary_cloud_name,content_sha256,byte_size,lifecycle)
 values(p_id,'supabase_private','catalog-private',path,p_alt,p_environment,p_cloud,p_hash,p_bytes,'private_uploading');
 insert into public.media_workflows(media_id,deal_id,private_path,expected_public_id,replace_association_id,replace_media_id)
 values(p_id,p_deal,path,'nook-glow/'||p_environment||'/'||p_id::text,p_replace,(select media_id from public.deal_media where id=p_replace));
 return jsonb_build_object('media_id',p_id,'lifecycle','private_uploading','private_path',path);
end $$;


create function app_private.deal_media_workflow_action(p_id uuid,p_action text,p_result jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare m public.media_assets; w public.media_workflows; a public.deal_media; pos integer; old_media uuid; begin
 perform app_private.require_admin();
 -- Global ordering: product, media, workflow. Reference guards also lock media.
 select * into w from public.media_workflows where media_id=p_id;
 if not found then raise exception 'Media workflow missing'; end if;
 perform 1 from public.deals where id=w.deal_id for update;
 select * into m from public.media_assets where id=p_id for update;
 select * into w from public.media_workflows where media_id=p_id for update;
 if p_action='private_uploaded' then
  if m.lifecycle='private_pending' then null;
  elsif m.lifecycle in ('private_uploading','failed') and w.reviewed_at is null then
   update public.media_assets set lifecycle='private_pending' where id=p_id;
  else raise exception 'Invalid private upload transition'; end if;
 elsif p_action='approve' then
  if m.lifecycle='approved_for_publish' then null;
  elsif m.lifecycle='private_pending' then
   update public.media_assets set lifecycle='approved_for_publish' where id=p_id;
   update public.media_workflows set reviewed_by=auth.uid(),reviewed_at=now() where media_id=p_id;
  else raise exception 'Private media review required'; end if;
 elsif p_action='begin_publish' then
  if m.lifecycle='linked' then null;
  elsif m.lifecycle in ('approved_for_publish','uploading','failed') and w.reviewed_at is not null then
   update public.media_assets set lifecycle='uploading' where id=p_id;
  else raise exception 'Explicit publication approval required'; end if;
 elsif p_action='complete' then
  if m.lifecycle='linked' then
   if m.cloudinary_asset_id is distinct from p_result->>'asset_id' or m.cloudinary_version is distinct from (p_result->>'version')::bigint then raise exception 'Duplicate completion mismatch'; end if;
  elsif m.lifecycle='uploading' and w.reviewed_at is not null then
   if p_result->>'public_id' is distinct from w.expected_public_id or p_result->>'resource_type' is distinct from 'image'
    or p_result->>'type' is distinct from 'upload' or coalesce(p_result->>'asset_id','')=''
    or coalesce(p_result->>'format','') not in ('jpg','png','webp') or coalesce((p_result->>'version')::bigint,0)<1
    or coalesce((p_result->>'width')::integer,0) not between 1 and 12000
    or coalesce((p_result->>'height')::integer,0) not between 1 and 12000
    or (p_result->>'width')::bigint*(p_result->>'height')::bigint>40000000
    or (p_result->>'bytes')::bigint is distinct from m.byte_size
    or p_result->>'sha256' is distinct from m.content_sha256 then raise exception 'Verified provider metadata required'; end if;
   update public.media_assets set provider='cloudinary',private_bucket=null,private_path=null,
    cloudinary_public_id=w.expected_public_id,cloudinary_asset_id=p_result->>'asset_id',cloudinary_version=(p_result->>'version')::bigint,
    cloudinary_resource_type='image',cloudinary_format=p_result->>'format',width=(p_result->>'width')::integer,height=(p_result->>'height')::integer,
    status='approved',lifecycle='linked' where id=p_id;
   if w.replace_association_id is not null then
    select * into a from public.deal_media where id=w.replace_association_id and deal_id=w.deal_id for update;
    if not found then raise exception 'Replacement target no longer exists'; end if;
    if a.media_id is distinct from w.replace_media_id then raise exception 'Replacement target changed; review new intent'; end if;
    old_media=a.media_id;
    update public.deal_media set media_id=p_id where id=a.id;
    update public.media_assets set lifecycle='retired' where id=old_media and lifecycle='linked';
   else
    select coalesce(max(position),-1)+1 into pos from public.deal_media where deal_id=w.deal_id;
    insert into public.deal_media(deal_id,media_id,position,is_primary)
     values(w.deal_id,p_id,pos,not exists(select 1 from public.deal_media where deal_id=w.deal_id and is_primary)) returning * into a;
   end if;
   update public.media_workflows set association_id=a.id,error_code=null where media_id=p_id;
  else raise exception 'Invalid completion state'; end if;
 elsif p_action='failed' then
  if m.lifecycle in ('private_uploading','uploading','failed') then
   update public.media_assets set lifecycle='failed' where id=p_id;
   update public.media_workflows set error_code='provider_or_validation_failed' where media_id=p_id;
  end if;
 elsif p_action='detach' then
  if exists(select 1 from public.deals where id=w.deal_id and status='published') and (select count(*) from public.deal_media where deal_id=w.deal_id)<=1 then raise exception 'Hide the deal before removing its last image';end if;
  if m.lifecycle not in ('linked','retired') then raise exception 'Cannot detach this state'; end if;
  delete from public.deal_media where media_id=p_id and deal_id=w.deal_id;
  if not exists(select 1 from public.deal_media where deal_id=w.deal_id and is_primary) then
   update public.deal_media set is_primary=true where id=(select id from public.deal_media where deal_id=w.deal_id order by position,id limit 1);
  end if;
  update public.media_assets set lifecycle='retired' where id=p_id;
 elsif p_action='claim_cleanup' then
  if exists(select 1 from public.deal_media where media_id=p_id) or exists(select 1 from public.article_media where media_id=p_id)
   or exists(select 1 from public.homepage_selections where media_id=p_id) then raise exception 'Referenced media cannot be deleted'; end if;
  if exists(select 1 from public.media_assets where id<>p_id and
    ((cloudinary_public_id=w.expected_public_id and (cloudinary_cloud_name=m.cloudinary_cloud_name or cloudinary_cloud_name is null))
     or private_path=w.private_path)) then raise exception 'Provider identity has another database owner'; end if;
  if m.lifecycle in ('uploading','failed','private_uploading') and w.updated_at>now()-interval '24 hours' then raise exception 'Wait for uncertain uploads to settle'; end if;
  if m.lifecycle<>'deleted' then update public.media_assets set lifecycle='deleting',status='rejected' where id=p_id; end if;
 elsif p_action='deleted' then
  if m.lifecycle not in ('deleting','deleted') then raise exception 'Cleanup claim required'; end if;
  update public.media_assets set lifecycle='deleted',status='rejected' where id=p_id;
 else raise exception 'Unknown media action'; end if;
 update public.media_workflows set updated_at=now() where media_id=p_id;
 return (select to_jsonb(ma)||jsonb_build_object('workflow',to_jsonb(mw)) from public.media_assets ma join public.media_workflows mw on mw.media_id=ma.id where ma.id=p_id);
end $$;


alter function public.media_workflow_action(uuid,text,jsonb) rename to media_workflow_action_016;
alter function public.media_workflow_action_016(uuid,text,jsonb) set schema app_private;
create function public.media_workflow_action(p_id uuid,p_action text,p_result jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$ begin
 perform app_private.require_admin();perform pg_advisory_xact_lock(73525);
 if p_action='claim_cleanup' and exists(select 1 from public.deal_media where media_id=p_id) then raise exception 'Referenced deal media cannot be deleted';end if;
 if exists(select 1 from public.media_workflows where media_id=p_id and deal_id is not null) then return app_private.deal_media_workflow_action(p_id,p_action,p_result);end if;
 return app_private.media_workflow_action_016(p_id,p_action,p_result);end $$;
create function public.arrange_deal_media(p_deal uuid,p_ids uuid[],p_primary uuid,p_alts jsonb default '{}') returns void language plpgsql security definer set search_path='' as $$ declare n integer;base integer;r record;begin
 perform app_private.require_admin();perform pg_advisory_xact_lock(73525);perform 1 from public.deals where id=p_deal for update;
 select count(*),coalesce(max(position),0)+1 into n,base from public.deal_media where deal_id=p_deal;
 if p_ids is null or cardinality(p_ids)<>n or n>100 or (select count(distinct x) from unnest(p_ids) x)<>n or exists(select 1 from unnest(p_ids) x where not exists(select 1 from public.deal_media where id=x and deal_id=p_deal)) or p_primary is null or not p_primary=any(p_ids) then raise exception 'Exact current image list required';end if;
 update public.deal_media dm set position=base+u.ord::int from unnest(p_ids) with ordinality u(id,ord) where dm.id=u.id;
 update public.deal_media dm set position=u.ord::int-1,is_primary=false from unnest(p_ids) with ordinality u(id,ord) where dm.id=u.id;
 update public.deal_media set is_primary=true where id=p_primary;
 if p_alts is null or jsonb_typeof(p_alts)<>'object' or length(p_alts::text)>60000 then raise exception 'Invalid image text';end if;
 for r in select key,value from jsonb_each_text(p_alts) loop
 if length(btrim(r.value)) not between 1 and 500 or not exists(select 1 from public.deal_media where deal_id=p_deal and media_id=r.key::uuid) then raise exception 'Check image descriptions';end if;
 update public.media_assets set alt=btrim(r.value) where id=r.key::uuid;end loop;
end $$;

revoke all on function app_private.media_is_public_016(uuid),app_private.commerce_view_016(uuid),app_private.reserve_inventory_016(uuid,text,timestamptz),app_private.finish_inventory_016(uuid,boolean),app_private.media_workflow_action_016(uuid,text,jsonb),app_private.deal_history_immutable(),app_private.deal_pool_open(uuid),app_private.release_deal_pool(uuid,text),app_private.deal_public_view(uuid),app_private.cart_components(jsonb),app_private.snapshot_deal_components(uuid),app_private.deal_media_workflow_action(uuid,text,jsonb),app_private.commerce_view(uuid),app_private.reserve_inventory(uuid,text,timestamptz),app_private.finish_inventory(uuid,boolean) from public,anon,authenticated,service_role;
revoke all on function public.admin_deals(uuid,text,integer),public.save_deal(uuid,integer,uuid,text,jsonb),public.storefront_deals(text,uuid[],integer,boolean),public.create_deal_upload(uuid,uuid,text,text,text,bigint,text,uuid),public.arrange_deal_media(uuid,uuid[],uuid,jsonb),public.media_workflow_action(uuid,text,jsonb),public.expire_deal_allocations(integer),public.media_is_public(uuid) from public,anon,authenticated,service_role;
grant execute on function public.admin_deals(uuid,text,integer),public.save_deal(uuid,integer,uuid,text,jsonb),public.create_deal_upload(uuid,uuid,text,text,text,bigint,text,uuid),public.arrange_deal_media(uuid,uuid[],uuid,jsonb),public.media_workflow_action(uuid,text,jsonb) to authenticated;
grant execute on function public.storefront_deals(text,uuid[],integer,boolean),public.media_is_public(uuid) to anon,authenticated,service_role;
grant execute on function public.expire_deal_allocations(integer) to service_role;
-- Pin policy to the new public dispatcher (renaming a function retains old policy OIDs).
drop policy public_read on public.media_assets;
create policy public_read on public.media_assets for select to anon,authenticated using(public.media_is_public(id));

create or replace function public.save_homepage_content(p_section text,p_items jsonb) returns void
language plpgsql security definer set search_path='' as $homepage$
declare item jsonb; position integer=0; offset_position integer; chosen uuid; entity uuid; previous uuid; begin
 perform app_private.require_admin();
 if p_section not in('products','the-edit') or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)>12 then raise exception 'Choose up to 12 manual selections'; end if;
 perform pg_advisory_xact_lock(73525);
 if (select count(distinct value->>'entity') from jsonb_array_elements(p_items))<>jsonb_array_length(p_items) then raise exception 'Choose each item once'; end if;
 select coalesce(max(h.position),-1)+100 into offset_position from public.homepage_selections h where h.section=p_section;
 if offset_position>2147480000 then raise exception 'Selection order needs maintenance'; end if;
 update public.homepage_selections set position=homepage_selections.position+offset_position,retired_at=now(),status='archived' where section=p_section and retired_at is null;
 for item in select value from jsonb_array_elements(p_items) loop
 entity=(item->>'entity')::uuid;chosen=(item->>'id')::uuid;
 if p_section='products' and ((coalesce(item->>'kind','product')='deal' and not public.deal_is_public(entity)) or (coalesce(item->>'kind','product')='product' and not public.product_is_public(entity)) or coalesce(item->>'kind','product') not in('product','deal')) then raise exception 'Choose an eligible published product'; end if;
 if p_section='the-edit' and not exists(select 1 from public.articles where id=entity and status='published' and published_at<=now() and deleted_at is null) then raise exception 'Choose a published article'; end if;
 if p_section='the-edit' and coalesce(item->>'theme','sage') not in('sage','warm','blush') then raise exception 'Choose Sage, Warm or Blush'; end if;
 select id into previous from public.homepage_selections where id=chosen and section=p_section and ((coalesce(item->>'kind','product')='deal' and deal_id=entity) or (coalesce(item->>'kind','product')='product' and product_id=entity) or article_id=entity);
 if not found and exists(select 1 from public.homepage_selections where id=chosen) then raise exception 'Selection identity changed'; end if;
 insert into public.homepage_selections(id,section,position,status,product_id,article_id,slide_theme,deal_id)
 values(chosen,p_section,position,'published',case when p_section='products' and coalesce(item->>'kind','product')='product' then entity end,case when p_section='the-edit' then entity end,case when p_section='the-edit' then coalesce(item->>'theme','sage') end,case when p_section='products' and item->>'kind'='deal' then entity end)
 on conflict(id) do update set position=excluded.position,status='published',retired_at=null,slide_theme=excluded.slide_theme;
 position=position+1;end loop;
END; $homepage$;

alter function public.admin_content_choices(text,text) rename to admin_content_choices_016;
alter function public.admin_content_choices_016(text,text) set schema app_private;
create function public.admin_content_choices(p_kind text,p_query text default '') returns jsonb language plpgsql stable security definer set search_path='' as $$ begin
 perform app_private.require_admin();if p_kind<>'homepage-products' then return app_private.admin_content_choices_016(p_kind,p_query);end if;
 return coalesce(app_private.admin_content_choices_016('products',p_query),'[]')||coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'kind','deal','name','Deal — '||d.name)) from(select id,name from public.deals where public.deal_is_public(id) and position(lower(left(p_query,100)) in lower(name))>0 order by name,id limit 24) d),'[]');
end $$;
revoke all on function app_private.admin_content_choices_016(text,text) from public,anon,authenticated,service_role;
revoke all on function public.admin_content_choices(text,text) from public,anon,authenticated,service_role;
grant execute on function public.admin_content_choices(text,text) to authenticated;

-- Admin order search uses frozen component names/SKUs, never current deal composition.
create or replace function public.admin_payment_orders(p_query text default '',p_status text default '',p_from date default null,p_to date default null,p_offset integer default 0,p_id uuid default null,p_queue text default '') returns jsonb language plpgsql stable security definer set search_path='' as $orders$
begin
 perform app_private.require_admin();if p_queue not in('','Awaiting payment','Proof submitted','Needs attention','Paid') or length(p_query)>120 or p_offset not between 0 and 100000 or p_status not in('','placed','confirmed','dispatched','completed','cancelled','expired') or (p_from is not null and p_to is not null and p_from>p_to) then raise exception 'Invalid order filters';end if;
 if p_id is not null then return app_private.commerce_view(p_id);end if;
 return(with matched as(select c.order_id from app_private.commerce_orders c join public.orders o on o.id=c.order_id where
 (p_queue='' or app_private.commerce_view(c.order_id)#>>'{manualPayment,queue}'=p_queue) and (p_status='' or c.fulfilment=p_status) and (p_from is null or o.created_at>=p_from::timestamp at time zone 'Asia/Karachi') and (p_to is null or o.created_at<(p_to+1)::timestamp at time zone 'Asia/Karachi') and
 (btrim(p_query)='' or position(lower(btrim(p_query)) in lower(c.order_number||' '||o.delivery_name||' '||o.contact_phone))>0 or exists(select 1 from public.order_items i where i.order_id=o.id and position(lower(btrim(p_query)) in lower(i.name_snapshot||' '||coalesce(i.sku_snapshot,'')))>0) or exists(select 1 from app_private.order_component_snapshots sn join public.order_items oi on oi.id=sn.order_item_id where oi.order_id=o.id and position(lower(btrim(p_query)) in lower(sn.sku||' '||sn.product_name||' '||sn.option_name))>0)))
 select jsonb_build_object('total',(select count(*) from matched),'offset',p_offset,'rows',coalesce((select jsonb_agg(app_private.commerce_view(order_id)) from(select m.order_id from matched m join app_private.commerce_orders c on c.order_id=m.order_id order by c.created_at desc,c.order_id limit 25 offset p_offset) page),'[]')));
end $orders$;



insert into app_private.sql_editor_receipts(version,filename,sha256) values('202610160017','202610160017_assembled_deals.sql','dfdae129e62884b12d58e0bb43f628a7b9dece652dc413c789af3a381db8c7e7');notify pgrst,'reload schema';commit;
-- READ ONLY: no customer, catalog or account details.
select exists(select 1 from app_private.sql_editor_receipts where version='202610150016' and sha256='d0e29a69895ac34b808371c40c126235f7b7d019ee77874b218b3a65cbfdb612') prerequisite_016,
 to_regclass('app_private.deal_settings') is not null deals_present,
 to_regclass('app_private.deal_pools') is not null pools_present,
 to_regclass('app_private.order_component_snapshots') is not null snapshots_present,
 to_regclass('public.deal_media') is not null media_present,
 to_regprocedure('public.save_deal(uuid,integer,uuid,text,jsonb)') is not null save_present,
 to_regprocedure('public.storefront_deals(text,uuid[],integer,boolean)') is not null public_projection_present,
 to_regprocedure('public.expire_deal_allocations(integer)') is not null expiry_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610160017') receipt_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610160017' and sha256='dfdae129e62884b12d58e0bb43f628a7b9dece652dc413c789af3a381db8c7e7') receipt_matches,
 (select count(*)=6 and bool_and(relrowsecurity) from pg_class where oid in(to_regclass('app_private.deal_settings'),to_regclass('app_private.deal_pools'),to_regclass('app_private.deal_operations'),to_regclass('app_private.deal_allocation_events'),to_regclass('app_private.order_component_snapshots'),to_regclass('app_private.order_pool_sources'))) private_rls,
 not exists(select 1 from pg_policies where schemaname='app_private' and tablename in('deal_settings','deal_pools','deal_operations','deal_allocation_events','order_component_snapshots','order_pool_sources')) no_client_policies,
 coalesce((select prosecdef and position('require_admin()' in prosrc)>0 from pg_proc where oid=to_regprocedure('public.save_deal(uuid,integer,uuid,text,jsonb)')),false) admin_authorization,
 coalesce((select position('73525' in prosrc)>0 from pg_proc where oid=to_regprocedure('public.place_guest_order(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb)')),false) inventory_gate,
 coalesce((select position('deal_pools' in prosrc)>0 from pg_proc where oid=to_regprocedure('app_private.assert_order_allocation(uuid,text,boolean)')),false) shared_assertion;
