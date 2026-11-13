-- Complete incremental 020 only; do not rerun earlier installers.
-- Adds private ledgers/indexes/functions/trigger and reconstructs explicit historical Complete events.
-- No business rows deleted/reset. Revokes generic legacy sales/refund INSERT from authenticated.
begin;set local lock_timeout='5s';set local statement_timeout='120s';select pg_advisory_xact_lock(73525);
do $guard$ begin
 if not exists(select 1 from app_private.sql_editor_receipts where version='202610180019' and sha256='19ee24e376d66ad9dca4e09cc5bec42b1a703e3dfb69011849eef0dd8796623c') then raise exception 'Verify canonical 019 first';end if;
 if exists(select 1 from app_private.sql_editor_receipts where version='202610180020') or to_regclass('app_private.completed_sales') is not null or to_regprocedure('public.admin_order_finance(uuid)') is not null then raise exception '020 already or partly installed. Inspect state; do not rerun';end if;
end $guard$;
-- 020: private completed-sales, manual refund and inspected-return ledgers.
-- Additive financial history; never rewrites order prices, receipts or stock counts.
create table app_private.completed_sales(order_id uuid primary key references public.orders(id),completed_at timestamptz not null,merchandise_minor bigint not null check(merchandise_minor>=0),shipping_minor bigint not null check(shipping_minor>=0),actor_id uuid references auth.users(id),source text not null check(source in('completion','historical_completion_event')));
create table app_private.receipt_dates(receipt_id uuid primary key references app_private.payment_receipts(id),actual_received_at timestamptz not null,recorded_at timestamptz not null default now(),actor_id uuid not null references auth.users(id));
create index receipt_dates_reporting on app_private.receipt_dates(actual_received_at,receipt_id);
create table app_private.finance_versions(order_id uuid primary key references public.orders(id),revision integer not null check(revision>0));
create table app_private.refund_requests(id uuid primary key,order_id uuid not null references public.orders(id),state text not null check(state in('requested','approved','sent','cancelled','reversed')),reason text not null check(length(btrim(reason)) between 3 and 500),selection jsonb not null,lines jsonb not null,merchandise_minor bigint not null check(merchandise_minor>=0),shipping_minor bigint not null check(shipping_minor>=0),overpayment_minor bigint not null check(overpayment_minor>=0),amount_minor bigint not null check(amount_minor between 1 and 9007199254740991),created_at timestamptz not null default now(),actor_id uuid not null references auth.users(id),check(amount_minor=merchandise_minor+shipping_minor+overpayment_minor));
create table app_private.refund_events(id uuid primary key,refund_id uuid not null references app_private.refund_requests(id),order_id uuid not null references public.orders(id),action text not null check(action in('request','approve','cancel','send','reverse')),amount_minor bigint not null check(amount_minor>=0),merchandise_minor bigint not null default 0,shipping_minor bigint not null default 0,overpayment_minor bigint not null default 0,sales_applicable boolean not null default false,method text check(method in('bank-transfer','easypaisa','jazzcash')),account_scope text,reference text,reference_key text,reason text not null,occurred_at timestamptz not null,recorded_at timestamptz not null default now(),actor_id uuid not null references auth.users(id),reverses uuid unique references app_private.refund_events(id),check((action='send')=(method is not null and account_scope is not null and reference_key is not null)),unique(account_scope,reference_key));
create table app_private.return_events(id uuid primary key,order_id uuid not null references public.orders(id),item_id uuid not null references public.order_items(id),variant_id uuid not null references public.variants(id),quantity integer not null check(quantity between 1 and 10000),resale_quantity integer not null check(resale_quantity between 0 and quantity),action text not null check(action in('receive','reverse')),reason text not null check(length(btrim(reason)) between 3 and 500),occurred_at timestamptz not null,recorded_at timestamptz not null default now(),actor_id uuid not null references auth.users(id),reverses uuid unique references app_private.return_events(id));
create table app_private.finance_operations(id uuid primary key,order_id uuid not null references public.orders(id),request_hash text not null,action text not null,reason text not null,actor_id uuid not null references auth.users(id),created_at timestamptz not null default now());
do $security$ declare t text;begin
 foreach t in array array['receipt_dates','completed_sales','finance_versions','refund_requests','refund_events','return_events','finance_operations'] loop
 execute format('alter table app_private.%I enable row level security',t);
 execute format('revoke all on app_private.%I from public,anon,authenticated,service_role',t);
 end loop;
 foreach t in array array['receipt_dates','completed_sales','refund_events','return_events','finance_operations'] loop execute format('create trigger immutable before update or delete on app_private.%I for each row execute function app_private.payment_immutable()',t);end loop;
