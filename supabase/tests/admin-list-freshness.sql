\set ON_ERROR_STOP on
-- Disposable database only. All synthetic records and changes roll back.
begin;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
create function pg_temp.assert_true(ok boolean,label text) returns void language plpgsql as $$begin
 if ok is distinct from true then raise exception 'FAIL: %',label;end if;raise notice 'PASS: %',label;
end $$;
create function pg_temp.issue(p uuid,v uuid,c text) returns jsonb language sql as $$
 select jsonb_build_object('key',i.issue_key,'episode',i.episode,'ignored',exists(select 1 from app_private.admin_reminder_dismissals d where d.issue_key=i.issue_key and d.episode=i.episode))
 from app_private.admin_reminder_issues i where i.product_id=p and i.variant_id is not distinct from v and i.code=c and i.active;
$$;
insert into public.brands(id,name) values('af-brand','Freshness fixture brand');
insert into public.categories(id,name,scope) values('af-main','Freshness main','skincare'),('af-other','Freshness other','skincare');
insert into public.categories(id,parent_id,name,scope) values('af-child','af-main','Freshness child','skincare');
insert into public.category_product_types(category_id,product_type_id) values('af-other','cleanser'),('af-child','cleanser');
insert into public.products(id,name,brand_id,category_id,product_type_id) values
 ('14141414-0000-4000-8000-000000000001','Freshness one','af-brand','af-other','cleanser'),
 ('14141414-0000-4000-8000-000000000002','Freshness two','af-brand','af-other','cleanser'),
 ('14141414-0000-4000-8000-000000000003','Freshness archived','af-brand','af-child','cleanser');
insert into public.product_categories(product_id,category_id) values('14141414-0000-4000-8000-000000000001','af-child');
insert into public.variants(id,product_id,original_sku,label,status) values
 ('14141414-0000-4000-8000-000000000011','14141414-0000-4000-8000-000000000001','AF-A','Small','draft'),
 ('14141414-0000-4000-8000-000000000012','14141414-0000-4000-8000-000000000001','AF-B','Large','draft'),
 ('14141414-0000-4000-8000-000000000013','14141414-0000-4000-8000-000000000001','AF-C','Removed','archived'),
 ('14141414-0000-4000-8000-000000000014','14141414-0000-4000-8000-000000000003','AF-HISTORY-A','First history','archived'),
 ('14141414-0000-4000-8000-000000000015','14141414-0000-4000-8000-000000000003','AF-HISTORY-B','Other history','archived');
insert into public.facet_definitions values('af-finish','Freshness finish','enum',true);
insert into public.facet_scopes values('af-finish','skincare');
insert into public.facet_values values('af-common','af-finish','Shared'),('af-small','af-finish','Small only'),('af-large','af-finish','Large only'),('af-removed','af-finish','Removed only'),('af-history','af-finish','History first'),('af-excluded-history','af-finish','History excluded');
insert into public.product_facets(product_id,variant_id,facet_id,kind,option_id) values
 ('14141414-0000-4000-8000-000000000001',null,'af-finish','enum','af-common'),
 ('14141414-0000-4000-8000-000000000001','14141414-0000-4000-8000-000000000011','af-finish','enum','af-small'),
 ('14141414-0000-4000-8000-000000000001','14141414-0000-4000-8000-000000000012','af-finish','enum','af-large'),
 ('14141414-0000-4000-8000-000000000001','14141414-0000-4000-8000-000000000013','af-finish','enum','af-removed'),
 ('14141414-0000-4000-8000-000000000003','14141414-0000-4000-8000-000000000014','af-finish','enum','af-history'),
 ('14141414-0000-4000-8000-000000000003','14141414-0000-4000-8000-000000000015','af-finish','enum','af-excluded-history');
