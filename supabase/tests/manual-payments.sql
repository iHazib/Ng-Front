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

create function pg_temp.place_fixture(oid uuid, refscope text default repeat('c',64)) returns jsonb language sql as $$
select public.place_guest_order(oid,repeat('a',64),repeat('b',64),'[{"id":"99999999-0000-4000-8000-000000000002","quantity":1,"expectedPriceMinor":100000}]',
'{"name":"Synthetic Guest","phone":"+923001234567","address":"Synthetic address","city":"Test City"}',
'{"id":"test","label":"Synthetic delivery","feeMinor":0}',
jsonb_build_object('id','bank-transfer','label','Synthetic bank','allocation','temporary','accountScope',refscope,'accountTitle','Synthetic only','destination','TEST ONLY'),
'{"mode":"development","version":"sql-payment-test","paymentSeconds":60,"reviewExtensionSeconds":60}');$$;
create function pg_temp.verify(oid uuid,ref text,amount bigint,reacquire boolean default false,op uuid default gen_random_uuid()) returns jsonb language sql as $$
select public.review_manual_payment(oid,(select revision from app_private.commerce_orders where order_id=oid),'verify',op,jsonb_build_object('checkedHistory',true,'amountMinor',amount,'reference',ref,'reacquire',reacquire));$$;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
do $test$ declare o uuid=gen_random_uuid();o2 uuid=gen_random_uuid();o3 uuid=gen_random_uuid();r jsonb;k uuid=gen_random_uuid();deadline timestamptz;begin
r=pg_temp.place_fixture(o);
if r->>'paymentStatus'<>'awaiting_payment' then raise exception 'Must await payment';end if;
if pg_temp.place_fixture(o)->>'id'<>o::text then raise exception 'Retry failed';end if;
begin perform public.admin_order_action(o,1,'confirm',gen_random_uuid());raise exception 'Unpaid confirmed';exception when raise_exception then if sqlerrm='Unpaid confirmed' then raise;end if;end;
raise notice 'PASS: advance-only placement, retry and unpaid fulfilment rejection';
r=public.submit_manual_payment(o,repeat('a',64),repeat('b',64),k,'TEST-REF-1',100000,null);
if r->>'paymentStatus'<>'under_review' then raise exception 'Submission marked paid';end if;
select hold_expires_at into deadline from app_private.commerce_orders where order_id=o;
perform public.submit_manual_payment(o,repeat('a',64),repeat('b',64),gen_random_uuid(),'TEST-REF-1',100000,null);
if deadline is distinct from (select hold_expires_at from app_private.commerce_orders where order_id=o) then raise exception 'Repeated extension';end if;
raise notice 'PASS: submission under review; bounded non-renewable deadline';
begin perform public.submit_manual_payment(o,repeat('d',64),repeat('b',64),gen_random_uuid(),'BAD',null,null);raise exception 'Wrong guest accepted';exception when sqlstate 'P0404' then null;end;
begin perform public.review_manual_payment(o,1,'verify',gen_random_uuid(),'{"checkedHistory":true,"amountMinor":100000,"reference":"TEST-REF-1"}');raise exception 'Stale accepted';exception when raise_exception then if sqlerrm='Stale accepted' then raise;end if;end;
r=pg_temp.verify(o,'TEST-REF-1',50000);
if r->>'paymentStatus'<>'needs_attention' or (r#>>'{manualPayment,receivedMinor}')::bigint<>50000 then raise exception 'Partial amount not recorded';end if;
r=pg_temp.verify(o,'TEST-REF-2',50000);
if r->>'paymentStatus'<>'paid' then raise exception 'Full receipt not paid';end if;
perform pg_temp.verify(o,'TEST-REF-2',50000);
if (select count(*) from app_private.payment_receipts where order_id=o)<>2 then raise exception 'Duplicate receipt';end if;
r=public.admin_order_action(o,(r->>'revision')::int+1,'confirm',gen_random_uuid());
r=public.admin_order_action(o,(r->>'revision')::int,'dispatch',gen_random_uuid());
r=public.admin_order_action(o,(r->>'revision')::int,'complete',gen_random_uuid());
if (select on_hand<>2 or reserved<>0 from public.inventory_balances where variant_id='99999999-0000-4000-8000-000000000002') then raise exception 'Consumption incorrect';end if;
raise notice 'PASS: actual full receipt required; partial and duplicate receipts; dispatch once/completion no extra stock';
r=pg_temp.place_fixture(o2);r=pg_temp.verify(o2,'TEST REF 1',50000);
if r->>'paymentStatus'<>'needs_attention' or exists(select 1 from app_private.payment_receipts where order_id=o2) then raise exception 'Transfer credited twice';end if;
raise notice 'PASS: normalized receiving-account scoped reference cannot be credited twice';
update app_private.commerce_orders set hold_expires_at=now()-interval '1 second' where order_id=o2;
update public.inventory_reservations set expires_at=now()-interval '1 second' where order_id=o2;
perform public.expire_commerce_holds();perform public.expire_commerce_holds();
if (select reserved<>0 from public.inventory_balances where variant_id='99999999-0000-4000-8000-000000000002') then raise exception 'Expiry release failed';end if;
r=pg_temp.verify(o2,'LATE-1',100000,false);
if r->>'paymentStatus'<>'received_resolution_required' then raise exception 'Late funds not recorded separately';end if;
r=pg_temp.place_fixture(o3);
-- Consume remaining unreserved unit through audited stock reconciliation analogue in disposable fixture.
update public.inventory_balances set on_hand=reserved where variant_id='99999999-0000-4000-8000-000000000002';
r=pg_temp.verify(o2,'LATE-1',100000,true);
if r->>'paymentStatus'<>'received_resolution_required' or (select count(*) from app_private.payment_receipts where order_id=o2)<>1 then raise exception 'Late stock shortage duplicated funds or fulfilled';end if;
update public.inventory_balances set on_hand=reserved+1 where variant_id='99999999-0000-4000-8000-000000000002';
r=pg_temp.verify(o2,'LATE-1',100000,true);
if r->>'paymentStatus'<>'paid' then raise exception 'Explicit late stock reacquisition failed';end if;
raise notice 'PASS: expiry idempotency; late receipt retained on shortage; explicit atomic reacquisition';
r=public.review_manual_payment(o3,(select revision from app_private.commerce_orders where order_id=o3),'correction',gen_random_uuid(),'{"message":"Please check the reference"}');
r=public.review_manual_payment(o3,(r->>'revision')::int,'reject',gen_random_uuid(),'{"message":"No funds found in account history"}');
if r->>'fulfilment'<>'cancelled' then raise exception 'Reject did not release';end if;
raise notice 'PASS: request correction and reject submission preserve history and release unpaid allocation';
end $test$;
do $proof$ declare o uuid=gen_random_uuid();o2 uuid=gen_random_uuid();o3 uuid=gen_random_uuid();m uuid=gen_random_uuid();m2 uuid=gen_random_uuid();r jsonb;k uuid=gen_random_uuid();rev integer;begin
-- Replenishment belongs only to this rolled-back disposable synthetic fixture.
update public.inventory_balances set on_hand=reserved+5 where variant_id='99999999-0000-4000-8000-000000000002';
perform pg_temp.place_fixture(o);perform pg_temp.place_fixture(o2);perform pg_temp.place_fixture(o3,repeat('d',64));
perform public.payment_proof(o,repeat('a',64),repeat('b',64),m,'create',jsonb_build_object('environment','development','hash',repeat('f',64),'bytes',100));
begin perform public.submit_manual_payment(o,repeat('a',64),repeat('b',64),gen_random_uuid(),'PRIVATE-1',100000,m);raise exception 'Incomplete image submitted';exception when raise_exception then if sqlerrm='Incomplete image submitted' then raise;end if;end;
perform public.payment_proof(o,repeat('a',64),repeat('b',64),m,'complete');
perform public.payment_proof(o2,repeat('a',64),repeat('b',64),m2,'create',jsonb_build_object('environment','development','hash',repeat('f',64),'bytes',100));perform public.payment_proof(o2,repeat('a',64),repeat('b',64),m2,'complete');
perform public.submit_manual_payment(o,repeat('a',64),repeat('b',64),gen_random_uuid(),'PRIVATE-1',90000,m);
r=public.submit_manual_payment(o2,repeat('a',64),repeat('b',64),gen_random_uuid(),'PRIVATE-1',100000,m2);
if jsonb_array_length(r#>'{manualPayment,flags}')<2 then raise exception 'Image/reference flags missing';end if;
if not 'Amount does not match order total'=any(app_private.payment_flags(o)) then raise exception 'Mismatch flag missing';end if;
begin perform public.payment_proof(o2,repeat('a',64),repeat('b',64),m,'read');raise exception 'Cross-order proof read';exception when sqlstate 'P0404' then null;end;
begin perform public.media_workflow_action(m,'approve','{}');raise exception 'Proof publication accepted';exception when raise_exception then if sqlerrm='Proof publication accepted' then raise;end if;end;
begin update public.media_assets set lifecycle='approved_for_publish' where id=m;raise exception 'Private lifecycle bypass';exception when raise_exception then if sqlerrm='Private lifecycle bypass' then raise;end if;end;
begin insert into public.product_media(product_id,media_id,position,is_primary) values('99999999-0000-4000-8000-000000000001',m,5,false);raise exception 'Proof publicly associated';exception when raise_exception then if sqlerrm='Proof publicly associated' then raise;end if;end;
raise notice 'PASS: private proof ownership, incomplete upload rejection, identical-image/reference/amount flags; Cloudinary/public association denied';
r=pg_temp.verify(o,'ACCOUNT-SCOPED',100000);r=pg_temp.verify(o3,'ACCOUNT-SCOPED',100000);
if r->>'paymentStatus'<>'paid' then raise exception 'Different receiving account incorrectly blocked';end if;
raise notice 'PASS: same reference on different receiving account remains distinct';
select revision into rev from app_private.commerce_orders where order_id=o2;
r=public.review_manual_payment(o2,rev,'verify',k,'{"checkedHistory":true,"amountMinor":110000,"reference":"OVER-PAYMENT"}');
if r->>'paymentStatus'<>'needs_attention' or not 'Received amount exceeds order total'=any(app_private.payment_flags(o2)) then raise exception 'Overpayment not flagged';end if;
perform public.review_manual_payment(o2,rev,'verify',k,'{"checkedHistory":true,"amountMinor":110000,"reference":"OVER-PAYMENT"}');
if (select count(*) from app_private.payment_receipts where order_id=o2)<>1 then raise exception 'Operation duplicated';end if;
if (select count(*) from jsonb_array_elements(public.admin_payment_orders(p_queue=>'Needs attention')->'rows'))<1 then raise exception 'Queue filtering failed';end if;
raise notice 'PASS: overpayment requires attention, verification retry once and bounded payment queue';
end $proof$;
insert into storage.objects(bucket_id,name) select 'catalog-private',private_path from public.media_workflows where payment_order_id is not null;
set local role anon;
do $$ begin
 begin perform 1 from app_private.payment_receipts;raise exception 'Private receipts exposed';exception when insufficient_privilege then null;end;
 if exists(select 1 from storage.objects where bucket_id='catalog-private') then raise exception 'Private proof Storage exposed';end if;
 begin perform public.payment_proof(gen_random_uuid(),repeat('a',64),repeat('b',64),gen_random_uuid(),'read','{}');raise exception 'Client proof RPC exposed';exception when insufficient_privilege then null;end;
 begin perform public.review_manual_payment(gen_random_uuid(),1,'verify',gen_random_uuid(),'{}');raise exception 'Anonymous accepted';exception when insufficient_privilege then null;end;end $$;
reset role;set local role authenticated;set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $$ begin
 begin perform 1 from app_private.payment_receipts;raise exception 'Private receipts exposed';exception when insufficient_privilege then null;end;
 if exists(select 1 from storage.objects where bucket_id='catalog-private') then raise exception 'Private proof Storage exposed';end if;
 begin perform public.payment_proof(gen_random_uuid(),repeat('a',64),repeat('b',64),gen_random_uuid(),'read','{}');raise exception 'Client proof RPC exposed';exception when insufficient_privilege then null;end;
 begin perform public.review_manual_payment(gen_random_uuid(),1,'verify',gen_random_uuid(),'{}');raise exception 'Nonadmin accepted';exception when insufficient_privilege then null;end;end $$;
reset role;
rollback;
