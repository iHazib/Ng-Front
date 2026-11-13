create table public.orders (
  id uuid primary key default gen_random_uuid(), customer_id uuid references auth.users(id),
  status text not null default 'draft' check(status in ('draft','placed','cancelled','fulfilled')),
  currency text not null default 'PKR' check(currency='PKR'),
  subtotal_minor bigint not null default 0 check(subtotal_minor between 0 and 9007199254740991),
  shipping_minor bigint check(shipping_minor between 0 and 9007199254740991),
  discount_minor bigint not null default 0 check(discount_minor between 0 and subtotal_minor),
  total_minor bigint check(total_minor between 0 and 9007199254740991),
  contact_email text, contact_phone text, delivery_name text, address jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check(total_minor is null or (shipping_minor is not null and total_minor=subtotal_minor+shipping_minor-discount_minor))
);
create table public.deals (
  id uuid primary key default gen_random_uuid(), name text not null, slug text unique,
  status public.publication_status not null default 'draft',
  price_minor bigint check(price_minor between 1 and 9007199254740991),
  currency text not null default 'PKR' check(currency='PKR')
);
create table public.deal_components (
  deal_id uuid references public.deals(id), variant_id uuid references public.variants(id),
  quantity integer not null check(quantity between 1 and 10000), primary key(deal_id,variant_id)
);
create table public.order_items (
  id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id),
  variant_id uuid references public.variants(id), deal_id uuid references public.deals(id),
  name_snapshot text not null, sku_snapshot text, quantity integer not null check(quantity between 1 and 10000),
  unit_price_minor bigint not null check(unit_price_minor between 0 and 9007199254740991),
  line_total_minor bigint not null check(line_total_minor between 0 and 9007199254740991),
  check(num_nonnulls(variant_id,deal_id)=1), check(line_total_minor=quantity*unit_price_minor), unique(id,order_id)
);
create table public.order_item_components (
  order_item_id uuid references public.order_items(id), variant_id uuid references public.variants(id),
  quantity integer not null check(quantity>0), primary key(order_item_id,variant_id)
);
create table public.inventory_balances (
  variant_id uuid primary key references public.variants(id),
  on_hand integer not null default 0 check(on_hand>=0), reserved integer not null default 0 check(reserved between 0 and on_hand),
  reconciled_at timestamptz
);
create table public.inventory_movements (
  id uuid primary key default gen_random_uuid(), variant_id uuid not null references public.variants(id),
  delta integer not null check(delta<>0), reason text not null check(length(btrim(reason))>0),
  idempotency_key text not null unique, order_id uuid references public.orders(id),
  actor_id uuid references auth.users(id), created_at timestamptz not null default now()
);
create table public.inventory_reservations (
  id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id),
  variant_id uuid not null references public.variants(id), quantity integer not null check(quantity>0),
  state text not null default 'active' check(state in ('active','released','consumed')),
  expires_at timestamptz not null, idempotency_key text not null unique, created_at timestamptz not null default now()
);
create table public.sales (
  id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id),
  amount_minor bigint not null check(amount_minor between 1 and 9007199254740991),
  currency text not null default 'PKR' check(currency='PKR'), external_reference text,
  idempotency_key text not null unique, occurred_at timestamptz not null default now()
);
create table public.refunds (
  id uuid primary key default gen_random_uuid(), sale_id uuid not null references public.sales(id),
  amount_minor bigint not null check(amount_minor between 1 and 9007199254740991),
  reason text not null, idempotency_key text not null unique, occurred_at timestamptz not null default now()
);
create table public.shipments (
  id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id),
  provider text, tracking_reference text, status text not null default 'draft' check(status in ('draft','booked','in_transit','delivered','cancelled','returned')),
  created_at timestamptz not null default now(), dispatched_at timestamptz, delivered_at timestamptz,
  check(status='draft' or (provider is not null and tracking_reference is not null))
);
create table public.shipment_items (
  shipment_id uuid references public.shipments(id), order_item_id uuid references public.order_items(id),
  quantity integer not null check(quantity>0), primary key(shipment_id,order_item_id)
);
create table public.reviews (
  id uuid primary key default gen_random_uuid(), product_id uuid not null references public.products(id),
  display_name text not null, rating smallint not null check(rating between 1 and 5), body text not null,
  status public.review_status not null default 'pending', created_at timestamptz not null default now()
);
create table public.review_private (
  review_id uuid primary key references public.reviews(id), user_id uuid references auth.users(id),
  order_item_id uuid references public.order_items(id), moderation_note text,
  approved_by uuid references auth.users(id), approved_at timestamptz
);
create table public.articles (
  id uuid primary key default gen_random_uuid(), slug text unique, title text not null,
  excerpt text, body text, theme text check(theme in ('sage','warm','blush')),
  status public.publication_status not null default 'draft', published_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check(status<>'published' or (slug is not null and body is not null and published_at is not null))
);
create table public.article_media (
  article_id uuid references public.articles(id), media_id uuid references public.media_assets(id),
  position integer not null check(position>=0), primary key(article_id,media_id), unique(article_id,position)
);
create table public.homepage_selections (
  id uuid primary key default gen_random_uuid(), section text not null check(section in ('hero','the-edit','products','categories','brands')),
  position integer not null check(position>=0), status public.publication_status not null default 'draft',
  product_id uuid references public.products(id), article_id uuid references public.articles(id),
  category_id text references public.categories(id), brand_id text references public.brands(id), media_id uuid references public.media_assets(id),
  heading text, body text, cta_path text check(cta_path is null or cta_path ~ '^/[^/]'),
  unique(section,position), check(num_nonnulls(product_id,article_id,category_id,brand_id)<=1)
);