do $membership$ declare options jsonb;v text;begin
 options=public.admin_catalog_filter_options('af-main');
 perform pg_temp.assert_true((public.admin_catalog_list('', '{"category":"af-main"}')->>'total')::int=3,'primary/additional descendant category listing');
 perform pg_temp.assert_true(options::text like '%af-small%' and options::text like '%af-large%' and options::text like '%af-common%' and options::text like '%af-history%' and options::text not like '%af-removed%' and options::text not like '%af-excluded-history%','filter options share additional membership and eligible option rules');
 for v in select x->>'value' from jsonb_array_elements(options) g cross join jsonb_array_elements(g->'values') x loop
  perform pg_temp.assert_true((public.admin_catalog_list('',jsonb_build_object('category','af-main','facets',jsonb_build_object('af-finish',jsonb_build_array(v))))->>'total')::int>0,'every offered category facet matches a list row: '||v);
 end loop;
 update public.product_categories set category_id='af-other' where product_id='14141414-0000-4000-8000-000000000001';
 perform pg_temp.assert_true(public.admin_catalog_filter_options('af-main')::text not like '%af-small%' and (public.admin_catalog_list('AF-A','{"category":"af-main"}')->>'total')::int=0,'additional category update refreshes search and filter membership');
 update public.product_categories set category_id='af-child' where product_id='14141414-0000-4000-8000-000000000001';
 delete from public.product_categories where product_id='14141414-0000-4000-8000-000000000001';
 perform pg_temp.assert_true((public.admin_catalog_list('AF-A Freshness child')->>'total')::int=0,'additional category deletion refreshes indexed category names');
 insert into public.product_categories values('14141414-0000-4000-8000-000000000001','af-child');
 perform pg_temp.assert_true((public.admin_catalog_list('Freshness child','{"brand":"af-brand"}')->>'total')::int=3,'additional category insertion refreshes indexed category names');
end $membership$;
-- A clean option can move ownership without changing any business family automatically.
insert into public.variants(id,product_id,original_sku,label) values('14141414-0000-4000-8000-000000000016','14141414-0000-4000-8000-000000000002','AF-MOVE','Original label');
do $variants$ declare r jsonb;begin
 perform pg_temp.assert_true((public.admin_catalog_list('AF-MOVE Original')->>'total')::int=1,'variant INSERT refresh');
 update public.variants set label='Updated label' where id='14141414-0000-4000-8000-000000000016';
 perform pg_temp.assert_true((public.admin_catalog_list('AF-MOVE Updated')->>'total')::int=1 and (public.admin_catalog_list('AF-MOVE Original')->>'total')::int=0,'variant UPDATE removes old search words');
 update public.variants set product_id='14141414-0000-4000-8000-000000000001' where id='14141414-0000-4000-8000-000000000016';
 r=public.admin_catalog_list('AF-MOVE');
 perform pg_temp.assert_true(r->'rows'->0->>'product_id'='14141414-0000-4000-8000-000000000001' and (public.admin_catalog_list('AF-MOVE one')->>'total')::int=1 and (public.admin_catalog_list('AF-MOVE two')->>'total')::int=0,'variant ownership updates search document and results');
 perform pg_temp.assert_true(pg_temp.issue('14141414-0000-4000-8000-000000000002','14141414-0000-4000-8000-000000000016','price_missing') is null and pg_temp.issue('14141414-0000-4000-8000-000000000001','14141414-0000-4000-8000-000000000016','price_missing') is not null,'both owners reminder state refreshed');
 r=public.admin_catalog_list('Freshness two');
 perform pg_temp.assert_true((r->>'total')::int=1 and (r->>'skus')::int=0 and r->'rows'->0->>'variant_id' is null and exists(select 1 from jsonb_array_elements(r->'rows'->0->'issues') x where x->>'code'='option_missing'),'last option moved: product remains visible with add-option blocker and accurate SKU count');
 update public.variants set product_id='14141414-0000-4000-8000-000000000002' where id='14141414-0000-4000-8000-000000000016';
 delete from public.variants where id='14141414-0000-4000-8000-000000000016';
 perform pg_temp.assert_true((public.admin_catalog_list('AF-MOVE')->>'total')::int=0 and not exists(select 1 from app_private.admin_catalog_search where variant_id='14141414-0000-4000-8000-000000000016') and not exists(select 1 from app_private.admin_reminder_issues where variant_id='14141414-0000-4000-8000-000000000016'),'variant DELETE removes indexed words and variant reminders');
 perform pg_temp.assert_true(pg_temp.issue('14141414-0000-4000-8000-000000000002',null,'option_missing') is not null and (public.admin_catalog_list('Freshness two','{"issues":["publication_blockers"]}')->>'total')::int=1,'last variant deletion retains actionable product row');
 update public.variants set status='archived' where id='14141414-0000-4000-8000-000000000011';
 perform pg_temp.assert_true(public.admin_catalog_filter_options('af-main')::text not like '%af-small%' and pg_temp.issue('14141414-0000-4000-8000-000000000001','14141414-0000-4000-8000-000000000011','price_missing') is null,'archiving option removes facet and active reminders');
 update public.variants set status='draft' where id='14141414-0000-4000-8000-000000000011';
 perform pg_temp.assert_true(public.admin_catalog_filter_options('af-main')::text like '%af-small%' and pg_temp.issue('14141414-0000-4000-8000-000000000001','14141414-0000-4000-8000-000000000011','price_missing') is not null,'restoring option restores facet and reminders');
