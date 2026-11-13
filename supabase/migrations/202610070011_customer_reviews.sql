-- Additive customer reviews; original review/contact/order evidence retained.
alter table public.reviews add column title text,add column hidden_at timestamptz,
 add column revision integer not null default 1 check(revision>0),add column updated_at timestamptz not null default now(),
 add column submission_complete boolean not null default false;
alter table public.review_private add column email text,add column submission_hash text unique,add column payload_hash text;
create table public.review_media(id uuid primary key default gen_random_uuid(),review_id uuid not null references public.reviews(id),
 media_id uuid not null unique references public.media_assets(id),position integer not null check(position>=0),unique(review_id,position));
alter table public.review_media enable row level security;
revoke all on public.review_media from public,anon,authenticated;
grant select on public.review_media to anon,authenticated;
grant insert,update,delete on public.review_media to authenticated;
create policy admin_access on public.review_media to authenticated using((select public.is_admin())) with check((select public.is_admin()));
create trigger audit_changes after insert or update or delete on public.review_media for each row execute function app_private.audit_change();
create trigger media_reference_guard before insert or update on public.review_media for each row execute function app_private.guard_media_reference();
alter table public.media_workflows add column review_id uuid references public.reviews(id);
alter table public.media_workflows drop constraint media_exact_owner,drop constraint media_content_owner_kind;
alter table public.media_workflows add constraint media_exact_owner check(num_nonnulls(product_id,article_id,homepage_id,review_id)=1),
 add constraint media_content_owner_kind check((product_id is not null and content_kind is null) or (article_id is not null and content_kind in('cover','inline')) or (homepage_id is not null and content_kind='slide') or (review_id is not null and content_kind is null));
create index review_media_owner on public.media_workflows(review_id) where review_id is not null;
create index review_moderation_queue on public.reviews(status,created_at desc,id);
create index review_public_product on public.reviews(product_id,created_at desc,id) where status='approved' and hidden_at is null;
create table app_private.review_limits(key text not null,window_start timestamptz not null,attempts integer not null check(attempts>0),primary key(key,window_start));
alter table app_private.review_limits enable row level security;
revoke all on app_private.review_limits from public,anon,authenticated;

create function public.review_is_public(p_id uuid) returns boolean language sql stable security definer set search_path='' as $eligible$
 select exists(select 1 from public.reviews r where r.id=p_id and r.status='approved' and r.hidden_at is null
 and public.product_is_public(r.product_id) and not exists(select 1 from public.media_workflows w join public.media_assets m on m.id=w.media_id
 where w.review_id=r.id and m.lifecycle not in('retired','deleted') and (m.lifecycle<>'linked' or m.status<>'approved')));
$eligible$;
revoke all on function public.review_is_public(uuid) from public;
grant execute on function public.review_is_public(uuid) to anon,authenticated;
drop policy public_read on public.reviews;
create policy public_read on public.reviews for select to anon,authenticated using(public.review_is_public(id));
create policy public_read on public.review_media for select to anon,authenticated using(public.review_is_public(review_id) and public.media_is_public(media_id));

create table public.review_moderation_events(id bigint generated always as identity primary key,review_id uuid not null references public.reviews(id),action text not null check(action in('approve','decline','hide','edit')),revision integer not null,actor_id uuid references auth.users(id),occurred_at timestamptz not null default now());
alter table public.review_moderation_events enable row level security;
revoke all on public.review_moderation_events from public,anon,authenticated;
grant select on public.review_moderation_events to authenticated;
create policy admin_read on public.review_moderation_events for select to authenticated using((select public.is_admin()));
create index review_events_owner on public.review_moderation_events(review_id,occurred_at desc,id);
-- ANY edit to visible customer content returns it to moderation, including direct admin writes.
create function app_private.review_edit_guard() returns trigger language plpgsql security definer set search_path='' as $edit$
begin
 if new.product_id is distinct from old.product_id then raise exception 'Review product identity cannot change';end if;
 if row(new.rating,new.display_name,new.title,new.body) is distinct from row(old.rating,old.display_name,old.title,old.body) then
  if length(btrim(new.display_name)) not between 1 and 80 or length(btrim(new.body)) not between 10 and 4000 or length(coalesce(new.title,''))>160 then raise exception 'Check review name, title and text';end if;
  new.status='pending';new.hidden_at=null;new.revision=old.revision+1;
  insert into public.review_moderation_events(review_id,action,revision,actor_id) values(new.id,'edit',new.revision,auth.uid());
 end if;
 new.updated_at=now();return new;
