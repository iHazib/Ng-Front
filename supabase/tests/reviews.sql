\set ON_ERROR_STOP on
begin;
do $security$ begin
 if not (select relrowsecurity from pg_class where oid='app_private.storefront_search'::regclass) then raise exception 'Private search RLS missing'; end if;
 if exists(select 1 from pg_policy where polrelid='app_private.storefront_search'::regclass) then raise exception 'Private search must have no client policies'; end if;
 if has_table_privilege('anon','app_private.storefront_search','SELECT') or has_table_privilege('authenticated','app_private.storefront_search','SELECT') then raise exception 'Private search client grants present'; end if;
 if exists(select 1 from pg_proc where oid in('public.storefront_navigation()'::regprocedure,'public.storefront_catalog(text,text[],text,jsonb,text,integer,integer,text,boolean)'::regprocedure) and (not prosecdef or proowner<>(select relowner from pg_class where oid='app_private.storefront_search'::regclass))) then raise exception 'Public RPC must use authorized search-table owner'; end if;
 raise notice 'PASS: private search RLS enabled, no policies/client grants, authorized SECURITY DEFINER owners';
end $security$;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
insert into public.brands(id,name) values('sf-fixture','Synthetic CeraVe');
insert into public.brand_aliases(brand_id,alias) values('sf-fixture','SyntheticDerm');
insert into public.categories(id,name,scope) values('sf-fixture','Synthetic cleansers','skincare');
insert into public.category_product_types values('sf-fixture','cleanser');
insert into public.products(id,name) values('99999999-0000-4000-8000-000000000001','Synthetic cleanser');
select public.save_daily_product('99999999-0000-4000-8000-000000000001',1,'{"name":"Synthetic cleanser","brand":"sf-fixture","category":"sf-fixture","productType":"cleanser","description":"Local SQL fixture only","featured":true,"options":[{"id":"99999999-0000-4000-8000-000000000002","sku":"SF-RED","label":"Small","priceMinor":100000,"stock":3,"expectedStock":0,"countChanged":true},{"id":"99999999-0000-4000-8000-000000000003","sku":"SF-BLUE","label":"Large","priceMinor":200000,"stock":0,"expectedStock":0,"countChanged":true}]}',gen_random_uuid());
insert into public.evidence(id,source_type,finding,status,reviewed_by,reviewed_at) values('99999999-0000-4000-8000-000000000004','package','Synthetic SQL concern fixture, not manufacturer research','approved','00000000-0000-0000-0000-000000000001',now());
insert into public.concerns(id,name,claim_kind,active) values('sf-dry','Dry skin','hydration',true);
insert into public.product_concerns values('99999999-0000-4000-8000-000000000001','sf-dry','99999999-0000-4000-8000-000000000004','approved','Synthetic fixture only');
insert into public.facet_definitions values('sf-size','Synthetic size','quantity',true),('sf-finish','Synthetic finish','enum',true);
insert into public.facet_scopes values('sf-size','skincare'),('sf-finish','skincare');
insert into public.facet_values values('sf-red','sf-finish','Synthetic red'),('sf-blue','sf-finish','Synthetic blue');
insert into public.product_facets(product_id,variant_id,facet_id,kind,decimal_value,unit,evidence_id,status) values
 ('99999999-0000-4000-8000-000000000001','99999999-0000-4000-8000-000000000002','sf-size','quantity',10,'ml','99999999-0000-4000-8000-000000000004','approved'),
 ('99999999-0000-4000-8000-000000000001','99999999-0000-4000-8000-000000000003','sf-size','quantity',20,'ml','99999999-0000-4000-8000-000000000004','approved');
insert into public.product_facets(product_id,variant_id,facet_id,kind,option_id,evidence_id,status) values
 ('99999999-0000-4000-8000-000000000001','99999999-0000-4000-8000-000000000002','sf-finish','enum','sf-red','99999999-0000-4000-8000-000000000004','approved'),
 ('99999999-0000-4000-8000-000000000001','99999999-0000-4000-8000-000000000003','sf-finish','enum','sf-blue','99999999-0000-4000-8000-000000000004','approved');
insert into public.catalog_search_aliases(product_id,alias,status,reviewed_by,reviewed_at) values
 ('99999999-0000-4000-8000-000000000001','Verified synthetic synonym','approved','00000000-0000-0000-0000-000000000001',now());
