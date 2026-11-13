-- Incremental media service only. Run the ENTIRE file once in the development SQL Editor.
-- Additive columns/table/functions/triggers; no product import or existing-row deletion.
begin;
set local lock_timeout='5s';
set local statement_timeout='120s';
select pg_advisory_xact_lock(73523);
do $$ begin
 if to_regclass('app_private.sql_editor_receipts') is null then raise exception 'Six-migration SQL Editor installation receipt required'; end if;
 if (select count(*) from app_private.sql_editor_receipts where version between '202610050001' and '202610050006')<>6 then raise exception 'Prerequisite receipts missing'; end if;
 if to_regclass('public.media_workflows') is not null then raise exception 'Media migration already present; do not overwrite'; end if;
end $$;
-- Additive media service migration. Preserve existing media and associations.
alter table public.media_assets
 add column cloudinary_asset_id text unique,
 add column cloudinary_cloud_name text,
 add column media_environment text check(media_environment in ('development','staging','production')),
 add column content_sha256 text check(content_sha256 ~ '^[a-f0-9]{64}$'),
 add column byte_size bigint check(byte_size between 1 and 10485760),
 add column lifecycle text not null default 'legacy' check(lifecycle in
 ('legacy','private_uploading','private_pending','approved_for_publish','uploading','linked','failed','retired','deleting','deleted'));

create table public.media_workflows (
 media_id uuid primary key references public.media_assets(id),
 product_id uuid not null references public.products(id), variant_id uuid,
 foreign key(variant_id,product_id) references public.variants(id,product_id),
 private_path text not null unique, expected_public_id text not null unique,
 replace_association_id uuid, replace_media_id uuid, association_id uuid,
 reviewed_by uuid references auth.users(id), reviewed_at timestamptz,
 error_code text, updated_at timestamptz not null default now(),
 created_at timestamptz not null default now()
);
create index media_workflows_owner on public.media_workflows(product_id,variant_id);
create index media_workflows_reconcile on public.media_workflows(updated_at);
alter table public.media_workflows enable row level security;
revoke all on public.media_workflows from public,anon,authenticated;
grant select on public.media_workflows to authenticated;
create policy admin_read on public.media_workflows for select to authenticated using((select public.is_admin()));
create trigger audit_changes after insert or update or delete on public.media_workflows for each row execute function app_private.audit_change();

