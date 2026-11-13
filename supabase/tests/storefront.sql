\set ON_ERROR_STOP on
begin;
do $security$ begin
 if not (select relrowsecurity from pg_class where oid='app_private.storefront_search'::regclass) then raise exception 'Private search RLS missing'; end if;
 if exists(select 1 from pg_policy where polrelid='app_private.storefront_search'::regclass) then raise exception 'Private search must have no client policies'; end if;
 if has_table_privilege('anon','app_private.storefront_search','SELECT') or has_table_privilege('authenticated','app_private.storefront_search','SELECT') then raise exception 'Private search client grants present'; end if;
 if exists(select 1 from pg_proc where oid in('public.storefront_navigation()'::regprocedure,'public.storefront_catalog(text,text[],text,jsonb,text,integer,integer,text,boolean)'::regprocedure) and (not prosecdef or proowner<>(select relowner from pg_class where oid='app_private.storefront_search'::regclass))) then raise exception 'Public RPC must use authorized search-table owner'; end if;
 raise notice 'PASS: private search RLS enabled, no policies/client grants, authorized SECURITY DEFINER owners';
end $security$;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
insert into public.brands(id,name) values('sf-fixture','Synthetic CeraVe');
insert into public.brand_aliases(brand_id,alias) values('sf-fixture','SyntheticDerm');
insert into public.categories(id,name,scope) values('sf-fixture','Synthetic cleansers','skincare');
insert into public.category_product_types values('sf-fixture','cleanser');
insert into public.products(id,name) values('99999999-0000-4000-8000-000000000001','Synthetic cleanser');
select public.save_daily_product('99999999-0000-4000-8000-000000000001',1,'{"name":"Synthetic cleanser","brand":"sf-fixture","category":"sf-fixture","productType":"cleanser","description":"Local SQL fixture only","featured":true,"options":[{"id":"99999999-0000-4000-8000-000000000002","sku":"SF-RED","label":"Small","priceMinor":100000,"stock":3,"expectedStock":0,"countChanged":true},{"id":"99999999-0000-4000-8000-000000000003","sku":"SF-BLUE","label":"Large","priceMinor":200000,"stock":0,"expectedStock":0,"countChanged":true}]}',gen_random_uuid());
insert into public.evidence(id,source_type,finding,status,reviewed_by,reviewed_at) values('99999999-0000-4000-8000-000000000004','package','Synthetic SQL concern fixture, not manufacturer research','approved','00000000-0000-0000-0000-000000000001',now());
insert into public.concerns(id,name,claim_kind,active) values('sf-dry','Dry skin','hydration',true);
insert into public.product_concerns values('99999999-0000-4000-8000-000000000001','sf-dry','99999999-0000-4000-8000-000000000004','approved','Synthetic fixture only');
insert into public.facet_definitions values('sf-size','Synthetic size','quantity',true),('sf-finish','Synthetic finish','enum',true);
insert into public.facet_scopes values('sf-size','skincare'),('sf-finish','skincare');
insert into public.facet_values values('sf-red','sf-finish','Synthetic red'),('sf-blue','sf-finish','Synthetic blue');
insert into public.product_facets(product_id,variant_id,facet_id,kind,decimal_value,unit,evidence_id,status) values
 ('99999999-0000-4000-8000-000000000001','99999999-0000-4000-8000-000000000002','sf-size','quantity',10,'ml','99999999-0000-4000-8000-000000000004','approved'),
 ('99999999-0000-4000-8000-000000000001','99999999-0000-4000-8000-000000000003','sf-size','quantity',20,'ml','99999999-0000-4000-8000-000000000004','approved');
insert into public.product_facets(product_id,variant_id,facet_id,kind,option_id,evidence_id,status) values
 ('99999999-0000-4000-8000-000000000001','99999999-0000-4000-8000-000000000002','sf-finish','enum','sf-red','99999999-0000-4000-8000-000000000004','approved'),
 ('99999999-0000-4000-8000-000000000001','99999999-0000-4000-8000-000000000003','sf-finish','enum','sf-blue','99999999-0000-4000-8000-000000000004','approved');
insert into public.catalog_search_aliases(product_id,alias,status,reviewed_by,reviewed_at) values
 ('99999999-0000-4000-8000-000000000001','Verified synthetic synonym','approved','00000000-0000-0000-0000-000000000001',now());
