\set ON_ERROR_STOP on
begin;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
insert into public.brands(id,name) values('sf-fixture','Synthetic CeraVe');
insert into public.brand_aliases(brand_id,alias) values('sf-fixture','SyntheticDerm');
insert into public.categories(id,name,scope) values('sf-fixture','Synthetic cleansers','skincare');
insert into public.category_product_types values('sf-fixture','cleanser');
insert into public.products(id,name) values('99999999-0000-4000-8000-000000000001','Synthetic cleanser');
select public.save_daily_product('99999999-0000-4000-8000-000000000001',1,'{"name":"Synthetic cleanser","brand":"sf-fixture","category":"sf-fixture","productType":"cleanser","description":"Local SQL fixture only","featured":false,"options":[{"id":"99999999-0000-4000-8000-000000000002","sku":"SF-RED","label":"Small","priceMinor":100000,"stock":3,"expectedStock":0,"countChanged":true},{"id":"99999999-0000-4000-8000-000000000003","sku":"SF-BLUE","label":"Large","priceMinor":200000,"stock":0,"expectedStock":0,"countChanged":true}]}',gen_random_uuid());
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
select public.save_daily_product('99999999-0000-4000-8000-000000000001',2,'{"name":"Synthetic cleanser","brand":"sf-fixture","category":"sf-fixture","productType":"cleanser","description":"Local SQL fixture only","featured":false,"options":[{"id":"99999999-0000-4000-8000-000000000002","sku":"SF-RED","label":"Small","priceMinor":100000,"stock":3,"expectedStock":3,"countChanged":false},{"id":"99999999-0000-4000-8000-000000000003","sku":"SF-BLUE","label":"Large","priceMinor":200000,"stock":0,"expectedStock":0,"countChanged":false}]}',gen_random_uuid(),'publish');

reset role;


set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
select public.adjust_inventory('99999999-0000-4000-8000-000000000002',17,'Synthetic deal fixture','deal-red-stock');
select public.adjust_inventory('99999999-0000-4000-8000-000000000003',10,'Synthetic deal fixture','deal-blue-stock');
create function pg_temp.deal_data() returns jsonb language sql as $$ select '{"title":"Synthetic assembled deal","slug":"synthetic-assembled-deal","description":"Synthetic SQL fixture only","priceMinor":250000,"setAside":0,"components":[{"id":"99999999-0000-4000-8000-000000000002","quantity":2},{"id":"99999999-0000-4000-8000-000000000002","quantity":1},{"id":"99999999-0000-4000-8000-000000000003","quantity":1}]}'::jsonb;$$;
select public.save_deal('17171717-0000-4000-8000-000000000001',0,gen_random_uuid(),'draft',pg_temp.deal_data());
insert into public.media_assets(id,provider,cloudinary_public_id,cloudinary_version,cloudinary_cloud_name,cloudinary_format,width,height,alt,status,lifecycle) values('17171717-0000-4000-8000-000000000002','cloudinary','mock/deal-fixture',1,'mock','png',1,1,'Synthetic assembled deal image','approved','linked');
insert into public.deal_media(deal_id,media_id,position,is_primary) values('17171717-0000-4000-8000-000000000001','17171717-0000-4000-8000-000000000002',0,true);
select public.save_deal('17171717-0000-4000-8000-000000000001',2,gen_random_uuid(),'publish',pg_temp.deal_data()||'{"setAside":2}');
do $$ begin
 if (select quantity from public.deal_components where deal_id='17171717-0000-4000-8000-000000000001' and variant_id='99999999-0000-4000-8000-000000000002')<>3 then raise exception 'Repeated SKU aggregation failed';end if;
 if (select reserved from public.inventory_balances where variant_id='99999999-0000-4000-8000-000000000002')<>6 then raise exception 'Set aside failed';end if;
 if (public.storefront_deals()->'deals'->0->>'available')::int<>6 then raise exception 'Deal availability failed';end if;
 raise notice 'PASS: draft/publish, repeated SKUs, approved own media, shared stock and set aside';end $$;
