-- Complete incremental 021 AFTER 020; do not rerun 020 or any prior installer.
-- Replaces only two function bodies, preserving their identities/grants. No row rewrites/deletes.
begin;set local lock_timeout='5s';set local statement_timeout='120s';select pg_advisory_xact_lock(73525);
do $guard$ begin
 if not exists(select 1 from app_private.sql_editor_receipts where version='202610180020' and sha256='3a274cb58a5da769a57ee7ab0dfb5877b68bb82adcf92caba1031ca1e4b6b434') then raise exception 'Confirm canonical 020 first';end if;
 if exists(select 1 from app_private.sql_editor_receipts where version='202610200021') then raise exception '021 already installed; inspect state, do not rerun';end if;
end $guard$;
-- 021: partial-value refunds, including partially paid cancelled orders. No tables/rows/grants are changed at installation.
create or replace function app_private.refund_quote(p_order uuid,p_selection jsonb,p_exclude uuid default null) returns jsonb language plpgsql stable set search_path='' as $$
declare x jsonb;c record;used_qty integer;used_money bigint;allowed bigint;chosen bigint;merch bigint=0;shipping bigint;overpay bigint;funds numeric;held numeric;lines jsonb='[]';total bigint;begin
 if p_selection is null or jsonb_typeof(p_selection)<>'object' or length(p_selection::text)>16000 or jsonb_typeof(p_selection->'items')<>'array' or jsonb_array_length(p_selection->'items')>100 then raise exception 'Select valid refund items';end if;
 if coalesce(p_selection->>'shippingMinor','0') !~ '^[0-9]{1,16}$' or coalesce(p_selection->>'overpaymentMinor','0') !~ '^[0-9]{1,16}$' then raise exception 'Enter valid PKR amounts';end if;
 shipping=coalesce((p_selection->>'shippingMinor')::bigint,0);overpay=coalesce((p_selection->>'overpaymentMinor')::bigint,0);
 if exists(select 1 from jsonb_array_elements(p_selection->'items') v group by (v->>'itemId')::uuid,(v->>'variantId')::uuid having count(*)>1) then raise exception 'Select each item option once';end if;
 for x in select * from jsonb_array_elements(p_selection->'items') loop
  if coalesce(x->>'quantity','') !~ '^[0-9]{1,5}$' or (x->>'quantity')::integer not between 0 and 10000 then raise exception 'Choose a valid item quantity';end if;
  select * into c from app_private.finance_components(p_order) where item_id=(x->>'itemId')::uuid and variant_id=(x->>'variantId')::uuid;
  if not found then raise exception 'Item does not belong to this order';end if;
  select coalesce(sum((v->>'quantity')::integer),0),coalesce(sum((v->>'amountMinor')::bigint),0) into used_qty,used_money from app_private.refund_requests r cross join lateral jsonb_array_elements(r.lines) v where r.order_id=p_order and r.state in('approved','sent') and r.id is distinct from p_exclude and v->>'itemId'=c.item_id::text and v->>'variantId'=c.variant_id::text;
  if used_qty+(x->>'quantity')::integer>c.quantity then raise exception 'This item quantity is already refunded or reserved for a refund';end if;
  allowed=case when (x->>'quantity')::integer=0 then c.attributed_minor-used_money else greatest(0,floor(c.attributed_minor::numeric*(used_qty+(x->>'quantity')::integer)/c.quantity)-used_money) end;
  if x ? 'amountMinor' then
   if coalesce(x->>'amountMinor','') !~ '^[0-9]{1,16}$' then raise exception 'Enter a valid partial refund amount';end if;
   chosen=(x->>'amountMinor')::bigint;
  else chosen=allowed;end if;
  if chosen>allowed or chosen<0 or ((x->>'quantity')::integer=0 and (not (x ? 'amountMinor') or chosen=0)) then raise exception 'Refund value exceeds this item remaining entitlement';end if;
  merch=merch+chosen;lines=lines||jsonb_build_array(jsonb_build_object('itemId',c.item_id,'variantId',c.variant_id,'name',c.name,'lineName',c.line_name,'sku',c.sku,'quantity',(x->>'quantity')::integer,'amountMinor',chosen));
 end loop;
 select total_minor into total from public.orders where id=p_order;
 select coalesce(sum(amount_minor),0) into funds from app_private.payment_receipts where order_id=p_order;
 select coalesce(sum(amount_minor),0) into held from app_private.refund_requests where order_id=p_order and state in('approved','sent') and id is distinct from p_exclude;
 if shipping+coalesce((select sum(shipping_minor) from app_private.refund_requests where order_id=p_order and state in('approved','sent') and id is distinct from p_exclude),0)>(select shipping_minor from public.orders where id=p_order) then raise exception 'Delivery refund exceeds its remaining charge';end if;
 if overpay+coalesce((select sum(overpayment_minor) from app_private.refund_requests where order_id=p_order and state in('approved','sent') and id is distinct from p_exclude),0)>greatest(0,funds-total) then raise exception 'Overpayment refund exceeds verified overpayment';end if;
 if merch+shipping+overpay<1 or merch+shipping+overpay>funds-held then raise exception 'Refund exceeds the remaining verified funds';end if;
 return jsonb_build_object('lines',lines,'merchandiseMinor',merch,'shippingMinor',shipping,'overpaymentMinor',overpay,'amountMinor',merch+shipping+overpay);
