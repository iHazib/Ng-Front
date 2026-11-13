\set ON_ERROR_STOP on
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
do $test$ declare oid uuid;item uuid;r uuid;r2 uuid;state jsonb;selection jsonb;before_sales bigint;begin
 before_sales=(select coalesce(sum(merchandise_minor),0) from app_private.completed_sales);
 oid=report_test.place();perform public.review_manual_payment(oid,(select revision from app_private.commerce_orders where order_id=oid),'verify',gen_random_uuid(),jsonb_build_object('checkedHistory',true,'amountMinor',30000,'reference','SYNTHETIC-PARTIAL-'||oid));perform report_test.step(oid,'cancel');
 item=(select id from public.order_items where order_id=oid);selection=jsonb_build_object('items',jsonb_build_array(jsonb_build_object('itemId',item,'variantId','15151515-0000-4000-8000-000000000002','quantity',0,'amountMinor',30000)),'shippingMinor',0,'overpaymentMinor',0);
 r=report_test.request(oid,selection);perform report_test.finance(oid,'approve',jsonb_build_object('refundId',r,'reason','Approve actual partial funds only'));perform report_test.ok((public.admin_order_finance(oid)->>'reservedMinor')::bigint=30000,'partial cancelled payment can reserve exactly actual funds');perform report_test.send(oid,r);
 state=public.admin_order_finance(oid);perform report_test.ok((state->>'availableMinor')::bigint=0 and (state->>'sentMinor')::bigint=30000,'partial cancelled balance fully refundable without whole-item charge');
 perform report_test.ok((select sum(merchandise_minor)=0 and sum(refunds_minor)=30000 from app_private.reporting_events() where order_id=oid),'partial cancelled refund affects cash only');
 perform report_test.denied(format('select report_test.request(%L::uuid,%L::jsonb)',oid,selection),'partial-value refund cannot over-refund received cash');
 perform report_test.ok((state->>'partialAmountsSupported')::boolean and (state->'items'->0->>'remainingAmountMinor')::bigint=70000,'remaining value and quantity are separate explicit entitlements');
 oid=report_test.place();perform public.review_manual_payment(oid,(select revision from app_private.commerce_orders where order_id=oid),'verify',gen_random_uuid(),jsonb_build_object('checkedHistory',true,'amountMinor',50000,'reference','SYNTHETIC-SPLIT-'||oid));perform report_test.step(oid,'cancel');item=(select id from public.order_items where order_id=oid);
 selection=jsonb_build_object('items',jsonb_build_array(jsonb_build_object('itemId',item,'variantId','15151515-0000-4000-8000-000000000002','quantity',1,'amountMinor',25000)),'shippingMinor',0,'overpaymentMinor',0);
 r=report_test.request(oid,selection);perform report_test.finance(oid,'approve',jsonb_build_object('refundId',r,'reason','First partial value with quantity'));perform report_test.send(oid,r);
 selection=jsonb_set(selection,'{items,0,quantity}','0');r2=report_test.request(oid,selection);perform report_test.finance(oid,'approve',jsonb_build_object('refundId',r2,'reason','Remaining received value without duplicate quantity'));perform report_test.send(oid,r2);
 state=public.admin_order_finance(oid);perform report_test.ok((state->>'sentMinor')::bigint=50000 and (state->'items'->0->>'remainingQuantity')::integer=0,'split values cannot count the same refunded quantity twice');
 perform report_test.denied(format('select report_test.request(%L::uuid,%L::jsonb)',oid,jsonb_set(selection,'{items,0,amountMinor}','999999')),'partial item value capped by its frozen allocation');
 perform report_test.denied(format('select report_test.request(%L::uuid,%L::jsonb)',oid,jsonb_set(selection,'{items,0,amountMinor}','-1')),'negative partial refund rejected');
 perform report_test.denied(format('select report_test.request(%L::uuid,%L::jsonb)',oid,jsonb_set(selection,'{items,0,amountMinor}','"1e3"')),'scientific partial refund input rejected');
 perform report_test.denied(format('select report_test.request(%L::uuid,%L::jsonb)',oid,(selection#-'{items,0,amountMinor}')),'zero quantity requires explicit positive value');
 perform report_test.ok((select coalesce(sum(merchandise_minor),0) from app_private.completed_sales)=before_sales,'partial cancelled refunds never create or rewrite completed sales');
end $test$;
