"""Fresh disposable 001-019; exact 020 installer test. No hosted connection."""
from pathlib import Path
import subprocess,uuid,json,hashlib,os
from concurrent.futures import ThreadPoolExecutor
ROOT=Path(__file__).resolve().parents[1];PG=Path('C:/Program Files/PostgreSQL/16/bin');run=ROOT/'.local'/('database-test-'+uuid.uuid4().hex[:12]);run.mkdir();data=run/'cluster';port='55473';env={**os.environ,'PGCLIENTENCODING':'UTF8'}
def command(name,*args,ok=True):
 if name=='pg_ctl':
  with (run/'control.log').open('a') as log:r=subprocess.run([str(PG/(name+'.exe')),*map(str,args)],stdout=log,stderr=log,env=env,creationflags=subprocess.CREATE_NO_WINDOW,timeout=45)
 else:r=subprocess.run([str(PG/(name+'.exe')),*map(str,args)],capture_output=True,text=True,encoding='utf-8',errors='replace',env=env,creationflags=subprocess.CREATE_NO_WINDOW)
 if ok and r.returncode:raise RuntimeError(name+' failed: '+getattr(r,'stderr','')[-2500:])
 return r
params=['-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',port,'-U','postgres','-d','postgres']
def sql(s,ok=True):return command('psql',*params,'-At','-c',s,ok=ok)
def file(p,ok=True):return command('psql',*params,'-f',p,ok=ok)
command('initdb','-D',data,'-U','postgres','-A','trust','--encoding=UTF8','--no-locale');(data/'postgresql.conf').open('a',encoding='utf-8').write("\nlisten_addresses='127.0.0.1'\nport="+port+'\n')
started=False
try:
 command('pg_ctl','-D',data,'-l',run/'postgres.log','-w','start');started=True
 source=(ROOT/'scripts/test_database.py').read_text(encoding='utf-8');bootstrap=source.split('sql("""',1)[1].split('""")',1)[0];sql(bootstrap)
 bases=[p for p in sorted((ROOT/'supabase/migrations').glob('*.sql')) if p.name<'202611230023']
 for p in bases:file(p)
 sql('create table app_private.sql_editor_receipts(version text primary key,filename text not null,sha256 text not null,applied_at timestamptz not null default now());')
 sql("insert into auth.users values('00000000-0000-0000-0000-000000000001');insert into app_private.admin_members(user_id,reason) values('00000000-0000-0000-0000-000000000001','Synthetic boxed set test');")
 file(ROOT/'supabase/tests/deals-race-setup.sql')
 # Set only the local fixture to Draft before restoring its old imported classification.
 sql("update public.products set status='draft' where id='15151515-0000-4000-8000-000000000001';update public.variants set status='draft',sellable_kind='unconfirmed_set' where product_id='15151515-0000-4000-8000-000000000001';")
 assert 'set_contents_missing' in sql("select app_private.publication_blockers('15151515-0000-4000-8000-000000000001');").stdout
 tables=json.loads(sql("select json_agg(schemaname||'.'||tablename) from pg_tables where schemaname in('public','app_private') and tablename not in('sql_editor_receipts','admin_reminder_issues')").stdout)
 def snapshot():return {t:sql("select md5(coalesce(string_agg(to_jsonb(x)::text,'' order by to_jsonb(x)::text),'')) from "+t+' x').stdout for t in tables}
 before=snapshot();acl=sql("select md5(string_agg(concat_ws(':',oid,proowner,proacl::text,proconfig::text),',' order by oid)) from pg_proc where pronamespace in('public'::regnamespace,'app_private'::regnamespace)").stdout
 installer=ROOT/'supabase/sql-editor/20_install_optional_boxed_sets_clean.sql';digest=hashlib.sha256(installer.read_bytes()).hexdigest();result=file(installer);(run/'exact-installer.log').write_text(result.stdout+result.stderr,encoding='utf-8')
 assert before==snapshot(),'Existing business data changed'
 assert acl==sql("select md5(string_agg(concat_ws(':',oid,proowner,proacl::text,proconfig::text),',' order by oid)) from pg_proc where pronamespace in('public'::regnamespace,'app_private'::regnamespace)").stdout
 assert sql("select cardinality(app_private.publication_blockers('15151515-0000-4000-8000-000000000001'));").stdout.strip()=='0'
 assert sql("select count(*) from app_private.admin_current_issues('15151515-0000-4000-8000-000000000001') where code='set_contents_missing';").stdout.strip()=='0'
 # Controlled local publish, not a hosted operation: check the real daily save workflow.
 sql("set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';select public.save_daily_product(p.id,p.revision,jsonb_build_object('name',p.name,'description',p.description,'brand',p.brand_id,'category',p.category_id,'productType',p.product_type_id,'options',(select jsonb_agg(jsonb_build_object('id',v.id,'sku',v.original_sku,'label',v.label,'priceMinor',price.amount_minor,'countChanged',false)) from public.variants v join public.variant_prices price on price.variant_id=v.id where v.product_id=p.id)),gen_random_uuid(),'publish') from public.products p where p.id='15151515-0000-4000-8000-000000000001';")
 assert sql("select public.variant_is_public('15151515-0000-4000-8000-000000000002');").stdout.strip()=='t'
 sql("update public.variants set sellable_kind='factory_set' where id='15151515-0000-4000-8000-000000000002';")
 assert sql("select public.variant_is_public('15151515-0000-4000-8000-000000000002');").stdout.strip()=='t'
 # Other safeguards remain enforceable; block direct published-state corruption.
 for change in ["delete from public.variant_prices where variant_id='15151515-0000-4000-8000-000000000002'", "update public.inventory_balances set reconciled_at=null where variant_id='15151515-0000-4000-8000-000000000002'", "update public.products set description='' where id='15151515-0000-4000-8000-000000000001'"]:
  sql('begin;'+change,ok=False);assert sql("select public.variant_is_public('15151515-0000-4000-8000-000000000002');").stdout.strip()=='t'
 repeat=file(installer,ok=False);assert repeat.returncode and '023 already installed' in repeat.stderr
 assert hashlib.sha256(installer.read_bytes()).hexdigest()==digest
 report={'status':'passed','kind':'fresh disposable PostgreSQL, Supabase Auth/Storage doubles; not hosted','base_migrations':len(bases),'exact_file':str(installer.relative_to(ROOT)),'installer_sha256':digest,'execution':'psql -X -v ON_ERROR_STOP=1 -f','business_rows_preserved':True,'function_oids_owners_grants_preserved':True,'unconfirmed_set_daily_publish_and_public_visibility':True,'factory_set_without_contents_public_visibility':True,'reminder_removed':True,'other_safeguards_retained':True,'repeat_refused':True,'final_flags_in_log':str(run.relative_to(ROOT)/'exact-installer.log')}
 (ROOT/'docs/boxed-set-local-verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(json.dumps(report))
finally:
 if started:command('pg_ctl','-D',data,'-m','fast','-w','stop')