savepoint homepage;
do $$ declare h1 uuid=gen_random_uuid();h2 uuid=gen_random_uuid();op uuid=gen_random_uuid();failed boolean=false;data jsonb;begin
 perform public.save_homepage_content('products',jsonb_build_array(jsonb_build_object('id',h1,'entity','17171717-0000-4000-8000-000000000001','kind','deal'),jsonb_build_object('id',h2,'entity','99999999-0000-4000-8000-000000000001','kind','product')));
 if public.storefront_deals(p_home=>true)#>>'{homeOrder,0,kind}'<>'deal' or (select position from public.homepage_selections where id=h1)<>0 then raise exception 'Mixed homepage order not projected';end if;
 if not exists(select 1 from jsonb_array_elements(public.admin_content_choices('homepage-products','Synthetic')) x where x->>'kind'='deal') or exists(select 1 from jsonb_array_elements(public.admin_content_choices('products','Synthetic')) x where x->>'kind'='deal') then raise exception 'Homepage/article choices mixed incorrectly';end if;
 perform public.save_homepage_content('products',jsonb_build_array(jsonb_build_object('id',h2,'entity','99999999-0000-4000-8000-000000000001','kind','product'),jsonb_build_object('id',h1,'entity','17171717-0000-4000-8000-000000000001','kind','deal')));
 data=pg_temp.deal_data()||'{"setAside":2,"homepage":true,"homePosition":1}';
 perform public.save_deal('17171717-0000-4000-8000-000000000001',3,op,'save',data);perform public.save_deal('17171717-0000-4000-8000-000000000001',3,op,'save',data);
 if (select revision from app_private.deal_settings where deal_id='17171717-0000-4000-8000-000000000001')<>4 or (select reserved from public.inventory_balances where variant_id='99999999-0000-4000-8000-000000000002')<>6 then raise exception 'Save retry changed pool/revision twice';end if;
 begin perform public.save_deal('17171717-0000-4000-8000-000000000001',4,gen_random_uuid(),'save',data||'{"homePosition":0}');exception when others then failed=true;end;
 if not failed or (select product_id from public.homepage_selections where id=h2)<>'99999999-0000-4000-8000-000000000001' then raise exception 'Owner product selection overwritten';end if;
 raise notice 'PASS: mixed homepage selection/order, isolated article choices, protected owner slots and deal-save retry';
