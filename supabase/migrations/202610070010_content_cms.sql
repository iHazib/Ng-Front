-- Content CMS extension. Preserves existing products, source records and audit history.
alter table public.articles add column author text check(length(author)<=120),
 add column seo_title text check(length(seo_title)<=160), add column seo_description text check(length(seo_description)<=320),
 add column revision integer not null default 1 check(revision>0), add column deleted_at timestamptz;
create table public.editorial_categories(id uuid primary key default gen_random_uuid(),name text not null unique check(length(btrim(name)) between 1 and 80));
alter table public.articles add column category_id uuid references public.editorial_categories(id);
create table public.editorial_tags(id uuid primary key default gen_random_uuid(),name text not null unique check(length(btrim(name)) between 1 and 60));
create table public.article_tags(article_id uuid references public.articles(id),tag_id uuid references public.editorial_tags(id),primary key(article_id,tag_id));
alter table public.article_media add column id uuid not null default gen_random_uuid() unique,
 add column kind text not null default 'inline' check(kind in('cover','inline'));
create unique index article_one_cover on public.article_media(article_id) where kind='cover';
alter table public.homepage_selections add column slide_theme text check(slide_theme in('sage','warm','blush')),add column retired_at timestamptz;
create table public.homepage_media(id uuid primary key default gen_random_uuid(),homepage_id uuid not null unique references public.homepage_selections(id),media_id uuid not null references public.media_assets(id));
alter table public.media_workflows alter column product_id drop not null,
 add column article_id uuid references public.articles(id),add column homepage_id uuid references public.homepage_selections(id),
 add column content_kind text check(content_kind in('cover','inline','slide')),
 add constraint media_exact_owner check(num_nonnulls(product_id,article_id,homepage_id)=1),
 add constraint media_content_owner_kind check((product_id is not null and content_kind is null) or (article_id is not null and content_kind is not null and content_kind in('cover','inline')) or (homepage_id is not null and content_kind is not null and content_kind='slide')),
 add constraint content_media_no_variant check(product_id is not null or variant_id is null);
