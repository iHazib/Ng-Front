"""Fresh disposable 001-019; exact 020 installer test. No hosted connection."""
from pathlib import Path
import subprocess,uuid,json,hashlib,os
from concurrent.futures import ThreadPoolExecutor
ROOT=Path(__file__).resolve().parents[1];PG=Path('C:/Program Files/PostgreSQL/16/bin');run=ROOT/'.local'/('database-test-'+uuid.uuid4().hex[:12]);run.mkdir();data=run/'cluster';port='55470';env={**os.environ,'PGCLIENTENCODING':'UTF8'}
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
 bases=[p for p in sorted((ROOT/'supabase/migrations').glob('*.sql')) if p.name.split('_')[0]<'202610180020'];assert len(bases)==19
 for p in bases:file(p)
 sql('create table app_private.sql_editor_receipts(version text primary key,filename text not null,sha256 text not null,applied_at timestamptz not null default now());')
 for p in bases:sql("insert into app_private.sql_editor_receipts(version,filename,sha256) values('"+p.name.split('_')[0]+"','"+p.name+"','"+hashlib.sha256(p.read_bytes()).hexdigest()+"');")
 sql("insert into auth.users values('00000000-0000-0000-0000-000000000001');insert into app_private.admin_members(user_id,reason) values('00000000-0000-0000-0000-000000000001','Synthetic reporting local test');")
 file(ROOT/'supabase/tests/deals-race-setup.sql')
 file(ROOT/'supabase/tests/reports-fixtures.sql')
 sql("set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';do $$$$ declare oid uuid;begin oid=report_test.place();perform report_test.pay(oid);perform report_test.step(oid,'confirm');perform report_test.step(oid,'dispatch');perform report_test.step(oid,'complete');end $$$$;".replace('$$$$','$$'))
 tables=json.loads(sql("select json_agg(schemaname||'.'||tablename) from pg_tables where schemaname in('public','app_private') and tablename<>'sql_editor_receipts'").stdout)
 def snapshot():return {t:sql("select md5(coalesce(string_agg(to_jsonb(x)::text,'' order by to_jsonb(x)::text),'')) from "+t+' x').stdout for t in tables}
 before=snapshot()
 p=ROOT/'supabase/sql-editor/18_install_reports_refunds_clean.sql';digest=hashlib.sha256(p.read_bytes()).hexdigest();installed=file(p);(run/'exact-installer.log').write_text(installed.stdout+installed.stderr)
 assert before==snapshot()
 verify=(ROOT/'supabase/sql-editor/18_preflight_reports_refunds.sql').read_text(encoding='utf-8').split('select exists',1)[1]
 out=json.loads(sql('select row_to_json(v) from (select exists'+verify.strip().rstrip(';')+')v').stdout);assert all(out.values()),out
 file(ROOT/'supabase/tests/reports-refunds.sql')
 file(ROOT/'supabase/tests/reports-refunds-extra.sql')
 uid="set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';"
 def value(statement):return sql(uid+statement).stdout.strip().splitlines()[-1]
 def quote(text):return "'"+str(text).replace("'","''")+"'"
 def rpc_action(oid,revision,key,action,payload):return "select public.admin_finance_action("+','.join([quote(oid)+'::uuid',str(revision),quote(key)+'::uuid',quote(action),quote(json.dumps(payload))+'::jsonb'])+");"
 def race(statements):
  with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda statement:sql("set role authenticated;"+uid+statement,ok=False),statements))
  assert sorted(r.returncode==0 for r in results)==[False,True],[(r.returncode,r.stderr[-500:]) for r in results]
  return [r.returncode==0 for r in results]
 oid=value('select report_test.place();');value('select report_test.pay('+quote(oid)+'::uuid);')
 reqs=[value('select report_test.request('+quote(oid)+'::uuid,report_test.selection('+quote(oid)+'::uuid,false,1));') for _ in range(2)]
 revision=int(value('select revision from app_private.finance_versions where order_id='+quote(oid)+'::uuid;'))
 race([rpc_action(oid,revision,uuid.uuid4(),'approve',{'refundId':rid,'reason':'Concurrent synthetic approval'}) for rid in reqs])
 assert int(value("select coalesce(sum(amount_minor),0) from app_private.refund_requests where order_id="+quote(oid)+"::uuid and state='approved';"))==100000
 for rid in reqs:value("select report_test.finance("+quote(oid)+"::uuid,'cancel',"+quote(json.dumps({'refundId':rid,'reason':'Release concurrent test approval'}))+"::jsonb);")
 value("select report_test.step("+quote(oid)+"::uuid,'cancel');")
 orders=[];sends=[]
 for _ in range(2):
  oid=value('select report_test.place();');value('select report_test.pay('+quote(oid)+'::uuid);');rid=value('select report_test.request('+quote(oid)+'::uuid,report_test.selection('+quote(oid)+'::uuid,false,1));')
  value("select report_test.finance("+quote(oid)+"::uuid,'approve',"+quote(json.dumps({'refundId':rid,'reason':'Synthetic send race approval'}))+"::jsonb);")
  revision=int(value('select revision from app_private.finance_versions where order_id='+quote(oid)+'::uuid;'))
  sends.append(rpc_action(oid,revision,uuid.uuid4(),'send',{'refundId':rid,'reason':'Concurrent outgoing-history verification','method':'bank-transfer','account':'Synthetic account','reference':'SYNTHETIC-CONCURRENT-TRANSFER','sentAt':value('select clock_timestamp();'),'checkedHistory':True}));orders.append((oid,rid))
 winners=race(sends)
 assert int(value("select count(*) from app_private.refund_events where action='send' and reference='SYNTHETIC-CONCURRENT-TRANSFER';"))==1
 for (oid,rid),won in zip(orders,winners):
  if not won:value("select report_test.finance("+quote(oid)+"::uuid,'cancel',"+quote(json.dumps({'refundId':rid,'reason':'Release unsent race fixture'}))+"::jsonb);")
  value("select report_test.step("+quote(oid)+"::uuid,'cancel');")
 # Release any remaining synthetic operational holds; financial history is retained.
 value("do $$ declare item record;begin for item in select order_id from app_private.commerce_orders where fulfilment in('placed','confirmed') loop perform report_test.step(item.order_id,'cancel');end loop;end $$;")
 assert json.loads(value('select public.commerce_reconciliation();'))=={'balanceMismatches':0,'overdueHolds':0,'endedDealAllocations':0}
 assertions=int(value('select count(*) from report_test.checks;'))

 repeat=file(p,ok=False);assert repeat.returncode and 'already or partly installed' in repeat.stderr
 assert hashlib.sha256(p.read_bytes()).hexdigest()==digest
 # 020 remains byte-identical to the installer already supplied to the owner.
 frozen=json.loads((ROOT/'docs/reports-installer-manifest.json').read_text(encoding='utf-8'))
 assert frozen['installer_sha256']==digest=='9495f7d52a00ebbc2679e861215475fddef46e85ff91cb356a770398cb6ae515'
 tables21=json.loads(sql("select json_agg(schemaname||'.'||tablename) from pg_tables where schemaname in('public','app_private') and tablename<>'sql_editor_receipts'").stdout)
 def snapshot21():return {t:sql("select md5(coalesce(string_agg(to_jsonb(x)::text,'' order by to_jsonb(x)::text),'')) from "+t+' x').stdout for t in tables21}
 before21=snapshot21()
 grants=sql("select json_agg(json_build_object('oid',oid,'owner',proowner,'acl',proacl) order by oid) from pg_proc where pronamespace in('public'::regnamespace,'app_private'::regnamespace)").stdout
 p21=ROOT/'supabase/sql-editor/19_install_partial_refunds_clean.sql';digest21=hashlib.sha256(p21.read_bytes()).hexdigest();applied=file(p21);(run/'exact-021-installer.log').write_text(applied.stdout+applied.stderr)
 assert before21==snapshot21()
 assert grants==sql("select json_agg(json_build_object('oid',oid,'owner',proowner,'acl',proacl) order by oid) from pg_proc where pronamespace in('public'::regnamespace,'app_private'::regnamespace)").stdout
 verify21=(ROOT/'supabase/sql-editor/19_preflight_partial_refunds.sql').read_text(encoding='utf-8').split('select exists',1)[1]
 final21=json.loads(sql('select row_to_json(v) from (select exists'+verify21.strip().rstrip(';')+')v').stdout);assert all(final21.values()),final21
 file(ROOT/'supabase/tests/partial-refunds.sql')
 repeat21=file(p21,ok=False);assert repeat21.returncode and '021 already installed' in repeat21.stderr
 assert hashlib.sha256(p21.read_bytes()).hexdigest()==digest21
 report={'kind':'fresh disposable PostgreSQL 001-019 plus exact 020 and 021; Auth/Storage doubles, not hosted','status':'passed','execution':'psql -X -v ON_ERROR_STOP=1 -f','installer_020_sha256':digest,'exact_021_file':str(p21.relative_to(ROOT)),'installer_021_sha256':digest21,'final_020_flags':out,'final_021_flags':final21,'existing_financial_rows_preserved':True,'function_identities_owners_grants_preserved':True,'020_regressions_and_independent_races':'passed','021_assertions':int(value('select count(*) from report_test.checks;'))-assertions,'repeat_refused':True,'evidence':run.name}
 (ROOT/'docs/partial-refunds-local-verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report),flush=True)

finally:
 if started:command('pg_ctl','-D',data,'-m','fast','-w','stop')
