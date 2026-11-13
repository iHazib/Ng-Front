-- Claims remain hidden if evidence or scope is later withdrawn.
alter function app_private.guard_money() security definer;
create function public.facet_is_public(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.product_facets f join public.facet_definitions d on d.id=f.facet_id
   join public.evidence e on e.id=f.evidence_id join public.products p on p.id=f.product_id join public.categories c on c.id=p.category_id
   join public.facet_scopes s on s.facet_id=f.facet_id and s.scope=c.scope
   where f.id=p_id and f.status='approved' and e.status='approved' and d.active
   and public.product_is_public(p.id) and (f.variant_id is null or public.variant_is_public(f.variant_id)))
$$;
create function public.concern_is_public(p_product uuid,p_concern text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.product_concerns pc join public.concerns c on c.id=pc.concern_id
   join public.evidence e on e.id=pc.evidence_id join public.products p on p.id=pc.product_id join public.categories cat on cat.id=p.category_id
   where pc.product_id=p_product and pc.concern_id=p_concern and pc.status='approved' and e.status='approved' and c.active
   and cat.scope='skincare' and public.product_is_public(p_product))
$$;
drop policy public_read on public.product_facets;
create policy public_read on public.product_facets for select to anon,authenticated using(public.facet_is_public(id));
drop policy public_read on public.product_concerns;
create policy public_read on public.product_concerns for select to anon,authenticated using(public.concern_is_public(product_id,concern_id));
revoke all on function public.facet_is_public(uuid),public.concern_is_public(uuid,text) from public,anon,authenticated;
grant execute on function public.facet_is_public(uuid),public.concern_is_public(uuid,text) to anon,authenticated;

create or replace function public.search_published_catalog(p_query text,p_limit integer default 30)
returns table(product_id uuid,name text,slug text) language sql stable set search_path='' as $$
 select p.id,p.name,p.slug from public.products p where public.product_is_public(p.id) and
 (p.search_vector @@ websearch_to_tsquery('simple',left(p_query,160)) or extensions.similarity(p.name,left(p_query,160))>0.25)
 order by p.name limit least(greatest(p_limit,1),100)
$$;

create function app_private.guard_shipment_item() returns trigger language plpgsql security definer set search_path='' as $$
declare ordered integer; used integer; oid uuid; begin
  select i.quantity,i.order_id into ordered,oid from public.order_items i where i.id=new.order_item_id for update;
  if not exists(select 1 from public.shipments s where s.id=new.shipment_id and s.order_id=oid) then raise exception 'Shipment belongs to another order'; end if;
  select coalesce(sum(si.quantity),0) into used from public.shipment_items si join public.shipments s on s.id=si.shipment_id
    where si.order_item_id=new.order_item_id and s.status<>'cancelled' and si.shipment_id<>new.shipment_id;
  if used+new.quantity>ordered then raise exception 'Shipment quantity exceeds order'; end if;
  return new;
end $$;
create trigger guard_shipment_item before insert or update on public.shipment_items for each row execute function app_private.guard_shipment_item();
create function app_private.guard_order_total() returns trigger language plpgsql security definer set search_path='' as $$ begin
  if new.status in ('placed','fulfilled') and (new.total_minor is null or new.shipping_minor is null or
    new.subtotal_minor<>(select coalesce(sum(line_total_minor),0) from public.order_items where order_id=new.id)) then raise exception 'Order totals incomplete or inconsistent'; end if;
  return new;
end $$;
create trigger guard_order_total before insert or update on public.orders for each row execute function app_private.guard_order_total();
create function app_private.guard_factory_contents() returns trigger language plpgsql security definer set search_path='' as $$ begin
  if not exists(select 1 from public.variants where id=new.set_variant_id and sellable_kind in ('factory_set','unconfirmed_set')) then raise exception 'Factory contents require a packed-set variant'; end if;
  return new;
end $$;
create trigger guard_factory_contents before insert or update on public.factory_set_contents for each row execute function app_private.guard_factory_contents();
revoke all on function app_private.guard_shipment_item(),app_private.guard_order_total(),app_private.guard_factory_contents() from public,anon,authenticated;

-- Conditional product-type checks supplement the category's essential checks.
create function app_private.guard_sunscreen() returns trigger language plpgsql security definer set search_path='' as $$ begin
  if new.status='published' and new.product_type_id='sunscreen' and not exists(select 1 from public.product_checks where product_id=new.id and code='spf_label' and approved) then raise exception 'Sunscreen SPF/variant/directions approval required'; end if;
  return new;
end $$;
create trigger guard_sunscreen before insert or update on public.products for each row execute function app_private.guard_sunscreen();
revoke all on function app_private.guard_sunscreen() from public,anon,authenticated;
