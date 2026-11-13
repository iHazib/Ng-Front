\set ON_ERROR_STOP on
begin;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
insert into public.products(id,name,description,usage) values('88888888-0000-4000-8000-000000000001','Markdown fixture',E'Original copy\r\n**unchanged**','Legacy usage exactly');
do $test$ declare data jsonb; rev integer; key uuid=gen_random_uuid(); result jsonb; rejected boolean=false; begin
 data='{"name":"Markdown fixture","brand":"","category":"","productType":"","featured":false,"options":[{"id":"88888888-0000-4000-8000-000000000002","sku":"MARKDOWN-ONLY","label":"","priceMinor":120000,"stock":0,"expectedStock":0,"countChanged":true}]}';
 perform public.save_daily_product('88888888-0000-4000-8000-000000000001',1,data,key);
 if (select description<>E'Original copy\r\n**unchanged**' or usage<>'Legacy usage exactly' or key_benefits is not null from public.products where id='88888888-0000-4000-8000-000000000001') then raise exception 'Legacy copy was lost'; end if;
 data=data||jsonb_build_object('description',E'## Heading\n\n**Bold** paragraph\n\n- First\n- Second','usage',E'1. First step\n2. Next step','keyBenefits',E'Owner supplied benefits\n<script>not executable</script>');
 select revision into rev from public.products where id='88888888-0000-4000-8000-000000000001';key=gen_random_uuid();
 perform public.save_daily_product('88888888-0000-4000-8000-000000000001',rev,data,key);
 perform public.save_daily_product('88888888-0000-4000-8000-000000000001',rev,data,key);
 if (select description is distinct from data->>'description' or usage is distinct from data->>'usage' or key_benefits is distinct from data->>'keyBenefits' from public.products where id='88888888-0000-4000-8000-000000000001') then raise exception 'Markdown persistence changed source'; end if;
 select revision into rev from public.products where id='88888888-0000-4000-8000-000000000001';
 perform public.save_daily_product('88888888-0000-4000-8000-000000000001',rev,data||'{"keyBenefits":"Later edit"}',gen_random_uuid(),'hide');
 perform public.save_daily_product('88888888-0000-4000-8000-000000000001',rev-1,data,key);
 if (select key_benefits<>'Later edit' or status<>'archived' from public.products where id='88888888-0000-4000-8000-000000000001') then raise exception 'Idempotent retry overwrote later edit'; end if;
 begin perform public.save_daily_product('88888888-0000-4000-8000-000000000001',rev,data,gen_random_uuid());exception when raise_exception then rejected=sqlerrm like 'Product changed%';end;
 if not rejected then raise exception 'Stale content save allowed';end if;
 result=public.admin_product_list('MARKDOWN-ONLY',0,'archived');
 if jsonb_array_length(result)<>1 or result->0->>'stock'<>'0' or result->0->>'price_minor'<>'120000' or jsonb_array_length(public.admin_product_list('MARKDOWN-ONLY',0,'draft'))<>0 then raise exception 'Daily list summaries/filter mismatch';end if;
 raise notice 'PASS: exact legacy preservation, three Markdown fields, duplicate retry, stale rejection, hidden preservation, zero stock and filtered summary';
end $test$;
-- Publish only this disposable fixture; optional usage and benefits stay non-blocking.
insert into public.media_assets(id,provider,cloudinary_public_id,cloudinary_version,cloudinary_cloud_name,cloudinary_format,width,height,alt,status,lifecycle)
values('88888888-0000-4000-8000-000000000003','cloudinary','mock/markdown',1,'mock','png',1,1,'Synthetic SQL pixel','approved','linked');
insert into public.product_media(product_id,media_id,position,is_primary) values('88888888-0000-4000-8000-000000000001','88888888-0000-4000-8000-000000000003',0,true);
do $public_copy$ declare data jsonb; rev integer; begin
 select revision into rev from public.products where id='88888888-0000-4000-8000-000000000001';
 data='{"name":"Markdown fixture","brand":"pixi","category":"makeup/face","productType":"blush","description":"**Public description**","usage":"1. Public step","keyBenefits":"Public supplied benefits","featured":false,"options":[{"id":"88888888-0000-4000-8000-000000000002","sku":"MARKDOWN-ONLY","label":"","priceMinor":120000,"countChanged":false}]}';
 perform public.save_daily_product('88888888-0000-4000-8000-000000000001',rev,data,gen_random_uuid(),'publish');
end $public_copy$;
set local role anon;
do $public_check$ declare r jsonb; begin
 r=public.storefront_catalog(p_slug=>'product-88888888000040008000000000000001');
 if r->>'total'<>'1' or r->'products'->0->>'keyBenefits'<>'Public supplied benefits' or r->'products'->0->>'usage'<>'1. Public step' then raise exception 'Public Markdown projection missing';end if;
 raise notice 'PASS: public eligible RPC returns three content fields';
end $public_check$;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
update public.products set status='archived' where id='88888888-0000-4000-8000-000000000001';
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $deny$ begin
 begin perform public.admin_product_list();raise exception 'Non-admin list allowed';exception when insufficient_privilege then null;end;
 begin perform public.save_daily_product('88888888-0000-4000-8000-000000000001',1,'{}',gen_random_uuid());raise exception 'Non-admin save allowed';exception when insufficient_privilege then null;end;
 if exists(select 1 from public.products where id='88888888-0000-4000-8000-000000000001') then raise exception 'Non-admin draft visible';end if;
end $deny$;
set local role anon;
do $deny$ begin
 begin perform public.admin_product_list();raise exception 'Anonymous list allowed';exception when insufficient_privilege then null;end;
 if exists(select 1 from public.products where id='88888888-0000-4000-8000-000000000001') then raise exception 'Anonymous private copy visible';end if;
 if public.storefront_catalog(p_slug=>'product-88888888000040008000000000000001')->>'total'<>'0' then raise exception 'Hidden content leaked through RPC';end if;
end $deny$;
rollback;
select 'PRODUCT MARKDOWN SQL TESTS PASSED';
