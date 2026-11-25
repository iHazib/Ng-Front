\set ON_ERROR_STOP on
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
create schema discovery_test;
create table discovery_test.checks(name text);
create table discovery_test.stock_before as select * from public.inventory_balances;
create function discovery_test.ok(p boolean,n text) returns void language plpgsql as $$begin if p is distinct from true then raise exception 'FAIL: %',n;end if;insert into discovery_test.checks values(n);end$$;
create function discovery_test.save(d jsonb,k uuid default gen_random_uuid()) returns jsonb language plpgsql as $$declare p public.products;begin
select * into p from public.products where id='15151515-0000-4000-8000-000000000001';
return public.save_daily_product(p.id,p.revision,jsonb_build_object('name',p.name,'brand',p.brand_id,'category',p.category_id,'productType',p.product_type_id,'discovery',d,'options',(select jsonb_agg(jsonb_build_object('id',v.id,'sku',v.original_sku,'label',v.label,'priceMinor',price.amount_minor,'countChanged',false)) from public.variants v join public.variant_prices price on price.variant_id=v.id where v.product_id=p.id and v.status<>'archived')),k,'save');end$$;
create function discovery_test.denied(d jsonb,n text) returns void language plpgsql as $$declare denied boolean=false;before integer;begin
select count(*) into before from public.product_facets;
begin perform discovery_test.save(d);exception when others then denied=true;end;
perform discovery_test.ok(denied and (select count(*) from public.product_facets)=before,n);end$$;
select discovery_test.ok((public.publication_report('15151515-0000-4000-8000-000000000001')->>'discovery_editor_version')::integer=1,'Installed capability advertised');
select discovery_test.denied('{"facets":[{"facetId":"skin-type","value":"skin-type:dry"}]}','Explicit confirmation required');
select discovery_test.denied('{"confirmed":true,"sourceType":"package","facets":[{"facetId":"concentration","value":"concentration:eau-de-parfum"}]}','Wrong category rejected');
select discovery_test.denied('{"confirmed":true,"sourceType":"package","facets":[{"facetId":"skin-type","value":"concentration:eau-de-parfum"}]}','Foreign facet option rejected');
select discovery_test.denied('{"confirmed":true,"sourceType":"official_page","sourceUrl":"javascript:alert(1)","concerns":["oiliness"]}','Unsafe source rejected');
select discovery_test.denied('{"confirmed":true,"sourceType":"package","facets":[{"facetId":"size","value":"-2","unit":"ml"}]}','Negative quantity rejected');
select discovery_test.denied('{"confirmed":true,"sourceType":"package","facets":[{"facetId":"size","value":"10","unit":"ml","variantId":"aaaaaaaa-aaaa-4aaa-8aaa-000000000000"}]}','Foreign variant rejected');
select discovery_test.save('{"confirmed":true,"sourceType":"package","facets":[{"facetId":"skin-type","value":"skin-type:dry"},{"facetId":"size","value":"10","unit":"ml","variantId":"15151515-0000-4000-8000-000000000002"}],"concerns":["oiliness","uneven-texture"]}');
select discovery_test.ok((select status='published' from public.products where id='15151515-0000-4000-8000-000000000001'),'Ordinary Save preserves published status');
select discovery_test.ok((select active from public.concerns where id='uneven-texture'),'Only assigned concern activated');
select discovery_test.ok((select count(*)=2 from app_private.storefront_attributes where product_id='15151515-0000-4000-8000-000000000001' and key='concern' and value in('oiliness','uneven-texture')),'Approved concerns become public attributes');
select discovery_test.ok((public.storefront_catalog(p_query=>'Oiliness',p_filters=>'{"skin-type":["skin-type:dry"]}')->>'total')::integer=1,'Combined assigned search and filter works');
select discovery_test.ok(exists(select 1 from jsonb_array_elements(public.storefront_navigation()->'facets') f where f->>'key'='skin-type' and f->>'value'='skin-type:dry'),'Navigation exposes supported assigned value');
select discovery_test.ok(not exists(select 1 from jsonb_array_elements(public.storefront_navigation()->'facets') f where f->>'key'='occasion'),'Unassigned vocabulary stays absent publicly');
insert into public.categories(id,parent_id,name,status) values('discovery-child','sf-fixture','Synthetic child','published');insert into public.category_product_types values('discovery-child','cleanser');
update public.products set category_id='discovery-child' where id='15151515-0000-4000-8000-000000000001';
select discovery_test.ok((public.storefront_catalog(p_scopes=>array['skincare'],p_filters=>'{"concern":["uneven-texture"]}')->>'total')::integer=1,'Inherited subcategory scope keeps public assignments searchable');
select discovery_test.ok(public.concern_is_public('15151515-0000-4000-8000-000000000001','uneven-texture'),'Native concern RLS uses inherited scope');
select discovery_test.ok((select count(*)=1 from public.product_facets where product_id='15151515-0000-4000-8000-000000000001' and facet_id='size' and decimal_value=10),'Typed numeric assignment saved');
select discovery_test.save('{"confirmed":true,"sourceType":"package","facets":[{"facetId":"size","value":"10.0000","unit":"ml","variantId":"15151515-0000-4000-8000-000000000002"}]}');
select discovery_test.ok((select count(*)=1 from public.product_facets where product_id='15151515-0000-4000-8000-000000000001' and facet_id='size' and decimal_value=10),'Equivalent numeric selection deduplicated');
do $$declare r integer;d jsonb;k uuid=gen_random_uuid();before integer;begin
 select revision into r from public.products where id='15151515-0000-4000-8000-000000000001';
 select jsonb_build_object('name',p.name,'brand',p.brand_id,'category',p.category_id,'productType',p.product_type_id,'discovery','{"confirmed":true,"sourceType":"package","facets":[{"facetId":"skin-type","value":"skin-type:normal"}]}'::jsonb,'options',(select jsonb_agg(jsonb_build_object('id',v.id,'sku',v.original_sku,'label',v.label,'priceMinor',price.amount_minor,'countChanged',false)) from public.variants v join public.variant_prices price on price.variant_id=v.id where v.product_id=p.id and v.status<>'archived')) into d from public.products p where p.id='15151515-0000-4000-8000-000000000001';
 perform public.save_daily_product('15151515-0000-4000-8000-000000000001',r,d,k,'save');select count(*) into before from public.evidence;
 perform public.save_daily_product('15151515-0000-4000-8000-000000000001',r,d,k,'save');perform discovery_test.ok((select count(*)=before from public.evidence),'Exact retry creates no repeated evidence');
 begin perform public.save_daily_product('15151515-0000-4000-8000-000000000001',r,d,gen_random_uuid(),'save');raise exception 'Unexpected stale acceptance';exception when others then if sqlerrm='Unexpected stale acceptance' then raise;end if;end;
 perform discovery_test.ok(true,'Stale Save rejected');
