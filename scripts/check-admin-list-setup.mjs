// Read-only hosted probe. Never prints credentials, tokens, catalog rows or provider errors.
import {readFile,writeFile} from 'node:fs/promises';
import {parseEnv} from 'node:util';
for(const file of ['.env','.env.local'])try{Object.assign(process.env,parseEnv(await readFile(file,'utf8')));}catch{}
const report={kind:'actual_hosted_read_only',checked_at:new Date().toISOString(),checks:[],pending:[],mutations:0};
try{
 const base=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
 if(!base||!key||!process.env.TEST_ADMIN_EMAIL||!process.env.TEST_ADMIN_PASSWORD)throw Error('setup');
 const login=await fetch(new URL('/auth/v1/token?grant_type=password',base),{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:JSON.stringify({email:process.env.TEST_ADMIN_EMAIL,password:process.env.TEST_ADMIN_PASSWORD}),signal:AbortSignal.timeout(15000)});
 if(!login.ok)throw Error('auth');const auth=await login.json();
 report.checks.push({name:'Actual admin Auth login',result:'passed'});
 const response=await fetch(new URL('/rest/v1/rpc/admin_catalog_list',base),{method:'POST',headers:{apikey:key,Authorization:'Bearer '+auth.access_token,'Content-Type':'application/json'},body:JSON.stringify({p_query:'',p_filters:{},p_offset:0,p_limit:1}),signal:AbortSignal.timeout(15000)});
 report.checks.push({name:'Hosted admin-list RPC available',http:response.status,result:response.ok?'passed':'pending'});
 if(!response.ok)report.pending.push('Confirm migration 013 receipt/objects with the read-only SQL Editor preflight; if installed, inspect exposure/schema cache instead of rerunning.');
 report.status=response.ok?'ready_for_live_fixtures':'hosted_migration_pending';
}catch{report.status='setup_or_network_pending';report.pending.push('Existing local test-admin/project configuration or outbound network needs checking privately.');}
await writeFile('docs/admin-list-hosted-preflight.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report));
