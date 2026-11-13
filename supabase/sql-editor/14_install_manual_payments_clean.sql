-- Complete incremental 016. Apply ONCE after canonical 015; no earlier installers.
-- No business rows deleted or rewritten. Replaces payment/fulfilment guards.
-- Drops and immediately replaces only CHECK constraints, not tables or data.
begin;
set local lock_timeout='5s';set local statement_timeout='120s';
select pg_advisory_xact_lock(73524);
do $guard$ begin
 if not exists(select 1 from app_private.sql_editor_receipts where version='202610130015' and sha256='b89d4a6a6ae13c27be9d71928c5ea288c26b64691f8be0d867c8070abf5b0ce0') then raise exception 'Verify canonical 015 receipt first';end if;
 if exists(select 1 from app_private.sql_editor_receipts where version='202610150016') or to_regclass('app_private.manual_payments') is not null or to_regclass('app_private.payment_submissions') is not null or to_regclass('app_private.payment_receipts') is not null or to_regclass('app_private.payment_actions') is not null or to_regprocedure('public.review_manual_payment(uuid,integer,text,uuid,jsonb)') is not null then raise exception 'Manual payments already or partly installed; inspect state, do not rerun';end if;
end $guard$;
-- 016: manual advance payments. Existing orders, stock and receipts are preserved.
alter table app_private.commerce_orders drop constraint commerce_orders_payment_status_check;
alter table app_private.commerce_orders add constraint commerce_orders_payment_status_check check(payment_status in('due_on_delivery','awaiting_payment','under_review','needs_attention','paid','received_resolution_required'));
create table app_private.manual_payments(
 order_id uuid primary key references public.orders(id), account_scope text not null check(account_scope ~ '^[a-f0-9]{64}$'),
 payment_deadline timestamptz not null, review_until timestamptz not null, extension_seconds integer not null check(extension_seconds between 0 and 86400),
 first_submission_at timestamptz, flags text[] not null default '{}', message text,
 check(review_until>=payment_deadline)
);
create table app_private.payment_submissions(
 id uuid primary key, order_id uuid not null references app_private.manual_payments(order_id), reference text not null check(length(reference) between 3 and 120),
 reference_key text not null, amount_minor bigint check(amount_minor between 1 and 9007199254740991), proof_id uuid references public.media_assets(id),
 created_at timestamptz not null default now(), request_hash text not null
);
create table app_private.payment_receipts(
 id uuid primary key, order_id uuid not null references app_private.manual_payments(order_id), account_scope text not null,
 reference text not null, reference_key text not null, amount_minor bigint not null check(amount_minor between 1 and 9007199254740991),
 verification_method text not null default 'manual_account_history' check(verification_method='manual_account_history'),
 actor_id uuid not null references auth.users(id), received_at timestamptz not null default now(), unique(account_scope,reference_key)
);
create table app_private.payment_actions(
 id uuid primary key,order_id uuid not null references app_private.manual_payments(order_id),action text not null,request_hash text not null,
 actor_id uuid references auth.users(id),created_at timestamptz not null default now(),details jsonb not null check(length(details::text)<=1500)
);
create index payment_submissions_order on app_private.payment_submissions(order_id,created_at desc,id);
create index payment_submissions_reference on app_private.payment_submissions(reference_key);
create index payment_submissions_proof on app_private.payment_submissions(proof_id);
create index payment_proof_hash on public.media_assets(content_sha256) where provider='supabase_private' and content_sha256 is not null;
create index payment_receipts_order on app_private.payment_receipts(order_id);
create index manual_payments_scope on app_private.manual_payments(account_scope);
alter table app_private.manual_payments enable row level security;
alter table app_private.payment_submissions enable row level security;
alter table app_private.payment_receipts enable row level security;
alter table app_private.payment_actions enable row level security;
revoke all on app_private.manual_payments,app_private.payment_submissions,app_private.payment_receipts,app_private.payment_actions from public,anon,authenticated,service_role;
-- Append-only histories: no runtime update/delete paths.
create function app_private.payment_immutable() returns trigger language plpgsql set search_path='' as $$ begin raise exception 'Payment history is append only';end $$;
create trigger immutable before update or delete on app_private.payment_submissions for each row execute function app_private.payment_immutable();
create trigger immutable before update or delete on app_private.payment_receipts for each row execute function app_private.payment_immutable();
create trigger immutable before update or delete on app_private.payment_actions for each row execute function app_private.payment_immutable();

