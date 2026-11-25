-- 024: Category-specific owner-managed discovery; no automatic claims/product publication.
-- Existing assignment/evidence tables, private services and search projections are reused.
insert into public.facet_definitions(id,name,kind) values('occasion','Occasion','enum') on conflict do nothing;
insert into public.facet_scopes values('occasion','makeup') on conflict do nothing;
insert into public.facet_scopes values('occasion','personal-fragrance') on conflict do nothing;
insert into public.facet_scopes values('occasion','home-fragrance') on conflict do nothing;
insert into public.facet_scopes values('occasion','cutlery') on conflict do nothing;
insert into public.facet_scopes values('occasion','bath-body') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('occasion:everyday','occasion','Everyday') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('occasion:work','occasion','Work') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('occasion:evening','occasion','Evening') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('occasion:wedding','occasion','Wedding') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('occasion:gifting','occasion','Gifting') on conflict do nothing;
insert into public.facet_definitions(id,name,kind) values('makeup-finish','Makeup finish','enum') on conflict do nothing;
insert into public.facet_scopes values('makeup-finish','makeup') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('makeup-finish:matte','makeup-finish','Matte') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('makeup-finish:dewy','makeup-finish','Dewy') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('makeup-finish:natural','makeup-finish','Natural') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('makeup-finish:satin','makeup-finish','Satin') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('makeup-finish:shimmer','makeup-finish','Shimmer') on conflict do nothing;
insert into public.facet_definitions(id,name,kind) values('coverage','Coverage','enum') on conflict do nothing;
insert into public.facet_scopes values('coverage','makeup') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('coverage:sheer','coverage','Sheer') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('coverage:light','coverage','Light') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('coverage:medium','coverage','Medium') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('coverage:full','coverage','Full') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('coverage:buildable','coverage','Buildable') on conflict do nothing;
insert into public.facet_definitions(id,name,kind) values('hair-type','Hair type','enum') on conflict do nothing;
insert into public.facet_scopes values('hair-type','hair-care') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('hair-type:straight','hair-type','Straight') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('hair-type:wavy','hair-type','Wavy') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('hair-type:curly','hair-type','Curly') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('hair-type:coily','hair-type','Coily') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('hair-type:fine','hair-type','Fine') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('hair-type:thick','hair-type','Thick') on conflict do nothing;
insert into public.facet_definitions(id,name,kind) values('hair-format','Hair product format','enum') on conflict do nothing;
insert into public.facet_scopes values('hair-format','hair-care') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('hair-format:shampoo','hair-format','Shampoo') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('hair-format:dry-shampoo','hair-format','Dry shampoo') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('hair-format:conditioner','hair-format','Conditioner') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('hair-format:mask','hair-format','Mask') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('hair-format:serum','hair-format','Serum') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('hair-format:oil','hair-format','Oil') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('hair-format:styling','hair-format','Styling') on conflict do nothing;
insert into public.facet_definitions(id,name,kind) values('season','Season','enum') on conflict do nothing;
insert into public.facet_scopes values('season','personal-fragrance') on conflict do nothing;
insert into public.facet_scopes values('season','home-fragrance') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('season:spring','season','Spring') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('season:summer','season','Summer') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('season:autumn','season','Autumn') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('season:winter','season','Winter') on conflict do nothing;
insert into public.facet_definitions(id,name,kind) values('care-feature','Care instructions','enum') on conflict do nothing;
insert into public.facet_scopes values('care-feature','cutlery') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('care-feature:hand-wash-only','care-feature','Hand wash only') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('care-feature:dishwasher-safe','care-feature','Dishwasher safe') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('fragrance-family:floral','fragrance-family','Floral') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('fragrance-family:woody','fragrance-family','Woody') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('fragrance-family:fresh','fragrance-family','Fresh') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('fragrance-family:citrus','fragrance-family','Citrus') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('fragrance-family:amber','fragrance-family','Amber') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('fragrance-family:gourmand','fragrance-family','Gourmand') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('fragrance-family:aquatic','fragrance-family','Aquatic') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('fragrance-family:chypre','fragrance-family','Chypre') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('fragrance-family:fougère','fragrance-family','Fougère') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('fragrance-note:rose','fragrance-note','Rose') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('fragrance-note:jasmine','fragrance-note','Jasmine') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('fragrance-note:vanilla','fragrance-note','Vanilla') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('fragrance-note:musk','fragrance-note','Musk') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('fragrance-note:bergamot','fragrance-note','Bergamot') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('fragrance-note:sandalwood','fragrance-note','Sandalwood') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('fragrance-note:oud','fragrance-note','Oud') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('fragrance-note:patchouli','fragrance-note','Patchouli') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('material:stainless-steel','material','Stainless steel') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('material:silicone','material','Silicone') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('material:wood','material','Wood') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('material:bamboo','material','Bamboo') on conflict do nothing;
insert into public.facet_values(id,facet_id,label) values('material:synthetic-fibres','material','Synthetic fibres') on conflict do nothing;

