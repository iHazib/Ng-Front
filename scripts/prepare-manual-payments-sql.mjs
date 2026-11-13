import {readFile,writeFile} from 'node:fs/promises';import {createHash} from 'node:crypto';
const file='202610150016_manual_advance_payments.sql',version='202610150016',hash=x=>createHash('sha256').update(x).digest('hex'),source=await readFile('supabase/migrations/'+file),sha=hash(source),prior=hash(await readFile('supabase/migrations/202610130015_guest_commerce.sql'));
const verify=`-- READ ONLY. No customer, receiving-account or catalog data returned.
select exists(select 1 from app_private.sql_editor_receipts where version='202610130015' and sha256='${prior}') prerequisite_015,
 to_regclass('app_private.manual_payments') is not null manual_payments_present,
 to_regclass('app_private.payment_submissions') is not null submissions_present,
 to_regclass('app_private.payment_receipts') is not null receipts_present,
 to_regclass('app_private.payment_actions') is not null actions_present,
 (to_regprocedure('public.review_manual_payment(uuid,integer,text,uuid,jsonb)') is not null and to_regprocedure('public.admin_payment_orders(text,text,date,date,integer,uuid,text)') is not null and to_regprocedure('app_private.reacquire_payment_stock(uuid)') is not null) review_present,
 to_regprocedure('public.payment_proof(uuid,text,text,uuid,text,jsonb)') is not null proof_present,
 exists(select 1 from pg_trigger where tgname='payment_proof_private' and tgrelid='public.media_assets'::regclass) private_proof_guard,
 exists(select 1 from app_private.sql_editor_receipts where version='${version}') receipt_present,
 exists(select 1 from app_private.sql_editor_receipts where version='${version}' and sha256='${sha}') receipt_matches,
 (select count(*)=4 and bool_and(relrowsecurity) from pg_class where oid in(to_regclass('app_private.manual_payments'),to_regclass('app_private.payment_submissions'),to_regclass('app_private.payment_receipts'),to_regclass('app_private.payment_actions'))) private_rls,
 not exists(select 1 from pg_policies where schemaname='app_private' and tablename in('manual_payments','payment_submissions','payment_receipts','payment_actions')) no_client_policies,
 case when to_regprocedure('public.review_manual_payment(uuid,integer,text,uuid,jsonb)') is null then false else has_function_privilege('authenticated','public.review_manual_payment(uuid,integer,text,uuid,jsonb)','execute') and not has_function_privilege('anon','public.review_manual_payment(uuid,integer,text,uuid,jsonb)','execute') and (select prosecdef and position('require_admin()' in prosrc)>0 from pg_proc where oid=to_regprocedure('public.review_manual_payment(uuid,integer,text,uuid,jsonb)')) end admin_authorization,
 case when to_regprocedure('public.submit_manual_payment(uuid,text,text,uuid,text,bigint,uuid)') is null then false else has_function_privilege('service_role','public.submit_manual_payment(uuid,text,text,uuid,text,bigint,uuid)','execute') and not has_function_privilege('authenticated','public.submit_manual_payment(uuid,text,text,uuid,text,bigint,uuid)','execute') and not has_function_privilege('anon','public.submit_manual_payment(uuid,text,text,uuid,text,bigint,uuid)','execute') end guest_gateway_private;
`;
const sql=`-- Complete incremental 016. Apply ONCE after canonical 015; no earlier installers.
-- No business rows deleted or rewritten. Replaces payment/fulfilment guards.
-- Drops and immediately replaces only CHECK constraints, not tables or data.
begin;
set local lock_timeout='5s';set local statement_timeout='120s';
select pg_advisory_xact_lock(73524);
do $guard$ begin
 if not exists(select 1 from app_private.sql_editor_receipts where version='202610130015' and sha256='${prior}') then raise exception 'Verify canonical 015 receipt first';end if;
 if exists(select 1 from app_private.sql_editor_receipts where version='${version}') or to_regclass('app_private.manual_payments') is not null or to_regclass('app_private.payment_submissions') is not null or to_regclass('app_private.payment_receipts') is not null or to_regclass('app_private.payment_actions') is not null or to_regprocedure('public.review_manual_payment(uuid,integer,text,uuid,jsonb)') is not null then raise exception 'Manual payments already or partly installed; inspect state, do not rerun';end if;
end $guard$;
${source.toString()}
insert into app_private.sql_editor_receipts(version,filename,sha256) values('${version}','${file}','${sha}');
notify pgrst,'reload schema';
commit;
${verify}`;
const functions=[...sql.matchAll(/^create (?:or replace )?function ([\w.]+)/gm)].map(x=>x[1]);if(new Set(functions).size!==functions.length||[...sql.matchAll(/^insert into app_private.sql_editor_receipts/gm)].length!==1)throw Error('Installer contains duplicate functions or receipts');
await writeFile('supabase/sql-editor/14_preflight_manual_payments.sql',verify);await writeFile('supabase/sql-editor/14_install_manual_payments_clean.sql',sql);await writeFile('docs/manual-payments-installer-manifest.json',JSON.stringify({canonical:file,canonical_sha256:sha,installer_sha256:hash(sql),prior_015_sha256:prior},null,2)+'\n');console.log('Generated incremental manual payment installer and read-only preflight.');