create function public.create_media_upload(p_id uuid,p_product uuid,p_variant uuid,p_environment text,p_cloud text,
 p_hash text,p_bytes bigint,p_alt text,p_replace uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare m public.media_assets; w public.media_workflows; path text; begin
 perform app_private.require_admin();
 if p_environment not in ('development','staging','production') or p_cloud !~ '^[a-zA-Z0-9_-]+$'
 or p_hash !~ '^[a-f0-9]{64}$' or p_bytes not between 1 and 10485760
 or length(btrim(p_alt)) not between 1 and 500 then raise exception 'Invalid upload intent'; end if;
 perform 1 from public.products where id=p_product for update;
 if not found then raise exception 'Product missing'; end if;
 select * into m from public.media_assets where id=p_id for update;
 if found then
  select * into w from public.media_workflows where media_id=p_id;
  if w.media_id is null or w.product_id<>p_product or w.variant_id is distinct from p_variant
   or m.content_sha256<>p_hash or m.byte_size<>p_bytes or m.alt<>p_alt or m.media_environment<>p_environment
   or m.cloudinary_cloud_name<>p_cloud or w.replace_association_id is distinct from p_replace then raise exception 'Idempotency identity mismatch'; end if;
  return jsonb_build_object('media_id',m.id,'lifecycle',m.lifecycle,'private_path',w.private_path);
 end if;
 if p_replace is not null and not exists(select 1 from public.product_media where id=p_replace and product_id=p_product and variant_id is not distinct from p_variant) then raise exception 'Replacement association mismatch'; end if;
 path='media/'||p_environment||'/'||p_id::text||'/original';
 insert into public.media_assets(id,provider,private_bucket,private_path,alt,media_environment,cloudinary_cloud_name,content_sha256,byte_size,lifecycle)
 values(p_id,'supabase_private','catalog-private',path,p_alt,p_environment,p_cloud,p_hash,p_bytes,'private_uploading');
 insert into public.media_workflows(media_id,product_id,variant_id,private_path,expected_public_id,replace_association_id,replace_media_id)
 values(p_id,p_product,p_variant,path,'nook-glow/'||p_environment||'/'||p_id::text,p_replace,(select media_id from public.product_media where id=p_replace));
 return jsonb_build_object('media_id',p_id,'lifecycle','private_uploading','private_path',path);
end $$;

-- A row lock prevents cleanup racing with any new association in any owner table.
create function app_private.guard_media_reference() returns trigger language plpgsql security definer set search_path='' as $$
declare state text; begin
 if new.media_id is not null then
  select lifecycle into state from public.media_assets where id=new.media_id for update;
  if state in ('deleting','deleted') then raise exception 'Media is unavailable'; end if;
 end if;
 return new;
end $$;
create trigger media_reference_guard before insert or update on public.product_media for each row execute function app_private.guard_media_reference();
create trigger media_reference_guard before insert or update on public.article_media for each row execute function app_private.guard_media_reference();
create trigger media_reference_guard before insert or update on public.homepage_selections for each row execute function app_private.guard_media_reference();

create function public.media_workflow_action(p_id uuid,p_action text,p_result jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare m public.media_assets; w public.media_workflows; a public.product_media; pos integer; old_media uuid; begin
 perform app_private.require_admin();
 -- Global ordering: product, media, workflow. Reference guards also lock media.
 select * into w from public.media_workflows where media_id=p_id;
 if not found then raise exception 'Media workflow missing'; end if;
 perform 1 from public.products where id=w.product_id for update;
 select * into m from public.media_assets where id=p_id for update;
 select * into w from public.media_workflows where media_id=p_id for update;
 if p_action='private_uploaded' then
  if m.lifecycle='private_pending' then null;
  elsif m.lifecycle in ('private_uploading','failed') and w.reviewed_at is null then
   update public.media_assets set lifecycle='private_pending' where id=p_id;
  else raise exception 'Invalid private upload transition'; end if;
 elsif p_action='approve' then
  if m.lifecycle='approved_for_publish' then null;
  elsif m.lifecycle='private_pending' then
   update public.media_assets set lifecycle='approved_for_publish' where id=p_id;
   update public.media_workflows set reviewed_by=auth.uid(),reviewed_at=now() where media_id=p_id;
  else raise exception 'Private media review required'; end if;
 elsif p_action='begin_publish' then
  if m.lifecycle='linked' then null;
  elsif m.lifecycle in ('approved_for_publish','uploading','failed') and w.reviewed_at is not null then
   update public.media_assets set lifecycle='uploading' where id=p_id;
  else raise exception 'Explicit publication approval required'; end if;
 elsif p_action='complete' then
  if m.lifecycle='linked' then
   if m.cloudinary_asset_id is distinct from p_result->>'asset_id' or m.cloudinary_version is distinct from (p_result->>'version')::bigint then raise exception 'Duplicate completion mismatch'; end if;
  elsif m.lifecycle='uploading' and w.reviewed_at is not null then
   if p_result->>'public_id' is distinct from w.expected_public_id or p_result->>'resource_type' is distinct from 'image'
    or p_result->>'type' is distinct from 'upload' or coalesce(p_result->>'asset_id','')=''
    or coalesce(p_result->>'format','') not in ('jpg','png','webp') or coalesce((p_result->>'version')::bigint,0)<1
    or coalesce((p_result->>'width')::integer,0) not between 1 and 12000
    or coalesce((p_result->>'height')::integer,0) not between 1 and 12000
    or (p_result->>'width')::bigint*(p_result->>'height')::bigint>40000000
    or (p_result->>'bytes')::bigint is distinct from m.byte_size
    or p_result->>'sha256' is distinct from m.content_sha256 then raise exception 'Verified provider metadata required'; end if;
   update public.media_assets set provider='cloudinary',private_bucket=null,private_path=null,
    cloudinary_public_id=w.expected_public_id,cloudinary_asset_id=p_result->>'asset_id',cloudinary_version=(p_result->>'version')::bigint,
    cloudinary_resource_type='image',cloudinary_format=p_result->>'format',width=(p_result->>'width')::integer,height=(p_result->>'height')::integer,
    status='approved',lifecycle='linked' where id=p_id;
   if w.replace_association_id is not null then
    select * into a from public.product_media where id=w.replace_association_id and product_id=w.product_id and variant_id is not distinct from w.variant_id for update;
    if not found then raise exception 'Replacement target no longer exists'; end if;
    if a.media_id is distinct from w.replace_media_id then raise exception 'Replacement target changed; review new intent'; end if;
    old_media=a.media_id;
    update public.product_media set media_id=p_id where id=a.id;
    update public.media_assets set lifecycle='retired' where id=old_media and lifecycle='linked';
   else
    select coalesce(max(position),-1)+1 into pos from public.product_media where product_id=w.product_id and variant_id is not distinct from w.variant_id;
    insert into public.product_media(product_id,variant_id,media_id,position,is_primary)
     values(w.product_id,w.variant_id,p_id,pos,not exists(select 1 from public.product_media where product_id=w.product_id and variant_id is not distinct from w.variant_id and is_primary)) returning * into a;
   end if;
   update public.media_workflows set association_id=a.id,error_code=null where media_id=p_id;
  else raise exception 'Invalid completion state'; end if;
 elsif p_action='failed' then
  if m.lifecycle in ('private_uploading','uploading','failed') then
   update public.media_assets set lifecycle='failed' where id=p_id;
   update public.media_workflows set error_code='provider_or_validation_failed' where media_id=p_id;
  end if;
 elsif p_action='detach' then
  if m.lifecycle not in ('linked','retired') then raise exception 'Cannot detach this state'; end if;
  delete from public.product_media where media_id=p_id and product_id=w.product_id and variant_id is not distinct from w.variant_id;
  if not exists(select 1 from public.product_media where product_id=w.product_id and variant_id is not distinct from w.variant_id and is_primary) then
   update public.product_media set is_primary=true where id=(select id from public.product_media where product_id=w.product_id and variant_id is not distinct from w.variant_id order by position,id limit 1);
  end if;
  update public.media_assets set lifecycle='retired' where id=p_id;
 elsif p_action='claim_cleanup' then
  if exists(select 1 from public.product_media where media_id=p_id) or exists(select 1 from public.article_media where media_id=p_id)
   or exists(select 1 from public.homepage_selections where media_id=p_id) then raise exception 'Referenced media cannot be deleted'; end if;
  if exists(select 1 from public.media_assets where id<>p_id and
    ((cloudinary_public_id=w.expected_public_id and (cloudinary_cloud_name=m.cloudinary_cloud_name or cloudinary_cloud_name is null))
     or private_path=w.private_path)) then raise exception 'Provider identity has another database owner'; end if;
  if m.lifecycle in ('uploading','failed','private_uploading') and w.updated_at>now()-interval '24 hours' then raise exception 'Wait for uncertain uploads to settle'; end if;
  if m.lifecycle<>'deleted' then update public.media_assets set lifecycle='deleting',status='rejected' where id=p_id; end if;
 elsif p_action='deleted' then
  if m.lifecycle not in ('deleting','deleted') then raise exception 'Cleanup claim required'; end if;
  update public.media_assets set lifecycle='deleted',status='rejected' where id=p_id;
 else raise exception 'Unknown media action'; end if;
 update public.media_workflows set updated_at=now() where media_id=p_id;
 return (select to_jsonb(ma)||jsonb_build_object('workflow',to_jsonb(mw)) from public.media_assets ma join public.media_workflows mw on mw.media_id=ma.id where ma.id=p_id);
end $$;

create function public.reorder_product_media(p_product uuid,p_variant uuid,p_ids uuid[]) returns void
language plpgsql security definer set search_path='' as $$
declare total integer; base integer; begin
 perform app_private.require_admin();
 perform 1 from public.products where id=p_product for update;
 select count(*),coalesce(max(position),0)+1 into total,base from public.product_media where product_id=p_product and variant_id is not distinct from p_variant;
 if p_ids is null or cardinality(p_ids)<>total or total>1000 or base>2147480000
  or (select count(distinct x) from unnest(p_ids) x)<>total
  or exists(select 1 from unnest(p_ids) x where not exists(select 1 from public.product_media where id=x and product_id=p_product and variant_id is not distinct from p_variant)) then raise exception 'Exact association list required'; end if;
 update public.product_media pm set position=base+u.ord::integer from unnest(p_ids) with ordinality u(id,ord) where pm.id=u.id;
 update public.product_media pm set position=u.ord::integer-1 from unnest(p_ids) with ordinality u(id,ord) where pm.id=u.id;
end $$;
revoke all on function public.create_media_upload(uuid,uuid,uuid,text,text,text,bigint,text,uuid),public.media_workflow_action(uuid,text,jsonb),public.reorder_product_media(uuid,uuid,uuid[]) from public,anon,authenticated;
grant execute on function public.create_media_upload(uuid,uuid,uuid,text,text,text,bigint,text,uuid),public.media_workflow_action(uuid,text,jsonb),public.reorder_product_media(uuid,uuid,uuid[]) to authenticated;
revoke all on function app_private.guard_media_reference() from public,anon,authenticated;

insert into app_private.sql_editor_receipts(version,filename,sha256) values('202610050007','202610050007_media_service.sql','a7e4b47a439f583911a4101e1dc53bcc20ac218c1bd1fa331a4db75973eac8ed');
notify pgrst, 'reload schema';
commit;
select 'MEDIA SERVICE MIGRATION COMMITTED' as result;