end$$;
select discovery_test.save(jsonb_build_object('removeConcerns','["oiliness"]'::jsonb,'removeFacets',(select jsonb_agg(id) from public.product_facets where product_id='15151515-0000-4000-8000-000000000001' and facet_id='skin-type')));
select discovery_test.ok(not exists(select 1 from app_private.storefront_attributes where product_id='15151515-0000-4000-8000-000000000001' and key='skin-type'),'Explicit removals refresh public attributes');
select discovery_test.ok((public.storefront_catalog(p_query=>'Oiliness')->>'total')::integer=0,'Search projection refreshed after removal');
-- Same physical stock and preserved required fields throughout attribute-only edits.
select discovery_test.ok(not exists(select * from discovery_test.stock_before except select * from public.inventory_balances),'Discovery save does not alter stock');
insert into public.categories(id,name,scope,status) values('discovery-fragrance','Synthetic fragrance','personal-fragrance','published');insert into public.category_product_types values('discovery-fragrance','cleanser');
update public.products set category_id='discovery-fragrance' where id='15151515-0000-4000-8000-000000000001';
select discovery_test.ok(not exists(select 1 from app_private.storefront_attributes where product_id='15151515-0000-4000-8000-000000000001' and key='concern'),'Category change withdraws old skincare claims publicly');
select discovery_test.denied('{"confirmed":true,"sourceType":"package","concerns":["dryness"]}','Skincare concern on fragrance rejected');
select discovery_test.save('{"confirmed":true,"sourceType":"package","facets":[{"facetId":"concentration","value":"concentration:eau-de-parfum"},{"facetId":"fragrance-family","value":"fragrance-family:woody"},{"facetId":"fragrance-note","newValue":"Synthetic Test Note"},{"facetId":"occasion","value":"occasion:evening"}]}');
select discovery_test.ok((public.storefront_catalog(p_query=>'Synthetic Test Note',p_filters=>'{"concentration":["concentration:eau-de-parfum"],"occasion":["occasion:evening"]}')->>'total')::integer=1,'Fragrance note search with concentration and occasion filters');
select discovery_test.ok((public.storefront_catalog(p_query=>'EDP Woody Evening')->>'total')::integer=1,'Common fragrance abbreviation and assigned values searchable');
select discovery_test.ok((public.admin_catalog_list(p_query=>'EDP Woody Evening')->>'total')::integer>0,'Admin search includes assigned values and fragrance aliases');
select discovery_test.ok(exists(select 1 from jsonb_array_elements(public.storefront_navigation()->'facets') f where f->>'key'='occasion' and f->>'scope'='personal-fragrance'),'Navigation has published occasion assignment with scope');
update public.variants set sellable_kind='factory_set' where product_id='15151515-0000-4000-8000-000000000001';
select discovery_test.denied('{"confirmed":true,"sourceType":"package","facets":[{"facetId":"fragrance-note","newValue":"Another Note"}]}','Fragrance set does not receive one invented scent profile');
select discovery_test.save('{"confirmed":true,"setSingleProfileConfirmed":true,"sourceType":"package","facets":[{"facetId":"fragrance-note","newValue":"Confirmed Shared Note"}]}');
select discovery_test.ok(exists(select 1 from app_private.storefront_attributes where value_label='Confirmed Shared Note'),'Explicit single-profile set confirmation supported');
update public.products set status='draft' where id='15151515-0000-4000-8000-000000000001';
select discovery_test.ok((public.storefront_catalog(p_query=>'Synthetic Test Note')->>'total')::integer=0,'Draft assignments remain private');
select discovery_test.ok(not exists(select 1 from jsonb_array_elements(public.storefront_navigation()->'facets') f where f->>'key'='occasion'),'Unsupported navigation removed when product drafted');
do $category_coverage$ declare item record;pid uuid='15151515-0000-4000-8000-000000000001';begin
 for item in select * from (values
 ('hair-care','hair-type','hair-type:curly'),('bath-body','body-format','body-format:lotion'),('cutlery','finish-colour','finish-colour:gold'),('makeup','coverage','coverage:full'),('home-fragrance','home-format','home-format:candle')
 ) x(scope,facet,value) loop
 insert into public.categories(id,name,scope) values('discovery-'||item.scope,'Synthetic '||item.scope,item.scope::public.catalog_scope);
 insert into public.category_product_types values('discovery-'||item.scope,'cleanser');
 update public.products set category_id='discovery-'||item.scope where id=pid;
 perform discovery_test.save(jsonb_build_object('confirmed',true,'sourceType','package','facets',jsonb_build_array(jsonb_build_object('facetId',item.facet,'value',item.value))));
 perform discovery_test.ok(exists(select 1 from public.product_facets where product_id=pid and facet_id=item.facet and option_id=item.value),'Category field saved: '||item.scope);
 end loop;
end $category_coverage$;
set role anon;
do $$begin begin perform public.save_daily_product(gen_random_uuid(),1,'{}',gen_random_uuid(),'save');raise exception 'write exposed';exception when insufficient_privilege then null;end;end$$;
reset role;
set role authenticated;set request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $$begin begin perform public.save_daily_product(gen_random_uuid(),1,'{}',gen_random_uuid(),'save');raise exception 'write exposed';exception when others then if sqlerrm='write exposed' then raise;end if;end;end$$;
reset role;
select count(*) assertions from discovery_test.checks;