end $$;
rollback to homepage;
create function pg_temp.place_deal(oid uuid,lines jsonb) returns jsonb language sql as $$ select public.place_guest_order(oid,repeat('a',64),repeat('b',64),lines,'{"name":"Synthetic Guest","phone":"+923001234567","address":"Synthetic address","city":"Test City"}','{"id":"test","label":"Synthetic","feeMinor":0}','{"id":"bank-transfer","label":"Synthetic","allocation":"temporary","accountScope":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","accountTitle":"Synthetic","destination":"TEST-ONLY"}','{"mode":"development","version":"deal-test","paymentSeconds":60,"reviewExtensionSeconds":30}');$$;
do $test$ declare o uuid=gen_random_uuid();r jsonb;lines jsonb;rev integer;failed boolean=false;begin
 lines=jsonb_build_array(jsonb_build_object('id','17171717-0000-4000-8000-000000000001','kind','deal','quantity',1,'expectedPriceMinor',250000,'expectedDealRevision',3),jsonb_build_object('id','99999999-0000-4000-8000-000000000002','quantity',1,'expectedPriceMinor',100000));
 r=pg_temp.place_deal(o,lines);
 if (r->>'totalMinor')::int<>350000 then raise exception 'Mixed total wrong';end if;
 if (select sum(quantity) from public.inventory_reservations where order_id=o and variant_id='99999999-0000-4000-8000-000000000002')<>4 then raise exception 'Mixed aggregation wrong';end if;
 if (select reserved from public.inventory_balances where variant_id='99999999-0000-4000-8000-000000000002')<>7 then raise exception 'Allocation counted twice';end if;
 begin perform public.adjust_inventory('99999999-0000-4000-8000-000000000002',-14,'Synthetic invalid count','deal-invalid-count');exception when others then failed=true;end;
 if not failed or (select on_hand from public.inventory_balances where variant_id='99999999-0000-4000-8000-000000000002')<>20 then raise exception 'Count below pooled/order reserved stock accepted';end if;
 perform pg_temp.place_deal(o,lines);
 if (select count(*) from public.inventory_reservations where order_id=o)<>2 then raise exception 'Retry duplicated reserves';end if;
 perform public.admin_order_action(o,1,'cancel',gen_random_uuid());
 if (select reserved from public.inventory_balances where variant_id='99999999-0000-4000-8000-000000000002')<>6 then raise exception 'Cancellation did not return only own allocation';end if;
 raise notice 'PASS: mixed aggregation, authoritative total, pool transfer once, idempotency and cancellation return';
 o=gen_random_uuid();r=pg_temp.place_deal(o,lines);
 update app_private.commerce_orders set hold_expires_at=now()-interval '1 second' where order_id=o;update public.inventory_reservations set expires_at=now()-interval '1 second' where order_id=o;perform public.expire_commerce_holds();
 r=public.review_manual_payment(o,2,'verify',gen_random_uuid(),'{"checkedHistory":true,"amountMinor":350000,"reference":"SYNTHETIC-DEAL-LATE","reacquire":true}');
 if r->>'paymentStatus'<>'paid' then raise exception 'Late deal reallocation failed';end if;
 perform public.save_deal('17171717-0000-4000-8000-000000000001',3,gen_random_uuid(),'hide',pg_temp.deal_data());
 if exists(select 1 from app_private.deal_pools where deal_id='17171717-0000-4000-8000-000000000001') then raise exception 'Hide did not release idle';end if;
 r=public.admin_order_action(o,(r->>'revision')::int,'confirm',gen_random_uuid());r=public.admin_order_action(o,(r->>'revision')::int,'dispatch',gen_random_uuid());r=public.admin_order_action(o,(r->>'revision')::int,'complete',gen_random_uuid());
 if (select on_hand from public.inventory_balances where variant_id='99999999-0000-4000-8000-000000000002')<>16 or (select on_hand from public.inventory_balances where variant_id='99999999-0000-4000-8000-000000000003')<>9 then raise exception 'Snapshot dispatch double/wrong consumption';end if;
 if public.deal_is_public('17171717-0000-4000-8000-000000000001') then raise exception 'Hidden deal exposed';end if;
 if (public.commerce_reconciliation()->>'balanceMismatches')::int<>0 then raise exception 'Counters mismatch';end if;
 raise notice 'PASS: expiry returns own pool, late payment reacquires atomically; hiding preserves snapshots; dispatch/completion once';
