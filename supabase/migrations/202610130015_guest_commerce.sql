-- Incremental commerce boundary. Existing business rows are not rewritten.
create sequence app_private.order_numbers;
create table app_private.commerce_orders (
 order_id uuid primary key references public.orders(id), order_number text not null unique,
 session_hash text not null check(session_hash ~ '^[a-f0-9]{64}$'), token_hash text not null check(token_hash ~ '^[a-f0-9]{64}$'),
 request_hash text not null, revision integer not null default 1,
 fulfilment text not null check(fulfilment in('placed','confirmed','dispatched','completed','cancelled','expired')),
 payment_status text not null check(payment_status in('due_on_delivery','awaiting_payment')),
 allocation text not null check(allocation in('temporary','accepted','released','consumed')),
 payment_snapshot jsonb not null, shipping_snapshot jsonb not null, configuration_snapshot jsonb not null,
 note text, hold_expires_at timestamptz, created_at timestamptz not null default now()
);
create table app_private.order_events (
 id bigint generated always as identity primary key, order_id uuid not null references public.orders(id),
 operation_key uuid not null unique, action text not null, revision integer not null,
 actor_id uuid references auth.users(id), occurred_at timestamptz not null default now()
);
create table app_private.checkout_rate_buckets (
 key text not null, hour timestamptz not null, attempts integer not null, primary key(key,hour)
);
alter table app_private.commerce_orders enable row level security;
alter table app_private.order_events enable row level security;
alter table app_private.checkout_rate_buckets enable row level security;
revoke all on app_private.commerce_orders,app_private.order_events,app_private.checkout_rate_buckets,app_private.order_numbers from public,anon,authenticated;
-- Managed order writes happen through validated transactional RPCs, not generic admin table writes.
revoke insert,update,delete on public.orders,public.order_items from authenticated;
create index commerce_orders_created on app_private.commerce_orders(created_at,order_id);
create index commerce_orders_holds on app_private.commerce_orders(hold_expires_at,order_id) where allocation='temporary';
create index commerce_order_events on app_private.order_events(order_id,occurred_at,id);

create function app_private.commerce_lines(p_lines jsonb) returns void language plpgsql set search_path='' as $lines$
begin
 if p_lines is null or jsonb_typeof(p_lines)<>'array' or jsonb_array_length(p_lines) not between 1 and 20 or length(p_lines::text)>12000 then raise exception 'Invalid cart';end if;
 if exists(select 1 from jsonb_array_elements(p_lines) x where jsonb_typeof(x)<>'object' or x->>'id' is null or x->>'id' !~ '^[a-f0-9-]{36}$' or (x->>'quantity') is null or (x->>'quantity') !~ '^[0-9]{1,3}$' or (x->>'quantity')::integer not between 1 and 99) then raise exception 'Invalid cart line';end if;
 if (select count(distinct (x->>'id')::uuid) from jsonb_array_elements(p_lines) x)<>jsonb_array_length(p_lines) then raise exception 'Duplicate variant';end if;
end $lines$;

create function public.commerce_quote(p_lines jsonb) returns jsonb language plpgsql stable security definer set search_path='' as $quote$
declare result jsonb;begin
 perform app_private.commerce_lines(p_lines);
 with requested as(select (x->>'id')::uuid id,(x->>'quantity')::int quantity,x->>'expectedPriceMinor' expected from jsonb_array_elements(p_lines) x), eligible as(
 select v.id,p.name,coalesce(v.label,'') label,v.original_sku sku,p.slug,b.name brand,pr.amount_minor price,
 coalesce(i.on_hand-i.reserved,0) available from public.variants v join public.products p on p.id=v.product_id
 join public.variant_prices pr on pr.variant_id=v.id left join public.inventory_balances i on i.variant_id=v.id left join public.brands b on b.id=p.brand_id
 where v.id in(select id from requested) and public.variant_is_public(v.id) and public.product_is_public(p.id)
 ), lines as(select r.id,r.quantity,e.name,e.label,e.sku,e.slug,e.brand,e.price price_minor,e.available,
 e.id is not null eligible,(e.id is not null and e.available>=r.quantity) valid,
 case when e.id is null then 'unavailable' when e.available<r.quantity then 'stock_changed' when r.expected is not null and r.expected<>e.price::text then 'price_changed' else null end issue
 from requested r left join eligible e on e.id=r.id)
 select jsonb_build_object('lines',jsonb_agg(l order by l.id),'valid',bool_and(l.valid),'subtotal_minor',coalesce(sum(l.price_minor*l.quantity),0)) into result from lines l;
 if (result->>'subtotal_minor')::numeric>9007199254740991 then raise exception 'Cart total too large';end if;
 return result;
