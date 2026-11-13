\set ON_ERROR_STOP on
begin;
create function pg_temp.check_true(ok boolean,label text) returns void language plpgsql as $$ begin
 if ok is distinct from true then raise exception 'FAIL: %',label; end if;
 raise notice 'PASS: %',label;
end $$;
create function pg_temp.expect_error(statement text,label text) returns void language plpgsql as $$
declare failed boolean=false; begin
 begin execute statement; exception when others then failed=true; end;
 if not failed then raise exception 'FAIL allowed: %',label; end if;
 raise notice 'PASS denied: %',label;
end $$;

select pg_temp.check_true((select count(*)=121 from public.variants),'121 valid SKU drafts imported without media');
select pg_temp.check_true((select sum(source_quantity)=270 from public.import_records),'source quantities preserved');
select pg_temp.check_true((select count(*)=0 from public.media_assets),'no invented images');
select pg_temp.check_true((select amount_minor=349900 from public.variant_prices join public.variants on variants.id=variant_id where original_sku='PIX-005'),'PKR integer minor units');
select pg_temp.check_true((select source_target_minor is null from public.import_records where original_sku='SB-001'),'missing price preserved');
select pg_temp.check_true((select count(*)=2 from public.variants where original_sku in ('DANM - 001','MAC - 001')),'spaced SKUs preserved');
select pg_temp.check_true((select count(distinct product_id)=5 from public.variants where original_sku like 'DIOR-%'),'ambiguous Dior products separate');
select pg_temp.check_true((select bool_and(relrowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r'),'all public tables enable RLS');

set local role anon;
select pg_temp.check_true((select count(*)=0 from public.products),'anonymous cannot read drafts');
select pg_temp.check_true((select count(*)=0 from public.search_published_catalog('blush')),'public search hides drafts');
select pg_temp.expect_error('select * from public.orders','anonymous orders private');
select pg_temp.expect_error('select * from public.import_records','raw workbook private');
select pg_temp.expect_error('select * from public.audit_logs','audit private');
select pg_temp.check_true((select count(*)=0 from storage.objects),'private storage hidden');
reset role;

set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000002';
select pg_temp.check_true(not public.is_admin(),'ordinary user not admin');
select pg_temp.check_true((select count(*)=0 from public.orders),'nonadmin sees no orders');
select pg_temp.check_true((select count(*)=0 from public.products),'nonadmin sees no drafts');
select pg_temp.expect_error('insert into app_private.admin_members(user_id,reason) values(auth.uid(),''self'')','self promotion denied');
select pg_temp.expect_error('insert into public.products(name) values(''unauthorized'')','nonadmin write denied');
select pg_temp.expect_error('select * from public.admin_search_catalog('''')','admin RPC denied');
select pg_temp.expect_error('select public.adjust_inventory(gen_random_uuid(),1,''fake'',''fake'')','privileged operation denied');
select pg_temp.expect_error('insert into storage.objects(bucket_id,name) values(''catalog-private'',''private.png'')','nonadmin upload denied');
reset role;

set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
select pg_temp.check_true(public.is_admin(),'admin membership recognized');
select pg_temp.check_true((select count(*)=121 from public.admin_search_catalog('',200,0)),'all drafts searchable without photos');
select pg_temp.check_true((select count(*)=1 from public.admin_search_catalog('DANM - 001')),'original SKU search');
select pg_temp.expect_error('insert into public.audit_logs(table_name,operation) values(''forged'',''INSERT'')','audit append restricted');
select pg_temp.expect_error('update public.variants set original_sku=''PIX-NEW'' where original_sku=''PIX-005''','immutable original SKU');
select pg_temp.expect_error('insert into public.sku_aliases(alias,variant_id) select ''DANM-001'',id from public.variants where original_sku=''PIX-005''','alias collision denied');

-- Test product uses an imported draft but only synthetic local approvals/assets.
update public.products set slug='test-blush',description='Disposable fixture',identity_confirmed=true
 where id=(select product_id from public.variants where original_sku='PIX-005');
update public.brands set status='published' where id='pixi';
update public.categories set status='published' where id='makeup/face';
update public.variants set status='published',identity_confirmed=true where original_sku='PIX-005';
update public.variant_prices set approved=true where variant_id=(select id from public.variants where original_sku='PIX-005');
select public.adjust_inventory(id,10,'disposable count','test-opening') from public.variants where original_sku='PIX-005';
select public.adjust_inventory(id,10,'disposable count','test-opening') from public.variants where original_sku='PIX-005';
select pg_temp.check_true((select on_hand=10 from public.inventory_balances b join public.variants v on v.id=b.variant_id where original_sku='PIX-005'),'adjustment idempotent');
select pg_temp.expect_error('update public.inventory_balances set on_hand=999','direct stock reset denied');
select pg_temp.expect_error('update public.products set status=''published'' where slug=''test-blush''','publication missing required media/checks');
insert into public.media_assets(id,provider,cloudinary_public_id,cloudinary_version,status,alt)
 values('10000000-0000-0000-0000-000000000001','cloudinary','test-only/placeholder',1,'approved','Neutral test placeholder');
insert into public.product_media(product_id,media_id,position,is_primary)
 select id,'10000000-0000-0000-0000-000000000001',0,true from public.products where slug='test-blush';
insert into public.media_assets(id,provider,private_bucket,private_path)
 values('10000000-0000-0000-0000-000000000002','supabase_private','catalog-private','test-only/pending.png');
insert into public.product_media(product_id,media_id,position)
 select id,'10000000-0000-0000-0000-000000000002',1 from public.products where slug='test-blush';
select pg_temp.expect_error('update public.product_media set is_primary=true where media_id=''10000000-0000-0000-0000-000000000002''','one primary per owner');
insert into public.product_checks(product_id,code,approved,approved_by,approved_at)
 select p.id,r.code,true,auth.uid(),now() from public.products p cross join public.publication_requirements r
 where p.slug='test-blush' and r.scope='makeup' and r.kind='essential';
-- Resolve only specific source/package issues on this synthetic local fixture.
insert into public.product_checks(product_id,code,approved,approved_by,approved_at)
 select p.id,issue,true,auth.uid(),now() from public.products p
 cross join lateral jsonb_array_elements_text(public.publication_report(p.id)->'specific_issues') issue
 where p.slug='test-blush' on conflict do nothing;
update public.products set status='published' where slug='test-blush';
select pg_temp.check_true((select count(*)=0 from public.product_concerns),'optional concerns absent');
select pg_temp.check_true((select public.product_is_public(id) from public.products where slug='test-blush'),'publication succeeds without optional concerns');
insert into public.reviews(product_id,display_name,rating,body,status)
 select id,'Fictional local test',5,'Local approved fixture','approved' from public.products where slug='test-blush';
insert into public.reviews(product_id,display_name,rating,body)
 select id,'Fictional local test',4,'Pending fixture' from public.products where slug='test-blush';
insert into storage.objects(bucket_id,name) values('catalog-private','test-only/pending.png');

-- Changed source is staged without resetting stock, published price or admin content.
select public.import_catalog_drafts(repeat('b',64),repeat('c',64),'test',
 (select jsonb_agg(jsonb_set(mapping,'{source_stock_units}','999')) from public.import_records where original_sku='PIX-005'));
select pg_temp.check_true((select on_hand=10 from public.inventory_balances b join public.variants v on v.id=b.variant_id where original_sku='PIX-005'),'repeat changed import cannot reset stock');
select pg_temp.check_true((select description='Disposable fixture' from public.products where slug='test-blush'),'admin copy preserved');

insert into public.orders(id,subtotal_minor,shipping_minor,total_minor) values('20000000-0000-0000-0000-000000000001',1000,0,1000);
insert into public.order_items(order_id,variant_id,name_snapshot,sku_snapshot,quantity,unit_price_minor,line_total_minor)
 select '20000000-0000-0000-0000-000000000001',id,'Fixture','PIX-005',2,500,1000 from public.variants where original_sku='PIX-005';
select public.reserve_order('20000000-0000-0000-0000-000000000001','test-order',now()+interval '1 hour');
select public.reserve_order('20000000-0000-0000-0000-000000000001','test-order',now()+interval '1 hour');
select pg_temp.check_true((select reserved=2 from public.inventory_balances b join public.variants v on v.id=b.variant_id where original_sku='PIX-005'),'reservation idempotent');
select public.finish_reservation('20000000-0000-0000-0000-000000000001',true);
select public.finish_reservation('20000000-0000-0000-0000-000000000001',true);
select pg_temp.check_true((select on_hand=8 and reserved=0 from public.inventory_balances b join public.variants v on v.id=b.variant_id where original_sku='PIX-005'),'consume exactly once');
insert into public.deals(id,name) values('40000000-0000-0000-0000-000000000001','Disposable component deal');
insert into public.deal_components(deal_id,variant_id,quantity)
 select '40000000-0000-0000-0000-000000000001',id,2 from public.variants where original_sku='PIX-005';
insert into public.orders(id) values('20000000-0000-0000-0000-000000000002');
insert into public.order_items(order_id,deal_id,name_snapshot,quantity,unit_price_minor,line_total_minor)
 values('20000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000001','Fixture deal',2,500,1000);
insert into public.order_items(order_id,variant_id,name_snapshot,quantity,unit_price_minor,line_total_minor)
 select '20000000-0000-0000-0000-000000000002',id,'Fixture direct',1,500,500 from public.variants where original_sku='PIX-005';
select public.reserve_order('20000000-0000-0000-0000-000000000002','deal-exact-key',now()+interval '1 hour');
select pg_temp.check_true((select reserved=5 from public.inventory_balances b join public.variants v on v.id=b.variant_id where original_sku='PIX-005'),'deal and direct lines aggregate shared stock');
select pg_temp.expect_error('select public.reserve_order(''20000000-0000-0000-0000-000000000002'',''%'',now()+interval ''1 hour'')','wildcard cannot alias reservation key');
select public.finish_reservation('20000000-0000-0000-0000-000000000002',false);
select pg_temp.check_true((select on_hand=8 and reserved=0 from public.inventory_balances b join public.variants v on v.id=b.variant_id where original_sku='PIX-005'),'release preserves stock');
insert into public.orders(id) values('20000000-0000-0000-0000-000000000003');
insert into public.order_items(order_id,variant_id,name_snapshot,quantity,unit_price_minor,line_total_minor)
 select '20000000-0000-0000-0000-000000000003',id,'Insufficient fixture',9,500,4500 from public.variants where original_sku='PIX-005';
select pg_temp.expect_error('select public.reserve_order(''20000000-0000-0000-0000-000000000003'',''insufficient'',now()+interval ''1 hour'')','insufficient stock denied');
select pg_temp.check_true((select count(*)=0 from public.order_item_components c join public.order_items i on i.id=c.order_item_id where i.order_id='20000000-0000-0000-0000-000000000003'),'failed reservation rolls back snapshots');
update public.orders set status='placed' where id='20000000-0000-0000-0000-000000000001';
select pg_temp.expect_error('delete from public.order_items where order_id=''20000000-0000-0000-0000-000000000001''','placed order lines immutable');
insert into public.sales(id,order_id,amount_minor,idempotency_key) values('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001',1000,'test-sale');
insert into public.refunds(sale_id,amount_minor,reason,idempotency_key) values('30000000-0000-0000-0000-000000000001',400,'test','test-refund');
select pg_temp.expect_error('insert into public.refunds(sale_id,amount_minor,reason,idempotency_key) values(''30000000-0000-0000-0000-000000000001'',700,''test'',''over-refund'')','over refund denied');
select pg_temp.expect_error('update public.sales set amount_minor=1','financial history immutable');
select pg_temp.check_true((select start_at='2026-10-04 19:00:00+00'::timestamptz and end_at='2026-10-05 19:00:00+00'::timestamptz from public.karachi_day_bounds('2026-10-05')),'Karachi UTC reporting bounds');
reset role;

set local role anon;
select pg_temp.check_true((select count(*)=1 from public.products),'public sees only eligible published product');
select pg_temp.check_true((select count(*)=1 from public.reviews),'only approved reviews public');
select pg_temp.check_true((select count(*)=1 from public.media_assets),'only approved associated Cloudinary media public');
select pg_temp.check_true((select count(*)=1 from public.product_media),'pending association hidden');
select pg_temp.check_true((select count(*)=0 from storage.objects),'pending object stays private');
select pg_temp.check_true((select count(*)=0 from public.concerns),'unsupported concern options inactive');
select pg_temp.expect_error('select * from public.review_private','review customer metadata private');
reset role;
rollback;
select 'DATABASE TESTS PASSED';
