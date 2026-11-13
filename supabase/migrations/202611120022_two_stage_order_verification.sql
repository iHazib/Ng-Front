-- 022: Two-stage order verification workflow
-- Adds order_status and transaction_id to public.orders for explicit
-- pending-verification → paid → rejected/cancelled lifecycle.
-- Existing commerce_orders.payment_status is preserved; this denormalizes
-- the customer-facing status onto public.orders for simpler queries.

-- Add order_status column to public.orders
alter table public.orders add column if not exists order_status text not null default 'pending_verification'
  check(order_status in('pending_verification','paid','rejected','cancelled'));

-- Add transaction_id column with UNIQUE constraint (prevents duplicate TID/receipt reuse)
alter table public.orders add column if not exists transaction_id text unique
  check(length(btrim(transaction_id)) between 3 and 120);

-- Add proof_url column to store the private payment proof image path
alter table public.orders add column if not exists proof_url text;

-- Add index for fast lookup by transaction_id
create index if not exists orders_transaction_id_idx on public.orders(transaction_id) where transaction_id is not null;

-- Add index for fast lookup by order_status
create index if not exists orders_order_status_idx on public.orders(order_status);

-- Add comment documenting the lifecycle
comment on column public.orders.order_status is '
  Two-stage order verification lifecycle:
  pending_verification - order placed, stock temporarily reserved, awaiting payment proof
  paid                 - funds verified in receiving account, stock permanently deducted
  rejected             - fake/no funds, stock released, order cancelled
  cancelled            - order cancelled by customer or admin, stock released
';

comment on column public.orders.transaction_id is '
  Customer-supplied transaction reference (TID) from bank/wallet transfer.
  UNIQUE constraint prevents the same receipt being used for two orders.
';

comment on column public.orders.proof_url is '
  Private Supabase Storage path to the customer-uploaded payment proof image.
  Accessible only to the customer (via order confirmation) and admins.
';

-- Create a view that joins orders with their verification state for admin use
create or replace view public.order_verification_view as
select
  o.id,
  o.order_status,
  o.transaction_id,
  o.proof_url,
  o.total_minor,
  o.delivery_name,
  o.contact_phone,
  o.created_at,
  o.updated_at,
  co.payment_status as internal_payment_status,
  co.fulfilment as internal_fulfilment,
  co.hold_expires_at,
  mp.payment_deadline,
  mp.review_until,
  mp.flags as payment_flags,
  mp.message as payment_message,
  coalesce(pr.received_minor, 0) as received_minor
from public.orders o
left join app_private.commerce_orders co on co.order_id = o.id
left join app_private.manual_payments mp on mp.order_id = o.id
left join (
  select order_id, sum(amount_minor) as received_minor
  from app_private.payment_receipts
  group by order_id
) pr on pr.order_id = o.id;

grant select on public.order_verification_view to authenticated;

-- Helper function to transition an order from pending_verification to paid
create or replace function public.confirm_order_payment(
  p_order_id uuid,
  p_transaction_id text,
  p_amount_minor bigint,
  p_actor_id uuid
) returns jsonb language plpgsql set search_path='' as $$
declare
  v_order record;
  v_ref_key text;
  v_existing uuid;
begin
  -- Lock the order row
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'Order not found' using errcode = 'P0404';
  end if;

  if v_order.order_status <> 'pending_verification' then
    raise exception 'Order is not in pending_verification state' using errcode = 'P0409';
  end if;

  -- Normalize and check transaction_id uniqueness
  v_ref_key := regexp_replace(upper(normalize(btrim(p_transaction_id),NFKC)), '[[:space:]-]+', '', 'g');
  if length(v_ref_key) < 3 then
    raise exception 'Transaction reference is incomplete' using errcode = 'P0400';
  end if;

  select id into v_existing from public.orders where transaction_id = p_transaction_id and id <> p_order_id;
  if v_existing is not null then
    raise exception 'Transaction reference already used on another order' using errcode = 'P0409';
  end if;

  -- Update order status and transaction_id
  update public.orders
  set order_status = 'paid',
      transaction_id = p_transaction_id,
      updated_at = now()
  where id = p_order_id;

  -- Record the payment receipt
  insert into app_private.payment_receipts (
    id, order_id, account_scope, reference, reference_key, amount_minor, actor_id
  ) values (
    gen_random_uuid(),
    p_order_id,
    (select account_scope from app_private.manual_payments where order_id = p_order_id),
    p_transaction_id,
    v_ref_key,
    p_amount_minor,
    p_actor_id
  ) on conflict (account_scope, reference_key) do nothing;

  -- Update commerce_orders payment status
  update app_private.commerce_orders
  set payment_status = 'paid',
      allocation = 'accepted',
      hold_expires_at = null
  where order_id = p_order_id;

  -- Permanently deduct stock (consume reservations)
  update public.inventory_reservations
  set state = 'consumed', expires_at = 'infinity'
  where order_id = p_order_id and state = 'active';

  insert into public.inventory_movements (variant_id, delta, reason, idempotency_key, order_id, actor_id)
  select variant_id, -quantity, 'order consumption confirmed', 'confirm:' || id, p_order_id, p_actor_id
  from public.inventory_reservations
  where order_id = p_order_id and state = 'consumed';

  update public.orders set status = 'placed', updated_at = now() where id = p_order_id;

  return jsonb_build_object(
    'id', p_order_id,
    'order_status', 'paid',
    'transaction_id', p_transaction_id,
    'amount_minor', p_amount_minor
  );
end $$;

-- Helper function to reject an order (release stock, cancel)
create or replace function public.reject_order_payment(
  p_order_id uuid,
  p_reason text,
  p_actor_id uuid
) returns jsonb language plpgsql set search_path='' as $$
declare
  v_order record;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then
    raise exception 'Order not found' using errcode = 'P0404';
  end if;

  if v_order.order_status <> 'pending_verification' then
    raise exception 'Order is not in pending_verification state' using errcode = 'P0409';
  end if;

  -- Release stock
  update public.inventory_reservations
  set state = 'released', expires_at = now()
  where order_id = p_order_id and state = 'active';

  update public.inventory_balances b
  set reserved = reserved - r.quantity
  from public.inventory_reservations r
  where b.variant_id = r.variant_id
    and r.order_id = p_order_id
    and r.state = 'released'
    and b.reconciled_at is not null;

  -- Update order status
  update public.orders
  set order_status = 'rejected',
      status = 'cancelled',
      updated_at = now()
  where id = p_order_id;

  -- Update commerce_orders
  update app_private.commerce_orders
  set payment_status = 'rejected',
      fulfilment = 'cancelled',
      allocation = 'released',
      hold_expires_at = null
  where order_id = p_order_id;

  -- Record the rejection
  insert into app_private.payment_actions (id, order_id, action, request_hash, actor_id, details)
  values (
    gen_random_uuid(),
    p_order_id,
    'reject',
    encode(pg_catalog.sha256(convert_to(jsonb_build_array(p_order_id, p_reason)::text, 'UTF8')), 'hex'),
    p_actor_id,
    jsonb_build_object('reason', p_reason)
  );

  return jsonb_build_object(
    'id', p_order_id,
    'order_status', 'rejected',
    'reason', p_reason
  );
end $$;

-- Grant execute on the new functions
grant execute on function public.confirm_order_payment(uuid,text,bigint,uuid) to authenticated;
grant execute on function public.reject_order_payment(uuid,text,uuid) to authenticated;

-- ============================================================
-- End of migration 022
-- ============================================================
