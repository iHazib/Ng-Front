\set ON_ERROR_STOP on
begin;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
insert into public.brands(id,name) values('al-fixture','CeraVe synthetic');
insert into public.brand_aliases(brand_id,alias) values('al-fixture','SyntheticDerm');
insert into public.categories(id,name,scope) values('al-main','Synthetic skin care','skincare');
insert into public.categories(id,parent_id,name,scope) values('al-child','al-main','Synthetic cleansers','skincare');
insert into public.category_product_types values('al-child','cleanser');
insert into public.products(id,name,brand_id,category_id,product_type_id) values('13131313-0000-4000-8000-000000000001','Admin synthetic cleanser','al-fixture','al-child','cleanser');
insert into public.variants(id,product_id,original_sku,label) values
 ('13131313-0000-4000-8000-000000000002','13131313-0000-4000-8000-000000000001','AL-SMALL','Small'),
 ('13131313-0000-4000-8000-000000000003','13131313-0000-4000-8000-000000000001','AL-LARGE','Large');
insert into public.variants(id,product_id,original_sku,label,status) values('13131313-0000-4000-8000-000000000004','13131313-0000-4000-8000-000000000001','AL-REMOVED','Removed','archived');
insert into public.sku_aliases values('AL-ALIAS','13131313-0000-4000-8000-000000000002');
select public.save_daily_product('13131313-0000-4000-8000-000000000001',1,'{"name":"Admin synthetic cleanser","brand":"al-fixture","category":"al-child","productType":"cleanser","featured":false,"options":[{"id":"13131313-0000-4000-8000-000000000002","sku":"AL-SMALL","label":"Small","priceMinor":null,"countChanged":false},{"id":"13131313-0000-4000-8000-000000000003","sku":"AL-LARGE","label":"Large","priceMinor":100000,"stock":0,"expectedStock":0,"countChanged":true}]}',gen_random_uuid());
insert into public.concerns(id,name,claim_kind) values('al-dry','Dry skin synthetic','hydration');
insert into public.product_concerns(product_id,concern_id,qualification) values('13131313-0000-4000-8000-000000000001','al-dry','Synthetic assigned data only');
insert into public.facet_definitions values('al-finish','Synthetic finish','enum',true);
insert into public.facet_scopes values('al-finish','skincare');
insert into public.facet_values values('al-matte','al-finish','Matte'),('al-gloss','al-finish','Gloss');
insert into public.product_facets(product_id,variant_id,facet_id,kind,option_id) values
 ('13131313-0000-4000-8000-000000000001','13131313-0000-4000-8000-000000000002','al-finish','enum','al-matte'),
 ('13131313-0000-4000-8000-000000000001','13131313-0000-4000-8000-000000000003','al-finish','enum','al-gloss');