end $quote$;
revoke all on function public.commerce_quote(jsonb) from public;
grant execute on function public.commerce_quote(jsonb) to anon,authenticated,service_role;

create function app_private.reserve_inventory(p_order uuid,p_key text,p_expires timestamptz)
returns void language plpgsql security definer set search_path='' as $$
declare item record; part record; units integer; prior integer;
begin
  if p_key is null or p_key='' then raise exception 'Idempotency key required'; end if;
  perform 1 from public.orders where id=p_order and status in ('draft','placed') for update;
  if not found then raise exception 'Order is not reservable'; end if;
  if exists(select 1 from public.inventory_reservations where order_id=p_order) then
    if exists(select 1 from public.inventory_reservations where order_id=p_order and idempotency_key <> p_key||':'||variant_id::text) then raise exception 'Order already reserved with another key'; end if;
    return;
  end if;
  if p_expires<=now() or p_expires>now()+interval '7 days' then raise exception 'Invalid reservation expiry'; end if;
  if not exists(select 1 from public.order_items where order_id=p_order) then raise exception 'Empty order'; end if;
  for item in select * from public.order_items where order_id=p_order order by id loop
    if item.variant_id is not null then
      insert into public.order_item_components values(item.id,item.variant_id,item.quantity);
    else
      if not exists(select 1 from public.deal_components where deal_id=item.deal_id) then raise exception 'Empty deal'; end if;
      insert into public.order_item_components select item.id,variant_id,quantity*item.quantity from public.deal_components where deal_id=item.deal_id;
    end if;
  end loop;
  -- Deterministic row locking, aggregate shared components across all lines.
  for part in select c.variant_id,sum(c.quantity)::integer qty from public.order_item_components c
    join public.order_items i on i.id=c.order_item_id where i.order_id=p_order group by c.variant_id order by c.variant_id loop
    update public.inventory_balances set reserved=reserved+part.qty where variant_id=part.variant_id and on_hand-reserved>=part.qty;
    if not found then raise exception 'Insufficient stock'; end if;
    insert into public.inventory_reservations(order_id,variant_id,quantity,expires_at,idempotency_key)
      values(p_order,part.variant_id,part.qty,p_expires,p_key||':'||part.variant_id);
  end loop;
end $$;
create function app_private.finish_inventory(p_order uuid,p_consume boolean) returns void
language plpgsql security definer set search_path='' as $$ declare r record; begin
  perform 1 from public.orders where id=p_order for update;
  for r in select * from public.inventory_reservations where order_id=p_order and state='active' order by variant_id for update loop
    if p_consume and r.expires_at<=now() then raise exception 'Reservation expired'; end if;
    update public.inventory_balances set reserved=reserved-r.quantity,on_hand=on_hand-case when p_consume then r.quantity else 0 end where variant_id=r.variant_id;
    update public.inventory_reservations set state=case when p_consume then 'consumed' else 'released' end where id=r.id;
    if p_consume then
      insert into public.inventory_movements(variant_id,delta,reason,idempotency_key,order_id,actor_id)
        values(r.variant_id,-r.quantity,'order consumption','reservation:'||r.id,p_order,auth.uid());
    end if;
  end loop;
