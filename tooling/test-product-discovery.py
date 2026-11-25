"""Fresh disposable 001-019; exact 020 installer test. No hosted connection."""
from pathlib import Path
import subprocess,uuid,json,hashlib,os
from concurrent.futures import ThreadPoolExecutor
ROOT=Path(__file__).resolve().parents[1];PG=Path('C:/Program Files/PostgreSQL/16/bin');run=ROOT/'.local'/('database-test-'+uuid.uuid4().hex[:12]);run.mkdir();data=run/'cluster';port='55474';env={**os.environ,'PGCLIENTENCODING':'UTF8'}
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
 bases=[p for p in sorted((ROOT/'supabase/migrations').glob('*.sql')) if p.name<'202611250024']
 for p in bases:file(p)
 sql('create table app_private.sql_editor_receipts(version text primary key,filename text not null,sha256 text not null,applied_at timestamptz not null default now());')
 for p in bases:sql("insert into app_private.sql_editor_receipts(version,filename,sha256) values('"+p.name.split('_')[0]+"','"+p.name+"','"+hashlib.sha256(p.read_bytes()).hexdigest()+"');")
 sql("insert into auth.users values('00000000-0000-0000-0000-000000000001');insert into app_private.admin_members(user_id,reason) values('00000000-0000-0000-0000-000000000001','Synthetic discovery test');")
 file(ROOT/'supabase/tests/deals-race-setup.sql')
 tables=json.loads(sql("select json_agg(schemaname||'.'||tablename) from pg_tables where schemaname in('public','app_private') and tablename not in('sql_editor_receipts','storefront_search','admin_catalog_search')").stdout)
 def snapshot():return {t:sql("select coalesce(json_agg(to_jsonb(x)),'[]') from "+t+' x').stdout for t in tables}
 before=snapshot();acl=sql("select md5(string_agg(concat_ws(':',oid,proowner,proacl::text,proconfig::text),',' order by oid)) from pg_proc where pronamespace in('public'::regnamespace,'app_private'::regnamespace)").stdout
 installer=ROOT/'supabase/sql-editor/21_install_product_discovery_clean.sql';digest=hashlib.sha256(installer.read_bytes()).hexdigest();result=file(installer);(run/'exact-installer.log').write_text(result.stdout+result.stderr,encoding='utf-8')
 after=snapshot()
 for t in tables:
  old=json.loads(before[t]);new=json.loads(after[t]);assert all(x in new for x in old),'Existing business data changed: '+t
 final=json.loads(sql('select row_to_json(v) from ('+('select exists'+(ROOT/'supabase/sql-editor/21_preflight_product_discovery.sql').read_text(encoding='utf-8').split('select exists',1)[1]).strip().rstrip(';')+')v').stdout);assert all(final.values()),final
 file(ROOT/'supabase/tests/product-discovery.sql')
 repeat=file(installer,ok=False);assert repeat.returncode and '024 already' in repeat.stderr
 report={'status':'passed','kind':'fresh disposable PostgreSQL; Auth/Storage doubles, not hosted','base_migrations':len(bases),'exact_file':str(installer.relative_to(ROOT)),'installer_sha256':digest,'execution':'psql -X -v ON_ERROR_STOP=1 -f','existing_business_rows_preserved':True,'final_flags':final,'assertions':int(sql('select count(*) from discovery_test.checks').stdout),'repeat_refused':True,'evidence':run.name}
 (ROOT/'docs/product-discovery-local-verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(json.dumps(report))
finally:
 if started:command('pg_ctl','-D',data,'-m','fast','-w','stop')