end $security$;
-- Legacy generic entry points are not a second financial workflow.
revoke insert on public.sales,public.refunds from authenticated;
create trigger audit_changes after insert or update or delete on app_private.refund_requests for each row execute function app_private.audit_change();
create index completed_sales_time on app_private.completed_sales(completed_at,order_id);
create index refund_events_time on app_private.refund_events(occurred_at,id) where action in('send','reverse');
create index refund_events_refund on app_private.refund_events(refund_id,action);
create index refund_events_order on app_private.refund_events(order_id,recorded_at,id);
create index refund_requests_order on app_private.refund_requests(order_id,state);
create index return_events_order on app_private.return_events(order_id,item_id,variant_id);
create index payment_receipts_reporting_time on app_private.payment_receipts(received_at,id);
create function app_private.record_completed_sale() returns trigger language plpgsql security definer set search_path='' as $$ begin
 if new.fulfilment='completed' and old.fulfilment<>'completed' then
  perform app_private.assert_order_allocation(new.order_id,'consumed');
  insert into app_private.completed_sales select o.id,clock_timestamp(),o.subtotal_minor-o.discount_minor,o.shipping_minor,auth.uid(),'completion' from public.orders o where o.id=new.order_id;
 end if;return new;
end $$;
create trigger completed_sale after update of fulfilment on app_private.commerce_orders for each row execute function app_private.record_completed_sale();
-- Reconstruct ONLY explicit historical Complete events, preserving their actual timestamps.
do $history$ begin
 if exists(select 1 from app_private.commerce_orders c where c.fulfilment='completed' and not exists(select 1 from app_private.order_events e where e.order_id=c.order_id and e.action='complete')) then raise exception 'Completed order lacks explicit completion history. Inspect before installation';end if;
end $history$;
insert into app_private.completed_sales select c.order_id,e.occurred_at,o.subtotal_minor-o.discount_minor,o.shipping_minor,e.actor_id,'historical_completion_event' from app_private.commerce_orders c join public.orders o on o.id=c.order_id cross join lateral(select occurred_at,actor_id from app_private.order_events where order_id=c.order_id and action='complete' order by occurred_at,id limit 1)e where c.fulfilment='completed';

create function app_private.finance_components(p_order uuid) returns table(item_id uuid,variant_id uuid,name text,sku text,kind text,quantity integer,attributed_minor bigint,line_name text) language sql stable set search_path='' as $$
 select i.id,s.variant_id,s.product_name||case when s.option_name<>'' then ' · '||s.option_name else '' end,s.sku,case when i.deal_id is null then 'product' else 'deal component' end,s.quantity,s.attributed_minor,i.name_snapshot from public.order_items i join app_private.order_component_snapshots s on s.order_item_id=i.id where i.order_id=p_order
 union all select i.id,i.variant_id,i.name_snapshot,i.sku_snapshot,'product',i.quantity,i.line_total_minor,i.name_snapshot from public.order_items i where i.order_id=p_order and i.variant_id is not null and not exists(select 1 from app_private.order_component_snapshots s where s.order_item_id=i.id);
$$;
create function app_private.refund_quote(p_order uuid,p_selection jsonb,p_exclude uuid default null) returns jsonb language plpgsql stable set search_path='' as $$
declare x jsonb;c record;used_qty integer;used_money bigint;allowed bigint;merch bigint=0;shipping bigint;overpay bigint;funds numeric;held numeric;lines jsonb='[]';total bigint;begin
 if p_selection is null or jsonb_typeof(p_selection)<>'object' or length(p_selection::text)>16000 or jsonb_typeof(p_selection->'items')<>'array' or jsonb_array_length(p_selection->'items')>100 then raise exception 'Select valid refund items';end if;
 if coalesce(p_selection->>'shippingMinor','0') !~ '^[0-9]{1,16}$' or coalesce(p_selection->>'overpaymentMinor','0') !~ '^[0-9]{1,16}$' then raise exception 'Enter valid PKR amounts';end if;
 shipping=coalesce((p_selection->>'shippingMinor')::bigint,0);overpay=coalesce((p_selection->>'overpaymentMinor')::bigint,0);
 if exists(select 1 from jsonb_array_elements(p_selection->'items') v group by (v->>'itemId')::uuid,(v->>'variantId')::uuid having count(*)>1) then raise exception 'Select each item option once';end if;
 for x in select * from jsonb_array_elements(p_selection->'items') loop
  if coalesce(x->>'quantity','') !~ '^[0-9]{1,5}$' or (x->>'quantity')::integer not between 1 and 10000 then raise exception 'Choose a positive item quantity';end if;
  select * into c from app_private.finance_components(p_order) where item_id=(x->>'itemId')::uuid and variant_id=(x->>'variantId')::uuid;
  if not found then raise exception 'Item does not belong to this order';end if;
  select coalesce(sum((v->>'quantity')::integer),0),coalesce(sum((v->>'amountMinor')::bigint),0) into used_qty,used_money from app_private.refund_requests r cross join lateral jsonb_array_elements(r.lines) v where r.order_id=p_order and r.state in('approved','sent') and r.id is distinct from p_exclude and v->>'itemId'=c.item_id::text and v->>'variantId'=c.variant_id::text;
  if used_qty+(x->>'quantity')::integer>c.quantity then raise exception 'This item quantity is already refunded or reserved for a refund';end if;
  allowed=floor(c.attributed_minor::numeric*(used_qty+(x->>'quantity')::integer)/c.quantity)-used_money;
  if allowed<0 then raise exception 'Refund allocation needs review';end if;
  merch=merch+allowed;lines=lines||jsonb_build_array(jsonb_build_object('itemId',c.item_id,'variantId',c.variant_id,'name',c.name,'lineName',c.line_name,'sku',c.sku,'quantity',(x->>'quantity')::integer,'amountMinor',allowed));
 end loop;
 select total_minor into total from public.orders where id=p_order;
 select coalesce(sum(amount_minor),0) into funds from app_private.payment_receipts where order_id=p_order;
 select coalesce(sum(amount_minor),0) into held from app_private.refund_requests where order_id=p_order and state in('approved','sent') and id is distinct from p_exclude;
 if shipping+coalesce((select sum(shipping_minor) from app_private.refund_requests where order_id=p_order and state in('approved','sent') and id is distinct from p_exclude),0)>(select shipping_minor from public.orders where id=p_order) then raise exception 'Delivery refund exceeds its remaining charge';end if;
 if overpay+coalesce((select sum(overpayment_minor) from app_private.refund_requests where order_id=p_order and state in('approved','sent') and id is distinct from p_exclude),0)>greatest(0,funds-total) then raise exception 'Overpayment refund exceeds verified overpayment';end if;
 if merch+shipping+overpay<1 or merch+shipping+overpay>funds-held then raise exception 'Refund exceeds the remaining verified funds';end if;
 return jsonb_build_object('lines',lines,'merchandiseMinor',merch,'shippingMinor',shipping,'overpaymentMinor',overpay,'amountMinor',merch+shipping+overpay);