end $$;


-- Fail closed on incomplete/corrupt allocations; never guess stock corrections.
create function app_private.assert_order_allocation(p_order uuid,p_state text,p_allow_expired boolean default false)
returns void language plpgsql set search_path='' as $allocation$
begin
 if p_state not in('active','consumed') or not exists(select 1 from public.order_items where order_id=p_order) then raise exception 'Order allocation is incomplete';end if;
 if exists(select 1 from public.order_items i left join public.order_item_components c on c.order_item_id=i.id and c.variant_id=i.variant_id where i.order_id=p_order and (i.variant_id is null or c.quantity is distinct from i.quantity))
 or exists(select 1 from public.order_item_components c join public.order_items i on i.id=c.order_item_id where i.order_id=p_order and c.variant_id is distinct from i.variant_id) then raise exception 'Order component allocation is incomplete';end if;
 -- Same deterministic inventory-lock order as the shared reservation primitive.
 perform 1 from public.inventory_balances b where b.variant_id in(select variant_id from public.order_items where order_id=p_order) order by b.variant_id for update;
 perform 1 from public.inventory_reservations where order_id=p_order order by variant_id,id for update;
 if exists(
 with expected as(select variant_id,sum(quantity) qty from public.order_items where order_id=p_order group by variant_id),
 actual as(select variant_id,sum(quantity) qty,count(*) copies,bool_and(state=p_state) states_ok from public.inventory_reservations where order_id=p_order group by variant_id)
 select 1 from expected e full join actual r on r.variant_id=e.variant_id where e.variant_id is null or r.variant_id is null or e.qty<>r.qty or r.copies<>1 or not r.states_ok
 ) then raise exception 'Order reservation is missing, partial or inconsistent. Reconcile before proceeding';end if;
 if exists(select 1 from public.order_items i left join public.inventory_balances b on b.variant_id=i.variant_id where i.order_id=p_order and (b.variant_id is null or b.reconciled_at is null)) then raise exception 'Counted inventory is missing';end if;
 if exists(select 1 from public.inventory_balances b where b.variant_id in(select variant_id from public.order_items where order_id=p_order) and b.reserved<>(select coalesce(sum(r.quantity),0) from public.inventory_reservations r where r.variant_id=b.variant_id and r.state='active')) then raise exception 'Reserved inventory does not match active allocations. Reconcile before proceeding';end if;
 if p_state='active' then
 if not p_allow_expired and exists(select 1 from public.inventory_reservations where order_id=p_order and expires_at<=now()) then raise exception 'Order hold expired';end if;
 if exists(select 1 from public.inventory_reservations r join app_private.commerce_orders c on c.order_id=r.order_id where r.order_id=p_order and ((c.allocation='accepted' and r.expires_at<>'infinity'::timestamptz) or (c.allocation='temporary' and r.expires_at is distinct from c.hold_expires_at))) then raise exception 'Order reservation lifecycle is inconsistent';end if;
 else
 if exists(select 1 from public.inventory_reservations r left join public.inventory_movements m on m.idempotency_key='reservation:'||r.id::text where r.order_id=p_order and (m.id is null or m.order_id is distinct from r.order_id or m.variant_id<>r.variant_id or m.delta<>-r.quantity)) then raise exception 'Dispatch consumption history is incomplete';end if;
 end if;
end $allocation$;

create or replace function public.reserve_order(p_order uuid,p_key text,p_expires timestamptz) returns void language plpgsql security definer set search_path='' as $reserve$
begin perform app_private.require_admin();
 if exists(select 1 from app_private.commerce_orders where order_id=p_order) then raise exception 'Use validated order actions';end if;
 perform app_private.reserve_inventory(p_order,p_key,p_expires);