insert into public.facet_definitions(id,name,kind) values('ingredient','Named ingredients','reference') on conflict do nothing;
insert into public.facet_scopes values('ingredient','skincare') on conflict do nothing;
insert into public.facet_scopes values('ingredient','bath-body') on conflict do nothing;
insert into public.facet_scopes values('ingredient','hair-care') on conflict do nothing;
insert into public.facet_definitions(id,name,kind) values('hair-concern','Hair / scalp concern','enum') on conflict do nothing;
insert into public.facet_scopes values('hair-concern','hair-care') on conflict do nothing;
insert into public.facet_values values('hair-concern:dry-hair','hair-concern','Dry hair') on conflict do nothing;
insert into public.facet_values values('hair-concern:frizz','hair-concern','Frizz') on conflict do nothing;
insert into public.facet_values values('hair-concern:damage','hair-concern','Damage') on conflict do nothing;
insert into public.facet_values values('hair-concern:oily-scalp','hair-concern','Oily scalp') on conflict do nothing;
insert into public.facet_values values('hair-concern:scalp-dryness','hair-concern','Scalp dryness') on conflict do nothing;
insert into public.facet_definitions(id,name,kind) values('body-concern','Body care focus','enum') on conflict do nothing;
insert into public.facet_scopes values('body-concern','bath-body') on conflict do nothing;
insert into public.facet_values values('body-concern:dryness','body-concern','Dryness') on conflict do nothing;
insert into public.facet_values values('body-concern:rough-texture','body-concern','Rough texture') on conflict do nothing;
insert into public.facet_values values('body-concern:exfoliation','body-concern','Exfoliation') on conflict do nothing;
insert into public.facet_values values('body-concern:hand-care','body-concern','Hand care') on conflict do nothing;
insert into public.facet_values values('body-concern:nail-care','body-concern','Nail care') on conflict do nothing;
insert into public.facet_scopes values('skin-type','makeup') on conflict do nothing;

create function app_private.discovery_scope(p_product uuid) returns public.catalog_scope language sql stable security definer set search_path='' as $scope$
 with recursive tree as(select c.id,c.parent_id,c.scope,0 depth from public.categories c join public.products p on p.category_id=c.id where p.id=p_product
 union all select c.id,c.parent_id,c.scope,t.depth+1 from public.categories c join tree t on c.id=t.parent_id where t.depth<20)
 select scope from tree where scope is not null order by depth limit 1;
