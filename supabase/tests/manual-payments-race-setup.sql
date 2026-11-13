\set ON_ERROR_STOP on
begin;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
insert into public.brands(id,name) values('sf-fixture','Synthetic CeraVe');
insert into public.brand_aliases(brand_id,alias) values('sf-fixture','SyntheticDerm');
insert into public.categories(id,name,scope) values('sf-fixture','Synthetic cleansers','skincare');
insert into public.category_product_types values('sf-fixture','cleanser');
insert into public.products(id,name) values('15151515-0000-4000-8000-000000000001','Synthetic cleanser');
select public.save_daily_product('15151515-0000-4000-8000-000000000001',1,'{"name":"Synthetic cleanser","brand":"sf-fixture","category":"sf-fixture","productType":"cleanser","description":"Local SQL fixture only","featured":false,"options":[{"id":"15151515-0000-4000-8000-000000000002","sku":"SF-RED","label":"Small","priceMinor":100000,"stock":3,"expectedStock":0,"countChanged":true},{"id":"99999999-0000-4000-8000-000000000003","sku":"SF-BLUE","label":"Large","priceMinor":200000,"stock":0,"expectedStock":0,"countChanged":true}]}',gen_random_uuid());
insert into public.evidence(id,source_type,finding,status,reviewed_by,reviewed_at) values('99999999-0000-4000-8000-000000000004','package','Synthetic SQL concern fixture, not manufacturer research','approved','00000000-0000-0000-0000-000000000001',now());
insert into public.concerns(id,name,claim_kind,active) values('sf-dry','Dry skin','hydration',true);
insert into public.product_concerns values('15151515-0000-4000-8000-000000000001','sf-dry','99999999-0000-4000-8000-000000000004','approved','Synthetic fixture only');
insert into public.facet_definitions values('sf-size','Synthetic size','quantity',true),('sf-finish','Synthetic finish','enum',true);
insert into public.facet_scopes values('sf-size','skincare'),('sf-finish','skincare');
insert into public.facet_values values('sf-red','sf-finish','Synthetic red'),('sf-blue','sf-finish','Synthetic blue');
insert into public.product_facets(product_id,variant_id,facet_id,kind,decimal_value,unit,evidence_id,status) values
 ('15151515-0000-4000-8000-000000000001','15151515-0000-4000-8000-000000000002','sf-size','quantity',10,'ml','99999999-0000-4000-8000-000000000004','approved'),
 ('15151515-0000-4000-8000-000000000001','99999999-0000-4000-8000-000000000003','sf-size','quantity',20,'ml','99999999-0000-4000-8000-000000000004','approved');
insert into public.product_facets(product_id,variant_id,facet_id,kind,option_id,evidence_id,status) values
 ('15151515-0000-4000-8000-000000000001','15151515-0000-4000-8000-000000000002','sf-finish','enum','sf-red','99999999-0000-4000-8000-000000000004','approved'),
 ('15151515-0000-4000-8000-000000000001','99999999-0000-4000-8000-000000000003','sf-finish','enum','sf-blue','99999999-0000-4000-8000-000000000004','approved');
insert into public.catalog_search_aliases(product_id,alias,status,reviewed_by,reviewed_at) values
 ('15151515-0000-4000-8000-000000000001','Verified synthetic synonym','approved','00000000-0000-0000-0000-000000000001',now());
insert into public.catalog_search_aliases(product_id,alias) values('15151515-0000-4000-8000-000000000001','Pending secret synonym');
insert into public.media_assets(id,provider,cloudinary_public_id,cloudinary_version,cloudinary_cloud_name,cloudinary_format,width,height,alt,status,lifecycle)
values('99999999-0000-4000-8000-000000000005','cloudinary','mock/fixture',1,'mock','png',1,1,'Synthetic pixel','approved','linked');
insert into public.product_media(product_id,media_id,position,is_primary) values('15151515-0000-4000-8000-000000000001','99999999-0000-4000-8000-000000000005',0,true);
select public.save_daily_product('15151515-0000-4000-8000-000000000001',2,'{"name":"Synthetic cleanser","brand":"sf-fixture","category":"sf-fixture","productType":"cleanser","description":"Local SQL fixture only","featured":false,"options":[{"id":"15151515-0000-4000-8000-000000000002","sku":"SF-RED","label":"Small","priceMinor":100000,"stock":3,"expectedStock":3,"countChanged":false},{"id":"99999999-0000-4000-8000-000000000003","sku":"SF-BLUE","label":"Large","priceMinor":200000,"stock":0,"expectedStock":0,"countChanged":false}]}',gen_random_uuid(),'publish');

reset role;

select public.place_guest_order('16161616-0000-4000-8000-000000000101',repeat('a',64),repeat('b',64),'[{"id":"15151515-0000-4000-8000-000000000002","quantity":1,"expectedPriceMinor":100000}]','{"name":"Synthetic Guest","phone":"+923001234567","address":"Synthetic address","city":"Test City"}','{"id":"test","label":"Synthetic","feeMinor":0}','{"id":"jazzcash","label":"Synthetic wallet","allocation":"temporary","accountScope":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","accountTitle":"Synthetic","destination":"TEST-ONLY"}','{"mode":"development","version":"race","paymentSeconds":60,"reviewExtensionSeconds":0}');
select public.place_guest_order('16161616-0000-4000-8000-000000000102',repeat('a',64),repeat('b',64),'[{"id":"15151515-0000-4000-8000-000000000002","quantity":1,"expectedPriceMinor":100000}]','{"name":"Synthetic Guest","phone":"+923001234567","address":"Synthetic address","city":"Test City"}','{"id":"test","label":"Synthetic","feeMinor":0}','{"id":"jazzcash","label":"Synthetic wallet","allocation":"temporary","accountScope":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","accountTitle":"Synthetic","destination":"TEST-ONLY"}','{"mode":"development","version":"race","paymentSeconds":60,"reviewExtensionSeconds":0}');
update app_private.commerce_orders set hold_expires_at=now()-interval '1 second' where order_id in('16161616-0000-4000-8000-000000000101','16161616-0000-4000-8000-000000000102');update public.inventory_reservations set expires_at=now()-interval '1 second' where order_id in('16161616-0000-4000-8000-000000000101','16161616-0000-4000-8000-000000000102');select public.expire_commerce_holds();select public.adjust_inventory('15151515-0000-4000-8000-000000000002',-2,'Synthetic late last-unit race','manual-race-count');commit;