END; $edit$;
create trigger review_edit_guard before update on public.reviews for each row execute function app_private.review_edit_guard();

create function app_private.review_rate(p_key text,p_limit integer) returns void language plpgsql set search_path='' as $rate$
declare n integer;begin
 insert into app_private.review_limits values(p_key,date_trunc('hour',now()),1)
 on conflict(key,window_start) do update set attempts=review_limits.attempts+1 returning attempts into n;
 if n>p_limit then raise sqlstate 'PT429' using message='Review submission limit reached';end if;
 delete from app_private.review_limits where window_start<now()-interval '48 hours';
END; $rate$;
revoke all on function app_private.review_rate(text,integer),app_private.review_edit_guard() from public,anon,authenticated;

-- Only the server's Supabase secret/service key may call this guest gateway.
-- Browser anon/authenticated clients have neither execute nor direct INSERT access.
create function public.submit_customer_review(p_id uuid,p_product uuid,p_data jsonb,p_token text,p_rate text,p_media jsonb default '[]') returns jsonb
language plpgsql security definer set search_path='' set statement_timeout='8s' as $submit$
declare r public.reviews;item jsonb;path text;mid uuid;name text=btrim(p_data->>'name');body text=btrim(p_data->>'body');rating integer=(p_data->>'rating')::integer;payload text=encode(sha256(convert_to(p_data::text||p_product::text||p_media::text,'UTF8')),'hex');begin
 if p_token is null or p_token !~ '^[a-f0-9]{64}$' or p_rate is null or p_rate !~ '^[a-f0-9]{64}$' then raise exception 'Invalid submission session';end if;
 if p_data is null or name is null or body is null or rating is null or length(name) not between 1 and 80 or length(body) not between 10 and 4000 or rating not between 1 and 5 or length(coalesce(p_data->>'title',''))>160
 or length(coalesce(p_data->>'email',''))>254 or (coalesce(p_data->>'email','')<>'' and p_data->>'email' !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')
 or jsonb_typeof(p_media) is distinct from 'array' or jsonb_array_length(p_media)>3 then raise exception 'Invalid review fields';end if;
 if not public.product_is_public(p_product) then raise exception 'Choose an eligible published product';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_token,0));
 select rv.* into r from public.reviews rv join public.review_private rp on rp.review_id=rv.id where rp.submission_hash=p_token;
 if found then
  if r.id<>p_id or (select payload_hash from public.review_private where review_id=r.id)<>payload then raise exception 'Submission identity mismatch';end if;
 else
  perform app_private.review_rate('global',100);perform app_private.review_rate('visitor:'||p_rate,5);
  if exists(select 1 from public.review_private rp join public.reviews rv on rv.id=rp.review_id where rp.payload_hash=payload and rv.created_at>now()-interval '24 hours') then raise exception 'Duplicate review already received';end if;
  insert into public.reviews(id,product_id,display_name,rating,title,body) values(p_id,p_product,name,rating,nullif(btrim(p_data->>'title'),''),body);
  insert into public.review_private(review_id,email,submission_hash,payload_hash) values(p_id,nullif(btrim(p_data->>'email'),''),p_token,payload);
  for item in select value from jsonb_array_elements(p_media) loop
   mid=(item->>'id')::uuid;
   if item->>'environment' is null or item->>'environment' not in('development','staging','production') or item->>'cloud' is null or item->>'cloud' !~ '^[a-zA-Z0-9_-]+$' or item->>'hash' is null or item->>'hash' !~ '^[a-f0-9]{64}$' or (item->>'bytes')::bigint is null or (item->>'bytes')::bigint not between 1 and 5242880 or length(btrim(coalesce(item->>'alt',''))) not between 1 and 500 then raise exception 'Invalid review image';end if;
   path='media/'||(item->>'environment')||'/'||mid::text||'/original';
   insert into public.media_assets(id,provider,private_bucket,private_path,alt,media_environment,cloudinary_cloud_name,content_sha256,byte_size,lifecycle)
   values(mid,'supabase_private','catalog-private',path,item->>'alt',item->>'environment',item->>'cloud',item->>'hash',(item->>'bytes')::bigint,'private_uploading');
   insert into public.media_workflows(media_id,review_id,private_path,expected_public_id) values(mid,p_id,path,'nook-glow/'||(item->>'environment')||'/'||mid::text);
  end loop;
 end if;
 return jsonb_build_object('id',p_id,'images',coalesce((select jsonb_agg(jsonb_build_object('id',media_id,'path',private_path)) from public.media_workflows where review_id=p_id),'[]'));