end $test$;
-- Independent savepoint cases all roll back, retaining the fixture above.
savepoint more;
select public.save_deal('17171717-0000-4000-8000-000000000001',4,gen_random_uuid(),'publish',pg_temp.deal_data());
do $checks$ declare o uuid=gen_random_uuid();lines jsonb;before_count int;failed boolean=false;r jsonb;begin
 lines=jsonb_build_array(jsonb_build_object('id','17171717-0000-4000-8000-000000000001','kind','deal','quantity',1,'expectedPriceMinor',250000,'expectedDealRevision',5));
 -- Price and composition expectations are mandatory and authoritative.
 begin perform pg_temp.place_deal(o,jsonb_set(lines,'{0,expectedPriceMinor}','1'));exception when others then failed=true;end;
 if not failed then raise exception 'Client price accepted';end if;failed=false;
 begin perform pg_temp.place_deal(o,jsonb_set(lines,'{0,expectedDealRevision}','4'));exception when others then failed=true;end;
 if not failed then raise exception 'Stale deal accepted';end if;failed=false;
 before_count=(select count(*) from public.orders);
 begin perform pg_temp.place_deal(o,jsonb_set(lines,'{0,quantity}','4')||jsonb_build_array(jsonb_build_object('id','99999999-0000-4000-8000-000000000002','quantity',5,'expectedPriceMinor',100000)));exception when others then failed=true;end;
 if not failed or (select count(*) from public.orders)<>before_count then raise exception 'Mixed per-line valid/shared shortage did not roll back';end if;failed=false;
 -- A second deal shares a component: neither gets copied inventory.
 perform public.save_deal('17171717-0000-4000-8000-000000000003',0,gen_random_uuid(),'draft',pg_temp.deal_data()||'{"slug":"second-synthetic-deal","title":"Second synthetic deal"}');
 insert into public.deal_media(deal_id,media_id,position,is_primary) values('17171717-0000-4000-8000-000000000003','17171717-0000-4000-8000-000000000002',0,true);
 perform public.save_deal('17171717-0000-4000-8000-000000000003',2,gen_random_uuid(),'publish',pg_temp.deal_data()||'{"slug":"second-synthetic-deal","title":"Second synthetic deal","setAside":5}');
 if (app_private.deal_public_view('17171717-0000-4000-8000-000000000001')->>'available')::int<>0 then raise exception 'Other deal pool not excluded';end if;
 before_count=(select count(*) from public.orders);
 begin perform pg_temp.place_deal(o,lines);exception when others then failed=true;end;
 if not failed or (select count(*) from public.orders)<>before_count then raise exception 'Short order did not roll back';end if;
 perform public.save_deal('17171717-0000-4000-8000-000000000003',3,gen_random_uuid(),'hide',pg_temp.deal_data()||'{"slug":"second-synthetic-deal","title":"Second synthetic deal"}');
 r=pg_temp.place_deal(o,lines);
 if exists(select 1 from public.order_items i where i.order_id=o and i.line_total_minor<>(select sum(attributed_minor) from app_private.order_component_snapshots where order_item_id=i.id)) then raise exception 'Paisa allocation not exact';end if;
 failed=false;begin perform public.admin_order_action(o,1,'confirm',gen_random_uuid());exception when others then failed=true;end;if not failed then raise exception 'Unpaid confirmation allowed';end if;
 -- Edit composition/price after placement, then release/reacquire/dispatch original snapshot.
 perform public.save_deal('17171717-0000-4000-8000-000000000001',5,gen_random_uuid(),'save',pg_temp.deal_data()||'{"priceMinor":12345,"components":[{"id":"99999999-0000-4000-8000-000000000003","quantity":2}]}');
 if (select sum(s.quantity) from app_private.order_component_snapshots s join public.order_items i on i.id=s.order_item_id where i.order_id=o)<>4 then raise exception 'Deal edit changed snapshot';end if;
 update app_private.commerce_orders set hold_expires_at=now()-interval '1 second' where order_id=o;update public.inventory_reservations set expires_at=now()-interval '1 second' where order_id=o;perform public.expire_commerce_holds();
 -- Consume general free red stock to force a late payment resolution, not a false refund.
 perform public.adjust_inventory('99999999-0000-4000-8000-000000000002',-16,'Synthetic shortage','synthetic-deal-shortage');
 r=public.review_manual_payment(o,2,'verify',gen_random_uuid(),'{"checkedHistory":true,"amountMinor":250000,"reference":"SYNTHETIC-DEAL-NO-STOCK","reacquire":true}');
 if r->>'paymentStatus'<>'received_resolution_required' or (r->'manualPayment'->>'receivedMinor')::int<>250000 then raise exception 'Late funds lost or unavailable stock fulfilled';end if;
 if exists(select 1 from public.inventory_reservations where order_id=o and state='active') then raise exception 'Partial reacquisition leaked';end if;
 raise notice 'PASS: sibling deals share stock; stale price/revision, rollback, unpaid denial, immutable snapshots and late receipt without stock';
end $checks$;
rollback to more;
savepoint edit_dispatch;
do $$ declare o uuid=gen_random_uuid();r jsonb;begin
 perform public.save_deal('17171717-0000-4000-8000-000000000001',4,gen_random_uuid(),'publish',pg_temp.deal_data());
 r=pg_temp.place_deal(o,'[{"id":"17171717-0000-4000-8000-000000000001","kind":"deal","quantity":1,"expectedPriceMinor":250000,"expectedDealRevision":5}]');
 perform public.save_deal('17171717-0000-4000-8000-000000000001',5,gen_random_uuid(),'save',pg_temp.deal_data()||'{"priceMinor":12345,"components":[{"id":"99999999-0000-4000-8000-000000000003","quantity":2}]}');
 r=public.review_manual_payment(o,1,'verify',gen_random_uuid(),'{"checkedHistory":true,"amountMinor":250000,"reference":"SYNTHETIC-EDIT-DISPATCH"}');
 r=public.admin_order_action(o,(r->>'revision')::int,'confirm',gen_random_uuid());r=public.admin_order_action(o,(r->>'revision')::int,'dispatch',gen_random_uuid());r=public.admin_order_action(o,(r->>'revision')::int,'complete',gen_random_uuid());
 if (select on_hand from public.inventory_balances where variant_id='99999999-0000-4000-8000-000000000002')<>13 or (select on_hand from public.inventory_balances where variant_id='99999999-0000-4000-8000-000000000003')<>8 or (r->>'totalMinor')::int<>250000 then raise exception 'Edited deal changed historical charge or dispatched composition';end if;
 raise notice 'PASS: composition and price edits after placement do not alter charged total or dispatch component deductions';