end $reserve$;
create or replace function public.finish_reservation(p_order uuid,p_consume boolean) returns void language plpgsql security definer set search_path='' as $finish$
begin perform app_private.require_admin();
 if exists(select 1 from app_private.commerce_orders where order_id=p_order) then raise exception 'Use validated order actions';end if;
 perform app_private.finish_inventory(p_order,p_consume);
end $finish$;

create function public.commerce_rate(p_rate text) returns void language plpgsql security definer set search_path='' as $rate$
declare n integer;k text;cap integer;begin
 if p_rate is null or p_rate !~ '^[a-f0-9]{64}$' then raise exception 'Invalid protection key';end if;
 foreach k in array array['global','visitor:'||p_rate] loop
 cap=case when k='global' then 300 else 20 end;
 insert into app_private.checkout_rate_buckets(key,hour,attempts) values(k,date_trunc('hour',now()),1)
 on conflict(key,hour) do update set attempts=app_private.checkout_rate_buckets.attempts+1 returning attempts into n;
 if n>cap then raise exception 'Checkout rate limit' using errcode='P0429';end if;
 end loop;
end $rate$;

create function app_private.commerce_view(p_order uuid) returns jsonb language sql stable set search_path='' as $view$
 select jsonb_build_object('id',o.id,'number',c.order_number,'revision',c.revision,'fulfilment',c.fulfilment,'paymentStatus',c.payment_status,
 'subtotalMinor',o.subtotal_minor,'shippingMinor',o.shipping_minor,'totalMinor',o.total_minor,'name',o.delivery_name,'phone',o.contact_phone,'email',o.contact_email,'address',o.address,'note',c.note,'createdAt',o.created_at,
 'shipping',c.shipping_snapshot,'payment',c.payment_snapshot,'holdExpiresAt',c.hold_expires_at,
 'items',(select jsonb_agg(jsonb_build_object('name',i.name_snapshot,'sku',i.sku_snapshot,'quantity',i.quantity,'unitPriceMinor',i.unit_price_minor,'totalMinor',i.line_total_minor) order by i.id) from public.order_items i where i.order_id=o.id),
 'history',(select jsonb_agg(jsonb_build_object('action',e.action,'at',e.occurred_at,'revision',e.revision) order by e.id) from app_private.order_events e where e.order_id=o.id))
 from public.orders o join app_private.commerce_orders c on c.order_id=o.id where o.id=p_order;
$view$;