end $$;
create function public.admin_order_finance(p_order uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$ begin
 perform app_private.require_admin();if not exists(select 1 from app_private.commerce_orders where order_id=p_order) then raise exception 'Order not found';end if;
 return jsonb_build_object('revision',coalesce((select revision from app_private.finance_versions where order_id=p_order),0),'receivedMinor',(select coalesce(sum(amount_minor),0) from app_private.payment_receipts where order_id=p_order),
 'reservedMinor',(select coalesce(sum(amount_minor),0) from app_private.refund_requests where order_id=p_order and state='approved'),'sentMinor',(select coalesce(sum(amount_minor),0) from app_private.refund_requests where order_id=p_order and state='sent'),
 'availableMinor',(select coalesce(sum(amount_minor),0) from app_private.payment_receipts where order_id=p_order)-(select coalesce(sum(amount_minor),0) from app_private.refund_requests where order_id=p_order and state in('approved','sent')),
 'shippingAvailableMinor',(select shipping_minor from public.orders where id=p_order)-(select coalesce(sum(shipping_minor),0) from app_private.refund_requests where order_id=p_order and state in('approved','sent')),
 'overpaymentAvailableMinor',greatest(0,(select coalesce(sum(amount_minor),0) from app_private.payment_receipts where order_id=p_order)-(select total_minor from public.orders where id=p_order))-(select coalesce(sum(overpayment_minor),0) from app_private.refund_requests where order_id=p_order and state in('approved','sent')),
 'items',coalesce((select jsonb_agg(to_jsonb(c)||jsonb_build_object('remainingQuantity',c.quantity-coalesce((select sum((v->>'quantity')::integer) from app_private.refund_requests q cross join lateral jsonb_array_elements(q.lines)v where q.order_id=p_order and q.state in('approved','sent') and v->>'itemId'=c.item_id::text and v->>'variantId'=c.variant_id::text),0),'returnableQuantity',case when exists(select 1 from app_private.commerce_orders where order_id=p_order and fulfilment in('dispatched','completed')) then c.quantity-coalesce((select sum(case when t.action='receive' then t.quantity else -t.quantity end) from app_private.return_events t where t.order_id=p_order and t.item_id=c.item_id and t.variant_id=c.variant_id),0) else 0 end)) from app_private.finance_components(p_order)c),'[]'),
 'refunds',coalesce((select jsonb_agg(to_jsonb(q) order by q.created_at desc,q.id) from app_private.refund_requests q where q.order_id=p_order),'[]'),
 'events',coalesce((select jsonb_agg(to_jsonb(e) order by e.recorded_at desc,e.id) from app_private.refund_events e where e.order_id=p_order),'[]'),
 'returns',coalesce((select jsonb_agg(to_jsonb(t) order by t.recorded_at desc,t.id) from app_private.return_events t where t.order_id=p_order),'[]'));
end $$;

create function public.admin_finance_action(p_order uuid,p_revision integer,p_key uuid,p_action text,p_data jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare prior app_private.finance_operations;r app_private.refund_requests;t app_private.return_events;e app_private.refund_events;q jsonb;rh text;stamp timestamptz;reason text;scope text;ref text;method text;v integer;c record;already integer;qty integer;resale integer;co app_private.commerce_orders;net bigint;ready boolean=false;begin
 perform app_private.require_admin();perform pg_advisory_xact_lock(73525);
 if p_order is null or p_revision is null or p_revision<0 or p_action is null or p_key is null or p_data is null or length(p_data::text)>18000 or p_action not in('request','approve','cancel','send','reverse','return','reverse-return','resolve-payment') then raise exception 'Invalid financial action';end if;
 perform 1 from app_private.commerce_orders where order_id=p_order for update;if not found then raise exception 'Order not found';end if;
 rh=encode(sha256(convert_to(jsonb_build_array(p_order,p_revision,p_action,p_data)::text,'UTF8')),'hex');
 select * into prior from app_private.finance_operations where id=p_key;
 if found then if prior.order_id<>p_order or prior.request_hash<>rh then raise exception 'Idempotency conflict';end if;return public.admin_order_finance(p_order);end if;
 select coalesce((select revision from app_private.finance_versions where order_id=p_order),0) into v;
 if v<>p_revision then raise exception 'Refund or return information changed. Refresh before retrying';end if;
 reason=btrim(coalesce(p_data->>'reason',''));if length(reason) not between 3 and 500 then raise exception 'Add a short reason';end if;
 if p_action='request' then
  if (select count(*) from app_private.refund_requests where order_id=p_order)>=100 then raise exception 'This order has reached the refund-history limit. Review its existing records';end if;
  q=app_private.refund_quote(p_order,p_data->'selection');
  insert into app_private.refund_requests(id,order_id,state,reason,selection,lines,merchandise_minor,shipping_minor,overpayment_minor,amount_minor,actor_id) values(p_key,p_order,'requested',reason,p_data->'selection',q->'lines',(q->>'merchandiseMinor')::bigint,(q->>'shippingMinor')::bigint,(q->>'overpaymentMinor')::bigint,(q->>'amountMinor')::bigint,auth.uid());
 elsif p_action='resolve-payment' then
  if p_data->>'checkedHistory' is distinct from 'true' then raise exception 'Explicitly review the verified receipts and sent refunds first';end if;
  select * into co from app_private.commerce_orders where order_id=p_order;
  if co.fulfilment='cancelled' then raise exception 'Cancellation remains separate; a refund must not reopen this order';end if;
  net=(select coalesce(sum(amount_minor),0) from app_private.payment_receipts where order_id=p_order)-(select coalesce(sum(amount_minor),0) from app_private.refund_requests where order_id=p_order and state='sent');
  if net<>(select total_minor from public.orders where id=p_order) or exists(select 1 from app_private.refund_requests where order_id=p_order and state in('approved','sent') and merchandise_minor+shipping_minor>0) then raise exception 'Resolve item/shipping refunds and match the original order amount before making it fulfilment-ready';end if;
  if co.allocation='temporary' and co.hold_expires_at<=now() then
   perform app_private.assert_order_allocation(p_order,'active',true);perform app_private.finish_inventory(p_order,false);
   update app_private.commerce_orders set allocation='released',fulfilment='expired' where order_id=p_order;update public.orders set status='cancelled' where id=p_order;co.allocation='released';co.fulfilment='expired';
  end if;
  if co.allocation in('accepted','consumed','temporary') then ready=true;
  elsif co.fulfilment='expired' and p_data->>'reacquire'='true' then ready=app_private.reacquire_payment_stock(p_order);end if;
  if ready then
   perform app_private.assert_order_allocation(p_order,case when co.allocation='consumed' then 'consumed' else 'active' end);
   update public.inventory_reservations set expires_at='infinity' where order_id=p_order and state='active';
   update app_private.commerce_orders set payment_status='paid',allocation=case when allocation='consumed' then allocation else 'accepted' end,fulfilment=case when fulfilment='expired' then 'placed' else fulfilment end,hold_expires_at=null where order_id=p_order;
   update public.orders set status=case when status='cancelled' then 'placed' else status end where id=p_order;
   update app_private.manual_payments set flags='{}',message=null where order_id=p_order;
  else
   update app_private.commerce_orders set payment_status='received_resolution_required' where order_id=p_order;
   update app_private.manual_payments set flags=array['Stock allocation requires resolution'],message='Payment balance resolved; stock unavailable. Do not fulfil automatically.' where order_id=p_order;
  end if;
  update app_private.commerce_orders set revision=revision+1 where order_id=p_order;
  insert into app_private.order_events(order_id,operation_key,action,revision,actor_id) select p_order,p_key,'payment_balance_reviewed',revision,auth.uid() from app_private.commerce_orders where order_id=p_order;
 elsif p_action in('approve','cancel','send','reverse') then
  select * into r from app_private.refund_requests where id=(p_data->>'refundId')::uuid and order_id=p_order for update;if not found then raise exception 'Refund not found';end if;
  if p_action='approve' and r.state='requested' then
   q=app_private.refund_quote(p_order,r.selection,r.id);
   update app_private.refund_requests set state='approved',lines=q->'lines',merchandise_minor=(q->>'merchandiseMinor')::bigint,amount_minor=(q->>'amountMinor')::bigint where id=r.id;
  elsif p_action='cancel' and r.state in('requested','approved') then update app_private.refund_requests set state='cancelled' where id=r.id;
  elsif p_action='send' and r.state='approved' then
   if p_data->>'checkedHistory' is distinct from 'true' then raise exception 'Confirm the transfer in actual outgoing-account history';end if;
   method=p_data->>'method';scope=method;ref=app_private.payment_reference(p_data->>'reference');
   if method is null or method not in('bank-transfer','easypaisa','jazzcash') or length(ref) not between 3 and 120 then raise exception 'Choose a manual method and enter the outgoing transfer reference';end if;
   scope=encode(sha256(convert_to(method,'UTF8')),'hex'); -- conservative service-wide reference isolation; account label cannot evade it
   stamp=(p_data->>'sentAt')::timestamptz;
   if stamp is null or stamp>now()+interval '1 minute' or stamp<r.created_at then raise exception 'Sent date must be between the refund request and now';end if;
   if coalesce((select sum(amount_minor) from app_private.payment_receipts where order_id=p_order),0)<(select coalesce(sum(amount_minor),0) from app_private.refund_requests where order_id=p_order and state in('approved','sent')) then raise exception 'Refund exceeds verified funds';end if;
   update app_private.refund_requests set state='sent' where id=r.id;
  elsif p_action='reverse' and r.state='sent' then
   if p_data->>'checkedHistory' is distinct from 'true' then raise exception 'Confirm this was a recording mistake against actual account history';end if;
   select * into e from app_private.refund_events where refund_id=r.id and action='send';stamp=clock_timestamp();
   update app_private.refund_requests set state='reversed' where id=r.id;
  else raise exception 'This refund action is unavailable';end if;
 else
  stamp=(p_data->>'receivedAt')::timestamptz;
  if p_action='return' then
   if (select count(*) from app_private.return_events where order_id=p_order)>=200 then raise exception 'This order has reached the return-history limit. Review its existing records';end if;
   if p_data->>'inspected' is distinct from 'true' or coalesce(p_data->>'quantity','') !~ '^[0-9]{1,5}$' or coalesce(p_data->>'resaleQuantity','') !~ '^[0-9]{1,5}$' then raise exception 'Inspect the return and enter valid quantities';end if;
   qty=(p_data->>'quantity')::integer;resale=(p_data->>'resaleQuantity')::integer;
   if qty not between 1 and 10000 or resale not between 0 and qty then raise exception 'Resale quantity cannot exceed received quantity';end if;
   if not exists(select 1 from app_private.commerce_orders where order_id=p_order and fulfilment in('dispatched','completed')) then raise exception 'Only dispatched items can be returned. Cancellation releases reservations, not physical stock';end if;
   select * into c from app_private.finance_components(p_order) where item_id=(p_data->>'itemId')::uuid and variant_id=(p_data->>'variantId')::uuid;if not found then raise exception 'Item not in this order';end if;
   if stamp is null or stamp>now()+interval '1 minute' or stamp<(select min(occurred_at) from app_private.order_events where order_id=p_order and action='dispatch') then raise exception 'Enter the actual receipt date after dispatch';end if;
   select coalesce(sum(case when action='receive' then quantity else -quantity end),0) into already from app_private.return_events where order_id=p_order and item_id=c.item_id and variant_id=c.variant_id;
   if already+qty>c.quantity then raise exception 'Return exceeds the dispatched quantity not already returned';end if;
   insert into app_private.return_events values(p_key,p_order,c.item_id,c.variant_id,qty,resale,'receive',reason,stamp,now(),auth.uid(),null);
   if resale>0 then perform public.adjust_inventory(c.variant_id,resale,'Inspected resale return: '||reason,'return:'||p_key);end if;
  else
   select * into t from app_private.return_events where id=(p_data->>'returnId')::uuid and order_id=p_order and action='receive';
   if not found or exists(select 1 from app_private.return_events where reverses=t.id) or p_data->>'inspected' is distinct from 'true' then raise exception 'Confirm the return-record correction after inspection';end if;
   insert into app_private.return_events values(p_key,p_order,t.item_id,t.variant_id,t.quantity,t.resale_quantity,'reverse',reason,clock_timestamp(),now(),auth.uid(),t.id);
   if t.resale_quantity>0 then perform public.adjust_inventory(t.variant_id,-t.resale_quantity,'Return-record correction: '||reason,'return-reversal:'||p_key);end if;
  end if;
 end if;
 if p_action in('request','approve','cancel','send','reverse') then
  select * into r from app_private.refund_requests where id=case when p_action='request' then p_key else (p_data->>'refundId')::uuid end;
  insert into app_private.refund_events(id,refund_id,order_id,action,amount_minor,merchandise_minor,shipping_minor,overpayment_minor,sales_applicable,method,account_scope,reference,reference_key,reason,occurred_at,actor_id,reverses) values(p_key,r.id,p_order,p_action,r.amount_minor,r.merchandise_minor,r.shipping_minor,r.overpayment_minor,case when p_action='reverse' then e.sales_applicable or exists(select 1 from app_private.completed_sales where order_id=p_order) else exists(select 1 from app_private.completed_sales where order_id=p_order and completed_at<=coalesce(stamp,now())) end,method,scope,case when p_action='send' then btrim(p_data->>'reference') end,case when p_action='send' then ref end,reason,coalesce(stamp,now()),auth.uid(),case when p_action='reverse' then e.id end);
 end if;
 if p_action in('send','reverse') and exists(select 1 from app_private.commerce_orders where order_id=p_order and fulfilment in('placed','confirmed') and payment_status='paid') then
  update app_private.commerce_orders set payment_status='received_resolution_required',revision=revision+1 where order_id=p_order;
  update app_private.manual_payments set flags=array['Refund balance requires explicit review'],message='Refund recorded. Review the net payment balance before fulfilment.' where order_id=p_order;
 end if;
 insert into app_private.finance_versions values(p_order,1) on conflict(order_id) do update set revision=app_private.finance_versions.revision+1;
 insert into app_private.finance_operations values(p_key,p_order,rh,p_action,reason,auth.uid(),now());
 return public.admin_order_finance(p_order);
end $$;

-- Preserve immutable original receipts; record actual receipt dates additively for new verification.
create or replace function public.review_manual_payment(p_order uuid,p_revision integer,p_action text,p_key uuid,p_data jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;stamp timestamptz;begin
 perform app_private.require_admin();perform pg_advisory_xact_lock(73525);
 if p_action='verify' then
 stamp=coalesce(nullif(p_data->>'actualReceivedAt','')::timestamptz,now());
 if stamp>now()+interval '1 minute' or stamp<(select created_at from public.orders where id=p_order) then raise exception 'Choose the actual receipt date between order placement and now';end if;
 end if;
 result=app_private.review_manual_payment_016(p_order,p_revision,p_action,p_key,p_data);
 if p_action='verify' and exists(select 1 from app_private.payment_receipts where id=p_key and order_id=p_order) then
 insert into app_private.receipt_dates(receipt_id,actual_received_at,actor_id) values(p_key,stamp,auth.uid()) on conflict(receipt_id) do nothing;
 end if;return result;
end $$;
create or replace function public.admin_order_action(p_id uuid,p_revision integer,p_action text,p_key uuid) returns jsonb language plpgsql security definer set search_path='' as $$ begin
 perform app_private.require_admin();perform pg_advisory_xact_lock(73525);
 if p_action in('confirm','dispatch') and not exists(select 1 from app_private.order_events where operation_key=p_key) and exists(select 1 from app_private.refund_requests where order_id=p_id and state='approved' and merchandise_minor+shipping_minor>0) then raise exception 'Resolve or cancel the approved unsent item/shipping refund before fulfilment';end if;
 return app_private.admin_order_action_016(p_id,p_revision,p_action,p_key);
end $$;
create function app_private.reporting_events() returns table(id text,order_id uuid,order_number text,event text,occurred_at timestamptz,merchandise_minor bigint,shipping_minor bigint,receipts_minor bigint,refunds_minor bigint) language sql stable set search_path='' as $$
 select 'sale:'||s.order_id,s.order_id,c.order_number,'completed',s.completed_at,s.merchandise_minor,s.shipping_minor,0::bigint,0::bigint from app_private.completed_sales s join app_private.commerce_orders c on c.order_id=s.order_id
 union all select 'receipt:'||p.id,p.order_id,c.order_number,'receipt',coalesce(d.actual_received_at,p.received_at),0,0,p.amount_minor,0 from app_private.payment_receipts p join app_private.commerce_orders c on c.order_id=p.order_id left join app_private.receipt_dates d on d.receipt_id=p.id
 union all select 'refund:'||e.id,e.order_id,c.order_number,case when e.action='send' then 'refund sent' else 'refund record reversal' end,e.occurred_at,case when e.sales_applicable then (case when e.action='send' then -1 else 1 end)*e.merchandise_minor else 0 end,case when e.sales_applicable then (case when e.action='send' then -1 else 1 end)*e.shipping_minor else 0 end,0,case when e.action='send' then e.amount_minor else -e.amount_minor end from app_private.refund_events e join app_private.commerce_orders c on c.order_id=e.order_id where e.action in('send','reverse')
 union all select 'recognition:'||e.id,e.order_id,c.order_number,'earlier refund recognized on completion',greatest(s.completed_at,e.recorded_at),-e.merchandise_minor,-e.shipping_minor,0,0 from app_private.refund_events e join app_private.completed_sales s on s.order_id=e.order_id join app_private.commerce_orders c on c.order_id=e.order_id where e.action='send' and e.merchandise_minor+e.shipping_minor>0 and not e.sales_applicable and s.completed_at>e.occurred_at and not exists(select 1 from app_private.refund_events rev where rev.reverses=e.id and rev.occurred_at<=greatest(s.completed_at,e.recorded_at));
$$;
create function public.admin_sales_report(p_from date default null,p_to date default null,p_grain text default 'day',p_offset integer default 0,p_limit integer default 25,p_components boolean default false,p_export boolean default false,p_development boolean default false) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a timestamptz;b timestamptz;result jsonb;begin
 perform app_private.require_admin();if p_offset is null or p_limit is null or p_grain is null or p_components is null or p_export is null or p_development is null or p_offset not between 0 and 100000 or p_limit not between 1 and 100 or p_grain not in('day','month') or p_from>p_to then raise exception 'Choose a valid reporting period/page';end if;
 a=coalesce(p_from::timestamp at time zone 'Asia/Karachi','-infinity'::timestamptz);b=coalesce((p_to+1)::timestamp at time zone 'Asia/Karachi','infinity'::timestamptz);
 if p_export and (select count(*) from app_private.reporting_events() ev where occurred_at>=a and occurred_at<b and exists(select 1 from app_private.commerce_orders scope where scope.order_id=ev.order_id and scope.configuration_snapshot->>'mode'=case when p_development then 'development' else 'approved' end))>5000 then raise exception 'Narrow the date range to export at most 5,000 events';end if;
 with ev as materialized(select * from app_private.reporting_events() ev where occurred_at>=a and occurred_at<b and exists(select 1 from app_private.commerce_orders scope where scope.order_id=ev.order_id and scope.configuration_snapshot->>'mode'=case when p_development then 'development' else 'approved' end)),
 top_lines as(select case when i.deal_id is null then 'product' else 'deal' end kind,coalesce(i.deal_id,i.variant_id) entity_id,i.name_snapshot name,i.quantity,i.line_total_minor amount from app_private.completed_sales s join public.order_items i on i.order_id=s.order_id where s.completed_at>=a and s.completed_at<b and not p_components and exists(select 1 from app_private.commerce_orders scope where scope.order_id=s.order_id and scope.configuration_snapshot->>'mode'=case when p_development then 'development' else 'approved' end)
 union all select 'component',f.variant_id,f.name,f.quantity,f.attributed_minor from app_private.completed_sales s cross join lateral app_private.finance_components(s.order_id) f where s.completed_at>=a and s.completed_at<b and p_components and exists(select 1 from app_private.commerce_orders scope where scope.order_id=s.order_id and scope.configuration_snapshot->>'mode'=case when p_development then 'development' else 'approved' end))
 select jsonb_build_object('from',p_from,'to',p_to,'timezone','Asia/Karachi','development',p_development,'totalEvents',(select count(*) from ev),'offset',p_offset,
 'totals',(select jsonb_build_object('completedOrders',count(*) filter(where event='completed'),'grossMerchandiseMinor',(coalesce(sum(merchandise_minor) filter(where event='completed'),0))::text,'salesRefundsMinor',(-coalesce(sum(merchandise_minor) filter(where event<>'completed'),0))::text,'netMerchandiseMinor',(coalesce(sum(merchandise_minor),0))::text,'shippingChargedMinor',(coalesce(sum(shipping_minor) filter(where event='completed'),0))::text,'shippingRefundsMinor',(-coalesce(sum(shipping_minor) filter(where event<>'completed'),0))::text,'receiptsMinor',(coalesce(sum(receipts_minor),0))::text,'refundsSentMinor',(coalesce(sum(refunds_minor),0))::text,'netCashMinor',(coalesce(sum(receipts_minor-refunds_minor),0))::text) from ev),
 'trend',coalesce((select jsonb_agg(t order by t.period) from(select date_trunc(p_grain,occurred_at at time zone 'Asia/Karachi')::date period,count(*) filter(where event='completed') orders,sum(merchandise_minor)::text merchandise_minor,sum(receipts_minor)::text receipts_minor,sum(refunds_minor)::text refunds_minor from ev group by 1 order by 1 desc limit 400)t),'[]'),
 'top',coalesce((select jsonb_agg(t order by t.amount_minor::numeric desc,t.name) from(select kind,entity_id,min(name) name,sum(quantity) units,sum(amount)::text amount_minor from top_lines group by kind,entity_id order by sum(amount) desc,entity_id limit 20)t),'[]'),
 'events',coalesce((select jsonb_agg(t order by t.occurred_at desc,t.id desc) from(select * from ev order by occurred_at desc,id desc limit case when p_export then 5000 else p_limit end offset case when p_export then 0 else p_offset end)t),'[]'),
 'resolution',jsonb_build_object('cancelledOrders',(select count(*) from app_private.order_events where action='cancel' and occurred_at>=a and occurred_at<b and exists(select 1 from app_private.commerce_orders scope where scope.order_id=app_private.order_events.order_id and scope.configuration_snapshot->>'mode'=case when p_development then 'development' else 'approved' end)),'receivedNeedingResolutionMinor',(select coalesce(sum(greatest(0,(select coalesce(sum(amount_minor),0) from app_private.payment_receipts where order_id=c.order_id)-(select coalesce(sum(amount_minor),0) from app_private.refund_requests where order_id=c.order_id and state='sent'))),0)::text from app_private.commerce_orders c where c.payment_status='received_resolution_required' and c.configuration_snapshot->>'mode'=case when p_development then 'development' else 'approved' end)))
 into result;return result;
end $$;
revoke all on function app_private.record_completed_sale(),app_private.finance_components(uuid),app_private.refund_quote(uuid,jsonb,uuid),app_private.reporting_events() from public,anon,authenticated,service_role;
revoke all on function public.admin_order_finance(uuid),public.admin_finance_action(uuid,integer,uuid,text,jsonb),public.admin_sales_report(date,date,text,integer,integer,boolean,boolean,boolean) from public,anon,authenticated,service_role;
grant execute on function public.admin_order_finance(uuid),public.admin_finance_action(uuid,integer,uuid,text,jsonb),public.admin_sales_report(date,date,text,integer,integer,boolean,boolean,boolean) to authenticated;

insert into app_private.sql_editor_receipts(version,filename,sha256) values('202610180020','202610180020_reports_refunds_returns.sql','3a274cb58a5da769a57ee7ab0dfb5877b68bb82adcf92caba1031ca1e4b6b434');notify pgrst,'reload schema';commit;
-- READ ONLY. Before: prerequisite_019, history_complete and no_client_policies true;
-- new object/receipt/RLS/grant flags false. All flags true after installation.
select exists(select 1 from app_private.sql_editor_receipts where version='202610180019' and sha256='19ee24e376d66ad9dca4e09cc5bec42b1a703e3dfb69011849eef0dd8796623c') prerequisite_019,
 not exists(select 1 from app_private.commerce_orders c where c.fulfilment='completed' and not exists(select 1 from app_private.order_events e where e.order_id=c.order_id and e.action='complete')) history_complete,
 to_regclass('app_private.completed_sales') is not null sales_present,
 to_regclass('app_private.refund_requests') is not null refunds_present,
 to_regclass('app_private.return_events') is not null returns_present,
 to_regprocedure('public.admin_order_finance(uuid)') is not null finance_present,
 to_regprocedure('public.admin_finance_action(uuid,integer,uuid,text,jsonb)') is not null action_present,
 to_regprocedure('public.admin_sales_report(date,date,text,integer,integer,boolean,boolean,boolean)') is not null reports_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610180020') receipt_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610180020' and sha256='3a274cb58a5da769a57ee7ab0dfb5877b68bb82adcf92caba1031ca1e4b6b434') receipt_matches,
 (select count(*)=7 and bool_and(relrowsecurity and not relforcerowsecurity) from pg_class where oid in(to_regclass('app_private.receipt_dates'),to_regclass('app_private.completed_sales'),to_regclass('app_private.finance_versions'),to_regclass('app_private.refund_requests'),to_regclass('app_private.refund_events'),to_regclass('app_private.return_events'),to_regclass('app_private.finance_operations'))) private_rls,
 not exists(select 1 from pg_policies where schemaname='app_private' and tablename in('receipt_dates','completed_sales','finance_versions','refund_requests','refund_events','return_events','finance_operations')) no_client_policies,
 (select count(*)=7 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='app_private' and c.relname in('receipt_dates','completed_sales','finance_versions','refund_requests','refund_events','return_events','finance_operations')) and not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join (values('anon'),('authenticated'),('service_role'))roles(name) cross join (values('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),('REFERENCES'),('TRIGGER'))privileges(name) where n.nspname='app_private' and c.relname in('receipt_dates','completed_sales','finance_versions','refund_requests','refund_events','return_events','finance_operations') and has_table_privilege(roles.name,c.oid,privileges.name)) private_grants,
 (select count(*)=5 and bool_and(p.prosecdef and p.proowner='postgres'::regrole and p.proconfig @> array['search_path=""'] and position('require_admin()' in p.prosrc)>0 and has_function_privilege('authenticated',p.oid,'EXECUTE') and not has_function_privilege('anon',p.oid,'EXECUTE') and not has_function_privilege('service_role',p.oid,'EXECUTE') and not exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl where acl.grantee=0 and acl.privilege_type='EXECUTE')) from pg_proc p where p.oid in(to_regprocedure('public.admin_order_finance(uuid)'),to_regprocedure('public.admin_finance_action(uuid,integer,uuid,text,jsonb)'),to_regprocedure('public.admin_sales_report(date,date,text,integer,integer,boolean,boolean,boolean)'),to_regprocedure('public.admin_order_action(uuid,integer,text,uuid)'),to_regprocedure('public.review_manual_payment(uuid,integer,text,uuid,jsonb)'))) rpc_security,
 coalesce((select not has_function_privilege('anon',oid,'EXECUTE') and not has_function_privilege('service_role',oid,'EXECUTE') and has_function_privilege('authenticated',oid,'EXECUTE') and prosecdef and proowner='postgres'::regrole from pg_proc where oid=to_regprocedure('public.admin_finance_action(uuid,integer,uuid,text,jsonb)')),false) action_grants;
