/** Read-only API inspection after a failed installer. Never executes an installer/save. */
import {readFile,writeFile} from 'node:fs/promises';
import {parseEnv} from 'node:util';
import {randomUUID} from 'node:crypto';
for(const file of ['.env','.env.local'])try{Object.assign(process.env,parseEnv(await readFile(file,'utf8')));}catch{}
const report={kind:'actual_development_auth_and_read_only_api_inspection',checked_at:new Date().toISOString(),checks:[],private_sql_inspection:'unavailable: no configured SQL connection; API visibility is not a definitive pg_catalog inspection',required_next_step:'Run 06_preflight_daily_product_editor.sql before considering another installer attempt'};
let token;
try{
 if(process.env.MEDIA_ENVIRONMENT!=='development')throw new Error('Development required');
 const base=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
 const headers={apikey:key,'Content-Type':'application/json'};
 const login=await fetch(new URL('/auth/v1/token?grant_type=password',base),{method:'POST',headers,body:JSON.stringify({email:process.env.TEST_ADMIN_EMAIL,password:process.env.TEST_ADMIN_PASSWORD}),signal:AbortSignal.timeout(20000)});
 if(!login.ok)throw new Error('Login failed');token=(await login.json()).access_token;
 async function get(path){const r=await fetch(new URL(path,base),{headers:{...headers,Authorization:`Bearer ${token}`},cache:'no-store',signal:AbortSignal.timeout(20000)});let body;try{body=await r.json();}catch{}return{status:r.status,body};}
 const admin=await get('/rest/v1/rpc/is_admin');if(admin.status!==200||admin.body!==true)throw new Error('Admin required');
 report.checks.push({name:'actual Auth token and active database admin membership',result:'passed'});
 const products=await get('/rest/v1/products?select=id&limit=0');report.checks.push({name:'products endpoint',http_status:products.status});
 const counts=await get('/rest/v1/inventory_counts?select=id&limit=0');report.checks.push({name:'inventory_counts endpoint',http_status:counts.status,provider_code:counts.body?.code??null});
 const detail=await get('/rest/v1/rpc/publication_report?p_product=00000000-0000-0000-0000-000000000000');report.checks.push({name:'publication report version',http_status:detail.status,daily_editor_version:detail.body?.daily_editor_version??null});
 // VOLATILE RPC cannot execute under GET. This only checks route/signature discovery.
 const query=new URLSearchParams({p_product:'00000000-0000-0000-0000-000000000000',p_revision:'1',p_data:'{}',p_key:randomUUID(),p_intent:'save'});
 const save=await get('/rest/v1/rpc/save_daily_product?'+query);report.checks.push({name:'save RPC discovery only (GET; no mutation)',http_status:save.status,provider_code:save.body?.code??null});
 report.result='API inspection completed; SQL preflight still required';
}catch{report.result='API inspection unavailable; credentials/provider details suppressed';process.exitCode=1;}
finally{
 if(token)try{await fetch(new URL('/auth/v1/logout?scope=local',process.env.NEXT_PUBLIC_SUPABASE_URL),{method:'POST',headers:{apikey:process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,Authorization:`Bearer ${token}`},signal:AbortSignal.timeout(10000)});}catch{}
 await writeFile('docs/daily-editor-development-state.json',JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify(report,null,2));
}