create function public.place_guest_order(p_id uuid,p_session text,p_token text,p_lines jsonb,p_customer jsonb,p_shipping jsonb,p_payment jsonb,p_config jsonb) returns jsonb
language plpgsql security definer set search_path='' set statement_timeout='15s' as $place$
declare prior app_private.commerce_orders;rh text;q jsonb;l jsonb;shipping bigint;total bigint;expiry timestamptz;allocation text;number text;begin
 if p_id is null or p_session is null or p_session !~ '^[a-f0-9]{64}$' or p_token is null or p_token !~ '^[a-f0-9]{64}$' then raise exception 'Invalid ownership';end if;
 perform app_private.commerce_lines(p_lines);
 if p_customer is null or jsonb_typeof(p_customer)<>'object' or length(p_customer::text)>3000 or length(btrim(coalesce(p_customer->>'name',''))) not between 2 and 120 or coalesce(p_customer->>'phone','') !~ '^\+923[0-9]{9}$' or length(btrim(coalesce(p_customer->>'address',''))) not between 5 and 500 or length(btrim(coalesce(p_customer->>'city',''))) not between 2 and 100 or length(coalesce(p_customer->>'email',''))>254 or (coalesce(p_customer->>'email','')<>'' and p_customer->>'email' !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$') or length(coalesce(p_customer->>'note',''))>1000 then raise exception 'Check delivery details';end if;
 if p_shipping is null or p_payment is null or p_config is null or length((p_shipping||p_payment||p_config)::text)>5000 or p_config->>'mode' not in('development','approved') or p_config->>'version' is null or coalesce(p_shipping->>'feeMinor','') !~ '^[0-9]{1,12}$' or p_payment->>'allocation' not in('accepted','temporary') then raise exception 'Checkout settings incomplete';end if;
 shipping=(p_shipping->>'feeMinor')::bigint;
 rh=encode(pg_catalog.sha256(convert_to(jsonb_build_array(p_lines,p_customer,p_shipping,p_payment,p_config)::text,'UTF8')),'hex');
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,715));
 select * into prior from app_private.commerce_orders where order_id=p_id;
 if found then
 if prior.session_hash<>p_session or prior.token_hash<>p_token or prior.request_hash<>rh then raise exception 'Idempotency conflict';end if;
 return app_private.commerce_view(p_id);
 end if;
 -- Stable locks also prevent visibility/price/physical-count changes during placement.
 perform 1 from public.products where id in(select v.product_id from public.variants v where v.id in(select (x->>'id')::uuid from jsonb_array_elements(p_lines) x)) order by id for share;
 perform 1 from public.variants where id in(select (x->>'id')::uuid from jsonb_array_elements(p_lines) x) order by id for share;
 perform 1 from public.variant_prices where variant_id in(select (x->>'id')::uuid from jsonb_array_elements(p_lines) x) order by variant_id for share;
 q=public.commerce_quote(p_lines);
 if not (q->>'valid')::boolean then raise exception 'Availability changed. Review your bag';end if;
 if exists(select 1 from jsonb_array_elements(q->'lines') x where x->>'issue'='price_changed') or exists(select 1 from jsonb_array_elements(p_lines) x where x->>'expectedPriceMinor' is null) then raise exception 'Prices changed. Review your bag';end if;
 total=(q->>'subtotal_minor')::bigint+shipping;
 if total>9007199254740991 then raise exception 'Order total too large';end if;
 insert into public.orders(id,delivery_name,contact_phone,contact_email,address) values(p_id,p_customer->>'name',p_customer->>'phone',nullif(p_customer->>'email',''),jsonb_build_object('country','PK','address',p_customer->>'address','city',p_customer->>'city'));
 for l in select value from jsonb_array_elements(q->'lines') loop
 insert into public.order_items(order_id,variant_id,name_snapshot,sku_snapshot,quantity,unit_price_minor,line_total_minor) values(p_id,(l->>'id')::uuid,l->>'name'||case when l->>'label'<>'' then ' - '||(l->>'label') else '' end,l->>'sku',(l->>'quantity')::int,(l->>'price_minor')::bigint,(l->>'price_minor')::bigint*(l->>'quantity')::int);
 end loop;
 allocation=p_payment->>'allocation';expiry=now()+interval '20 minutes';
 perform app_private.reserve_inventory(p_id,p_id::text,expiry);
 if allocation='accepted' then update public.inventory_reservations set expires_at='infinity' where order_id=p_id;end if;
 number='NG-'||lpad(nextval('app_private.order_numbers')::text,8,'0');
 insert into app_private.commerce_orders(order_id,order_number,session_hash,token_hash,request_hash,fulfilment,payment_status,allocation,payment_snapshot,shipping_snapshot,configuration_snapshot,note,hold_expires_at)
 values(p_id,number,p_session,p_token,rh,'placed',case when allocation='accepted' then 'due_on_delivery' else 'awaiting_payment' end,allocation,p_payment,p_shipping,p_config,nullif(p_customer->>'note',''),case when allocation='temporary' then expiry else null end);
 update public.orders set status='placed',subtotal_minor=(q->>'subtotal_minor')::bigint,shipping_minor=shipping,total_minor=total,updated_at=now() where id=p_id;
 perform app_private.assert_order_allocation(p_id,'active');
 insert into app_private.order_events(order_id,operation_key,action,revision) values(p_id,p_id,'placed',1);
 return app_private.commerce_view(p_id);
