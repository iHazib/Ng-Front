\set ON_ERROR_STOP on
begin;
set local role authenticated;
set local request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';
insert into public.brands(id,name) values('al-fixture','CeraVe synthetic');
insert into public.brand_aliases(brand_id,alias) values('al-fixture','SyntheticDerm');
insert into public.categories(id,name,scope) values('al-main','Synthetic skin care','skincare');
insert into public.categories(id,parent_id,name,scope) values('al-child','al-main','Synthetic cleansers','skincare');
insert into public.category_product_types values('al-child','cleanser');
insert into public.products(id,name,brand_id,category_id,product_type_id) values('13131313-0000-4000-8000-000000000001','Admin synthetic cleanser','al-fixture','al-child','cleanser');
insert into public.variants(id,product_id,original_sku,label) values
 ('13131313-0000-4000-8000-000000000002','13131313-0000-4000-8000-000000000001','AL-SMALL','Small'),
 ('13131313-0000-4000-8000-000000000003','13131313-0000-4000-8000-000000000001','AL-LARGE','Large');
insert into public.variants(id,product_id,original_sku,label,status) values('13131313-0000-4000-8000-000000000004','13131313-0000-4000-8000-000000000001','AL-REMOVED','Removed','archived');
insert into public.sku_aliases values('AL-ALIAS','13131313-0000-4000-8000-000000000002');
select public.save_daily_product('13131313-0000-4000-8000-000000000001',1,'{"name":"Admin synthetic cleanser","brand":"al-fixture","category":"al-child","productType":"cleanser","featured":false,"options":[{"id":"13131313-0000-4000-8000-000000000002","sku":"AL-SMALL","label":"Small","priceMinor":null,"countChanged":false},{"id":"13131313-0000-4000-8000-000000000003","sku":"AL-LARGE","label":"Large","priceMinor":100000,"stock":0,"expectedStock":0,"countChanged":true}]}',gen_random_uuid());
insert into public.concerns(id,name,claim_kind) values('al-dry','Dry skin synthetic','hydration');
insert into public.product_concerns(product_id,concern_id,qualification) values('13131313-0000-4000-8000-000000000001','al-dry','Synthetic assigned data only');
insert into public.facet_definitions values('al-finish','Synthetic finish','enum',true);
insert into public.facet_scopes values('al-finish','skincare');
insert into public.facet_values values('al-matte','al-finish','Matte'),('al-gloss','al-finish','Gloss');
insert into public.product_facets(product_id,variant_id,facet_id,kind,option_id) values
 ('13131313-0000-4000-8000-000000000001','13131313-0000-4000-8000-000000000002','al-finish','enum','al-matte'),
 ('13131313-0000-4000-8000-000000000001','13131313-0000-4000-8000-000000000003','al-finish','enum','al-gloss');

-- Long sibling identifiers reproduce the observed trigram precision failure.
update public.variants set label='Small' where original_sku='AL-SMALL';
insert into public.products(id,name,brand_id,category_id,product_type_id) values('14141414-0000-4000-8000-000000000001','Precision cleanser','al-fixture','al-child','cleanser');
insert into public.variants(id,product_id,original_sku,label) values
 ('14141414-0000-4000-8000-000000000002','14141414-0000-4000-8000-000000000001','EX-14141414-0000-4000-8000-000000000001-SMALL','Small'),
 ('14141414-0000-4000-8000-000000000003','14141414-0000-4000-8000-000000000001','EX-14141414-0000-4000-8000-000000000001-LARGE','Large'),
 ('14141414-0000-4000-8000-000000000004','14141414-0000-4000-8000-000000000001','EXDANM - 001','Spaced');
insert into public.sku_aliases(alias,variant_id) values('EX-14141414-0000-4000-8000-000000000001-ALIAS','14141414-0000-4000-8000-000000000002');
do $exact$ declare r jsonb;q text;begin
 foreach q in array array['EX-14141414-0000-4000-8000-000000000001-SMALL','  ex-14141414-0000-4000-8000-000000000001-small  ','EX-14141414-0000-4000-8000-000000000001-ALIAS',E'\tEX-14141414-0000-4000-8000-000000000001-SMALL\n'] loop
  r=public.admin_catalog_list(q);if (r->>'total')::int<>1 or r->'rows'->0->>'variant_id'<>'14141414-0000-4000-8000-000000000002' then raise exception 'Exact sibling isolation failed';end if;
 end loop;raise notice 'PASS: original/normalized/alias exact sibling isolation';
 foreach q in array array['EXDANM - 001',' exdanm-001 ','EXDANM  -  001'] loop
  r=public.admin_catalog_list(q);if (r->>'total')::int<>1 or r->'rows'->0->>'original_sku'<>'EXDANM - 001' then raise exception 'Spaced SKU normalization failed';end if;
 end loop;raise notice 'PASS: spaced SKU original preserved and normalized exact queries';
 if (public.admin_catalog_list('AL-ALIAS','{"brand":"al-fixture","category":"al-main","type":"cleanser","facets":{"al-finish":["al-matte"]}}')->>'total')::int<>1 then raise exception 'Exact combined filters failed';end if;
 if (public.admin_catalog_list('AL-ALIAS','{"facets":{"al-finish":["al-gloss"]}}')->>'total')::int<>0 or (public.admin_catalog_list('AL-ALIAS','{"status":"published"}')->>'total')::int<>0 then raise exception 'Excluded exact identifier fell back to fuzzy';end if;
 raise notice 'PASS: combined filters constrain exact matches; no fuzzy fallback';
 if (public.admin_catalog_list('AL-REMOVED')->>'total')::int<>0 then raise exception 'Archived option fell back to active siblings';end if;
 raise notice 'PASS: archived exact option never returns active siblings';
 if (public.admin_catalog_list('cerav cleanser dry skin','{"brand":"al-fixture"}')->>'total')::int<>2 then raise exception 'General combined typo search regressed';end if;
 if (public.admin_catalog_list('EX-14141414-0000-4000-8000-000000000001')->>'total')::int<>2 then raise exception 'Partial identifier search regressed';end if;
 raise notice 'PASS: ordinary typo/assigned concern and partial queries remain fuzzy';
 if (public.admin_catalog_list('AL-ALIAS','{}',1,1)->>'total')::int<>1 or jsonb_array_length(public.admin_catalog_list('AL-ALIAS','{}',1,1)->'rows')<>0 then raise exception 'Exact pagination count failed';end if;
 begin update public.variants set original_sku='changed' where id='14141414-0000-4000-8000-000000000004';raise exception 'Immutable guard missing';exception when raise_exception then if sqlerrm='Immutable guard missing' then raise;end if;end;
 begin insert into public.sku_aliases(alias,variant_id) values('exdanm-001','14141414-0000-4000-8000-000000000002');raise exception 'Collision guard missing';exception when raise_exception then if sqlerrm='Collision guard missing' then raise;end if;end;
 raise notice 'PASS: bounded counts, immutable SKU and cross-owner normalization collision guard';
end $exact$;
rollback;
