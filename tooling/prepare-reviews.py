from pathlib import Path
root=Path(__file__).resolve().parents[1]
content=(root/'supabase/migrations/202610070010_content_cms.sql').read_text(encoding='utf-8')
product=content[content.index('create function app_private.product_media_workflow_action'):content.index('create or replace function public.media_workflow_action')]
review=product.replace('app_private.product_media_workflow_action','app_private.review_media_workflow_action').replace('a public.product_media','a public.review_media').replace('public.products where id=w.product_id','public.reviews where id=w.review_id')
start=review.index('   if w.replace_association_id is not null then')
end=review.index('   update public.media_workflows set association_id=',start)
review=review[:start]+'''   select coalesce(max(position),-1)+1 into pos from public.review_media where review_id=w.review_id;
   insert into public.review_media(review_id,media_id,position) values(w.review_id,p_id,pos) returning * into a;
'''+review[end:]
start=review.index('  delete from public.product_media')
end=review.index("  update public.media_assets set lifecycle='retired'",start)
review=review[:start]+'''  delete from public.review_media where media_id=p_id and review_id=w.review_id;
  update public.reviews set status='pending',hidden_at=null,revision=revision+1 where id=w.review_id;
'''+review[end:]
review=review.replace('or exists(select 1 from public.homepage_media where media_id=p_id) then','or exists(select 1 from public.homepage_media where media_id=p_id) or exists(select 1 from public.review_media where media_id=p_id) then')
public_media=content[content.index('create or replace function public.media_is_public'):content.index('create function app_private.product_media_workflow_action')]
public_media=public_media.replace("    or exists(select 1 from public.homepage_selections h", "    or exists(select 1 from public.review_media rm join public.reviews r on r.id=rm.review_id where rm.media_id=p_id and public.review_is_public(r.id))\n    or exists(select 1 from public.homepage_selections h")
header=(root/'tooling/reviews-core.sql').read_text(encoding='utf-8')
tail='''
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
'''
(root/'supabase/migrations/202610070011_customer_reviews.sql').write_text(header+'\n'+review+'\n'+public_media+'\n'+tail,encoding='utf-8')