end $place$;

create function public.guest_order_confirmation(p_id uuid,p_session text,p_token text) returns jsonb language plpgsql stable security definer set search_path='' as $guest$
begin
 if not exists(select 1 from app_private.commerce_orders where order_id=p_id and session_hash=p_session and token_hash=p_token) then raise exception 'Order confirmation unavailable' using errcode='P0404';end if;
 return app_private.commerce_view(p_id);
end $guest$;

create function public.admin_order_action(p_id uuid,p_revision integer,p_action text,p_key uuid) returns jsonb language plpgsql security definer set search_path='' as $action$
declare c app_private.commerce_orders;e app_private.order_events;next_status text;begin
 perform app_private.require_admin();if p_key is null or p_action not in('confirm','dispatch','complete','cancel') then raise exception 'Invalid order action';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_key::text,716));
 select * into c from app_private.commerce_orders where order_id=p_id for update;
 if not found then raise exception 'Order not found';end if;
 perform 1 from public.orders where id=p_id for update;
 select * into e from app_private.order_events where operation_key=p_key;
 if found then if e.order_id<>p_id or e.action<>p_action then raise exception 'Idempotency conflict';end if;return app_private.commerce_view(p_id);end if;
 if c.revision<>p_revision then raise exception 'Order changed. Refresh before retrying';end if;
 if c.allocation='temporary' and c.hold_expires_at<=now() and p_action<>'cancel' then raise exception 'Payment hold expired. Run expiry reconciliation';end if;
 if p_action in('confirm','dispatch') and (c.payment_status<>'due_on_delivery' or c.payment_snapshot->>'allocation' is distinct from 'accepted') then raise exception 'Payment is not ready. Unpaid payment holds cannot be confirmed or dispatched';end if;
 if p_action in('confirm','dispatch') and c.allocation<>'accepted' then raise exception 'Order allocation must be accepted before fulfilment';end if;
 if p_action='confirm' and c.fulfilment='placed' then
 perform app_private.assert_order_allocation(p_id,'active');
 next_status='confirmed';update public.inventory_reservations set expires_at='infinity' where order_id=p_id and state='active';
 elsif p_action='dispatch' and c.fulfilment='confirmed' then
 perform app_private.assert_order_allocation(p_id,'active');
 next_status='dispatched';perform app_private.finish_inventory(p_id,true);
 perform app_private.assert_order_allocation(p_id,'consumed');
 elsif p_action='complete' and c.fulfilment='dispatched' then
 if c.allocation<>'consumed' then raise exception 'Dispatch allocation is not consumed';end if;
 perform app_private.assert_order_allocation(p_id,'consumed');next_status='completed';
 elsif p_action='cancel' and c.fulfilment in('placed','confirmed') then perform app_private.assert_order_allocation(p_id,'active',true);next_status='cancelled';perform app_private.finish_inventory(p_id,false);
 else raise exception 'This action is unavailable for the current status';end if;
 update app_private.commerce_orders set fulfilment=next_status,revision=revision+1,allocation=case when next_status='cancelled' then 'released' when next_status in('dispatched','completed') then 'consumed' else 'accepted' end,hold_expires_at=null where order_id=p_id;
 update public.orders set status=case when next_status='cancelled' then 'cancelled' when next_status='completed' then 'fulfilled' else 'placed' end,updated_at=now() where id=p_id;
 insert into app_private.order_events(order_id,operation_key,action,revision,actor_id) values(p_id,p_key,p_action,c.revision+1,auth.uid());
 return app_private.commerce_view(p_id);
end $action$;

