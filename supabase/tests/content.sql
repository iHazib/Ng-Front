\set ON_ERROR_STOP on
begin;
set local role authenticated;set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
select public.save_article('88888888-0000-4000-8000-000000000001',0,'{"title":"Synthetic article","slug":"synthetic-article","body":"<p>Synthetic content.</p>","category":"Synthetic","tags":["testing"]}');
set local role anon;
do $test$ begin
 if (public.storefront_articles('synthetic-article')->>'total')::int<>0 then raise exception 'Draft article exposed';end if;
 begin perform public.save_article('88888888-0000-4000-8000-000000000002',0,'{}');raise exception 'Anonymous write allowed';exception when insufficient_privilege then null;end;
end $test$;
set local role authenticated;set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
select public.create_content_media_upload('88888888-0000-4000-8000-000000000003','88888888-0000-4000-8000-000000000001',null,'cover','development','mock',repeat('a',64),1,'Synthetic pixel');
select public.media_workflow_action('88888888-0000-4000-8000-000000000003','private_uploaded');
select public.media_workflow_action('88888888-0000-4000-8000-000000000003','approve');
select public.media_workflow_action('88888888-0000-4000-8000-000000000003','begin_publish');
select public.media_workflow_action('88888888-0000-4000-8000-000000000003','complete','{"asset_id":"synthetic-content","public_id":"nook-glow/development/88888888-0000-4000-8000-000000000003","resource_type":"image","type":"upload","format":"png","version":1,"width":1,"height":1,"bytes":1,"sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}');
select public.save_article('88888888-0000-4000-8000-000000000001',1,'{"title":"Synthetic article","slug":"synthetic-article","body":"<p>Published synthetic content.</p>","category":"Synthetic","tags":["testing"]}','publish');
select public.save_homepage_content('the-edit','[{"id":"88888888-0000-4000-8000-000000000004","entity":"88888888-0000-4000-8000-000000000001","theme":"blush"}]');
select public.create_content_media_upload('88888888-0000-4000-8000-000000000005',null,'88888888-0000-4000-8000-000000000004','slide','development','mock',repeat('b',64),1,'Synthetic slide pixel');
set local role anon;
do $test$ declare r jsonb;begin
 r=public.storefront_articles(null,true);if (r->>'total')::int<>1 or r->'articles'->0->>'theme'<>'blush' then raise exception 'Homepage article order/theme failed';end if;
 if (public.storefront_articles('synthetic-article')->'articles'->0->'cover'->>'id')<>'88888888-0000-4000-8000-000000000003' then raise exception 'Cover association failed';end if;
 begin perform 1 from public.media_workflows;raise exception 'Private content workflow leaked';exception when insufficient_privilege then null;end;
 raise notice 'PASS: draft isolation, published cover and slideshow theme; true content owners, private workflows';
end $test$;
set local role authenticated;set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
do $test$ begin
 begin perform public.save_article('88888888-0000-4000-8000-000000000001',1,'{}');raise exception 'Stale revision accepted';exception when raise_exception then if SQLERRM='Stale revision accepted' then raise;end if;end;
 begin perform public.save_article('88888888-0000-4000-8000-000000000001',2,'{"title":"","slug":"synthetic-article","body":""}');raise exception 'Invalid published edit accepted';exception when raise_exception then if SQLERRM='Invalid published edit accepted' then raise;end if;end;
 if (select revision from public.articles where id='88888888-0000-4000-8000-000000000001')<>2 then raise exception 'Rejected save changed article';end if;
end $test$;
select public.save_article('88888888-0000-4000-8000-000000000001',2,'{"title":"Hidden article","slug":"synthetic-article","body":"<p>Hidden text</p>"}','hide');
select public.save_article('88888888-0000-4000-8000-000000000001',3,'{"title":"Hidden edited","slug":"synthetic-article","body":"<p>Hidden edit</p>"}');
set local role anon;
do $test$ begin if (public.storefront_articles('synthetic-article')->>'total')::int<>0 or (public.storefront_articles(null,true)->>'total')::int<>0 then raise exception 'Hidden edit became public';end if;end $test$;
set local role authenticated;set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $test$ begin
 begin perform public.save_homepage_content('the-edit','[]');raise exception 'Nonadmin homepage mutation accepted';exception when insufficient_privilege then null;end;
 raise notice 'PASS: stale/invalid published edit rollback; hidden preservation; nonadmin denied';
end $test$;
rollback;
