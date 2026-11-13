/** Read-only discovery. No installer, catalog mutation, cache reload or fixtures. */
import {readFile,writeFile} from 'node:fs/promises';
import {parseEnv} from 'node:util';
for(const file of ['.env','.env.local'])try{Object.assign(process.env,parseEnv(await readFile(file,'utf8')));}catch{}
const report={checked_at:new Date().toISOString(),mode:'read_only_hosted_discovery',checks:[],private_installation_state:'unknown',receipt_009:'not verified',mutations:0};
const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
const codes=new Set(['PGRST202','PGRST205','PGRST106','42501']);
async function request(name,path,{token,body,headers={}}={}){
 try{
  const response=await fetch(new URL(path,url),{method:body===undefined?'GET':'POST',headers:{apikey:key,...(token?{Authorization:'Bearer '+token}:{}),...(body===undefined?{}:{'Content-Type':'application/json'}),...headers},body:body===undefined?undefined:JSON.stringify(body),cache:'no-store',redirect:'error',signal:AbortSignal.timeout(15000)});
  const data=await response.json().catch(()=>null);
  report.checks.push({name,http:response.status,...(codes.has(data?.code)?{code:data.code}:{})});
  return {ok:response.ok,data};
 }catch{report.checks.push({name,http:0,connection:'unavailable'});return {ok:false};}
}
if(!url||!key)throw Error('Local public configuration missing; values omitted.');
report.database_connection_configured=Boolean(process.env.SUPABASE_DB_URL||process.env.DATABASE_URL);
await request('anonymous navigation RPC','/rest/v1/rpc/storefront_navigation',{body:{}});
await request('anonymous catalog RPC','/rest/v1/rpc/storefront_catalog',{body:{p_query:'installation-read-only-check',p_size:1}});
if(process.env.TEST_ADMIN_EMAIL&&process.env.TEST_ADMIN_PASSWORD){
 const login=await request('admin Auth login','/auth/v1/token?grant_type=password',{body:{email:process.env.TEST_ADMIN_EMAIL,password:process.env.TEST_ADMIN_PASSWORD}});
 const token=login.data?.access_token;
 if(token){
  const member=await request('admin database membership','/rest/v1/rpc/is_admin',{token,body:{}});
  report.admin_membership_verified=member.ok&&member.data===true;
  await request('admin aliases table discovery','/rest/v1/catalog_search_aliases?select=id&limit=0',{token});
  await request('admin navigation RPC discovery','/rest/v1/rpc/storefront_navigation',{token,body:{}});
  await request('private migration receipt discovery','/rest/v1/sql_editor_receipts?select=version,filename,sha256&version=eq.202610070009',{token,headers:{'Accept-Profile':'app_private'}});
  await request('private search discovery','/rest/v1/storefront_search?select=variant_id&limit=0',{token,headers:{'Accept-Profile':'app_private'}});
 }
}
report.public_rpcs_available=report.checks.filter(c=>['anonymous navigation RPC','anonymous catalog RPC'].includes(c.name)).every(c=>c.http===200);
report.limitations=report.public_rpcs_available?'Public RPCs are available; private receipt/version and full expected-object state remain unverified. Run the single read-only 07_verify_installed_storefront.sql query in development SQL Editor; do not rerun the installer.':'API discovery cannot establish private object/receipt absence. Run 07_preflight_public_storefront.sql in development SQL Editor before any install; never infer rollback from missing RPCs.';
await writeFile('docs/storefront-hosted-preflight.json',JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify(report,null,2));