end $variants$;
-- Existing workflow RPCs with synthetic provider metadata, no remote upload.
select public.create_media_upload('14141414-0000-4000-8000-000000000021','14141414-0000-4000-8000-000000000001',null,'development','fixture-cloud',repeat('d',64),123,'Synthetic freshness photo');
update public.media_assets set width=10,height=10 where id='14141414-0000-4000-8000-000000000021';
select public.media_workflow_action('14141414-0000-4000-8000-000000000021','private_uploaded');
do $pending$ declare i jsonb;e text;begin
 perform pg_temp.assert_true(pg_temp.issue('14141414-0000-4000-8000-000000000001','14141414-0000-4000-8000-000000000011','image_missing') is null,'private completion resolves missing-photo reminder');
 i=pg_temp.issue('14141414-0000-4000-8000-000000000001','14141414-0000-4000-8000-000000000011','image_approval');e=i->>'episode';
 perform public.admin_catalog_reminder(i->>'key',(i->>'episode')::uuid,true);
 perform public.media_workflow_action('14141414-0000-4000-8000-000000000021','approve');
 perform public.media_workflow_action('14141414-0000-4000-8000-000000000021','begin_publish');
 perform pg_temp.assert_true(pg_temp.issue('14141414-0000-4000-8000-000000000001','14141414-0000-4000-8000-000000000011','image_approval')->>'episode'=e and (pg_temp.issue('14141414-0000-4000-8000-000000000001','14141414-0000-4000-8000-000000000011','image_approval')->>'ignored')::boolean,'in-flight publishing keeps existing review reminder occurrence');
 perform public.media_workflow_action('14141414-0000-4000-8000-000000000021','failed', '{"code":"synthetic_failure"}');
 perform pg_temp.assert_true(pg_temp.issue('14141414-0000-4000-8000-000000000001','14141414-0000-4000-8000-000000000011','image_approval')->>'episode'=e,'failed publish retains private photo reminder occurrence');
 perform public.media_workflow_action('14141414-0000-4000-8000-000000000021','begin_publish');
 perform public.media_workflow_action('14141414-0000-4000-8000-000000000021','complete',jsonb_build_object('asset_id','freshness-provider-double','public_id','nook-glow/development/14141414-0000-4000-8000-000000000021','version',1,'width',10,'height',10,'bytes',123,'format','png','resource_type','image','type','upload','sha256',repeat('d',64)));
 perform pg_temp.assert_true(pg_temp.issue('14141414-0000-4000-8000-000000000001','14141414-0000-4000-8000-000000000011','image_approval') is null,'link and primary association resolve image approval reminder');
 update public.product_media set is_primary=false where media_id='14141414-0000-4000-8000-000000000021';
 i=pg_temp.issue('14141414-0000-4000-8000-000000000001','14141414-0000-4000-8000-000000000011','image_approval');
 perform pg_temp.assert_true(i->>'episode'<>e and not (i->>'ignored')::boolean,'fixed image issue recurring starts fresh nonignored occurrence');
 update public.product_media set is_primary=true where media_id='14141414-0000-4000-8000-000000000021';
 perform public.media_workflow_action('14141414-0000-4000-8000-000000000021','detach');
 perform pg_temp.assert_true(pg_temp.issue('14141414-0000-4000-8000-000000000001','14141414-0000-4000-8000-000000000011','image_missing') is not null and public.admin_catalog_list('AF-A')->'rows'->0->>'media_id' is null,'detach refreshes missing photo and thumbnail');