create function public.karachi_day_bounds(day date) returns table(start_at timestamptz,end_at timestamptz)
language sql immutable set search_path='' as $$
  select day::timestamp at time zone 'Asia/Karachi', (day+1)::timestamp at time zone 'Asia/Karachi'
$$;

create function public.adjust_inventory(p_variant uuid,p_delta integer,p_reason text,p_key text)
returns uuid language plpgsql security definer set search_path='' as $$
declare prior public.inventory_movements; result uuid;
begin
  perform app_private.require_admin();
  perform pg_advisory_xact_lock(hashtextextended(p_key,0));
  select * into prior from public.inventory_movements where idempotency_key=p_key;
  if found then
    if prior.variant_id<>p_variant or prior.delta<>p_delta or prior.reason<>p_reason then raise exception 'Idempotency conflict'; end if;
    return prior.id;
  end if;
  if p_delta=0 or p_reason is null or btrim(p_reason)='' or p_key is null or p_key='' then raise exception 'Invalid inventory adjustment'; end if;
  insert into public.inventory_balances(variant_id) values(p_variant) on conflict do nothing;
  update public.inventory_balances set on_hand=on_hand+p_delta,reconciled_at=now()
    where variant_id=p_variant and on_hand+p_delta>=reserved;
  if not found then raise exception 'Insufficient unreserved stock'; end if;
  insert into public.inventory_movements(variant_id,delta,reason,idempotency_key,actor_id)
    values(p_variant,p_delta,p_reason,p_key,auth.uid()) returning id into result;
  return result;
end $$;

create function public.reserve_order(p_order uuid,p_key text,p_expires timestamptz)
returns void language plpgsql security definer set search_path='' as $$
declare item record; part record; units integer; prior integer;
begin
  perform app_private.require_admin();
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
create function public.finish_reservation(p_order uuid,p_consume boolean) returns void
language plpgsql security definer set search_path='' as $$ declare r record; begin
  perform app_private.require_admin();
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
create function app_private.guard_order_items() returns trigger language plpgsql set search_path='' as $$
declare oid uuid; begin
  oid=case when tg_op='DELETE' then old.order_id else new.order_id end;
    perform 1 from public.orders where id=oid for update;
    if exists(select 1 from public.orders where id=oid and status<>'draft') then raise exception 'Only draft order lines can change'; end if;
  if exists(select 1 from public.inventory_reservations where order_id=oid) then raise exception 'Reserved order lines are immutable'; end if;
  if tg_op='UPDATE' and new.order_id<>old.order_id then raise exception 'Order ownership immutable'; end if;
  if tg_op='DELETE' then return old; end if; return new;
end $$;
create trigger guard_order_items before insert or update or delete on public.order_items for each row execute function app_private.guard_order_items();
create function app_private.guard_money() returns trigger language plpgsql set search_path='' as $$
declare ceiling bigint; used bigint; begin
  if tg_table_name='sales' then
    select total_minor into ceiling from public.orders where id=new.order_id for update;
    select coalesce(sum(amount_minor),0) into used from public.sales where order_id=new.order_id;
  else
    select amount_minor into ceiling from public.sales where id=new.sale_id for update;
    select coalesce(sum(amount_minor),0) into used from public.refunds where sale_id=new.sale_id;
  end if;
  if ceiling is null or used+new.amount_minor>ceiling then raise exception 'Amount exceeds remaining balance'; end if;
  return new;
end $$;
create trigger guard_sale before insert on public.sales for each row execute function app_private.guard_money();
create trigger guard_refund before insert on public.refunds for each row execute function app_private.guard_money();

create index reservations_active on public.inventory_reservations(variant_id,expires_at) where state='active';
create index movements_variant_time on public.inventory_movements(variant_id,created_at);
create index orders_created on public.orders(created_at);
create index sales_reporting on public.sales(occurred_at);
create index refunds_reporting on public.refunds(occurred_at);