alter table public.media_workflows add column payment_order_id uuid references app_private.manual_payments(order_id);
alter table public.media_workflows drop constraint media_exact_owner,drop constraint media_content_owner_kind;
alter table public.media_workflows add constraint media_exact_owner check(num_nonnulls(product_id,article_id,homepage_id,review_id,payment_order_id)=1),
 add constraint media_content_owner_kind check((product_id is not null and content_kind is null) or (article_id is not null and content_kind in('cover','inline')) or (homepage_id is not null and content_kind='slide') or (review_id is not null and content_kind is null) or (payment_order_id is not null and content_kind is null));
create index payment_media_owner on public.media_workflows(payment_order_id) where payment_order_id is not null;
create function app_private.protect_payment_proof() returns trigger language plpgsql security definer set search_path='' as $$ begin
 if exists(select 1 from public.media_workflows where media_id=new.id and payment_order_id is not null) and (new.provider<>'supabase_private' or new.status<>'pending' or new.cloudinary_public_id is not null or new.lifecycle not in('private_uploading','private_pending','failed','deleted')) then raise exception 'Payment proofs must remain private';end if;return new;
end $$;
create trigger payment_proof_private before update on public.media_assets for each row execute function app_private.protect_payment_proof();
create function app_private.protect_payment_owner() returns trigger language plpgsql security definer set search_path='' as $$ begin
 if tg_op='UPDATE' and old.payment_order_id is not null and new is distinct from old then raise exception 'Payment proof ownership is immutable';end if;
 if new.payment_order_id is not null and not exists(select 1 from public.media_assets where id=new.media_id and provider='supabase_private' and status='pending' and lifecycle='private_uploading') then raise exception 'Invalid private payment proof';end if;return new;