$scope$;
create function app_private.save_product_discovery(p_product uuid,p_data jsonb) returns void language plpgsql security definer set search_path='' as $discovery$
declare s public.catalog_scope; x jsonb; d public.facet_definitions; eid uuid; fid uuid; vid uuid; option text; label text; actor uuid; source text; source_url text; value_text text;
begin
 perform app_private.require_admin(); actor=auth.uid();
 if p_data is null or jsonb_typeof(p_data)<>'object' then raise exception 'Invalid discovery selections';end if;
 if jsonb_typeof(coalesce(p_data->'facets','[]'))<>'array' or jsonb_typeof(coalesce(p_data->'concerns','[]'))<>'array'
 or jsonb_typeof(coalesce(p_data->'removeFacets','[]'))<>'array' or jsonb_typeof(coalesce(p_data->'removeConcerns','[]'))<>'array' then raise exception 'Invalid discovery selections';end if;
 if jsonb_array_length(coalesce(p_data->'facets','[]'))>60 or jsonb_array_length(coalesce(p_data->'concerns','[]'))>8 or jsonb_array_length(coalesce(p_data->'removeFacets','[]'))>100 or jsonb_array_length(coalesce(p_data->'removeConcerns','[]'))>8 then raise exception 'Too many discovery selections';end if;
 s=app_private.discovery_scope(p_product);
 if jsonb_array_length(coalesce(p_data->'facets','[]'))+jsonb_array_length(coalesce(p_data->'concerns','[]'))>0 then
 if s is null then raise exception 'Choose a category before adding discovery filters';end if;
 if coalesce((p_data->>'confirmed')::boolean,false) is not true then raise exception 'Confirm the selections match the product label or official information';end if;
 source=p_data->>'sourceType'; source_url=nullif(btrim(p_data->>'sourceUrl'),'');
 if source not in('package','official_page') or source is null then raise exception 'Choose label or official information';end if;
 if source='official_page' and (source_url is null or source_url !~ '^https://[^/ ]+' or length(source_url)>2000) then raise exception 'Add the official HTTPS product link';end if;
 end if;
 -- Explicit removals only: untouched assignments/history are preserved.
 for x in select value from jsonb_array_elements(coalesce(p_data->'removeFacets','[]')) loop
 if not exists(select 1 from public.product_facets where id=(x#>>'{}')::uuid and product_id=p_product) then raise exception 'Filter changed; reload the product';end if;
 delete from public.product_facets where id=(x#>>'{}')::uuid and product_id=p_product;
 end loop;
 for x in select value from jsonb_array_elements(coalesce(p_data->'removeConcerns','[]')) loop
 delete from public.product_concerns where product_id=p_product and concern_id=x#>>'{}';
 end loop;
 for x in select value from jsonb_array_elements(coalesce(p_data->'facets','[]')) loop
 select * into d from public.facet_definitions where id=x->>'facetId';
 if not found or not exists(select 1 from public.facet_scopes where facet_id=d.id and scope=s) then raise exception 'This filter does not belong to this category';end if;
 vid=nullif(x->>'variantId','')::uuid;
 if vid is not null and not exists(select 1 from public.variants where id=vid and product_id=p_product and status<>'archived') then raise exception 'Choose an active shade or size for this product';end if;
 if d.id in('fragrance-family','fragrance-note','concentration') and not coalesce((p_data->>'setSingleProfileConfirmed')::boolean,false) and exists(select 1 from public.variants where product_id=p_product and (vid is null or id=vid) and status<>'archived' and sellable_kind in('factory_set','unconfirmed_set')) then raise exception 'Keep mixed fragrance set profiles unassigned; use individual fragrance products';end if;
 option=null;value_text=nullif(btrim(x->>'value'),'');label=nullif(btrim(x->>'newValue'),'');
 if d.kind in('enum','reference') then
 if label is not null then
 if d.kind<>'reference' or length(label)>80 then raise exception 'Choose an existing option';end if;
 option=d.id||':'||left(regexp_replace(lower(label),'[^a-z0-9]+','-','g'),60)||'-'||left(md5(lower(label)),8);
 insert into public.facet_values(id,facet_id,label) values(option,d.id,label) on conflict do nothing;
 else select id into option from public.facet_values where id=value_text and facet_id=d.id;end if;
 if option is null then raise exception 'Choose a value for this filter';end if;
 else
 if d.kind='boolean' and value_text not in('true','false') or value_text is null then raise exception 'Enter a filter value';end if;
 if d.kind='integer' and value_text !~ '^[0-9]{1,7}$' then raise exception 'Enter a whole positive number';end if;
 if d.kind in('quantity','decimal') and value_text !~ '^[0-9]{1,7}(\.[0-9]{1,4})?$' then raise exception 'Enter a positive number';end if;
 if d.kind in('quantity','decimal','integer') and value_text::numeric<=0 then raise exception 'Filter values must be greater than zero';end if;
 end if;
 update public.facet_definitions set active=true where id=d.id and not active;
 -- Exact duplicate retries/selections do not create repeated rows.
 if exists(select 1 from public.product_facets f where f.product_id=p_product and f.variant_id is not distinct from vid and f.facet_id=d.id and case when d.kind in('enum','reference') then f.option_id=option when d.kind='integer' then f.integer_value=value_text::integer when d.kind in('decimal','quantity') then f.decimal_value=value_text::numeric when d.kind='boolean' then f.boolean_value=value_text::boolean else false end and coalesce(f.unit,'')=case when d.kind='quantity' then coalesce(x->>'unit','') else '' end and f.status='approved' and exists(select 1 from public.evidence e where e.id=f.evidence_id and e.status='approved')) then continue;end if;
 insert into public.evidence(source_type,url,finding,status,reviewed_by,reviewed_at,accessed_on) values(source,source_url,'Owner checked product filter'||case when coalesce((p_data->>'setSingleProfileConfirmed')::boolean,false) then ' (owner confirms all set items share this fragrance profile)' else '' end||': '||d.name||' = '||coalesce(label,option,value_text),'approved',actor,now(),current_date) returning id into eid;
 update public.facet_definitions set active=true where id=d.id and not active;
 insert into public.product_facets(product_id,variant_id,facet_id,kind,option_id,integer_value,decimal_value,boolean_value,unit,evidence_id,status)
 values(p_product,vid,d.id,d.kind,option,case when d.kind='integer' then value_text::integer end,case when d.kind in('quantity','decimal') then value_text::numeric end,case when d.kind='boolean' then value_text::boolean end,case when d.kind='quantity' then x->>'unit' end,eid,'approved');
 end loop;
 for x in select value from jsonb_array_elements(coalesce(p_data->'concerns','[]')) loop
 if s<>'skincare' or not exists(select 1 from public.concerns where id=x#>>'{}') then raise exception 'Choose a supported skincare concern';end if;
 if exists(select 1 from public.product_concerns where product_id=p_product and concern_id=x#>>'{}' and status='approved') then continue;end if;
 insert into public.evidence(source_type,url,finding,status,reviewed_by,reviewed_at,accessed_on) values(source,source_url,'Owner checked explicit product suitability: '||(x#>>'{}')||'. Not inferred from ingredients.','approved',actor,now(),current_date) returning id into eid;
 update public.concerns set active=true where id=x#>>'{}' and not active;
 insert into public.product_concerns(product_id,concern_id,evidence_id,status,qualification) values(p_product,x#>>'{}',eid,'approved','Confirmed against product label or official product information') on conflict(product_id,concern_id) do update set evidence_id=excluded.evidence_id,status=excluded.status,qualification=excluded.qualification;
 end loop;
end $discovery$;
revoke all on function app_private.discovery_scope(uuid),app_private.save_product_discovery(uuid,jsonb) from public,anon,authenticated,service_role;
-- Apply atomically inside existing authorized, revision-checked, idempotent Save.
do $hook$ declare definition text; needle text=' -- Remove from sale without deleting SKU identity, stock, images, orders or history.';begin
 definition=pg_get_functiondef('app_private.save_daily_product_016(uuid,integer,jsonb,uuid,text)'::regprocedure);
 if position(needle in definition)=0 then raise exception 'Unexpected product save definition; review before applying';end if;
 execute replace(definition,needle,E' if p_data ? ''discovery'' then perform app_private.save_product_discovery(p_product,p_data->''discovery'');end if;\n'||needle);
end $hook$;
-- Public attributes must remain in the product category and eligible variant scope.
create or replace view app_private.storefront_attributes as
 select f.product_id,f.variant_id,f.facet_id as key,d.name as label,
 coalesce(f.option_id,f.integer_value::text,f.decimal_value::text,f.boolean_value::text)||coalesce(' '||f.unit,'') as value,
 coalesce(v.label,f.integer_value::text,f.decimal_value::text,f.boolean_value::text)||coalesce(' '||f.unit,'') as value_label
 from public.product_facets f join public.facet_definitions d on d.id=f.facet_id and d.active
 join public.evidence e on e.id=f.evidence_id and e.status='approved'
 join public.facet_scopes scope on scope.facet_id=f.facet_id and scope.scope=app_private.discovery_scope(f.product_id)
 left join public.facet_values v on v.id=f.option_id where f.status='approved' and (f.variant_id is null or exists(select 1 from public.variants variant where variant.id=f.variant_id and variant.status='published'))
 union all select f.product_id,null,'concern','Concern',c.id,c.name from public.product_concerns f
 join public.concerns c on c.id=f.concern_id and c.active join public.evidence e on e.id=f.evidence_id and e.status='approved' where f.status='approved' and app_private.discovery_scope(f.product_id)='skincare';
create or replace function public.storefront_navigation() returns jsonb language sql stable security definer set search_path='' set statement_timeout='8s' as $navigation$
 with eligible as materialized(select distinct product_id,brand_id,brand,category_id,category,scope,product_type_id,product_type from app_private.storefront_variants),
 ancestors as (with recursive tree as(select c.id,c.parent_id,c.name,c.scope from public.categories c where c.id in(select category_id from eligible)
  union select c.id,c.parent_id,c.name,c.scope from public.categories c join tree t on c.id=t.parent_id where c.status='published') select * from tree)
 select jsonb_build_object('version',1,
  'brands',coalesce((select jsonb_agg(x order by x.name) from(select brand_id id,brand name,count(distinct product_id) count,array_agg(distinct scope) scopes from eligible group by brand_id,brand) x),'[]'),
  'categories',coalesce((select jsonb_agg(x order by x.name) from(select id,parent_id,name,scope from ancestors) x),'[]'),
  'types',coalesce((select jsonb_agg(x) from(select scope,product_type_id id,product_type name,count(distinct product_id) count from eligible group by scope,product_type_id,product_type) x),'[]'),
  'facets',coalesce((select jsonb_agg(x order by x.scope,x.label,x.value_label) from(select e.scope,a.key,a.label,a.value,a.value_label,count(distinct e.product_id) count from app_private.storefront_attributes a join app_private.storefront_variants e on e.product_id=a.product_id and (a.variant_id is null or a.variant_id=e.variant_id) where a.key<>'concern' group by e.scope,a.key,a.label,a.value,a.value_label) x),'[]'),
  'concerns',coalesce((select jsonb_agg(x) from(select a.value id,a.value_label name,count(distinct a.product_id) count from app_private.storefront_attributes a join eligible e on e.product_id=a.product_id where a.key='concern' group by a.value,a.value_label) x),'[]'));
$navigation$;
select app_private.refresh_storefront_search();

do $report$ declare definition text;begin
 definition=pg_get_functiondef('public.publication_report(uuid)'::regprocedure);
 if position($needle$'daily_editor_version',2$needle$ in definition)=0 then raise exception 'Unexpected publication report; review before applying';end if;
 execute replace(definition,$needle$'daily_editor_version',2$needle$,$replacement$'daily_editor_version',2,'discovery_editor_version',1$replacement$);
end $report$;

-- Apply the same inherited category scope to public projection and native RLS helpers.
do $inherited_scope$ declare definition text;begin
 definition=pg_get_viewdef('app_private.storefront_variants'::regclass,true);
 if position('c.scope::text AS scope' in definition)=0 then raise exception 'Unexpected storefront scope definition';end if;
 execute 'create or replace view app_private.storefront_variants as '||replace(definition,'c.scope::text AS scope','app_private.discovery_scope(p.id)::text AS scope');
 definition=pg_get_functiondef('public.facet_is_public(uuid)'::regprocedure);
 if position('s.scope=c.scope' in definition)=0 then raise exception 'Unexpected facet scope definition';end if;
 execute replace(definition,'s.scope=c.scope','s.scope=app_private.discovery_scope(p.id)');
 definition=pg_get_functiondef('public.concern_is_public(uuid,text)'::regprocedure);
 if position($needle$cat.scope='skincare'$needle$ in definition)=0 then raise exception 'Unexpected concern scope definition';end if;
 execute replace(definition,$needle$cat.scope='skincare'$needle$,$replacement$app_private.discovery_scope(p.id)='skincare'$replacement$);
end $inherited_scope$;
select app_private.refresh_storefront_search();

-- Existing assignment triggers share inherited scope, with explicit admin authorization.
create or replace function app_private.validate_facet() returns trigger language plpgsql security definer set search_path='' as $validate_facet$
begin
 perform app_private.require_admin();
 if not exists(select 1 from public.facet_scopes s where s.scope=app_private.discovery_scope(new.product_id) and s.facet_id=new.facet_id) then raise exception 'Facet outside category scope';end if;
 if new.status='approved' and not exists(select 1 from public.evidence where id=new.evidence_id and status='approved') then raise exception 'Approved evidence required';end if;
 return new;
end $validate_facet$;
create or replace function app_private.validate_concern() returns trigger language plpgsql security definer set search_path='' as $validate_concern$
begin
 perform app_private.require_admin();
 if app_private.discovery_scope(new.product_id) is distinct from 'skincare'::public.catalog_scope then raise exception 'Concern outside skincare scope';end if;
 if new.status='approved' and not exists(select 1 from public.evidence where id=new.evidence_id and status='approved') then raise exception 'Approved product-specific evidence required';end if;
 return new;
end $validate_concern$;
-- Names and assigned values both participate in search; common fragrance abbreviations are vocabulary aliases.
create function app_private.discovery_search_text(label text) returns text language sql immutable set search_path='' as $search_text$
 select replace(replace(replace(replace(replace(lower(coalesce(label,'')),'eau-de-parfum','eau de parfum edp'),'eau de parfum','eau de parfum edp'),'eau-de-toilette','eau de toilette edt'),'eau-de-cologne','eau de cologne edc'),'eau de toilette','eau de toilette edt');
$search_text$;
revoke all on function app_private.discovery_search_text(text) from public,anon,authenticated,service_role;
do $search_definitions$ declare signature text; definition text; needle text=$needle$string_agg(a.value_label,' ')$needle$;begin
 foreach signature in array array['app_private.refresh_storefront_search()','app_private.refresh_admin_catalog(uuid)'] loop
 definition=pg_get_functiondef(to_regprocedure(signature));
 if position(needle in definition)=0 then raise exception 'Unexpected search projection definition: %',signature;end if;
 execute replace(definition,needle,$replacement$string_agg(concat_ws(' ',a.label,app_private.discovery_search_text(a.value_label)),' ')$replacement$);
 end loop;
end $search_definitions$;
select app_private.refresh_storefront_search();
select app_private.refresh_admin_catalog();