end $pending$;
-- Ownership UPDATE and workflow DELETE must refresh both sides, even without media UPDATE.
insert into public.variants(id,product_id,original_sku,label,sellable_kind) values('14141414-0000-4000-8000-000000000017','14141414-0000-4000-8000-000000000002','AF-SET','Boxed set','factory_set');
update public.media_assets set lifecycle='private_pending' where id='14141414-0000-4000-8000-000000000021';
update public.media_workflows set variant_id='14141414-0000-4000-8000-000000000011' where media_id='14141414-0000-4000-8000-000000000021';
select pg_temp.assert_true(pg_temp.issue('14141414-0000-4000-8000-000000000001','14141414-0000-4000-8000-000000000012','image_missing') is not null,'workflow variant narrowing refreshes other option');
update public.media_workflows set variant_id='14141414-0000-4000-8000-000000000012' where media_id='14141414-0000-4000-8000-000000000021';
select pg_temp.assert_true(pg_temp.issue('14141414-0000-4000-8000-000000000001','14141414-0000-4000-8000-000000000011','image_missing') is not null and pg_temp.issue('14141414-0000-4000-8000-000000000001','14141414-0000-4000-8000-000000000012','image_missing') is null,'workflow option ownership refresh');
update public.media_workflows set product_id='14141414-0000-4000-8000-000000000002',variant_id=null where media_id='14141414-0000-4000-8000-000000000021';
select pg_temp.assert_true(pg_temp.issue('14141414-0000-4000-8000-000000000001','14141414-0000-4000-8000-000000000012','image_missing') is not null and pg_temp.issue('14141414-0000-4000-8000-000000000002','14141414-0000-4000-8000-000000000017','image_missing') is null and public.admin_catalog_list('Freshness two')->'rows'->0->>'media_id'='14141414-0000-4000-8000-000000000021','workflow product ownership refreshes both products');
delete from public.media_workflows where media_id='14141414-0000-4000-8000-000000000021';
select pg_temp.assert_true(public.admin_catalog_list('Freshness two')->'rows'->0->>'media_id' is null and pg_temp.issue('14141414-0000-4000-8000-000000000002','14141414-0000-4000-8000-000000000017','image_missing') is not null,'workflow DELETE refreshes thumbnail and missing photo');
-- Set contents ownership is keyed by set_variant_id, not product_id/variant_id.
update public.variants set sellable_kind='factory_set' where id in('14141414-0000-4000-8000-000000000011','14141414-0000-4000-8000-000000000012');
insert into public.factory_set_contents(set_variant_id,position,name,quantity) values('14141414-0000-4000-8000-000000000011',0,'Synthetic boxed contents',1);
update public.factory_set_contents set set_variant_id='14141414-0000-4000-8000-000000000017' where set_variant_id='14141414-0000-4000-8000-000000000011';
select pg_temp.assert_true(pg_temp.issue('14141414-0000-4000-8000-000000000001','14141414-0000-4000-8000-000000000011','set_contents_missing') is not null and pg_temp.issue('14141414-0000-4000-8000-000000000002','14141414-0000-4000-8000-000000000017','set_contents_missing') is null,'cross-product set contents ownership refresh');
rollback;