end $$;
create trigger payment_proof_owner before insert or update on public.media_workflows for each row execute function app_private.protect_payment_owner();
alter function public.media_workflow_action(uuid,text,jsonb) rename to media_workflow_action_015;
alter function public.media_workflow_action_015(uuid,text,jsonb) set schema app_private;
create function public.media_workflow_action(p_id uuid,p_action text,p_result jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$ begin
 perform app_private.require_admin();if exists(select 1 from public.media_workflows where media_id=p_id and payment_order_id is not null) then raise exception 'Payment proofs cannot be published or removed through public media controls';end if;
 return app_private.media_workflow_action_015(p_id,p_action,p_result);
end $$;
-- Existing association guards also reject payment proof reuse.
create or replace function app_private.guard_media_reference() returns trigger language plpgsql security definer set search_path='' as $$ declare state text;begin
 if new.media_id is not null then select lifecycle into state from public.media_assets where id=new.media_id for update;
 if state in('deleting','deleted') or exists(select 1 from public.media_workflows where media_id=new.media_id and payment_order_id is not null) then raise exception 'Media is unavailable for public content';end if;end if;return new;end $$;

create function app_private.payment_reference(p_reference text) returns text language sql immutable set search_path='' as $$
 select regexp_replace(upper(normalize(btrim(p_reference),NFKC)),'[[:space:]-]+','','g');
$$;
create function app_private.payment_flags(p_order uuid) returns text[] language sql stable set search_path='' as $$
 with latest as(select * from app_private.payment_submissions where order_id=p_order order by created_at desc,id desc limit 1),
 base as(select m.*,o.total_minor from app_private.manual_payments m join public.orders o on o.id=m.order_id where m.order_id=p_order),
 funds as(select coalesce(sum(amount_minor),0) amount from app_private.payment_receipts where order_id=p_order)
 select array(select distinct f from(
 select unnest(base.flags) f from base union all
 select 'Amount does not match order total' from latest,base where latest.amount_minor is not null and latest.amount_minor<>base.total_minor union all
 select 'Received amount below order total' from base,funds where funds.amount>0 and funds.amount<base.total_minor union all
 select 'Received amount exceeds order total' from base,funds where funds.amount>base.total_minor union all
 select 'Transaction reference reused' from latest,base where exists(select 1 from app_private.payment_receipts r where r.account_scope=base.account_scope and r.reference_key=latest.reference_key and r.order_id<>p_order) or exists(select 1 from app_private.payment_submissions s join app_private.manual_payments m on m.order_id=s.order_id where s.order_id<>p_order and m.account_scope=base.account_scope and s.reference_key=latest.reference_key) union all
 select 'Identical proof image used on another order' from latest join public.media_assets a on a.id=latest.proof_id where exists(select 1 from app_private.payment_submissions s join public.media_assets b on b.id=s.proof_id where s.order_id<>p_order and a.content_sha256=b.content_sha256)
 ) issues where f is not null);
$$;
alter function app_private.commerce_view(uuid) rename to commerce_view_015;
create function app_private.commerce_view(p_order uuid) returns jsonb language sql stable set search_path='' as $$
 select app_private.commerce_view_015(p_order)||coalesce((select jsonb_build_object('manualPayment',jsonb_build_object(
 'paymentDeadline',m.payment_deadline,'reviewDeadline',m.review_until,'flags',app_private.payment_flags(p_order),'message',m.message,
 'receivedMinor',(select coalesce(sum(amount_minor),0) from app_private.payment_receipts where order_id=p_order),
 'queue',case when c.payment_status='paid' then 'Paid' when cardinality(app_private.payment_flags(p_order))>0 or c.payment_status in('needs_attention','received_resolution_required') then 'Needs attention' when exists(select 1 from app_private.payment_submissions where order_id=p_order) then 'Proof submitted' else 'Awaiting payment' end,
 'submissions',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'reference',s.reference,'amountMinor',s.amount_minor,'proofId',s.proof_id,'at',s.created_at) order by s.created_at,s.id) from app_private.payment_submissions s where s.order_id=p_order),'[]'),
 'receipts',coalesce((select jsonb_agg(jsonb_build_object('amountMinor',r.amount_minor,'reference',r.reference,'at',r.received_at) order by r.received_at,r.id) from app_private.payment_receipts r where r.order_id=p_order),'[]')))
 from app_private.manual_payments m join app_private.commerce_orders c on c.order_id=m.order_id where m.order_id=p_order),'{}');