END; $submit$;
create function public.complete_customer_review(p_id uuid,p_token text) returns void language plpgsql security definer set search_path='' as $finish$
begin
 perform 1 from public.reviews r join public.review_private rp on rp.review_id=r.id where r.id=p_id and rp.submission_hash=p_token and r.status='pending' for update of r;
 if not found then raise exception 'Review submission unavailable';end if;
 update public.media_assets m set lifecycle='private_pending' from public.media_workflows w where w.review_id=p_id and w.media_id=m.id and m.lifecycle='private_uploading';
 update public.reviews set submission_complete=true where id=p_id;
END; $finish$;
revoke all on function public.submit_customer_review(uuid,uuid,jsonb,text,text,jsonb),public.complete_customer_review(uuid,text) from public,anon,authenticated;
grant execute on function public.submit_customer_review(uuid,uuid,jsonb,text,text,jsonb),public.complete_customer_review(uuid,text) to service_role;

create function public.moderate_review(p_id uuid,p_revision integer,p_action text) returns void language plpgsql security definer set search_path='' as $moderate$
declare r public.reviews;begin
 perform app_private.require_admin();select * into r from public.reviews where id=p_id for update;
 if not found or r.revision<>p_revision then raise exception 'Review changed; reload before moderating';end if;
 if p_action='approve' then
  if not r.submission_complete or not public.product_is_public(r.product_id) or exists(select 1 from public.media_workflows w join public.media_assets m on m.id=w.media_id where w.review_id=p_id and m.lifecycle not in('retired','deleted') and (m.lifecycle<>'linked' or m.status<>'approved')) then raise exception 'Complete submission and approve every image before approving review';end if;
  update public.reviews set status='approved',hidden_at=null,revision=revision+1 where id=p_id;
  update public.review_private set approved_by=auth.uid(),approved_at=now() where review_id=p_id;
 elsif p_action='decline' then update public.reviews set status='rejected',hidden_at=null,revision=revision+1 where id=p_id;
 elsif p_action='hide' then update public.reviews set status='rejected',hidden_at=now(),revision=revision+1 where id=p_id;
 else raise exception 'Unknown moderation action';end if;
 insert into public.review_moderation_events(review_id,action,revision,actor_id) values(p_id,p_action,r.revision+1,auth.uid());
END; $moderate$;
revoke all on function public.moderate_review(uuid,integer,text) from public,anon,authenticated;
grant execute on function public.moderate_review(uuid,integer,text) to authenticated;

create function public.storefront_reviews(p_product uuid,p_page integer default 1) returns jsonb language sql stable security definer set search_path='' set statement_timeout='8s' as $public_reviews$
 with eligible as materialized(select * from public.reviews r where r.product_id=p_product and public.review_is_public(r.id)),
 paged as(select * from eligible order by created_at desc,id limit 10 offset (least(greatest(p_page,1),1000)-1)*10)
 select jsonb_build_object('total',(select count(*) from eligible),'average',(select round(avg(rating)::numeric,2) from eligible),'page',least(greatest(p_page,1),1000),
 'reviews',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'name',r.display_name,'rating',r.rating,'title',r.title,'body',r.body,'createdAt',r.created_at,
 'images',coalesce((select jsonb_agg(app_private.content_public_media(rm.media_id) order by rm.position) from public.review_media rm where rm.review_id=r.id and public.media_is_public(rm.media_id)),'[]')) order by r.created_at desc,r.id) from paged r),'[]'));
