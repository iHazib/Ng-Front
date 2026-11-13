-- READ ONLY. Run in a new SQL Editor query using ordinary Run.
-- Do not run the installer or choose Run and enable RLS again.
-- Returns schema/permission metadata only; no business rows, credentials or customer data.
with targets(schema_name,table_name,private_table) as(values
 ('public','deal_media',false),
 ('app_private','deal_settings',true),('app_private','deal_pools',true),
 ('app_private','deal_operations',true),('app_private','deal_allocation_events',true),
 ('app_private','order_component_snapshots',true),('app_private','order_pool_sources',true)
), tables as(
 select t.*,c.oid,c.relrowsecurity,c.relforcerowsecurity,pg_get_userbyid(c.relowner) owner
 from targets t left join pg_namespace n on n.nspname=t.schema_name
 left join pg_class c on c.relnamespace=n.oid and c.relname=t.table_name and c.relkind='r'
), policies as(
 select p.* from pg_policies p join targets t on t.schema_name=p.schemaname and t.table_name=p.tablename
), table_privileges as(
 select t.schema_name,t.table_name,t.private_table,r.role_name,v.privilege,
 coalesce(has_table_privilege(r.role_name,t.oid,v.privilege),false) allowed
 from tables t cross join (values('anon'),('authenticated'),('service_role')) r(role_name)
 cross join (values('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE'),('REFERENCES'),('TRIGGER')) v(privilege)
), public_acl as(
 select t.schema_name,t.table_name,a.privilege_type,a.is_grantable
 from tables t join pg_class c on c.oid=t.oid
 cross join lateral aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a where a.grantee=0
), expected_rpcs(signature,anon_ok,authenticated_ok,service_ok) as(values
 ('public.admin_deals(uuid,text,integer)',false,true,false),
 ('public.save_deal(uuid,integer,uuid,text,jsonb)',false,true,false),
 ('public.create_deal_upload(uuid,uuid,text,text,text,bigint,text,uuid)',false,true,false),
 ('public.arrange_deal_media(uuid,uuid[],uuid,jsonb)',false,true,false),
 ('public.storefront_deals(text,uuid[],integer,boolean)',true,true,true),
 ('public.expire_deal_allocations(integer)',false,false,true),
 ('public.media_is_public(uuid)',true,true,true),
 ('public.place_guest_order(uuid,text,text,jsonb,jsonb,jsonb,jsonb,jsonb)',false,false,true),
 ('public.admin_order_action(uuid,integer,text,uuid)',false,true,false),
 ('public.review_manual_payment(uuid,integer,text,uuid,jsonb)',false,true,false),
 ('public.expire_commerce_holds(integer)',false,false,true),
 ('public.adjust_inventory(uuid,integer,text,text)',false,true,false),
 ('public.save_daily_product(uuid,integer,jsonb,uuid,text)',false,true,false),
 ('public.reserve_order(uuid,text,timestamp with time zone)',false,true,false),
 ('public.finish_reservation(uuid,boolean)',false,true,false),
 ('public.media_workflow_action(uuid,text,jsonb)',false,true,false),
 ('public.admin_content_choices(text,text)',false,true,false)
), rpc_state as(
 select e.*,p.oid,p.prosecdef,pg_get_userbyid(p.proowner) owner,p.proconfig,
 coalesce(has_function_privilege('anon',p.oid,'EXECUTE'),false) anon_execute,
 coalesce(has_function_privilege('authenticated',p.oid,'EXECUTE'),false) authenticated_execute,
 coalesce(has_function_privilege('service_role',p.oid,'EXECUTE'),false) service_execute,
 exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where a.grantee=0 and a.privilege_type='EXECUTE') public_execute
 from expected_rpcs e left join pg_proc p on p.oid=to_regprocedure(e.signature)
), checks as(
 select
 exists(select 1 from app_private.sql_editor_receipts where version='202610160017' and sha256='dfdae129e62884b12d58e0bb43f628a7b9dece652dc413c789af3a381db8c7e7') receipt_matches,
 (select count(*)=7 and bool_and(oid is not null and coalesce(relrowsecurity,false)) from tables) all_seven_rls_enabled,
 (select bool_and(oid is not null and not coalesce(relforcerowsecurity,true)) from tables) no_unexpected_force_rls,
 not exists(select 1 from policies where schemaname='app_private') six_private_tables_have_no_policies,
 not exists(select 1 from table_privileges where private_table and allowed) six_private_tables_have_no_effective_client_or_service_grants,
 not exists(select 1 from public_acl) no_public_table_grants,
 (select count(*)=2 from policies where schemaname='public' and tablename='deal_media') deal_media_has_only_two_policies,
 exists(select 1 from policies where schemaname='public' and tablename='deal_media' and policyname='admin_read' and permissive='PERMISSIVE' and cmd='SELECT' and roles=array['authenticated']::name[] and with_check is null and
 regexp_replace(replace(lower(qual),'public.',''),'\s','','g')='(selectis_admin()asis_admin)') deal_media_admin_policy_matches,
 exists(select 1 from policies where schemaname='public' and tablename='deal_media' and policyname='public_read' and permissive='PERMISSIVE' and cmd='SELECT' and cardinality(roles)=2 and roles @> array['anon','authenticated']::name[] and with_check is null and
 regexp_replace(replace(lower(qual),'public.',''),'\s','','g')='deal_is_public(deal_id)') deal_media_public_policy_matches,
 (select count(*)=2 and bool_and(allowed) from table_privileges where schema_name='public' and role_name in('anon','authenticated') and privilege='SELECT') deal_media_client_select_grants_present,
 not exists(select 1 from table_privileges where schema_name='public' and role_name in('anon','authenticated') and privilege<>'SELECT' and allowed) deal_media_no_additional_client_table_privileges,
 (select bool_and(oid is not null and prosecdef and owner='postgres' and proconfig @> array['search_path=""'] and anon_execute=anon_ok and authenticated_execute=authenticated_ok and service_execute=service_ok and not public_execute) from rpc_state) rpc_owners_definers_search_paths_and_grants_match
)
select to_jsonb(checks) checks,
 (select jsonb_agg(jsonb_build_object('table',schema_name||'.'||table_name,'exists',oid is not null,'rls',relrowsecurity,'force_rls',relforcerowsecurity,'owner',owner) order by schema_name,table_name) from tables) installed_tables,
 (select coalesce(jsonb_agg(jsonb_build_object('table',schemaname||'.'||tablename,'name',policyname,'command',cmd,'roles',roles,'permissive',permissive,'using',qual,'with_check',with_check) order by schemaname,tablename,policyname),'[]'::jsonb) from policies) installed_policies,
 (select coalesce(jsonb_agg(to_jsonb(p) order by schema_name,table_name,role_name,privilege),'[]'::jsonb) from table_privileges p where allowed) effective_table_privileges,
 (select coalesce(jsonb_agg(to_jsonb(p)),'[]'::jsonb) from public_acl p) public_table_acl,
 (select jsonb_agg(to_jsonb(r)-'oid' order by signature) from rpc_state r) installed_rpcs,
 (select coalesce(jsonb_agg(key),'[]'::jsonb) from jsonb_each(to_jsonb(checks)) where value='false'::jsonb) checks_requiring_review
from checks;