$$;
alter function public.place_guest_order(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb) rename to place_guest_order_015;
alter function public.place_guest_order_015(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb) set schema app_private;
create function public.place_guest_order(p_id uuid,p_session text,p_token text,p_lines jsonb,p_customer jsonb,p_shipping jsonb,p_payment jsonb,p_config jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
 declare seconds integer;extension integer;begin
 if coalesce(p_payment->>'id','') not in('bank-transfer','easypaisa','jazzcash') or p_payment->>'allocation' is distinct from 'temporary' or coalesce(p_payment->>'accountScope','') !~ '^[a-f0-9]{64}$' or length(coalesce(p_payment->>'accountTitle','')) not between 1 and 120 or length(coalesce(p_payment->>'destination','')) not between 3 and 120 or coalesce(p_config->>'paymentSeconds','') !~ '^[0-9]{1,6}$' or coalesce(p_config->>'reviewExtensionSeconds','') !~ '^[0-9]{1,5}$' then raise exception 'Manual advance payment configuration required';end if;
 seconds=(p_config->>'paymentSeconds')::int;extension=(p_config->>'reviewExtensionSeconds')::int;
 if seconds not between 60 and 604800 or extension not between 0 and 86400 then raise exception 'Invalid payment deadlines';end if;
 perform app_private.place_guest_order_015(p_id,p_session,p_token,p_lines,p_customer,p_shipping,p_payment,p_config);
 if not exists(select 1 from app_private.manual_payments where order_id=p_id) then
 insert into app_private.manual_payments(order_id,account_scope,payment_deadline,review_until,extension_seconds) values(p_id,p_payment->>'accountScope',now()+make_interval(secs=>seconds),now()+make_interval(secs=>seconds+extension),extension);
 update app_private.commerce_orders set hold_expires_at=now()+make_interval(secs=>seconds) where order_id=p_id;
 update public.inventory_reservations set expires_at=now()+make_interval(secs=>seconds) where order_id=p_id and state='active';
 perform app_private.assert_order_allocation(p_id,'active');end if;return app_private.commerce_view(p_id);
 end $$;
create function app_private.payment_owner(p_id uuid,p_session text,p_token text) returns void language plpgsql set search_path='' as $$ begin
 if not exists(select 1 from app_private.commerce_orders c join app_private.manual_payments m on m.order_id=c.order_id where c.order_id=p_id and c.session_hash=p_session and c.token_hash=p_token) then raise exception 'Order unavailable' using errcode='P0404';end if;
end $$;
create function public.payment_proof(p_order uuid,p_session text,p_token text,p_id uuid,p_action text,p_data jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
 declare m public.media_assets;path text;begin
 perform app_private.payment_owner(p_order,p_session,p_token);perform 1 from app_private.commerce_orders where order_id=p_order for update;
 select a.* into m from public.media_assets a join public.media_workflows w on w.media_id=a.id where a.id=p_id and w.payment_order_id=p_order;
 if p_action='create' then
 if exists(select 1 from app_private.commerce_orders where order_id=p_order and (payment_status='paid' or fulfilment in('cancelled','dispatched','completed'))) then raise exception 'Proof upload unavailable';end if;
 if coalesce(p_data->>'environment','') not in('development','staging','production') or coalesce(p_data->>'hash','') !~ '^[a-f0-9]{64}$' or coalesce(p_data->>'bytes','') !~ '^[0-9]{1,8}$' or (p_data->>'bytes')::int not between 1 and 5242880 then raise exception 'Invalid proof';end if;
 if m.id is not null then if m.content_sha256<>p_data->>'hash' or m.byte_size<>(p_data->>'bytes')::bigint then raise exception 'Upload retry differs';end if;
 else
 if (select count(*) from public.media_workflows where payment_order_id=p_order)>=5 then raise exception 'Proof upload limit reached';end if;
 path='media/'||(p_data->>'environment')||'/'||p_id::text||'/original';
 insert into public.media_assets(id,provider,private_bucket,private_path,alt,content_sha256,byte_size,media_environment,lifecycle) values(p_id,'supabase_private','catalog-private',path,'Private payment proof',p_data->>'hash',(p_data->>'bytes')::int,p_data->>'environment','private_uploading');
 insert into public.media_workflows(media_id,payment_order_id,private_path,expected_public_id) values(p_id,p_order,path,'never-publish/payment-proof/'||p_id);
 select * into m from public.media_assets where id=p_id;
 end if;
 elsif p_action='complete' then
 if m.id is null or m.lifecycle not in('private_uploading','private_pending') then raise exception 'Proof unavailable';end if;
 update public.media_assets set lifecycle='private_pending' where id=p_id;
 elsif p_action<>'read' then raise exception 'Invalid proof action';end if;
 if m.id is null then raise exception 'Proof unavailable' using errcode='P0404';end if;
 return jsonb_build_object('id',m.id,'path',m.private_path,'hash',m.content_sha256,'bytes',m.byte_size);
 end $$;
create function public.submit_manual_payment(p_order uuid,p_session text,p_token text,p_key uuid,p_reference text,p_amount bigint default null,p_proof uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
 declare c app_private.commerce_orders;m app_private.manual_payments;rh text;prior app_private.payment_submissions;deadline timestamptz;begin
 perform app_private.payment_owner(p_order,p_session,p_token);
 if p_key is null or p_reference is null or length(btrim(p_reference)) not between 3 and 120 or length(app_private.payment_reference(p_reference))<3 or (p_amount is not null and p_amount not between 1 and 9007199254740991) then raise exception 'Check payment reference and amount';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_key::text,816));
 select * into c from app_private.commerce_orders where order_id=p_order for update;select * into m from app_private.manual_payments where order_id=p_order for update;
 rh=md5(jsonb_build_array(p_order,p_reference,p_amount,p_proof)::text);select * into prior from app_private.payment_submissions where id=p_key;
 if found then if prior.request_hash<>rh then raise exception 'Submission retry differs';end if;return app_private.commerce_view(p_order);end if;
 if c.payment_status='paid' or c.fulfilment in('cancelled','dispatched','completed') or (select count(*) from app_private.payment_submissions where order_id=p_order)>=10 then raise exception 'Submission unavailable. Contact customer care';end if;
 if p_proof is not null and not exists(select 1 from public.media_assets a join public.media_workflows w on w.media_id=a.id where a.id=p_proof and w.payment_order_id=p_order and a.provider='supabase_private' and a.lifecycle='private_pending') then raise exception 'Private proof upload is incomplete';end if;
 insert into app_private.payment_submissions(id,order_id,reference,reference_key,amount_minor,proof_id,request_hash) values(p_key,p_order,btrim(p_reference),app_private.payment_reference(p_reference),p_amount,p_proof,rh);
 if m.first_submission_at is null and now()<m.payment_deadline and c.allocation='temporary' then
 deadline=least(m.review_until,greatest(m.payment_deadline,now()+make_interval(secs=>m.extension_seconds)));
 update public.inventory_reservations set expires_at=deadline where order_id=p_order and state='active';
 update app_private.commerce_orders set hold_expires_at=deadline where order_id=p_order;
 end if;
 update app_private.manual_payments set first_submission_at=coalesce(first_submission_at,now()),message=null where order_id=p_order;
 update app_private.commerce_orders set payment_status='under_review',revision=revision+1 where order_id=p_order;
 insert into app_private.order_events(order_id,operation_key,action,revision) values(p_order,p_key,'payment submitted',c.revision+1);
 return app_private.commerce_view(p_order);
 end $$;
-- Atomic all-or-nothing reacquisition. A caught shortage rolls back only this subtransaction,
-- preserving an accurately recorded receipt of funds.
create function app_private.reacquire_payment_stock(p_order uuid) returns boolean language plpgsql set search_path='' as $$ declare r record;begin
 perform 1 from public.inventory_balances where variant_id in(select variant_id from public.order_items where order_id=p_order) order by variant_id for update;
 if exists(with e as(select variant_id,sum(quantity) qty from public.order_items where order_id=p_order group by variant_id),a as(select variant_id,count(*) n,sum(quantity) qty,bool_and(state='released') ok from public.inventory_reservations where order_id=p_order group by variant_id) select 1 from e full join a using(variant_id) where e.variant_id is null or a.variant_id is null or a.n<>1 or a.qty<>e.qty or not a.ok) then raise exception 'Released allocation is incomplete';end if;
 for r in select * from public.inventory_reservations where order_id=p_order order by variant_id for update loop
 update public.inventory_balances set reserved=reserved+r.quantity where variant_id=r.variant_id and reconciled_at is not null and on_hand-reserved>=r.quantity;
 if not found then raise exception 'Stock unavailable' using errcode='P0409';end if;
 update public.inventory_reservations set state='active',expires_at='infinity' where id=r.id;
 end loop;return true;
 exception when sqlstate 'P0409' then return false;
 end $$;
create function public.review_manual_payment(p_order uuid,p_revision integer,p_action text,p_key uuid,p_data jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
 declare c app_private.commerce_orders;m app_private.manual_payments;a app_private.payment_actions;r app_private.payment_receipts;rh text;ref text;amount bigint;total bigint;received numeric;ready boolean=false;begin
 perform app_private.require_admin();if p_key is null or p_action not in('verify','correction','reject') or length(p_data::text)>1500 then raise exception 'Invalid payment action';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_key::text,816));
 select * into c from app_private.commerce_orders where order_id=p_order for update;select * into m from app_private.manual_payments where order_id=p_order for update;
 if m.order_id is null then raise exception 'Manual payment order missing';end if;
 perform 1 from public.orders where id=p_order for update;select total_minor into total from public.orders where id=p_order;
 rh=md5(jsonb_build_array(p_order,p_revision,p_action,p_data)::text);select * into a from app_private.payment_actions where id=p_key;
 if found then if a.request_hash<>rh then raise exception 'Payment retry differs';end if;return app_private.commerce_view(p_order);end if;
 if c.revision<>p_revision then raise exception 'Order changed. Refresh before retrying';end if;
 if p_action='verify' then
 if p_data->>'checkedHistory' is distinct from 'true' or coalesce(p_data->>'amountMinor','') !~ '^[0-9]{1,16}$' or (p_data->>'amountMinor')::numeric not between 1 and 9007199254740991 or length(btrim(coalesce(p_data->>'reference',''))) not between 3 and 120 then raise exception 'Check actual receiving-account history and record amount/reference';end if;
 amount=(p_data->>'amountMinor')::bigint;ref=app_private.payment_reference(p_data->>'reference');
 if length(ref)<3 then raise exception 'Reference is incomplete';end if;
 perform pg_advisory_xact_lock(hashtextextended(m.account_scope||':'||ref,817));
 select * into r from app_private.payment_receipts where account_scope=m.account_scope and reference_key=ref;
 if r.id is not null and (r.order_id<>p_order or r.amount_minor<>amount) then
 update app_private.manual_payments set flags=array(select distinct unnest(flags||array['Transfer already credited or amount differs'])),message='Check the receiving account: this transfer cannot be credited again.' where order_id=p_order;
 update app_private.commerce_orders set payment_status=case when payment_status='paid' then payment_status else 'needs_attention' end where order_id=p_order;
 else
 if r.id is null then
 if (select coalesce(sum(amount_minor),0) from app_private.payment_receipts where order_id=p_order)+amount>9007199254740991 then raise exception 'Received total exceeds supported amount';end if;
 insert into app_private.payment_receipts(id,order_id,account_scope,reference,reference_key,amount_minor,actor_id) values(p_key,p_order,m.account_scope,btrim(p_data->>'reference'),ref,amount,auth.uid());end if;
 select sum(amount_minor) into received from app_private.payment_receipts where order_id=p_order;
 if received=total then
 if c.allocation='temporary' and c.hold_expires_at<=now() then
 perform app_private.assert_order_allocation(p_order,'active',true);perform app_private.finish_inventory(p_order,false);
 update app_private.commerce_orders set allocation='released',fulfilment='expired' where order_id=p_order;update public.orders set status='cancelled' where id=p_order;c.allocation='released';c.fulfilment='expired';
 end if;
 if c.allocation in('accepted','consumed') then ready=true;
 elsif c.allocation='temporary' then perform app_private.assert_order_allocation(p_order,'active');ready=true;
 elsif c.fulfilment='expired' and p_data->>'reacquire'='true' then ready=app_private.reacquire_payment_stock(p_order);
 end if;
 if ready then
 update public.inventory_reservations set expires_at='infinity' where order_id=p_order and state='active';
 update app_private.commerce_orders set payment_status='paid',allocation=case when allocation='consumed' then allocation else 'accepted' end,hold_expires_at=null,fulfilment=case when fulfilment='expired' then 'placed' else fulfilment end where order_id=p_order;
 update public.orders set status=case when status='cancelled' then 'placed' else status end where id=p_order;
 perform app_private.assert_order_allocation(p_order,case when c.allocation='consumed' then 'consumed' else 'active' end);
 update app_private.manual_payments set flags='{}',message=null where order_id=p_order;
 else update app_private.commerce_orders set payment_status='received_resolution_required',allocation='released' where order_id=p_order;
 update app_private.manual_payments set flags=array['Stock allocation requires resolution'],message='Payment received—resolution required. Do not fulfil or refund automatically.' where order_id=p_order;
 end if;
 else update app_private.commerce_orders set payment_status='needs_attention' where order_id=p_order;
 update app_private.manual_payments set message='Received funds recorded. The total does not match the order. Review before fulfilment.' where order_id=p_order;
 end if;
 end if;
 else
 if c.payment_status='paid' or exists(select 1 from app_private.payment_receipts where order_id=p_order) then raise exception 'Received funds require explicit resolution, not submission rejection';end if;
 if length(btrim(coalesce(p_data->>'message',''))) not between 3 and 500 then raise exception 'Add a short customer message';end if;
 update app_private.manual_payments set message=p_data->>'message' where order_id=p_order;
 update app_private.commerce_orders set payment_status='needs_attention' where order_id=p_order;
 if p_action='reject' and c.allocation='temporary' then perform app_private.assert_order_allocation(p_order,'active',true);perform app_private.finish_inventory(p_order,false);
 update app_private.commerce_orders set fulfilment='cancelled',allocation='released',hold_expires_at=null where order_id=p_order;update public.orders set status='cancelled' where id=p_order;end if;
 end if;
 update app_private.commerce_orders set revision=revision+1 where order_id=p_order;
 insert into app_private.payment_actions values(p_key,p_order,p_action,rh,auth.uid(),now(),p_data);
 insert into app_private.order_events(order_id,operation_key,action,revision,actor_id) values(p_order,p_key,'payment '||p_action,c.revision+1,auth.uid());
 return app_private.commerce_view(p_order);
 end $$;
