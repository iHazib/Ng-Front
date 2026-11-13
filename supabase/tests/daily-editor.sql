\set ON_ERROR_STOP on
begin;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
insert into public.products(id,name) values('77777777-0000-4000-8000-000000000001','Daily editor test');
select public.save_daily_product('77777777-0000-4000-8000-000000000001',1,'{"name":"Daily editor test","brand":"","category":"","productType":"","description":"","featured":false,"options":[{"id":"77777777-0000-4000-8000-000000000002","sku":"DAILY-TEST","label":"","priceMinor":null,"stock":0,"countChanged":true,"expectedStock":0}]}','77777777-0000-4000-8000-000000000003');
select public.save_daily_product('77777777-0000-4000-8000-000000000001',1,'{"name":"Daily editor test","brand":"","category":"","productType":"","description":"","featured":false,"options":[{"id":"77777777-0000-4000-8000-000000000002","sku":"DAILY-TEST","label":"","priceMinor":null,"stock":0,"countChanged":true,"expectedStock":0}]}','77777777-0000-4000-8000-000000000003');
do $$ begin
 if (select count(*) from public.inventory_counts where variant_id='77777777-0000-4000-8000-000000000002')<>1 then raise exception 'Duplicate count'; end if;
 if (select reconciled_at from public.inventory_balances where variant_id='77777777-0000-4000-8000-000000000002') is null then raise exception 'Zero count not reconciled'; end if;
 if (select status from public.products where id='77777777-0000-4000-8000-000000000001')<>'draft' then raise exception 'Auto publication'; end if;
 raise notice 'PASS: draft save accepts missing optional/price fields; zero count audited; retry idempotent';
end $$;
select public.save_daily_product('77777777-0000-4000-8000-000000000001',2,'{"name":"Two options","brand":"","category":"","productType":"","description":"","featured":true,"options":[{"id":"77777777-0000-4000-8000-000000000002","sku":"DAILY-TEST","label":"Small","priceMinor":123400,"stock":3,"countChanged":true,"expectedStock":0},{"id":"77777777-0000-4000-8000-000000000004","sku":"DAILY-LARGE","label":"Large","priceMinor":200000,"stock":4,"countChanged":true,"expectedStock":0}]}','77777777-0000-4000-8000-000000000005');
do $$ begin
 if (select sum(on_hand) from public.inventory_balances where variant_id in('77777777-0000-4000-8000-000000000002','77777777-0000-4000-8000-000000000004'))<>7 then raise exception 'Counts wrong'; end if;
 if (select count(*) from public.variants where product_id='77777777-0000-4000-8000-000000000001')<>2 then raise exception 'Variants wrong'; end if;
 raise notice 'PASS: two options and stock counts saved atomically';
end $$;
do $$ declare data jsonb; revision integer; rejected boolean; begin
 data='{"name":"Must roll back","brand":"","category":"","productType":"","description":"","featured":false,"options":[{"id":"77777777-0000-4000-8000-000000000002","sku":"DAILY-TEST","label":"Small","priceMinor":99900,"stock":9,"countChanged":true,"expectedStock":0}]}';
 select p.revision into revision from public.products p where p.id='77777777-0000-4000-8000-000000000001';
 rejected=false;
 begin perform public.save_daily_product('77777777-0000-4000-8000-000000000001',revision,data,gen_random_uuid()); exception when raise_exception then rejected=sqlerrm like 'Stock changed%'; end;
 if not rejected or (select name from public.products where id='77777777-0000-4000-8000-000000000001')<>'Two options' then raise exception 'Stale stock save did not roll back'; end if;
 data=jsonb_set(data,'{options,0,expectedStock}','3');
 rejected=false;
 begin perform public.save_daily_product('77777777-0000-4000-8000-000000000001',revision,data,gen_random_uuid(),'publish'); exception when raise_exception then rejected=sqlerrm like 'Missing publication information:%'; end;
 if not rejected or (select on_hand from public.inventory_balances where variant_id='77777777-0000-4000-8000-000000000002')<>3 then raise exception 'Incomplete publication must roll back stock'; end if;
 if (select count(*) from public.variants where product_id='77777777-0000-4000-8000-000000000001' and status<>'archived')<>2 then raise exception 'Publication rollback lost an option'; end if;
 raise notice 'PASS: stale stock and incomplete publication rejected with complete transaction rollback';
 perform public.save_daily_product('77777777-0000-4000-8000-000000000001',revision,data,gen_random_uuid());
 if (select status from public.variants where id='77777777-0000-4000-8000-000000000004')<>'archived' or (select on_hand from public.inventory_balances where variant_id='77777777-0000-4000-8000-000000000004')<>4 then raise exception 'Removed option history or stock lost'; end if;
 raise notice 'PASS: removing an option archives its identity and preserves its stock/history';
