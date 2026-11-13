import {readFile,writeFile} from 'node:fs/promises';import {createHash} from 'node:crypto';
const file='202610160017_assembled_deals.sql',hash=x=>createHash('sha256').update(x).digest('hex'),source=await readFile('supabase/migrations/'+file),sha=hash(source),prior=hash(await readFile('supabase/migrations/202610150016_manual_advance_payments.sql'));
const verify=`-- READ ONLY: no customer, catalog or account details.
select exists(select 1 from app_private.sql_editor_receipts where version='202610150016' and sha256='${prior}') prerequisite_016,
 to_regclass('app_private.deal_settings') is not null deals_present,
 to_regclass('app_private.deal_pools') is not null pools_present,
 to_regclass('app_private.order_component_snapshots') is not null snapshots_present,
 to_regclass('public.deal_media') is not null media_present,
 to_regprocedure('public.save_deal(uuid,integer,uuid,text,jsonb)') is not null save_present,
 to_regprocedure('public.storefront_deals(text,uuid[],integer,boolean)') is not null public_projection_present,
 to_regprocedure('public.expire_deal_allocations(integer)') is not null expiry_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610160017') receipt_present,
 exists(select 1 from app_private.sql_editor_receipts where version='202610160017' and sha256='${sha}') receipt_matches,
 (select count(*)=6 and bool_and(relrowsecurity) from pg_class where oid in(to_regclass('app_private.deal_settings'),to_regclass('app_private.deal_pools'),to_regclass('app_private.deal_operations'),to_regclass('app_private.deal_allocation_events'),to_regclass('app_private.order_component_snapshots'),to_regclass('app_private.order_pool_sources'))) private_rls,
 not exists(select 1 from pg_policies where schemaname='app_private' and tablename in('deal_settings','deal_pools','deal_operations','deal_allocation_events','order_component_snapshots','order_pool_sources')) no_client_policies,
 coalesce((select prosecdef and position('require_admin()' in prosrc)>0 from pg_proc where oid=to_regprocedure('public.save_deal(uuid,integer,uuid,text,jsonb)')),false) admin_authorization,
 coalesce((select position('73525' in prosrc)>0 from pg_proc where oid=to_regprocedure('public.place_guest_order(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb)')),false) inventory_gate,
 coalesce((select position('deal_pools' in prosrc)>0 from pg_proc where oid=to_regprocedure('app_private.assert_order_allocation(uuid,text,boolean)')),false) shared_assertion;
`;
const sql=`-- Complete incremental 017; apply ONCE after confirmed 016. No earlier installers.
-- No business data reset/delete at installation. Adds columns/tables and replaces guards.
-- Drops/replaces only two media CHECK constraints; existing owner rules are retained.
begin;set local lock_timeout='5s';set local statement_timeout='120s';
select pg_advisory_xact_lock(73525);
do $guard$ begin
 if not exists(select 1 from app_private.sql_editor_receipts where version='202610150016' and sha256='${prior}') then raise exception 'Verify canonical 016 receipt first';end if;
 if exists(select 1 from app_private.sql_editor_receipts where version='202610160017') or to_regclass('app_private.deal_settings') is not null or to_regclass('app_private.deal_pools') is not null or to_regclass('public.deal_media') is not null or to_regprocedure('public.save_deal(uuid,integer,uuid,text,jsonb)') is not null then raise exception 'Deals already or partly installed; inspect state, do not rerun';end if;
end $guard$;
${source.toString()}
insert into app_private.sql_editor_receipts(version,filename,sha256) values('202610160017','${file}','${sha}');notify pgrst,'reload schema';commit;
${verify}`;
const functions=[...sql.matchAll(/^create (?:or replace )?function ([\w.]+)/gm)].map(x=>x[1]);if(new Set(functions).size!==functions.length)throw Error('Duplicate function declarations');
await writeFile('supabase/sql-editor/15_preflight_deals.sql',verify);await writeFile('supabase/sql-editor/15_install_deals_clean.sql',sql);await writeFile('docs/deals-installer-manifest.json',JSON.stringify({canonical:file,canonical_sha256:sha,installer_sha256:hash(sql),prior_016_sha256:prior},null,2)+'\n');console.log('Generated one complete incremental deals installer.');