do $test$ declare r jsonb;i jsonb;rev integer;before_doc text;old_episode text;begin
 r=public.admin_catalog_list('cerav cleanser dry skin','{"brand":"al-fixture","category":"al-main","type":"cleanser","status":"draft"}');
 if (r->>'total')::int<>2 or (r->>'products')::int<>1 then raise exception 'Combined typo assigned search/descendant category failed';end if;
 if (public.admin_catalog_list('AL-ALIAS')->>'total')::int<>1 or (public.admin_catalog_list('SyntheticDerm Small')->>'total')::int<>1 then raise exception 'Aliases/variant matching failed';end if;
 if (public.admin_catalog_list('cerave oily invented')->>'total')::int<>0 then raise exception 'Search invented suitability';end if;
 if (public.admin_catalog_list('AL-', '{"facets":{"concern":["al-dry"],"al-finish":["al-matte","nonexistent"]}}')->>'total')::int<>1 then raise exception 'Same-option AND/OR filters failed';end if;
 if (public.admin_catalog_list('AL-', '{"facets":{"al-finish":["al-matte"]},"issues":["price_missing","stock_count_missing"],"mode":"all"}')->>'total')::int<>1 then raise exception 'All issue filter failed';end if;
 if (public.admin_catalog_list('AL-', '{"issues":["stock_count_missing","out_of_stock"],"mode":"any"}')->>'total')::int<>2 then raise exception 'Any issue filter failed';end if;
 r=public.admin_catalog_list('AL-LARGE');
 if (r->'rows'->0->>'stock')::int<>0 or exists(select 1 from jsonb_array_elements(r->'rows'->0->'issues') x where x->>'code' in('stock_count_missing','price_missing')) then raise exception 'Confirmed zero or archived variant polluted issues';end if;
 if (public.admin_catalog_list('AL-', '{}',1,1)->>'total')::int<>2 or jsonb_array_length(public.admin_catalog_list('AL-','{}',1,1)->'rows')<>1 then raise exception 'Bounded pagination/count failed';end if;
 select revision,row_to_json(p)::text into rev,before_doc from public.products p where id='13131313-0000-4000-8000-000000000001';
 r=public.admin_catalog_list('AL-SMALL');select x into i from jsonb_array_elements(r->'rows'->0->'issues') x where x->>'code'='description_missing';old_episode=i->>'episode';
 perform public.admin_catalog_reminder(i->>'key',(i->>'episode')::uuid,true);
 if (public.admin_catalog_list('AL-','{"reminders":"ignored"}')->>'total')::int<>2 then raise exception 'Product reminder dismissal must affect both options';end if;
 if (select revision<>rev or row_to_json(p)::text<>before_doc from public.products p where id='13131313-0000-4000-8000-000000000001') then raise exception 'Ignore changed business product';end if;
 if not exists(select 1 from jsonb_array_elements_text(public.publication_report('13131313-0000-4000-8000-000000000001')->'essential_blockers') x where x='description_missing') then raise exception 'Ignore bypassed publication rules';end if;
 perform public.admin_catalog_reminder(i->>'key',(i->>'episode')::uuid,false);
 if (public.admin_catalog_list('AL-','{"reminders":"ignored"}')->>'total')::int<>0 then raise exception 'Restore failed';end if;
 perform public.admin_catalog_reminder(i->>'key',(i->>'episode')::uuid,true);
 update public.products set description='Fixed synthetic content' where id='13131313-0000-4000-8000-000000000001';
 update public.products set description=null where id='13131313-0000-4000-8000-000000000001';
 r=public.admin_catalog_list('AL-SMALL');select x into i from jsonb_array_elements(r->'rows'->0->'issues') x where x->>'code'='description_missing';
 if (i->>'ignored')::boolean or i->>'episode'=old_episode then raise exception 'Recurrence did not restore reminder';end if;
 if (public.admin_catalog_list('AL-','{"issues":["publication_blockers"],"mode":"all"}')->>'total')::int<>2 then raise exception 'Ignoring bypassed blockers';end if;
 update public.products set status='archived' where id='13131313-0000-4000-8000-000000000001';
 if (public.admin_catalog_list('AL-','{"status":"archived"}')->>'total')::int<>2 then raise exception 'Hidden product missing from search';end if;
 raise notice 'PASS: admin assigned search, aliases, typo, variants, AND/OR filters, counts/pagination, uncounted/zero, ignore/restore/recurrence/revision preservation';
end $test$;
reset role;
do $rls$ begin
 if exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='app_private' and c.relname in('admin_catalog_search','admin_reminder_issues','admin_reminder_dismissals') and not c.relrowsecurity) then raise exception 'Private RLS missing';end if;
end $rls$;
set local role anon;
do $deny$ begin
 begin perform public.admin_catalog_list();raise exception 'Anonymous RPC access allowed';exception when insufficient_privilege then null;end;
 begin perform 1 from app_private.admin_catalog_search;raise exception 'Anonymous direct access allowed';exception when insufficient_privilege then null;end;
 begin perform 1 from app_private.admin_category_membership;raise exception 'Anonymous membership access allowed';exception when insufficient_privilege then null;end;
 begin perform 1 from app_private.admin_list_options;raise exception 'Anonymous option view access allowed';exception when insufficient_privilege then null;end;
end $deny$;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $deny$ begin
 begin perform public.admin_catalog_list();raise exception 'Non-admin RPC access allowed';exception when insufficient_privilege then null;end;
 begin perform public.admin_catalog_filter_options();raise exception 'Non-admin options allowed';exception when insufficient_privilege then null;end;
 begin perform public.admin_catalog_reminder('x',gen_random_uuid(),true);raise exception 'Non-admin dismiss allowed';exception when insufficient_privilege then null;end;
 begin perform 1 from app_private.admin_reminder_dismissals;raise exception 'Non-admin direct access allowed';exception when insufficient_privilege then null;end;
 begin perform 1 from app_private.admin_category_membership;raise exception 'Non-admin membership access allowed';exception when insufficient_privilege then null;end;
 begin perform 1 from app_private.admin_list_options;raise exception 'Non-admin option view access allowed';exception when insufficient_privilege then null;end;
 raise notice 'PASS: anonymous/non-admin RPC and direct private access denied';
end $deny$;
reset role;
rollback;