create index content_media_article on public.media_workflows(article_id) where article_id is not null;
create index article_public_listing on public.articles(published_at desc,id) where status='published' and deleted_at is null;
create trigger media_reference_guard before insert or update on public.homepage_media for each row execute function app_private.guard_media_reference();
do $policies$ declare t text; begin
 foreach t in array array['editorial_categories','editorial_tags','article_tags','homepage_media'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated',t);
 execute format('grant select on public.%I to anon,authenticated',t);
 execute format('grant insert,update,delete on public.%I to authenticated',t);
 execute format('create policy admin_access on public.%I to authenticated using((select public.is_admin())) with check((select public.is_admin()))',t);
 execute format('create trigger audit_changes after insert or update or delete on public.%I for each row execute function app_private.audit_change()',t);
 end loop;
END; $policies$;
-- Policies replaced only to add soft-deletion isolation; no data is dropped.
drop policy public_read on public.articles;
create policy public_read on public.articles for select to anon,authenticated using(status='published' and published_at<=now() and deleted_at is null);
create policy public_read on public.article_tags for select to anon,authenticated using(exists(select 1 from public.articles a where a.id=article_id));
create policy public_read on public.editorial_categories for select to anon,authenticated using(exists(select 1 from public.articles a where a.category_id=editorial_categories.id));
create policy public_read on public.editorial_tags for select to anon,authenticated using(exists(select 1 from public.article_tags t where t.tag_id=editorial_tags.id));
create policy public_read on public.homepage_media for select to anon,authenticated using(exists(select 1 from public.homepage_selections h where h.id=homepage_id and h.status='published' and h.retired_at is null) and public.media_is_public(media_id));

create or replace function public.media_is_public(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.media_assets m where m.id=p_id and m.provider='cloudinary' and m.status='approved') and (
    exists(select 1 from public.product_media pm where pm.media_id=p_id and public.product_is_public(pm.product_id) and (pm.variant_id is null or public.variant_is_public(pm.variant_id)))
    or exists(select 1 from public.article_media am join public.articles a on a.id=am.article_id where am.media_id=p_id and a.status='published' and a.published_at<=now() and a.deleted_at is null)
    or exists(select 1 from public.homepage_media hm join public.homepage_selections hs on hs.id=hm.homepage_id join public.articles a on a.id=hs.article_id where hm.media_id=p_id and hs.status='published' and hs.retired_at is null and a.status='published' and a.published_at<=now() and a.deleted_at is null)
    or exists(select 1 from public.homepage_selections h where h.media_id=p_id and h.status='published' and h.section='hero')
  )
$$;
create function app_private.product_media_workflow_action(p_id uuid,p_action text,p_result jsonb default '{}') returns jsonb
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
   or exists(select 1 from public.homepage_selections where media_id=p_id) or exists(select 1 from public.homepage_media where media_id=p_id) then raise exception 'Referenced media cannot be deleted'; end if;
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
create or replace function public.media_workflow_action(p_id uuid,p_action text,p_result jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare m public.media_assets; w public.media_workflows; a record; pos integer; old_media uuid; begin
 perform app_private.require_admin();
 -- Global ordering: product, media, workflow. Reference guards also lock media.
 select * into w from public.media_workflows where media_id=p_id;
 if not found then raise exception 'Media workflow missing'; end if;
 if w.product_id is not null then return app_private.product_media_workflow_action(p_id,p_action,p_result); end if;
 if w.article_id is not null then perform 1 from public.articles where id=w.article_id for update;
 else perform 1 from public.homepage_selections where id=w.homepage_id for update; end if;
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
    if w.article_id is not null then
     select id,media_id into a from public.article_media where id=w.replace_association_id and article_id=w.article_id and kind=w.content_kind for update;
    else select id,media_id into a from public.homepage_media where id=w.replace_association_id and homepage_id=w.homepage_id for update; end if;
    if not found or a.media_id is distinct from w.replace_media_id then raise exception 'Replacement target changed'; end if;
    old_media=a.media_id;
    if w.article_id is not null then
     update public.article_media set media_id=p_id where id=a.id;
     update public.articles set body=replace(body,old_media::text,p_id::text),revision=revision+1 where id=w.article_id;
    else update public.homepage_media set media_id=p_id where id=a.id; end if;
    update public.media_assets set lifecycle='retired' where id=old_media and lifecycle='linked';
   elsif w.article_id is not null then
    if w.content_kind='cover' and exists(select 1 from public.article_media where article_id=w.article_id and kind='cover') then raise exception 'Choose Replace for the existing cover'; end if;
    select coalesce(max(position),-1)+1 into pos from public.article_media where article_id=w.article_id;
    insert into public.article_media(article_id,media_id,position,kind) values(w.article_id,p_id,pos,w.content_kind) returning id into a;
   else
    if exists(select 1 from public.homepage_media where homepage_id=w.homepage_id) then raise exception 'Choose Replace for the existing slide image'; end if;
    insert into public.homepage_media(homepage_id,media_id) values(w.homepage_id,p_id) returning id into a;
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
  if w.article_id is not null then
   if exists(select 1 from public.articles where id=w.article_id and status='published' and body like '%'||p_id::text||'%') then raise exception 'Remove this inline image from the article and save before deleting it'; end if;
   delete from public.article_media where media_id=p_id and article_id=w.article_id;
  else delete from public.homepage_media where media_id=p_id and homepage_id=w.homepage_id; end if;
  update public.media_assets set lifecycle='retired' where id=p_id;
 elsif p_action='claim_cleanup' then
  if exists(select 1 from public.product_media where media_id=p_id) or exists(select 1 from public.article_media where media_id=p_id)
   or exists(select 1 from public.homepage_selections where media_id=p_id) or exists(select 1 from public.homepage_media where media_id=p_id) then raise exception 'Referenced media cannot be deleted'; end if;
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

create function public.create_content_media_upload(p_id uuid,p_article uuid,p_homepage uuid,p_kind text,p_environment text,p_cloud text,p_hash text,p_bytes bigint,p_alt text,p_replace uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $intent$
declare m public.media_assets; w public.media_workflows; path text; old_media uuid; begin
 perform app_private.require_admin();
 if num_nonnulls(p_article,p_homepage)<>1 or (p_article is not null and p_kind not in('cover','inline')) or (p_homepage is not null and p_kind<>'slide')
 or p_environment not in('development','staging','production') or p_cloud !~ '^[a-zA-Z0-9_-]+$' or p_hash !~ '^[a-f0-9]{64}$'
 or p_bytes not between 1 and 10485760 or length(btrim(p_alt)) not between 1 and 500 then raise exception 'Invalid image owner or upload'; end if;
 if p_article is not null then perform 1 from public.articles where id=p_article and deleted_at is null for update;
 else perform 1 from public.homepage_selections where id=p_homepage and section='the-edit' and retired_at is null for update; end if;
 if not found then raise exception 'Save this content before uploading images'; end if;
 select * into m from public.media_assets where id=p_id for update;
 if found then
 select * into w from public.media_workflows where media_id=p_id;
 if w.media_id is null or w.article_id is distinct from p_article or w.homepage_id is distinct from p_homepage or w.content_kind is distinct from p_kind
 or w.replace_association_id is distinct from p_replace or m.content_sha256 is distinct from p_hash or m.byte_size is distinct from p_bytes or m.alt is distinct from p_alt or m.media_environment is distinct from p_environment or m.cloudinary_cloud_name is distinct from p_cloud then raise exception 'Retry identity changed'; end if;
 return jsonb_build_object('media_id',m.id,'lifecycle',m.lifecycle,'private_path',w.private_path); end if;
 if p_replace is not null then
 if p_article is not null then select media_id into old_media from public.article_media where id=p_replace and article_id=p_article and kind=p_kind;
 else select media_id into old_media from public.homepage_media where id=p_replace and homepage_id=p_homepage; end if;
 if not found then raise exception 'Replacement owner mismatch'; end if; end if;
 path='media/'||p_environment||'/'||p_id::text||'/original';
 insert into public.media_assets(id,provider,private_bucket,private_path,alt,media_environment,cloudinary_cloud_name,content_sha256,byte_size,lifecycle)
 values(p_id,'supabase_private','catalog-private',path,p_alt,p_environment,p_cloud,p_hash,p_bytes,'private_uploading');
 insert into public.media_workflows(media_id,article_id,homepage_id,content_kind,private_path,expected_public_id,replace_association_id,replace_media_id)
 values(p_id,p_article,p_homepage,p_kind,path,'nook-glow/'||p_environment||'/'||p_id::text,p_replace,old_media);
 return jsonb_build_object('media_id',p_id,'lifecycle','private_uploading','private_path',path);
END; $intent$;

create function public.save_article(p_id uuid,p_revision integer,p_data jsonb,p_intent text default 'save') returns jsonb
language plpgsql security definer set search_path='' as $article$
declare a public.articles; desired public.publication_status; category uuid; label text; tag uuid; image uuid; fresh boolean=false; begin
 perform app_private.require_admin();
 if p_intent is null or p_intent not in('save','draft','publish','hide','delete') or p_revision is null or p_revision<0 or p_id is null or p_data is null or jsonb_typeof(p_data)<>'object' then raise exception 'Invalid article action'; end if;
 select * into a from public.articles where id=p_id for update;
 if not found then
 if p_revision<>0 then raise exception 'Article no longer exists'; end if;
 insert into public.articles(id,title) values(p_id,coalesce(nullif(btrim(p_data->>'title'),''),'Untitled article')) returning * into a;fresh=true;
 elsif a.revision<>p_revision or a.deleted_at is not null then raise exception 'This article changed. Reload before saving; your entered text is kept.'; end if;
 if p_intent='delete' then
 update public.articles set status='archived',deleted_at=now(),revision=revision+1 where id=p_id;
 update public.homepage_selections set status='archived',retired_at=now() where article_id=p_id;
 update public.media_assets set lifecycle='retired' where id in(select media_id from public.article_media where article_id=p_id) and lifecycle='linked';
 delete from public.article_media where article_id=p_id;
 return jsonb_build_object('id',p_id,'deleted',true); end if;
 if length(coalesce(p_data->>'title',''))>300 or length(coalesce(p_data->>'body',''))>100000 or length(coalesce(p_data->>'summary',''))>1000
 or length(coalesce(p_data->>'author',''))>120 or length(coalesce(p_data->>'seoTitle',''))>160 or length(coalesce(p_data->>'seoDescription',''))>320
 or (nullif(p_data->>'slug','') is not null and (p_data->>'slug' !~ '^[a-z0-9]+(-[a-z0-9]+)*$' or length(p_data->>'slug')>160)) then raise exception 'Check title, slug and content lengths'; end if;
 if coalesce(p_data->>'category','')<>'' then
 if length(btrim(p_data->>'category'))>80 then raise exception 'Category is too long'; end if;
 insert into public.editorial_categories(name) values(btrim(p_data->>'category')) on conflict(name) do update set name=excluded.name returning id into category; end if;
 desired=case p_intent when 'draft' then 'draft' when 'publish' then 'published' when 'hide' then 'archived' else a.status end;
 if desired='published' then
 if length(btrim(coalesce(p_data->>'title','')))=0 or nullif(p_data->>'slug','') is null or length(btrim(regexp_replace(coalesce(p_data->>'body',''),'<[^>]*>','','g')))=0 then raise exception 'To publish, add a title, valid slug and article text. Or choose Save draft.'; end if;
 for image in select x[1]::uuid from regexp_matches(coalesce(p_data->>'body',''),'data-media-id="([a-f0-9-]{36})"','g') x loop
 if not exists(select 1 from public.article_media am join public.media_assets m on m.id=am.media_id where am.article_id=p_id and am.media_id=image and am.kind='inline' and m.provider='cloudinary' and m.status='approved' and m.lifecycle='linked') then raise exception 'Approve each inline image before publishing'; end if;
 end loop; end if;
 update public.articles set title=coalesce(nullif(btrim(p_data->>'title'),''),'Untitled article'),slug=nullif(p_data->>'slug',''),excerpt=nullif(p_data->>'summary',''),body=p_data->>'body',author=nullif(p_data->>'author',''),category_id=category,
 seo_title=nullif(p_data->>'seoTitle',''),seo_description=nullif(p_data->>'seoDescription',''),status=desired,published_at=case when desired='published' then coalesce(published_at,now()) else published_at end,revision=case when fresh then 1 else revision+1 end,updated_at=now() where id=p_id returning * into a;
 if jsonb_typeof(coalesce(p_data->'tags','[]'))<>'array' or jsonb_array_length(coalesce(p_data->'tags','[]'))>20 then raise exception 'Use at most 20 tags'; end if;
 delete from public.article_tags where article_id=p_id;
 for label in select distinct lower(btrim(value)) from jsonb_array_elements_text(coalesce(p_data->'tags','[]')) loop
 if length(label) not between 1 and 60 then raise exception 'Each tag needs 1–60 characters'; end if;
 insert into public.editorial_tags(name) values(label) on conflict(name) do update set name=excluded.name returning id into tag;
 insert into public.article_tags values(p_id,tag);end loop;
 return jsonb_build_object('id',a.id,'revision',a.revision,'status',a.status);
END; $article$;

create function public.save_homepage_content(p_section text,p_items jsonb) returns void
language plpgsql security definer set search_path='' as $homepage$
declare item jsonb; position integer=0; offset_position integer; chosen uuid; entity uuid; previous uuid; begin
 perform app_private.require_admin();
 if p_section not in('products','the-edit') or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)>12 then raise exception 'Choose up to 12 manual selections'; end if;
 perform pg_advisory_xact_lock(73525);
 if (select count(distinct value->>'entity') from jsonb_array_elements(p_items))<>jsonb_array_length(p_items) then raise exception 'Choose each item once'; end if;
 select coalesce(max(h.position),-1)+100 into offset_position from public.homepage_selections h where h.section=p_section;
 if offset_position>2147480000 then raise exception 'Selection order needs maintenance'; end if;
 update public.homepage_selections set position=homepage_selections.position+offset_position,retired_at=now(),status='archived' where section=p_section and retired_at is null;
 for item in select value from jsonb_array_elements(p_items) loop
 entity=(item->>'entity')::uuid;chosen=(item->>'id')::uuid;
 if p_section='products' and not public.product_is_public(entity) then raise exception 'Choose an eligible published product'; end if;
 if p_section='the-edit' and not exists(select 1 from public.articles where id=entity and status='published' and published_at<=now() and deleted_at is null) then raise exception 'Choose a published article'; end if;
 if p_section='the-edit' and coalesce(item->>'theme','sage') not in('sage','warm','blush') then raise exception 'Choose Sage, Warm or Blush'; end if;
 select id into previous from public.homepage_selections where id=chosen and section=p_section and (product_id=entity or article_id=entity);
 if not found and exists(select 1 from public.homepage_selections where id=chosen) then raise exception 'Selection identity changed'; end if;
 insert into public.homepage_selections(id,section,position,status,product_id,article_id,slide_theme)
 values(chosen,p_section,position,'published',case when p_section='products' then entity end,case when p_section='the-edit' then entity end,case when p_section='the-edit' then coalesce(item->>'theme','sage') end)
 on conflict(id) do update set position=excluded.position,status='published',retired_at=null,slide_theme=excluded.slide_theme;
 position=position+1;end loop;
END; $homepage$;

create function app_private.content_public_media(p_id uuid) returns jsonb language sql stable set search_path='' as $image$
 select jsonb_build_object('id',id,'alt',alt,'source',jsonb_build_object('kind','cloudinary','cloudName',cloudinary_cloud_name,'publicId',cloudinary_public_id,'version',cloudinary_version,'format',cloudinary_format,'width',width,'height',height,'publication','published'))
 from public.media_assets where id=p_id and provider='cloudinary' and status='approved' and lifecycle='linked';
$image$;
create function public.storefront_articles(p_slug text default null,p_home boolean default false,p_page integer default 1,p_size integer default 12) returns jsonb
language sql stable security definer set search_path='' set statement_timeout='8s' as $public_articles$
 with eligible as materialized(select a.*,c.name category from public.articles a left join public.editorial_categories c on c.id=a.category_id where a.status='published' and a.published_at<=now() and a.deleted_at is null and (p_slug is null or a.slug=left(p_slug,160))
 and (not p_home or exists(select 1 from public.homepage_selections h where h.article_id=a.id and h.section='the-edit' and h.status='published' and h.retired_at is null))),
 paged as(select * from eligible order by case when p_home then (select min(position) from public.homepage_selections h where h.article_id=eligible.id and h.section='the-edit' and h.status='published' and h.retired_at is null) end,published_at desc,id limit least(greatest(p_size,1),24) offset (least(greatest(p_page,1),10000)-1)*least(greatest(p_size,1),24))
 select jsonb_build_object('total',(select count(*) from eligible),'articles',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'title',a.title,'slug',a.slug,'summary',a.excerpt,'body',case when p_slug is not null then a.body else null end,'author',a.author,'category',a.category,'publishedAt',a.published_at,'seoTitle',a.seo_title,'seoDescription',a.seo_description,
 'tags',coalesce((select jsonb_agg(t.name order by t.name) from public.article_tags at join public.editorial_tags t on t.id=at.tag_id where at.article_id=a.id),'[]'),
 'theme',coalesce((select slide_theme from public.homepage_selections h where h.article_id=a.id and h.section='the-edit' and h.status='published' and h.retired_at is null order by position limit 1),a.theme,'sage'),
 'cover',coalesce(case when p_home then (select app_private.content_public_media(hm.media_id) from public.homepage_media hm join public.homepage_selections h on h.id=hm.homepage_id where h.article_id=a.id and h.section='the-edit' and h.status='published' and h.retired_at is null limit 1) end,(select app_private.content_public_media(am.media_id) from public.article_media am where am.article_id=a.id and am.kind='cover' limit 1)),
 'images',coalesce((select jsonb_agg(app_private.content_public_media(am.media_id) order by position) from public.article_media am where am.article_id=a.id and am.kind='inline' and app_private.content_public_media(am.media_id) is not null),'[]'))) from paged a),'[]'));