end $$;
create or replace function public.admin_order_finance(p_order uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$ begin
 perform app_private.require_admin();if not exists(select 1 from app_private.commerce_orders where order_id=p_order) then raise exception 'Order not found';end if;
 return jsonb_build_object('partialAmountsSupported',true,'revision',coalesce((select revision from app_private.finance_versions where order_id=p_order),0),'receivedMinor',(select coalesce(sum(amount_minor),0) from app_private.payment_receipts where order_id=p_order),
 'reservedMinor',(select coalesce(sum(amount_minor),0) from app_private.refund_requests where order_id=p_order and state='approved'),'sentMinor',(select coalesce(sum(amount_minor),0) from app_private.refund_requests where order_id=p_order and state='sent'),
 'availableMinor',(select coalesce(sum(amount_minor),0) from app_private.payment_receipts where order_id=p_order)-(select coalesce(sum(amount_minor),0) from app_private.refund_requests where order_id=p_order and state in('approved','sent')),
 'shippingAvailableMinor',(select shipping_minor from public.orders where id=p_order)-(select coalesce(sum(shipping_minor),0) from app_private.refund_requests where order_id=p_order and state in('approved','sent')),
 'overpaymentAvailableMinor',greatest(0,(select coalesce(sum(amount_minor),0) from app_private.payment_receipts where order_id=p_order)-(select total_minor from public.orders where id=p_order))-(select coalesce(sum(overpayment_minor),0) from app_private.refund_requests where order_id=p_order and state in('approved','sent')),
 'items',coalesce((select jsonb_agg(to_jsonb(c)||jsonb_build_object('remainingQuantity',c.quantity-coalesce((select sum((v->>'quantity')::integer) from app_private.refund_requests q cross join lateral jsonb_array_elements(q.lines)v where q.order_id=p_order and q.state in('approved','sent') and v->>'itemId'=c.item_id::text and v->>'variantId'=c.variant_id::text),0),'remainingAmountMinor',c.attributed_minor-coalesce((select sum((v->>'amountMinor')::bigint) from app_private.refund_requests q cross join lateral jsonb_array_elements(q.lines)v where q.order_id=p_order and q.state in('approved','sent') and v->>'itemId'=c.item_id::text and v->>'variantId'=c.variant_id::text),0),'returnableQuantity',case when exists(select 1 from app_private.commerce_orders where order_id=p_order and fulfilment in('dispatched','completed')) then c.quantity-coalesce((select sum(case when t.action='receive' then t.quantity else -t.quantity end) from app_private.return_events t where t.order_id=p_order and t.item_id=c.item_id and t.variant_id=c.variant_id),0) else 0 end)) from app_private.finance_components(p_order)c),'[]'),
 'refunds',coalesce((select jsonb_agg(to_jsonb(q) order by q.created_at desc,q.id) from app_private.refund_requests q where q.order_id=p_order),'[]'),
 'events',coalesce((select jsonb_agg(to_jsonb(e) order by e.recorded_at desc,e.id) from app_private.refund_events e where e.order_id=p_order),'[]'),
 'returns',coalesce((select jsonb_agg(to_jsonb(t) order by t.recorded_at desc,t.id) from app_private.return_events t where t.order_id=p_order),'[]'));
end $$;


insert into app_private.sql_editor_receipts(version,filename,sha256) values('202610200021','202610200021_partial_refund_values.sql','2c620c81ec6821b9f733a8108bfc881a6f4d209a04b9fb0fd9347d235c4fda73');notify pgrst,'reload schema';commit;
-- Read only. Before: prerequisite_020, private_rls and permissions_preserved true;
-- value_contract, view_contract and receipt flags false. All seven flags true after.
select exists(select 1 from app_private.sql_editor_receipts where version='202610180020' and sha256='3a274cb58a5da769a57ee7ab0dfb5877b68bb82adcf92caba1031ca1e4b6b434') prerequisite_020,
 coalesce((select position('chosen' in prosrc)>0 and position('amountMinor' in prosrc)>0 from pg_proc where oid=to_regprocedure('app_private.refund_quote(uuid,jsonb,uuid)')),false) value_contract,
 coalesce((select position('partialAmountsSupported' in prosrc)>0 and position('remainingAmountMinor' in prosrc)>0 from pg_proc where oid=to_regprocedure('public.admin_order_finance(uuid)')),false) view_contract,
 exists(select 1 from app_private.sql_editor_receipts where version='202610200021') receipt_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610200021' and sha256='2c620c81ec6821b9f733a8108bfc881a6f4d209a04b9fb0fd9347d235c4fda73') receipt_matches,
 (select count(*)=7 and bool_and(relrowsecurity and not relforcerowsecurity) from pg_class where oid in(to_regclass('app_private.completed_sales'),to_regclass('app_private.receipt_dates'),to_regclass('app_private.finance_versions'),to_regclass('app_private.refund_requests'),to_regclass('app_private.refund_events'),to_regclass('app_private.return_events'),to_regclass('app_private.finance_operations'))) private_rls,
 (select prosecdef and proowner='postgres'::regrole and has_function_privilege('authenticated',oid,'EXECUTE') and not has_function_privilege('anon',oid,'EXECUTE') and not has_function_privilege('service_role',oid,'EXECUTE') from pg_proc where oid=to_regprocedure('public.admin_order_finance(uuid)')) and not has_function_privilege('authenticated','app_private.refund_quote(uuid,jsonb,uuid)','EXECUTE') permissions_preserved;