insert into public.catalog_search_aliases(product_id,alias) values('99999999-0000-4000-8000-000000000001','Pending secret synonym');
insert into public.media_assets(id,provider,cloudinary_public_id,cloudinary_version,cloudinary_cloud_name,cloudinary_format,width,height,alt,status,lifecycle)
values('99999999-0000-4000-8000-000000000005','cloudinary','mock/fixture',1,'mock','png',1,1,'Synthetic pixel','approved','linked');
insert into public.product_media(product_id,media_id,position,is_primary) values('99999999-0000-4000-8000-000000000001','99999999-0000-4000-8000-000000000005',0,true);
select public.save_daily_product('99999999-0000-4000-8000-000000000001',2,'{"name":"Synthetic cleanser","brand":"sf-fixture","category":"sf-fixture","productType":"cleanser","description":"Local SQL fixture only","featured":true,"options":[{"id":"99999999-0000-4000-8000-000000000002","sku":"SF-RED","label":"Small","priceMinor":100000,"stock":3,"expectedStock":3,"countChanged":false},{"id":"99999999-0000-4000-8000-000000000003","sku":"SF-BLUE","label":"Large","priceMinor":200000,"stock":0,"expectedStock":0,"countChanged":false}]}',gen_random_uuid(),'publish');
set local role anon;
do $test$ declare r jsonb; begin
 begin
  perform 1 from app_private.storefront_search limit 1;
  raise exception 'Anonymous direct search access allowed';
 exception when insufficient_privilege then null;
 end;
 r=public.storefront_catalog('Cerave cleanser for dry skin',array['skincare']);
 if (r->>'total')::integer<>1 or jsonb_array_length(r->'products'->0->'variants')<>2 then raise exception 'Combined verified search failed'; end if;
 if r::text like '%source_cost%' or r::text like '%private_path%' or r::text like '%finding%' then raise exception 'Private payload leak'; end if;
 if (public.storefront_catalog('cerav cleanser',array['skincare'])->>'total')::integer<>1 then raise exception 'Typo/prefix search failed'; end if;
 if (public.storefront_catalog('SF-RED')->>'total')::integer<>1 then raise exception 'SKU search failed'; end if;
 if (public.storefront_catalog('',array['skincare'],null,'{"brand":["missing","sf-fixture"],"concern":["sf-dry"],"availability":["in-stock"]}')->>'total')::integer<>1 then raise exception 'AND/OR filter failed'; end if;
 if (public.storefront_catalog('',array['skincare'],null,'{"brand":["missing"],"concern":["sf-dry"]}')->>'total')::integer<>0 then raise exception 'Unsupported filter broadened results'; end if;
 if jsonb_array_length(public.storefront_catalog('',array['skincare'],null,'{}','relevance',1,24,null,true)->'products')<>1 then raise exception 'Homepage selection failed'; end if;
 if (public.storefront_catalog('Verified synthetic synonym')->>'total')::integer<>1 or (public.storefront_catalog('Pending secret synonym')->>'total')::integer<>0 then raise exception 'Alias approval failed'; end if;
 if (public.storefront_catalog('',array['skincare'],null,'{"sf-size":["10.0000 ml"],"sf-finish":["sf-blue"]}')->>'total')::integer<>0 then raise exception 'Facets crossed different variants'; end if;
 r=public.storefront_catalog('',array['skincare'],null,'{"sf-size":["10.0000 ml","20.0000 ml"],"sf-finish":["sf-blue"]}');
 if (r->>'total')::integer<>1 or jsonb_array_length(r->'products'->0->'variants')<>1 or (r->'products'->0->'variants'->0->>'priceMinor')::bigint<>200000 or (r->'products'->0->'variants'->0->>'available')::integer<>0 then raise exception 'Variant projection incorrect'; end if;
 if (public.storefront_catalog('',array['home-fragrance'])->>'total')::integer<>0 then raise exception 'Home fragrance branch mixed with skincare'; end if;
 raise notice 'PASS: public SKU/combined/fuzzy search; OR within and AND across filters; public payload allowlist; homepage';
 raise notice 'PASS: approved versus pending aliases; variant-specific filter conjunction and prices/availability; fragrance branch isolation';
end $test$;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $test$ begin
 begin
  perform 1 from app_private.storefront_search limit 1;
  raise exception 'Nonadmin direct search access allowed';
 exception when insufficient_privilege then null;
 end;
 if (public.storefront_catalog('SF-RED')->>'total')::integer<>1 then raise exception 'Nonadmin public catalog failed'; end if;
 if (select count(*) from public.catalog_search_aliases)<>0 then raise exception 'Nonadmin alias management leak'; end if;
 raise notice 'PASS: nonadmin public-only projection; private alias management hidden';
end $test$;
-- Test RLS independently of revoked schema/table privileges. Temporary grants
-- exist only inside this disposable, rolled-back test transaction.
reset role;
grant usage on schema app_private to anon,authenticated;
grant select on app_private.storefront_search to anon,authenticated;
set local role anon;
do $rls$ begin
 if exists(select 1 from app_private.storefront_search) then raise exception 'Anonymous RLS exposed search rows'; end if;
 if (public.storefront_catalog('SF-RED')->>'total')::integer<>1 or not exists(select 1 from jsonb_array_elements(public.storefront_navigation()->'brands') b where b->>'id'='sf-fixture') then raise exception 'Anonymous owner RPC failed with search RLS'; end if;
 raise notice 'PASS: anonymous direct access denied; RLS independently denies rows; both owner RPCs work';
end $rls$;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $rls$ begin
 if exists(select 1 from app_private.storefront_search) then raise exception 'Nonadmin RLS exposed search rows'; end if;
 if (public.storefront_catalog('SF-RED')->>'total')::integer<>1 or not exists(select 1 from jsonb_array_elements(public.storefront_navigation()->'brands') b where b->>'id'='sf-fixture') then raise exception 'Nonadmin owner RPC failed with search RLS'; end if;
 raise notice 'PASS: nonadmin direct access denied; RLS independently denies rows; both owner RPCs work';
end $rls$;
reset role;
revoke select on app_private.storefront_search from anon,authenticated;
revoke usage on schema app_private from anon,authenticated;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
update public.products set status='archived' where id='99999999-0000-4000-8000-000000000001';
set local role anon;
do $test$ begin
 if (public.storefront_catalog('SF-RED')->>'total')::integer<>0 then raise exception 'Hidden product leaked'; end if;
 if (public.storefront_catalog('CV-001')->>'total')::integer<>0 then raise exception 'Real draft leaked'; end if;
 raise notice 'PASS: hidden/draft exclusions and immediate freshness';
end $test$;
rollback;