end $$;
rollback to edit_dispatch;
savepoint two_products;
insert into public.products(id,name) values('17171717-0000-4000-8000-000000000009','Second synthetic product');
insert into public.product_media(product_id,media_id,position,is_primary) values('17171717-0000-4000-8000-000000000009','99999999-0000-4000-8000-000000000005',0,true);
select public.save_daily_product('17171717-0000-4000-8000-000000000009',(select revision from public.products where id='17171717-0000-4000-8000-000000000009'),'{"name":"Second synthetic product","brand":"sf-fixture","category":"sf-fixture","productType":"cleanser","description":"Synthetic SQL fixture only","featured":false,"options":[{"id":"17171717-0000-4000-8000-000000000010","sku":"SYNTHETIC-SECOND","label":"Normal","priceMinor":90000,"stock":4,"expectedStock":0,"countChanged":true}]}',gen_random_uuid(),'publish');
do $$ declare data jsonb;o uuid=gen_random_uuid();begin
 data=pg_temp.deal_data()||'{"title":"Two different products","slug":"two-different-products","components":[{"id":"99999999-0000-4000-8000-000000000002","quantity":1},{"id":"17171717-0000-4000-8000-000000000010","quantity":2}]}';
 perform public.save_deal('17171717-0000-4000-8000-000000000004',0,gen_random_uuid(),'draft',data);
 insert into public.deal_media(deal_id,media_id,position,is_primary) values('17171717-0000-4000-8000-000000000004','17171717-0000-4000-8000-000000000002',0,true);
 perform public.save_deal('17171717-0000-4000-8000-000000000004',2,gen_random_uuid(),'publish',data);
 if (app_private.deal_public_view('17171717-0000-4000-8000-000000000004')->>'available')::int<>2 then raise exception 'Cross-product floor availability wrong';end if;
 perform pg_temp.place_deal(o,'[{"id":"17171717-0000-4000-8000-000000000004","kind":"deal","quantity":2,"expectedPriceMinor":250000,"expectedDealRevision":3}]');
 if (select sum(quantity) from public.inventory_reservations where order_id=o)<>6 or (select count(distinct product_name) from app_private.order_component_snapshots s join public.order_items i on i.id=s.order_item_id where i.order_id=o)<>2 then raise exception 'Different products not snapshotted/reserved correctly';end if;
 if not exists(select 1 from jsonb_array_elements(public.admin_payment_orders('SYNTHETIC-SECOND')->'rows') x where x->>'id'=o::text) then raise exception 'Deal component snapshot SKU not searchable in orders';end if;
 perform public.admin_order_action(o,1,'cancel',gen_random_uuid());
 raise notice 'PASS: two different products, quantity greater than one, floor availability and exact component snapshots';