create function public.admin_payment_proof(p_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$ begin
 perform app_private.require_admin();return(select jsonb_build_object('id',a.id,'path',a.private_path,'hash',a.content_sha256,'bytes',a.byte_size) from public.media_assets a join public.media_workflows w on w.media_id=a.id where a.id=p_id and w.payment_order_id is not null and a.provider='supabase_private' and a.lifecycle='private_pending');
end $$;

create or replace function public.admin_order_action(p_id uuid,p_revision integer,p_action text,p_key uuid) returns jsonb language plpgsql security definer set search_path='' as $action$
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
 if p_action in('confirm','dispatch') and (c.payment_status<>'paid') then raise exception 'Verify full payment received before confirming or dispatching';end if;
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
 if next_status='cancelled' and exists(select 1 from app_private.payment_receipts where order_id=p_id) then update app_private.commerce_orders set payment_status='received_resolution_required' where order_id=p_id;update app_private.manual_payments set message='Payment received—resolution required. Cancelled order; no automatic refund.',flags=array['Cancelled order has received funds'] where order_id=p_id;end if;
 update public.orders set status=case when next_status='cancelled' then 'cancelled' when next_status='completed' then 'fulfilled' else 'placed' end,updated_at=now() where id=p_id;
 insert into app_private.order_events(order_id,operation_key,action,revision,actor_id) values(p_id,p_key,p_action,c.revision+1,auth.uid());
 return app_private.commerce_view(p_id);
end $action$;


revoke all on function app_private.place_guest_order_015(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb),app_private.media_workflow_action_015(uuid,text,jsonb),app_private.commerce_view_015(uuid),app_private.commerce_view(uuid),app_private.payment_reference(text),app_private.payment_flags(uuid),app_private.payment_owner(uuid,text,text),app_private.reacquire_payment_stock(uuid),app_private.protect_payment_proof(),app_private.protect_payment_owner(),app_private.payment_immutable() from public,anon,authenticated,service_role;
revoke all on function public.place_guest_order(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb),public.payment_proof(uuid,text,text,uuid,text,jsonb),public.submit_manual_payment(uuid,text,text,uuid,text,bigint,uuid),public.review_manual_payment(uuid,integer,text,uuid,jsonb),public.admin_payment_proof(uuid),public.media_workflow_action(uuid,text,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.place_guest_order(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb),public.payment_proof(uuid,text,text,uuid,text,jsonb),public.submit_manual_payment(uuid,text,text,uuid,text,bigint,uuid) to service_role;
grant execute on function public.review_manual_payment(uuid,integer,text,uuid,jsonb),public.admin_payment_proof(uuid),public.media_workflow_action(uuid,text,jsonb) to authenticated;

create function public.admin_payment_orders(p_query text default '',p_status text default '',p_from date default null,p_to date default null,p_offset integer default 0,p_id uuid default null,p_queue text default '') returns jsonb language plpgsql stable security definer set search_path='' as $orders$
begin
 perform app_private.require_admin();if p_queue not in('','Awaiting payment','Proof submitted','Needs attention','Paid') or length(p_query)>120 or p_offset not between 0 and 100000 or p_status not in('','placed','confirmed','dispatched','completed','cancelled','expired') or (p_from is not null and p_to is not null and p_from>p_to) then raise exception 'Invalid order filters';end if;
 if p_id is not null then return app_private.commerce_view(p_id);end if;
 return(with matched as(select c.order_id from app_private.commerce_orders c join public.orders o on o.id=c.order_id where
 (p_queue='' or app_private.commerce_view(c.order_id)#>>'{manualPayment,queue}'=p_queue) and (p_status='' or c.fulfilment=p_status) and (p_from is null or o.created_at>=p_from::timestamp at time zone 'Asia/Karachi') and (p_to is null or o.created_at<(p_to+1)::timestamp at time zone 'Asia/Karachi') and
 (btrim(p_query)='' or position(lower(btrim(p_query)) in lower(c.order_number||' '||o.delivery_name||' '||o.contact_phone))>0 or exists(select 1 from public.order_items i where i.order_id=o.id and position(lower(btrim(p_query)) in lower(i.name_snapshot||' '||i.sku_snapshot))>0)))
 select jsonb_build_object('total',(select count(*) from matched),'offset',p_offset,'rows',coalesce((select jsonb_agg(app_private.commerce_view(order_id)) from(select m.order_id from matched m join app_private.commerce_orders c on c.order_id=m.order_id order by c.created_at desc,c.order_id limit 25 offset p_offset) page),'[]')));
end $orders$;


revoke all on function public.admin_payment_orders(text,text,date,date,integer,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.admin_payment_orders(text,text,date,date,integer,uuid,text) to authenticated;

insert into app_private.sql_editor_receipts(version,filename,sha256) values('202610150016','202610150016_manual_advance_payments.sql','d0e29a69895ac34b808371c40c126235f7b7d019ee77874b218b3a65cbfdb612');
notify pgrst,'reload schema';
commit;
-- READ ONLY. No customer, receiving-account or catalog data returned.
select exists(select 1 from app_private.sql_editor_receipts where version='202610130015' and sha256='b89d4a6a6ae13c27be9d71928c5ea288c26b64691f8be0d867c8070abf5b0ce0') prerequisite_015,
 to_regclass('app_private.manual_payments') is not null manual_payments_present,
 to_regclass('app_private.payment_submissions') is not null submissions_present,
 to_regclass('app_private.payment_receipts') is not null receipts_present,
 to_regclass('app_private.payment_actions') is not null actions_present,
 (to_regprocedure('public.review_manual_payment(uuid,integer,text,uuid,jsonb)') is not null and to_regprocedure('public.admin_payment_orders(text,text,date,date,integer,uuid,text)') is not null and to_regprocedure('app_private.reacquire_payment_stock(uuid)') is not null) review_present,
 to_regprocedure('public.payment_proof(uuid,text,text,uuid,text,jsonb)') is not null proof_present,
 exists(select 1 from pg_trigger where tgname='payment_proof_private' and tgrelid='public.media_assets'::regclass) private_proof_guard,
 exists(select 1 from app_private.sql_editor_receipts where version='202610150016') receipt_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610150016' and sha256='d0e29a69895ac34b808371c40c126235f7b7d019ee77874b218b3a65cbfdb612') receipt_matches,
 (select count(*)=4 and bool_and(relrowsecurity) from pg_class where oid in(to_regclass('app_private.manual_payments'),to_regclass('app_private.payment_submissions'),to_regclass('app_private.payment_receipts'),to_regclass('app_private.payment_actions'))) private_rls,
 not exists(select 1 from pg_policies where schemaname='app_private' and tablename in('manual_payments','payment_submissions','payment_receipts','payment_actions')) no_client_policies,
 case when to_regprocedure('public.review_manual_payment(uuid,integer,text,uuid,jsonb)') is null then false else has_function_privilege('authenticated','public.review_manual_payment(uuid,integer,text,uuid,jsonb)','execute') and not has_function_privilege('anon','public.review_manual_payment(uuid,integer,text,uuid,jsonb)','execute') and (select prosecdef and position('require_admin()' in prosrc)>0 from pg_proc where oid=to_regprocedure('public.review_manual_payment(uuid,integer,text,uuid,jsonb)')) end admin_authorization,
 case when to_regprocedure('public.submit_manual_payment(uuid,text,text,uuid,text,bigint,uuid)') is null then false else has_function_privilege('service_role','public.submit_manual_payment(uuid,text,text,uuid,text,bigint,uuid)','execute') and not has_function_privilege('authenticated','public.submit_manual_payment(uuid,text,text,uuid,text,bigint,uuid)','execute') and not has_function_privilege('anon','public.submit_manual_payment(uuid,text,text,uuid,text,bigint,uuid)','execute') end guest_gateway_private;
