import {readFile,writeFile} from 'node:fs/promises';import {createHash} from 'node:crypto';
const filename='202610130015_guest_commerce.sql',version='202610130015',source=await readFile('supabase/migrations/'+filename),hash=b=>createHash('sha256').update(b).digest('hex'),sha=hash(source),prior=hash(await readFile('supabase/migrations/202610120014_admin_exact_identifier_search.sql'));
const verify=`-- READ ONLY. No customer or catalog records returned.
select exists(select 1 from app_private.sql_editor_receipts where version='202610120014' and sha256='${prior}') as prerequisite_014,
 (to_regclass('app_private.commerce_orders') is not null or to_regclass('app_private.order_events') is not null or to_regclass('app_private.checkout_rate_buckets') is not null or to_regclass('app_private.order_numbers') is not null or to_regprocedure('app_private.assert_order_allocation(uuid,text,boolean)') is not null) as commerce_present,
 to_regprocedure('public.place_guest_order(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb)') is not null as placement_present,
 (to_regprocedure('public.admin_order_action(uuid,integer,text,uuid)') is not null and to_regprocedure('app_private.assert_order_allocation(uuid,text,boolean)') is not null and coalesce(position('Unpaid payment holds cannot be confirmed or dispatched' in pg_get_functiondef(to_regprocedure('public.admin_order_action(uuid,integer,text,uuid)')))>0,false)) as transitions_and_safeguards_present,
 to_regprocedure('public.expire_commerce_holds(integer)') is not null as expiry_present,
 exists(select 1 from app_private.sql_editor_receipts where version='${version}') as receipt_present,
 exists(select 1 from app_private.sql_editor_receipts where version='${version}' and sha256='${sha}') as receipt_matches,
 (select count(*)=3 and bool_and(relrowsecurity) from pg_class where oid in(to_regclass('app_private.commerce_orders'),to_regclass('app_private.order_events'),to_regclass('app_private.checkout_rate_buckets'))) as private_rls,
 not exists(select 1 from pg_policies where schemaname='app_private' and tablename in('commerce_orders','order_events','checkout_rate_buckets')) as no_client_policies,
 case when to_regprocedure('public.place_guest_order(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb)') is null then false else
 has_function_privilege('service_role','public.place_guest_order(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb)','execute') and not has_function_privilege('anon','public.place_guest_order(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb)','execute') and not has_function_privilege('authenticated','public.place_guest_order(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb)','execute') end as guest_gateway_private,
 case when to_regprocedure('public.admin_orders(text,text,date,date,integer,uuid)') is null then false else
 has_function_privilege('authenticated','public.admin_orders(text,text,date,date,integer,uuid)','execute') and not has_function_privilege('anon','public.admin_orders(text,text,date,date,integer,uuid)','execute') and (select prosecdef and position('require_admin()' in prosrc)>0 from pg_proc where oid=to_regprocedure('public.admin_orders(text,text,date,date,integer,uuid)')) end as admin_authorization;
`;
const sql=`-- COMPLETE incremental 015. DEVELOPMENT only until business settings are approved.
-- No business rows are rewritten. No DROP/TRUNCATE/DELETE at installation.
-- Replaces inventory wrappers with the same shared transactional algorithms;
-- revokes generic authenticated order/item writes so mutations use validated RPCs.
begin;
set local lock_timeout='5s';set local statement_timeout='120s';
select pg_advisory_xact_lock(73523);
do $install_guard$ begin
 if not exists(select 1 from app_private.sql_editor_receipts where version='202610120014' and sha256='${prior}') then raise exception 'Verify installed canonical 014 first';end if;
 if exists(select 1 from app_private.sql_editor_receipts where version='${version}') or to_regclass('app_private.commerce_orders') is not null or to_regclass('app_private.order_events') is not null or to_regclass('app_private.checkout_rate_buckets') is not null or to_regclass('app_private.order_numbers') is not null or to_regprocedure('app_private.assert_order_allocation(uuid,text,boolean)') is not null or to_regprocedure('app_private.reserve_inventory(uuid,text,timestamptz)') is not null then raise exception 'Commerce already or partly installed; inspect preflight, do not rerun';end if;
end $install_guard$;
${source.toString('utf8')}
insert into app_private.sql_editor_receipts(version,filename,sha256) values('${version}','${filename}','${sha}');
notify pgrst,'reload schema';
commit;
${verify}`;
const names=[...sql.matchAll(/^create (?:or replace )?function ([\w.]+)/gm)].map(x=>x[1]);if(new Set(names).size!==names.length)throw Error('Duplicate functions');if([...sql.matchAll(/^insert into app_private.sql_editor_receipts/gm)].length!==1)throw Error('Duplicate receipts');
await writeFile('supabase/sql-editor/13_preflight_guest_commerce.sql',verify);await writeFile('supabase/sql-editor/13_install_guest_commerce_clean.sql',sql);await writeFile('docs/commerce-installer-manifest.json',JSON.stringify({canonical:filename,canonical_sha256:sha,installer_sha256:hash(sql),prior_014_sha256:prior,functions:names},null,2)+'\n');console.log('Generated one complete commerce installer and read-only preflight.');