end $$;
-- All statuses below belong to a synthetic local fixture; no provider upload is implied.
insert into public.media_assets(id,provider,cloudinary_public_id,cloudinary_version,status,alt)
 values('77777777-0000-4000-8000-000000000007','cloudinary','local-test/daily-editor',1,'approved','Synthetic local SQL asset');
insert into public.product_media(product_id,media_id,position,is_primary)
 values('77777777-0000-4000-8000-000000000001','77777777-0000-4000-8000-000000000007',0,true);
do $$ declare data jsonb; rev integer; rejected boolean; old_counts integer; begin
 data='{"name":"Visibility test","brand":"pixi","category":"makeup/face","productType":"blush","description":"Synthetic fixture","featured":true,"options":[{"id":"77777777-0000-4000-8000-000000000002","sku":"DAILY-TEST","label":"Small","priceMinor":99900,"countChanged":false}]}';
 select revision into rev from public.products where id='77777777-0000-4000-8000-000000000001';
 perform public.save_daily_product('77777777-0000-4000-8000-000000000001',rev,data,gen_random_uuid(),'publish');
 data=jsonb_set(data,'{name}','"Ordinary published edit"');
 select revision into rev from public.products where id='77777777-0000-4000-8000-000000000001';
 perform public.save_daily_product('77777777-0000-4000-8000-000000000001',rev,data,gen_random_uuid());
 if (select status from public.products where id='77777777-0000-4000-8000-000000000001')<>'published' or (select status from public.variants where id='77777777-0000-4000-8000-000000000002')<>'published' then raise exception 'Ordinary save changed published visibility'; end if;
 if not public.product_is_public('77777777-0000-4000-8000-000000000001') then raise exception 'Valid ordinary edit lost public eligibility'; end if;
 raise notice 'PASS: ordinary published save preserves product/option visibility and public eligibility';
 -- An added option stays draft during an ordinary save; existing options stay published.
 data=jsonb_set(data,'{options}',data->'options'||'[{"id":"77777777-0000-4000-8000-000000000006","sku":"DAILY-NEW","label":"Large","priceMinor":129900,"stock":0,"countChanged":true,"expectedStock":0}]'::jsonb);
 select revision into rev from public.products where id='77777777-0000-4000-8000-000000000001';
 perform public.save_daily_product('77777777-0000-4000-8000-000000000001',rev,data,gen_random_uuid());
 data=jsonb_set(data,'{options,1,countChanged}','false');
 select revision into rev from public.products where id='77777777-0000-4000-8000-000000000001';
 perform public.save_daily_product('77777777-0000-4000-8000-000000000001',rev,data,gen_random_uuid());
 if (select status from public.variants where id='77777777-0000-4000-8000-000000000006')<>'draft' or (select status from public.variants where id='77777777-0000-4000-8000-000000000002')<>'published' then raise exception 'Ordinary edit changed mixed option statuses'; end if;
 raise notice 'PASS: mixed option statuses preserved; new options do not silently publish';
 select revision into rev from public.products where id='77777777-0000-4000-8000-000000000001';
 select count(*) into old_counts from public.inventory_counts;
 rejected=false;
 begin perform public.save_daily_product('77777777-0000-4000-8000-000000000001',rev,jsonb_set(jsonb_set(jsonb_set(jsonb_set(data,'{options,0,priceMinor}','null'),'{options,0,countChanged}','true'),'{options,0,stock}','10'),'{options,0,expectedStock}','9'),gen_random_uuid()); exception when raise_exception then rejected=sqlerrm like 'Published edit would be invalid:%price_missing%'; end;
 if not rejected or (select amount_minor from public.variant_prices where variant_id='77777777-0000-4000-8000-000000000002')<>99900 or (select revision from public.products where id='77777777-0000-4000-8000-000000000001')<>rev or (select count(*) from public.inventory_counts)<>old_counts or (select on_hand from public.inventory_balances where variant_id='77777777-0000-4000-8000-000000000002')<>9 then raise exception 'Invalid published edit did not fully roll back'; end if;
 rejected=false;
 begin perform public.save_daily_product('77777777-0000-4000-8000-000000000001',rev,jsonb_set(data,'{description}','""'),gen_random_uuid()); exception when raise_exception then rejected=sqlerrm like 'Published edit would be invalid:%description_missing%'; end;
 if not rejected or (select status from public.products where id='77777777-0000-4000-8000-000000000001')<>'published' then raise exception 'Missing published copy not rejected clearly'; end if;
 raise notice 'PASS: invalid published price/copy edit rejected actionably without changing status or data';
 perform public.save_daily_product('77777777-0000-4000-8000-000000000001',rev,data,gen_random_uuid(),'hide');
 data=jsonb_set(data,'{name}','"Ordinary hidden edit"');
 select revision into rev from public.products where id='77777777-0000-4000-8000-000000000001';
 perform public.save_daily_product('77777777-0000-4000-8000-000000000001',rev,data,gen_random_uuid());
 if (select status from public.products where id='77777777-0000-4000-8000-000000000001')<>'archived' or public.product_is_public('77777777-0000-4000-8000-000000000001') or (select status from public.variants where id='77777777-0000-4000-8000-000000000002')<>'published' or (select status from public.variants where id='77777777-0000-4000-8000-000000000006')<>'draft' then raise exception 'Hidden save changed visibility'; end if;
 raise notice 'PASS: ordinary hidden edit remains hidden and preserves existing option statuses';
 select revision into rev from public.products where id='77777777-0000-4000-8000-000000000001';
 perform public.save_daily_product('77777777-0000-4000-8000-000000000001',rev,data,gen_random_uuid(),'draft');
 if (select status from public.products where id='77777777-0000-4000-8000-000000000001')<>'draft' or exists(select 1 from public.variants where product_id='77777777-0000-4000-8000-000000000001' and status not in('draft','archived')) then raise exception 'Explicit draft failed'; end if;
 select revision into rev from public.products where id='77777777-0000-4000-8000-000000000001';
 perform public.save_daily_product('77777777-0000-4000-8000-000000000001',rev,data,gen_random_uuid(),'publish');
 if not public.variant_is_public('77777777-0000-4000-8000-000000000006') or (select status from public.variants where id='77777777-0000-4000-8000-000000000004')<>'archived' then raise exception 'Explicit publish failed or restored removed option'; end if;
 raise notice 'PASS: explicit Draft/Publish transitions work; removed options remain archived';
end $$;
reset role;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $$ declare denied boolean=false; begin
 begin perform public.save_daily_product('77777777-0000-4000-8000-000000000001',3,'{}',gen_random_uuid()); exception when insufficient_privilege then denied=true; end;
 if not denied then raise exception 'Nonadmin allowed'; end if;
 raise notice 'PASS: nonadmin daily save rejected';
end $$;
rollback;
