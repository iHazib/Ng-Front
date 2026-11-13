"""Fresh disposable 001-018; exact 019 installer test. No hosted connection."""
from pathlib import Path
import subprocess,uuid,json,hashlib,os
ROOT=Path(__file__).resolve().parents[1];PG=Path('C:/Program Files/PostgreSQL/16/bin');run=ROOT/'.local'/('database-test-'+uuid.uuid4().hex[:12]);run.mkdir();data=run/'cluster';port='55468';env={**os.environ,'PGCLIENTENCODING':'UTF8'}
def command(name,*args,ok=True):
 if name=='pg_ctl':
  with (run/'control.log').open('a') as log:r=subprocess.run([str(PG/(name+'.exe')),*map(str,args)],stdout=log,stderr=log,env=env,creationflags=subprocess.CREATE_NO_WINDOW,timeout=45)
 else:r=subprocess.run([str(PG/(name+'.exe')),*map(str,args)],capture_output=True,text=True,encoding='utf-8',errors='replace',env=env,creationflags=subprocess.CREATE_NO_WINDOW)
 if ok and r.returncode:raise RuntimeError(name+' failed: '+getattr(r,'stderr','')[-2500:])
 return r
params=['-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',port,'-U','postgres','-d','postgres']
def sql(s,ok=True):return command('psql',*params,'-At','-c',s,ok=ok)
def file(p,ok=True):return command('psql',*params,'-f',p,ok=ok)
command('initdb','-D',data,'-U','postgres','-A','trust','--encoding=UTF8','--no-locale');(data/'postgresql.conf').open('a').write("\nlisten_addresses='127.0.0.1'\nport="+port+'\n')
started=False
try:
 command('pg_ctl','-D',data,'-l',run/'postgres.log','-w','start');started=True
 source=(ROOT/'scripts/test_database.py').read_text(encoding='utf-8');bootstrap=source.split('sql("""',1)[1].split('""")',1)[0];sql(bootstrap)
 bases=[p for p in sorted((ROOT/'supabase/migrations').glob('*.sql')) if p.name.split('_')[0]<'202610180019'];assert len(bases)==18
 for p in bases:file(p)
 sql('create table app_private.sql_editor_receipts(version text primary key,filename text not null,sha256 text not null,applied_at timestamptz not null default now());')
 for p in bases:sql("insert into app_private.sql_editor_receipts(version,filename,sha256) values('"+p.name.split('_')[0]+"','"+p.name+"','"+hashlib.sha256(p.read_bytes()).hexdigest()+"');")
 sql("insert into auth.users values('00000000-0000-0000-0000-000000000001');insert into app_private.admin_members(user_id,reason) values('00000000-0000-0000-0000-000000000001','Synthetic local policy test');")
 file(ROOT/'supabase/tests/commerce-concurrency-setup.sql')
 def snapshot():
  tables=json.loads(sql("select json_agg(schemaname||'.'||tablename) from pg_tables where schemaname in('public','app_private') and tablename<>'sql_editor_receipts'").stdout)
  rows={t:sql("select md5(coalesce(string_agg(to_jsonb(x)::text,'' order by to_jsonb(x)::text),'')) from "+t+' x').stdout for t in tables}
  policies=sql("select json_agg(json_build_object('table',polrelid,'name',polname,'roles',polroles,'command',polcmd,'permissive',polpermissive,'check',polwithcheck::text,'predicate',replace(pg_get_expr(polqual,polrelid),'app_private.media_is_public_016(', 'media_is_public(')) order by polrelid,polname) from pg_policy").stdout
  grants=sql("select json_agg(json_build_object('oid',oid,'acl',relacl,'rls',relrowsecurity,'force',relforcerowsecurity) order by oid) from pg_class where relnamespace in('public'::regnamespace,'app_private'::regnamespace)").stdout
  return rows,policies,grants
 before=snapshot()
 # Reproduce actual hosted failure before correction using a real policy row.
 denied=sql("set role anon;select media_id from public.product_media limit 1;",ok=False);assert denied.returncode and 'media_is_public_016' in denied.stderr
 p=ROOT/'supabase/sql-editor/17_install_media_policy_dispatch_clean.sql';digest=hashlib.sha256(p.read_bytes()).hexdigest();installed=file(p);(run/'exact-installer.log').write_text(installed.stdout+installed.stderr)
 assert before==snapshot()
 out=json.loads(sql("select row_to_json(v) from ("+(ROOT/'supabase/sql-editor/17_preflight_media_policy_dispatch.sql').read_text(encoding='utf-8').split('select exists',1)[1].join(['select exists','']).strip().rstrip(';')+")v").stdout)
 assert out['legacy_policy_count']==0 and out['dispatcher_policy_count']==5 and all(v for k,v in out.items() if k not in ['legacy_policy_count','dispatcher_policy_count'])
 for role,uid in [('anon',''),('authenticated','00000000-0000-0000-0000-000000000002'),('authenticated','00000000-0000-0000-0000-000000000001')]:
  result=sql("set role "+role+";set request.jwt.claim.sub='"+uid+"';select count(*) from public.product_media;select count(*) from public.article_media;select count(*) from public.homepage_selections;select count(*) from public.homepage_media;select count(*) from public.review_media;")
  assert '1' in result.stdout.splitlines()
 sql("update public.products set status='draft';")
 assert sql("set role anon;select count(*) from public.product_media;").stdout.strip().splitlines()[-1]=='0'
 assert sql("set role authenticated;set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';select count(*) from public.product_media;").stdout.strip().splitlines()[-1]=='1'
 denied=sql("set role authenticated;select app_private.media_is_public_016('99999999-0000-4000-8000-000000000005');",ok=False);assert denied.returncode
 repeat=file(p,ok=False);assert repeat.returncode and '019 already installed' in repeat.stderr
 assert hashlib.sha256(p.read_bytes()).hexdigest()==digest
 report={'kind':'fresh disposable PostgreSQL 001-018; Auth/Storage doubles, not hosted','exact_file':str(p.relative_to(ROOT)),'installer_sha256':digest,'execution':'psql -X -v ON_ERROR_STOP=1 -f','base_migrations':len(bases),'reproduced_hosted_failure':True,'final_checks':out,'business_rows_unchanged':True,'policy_predicates_preserved_except_dispatcher':True,'rls_grants_policy_roles_commands_with_check_preserved':True,'anonymous_non_admin_admin_reads':True,'draft_isolation':True,'legacy_helper_still_private':True,'repeat_refused':True,'status':'passed','evidence':run.name}
 (ROOT/'docs/media-policy-dispatch-local-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report),flush=True)
finally:
 if started:command('pg_ctl','-D',data,'-m','fast','-w','stop')