insert into public.catalog_search_aliases(product_id,alias) values('99999999-0000-4000-8000-000000000001','Pending secret synonym');
insert into public.media_assets(id,provider,cloudinary_public_id,cloudinary_version,cloudinary_cloud_name,cloudinary_format,width,height,alt,status,lifecycle)
values('99999999-0000-4000-8000-000000000005','cloudinary','mock/fixture',1,'mock','png',1,1,'Synthetic pixel','approved','linked');
insert into public.product_media(product_id,media_id,position,is_primary) values('99999999-0000-4000-8000-000000000001','99999999-0000-4000-8000-000000000005',0,true);
select public.save_daily_product('99999999-0000-4000-8000-000000000001',2,'{"name":"Synthetic cleanser","brand":"sf-fixture","category":"sf-fixture","productType":"cleanser","description":"Local SQL fixture only","featured":true,"options":[{"id":"99999999-0000-4000-8000-000000000002","sku":"SF-RED","label":"Small","priceMinor":100000,"stock":3,"expectedStock":3,"countChanged":false},{"id":"99999999-0000-4000-8000-000000000003","sku":"SF-BLUE","label":"Large","priceMinor":200000,"stock":0,"expectedStock":0,"countChanged":false}]}',gen_random_uuid(),'publish');

set local role anon;
do $security$ begin
 begin perform public.submit_customer_review(gen_random_uuid(),'99999999-0000-4000-8000-000000000001','{}',repeat('a',64),repeat('b',64));raise exception 'Anon submit allowed';exception when insufficient_privilege then null;end;
 begin perform public.complete_customer_review(gen_random_uuid(),repeat('a',64));raise exception 'Anon finalize allowed';exception when insufficient_privilege then null;end;
 begin perform 1 from public.review_private;raise exception 'Private contact leaked';exception when insufficient_privilege then null;end;
END; $security$;
set local role service_role;
select public.submit_customer_review('77777777-0000-4000-8000-000000000001','99999999-0000-4000-8000-000000000001','{"name":"Synthetic reviewer","rating":5,"body":"Synthetic review for a local test only.","email":"synthetic@example.invalid"}',repeat('a',64),repeat('b',64),'[{"id":"77777777-0000-4000-8000-000000000003","environment":"development","cloud":"mock","hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","bytes":1,"alt":"Synthetic pixel"}]');
select public.submit_customer_review('77777777-0000-4000-8000-000000000001','99999999-0000-4000-8000-000000000001','{"name":"Synthetic reviewer","rating":5,"body":"Synthetic review for a local test only.","email":"synthetic@example.invalid"}',repeat('a',64),repeat('b',64),'[{"id":"77777777-0000-4000-8000-000000000003","environment":"development","cloud":"mock","hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","bytes":1,"alt":"Synthetic pixel"}]');
set local role authenticated;set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
do $guard$ begin
 begin perform public.moderate_review('77777777-0000-4000-8000-000000000001',1,'approve');raise exception 'Incomplete approval allowed';exception when raise_exception then if SQLERRM='Incomplete approval allowed' then raise;end if;end;
END; $guard$;
set local role service_role;
select public.complete_customer_review('77777777-0000-4000-8000-000000000001',repeat('a',64));
set local role anon;
do $pending$ begin
 if (public.storefront_reviews('99999999-0000-4000-8000-000000000001')->>'total')::int<>0 then raise exception 'Pending review exposed';end if;
 if exists(select 1 from public.review_media) then raise exception 'Private media exposed';end if;
END; $pending$;
set local role authenticated;set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
do $nonadmin$ begin
 begin perform public.moderate_review('77777777-0000-4000-8000-000000000001',1,'approve');raise exception 'Nonadmin approval allowed';exception when insufficient_privilege then null;end;
 if exists(select 1 from public.review_private) then raise exception 'Nonadmin private contact exposed';end if;
END; $nonadmin$;
set local role authenticated;set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
do $imageguard$ begin
 begin perform public.moderate_review('77777777-0000-4000-8000-000000000001',1,'approve');raise exception 'Unpublished image approval allowed';exception when raise_exception then if SQLERRM='Unpublished image approval allowed' then raise;end if;end;
END; $imageguard$;
select public.media_workflow_action('77777777-0000-4000-8000-000000000003','approve');
select public.media_workflow_action('77777777-0000-4000-8000-000000000003','begin_publish');
select public.media_workflow_action('77777777-0000-4000-8000-000000000003','failed');
do $failed$ begin
 begin perform public.moderate_review('77777777-0000-4000-8000-000000000001',1,'approve');raise exception 'Failed image exposed review';exception when raise_exception then if SQLERRM='Failed image exposed review' then raise;end if;end;
