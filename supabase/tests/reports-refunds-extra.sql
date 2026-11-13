\set ON_ERROR_STOP on
set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
do $extra$ declare oid uuid;r uuid;r2 uuid;u uuid;item uuid;op uuid;rev integer;stock integer;baseline jsonb;payload jsonb;out jsonb;stamp timestamptz;begin
 oid=report_test.place();perform report_test.pay(oid,5000);
 perform report_test.ok((select payment_status='needs_attention' from app_private.commerce_orders where order_id=oid),'overpayment still needs explicit resolution');
 r=report_test.request(oid,report_test.selection(oid,false,0,0,5000));perform report_test.finance(oid,'approve',jsonb_build_object('refundId',r,'reason','Approve excess payment refund'));perform report_test.send(oid,r);
 perform report_test.ok((select payment_status<>'paid' from app_private.commerce_orders where order_id=oid),'sending overpayment refund never automatically marks Paid');
 perform report_test.denied(format('select report_test.finance(%L::uuid,''resolve-payment'',''{"reason":"Synthetic missing confirmation"}'')',oid),'balance resolution requires explicit account-history check');
 perform report_test.finance(oid,'resolve-payment','{"reason":"Reviewed net balance and stock","checkedHistory":true,"reacquire":false}');
 perform report_test.ok((select payment_status='paid' and allocation='accepted' from app_private.commerce_orders where order_id=oid),'explicit overpayment balance resolution accepts exact net funds');
 perform report_test.finance(oid,'reverse',jsonb_build_object('refundId',r,'reason','Mistaken refund recording','checkedHistory',true));
 perform report_test.ok((select payment_status='received_resolution_required' from app_private.commerce_orders where order_id=oid),'reversing a resolved overpayment refund removes fulfilment readiness');
 perform report_test.denied(format('select report_test.finance(%L::uuid,''resolve-payment'',''{"reason":"Unresolved excess funds","checkedHistory":true}'')',oid),'unmatched net funds cannot be resolved Paid');
 perform report_test.step(oid,'cancel');
 perform report_test.denied(format('select report_test.finance(%L::uuid,''resolve-payment'',''{"reason":"No automatic reopening","checkedHistory":true}'')',oid),'refund workflow cannot reopen cancellation');

 -- A return with no merchandise refund and zero resale does not create money/stock.
 oid=report_test.place(2);perform report_test.pay(oid);perform report_test.step(oid,'confirm');perform report_test.step(oid,'dispatch');
 stock=(select on_hand from public.inventory_balances where variant_id='15151515-0000-4000-8000-000000000002');item=(select id from public.order_items where order_id=oid);
 perform report_test.finance(oid,'return',jsonb_build_object('itemId',item,'variantId','15151515-0000-4000-8000-000000000002','quantity',1,'resaleQuantity',0,'receivedAt',clock_timestamp(),'inspected',true,'reason','Damaged return without refund'));
 perform report_test.ok(not exists(select 1 from app_private.refund_requests where order_id=oid) and (select on_hand from public.inventory_balances where variant_id='15151515-0000-4000-8000-000000000002')=stock,'damaged return without refund adds neither stock nor financial entry');
 r=report_test.request(oid,report_test.selection(oid,false,1));perform report_test.finance(oid,'approve',jsonb_build_object('refundId',r,'reason','Partial pre-completion refund'));perform report_test.send(oid,r);
 perform report_test.ok((select sum(merchandise_minor)=0 from app_private.reporting_events() where order_id=oid),'uncompleted refund is cash-only before completion');
 perform report_test.step(oid,'complete');
 perform report_test.ok((select sum(merchandise_minor)=100000 and sum(refunds_minor)=100000 from app_private.reporting_events() where order_id=oid),'later completion recognizes prior refund without double cash counting');
 perform report_test.ok((select occurred_at>=s.completed_at from app_private.reporting_events() e join app_private.completed_sales s on s.order_id=e.order_id where e.order_id=oid and e.event='earlier refund recognized on completion'),'prior-refund sales adjustment is dated at completion, not backdated');
 perform report_test.finance(oid,'reverse',jsonb_build_object('refundId',r,'reason','Correct earlier refund record','checkedHistory',true));
 perform report_test.ok((select sum(merchandise_minor)=200000 and sum(refunds_minor)=0 from app_private.reporting_events() where order_id=oid),'reversing recognized earlier refund restores sales and cash exactly');

 -- Full refund of the historical remaining items + delivery, leaving no budget.
 baseline=(select jsonb_build_object('order',to_jsonb(o),'items',(select jsonb_agg(to_jsonb(i) order by i.id) from public.order_items i where i.order_id=oid)) from public.orders o where o.id=oid);
 r=report_test.request(oid,report_test.selection(oid,false,1));perform report_test.finance(oid,'approve',jsonb_build_object('refundId',r,'reason','First partial refund'));perform report_test.send(oid,r);
 r2=report_test.request(oid,report_test.selection(oid,false,1,12345));perform report_test.finance(oid,'approve',jsonb_build_object('refundId',r2,'reason','Full remaining refund'));perform report_test.send(oid,r2);
 perform report_test.ok((public.admin_order_finance(oid)->>'availableMinor')::bigint=0,'full partial-plus-shipping refund consumes exact remaining balance');
 perform report_test.denied(format('select report_test.request(%L::uuid,%L::jsonb)',oid,report_test.selection(oid,false,0,1)),'no over-refund after full remaining refund');
 perform report_test.ok(baseline=(select jsonb_build_object('order',to_jsonb(o),'items',(select jsonb_agg(to_jsonb(i) order by i.id) from public.order_items i where i.order_id=oid)) from public.orders o where o.id=oid),'refunds never rewrite original order totals/items');

 -- Explicit receipt-date metadata preserves the original immutable receipt.
 oid=report_test.place();stamp=clock_timestamp();op=gen_random_uuid();perform public.review_manual_payment(oid,(select revision from app_private.commerce_orders where order_id=oid),'verify',op,jsonb_build_object('checkedHistory',true,'amountMinor',112345,'reference','DATE-'||oid,'actualReceivedAt',stamp,'reacquire',false));
 perform report_test.ok((select actual_received_at=stamp from app_private.receipt_dates where receipt_id=op),'actual receipt date stored without changing original receipt');
 perform report_test.ok((select occurred_at=stamp from app_private.reporting_events() where id='receipt:'||op),'receipt report uses actual receipt date');
 perform report_test.denied(format('update app_private.receipt_dates set actual_received_at=now() where receipt_id=%L::uuid',op),'actual receipt-date evidence remains immutable');
 perform report_test.step(oid,'confirm');perform report_test.step(oid,'dispatch');
 -- Retrying a prior successful dispatch must work even after a new approved refund.
 select operation_key,revision-1 into op,rev from app_private.order_events where order_id=oid and action='dispatch';r=report_test.request(oid,report_test.selection(oid,false,1));perform report_test.finance(oid,'approve',jsonb_build_object('refundId',r,'reason','Post-dispatch refund approval'));
 perform public.admin_order_action(oid,rev,'dispatch',op);perform report_test.ok(true,'dispatch retry preserves idempotency after refund approval');
 perform report_test.finance(oid,'cancel',jsonb_build_object('refundId',r,'reason','Release unsent test refund'));

 -- Report range boundaries use actual SQL timestamps; these rows are test fixtures only.
 oid=report_test.place();u=report_test.place();
 insert into app_private.completed_sales values(oid,'2026-02-01 18:59:59+00',100000,12345,auth.uid(),'completion'),(u,'2026-02-01 19:00:00+00',100000,12345,auth.uid(),'completion');
 out=public.admin_sales_report('2026-02-01','2026-02-01','day',p_development=>true);
 perform report_test.ok((out->'totals'->>'completedOrders')::integer=1 and out->'events'->0->>'order_id'=oid::text,'Pakistan end-of-day is exclusive at 19:00 UTC');
 out=public.admin_sales_report('2026-02-02','2026-02-02','day',p_development=>true);
 perform report_test.ok((out->'totals'->>'completedOrders')::integer=1 and out->'events'->0->>'order_id'=u::text,'Pakistan next day starts exactly at 19:00 UTC');
 perform report_test.step(oid,'cancel');perform report_test.step(u,'cancel');
 perform report_test.ok((select bool_and(completed_at=e.occurred_at) from app_private.completed_sales s join app_private.order_events e on e.order_id=s.order_id and e.action='complete' where s.source='historical_completion_event'),'historical backfill preserves explicit Complete timestamps');
end $extra$;
-- Test direct client permissions, not only API-wrapper behavior.
set role authenticated;set request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $$ declare v boolean=false;begin begin perform public.admin_order_finance('00000000-0000-0000-0000-000000000000');exception when others then v=true;end;if not v then raise exception 'non-admin finance exposed';end if;v=false;begin perform public.admin_finance_action(gen_random_uuid(),0,gen_random_uuid(),'request','{}');exception when others then v=true;end;if not v then raise exception 'non-admin write exposed';end if;end $$;
reset role;set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
select report_test.ok(not exists(select 1 from (values('anon'),('authenticated'),('service_role'))roles(name) cross join (values('receipt_dates'),('completed_sales'),('finance_versions'),('refund_requests'),('refund_events'),('return_events'),('finance_operations'))tables(name) where has_table_privilege(roles.name,'app_private.'||tables.name,'SELECT') or has_table_privilege(roles.name,'app_private.'||tables.name,'INSERT')),'private financial tables have no direct client/service grants');