$public_articles$;
create function public.admin_content_choices(p_kind text,p_query text default '') returns jsonb language plpgsql stable security definer set search_path='' as $choices$
begin perform app_private.require_admin();
 if p_kind='products' then return coalesce((select jsonb_agg(x) from(select distinct product_id id,name,slug from app_private.storefront_variants where name ilike '%'||left(p_query,100)||'%' order by name limit 50) x),'[]');
 elsif p_kind='the-edit' then return coalesce((select jsonb_agg(x) from(select id,title name from public.articles where status='published' and deleted_at is null and title ilike '%'||left(p_query,100)||'%' order by title limit 50) x),'[]');
 elsif p_kind='categories' then return coalesce((select jsonb_agg(x) from(select distinct scope id,scope name,case scope when 'personal-fragrance' then '/fragrances/personal-fragrance' when 'home-fragrance' then '/fragrances/home-fragrance' else '/'||scope end href from app_private.storefront_variants order by scope) x),'[]');
 else raise exception 'Unsupported selection'; end if;
END; $choices$;
revoke all on function app_private.product_media_workflow_action(uuid,text,jsonb),app_private.content_public_media(uuid) from public,anon,authenticated;
revoke all on function public.create_content_media_upload(uuid,uuid,uuid,text,text,text,text,bigint,text,uuid),public.save_article(uuid,integer,jsonb,text),public.save_homepage_content(text,jsonb),public.admin_content_choices(text,text),public.storefront_articles(text,boolean,integer,integer) from public,anon,authenticated;
grant execute on function public.create_content_media_upload(uuid,uuid,uuid,text,text,text,text,bigint,text,uuid),public.save_article(uuid,integer,jsonb,text),public.save_homepage_content(text,jsonb),public.admin_content_choices(text,text) to authenticated;
grant execute on function public.storefront_articles(text,boolean,integer,integer) to anon,authenticated;
notify pgrst,'reload schema';
create function public.content_link_targets(p_paths text[]) returns jsonb language sql stable security definer set search_path='' as $links$
 select coalesce(jsonb_agg(path),'[]') from (select distinct path from unnest(p_paths[1:32]) path where
 (path like '/products/%' and exists(select 1 from public.products p where '/products/'||p.slug=path and public.product_is_public(p.id)))
 or exists(select 1 from app_private.storefront_variants v where path=case v.scope when 'personal-fragrance' then '/fragrances/personal-fragrance' when 'home-fragrance' then '/fragrances/home-fragrance' else '/'||v.scope end)
 or (path='/fragrances' and exists(select 1 from app_private.storefront_variants where scope in('personal-fragrance','home-fragrance')))) x;
$links$;
revoke all on function public.content_link_targets(text[]) from public,anon,authenticated;
grant execute on function public.content_link_targets(text[]) to anon,authenticated;