END; $failed$;
select public.media_workflow_action('77777777-0000-4000-8000-000000000003','begin_publish');
select public.media_workflow_action('77777777-0000-4000-8000-000000000003','complete','{"asset_id":"synthetic-review","public_id":"nook-glow/development/77777777-0000-4000-8000-000000000003","resource_type":"image","type":"upload","format":"png","version":1,"width":1,"height":1,"bytes":1,"sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}');
select public.media_workflow_action('77777777-0000-4000-8000-000000000003','complete','{"asset_id":"synthetic-review","version":1}');
select public.moderate_review('77777777-0000-4000-8000-000000000001',1,'approve');
set local role service_role;
select public.submit_customer_review('77777777-0000-4000-8000-000000000002','99999999-0000-4000-8000-000000000001','{"name":"Second synthetic reviewer","rating":3,"body":"Second synthetic local review only."}',repeat('d',64),repeat('e',64));
select public.complete_customer_review('77777777-0000-4000-8000-000000000002',repeat('d',64));
set local role authenticated;set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
select public.moderate_review('77777777-0000-4000-8000-000000000002',1,'approve');
set local role anon;
do $averages$ begin
 if (public.storefront_reviews('99999999-0000-4000-8000-000000000001')->>'total')::int<>2 or (public.storefront_reviews('99999999-0000-4000-8000-000000000001')->>'average')::numeric<>4 then raise exception 'Two-review average failed';end if;
END; $averages$;
set local role authenticated;set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
select public.moderate_review('77777777-0000-4000-8000-000000000002',2,'decline');
set local role anon;
do $public$ declare data jsonb;begin
 data=public.storefront_reviews('99999999-0000-4000-8000-000000000001');
 if (data->>'total')::int<>1 or (data->>'average')::numeric<>5 or jsonb_array_length(data->'reviews'->0->'images')<>1 then raise exception 'Rating/media calculation failed';end if;
 if data::text like '%email%' or data::text like '%submission_hash%' or data::text like '%private_path%' or data::text like '%Verified purchase%' then raise exception 'Private/unsupported data exposed';end if;
END; $public$;
set local role authenticated;set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
update public.products set status='archived' where id='99999999-0000-4000-8000-000000000001';
set local role anon;
do $product_hidden$ begin if (public.storefront_reviews('99999999-0000-4000-8000-000000000001')->>'total')::int<>0 then raise exception 'Hidden product reviews exposed';end if;END; $product_hidden$;
set local role service_role;
do $invalid_subject$ begin
 begin perform public.submit_customer_review(gen_random_uuid(),'99999999-0000-4000-8000-000000000001','{"name":"Synthetic","rating":3,"body":"Review of hidden product rejected."}',repeat('f',64),repeat('b',64));raise exception 'Hidden product review accepted';exception when raise_exception then if SQLERRM='Hidden product review accepted' then raise;end if;end;
END; $invalid_subject$;
set local role authenticated;set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
update public.products set status='published' where id='99999999-0000-4000-8000-000000000001';
do $cleanup$ begin
 begin perform public.media_workflow_action('77777777-0000-4000-8000-000000000003','claim_cleanup');raise exception 'Referenced asset deleted';exception when raise_exception then if SQLERRM='Referenced asset deleted' then raise;end if;end;
END; $cleanup$;
update public.reviews set body='Edited synthetic review text.' where id='77777777-0000-4000-8000-000000000001';
set local role anon;
do $edited$ begin if (public.storefront_reviews('99999999-0000-4000-8000-000000000001')->>'total')::int<>0 then raise exception 'Approved edit not moderated';end if;END; $edited$;
set local role authenticated;set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
select public.moderate_review('77777777-0000-4000-8000-000000000001',3,'approve');
select public.moderate_review('77777777-0000-4000-8000-000000000001',4,'hide');
do $stale$ begin begin perform public.moderate_review('77777777-0000-4000-8000-000000000001',4,'approve');raise exception 'Stale moderation allowed';exception when raise_exception then if SQLERRM='Stale moderation allowed' then raise;end if;end;END; $stale$;
set local role anon;
do $hidden$ begin if (public.storefront_reviews('99999999-0000-4000-8000-000000000001')->>'total')::int<>0 then raise exception 'Hidden review exposed';end if;END; $hidden$;
set local role service_role;
do $limits$ declare i integer;begin
 for i in 1..4 loop perform public.submit_customer_review(gen_random_uuid(),'99999999-0000-4000-8000-000000000001',jsonb_build_object('name','Synthetic','rating',3,'body','Synthetic quota review number '||i),md5(i::text)||md5(i::text),repeat('b',64));end loop;
 begin perform public.submit_customer_review(gen_random_uuid(),'99999999-0000-4000-8000-000000000001','{"name":"Synthetic","rating":3,"body":"Synthetic sixth review blocked."}',repeat('c',64),repeat('b',64));raise exception 'Quota bypass';exception when sqlstate 'PT429' then null;end;
END; $limits$;
reset role;
do $audit$ begin if (select count(*) from public.review_moderation_events where review_id='77777777-0000-4000-8000-000000000001')<>4 then raise exception 'Moderation history missing';end if;END; $audit$;
do $pass$ begin raise notice 'PASS: review anon/nonadmin denial, private contact, idempotent submission, private image, failed-publication isolation, duplicate completion, ratings, edit re-moderation, hidden isolation, referenced cleanup guard and atomic quota';END; $pass$;
rollback;