create function public.expire_commerce_holds(p_limit integer default 100) returns integer language plpgsql security definer set search_path='' as $expire$
declare c record;n integer=0;begin
 if p_limit not between 1 and 500 then raise exception 'Invalid batch limit';end if;
 for c in select * from app_private.commerce_orders where allocation='temporary' and fulfilment='placed' and hold_expires_at<=now() order by hold_expires_at,order_id limit p_limit for update skip locked loop
 perform app_private.assert_order_allocation(c.order_id,'active',true);
 perform app_private.finish_inventory(c.order_id,false);
 update app_private.commerce_orders set fulfilment='expired',allocation='released',revision=revision+1 where order_id=c.order_id;
 update public.orders set status='cancelled',updated_at=now() where id=c.order_id;
 insert into app_private.order_events(order_id,operation_key,action,revision) values(c.order_id,gen_random_uuid(),'expired',c.revision+1);n=n+1;
 end loop;return n;
end $expire$;

create function public.commerce_reconciliation() returns jsonb language sql stable security definer set search_path='' as $reconcile$
 select jsonb_build_object('balanceMismatches',(select count(*) from public.inventory_balances b where b.reserved<>(select coalesce(sum(r.quantity),0) from public.inventory_reservations r where r.variant_id=b.variant_id and r.state='active')),
 'overdueHolds',(select count(*) from app_private.commerce_orders where allocation='temporary' and fulfilment='placed' and hold_expires_at<=now()));
$reconcile$;

create function public.admin_orders(p_query text default '',p_status text default '',p_from date default null,p_to date default null,p_offset integer default 0,p_id uuid default null) returns jsonb language plpgsql stable security definer set search_path='' as $orders$
begin
 perform app_private.require_admin();if length(p_query)>120 or p_offset not between 0 and 100000 or p_status not in('','placed','confirmed','dispatched','completed','cancelled','expired') or (p_from is not null and p_to is not null and p_from>p_to) then raise exception 'Invalid order filters';end if;
 if p_id is not null then return app_private.commerce_view(p_id);end if;
 return(with matched as(select c.order_id from app_private.commerce_orders c join public.orders o on o.id=c.order_id where
 (p_status='' or c.fulfilment=p_status) and (p_from is null or o.created_at>=p_from::timestamp at time zone 'Asia/Karachi') and (p_to is null or o.created_at<(p_to+1)::timestamp at time zone 'Asia/Karachi') and
 (btrim(p_query)='' or position(lower(btrim(p_query)) in lower(c.order_number||' '||o.delivery_name||' '||o.contact_phone))>0 or exists(select 1 from public.order_items i where i.order_id=o.id and position(lower(btrim(p_query)) in lower(i.name_snapshot||' '||i.sku_snapshot))>0)))
 select jsonb_build_object('total',(select count(*) from matched),'offset',p_offset,'rows',coalesce((select jsonb_agg(app_private.commerce_view(order_id)) from(select m.order_id from matched m join app_private.commerce_orders c on c.order_id=m.order_id order by c.created_at desc,c.order_id limit 25 offset p_offset) page),'[]')));
end $orders$;

-- New private functions never execute directly as client roles.
revoke all on function app_private.assert_order_allocation(uuid,text,boolean),app_private.commerce_lines(jsonb),app_private.reserve_inventory(uuid,text,timestamptz),app_private.finish_inventory(uuid,boolean),app_private.commerce_view(uuid) from public,anon,authenticated,service_role;
revoke all on function public.commerce_rate(text),public.place_guest_order(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb),public.guest_order_confirmation(uuid,text,text),public.expire_commerce_holds(integer),public.commerce_reconciliation(),public.admin_orders(text,text,date,date,integer,uuid),public.admin_order_action(uuid,integer,text,uuid) from public,anon,authenticated;
grant execute on function public.commerce_rate(text),public.place_guest_order(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb),public.guest_order_confirmation(uuid,text,text),public.expire_commerce_holds(integer),public.commerce_reconciliation() to service_role;
grant execute on function public.admin_orders(text,text,date,date,integer,uuid),public.admin_order_action(uuid,integer,text,uuid) to authenticated;
