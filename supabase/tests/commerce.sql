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

create function pg_temp.place_fixture(oid uuid,lines jsonb,temporary boolean default false) returns jsonb language sql as $$
 select public.place_guest_order(oid,repeat('a',64),repeat('b',64),lines,
 '{"name":"Synthetic Guest","phone":"+923001234567","address":"Synthetic address only","city":"Test City","email":"","note":"Test"}',
 '{"id":"test-delivery","label":"Development delivery only","feeMinor":12345}',
 jsonb_build_object('id',case when temporary then 'test-hold' else 'test-cod' end,'label','Development only','allocation',case when temporary then 'temporary' else 'accepted' end),
 '{"mode":"development","version":"sql-test","taxTreatment":"development-no-additional-tax"}');
$$;

do $test$ declare r jsonb;oid uuid='15151515-0000-4000-8000-000000000011';lines jsonb='[{"id":"99999999-0000-4000-8000-000000000002","quantity":1,"expectedPriceMinor":100000}]';begin
 r=public.commerce_quote(lines);if not (r->>'valid')::boolean or (r->>'subtotal_minor')::int<>100000 then raise exception 'Quote failed';end if;
 if (select reserved from public.inventory_balances where variant_id='99999999-0000-4000-8000-000000000002')<>0 then raise exception 'Cart reserved stock';end if;
 raise notice 'PASS: server quote computes actual minor units without reserving';
 begin perform pg_temp.place_fixture(oid,'[{"id":"99999999-0000-4000-8000-000000000002","quantity":1,"expectedPriceMinor":1}]');raise exception 'Expected stale rejection';exception when raise_exception then if sqlerrm='Expected stale rejection' then raise;end if;end;
 begin perform pg_temp.place_fixture(oid,'[{"id":"99999999-0000-4000-8000-000000000002","quantity":1,"expectedPriceMinor":100000},{"id":"99999999-0000-4000-8000-000000000003","quantity":1,"expectedPriceMinor":200000}]');raise exception 'Expected rollback';exception when raise_exception then if sqlerrm='Expected rollback' then raise;end if;end;
 if exists(select 1 from public.orders where id=oid) or exists(select 1 from public.inventory_reservations where order_id=oid) then raise exception 'Failed placement leaked rows';end if;
 raise notice 'PASS: stale prices and multi-item unavailable order roll back completely';
 r=pg_temp.place_fixture(oid,lines);
 if (r->>'totalMinor')::int<>112345 or r->>'paymentStatus'<>'due_on_delivery' then raise exception 'Snapshot total/payment failed';end if;
 if (select reserved from public.inventory_balances where variant_id='99999999-0000-4000-8000-000000000002')<>1 then raise exception 'Reservation failed';end if;
 if pg_temp.place_fixture(oid,lines)->>'id'<>oid::text or (select count(*) from public.inventory_reservations where order_id=oid)<>1 then raise exception 'Retry duplicated';end if;
 begin perform pg_temp.place_fixture(oid,'[{"id":"99999999-0000-4000-8000-000000000002","quantity":2,"expectedPriceMinor":100000}]');raise exception 'Expected conflict';exception when raise_exception then if sqlerrm='Expected conflict' then raise;end if;end;
 raise notice 'PASS: placement snapshots prices/customer/shipping; identical retry once; altered retry denied';
 begin perform public.finish_reservation(oid,true);raise exception 'Managed primitive bypass';exception when raise_exception then if sqlerrm='Managed primitive bypass' then raise;end if;end;
 raise notice 'PASS: legacy public primitive cannot bypass managed-order safeguards';
 begin perform public.guest_order_confirmation(oid,repeat('c',64),repeat('b',64));raise exception 'Ownership leak';exception when sqlstate 'P0404' then null;end;
 if public.guest_order_confirmation(oid,repeat('a',64),repeat('b',64))->>'id'<>oid::text then raise exception 'Guest ownership failure';end if;
 raise notice 'PASS: secure guest confirmation requires matching session and token';
 perform public.admin_order_action(oid,1,'confirm','15151515-0000-4000-8000-000000000021');
 begin perform public.admin_order_action(oid,1,'cancel',gen_random_uuid());raise exception 'Stale accepted';exception when raise_exception then if sqlerrm='Stale accepted' then raise;end if;end;
 perform public.admin_order_action(oid,2,'cancel','15151515-0000-4000-8000-000000000022');
 perform public.admin_order_action(oid,2,'cancel','15151515-0000-4000-8000-000000000022');
 if (select on_hand<>3 or reserved<>0 from public.inventory_balances where variant_id='99999999-0000-4000-8000-000000000002') then raise exception 'Release duplicated';end if;
 raise notice 'PASS: audited stale transitions rejected; cancellation retries release once';
 oid='15151515-0000-4000-8000-000000000012';r=pg_temp.place_fixture(oid,lines);
 perform public.admin_order_action(oid,1,'confirm','15151515-0000-4000-8000-000000000023');
 -- Corruption injections exist only in this disposable rolled-back transaction.
 delete from public.inventory_reservations where order_id=oid;
 begin perform public.admin_order_action(oid,2,'cancel',gen_random_uuid());raise exception 'Missing reservation allowed cancellation';exception when raise_exception then if sqlerrm='Missing reservation allowed cancellation' then raise;end if;end;
 begin perform public.admin_order_action(oid,2,'dispatch',gen_random_uuid());raise exception 'Missing reservation allowed dispatch';exception when raise_exception then if sqlerrm='Missing reservation allowed dispatch' then raise;end if;end;
 insert into public.inventory_reservations(order_id,variant_id,quantity,expires_at,idempotency_key) values(oid,'99999999-0000-4000-8000-000000000002',1,'infinity',oid::text||':99999999-0000-4000-8000-000000000002');
 update public.inventory_reservations set quantity=2 where order_id=oid;
 begin perform public.admin_order_action(oid,2,'dispatch',gen_random_uuid());raise exception 'Partial reservation allowed dispatch';exception when raise_exception then if sqlerrm='Partial reservation allowed dispatch' then raise;end if;end;
 update public.inventory_reservations set quantity=1 where order_id=oid;
 update public.inventory_reservations set state='released' where order_id=oid;
 begin perform public.admin_order_action(oid,2,'dispatch',gen_random_uuid());raise exception 'Inactive reservation allowed dispatch';exception when raise_exception then if sqlerrm='Inactive reservation allowed dispatch' then raise;end if;end;
 update public.inventory_reservations set state='active' where order_id=oid;
 delete from public.order_item_components where order_item_id in(select id from public.order_items where order_id=oid);
 begin perform public.admin_order_action(oid,2,'dispatch',gen_random_uuid());raise exception 'Missing components allowed dispatch';exception when raise_exception then if sqlerrm='Missing components allowed dispatch' then raise;end if;end;
 insert into public.order_item_components(order_item_id,variant_id,quantity) select id,variant_id,quantity from public.order_items where order_id=oid;
 update public.inventory_balances set reserved=0 where variant_id='99999999-0000-4000-8000-000000000002';
 begin perform public.admin_order_action(oid,2,'dispatch',gen_random_uuid());raise exception 'Counter mismatch allowed dispatch';exception when raise_exception then if sqlerrm='Counter mismatch allowed dispatch' then raise;end if;end;
 update public.inventory_balances set reserved=1 where variant_id='99999999-0000-4000-8000-000000000002';
 update public.inventory_reservations set expires_at=now()+interval '1 day' where order_id=oid;
 begin perform public.admin_order_action(oid,2,'dispatch',gen_random_uuid());raise exception 'Finite accepted hold allowed dispatch';exception when raise_exception then if sqlerrm='Finite accepted hold allowed dispatch' then raise;end if;end;
 update public.inventory_reservations set expires_at='infinity' where order_id=oid;
 if app_private.commerce_view(oid)->>'fulfilment'<>'confirmed' or exists(select 1 from public.inventory_movements where order_id=oid) then raise exception 'Invalid dispatch had side effects';end if;
 raise notice 'PASS: missing/partial/inactive reservations, missing components, stock counter mismatch and finite accepted holds block dispatch atomically';
 perform public.admin_order_action(oid,2,'dispatch','15151515-0000-4000-8000-000000000024');
 perform public.admin_order_action(oid,2,'dispatch','15151515-0000-4000-8000-000000000024');
 perform public.admin_order_action(oid,3,'complete','15151515-0000-4000-8000-000000000025');
 if (select on_hand<>2 or reserved<>0 from public.inventory_balances where variant_id='99999999-0000-4000-8000-000000000002') then raise exception 'Deduction failed';end if;
 if (select count(*) from public.inventory_movements where public.inventory_movements.order_id='15151515-0000-4000-8000-000000000012')<>1 then raise exception 'Double consumption';end if;
 if app_private.commerce_view(oid)->>'paymentStatus'<>'due_on_delivery' or exists(select 1 from public.sales where public.sales.order_id='15151515-0000-4000-8000-000000000012') then raise exception 'Fabricated remittance';end if;
 raise notice 'PASS: dispatch consumes once, completion deducts nothing and does not claim COD remittance';
 update public.products set name='Changed catalog name' where id='99999999-0000-4000-8000-000000000001';
 update public.variant_prices set amount_minor=123000 where variant_id='99999999-0000-4000-8000-000000000002';
 if app_private.commerce_view(oid)->'items'->0->>'name' like 'Changed%' or (app_private.commerce_view(oid)->>'subtotalMinor')::int<>100000 then raise exception 'Historical snapshots rewritten';end if;
 update public.variant_prices set amount_minor=100000 where variant_id='99999999-0000-4000-8000-000000000002';
 raise notice 'PASS: later catalog edits do not rewrite order snapshots';
 oid='15151515-0000-4000-8000-000000000013';perform pg_temp.place_fixture(oid,lines,true);
 begin perform public.admin_order_action(oid,1,'confirm',gen_random_uuid());raise exception 'Unpaid confirm allowed';exception when raise_exception then if sqlerrm='Unpaid confirm allowed' then raise;end if;end;
 update app_private.commerce_orders set fulfilment='confirmed',allocation='accepted',hold_expires_at=null where order_id=oid;
 update public.inventory_reservations set expires_at='infinity' where order_id=oid;
 begin perform public.admin_order_action(oid,1,'dispatch',gen_random_uuid());raise exception 'Unpaid dispatch allowed';exception when raise_exception then if sqlerrm='Unpaid dispatch allowed' then raise;end if;end;
 update app_private.commerce_orders set fulfilment='placed',allocation='temporary',hold_expires_at=now()+interval '20 minutes' where order_id=oid;
 update public.inventory_reservations set expires_at=now()+interval '20 minutes' where order_id=oid;
 if exists(select 1 from public.inventory_movements where order_id=oid) or app_private.commerce_view(oid)->>'paymentStatus'<>'awaiting_payment' then raise exception 'Unpaid action mutated payment/stock';end if;
 raise notice 'PASS: unpaid hold cannot confirm or dispatch, even with injected confirmed/accepted state; no payment claim or consumption';

 update app_private.commerce_orders set hold_expires_at=now()-interval '1 second' where app_private.commerce_orders.order_id='15151515-0000-4000-8000-000000000013';
 update public.inventory_reservations set expires_at=now()-interval '1 second' where public.inventory_reservations.order_id='15151515-0000-4000-8000-000000000013';
 update public.inventory_reservations set quantity=2 where order_id=oid;
 begin perform public.expire_commerce_holds();raise exception 'Partial expiry allowed';exception when raise_exception then if sqlerrm='Partial expiry allowed' then raise;end if;end;
 if app_private.commerce_view(oid)->>'fulfilment'<>'placed' or (select reserved from public.inventory_balances where variant_id='99999999-0000-4000-8000-000000000002')<>1 then raise exception 'Failed expiry changed state';end if;
 update public.inventory_reservations set quantity=1 where order_id=oid;
 raise notice 'PASS: expiry refuses partial allocations without silently releasing or repairing counters';
 if public.expire_commerce_holds()<>1 or public.expire_commerce_holds()<>0 then raise exception 'Expiry repeat failed';end if;
 if (select on_hand<>2 or reserved<>0 from public.inventory_balances where variant_id='99999999-0000-4000-8000-000000000002') then raise exception 'Expiry stock wrong';end if;
 oid='15151515-0000-4000-8000-000000000014';perform pg_temp.place_fixture(oid,lines);
 if public.expire_commerce_holds()<>0 or exists(select 1 from public.inventory_reservations where public.inventory_reservations.order_id='15151515-0000-4000-8000-000000000014' and expires_at<>'infinity') then raise exception 'Accepted COD expiration';end if;
 begin perform public.adjust_inventory('99999999-0000-4000-8000-000000000002',-2,'invalid reserved count',gen_random_uuid()::text);raise exception 'Stock below held accepted';exception when raise_exception then if sqlerrm='Stock below held accepted' then raise;end if;end;
 perform public.admin_order_action(oid,1,'cancel',gen_random_uuid());
 if public.commerce_reconciliation()->>'balanceMismatches'<>'0' then raise exception 'Reconciliation mismatch';end if;
 raise notice 'PASS: temporary expiry releases once; accepted COD retained; counts cannot fall below allocations';
 if (public.admin_orders('', 'completed')->>'total')::int<>1 then raise exception 'Admin status search failed';end if;
 raise notice 'PASS: private admin bounded order listing and status filters';
 oid='15151515-0000-4000-8000-000000000015';perform pg_temp.place_fixture(oid,lines,true);
 update app_private.commerce_orders set hold_expires_at=now()-interval '1 second' where order_id=oid;
 update public.inventory_reservations set expires_at=now()-interval '1 second' where order_id=oid;
 perform public.admin_order_action(oid,1,'cancel','15151515-0000-4000-8000-000000000026');
 perform public.admin_order_action(oid,1,'cancel','15151515-0000-4000-8000-000000000026');
 if public.expire_commerce_holds()<>0 or (select reserved from public.inventory_balances where variant_id='99999999-0000-4000-8000-000000000002')<>0 then raise exception 'Expired cancellation race release failed';end if;
 raise notice 'PASS: cancellation after deadline releases once; subsequent expiry cannot release again';

end $test$;
set local role anon;
do $deny$ begin
 begin perform public.place_guest_order(gen_random_uuid(),'', '', '[]','{}','{}','{}','{}');raise exception 'Guest bypass';exception when insufficient_privilege then null;end;
 begin perform public.admin_orders();raise exception 'Public orders';exception when insufficient_privilege then null;end;
 begin perform 1 from app_private.commerce_orders;raise exception 'Private metadata';exception when insufficient_privilege then null;end;
 begin if exists(select 1 from public.orders) then raise exception 'Anonymous customer leak';end if;exception when insufficient_privilege then null;end;
 raise notice 'PASS: anonymous direct placement/admin/customer/private access denied';
end $deny$;
set local role authenticated;set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $deny$ begin
 begin perform public.admin_orders();raise exception 'Nonadmin orders';exception when insufficient_privilege then null;end;
 begin perform public.admin_order_action('15151515-0000-4000-8000-000000000012',1,'confirm',gen_random_uuid());raise exception 'Nonadmin transition';exception when insufficient_privilege then null;end;
 if exists(select 1 from public.orders) then raise exception 'Nonadmin order leak';end if;
 raise notice 'PASS: nonadmin order reads and actions denied';
end $deny$;
rollback;
