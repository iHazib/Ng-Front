"""Create a NEW disposable local PostgreSQL cluster, migrate, test, generate TS.
Never connects to an existing database or uses DATABASE_URL. Keeps local evidence.
Supabase auth/storage schemas below are test doubles, not production migrations.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import uuid
ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--pg-bin',type=Path,default=Path('C:/Program Files/PostgreSQL/16/bin'))
    parser.add_argument('--port',type=int,default=55439)
    parser.add_argument('--sql-editor',action='store_true',help='Test the generated atomic SQL Editor installer')
    parser.add_argument('--daily-editor-installer',action='store_true',help='Apply only migrations 001-007, preserve a seeded catalog, then execute EXACT file 06 with psql -f')
    parser.add_argument('--storefront-installer',action='store_true',help='Apply 001-008 then execute exact storefront SQL Editor file')
    parser.add_argument('--product-markdown-installer',action='store_true',help='Apply 001-011 then execute exact incremental Markdown installer')
    parser.add_argument('--deals-installer',action='store_true',help='Fresh 001-016 then exact incremental 017 installer')
    parser.add_argument('--manual-payments-installer',action='store_true',help='Fresh 001-015 then exact manual-payment installer')
    parser.add_argument('--commerce-installer',action='store_true',help='Apply 001-014 then execute EXACT commerce installer and targeted transactional tests')
    parser.add_argument('--admin-exact-search-installer',action='store_true',help='Apply 001-013 then exact incremental 014 installer')
    parser.add_argument('--admin-list-installer',action='store_true',help='Apply 001-012 then execute exact incremental admin-list installer')
    parser.add_argument('--reviews-installer',action='store_true',help='Apply 001-010 then exact review installer with ON_ERROR_STOP=1')
    parser.add_argument('--content-installer',action='store_true',help='Apply 001-009 then execute exact content CMS SQL Editor file')
    parser.add_argument('--storefront-file',type=Path,default=Path('supabase/sql-editor/07_install_public_storefront_clean.sql'),help='Exact complete storefront installer artifact to execute')
    parser.add_argument('--daily-editor-file',type=Path,default=Path('supabase/sql-editor/06_install_daily_product_editor.sql'),help='Exact complete installer artifact to execute')
    args=parser.parse_args()
    run_dir=ROOT/'.local'/('database-test-'+uuid.uuid4().hex[:12]); run_dir.mkdir(parents=True)
    data=run_dir/'cluster'
    env={**os.environ,'PGCLIENTENCODING':'UTF8','PGOPTIONS':'-c timezone=UTC'}
    def command(name,*params,stdin=None):
        if name=='pg_ctl':
            # PostgreSQL on Windows can inherit captured pipe handles. File handles
            # let pg_ctl return without waiting for the database process to exit.
            with (run_dir/'pg-control.log').open('a',encoding='utf-8') as output:
                result=subprocess.run([str(args.pg_bin/(name+'.exe')),*map(str,params)],stdin=subprocess.DEVNULL,stdout=output,stderr=output,env=env,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0),timeout=45)
            if result.returncode: raise RuntimeError('pg_ctl failed; inspect local pg-control.log')
            return ''
        result=subprocess.run([str(args.pg_bin/(name+'.exe')),*map(str,params)],input=stdin,text=True,encoding='utf-8',errors='replace',capture_output=True,env=env,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        if result.returncode: raise RuntimeError(name+': '+result.stderr[-4000:])
        if name=='psql' and ('PASS:' in result.stderr or 'PASS denied:' in result.stderr):
            (run_dir/'assertions.txt').write_text(result.stderr,encoding='utf-8')
            print(result.stderr,flush=True)
        return result.stdout
    def sql(text): return command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-At',stdin=text)
    command('initdb','-D',data,'-U','postgres','-A','trust','--encoding=UTF8','--no-locale')
    # Loopback only, fresh isolated cluster. Never stop/delete a user's server.
    (data/'postgresql.conf').open('a',encoding='utf-8').write("\nlisten_addresses='127.0.0.1'\nport="+str(args.port)+"\nlog_statement='none'\n")
    started=False
    try:
        command('pg_ctl','-D',data,'-l',run_dir/'postgres.log','-w','start'); started=True
        sql("""
        create role anon nologin; create role authenticated nologin; create role service_role nologin bypassrls;
        create schema auth; create table auth.users(id uuid primary key);
        create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
        grant usage on schema auth to anon,authenticated; grant execute on function auth.uid() to anon,authenticated;
        create schema storage; create table storage.buckets(id text primary key,name text,public boolean);
        create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text references storage.buckets(id),name text);
        alter table storage.objects enable row level security;
        grant usage on schema storage to anon,authenticated;
        grant select,insert,update,delete on storage.objects to anon,authenticated;
        """)
        migrations=[]
        installer_report=None
        if args.deals_installer:
            bases=[p for p in sorted((ROOT/'supabase/migrations').glob('*.sql')) if p.name.split('_')[0]<'202610160017']
            assert len(bases)==16
            for file in bases:
                command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',file);migrations.append(file.name)
            sql('create table app_private.sql_editor_receipts(version text primary key,filename text not null,sha256 text not null,applied_at timestamptz not null default now());')
            for file in bases: sql("insert into app_private.sql_editor_receipts values('"+file.name.split('_')[0]+"','"+file.name+"','"+hashlib.sha256(file.read_bytes()).hexdigest()+"',now());")
            sql("insert into auth.users values('00000000-0000-0000-0000-000000000001');insert into app_private.admin_members(user_id,reason) values('00000000-0000-0000-0000-000000000001','Disposable preserved fixture');")
            preserved=(ROOT/'supabase/tests/commerce-concurrency-setup.sql').read_text(encoding='utf-8').replace('15151515','14141414').replace('99999999','14141415').replace('sf-','preserved-sf-').replace('SF-','PRESERVED-SF-').replace('Synthetic','Preserved Synthetic').replace('mock/fixture','mock/preserved-fixture')
            sql(preserved)
            sql("select public.place_guest_order('14141414-0000-4000-8000-000000000200',repeat('a',64),repeat('b',64),'[{\"id\":\"14141414-0000-4000-8000-000000000002\",\"quantity\":1,\"expectedPriceMinor\":100000}]','{\"name\":\"Preserved synthetic guest\",\"phone\":\"+923001234567\",\"address\":\"Preserved synthetic address\",\"city\":\"Test City\"}','{\"id\":\"legacy-test\",\"label\":\"Existing snapshot\",\"feeMinor\":0}','{\"id\":\"bank-transfer\",\"label\":\"Existing snapshot\",\"allocation\":\"temporary\",\"accountTitle\":\"Synthetic\",\"destination\":\"TEST-ONLY\",\"accountScope\":\"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\"}','{\"mode\":\"development\",\"version\":\"preservation\",\"paymentSeconds\":604800,\"reviewExtensionSeconds\":30}');")
            installer=ROOT/'supabase/sql-editor/15_install_deals_clean.sql'
            exact_hash=hashlib.sha256(installer.read_bytes()).hexdigest()
            tables=json.loads(sql("select json_agg(schemaname||'.'||tablename) from pg_tables where schemaname in('public','app_private') and tablename<>'sql_editor_receipts';"))
            def snapshot():
                parts=[]
                for t in tables:
                    excluded=['description','starts_at','ends_at'] if t=='public.deals' else ['deal_id'] if t in ['public.homepage_selections','public.media_workflows'] else []
                    expr='to_jsonb(x)'+("-array["+','.join("'"+v+"'" for v in excluded)+"]" if excluded else '')
                    parts.append("select '"+t+"' name,md5(coalesce(string_agg(("+expr+")::text,'' order by ("+expr+")::text),'')) hash from "+t+" x")
                return json.loads(sql('select json_object_agg(name,hash) from ('+' union all '.join(parts)+') preserved;'))
            before=snapshot()
            preflight=ROOT/'supabase/sql-editor/15_preflight_deals.sql'
            flags=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-At','-f',preflight).strip().split('|')
            assert flags==['t']+['f']*10+['t']+['f']*3,flags
            output=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',installer)
            assert snapshot()==before
            assert hashlib.sha256(installer.read_bytes()).hexdigest()==exact_hash
            flags=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-At','-f',preflight).strip().split('|')
            assert flags==['t']*15,flags
            try: command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',installer)
            except RuntimeError as error: assert 'already or partly installed' in str(error)
            else: raise AssertionError('Repeat must refuse')
            assert snapshot()==before
            (run_dir/'deals-exact-installer-output.txt').write_text(output,encoding='utf-8')
        elif args.manual_payments_installer:
            bases=[p for p in sorted((ROOT/'supabase/migrations').glob('*.sql')) if p.name.split('_')[0]<'202610150016']
            assert len(bases)==15
            for file in bases:
                command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',file);migrations.append(file.name)
            sql('create table app_private.sql_editor_receipts(version text primary key,filename text not null,sha256 text not null,applied_at timestamptz not null default now());')
            for file in bases: sql("insert into app_private.sql_editor_receipts values('"+file.name.split('_')[0]+"','"+file.name+"','"+hashlib.sha256(file.read_bytes()).hexdigest()+"',now());")
            sql("insert into auth.users values('00000000-0000-0000-0000-000000000001');insert into app_private.admin_members(user_id,reason) values('00000000-0000-0000-0000-000000000001','Disposable preserved fixture');")
            preserved=(ROOT/'supabase/tests/commerce-concurrency-setup.sql').read_text(encoding='utf-8').replace('15151515','14141414').replace('99999999','14141415').replace('sf-','preserved-sf-').replace('SF-','PRESERVED-SF-').replace('Synthetic','Preserved Synthetic').replace('mock/fixture','mock/preserved-fixture')
            sql(preserved)
            sql("select public.place_guest_order('14141414-0000-4000-8000-000000000200',repeat('a',64),repeat('b',64),'[{\"id\":\"14141414-0000-4000-8000-000000000002\",\"quantity\":1,\"expectedPriceMinor\":100000}]','{\"name\":\"Preserved synthetic guest\",\"phone\":\"+923001234567\",\"address\":\"Preserved synthetic address\",\"city\":\"Test City\"}','{\"id\":\"legacy-test\",\"label\":\"Existing snapshot\",\"feeMinor\":0}','{\"id\":\"legacy-cod\",\"label\":\"Existing snapshot\",\"allocation\":\"accepted\"}','{\"mode\":\"development\",\"version\":\"preservation\"}');")
            installer=ROOT/'supabase/sql-editor/14_install_manual_payments_clean.sql'
            exact_hash=hashlib.sha256(installer.read_bytes()).hexdigest()
            tables=json.loads(sql("select json_agg(schemaname||'.'||tablename) from pg_tables where schemaname in('public','app_private') and tablename<>'sql_editor_receipts';"))
            def snapshot(): return {t:sql("select md5(coalesce(string_agg(to_jsonb(x)::text,'' order by to_jsonb(x)::text),'')) from "+t+" x;").strip() for t in tables}
            before=snapshot()
            preflight=ROOT/'supabase/sql-editor/14_preflight_manual_payments.sql'
            flags=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-At','-f',preflight).strip().split('|')
            assert flags==['t']+['f']*10+['t','f','f'],flags
            output=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',installer)
            assert snapshot()==before
            assert hashlib.sha256(installer.read_bytes()).hexdigest()==exact_hash
            flags=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-At','-f',preflight).strip().split('|')
            assert flags==['t']*14,flags
            try: command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',installer)
            except RuntimeError as error: assert 'already or partly installed' in str(error)
            else: raise AssertionError('Repeat must refuse')
            assert snapshot()==before
            (run_dir/'manual-payments-exact-installer-output.txt').write_text(output,encoding='utf-8')
        elif args.daily_editor_installer:
            bases=[p for p in sorted((ROOT/'supabase/migrations').glob('*.sql')) if p.name.split('_')[0]<'202610060008']
            assert len(bases)==7
            for file in bases:
                command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',file)
                migrations.append(file.name)
            # Receipt registry is SQL Editor infrastructure, not a business migration.
            sql('create table app_private.sql_editor_receipts(version text primary key,filename text not null,sha256 text not null,applied_at timestamptz not null default now());')
            for file in bases:
                sql("insert into app_private.sql_editor_receipts(version,filename,sha256) values('"+file.name.split('_')[0]+"','"+file.name+"','"+hashlib.sha256(file.read_bytes()).hexdigest()+"');")
            print('Applied only migrations 001-007 to fresh disposable database; no earlier installers invoked',flush=True)
        elif args.sql_editor:
            sql((ROOT/'supabase/sql-editor/01_install_all_six.sql').read_text(encoding='utf-8'))
            sql((ROOT/'supabase/sql-editor/02_verify_installation.sql').read_text(encoding='utf-8'))
            migrations=[p.name for p in sorted((ROOT/'supabase/migrations').glob('*.sql'))]
            try:
                sql((ROOT/'supabase/sql-editor/01_install_all_six.sql').read_text(encoding='utf-8'))
            except RuntimeError as error:
                if 'app_private already exists' not in str(error): raise
                print('PASS: repeat installation rejected without overwriting existing schema',flush=True)
            else: raise AssertionError('Repeat installer should refuse existing schema')
            sql((ROOT/'supabase/sql-editor/05_install_media_service.sql').read_text(encoding='utf-8'))
            sql((ROOT/'supabase/sql-editor/06_install_daily_product_editor.sql').read_text(encoding='utf-8'))
            print('Applied atomic SQL Editor bundle and postflight',flush=True)
        else:
            for file in sorted((ROOT/'supabase/migrations').glob('*.sql')):
                if args.commerce_installer and file.name.split('_')[0]>'202610130015': continue
                if args.admin_exact_search_installer and file.name.split('_')[0]>'202610120014': continue
                if args.commerce_installer and file.name.startswith('202610130015'):
                    sql('create table app_private.sql_editor_receipts(version text primary key,filename text not null,sha256 text not null,applied_at timestamptz not null default now());')
                    for base in sorted((ROOT/'supabase/migrations').glob('*.sql')):
                        if base.name.split('_')[0]<'202610130015': sql("insert into app_private.sql_editor_receipts values('"+base.name.split('_')[0]+"','"+base.name+"','"+hashlib.sha256(base.read_bytes()).hexdigest()+"',now());")
                    sql("insert into public.products(name,description) values('Preserved commerce installer fixture','Existing copy');")
                    def commerce_snapshot():
                        tables=json.loads(sql("select json_agg(table_name) from information_schema.tables where table_schema='public' and table_type='BASE TABLE';"))
                        parts=["select '"+t+"' as table_name,md5(coalesce(string_agg(row_to_json(x)::text,'' order by row_to_json(x)::text),'')) as hash from public."+t+' x' for t in tables]
                        return json.loads(sql("select json_object_agg(table_name,hash) from ("+' union all '.join(parts)+") snapshots;"))
                    before=commerce_snapshot();commerce_file=ROOT/'supabase/sql-editor/13_install_guest_commerce_clean.sql';commerce_hash=hashlib.sha256(commerce_file.read_bytes()).hexdigest()
                    preflight=ROOT/'supabase/sql-editor/13_preflight_guest_commerce.sql'
                    pre=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-At','-f',preflight).strip()
                    assert pre.split('|')==['t']+['f']*7+['t','f','f'],pre
                    out=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',commerce_file)
                    post=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-At','-f',preflight).strip()
                    assert post.split('|')==['t']*11,post
                    assert commerce_snapshot()==before and hashlib.sha256(commerce_file.read_bytes()).hexdigest()==commerce_hash
                    try: command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',commerce_file)
                    except RuntimeError as error: assert 'already or partly installed' in str(error)
                    else: raise AssertionError('Repeat installer must refuse existing state')
                    assert commerce_snapshot()==before
                    (run_dir/'commerce-installer-output.txt').write_text(out,encoding='utf-8')
                    print('PASS: exact commerce installer on fresh 001-014; 11 flags, preserved rows, unchanged file hash, repeat refusal',flush=True)
                    migrations.append(file.name);continue
                if args.admin_list_installer and file.name.split('_')[0]>'202610090013': continue
                if args.admin_exact_search_installer and file.name.startswith('202610120014'):
                    sql('create table app_private.sql_editor_receipts(version text primary key,filename text not null,sha256 text not null,applied_at timestamptz not null default now());')
                    for base in sorted((ROOT/'supabase/migrations').glob('*.sql')):
                        if base.name.split('_')[0]<'202610120014': sql("insert into app_private.sql_editor_receipts values('"+base.name.split('_')[0]+"','"+base.name+"','"+hashlib.sha256(base.read_bytes()).hexdigest()+"',now());")
                    sql("insert into public.products(name,description,usage,key_benefits) values('Preserved exact search installer fixture','Existing description','Existing usage','Existing benefits');")
                    def exact_snapshot():
                        tables=json.loads(sql("select json_agg(table_name) from information_schema.tables where table_schema='public' and table_type='BASE TABLE';"))
                        parts=["select '"+t+"' as table_name,md5(coalesce(string_agg(row_to_json(x)::text,'' order by row_to_json(x)::text),'')) as hash from public."+t+' x' for t in tables]
                        return json.loads(sql("select json_object_agg(table_name,hash) from ("+' union all '.join(parts)+") snapshots;"))
                    before=exact_snapshot()
                    exact_file=ROOT/'supabase/sql-editor/12_install_admin_exact_search_clean.sql'
                    exact_hash=hashlib.sha256(exact_file.read_bytes()).hexdigest()
                    exact_preflight=ROOT/'supabase/sql-editor/12_preflight_admin_exact_search.sql'
                    pre=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-At','-f',exact_preflight).strip()
                    assert pre.split('|')==['t','t','f','f','f','t','t','t','t'],pre
                    out=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',exact_file)
                    post=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-At','-f',exact_preflight).strip()
                    assert post.split('|')==['t']*9,post
                    assert exact_snapshot()==before
                    assert hashlib.sha256(exact_file.read_bytes()).hexdigest()==exact_hash
                    try: command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',exact_file)
                    except RuntimeError as error: assert 'already or partly installed' in str(error)
                    else: raise AssertionError('Repeat installer must be rejected')
                    assert exact_snapshot()==before
                    (run_dir/'exact-search-installer-output.txt').write_text(out,encoding='utf-8')
                    print('PASS: exact 014 installer on fresh 001-013; unchanged business rows, matching file hash, nine final flags, repeat refusal',flush=True)
                    migrations.append(file.name);continue
                if args.admin_list_installer and file.name.startswith('202610090013'):
                    sql('create table app_private.sql_editor_receipts(version text primary key,filename text not null,sha256 text not null,applied_at timestamptz not null default now());')
                    for base in sorted((ROOT/'supabase/migrations').glob('*.sql')):
                        if base.name.split('_')[0]<'202610090013': sql("insert into app_private.sql_editor_receipts values('"+base.name.split('_')[0]+"','"+base.name+"','"+hashlib.sha256(base.read_bytes()).hexdigest()+"',now());")
                    sql("insert into public.products(name,description,usage,key_benefits) values('Preserved installer fixture','Original description','Original usage','Original benefits');")
                    def admin_snapshot():
                        tables=json.loads(sql("select json_agg(table_name) from information_schema.tables where table_schema='public' and table_type='BASE TABLE';"))
                        parts=["select '"+t+"' as table_name,md5(coalesce(string_agg(row_to_json(x)::text,'' order by row_to_json(x)::text),'')) as hash from public."+t+' x' for t in tables]
                        return json.loads(sql("select json_object_agg(table_name,hash) from ("+' union all '.join(parts)+") snapshots;"))
                    before=admin_snapshot()
                    admin_file=ROOT/'supabase/sql-editor/11_install_admin_catalog_list_clean.sql'
                    admin_hash=hashlib.sha256(admin_file.read_bytes()).hexdigest()
                    admin_preflight=ROOT/'supabase/sql-editor/11_preflight_admin_catalog_list.sql'
                    preflight_before=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-At','-f',admin_preflight).strip()
                    (run_dir/'admin-list-preflight-before.txt').write_text(preflight_before,encoding='utf-8')
                    assert preflight_before.split('|')==['t']+['f']*15+['','t','f'],preflight_before
                    output=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',admin_file)
                    preflight_after=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-At','-f',admin_preflight).strip()
                    assert preflight_after.split('|')==['t']*19,preflight_after
                    (run_dir/'admin-list-preflight-after.txt').write_text(preflight_after,encoding='utf-8')
                    assert admin_snapshot()==before
                    assert admin_hash==hashlib.sha256(admin_file.read_bytes()).hexdigest()
                    (run_dir/'admin-list-exact-output.txt').write_text(output,encoding='utf-8')
                    try: command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',admin_file)
                    except RuntimeError as error: assert 'already or partly installed' in str(error)
                    else: raise AssertionError('Repeated installer must refuse existing state')
                    print('PASS: exact admin-list installer preserves business rows and refuses repeat',flush=True)
                    migrations.append(file.name)
                    continue
                if args.storefront_installer and file.name.split('_')[0]>'202610070009': continue
                if args.content_installer and file.name.split('_')[0]>'202610070010': continue
                if args.reviews_installer and file.name.split('_')[0]>'202610070011': continue
                if args.product_markdown_installer and file.name.startswith('202610080012'):
                    sql('create table app_private.sql_editor_receipts(version text primary key,filename text not null,sha256 text not null,applied_at timestamptz not null default now());')
                    for base in sorted((ROOT/'supabase/migrations').glob('*.sql')):
                        if base.name.split('_')[0]<'202610080012': sql("insert into app_private.sql_editor_receipts values('"+base.name.split('_')[0]+"','"+base.name+"','"+hashlib.sha256(base.read_bytes()).hexdigest()+"',now());")
                    sql("insert into public.products(id,name,description,usage) values('77777777-0000-4000-8000-000000000001','Existing copy','Original **description**\nline two','Original usage â€” do not rewrite');")
                    originals=json.loads(sql("select json_agg(x) from (select table_name,string_agg(quote_ident(column_name),',' order by ordinal_position) columns from information_schema.columns where table_schema='public' group by table_name) x;"))
                    def content_snapshot():
                        return {t['table_name']:sql('select md5(coalesce(string_agg(row_to_json(x)::text,\'\' order by row_to_json(x)::text),\'\')) from (select '+t['columns']+' from public.'+t['table_name']+') x;').strip() for t in originals}
                    before=content_snapshot()
                    markdown_file=ROOT/'supabase/sql-editor/10_install_product_markdown_clean.sql'
                    markdown_hash=hashlib.sha256(markdown_file.read_bytes()).hexdigest()
                    output=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',markdown_file)
                    assert markdown_hash==hashlib.sha256(markdown_file.read_bytes()).hexdigest()
                    assert content_snapshot()==before
                    assert 't | t | t | t | t | t | t | t' in output.replace('  ',' ') or sql("select exists(select 1 from app_private.sql_editor_receipts where version='202610080012') and (select relrowsecurity from pg_class where oid='public.products'::regclass);").strip()=='t'
                    try: command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',markdown_file)
                    except RuntimeError as error: assert 'already or partly installed' in str(error)
                    else: raise AssertionError('Repeated installer should refuse existing state')
                    assert content_snapshot()==before
                    (run_dir/'markdown-exact-installer-output.txt').write_text(output,encoding='utf-8')
                    sql("delete from public.products where id='77777777-0000-4000-8000-000000000001';")
                    migrations.append(file.name);continue
                if args.reviews_installer and file.name.startswith('202610070011'):
                    sql('create table app_private.sql_editor_receipts(version text primary key,filename text not null,sha256 text not null,applied_at timestamptz not null default now());')
                    for base in sorted((ROOT/'supabase/migrations').glob('*.sql')):
                        if base.name.split('_')[0]<'202610070011': sql("insert into app_private.sql_editor_receipts values('"+base.name.split('_')[0]+"','"+base.name+"','"+hashlib.sha256(base.read_bytes()).hexdigest()+"',now());")
                    sql("insert into public.products(id,name) values('66666666-0000-4000-8000-000000000001','Pre-existing synthetic draft');insert into public.reviews(id,product_id,display_name,rating,body) values('66666666-0000-4000-8000-000000000002','66666666-0000-4000-8000-000000000001','Prior reviewer',4,'Pre-existing synthetic review');insert into public.review_private(review_id,moderation_note) values('66666666-0000-4000-8000-000000000002','Preserve private history');")
                    originals=json.loads(sql("select json_agg(x) from (select table_name,string_agg(quote_ident(column_name),',' order by ordinal_position) columns from information_schema.columns where table_schema='public' group by table_name) x;"))
                    def review_snapshot():
                        return {table['table_name']:sql('select md5(coalesce(string_agg(row_to_json(x)::text,\'\' order by row_to_json(x)::text),\'\')) from (select '+table['columns']+' from public.'+table['table_name']+') x;').strip() for table in originals}
                    review_before=review_snapshot()
                    preflight=ROOT/'supabase/sql-editor/09_preflight_customer_reviews.sql'
                    assert command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-At','-f',preflight).strip()=='t|t|f|f|f|f|'
                    reviews_file=ROOT/'supabase/sql-editor/09_install_customer_reviews_clean.sql'
                    reviews_hash=hashlib.sha256(reviews_file.read_bytes()).hexdigest()
                    output=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',reviews_file)
                    (run_dir/'reviews-exact-installer-output.txt').write_text(output,encoding='utf-8')
                    assert hashlib.sha256(reviews_file.read_bytes()).hexdigest()==reviews_hash
                    assert review_snapshot()==review_before
                    assert command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-At','-f',preflight).strip()=='t|t|t|t|t|t|t'
                    try: command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',reviews_file)
                    except RuntimeError as error: assert 'Reviews already or partly installed' in str(error)
                    else: raise AssertionError('Repeated installer must be rejected')
                    assert review_snapshot()==review_before
                    sql("delete from public.review_private where review_id='66666666-0000-4000-8000-000000000002';delete from public.reviews where id='66666666-0000-4000-8000-000000000002';delete from public.products where id='66666666-0000-4000-8000-000000000001';")
                    migrations.append(file.name);continue
                if args.content_installer and file.name.startswith('202610070010'):
                    sql('create table app_private.sql_editor_receipts(version text primary key,filename text not null,sha256 text not null,applied_at timestamptz not null default now());')
                    for base in sorted((ROOT/'supabase/migrations').glob('*.sql')):
                        if base.name.split('_')[0]<'202610070010': sql("insert into app_private.sql_editor_receipts values('"+base.name.split('_')[0]+"','"+base.name+"','"+hashlib.sha256(base.read_bytes()).hexdigest()+"',now());")
                    content_file=ROOT/'supabase/sql-editor/08_install_content_cms_clean.sql'
                    content_hash=hashlib.sha256(content_file.read_bytes()).hexdigest()
                    output=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',content_file)
                    (run_dir/'content-exact-installer-output.txt').write_text(output,encoding='utf-8')
                    assert sql("select to_regprocedure('public.storefront_articles(text,boolean,integer,integer)') is not null and (select relrowsecurity from pg_class where oid='public.homepage_media'::regclass);").strip()=='t'
                    migrations.append(file.name);continue
                if args.storefront_installer and file.name.startswith('202610070009'):
                    sql('create table app_private.sql_editor_receipts(version text primary key,filename text not null,sha256 text not null,applied_at timestamptz not null default now());')
                    exact=(ROOT/args.storefront_file).resolve()
                    assert exact.is_relative_to(ROOT/'supabase/sql-editor')
                    exact_hash=hashlib.sha256(exact.read_bytes()).hexdigest()
                    assert (ROOT/'supabase/sql-editor/07_install_public_storefront.sql').read_bytes()==exact.read_bytes()
                    preflight=ROOT/'supabase/sql-editor/07_preflight_public_storefront.sql'
                    preflight_before=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-At','-f',preflight)
                    assert preflight_before.startswith('t|f|f|f|f|f|f|f|f|f|')
                    (run_dir/'storefront-preflight-before.txt').write_text(preflight_before,encoding='utf-8')
                    tables=json.loads(sql("select json_agg(tablename order by tablename) from pg_tables where schemaname='public';"))
                    def business_snapshot():
                        return {table:sql('select md5(coalesce(string_agg(to_jsonb(x)::text,\'\' order by to_jsonb(x)::text),\'\')) from public."'+table+'" x;').strip() for table in tables}
                    before=business_snapshot()
                    output=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',exact)
                    assert hashlib.sha256(exact.read_bytes()).hexdigest()==exact_hash
                    assert sql("select to_regprocedure('public.storefront_navigation()') is not null and (select relrowsecurity from pg_class where oid='public.catalog_search_aliases'::regclass) and (select relrowsecurity from pg_class where oid='app_private.storefront_search'::regclass);").strip()=='t'
                    assert sql("select sha256 from app_private.sql_editor_receipts where version='202610070009';").strip()==hashlib.sha256(file.read_bytes()).hexdigest()
                    assert business_snapshot()==before
                    preflight_after=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-At','-f',preflight)
                    assert preflight_after.startswith('t|t|t|t|t|t|t|t|t|t|')
                    (run_dir/'storefront-preflight-after.txt').write_text(preflight_after,encoding='utf-8')
                    verification=ROOT/'supabase/sql-editor/07_verify_installed_storefront.sql'
                    if verification.exists():
                        verification_output=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-At','-f',verification)
                        fields=verification_output.strip().split('|')
                        assert len(fields)==11 and fields[0]=='t' and fields[2]=='t' and fields[3]=='[]' and fields[4:]==['t','t','t','0','t','t','t']
                        assert json.loads(fields[1])['sha256']==hashlib.sha256(file.read_bytes()).hexdigest()
                        (run_dir/'storefront-installed-verification.txt').write_text(verification_output,encoding='utf-8')
                        print('PASS: single read-only installed-state query; canonical receipt and all expected objects/permissions',flush=True)
                    try: command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',exact)
                    except RuntimeError as error: assert 'Storefront objects or receipt already exist' in str(error)
                    else: raise AssertionError('Repeat storefront installer must refuse installed objects/receipt')
                    assert business_snapshot()==before
                    (run_dir/'storefront-exact-installer-output.txt').write_text(output,encoding='utf-8')
                    print('PASS: exact public storefront installer executed against 001-008',flush=True)
                    migrations.append(file.name)
                    continue
                sql('begin;\n'+file.read_text(encoding='utf-8')+'\ncommit;');migrations.append(file.name)
                print('Applied',file.name,flush=True)
        sql("insert into auth.users values('00000000-0000-0000-0000-000000000001'),('00000000-0000-0000-0000-000000000002') on conflict do nothing; insert into app_private.admin_members(user_id,reason) values('00000000-0000-0000-0000-000000000001','Disposable test only') on conflict do nothing;")
        if args.deals_installer:
            print(sql((ROOT/'supabase/tests/deals.sql').read_text(encoding='utf-8')),flush=True)
            print(sql((ROOT/'supabase/tests/manual-payments.sql').read_text(encoding='utf-8')),flush=True)
            sql((ROOT/'supabase/tests/deals-race-setup.sql').read_text(encoding='utf-8'))
            from concurrent.futures import ThreadPoolExecutor
            def place_deal_race(oid,deal=None):
                lines=json.dumps([{'id':deal or '15151515-0000-4000-8000-000000000002','quantity':1,'expectedPriceMinor':90000 if deal else 100000,**({'kind':'deal','expectedDealRevision':3} if deal else {})}])
                return "select public.place_guest_order('"+oid+"',repeat('a',64),repeat('b',64),'"+lines+"','{\"name\":\"Synthetic race\",\"phone\":\"+923001234567\",\"address\":\"Synthetic race address\",\"city\":\"Test City\"}','{\"id\":\"test\",\"label\":\"Synthetic\",\"feeMinor\":0}','{\"id\":\"bank-transfer\",\"label\":\"Synthetic\",\"allocation\":\"temporary\",\"accountTitle\":\"Synthetic\",\"destination\":\"TEST-ONLY\",\"accountScope\":\"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc\"}','{\"mode\":\"development\",\"version\":\"synthetic-deal-race\",\"paymentSeconds\":60,\"reviewExtensionSeconds\":30}');"
            def compete(request):
                try: sql(request);return 'placed'
                except RuntimeError as error:
                    if 'Availability changed' not in str(error) and 'Insufficient shared stock' not in str(error): raise
                    return 'rejected'
            for round_number in [1,2]:
                ids=['17171717-0000-4000-8000-0000000002'+str(round_number)+str(n) for n in [1,2]]
                requests=[place_deal_race(ids[0],None if round_number==1 else '17171717-0000-4000-8000-000000000101'),place_deal_race(ids[1],'17171717-0000-4000-8000-000000000102')]
                with ThreadPoolExecutor(max_workers=2) as pool: outcomes=list(pool.map(compete,requests))
                assert sorted(outcomes)==['placed','rejected'],outcomes
                assert sql("select on_hand=1 and reserved=1 from public.inventory_balances where variant_id='15151515-0000-4000-8000-000000000002';").strip()=='t'
                for oid in ids:
                    sql("set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';select public.admin_order_action(order_id,revision,'cancel',gen_random_uuid()) from app_private.commerce_orders where order_id='"+oid+"' and fulfilment in('placed','confirmed');")
            print('PASS: independent PostgreSQL sessions: individual versus deal and two deals compete for last shared unit',flush=True)
            sql("set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';select public.adjust_inventory('15151515-0000-4000-8000-000000000002',1,'Synthetic late race','deal-late-race-count');")
            late_ids=['17171717-0000-4000-8000-00000000030'+str(n) for n in [1,2]]
            for n,oid in enumerate(late_ids): sql(place_deal_race(oid,'17171717-0000-4000-8000-00000000010'+str(n+1)))
            sql("begin;update app_private.commerce_orders set hold_expires_at=now()-interval '1 second' where order_id in('"+"','".join(late_ids)+"');update public.inventory_reservations set expires_at=now()-interval '1 second' where order_id in('"+"','".join(late_ids)+"');select public.expire_commerce_holds();set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';select public.adjust_inventory('15151515-0000-4000-8000-000000000002',-1,'Synthetic late shortage','deal-late-shortage');commit;")
            def late(oid): return sql("set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';select public.review_manual_payment('"+oid+"',2,'verify',gen_random_uuid(),jsonb_build_object('checkedHistory',true,'amountMinor',90000,'reference','SYNTHETIC-'||'"+oid+"','reacquire',true))->>'paymentStatus';").strip().splitlines()[-1]
            with ThreadPoolExecutor(max_workers=2) as pool: outcomes=list(pool.map(late,late_ids))
            assert sorted(outcomes)==['paid','received_resolution_required'],outcomes
            assert sql("select count(*) from app_private.payment_receipts where order_id in('"+"','".join(late_ids)+"');").strip()=='2'
            for oid in late_ids: sql("set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';select public.admin_order_action(order_id,revision,'cancel',gen_random_uuid()) from app_private.commerce_orders where order_id='"+oid+"' and fulfilment in('placed','confirmed');")
            assert sql("select reserved=0 from public.inventory_balances where variant_id='15151515-0000-4000-8000-000000000002';").strip()=='t'
            print('PASS: concurrent late deal receipts: one allocation, both funds retained; test reservations released',flush=True)
            rows=json.loads(sql("select json_agg(x) from (select table_name,column_name,udt_name,is_nullable,column_default,is_identity from information_schema.columns where table_schema='public' order by table_name,ordinal_position) x;"))
            enums=json.loads(sql("select json_agg(x) from (select t.typname,array_agg(e.enumlabel order by e.enumsortorder) labels from pg_type t join pg_enum e on e.enumtypid=t.oid join pg_namespace n on n.oid=t.typnamespace where n.nspname='public' group by t.typname) x;"))
            from generate_database_types import generate
            generate(rows,enums)
            (ROOT/'docs/deals-local-verification.json').write_text(json.dumps({'kind':'disposable PostgreSQL; Auth/Storage/media doubles','status':'passed','exact_file':installer.relative_to(ROOT).as_posix(),'installer_sha256':exact_hash,'base_migrations':migrations,'existing_values_preserved':True,'repeat_refused':True,'fifteen_flags':True,'sql_regressions':'passed','concurrency':'individual versus deal, two deals, late payment stock race; independent PG sessions','manual_payment_regressions':'passed against 017','cleanup':'all race reservations released; disposable cluster stopped','hosted':'pending incremental 017 application','evidence':run_dir.name},indent=2)+'\n',encoding='utf-8')
            return
        if args.manual_payments_installer:
            print(sql((ROOT/'supabase/tests/manual-payments.sql').read_text(encoding='utf-8')),flush=True)
            sql((ROOT/'supabase/tests/manual-payments-race-setup.sql').read_text(encoding='utf-8'))
            from concurrent.futures import ThreadPoolExecutor
            def late(index):
                oid='16161616-0000-4000-8000-00000000010'+str(index)
                request="set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';select public.review_manual_payment('"+oid+"',2,'verify',gen_random_uuid(),jsonb_build_object('checkedHistory',true,'amountMinor',100000,'reference','LATE-RACE-"+str(index)+"','reacquire',true))->>'paymentStatus';"
                return sql(request).strip().splitlines()[-1]
            with ThreadPoolExecutor(max_workers=2) as pool: outcomes=list(pool.map(late,[1,2]))
            assert sorted(outcomes)==['paid','received_resolution_required'],outcomes
            assert sql("select on_hand=1 and reserved=1 from public.inventory_balances where variant_id='15151515-0000-4000-8000-000000000002';").strip()=='t'
            assert sql('select count(*) from app_private.payment_receipts;').strip()=='2'
            print('PASS: two concurrent late receipts; one last-unit allocation, both accurate receipts retained',flush=True)
            def shared_reference(index):
                oid='16161616-0000-4000-8000-00000000010'+str(index)
                request="set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001';select public.review_manual_payment('"+oid+"',(select revision from app_private.commerce_orders where order_id='"+oid+"'),'verify',gen_random_uuid(),'{\"checkedHistory\":true,\"amountMinor\":1,\"reference\":\"SHARED-RACE\"}');"
                return sql(request)
            with ThreadPoolExecutor(max_workers=2) as pool: list(pool.map(shared_reference,[1,2]))
            assert sql("select count(*) from app_private.payment_receipts where reference_key='SHAREDRACE';").strip()=='1'
            print('PASS: concurrent duplicate-reference verification credits exactly one transfer',flush=True)

            rows=json.loads(sql("select json_agg(x) from (select table_name,column_name,udt_name,is_nullable,column_default,is_identity from information_schema.columns where table_schema='public' order by table_name,ordinal_position) x;"))
            enums=json.loads(sql("select json_agg(x) from (select t.typname,array_agg(e.enumlabel order by e.enumsortorder) labels from pg_type t join pg_enum e on e.enumtypid=t.oid join pg_namespace n on n.oid=t.typnamespace where n.nspname='public' group by t.typname) x;"))
            from generate_database_types import generate
            generate(rows,enums)
            (ROOT/'docs/manual-payments-local-verification.json').write_text(json.dumps({'kind':'disposable PostgreSQL; Auth/Storage doubles','exact_file':installer.relative_to(ROOT).as_posix(),'sha256':exact_hash,'base_migrations':migrations,'all_existing_rows_unchanged':True,'repeat_refused':True,'fourteen_final_flags':True,'sql_regressions':'passed','concurrent_late_stock_race':'passed; two independent PostgreSQL sessions','concurrent_duplicate_reference':'passed; one transfer credited once','seeded_legacy_order_catalog_inventory_preservation':True,'generated_public_types':True,'hosted':'pending 016 application','evidence':run_dir.name},indent=2)+'\n',encoding='utf-8')
            return
        if args.commerce_installer:
            print(sql((ROOT/'supabase/tests/commerce.sql').read_text(encoding='utf-8')),flush=True)
            sql((ROOT/'supabase/tests/commerce-concurrency-setup.sql').read_text(encoding='utf-8'))
            from concurrent.futures import ThreadPoolExecutor
            def competing(index):
                request=(ROOT/'supabase/tests/commerce-concurrency-request.sql').read_text(encoding='utf-8').replace('ORDER_ID','15151515-0000-4000-8000-00000000010'+str(index))
                try: sql(request);return 'placed'
                except RuntimeError as error:
                    if 'Insufficient stock' not in str(error) and 'Availability changed' not in str(error): raise
                    return 'rejected'
            with ThreadPoolExecutor(max_workers=2) as pool: outcomes=list(pool.map(competing,[1,2]))
            assert sorted(outcomes)==['placed','rejected'],outcomes
            assert sql("select on_hand=1 and reserved=1 from public.inventory_balances where variant_id='15151515-0000-4000-8000-000000000002';").strip()=='t'
            assert sql("select count(*) from public.orders where id in('15151515-0000-4000-8000-000000000101','15151515-0000-4000-8000-000000000102');").strip()=='1'
            print('PASS: two real PostgreSQL sessions compete for last unit; exactly one order/reservation commits',flush=True)
            (ROOT/'docs/commerce-local-verification.json').write_text(json.dumps({'kind':'disposable_PostgreSQL_Auth_Storage_and_media_doubles','status':'passed','exact_file':commerce_file.relative_to(ROOT).as_posix(),'sha256':commerce_hash,'base_migrations':migrations[:-1],'execution':'psql -X -v ON_ERROR_STOP=1 -f','all_pre_existing_business_rows_unchanged':True,'repeat_refusal':'passed','eleven_final_flags':True,'transactional_lifecycle_security':'passed','concurrent_last_unit_two_sessions':'passed','hosted':'pending 015 application','evidence':run_dir.name},indent=2)+'\n',encoding='utf-8')
            return
        payload=json.loads((ROOT/'data/catalog-dry-run/database-payload.json').read_text(encoding='utf-8'))
        def literal(v): return "'"+str(v).replace("'","''")+"'"
        args_sql=','.join(literal(payload[k]) for k in ['p_source_hash','p_contract_hash','p_version'])+','+literal(json.dumps(payload['p_records'],ensure_ascii=False))+'::jsonb'
        import_sql="set role authenticated; set request.jwt.claim.sub='00000000-0000-0000-0000-000000000001'; select public.import_catalog_drafts("+args_sql+"); reset role;"
        first=sql(import_sql); second=sql(import_sql)
        (run_dir/'imports.txt').write_text(first+second,encoding='utf-8')
        print(first.strip(),second.strip(),flush=True)
        if args.daily_editor_installer:
            # Snapshot every pre-existing public business table and admin membership.
            tables=json.loads(sql("select json_agg(tablename order by tablename) from pg_tables where schemaname='public';"))
            def snapshot():
                result={}
                for table in tables:
                    assert table.replace('_','').isalnum()
                    result[table]=sql('select md5(coalesce(string_agg(to_jsonb(x)::text,\'\' order by to_jsonb(x)::text),\'\')) from public."'+table+'" x;').strip()
                result['admin_members']=sql("select md5(coalesce(string_agg(to_jsonb(x)::text,'' order by to_jsonb(x)::text),'')) from app_private.admin_members x;").strip()
                return result
            before=snapshot()
            original_defs=sql("select md5(pg_get_functiondef('public.publication_report(uuid)'::regprocedure)||pg_get_functiondef('app_private.publication_blockers(uuid)'::regprocedure));").strip()
            installer=(ROOT/args.daily_editor_file).resolve()
            assert installer.is_relative_to(ROOT/'supabase/sql-editor')
            raw=installer.read_bytes(); exact_hash=hashlib.sha256(raw).hexdigest()
            # Simulate a missing preceding delimiter in a separate test copy.
            broken=run_dir/'intentional-missing-terminator.sql'
            broken.write_bytes(raw.replace(b'$publication_report$;',b'',1))
            try: command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',broken)
            except RuntimeError: pass
            else: raise AssertionError('Intentional malformed terminator must fail')
            assert snapshot()==before
            assert sql("select to_regclass('public.inventory_counts') is null and to_regclass('app_private.product_save_requests') is null and to_regprocedure('app_private.daily_product_issues(uuid)') is null and to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,text)') is null and not exists(select 1 from app_private.sql_editor_receipts where version='202610060008');").strip()=='t'
            assert sql("select md5(pg_get_functiondef('public.publication_report(uuid)'::regprocedure)||pg_get_functiondef('app_private.publication_blockers(uuid)'::regprocedure));").strip()==original_defs
            print('PASS: deliberate terminator failure rolled back objects, function replacements and business data',flush=True)
            preflight=ROOT/'supabase/sql-editor/06_preflight_daily_product_editor.sql'
            preflight_before=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-At','-f',preflight)
            assert 't|f|f|f|f|f|f|f|f' in preflight_before
            output=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',installer)
            assert hashlib.sha256(installer.read_bytes()).hexdigest()==exact_hash
            assert snapshot()==before
            assert sql("select count(*) from app_private.sql_editor_receipts;").strip()=='8'
            assert sql("select to_regprocedure('public.save_daily_product(uuid,integer,jsonb,uuid,text)') is not null and (select relrowsecurity from pg_class where oid='public.inventory_counts'::regclass);").strip()=='t'
            print('PASS: exact SQL Editor file executed with psql -f; all existing business table snapshots preserved',flush=True)
            installed=snapshot()
            try: command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-f',installer)
            except RuntimeError as error:
                assert 'Daily editor objects already exist' in str(error)
            else: raise AssertionError('Repeat exact installer must refuse existing state')
            assert snapshot()==installed
            preflight_after=command('psql','-X','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',args.port,'-U','postgres','-d','postgres','-At','-f',preflight)
            assert 't|t|t|t|t|f|t|t|t' in preflight_after
            (run_dir/'exact-installer-output.txt').write_text(output,encoding='utf-8')
            (run_dir/'preflight-before.txt').write_text(preflight_before,encoding='utf-8')
            (run_dir/'preflight-after.txt').write_text(preflight_after,encoding='utf-8')
            installer_report={'status':'passed','base_migrations':migrations.copy(),'earlier_installers_executed':False,'exact_file':installer.relative_to(ROOT).as_posix(),'sha256':exact_hash,'execution':'psql -X -v ON_ERROR_STOP=1 -f exact_file','seeded_source_products':121,'all_pre_existing_business_tables_unchanged':True,'syntax_failure_rollback':'passed','repeat_install_refusal':'passed','local_evidence':run_dir.name,'auth_and_storage':'test doubles; not hosted Supabase verification'}
            migrations.append('202610060008_daily_product_editor.sql')
        tests=sql((ROOT/'supabase/tests/database.sql').read_text(encoding='utf-8'))
        print(tests,flush=True)
        media_tests=sql((ROOT/'supabase/tests/media.sql').read_text(encoding='utf-8'))
        print('MEDIA SQL TESTS PASSED' if 'MEDIA SQL TESTS PASSED' in media_tests else media_tests,flush=True)
        if (ROOT/'supabase/tests/daily-editor.sql').exists():
            print(sql((ROOT/'supabase/tests/daily-editor.sql').read_text(encoding='utf-8')),flush=True)
        if '202610070009_public_storefront.sql' in migrations:
            print(sql((ROOT/'supabase/tests/storefront.sql').read_text(encoding='utf-8')),flush=True)
        if '202610070010_content_cms.sql' in migrations:
            print(sql((ROOT/'supabase/tests/content.sql').read_text(encoding='utf-8')),flush=True)
        if '202610070011_customer_reviews.sql' in migrations:
            print(sql((ROOT/'supabase/tests/reviews.sql').read_text(encoding='utf-8')),flush=True)
        if args.product_markdown_installer:
            print(sql((ROOT/'supabase/tests/product-markdown.sql').read_text(encoding='utf-8')),flush=True)
        if args.admin_exact_search_installer:
            print(sql((ROOT/'supabase/tests/admin-exact-search.sql').read_text(encoding='utf-8')),flush=True)
            print(sql((ROOT/'supabase/tests/admin-list.sql').read_text(encoding='utf-8')),flush=True)
            print(sql((ROOT/'supabase/tests/admin-list-freshness.sql').read_text(encoding='utf-8')),flush=True)
            (ROOT/'docs/admin-exact-search-local-verification.json').write_text(json.dumps({'kind':'disposable_PostgreSQL_Auth_Storage_doubles','exact_file':exact_file.relative_to(ROOT).as_posix(),'installer_sha256':exact_hash,'base_migrations':migrations[:-1],'execution':'psql -X -v ON_ERROR_STOP=1 -f','preflight_postflight':'passed','business_rows_unchanged':True,'repeat_refusal':'passed','exact_search_and_existing_admin_regressions':'passed','hosted':'pending incremental 014 application','evidence':run_dir.name},indent=2)+'\n',encoding='utf-8')
        if args.admin_list_installer:
            print(sql((ROOT/'supabase/tests/admin-list.sql').read_text(encoding='utf-8')),flush=True)
            print(sql((ROOT/'supabase/tests/admin-list-freshness.sql').read_text(encoding='utf-8')),flush=True)
            (ROOT/'docs/admin-list-database-verification.json').write_text(json.dumps({'kind':'disposable_PostgreSQL_with_Auth_Storage_doubles','exact_file':admin_file.relative_to(ROOT).as_posix(),'exact_sha256':admin_hash,'all_pre_existing_business_rows_unchanged':True,'repeat_install_refusal':'passed','permissions_search_filters_reminders':'passed','targeted_freshness_regressions':'passed','targeted_freshness_assertions':(run_dir/'assertions.txt').read_text(encoding='utf-8').count('NOTICE:  PASS:'),'preflight_postflight':'passed','canonical_sha256':hashlib.sha256((ROOT/'supabase/migrations/202610090013_admin_catalog_list.sql').read_bytes()).hexdigest(),'execution':'psql -X -v ON_ERROR_STOP=1 -f','evidence':run_dir.name,'hosted':'not verified by this local test'},indent=2)+'\n',encoding='utf-8')
        if installer_report:
            installer_report['catalog_security_media_and_daily_editor_regressions']='passed'
            (ROOT/'docs/daily-editor-exact-installer-verification.json').write_text(json.dumps(installer_report,indent=2)+'\n',encoding='utf-8')
        # Generate row/insert/update definitions directly from the applied DB catalog.
        rows=json.loads(sql("select json_agg(x) from (select table_name,column_name,udt_name,is_nullable,column_default,is_identity from information_schema.columns where table_schema='public' order by table_name,ordinal_position) x;"))
        enums=json.loads(sql("select json_agg(x) from (select t.typname,array_agg(e.enumlabel order by e.enumsortorder) labels from pg_type t join pg_enum e on e.enumtypid=t.oid join pg_namespace n on n.oid=t.typnamespace where n.nspname='public' group by t.typname) x;"))
        from generate_database_types import generate
        generate(rows,enums)
        report={'engine':sql('select version();').strip(),'migrations':migrations,'installation_mode':'exact_storefront_file_with_001_008_base' if args.storefront_installer else 'exact_daily_editor_file_with_001_007_base' if args.daily_editor_installer else 'atomic_sql_editor' if args.sql_editor else 'individual_migrations','source_rows':121,'permission_tests':'passed','supabase_auth_service':'not tested; auth.uid test double','supabase_storage_service':'not tested; table/policy test double','network_provider_operations':0,'production_imports':0}
        (ROOT/'docs/database-verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        if args.storefront_installer:
            assert hashlib.sha256(exact.read_bytes()).hexdigest()==exact_hash
            report.update({'exact_file':exact.relative_to(ROOT).as_posix(),'exact_sha256':exact_hash,'migration_receipt_sha256':hashlib.sha256((ROOT/'supabase/migrations/202610070009_public_storefront.sql').read_bytes()).hexdigest(),'evidence':run_dir.name,'execution':'psql -X -v ON_ERROR_STOP=1 -f exact_file','all_pre_existing_business_tables_unchanged':True,'repeat_install_refusal':'passed','read_only_preflight_before_after':'passed','storefront_search_filters_visibility_tests':'passed','installer_final_checks':{'storefront_present':True,'aliases_rls':True,'search_rls':True},'private_search_rls':{'enabled':True,'client_policies':0,'anonymous_direct_access':'denied','nonadmin_direct_access':'denied','temporary_grant_rls_isolation':'passed; grants rolled back','anonymous_and_nonadmin_owner_rpcs':'passed'}})
            (ROOT/'docs/storefront-database-verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        if args.reviews_installer:
            report.update({'installation_mode':'exact_reviews_file_with_001_010_base','exact_file':reviews_file.relative_to(ROOT).as_posix(),'exact_sha256':reviews_hash,'evidence':run_dir.name,'review_permissions_media_moderation_tests':'passed','repeat_install_refusal':'passed','all_pre_existing_business_rows_unchanged':True,'read_only_preflight_before_after':'passed'})
            (ROOT/'docs/reviews-database-verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        if args.product_markdown_installer:
            report.update({'installation_mode':'exact_incremental_012_with_001_011_base','exact_file':markdown_file.relative_to(ROOT).as_posix(),'exact_sha256':markdown_hash,'all_existing_columns_and_rows_unchanged':True,'repeat_install_refusal':'passed','markdown_persistence_and_permissions':'passed','evidence':run_dir.name})
            (ROOT/'docs/product-markdown-database-verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        if args.content_installer:
            assert hashlib.sha256(content_file.read_bytes()).hexdigest()==content_hash
            report.update({'installation_mode':'exact_content_file_with_001_009_base','exact_file':content_file.relative_to(ROOT).as_posix(),'exact_sha256':content_hash,'evidence':run_dir.name,'content_permissions_revision_media_tests':'passed'})
            (ROOT/'docs/content-database-verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    finally:
        if started: command('pg_ctl','-D',data,'-m','fast','-w','stop')
        print('Disposable cluster stopped; local evidence:',run_dir.name,flush=True)

if __name__=='__main__': main()