end $$;
rollback to two_products;
savepoint media_test;
do $media$ declare mid uuid=gen_random_uuid();replacement uuid=gen_random_uuid();association uuid;metadata jsonb;failed boolean=false;begin
 perform public.create_deal_upload(mid,'17171717-0000-4000-8000-000000000001','development','mock',repeat('d',64),123,'Synthetic private deal image');
 perform public.media_workflow_action(mid,'private_uploaded');
 if public.media_is_public(mid) then raise exception 'Pending image public';end if;
 begin perform public.media_workflow_action(mid,'begin_publish');exception when others then failed=true;end;if not failed then raise exception 'Unapproved publication allowed';end if;
 perform public.media_workflow_action(mid,'approve');perform public.media_workflow_action(mid,'begin_publish');
 metadata=jsonb_build_object('public_id','nook-glow/development/'||mid,'asset_id','synthetic-deal-asset','version',1,'resource_type','image','type','upload','format','png','width',1,'height',1,'bytes',123,'sha256',repeat('d',64));
 perform public.media_workflow_action(mid,'complete',metadata);perform public.media_workflow_action(mid,'complete',metadata);
 select id into association from public.deal_media where media_id=mid;
 perform public.create_deal_upload(replacement,'17171717-0000-4000-8000-000000000001','development','mock',repeat('e',64),123,'Synthetic replacement',association);
 perform public.media_workflow_action(replacement,'private_uploaded');perform public.media_workflow_action(replacement,'approve');perform public.media_workflow_action(replacement,'begin_publish');
 metadata=metadata||jsonb_build_object('public_id','nook-glow/development/'||replacement,'asset_id','synthetic-replacement','sha256',repeat('e',64));perform public.media_workflow_action(replacement,'complete',metadata);
 if (select media_id from public.deal_media where id=association)<>replacement or (select lifecycle from public.media_assets where id=mid)<>'retired' then raise exception 'Replacement association wrong';end if;
 failed=false;begin perform public.media_workflow_action(replacement,'claim_cleanup');exception when others then failed=true;end;if not failed then raise exception 'Referenced image deleted';end if;
 raise notice 'PASS: own deal media, private review, explicit approval, duplicate completion, replacement, referenced cleanup denial (provider metadata double)';
end $media$;
rollback to media_test;
savepoint dates;
do $$ declare failed boolean=false;begin
 perform public.save_deal('17171717-0000-4000-8000-000000000001',4,gen_random_uuid(),'publish',pg_temp.deal_data()||jsonb_build_object('setAside',1,'startsAt',now()+interval '1 hour','endsAt',now()+interval '2 hours'));
 if public.deal_is_public('17171717-0000-4000-8000-000000000001') or not exists(select 1 from app_private.deal_pools where deal_id='17171717-0000-4000-8000-000000000001') then raise exception 'Future allocation or visibility wrong';end if;
 begin perform public.save_deal('17171717-0000-4000-8000-000000000001',5,gen_random_uuid(),'save',pg_temp.deal_data()||'{"components":[]}');exception when others then failed=true;end;
 if not failed or (select status from public.deals where id='17171717-0000-4000-8000-000000000001')<>'published' then raise exception 'Invalid published edit did not roll back';end if;
 -- Clock simulation only in the disposable fixture, not a live API bypass.
 update public.deals set starts_at=now()-interval '2 hours',ends_at=now()-interval '1 hour' where id='17171717-0000-4000-8000-000000000001';
 perform public.expire_deal_allocations();perform public.expire_deal_allocations();
 if exists(select 1 from app_private.deal_pools where deal_id='17171717-0000-4000-8000-000000000001') or (select reserved from public.inventory_balances where variant_id='99999999-0000-4000-8000-000000000002')<>0 then raise exception 'Ended deal allocation release failed';end if;
 raise notice 'PASS: future start private, bounded end release idempotent, invalid published edit rolls back';
end $$;
rollback to dates;
set local role anon;
do $$ declare failed boolean=false;begin
 if (public.storefront_deals()->>'total')::int<>0 then raise exception 'Hidden deal public';end if;
 begin perform public.admin_deals();exception when insufficient_privilege then failed=true;end;if not failed then raise exception 'Anon admin allowed';end if;
 failed=false;begin perform 1 from app_private.deal_pools;exception when insufficient_privilege then failed=true;end;if not failed then raise exception 'Private pools exposed';end if;
end $$;
reset role;
set local role authenticated;set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $$ declare failed boolean=false;begin
 begin perform public.admin_deals();exception when others then failed=true;end;if not failed then raise exception 'Nonadmin admin allowed';end if;
 failed=false;begin insert into public.deals(name) values('unauthorized');exception when insufficient_privilege then failed=true;end;if not failed then raise exception 'Native deal writes bypassed workflow';end if;
 raise notice 'PASS: anonymous and non-admin private reads/writes denied; hidden projection isolated';
end $$;
rollback;