$public_reviews$;
revoke all on function public.storefront_reviews(uuid,integer) from public,anon,authenticated;
grant execute on function public.storefront_reviews(uuid,integer) to anon,authenticated;

create function app_private.review_media_workflow_action(p_id uuid,p_action text,p_result jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare m public.media_assets; w public.media_workflows; a public.review_media; pos integer; old_media uuid; begin
 perform app_private.require_admin();
 -- Global ordering: product, media, workflow. Reference guards also lock media.
 select * into w from public.media_workflows where media_id=p_id;
 if not found then raise exception 'Media workflow missing'; end if;
 perform 1 from public.reviews where id=w.review_id for update;
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
   select coalesce(max(position),-1)+1 into pos from public.review_media where review_id=w.review_id;
   insert into public.review_media(review_id,media_id,position) values(w.review_id,p_id,pos) returning * into a;
   update public.media_workflows set association_id=a.id,error_code=null where media_id=p_id;
  else raise exception 'Invalid completion state'; end if;
 elsif p_action='failed' then
  if m.lifecycle in ('private_uploading','uploading','failed') then
   update public.media_assets set lifecycle='failed' where id=p_id;
   update public.media_workflows set error_code='provider_or_validation_failed' where media_id=p_id;
  end if;
 elsif p_action='detach' then
  if m.lifecycle not in ('linked','retired') then raise exception 'Cannot detach this state'; end if;
  delete from public.review_media where media_id=p_id and review_id=w.review_id;
  update public.reviews set status='pending',hidden_at=null,revision=revision+1 where id=w.review_id;
  update public.media_assets set lifecycle='retired' where id=p_id;
 elsif p_action='claim_cleanup' then
  if exists(select 1 from public.product_media where media_id=p_id) or exists(select 1 from public.article_media where media_id=p_id)
   or exists(select 1 from public.homepage_selections where media_id=p_id) or exists(select 1 from public.homepage_media where media_id=p_id) or exists(select 1 from public.review_media where media_id=p_id) then raise exception 'Referenced media cannot be deleted'; end if;
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

create or replace function public.media_is_public(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.media_assets m where m.id=p_id and m.provider='cloudinary' and m.status='approved') and (
    exists(select 1 from public.product_media pm where pm.media_id=p_id and public.product_is_public(pm.product_id) and (pm.variant_id is null or public.variant_is_public(pm.variant_id)))
    or exists(select 1 from public.article_media am join public.articles a on a.id=am.article_id where am.media_id=p_id and a.status='published' and a.published_at<=now() and a.deleted_at is null)
    or exists(select 1 from public.homepage_media hm join public.homepage_selections hs on hs.id=hm.homepage_id join public.articles a on a.id=hs.article_id where hm.media_id=p_id and hs.status='published' and hs.retired_at is null and a.status='published' and a.published_at<=now() and a.deleted_at is null)
    or exists(select 1 from public.review_media rm join public.reviews r on r.id=rm.review_id where rm.media_id=p_id and public.review_is_public(r.id))
    or exists(select 1 from public.homepage_selections h where h.media_id=p_id and h.status='published' and h.section='hero')
  )
$$;


-- Preserve the entire prior content handler under a private name; one public dispatcher.
alter function public.media_workflow_action(uuid,text,jsonb) rename to content_media_workflow_action;
alter function public.content_media_workflow_action(uuid,text,jsonb) set schema app_private;
revoke all on function app_private.content_media_workflow_action(uuid,text,jsonb),app_private.review_media_workflow_action(uuid,text,jsonb) from public,anon,authenticated;
create function public.media_workflow_action(p_id uuid,p_action text,p_result jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $dispatch$
declare owner uuid;begin
 perform app_private.require_admin();
 if p_action='claim_cleanup' and exists(select 1 from public.review_media where media_id=p_id) then raise exception 'Referenced review media cannot be deleted';end if;
 select review_id into owner from public.media_workflows where media_id=p_id;
 if owner is not null then return app_private.review_media_workflow_action(p_id,p_action,p_result);end if;
 return app_private.content_media_workflow_action(p_id,p_action,p_result);
END; $dispatch$;
revoke all on function public.media_workflow_action(uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.media_workflow_action(uuid,text,jsonb) to authenticated;
notify pgrst,'reload schema';
