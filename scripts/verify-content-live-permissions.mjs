/** Actual read-only private-file/RLS checks while the tracked CMS fixture exists. */
import {readFile,writeFile} from 'node:fs/promises';import {parseEnv} from 'node:util';
for(const f of ['.env','.env.local'])try{Object.assign(process.env,parseEnv(await readFile(f,'utf8')));}catch{}
if(process.env.MEDIA_ENVIRONMENT!=='development')throw Error('Development configuration required.');
const base=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
const report={kind:'actual_supabase_content_permissions_private_storage',checks:[],status:'running',business_mutations:0};
const check=(name,ok)=>{report.checks.push({name,result:ok?'passed':'failed'});console.log((ok?'PASS: ':'FAIL: ')+name);if(!ok)throw Error('Permission check failed.');};
const request=(path,token,method='GET',body)=>fetch(new URL(path,base),{method,headers:{apikey:key,...(token?{Authorization:'Bearer '+token}:{}),...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(20000)});
async function login(prefix){const r=await request('/auth/v1/token?grant_type=password',null,'POST',{email:process.env[prefix+'_EMAIL'],password:process.env[prefix+'_PASSWORD']});if(!r.ok)throw Error('Local test login unavailable.');return (await r.json()).access_token;}
try{
 const admin=await login('TEST_ADMIN'),user=await login('TEST_USER');check('actual admin and non-admin Auth tokens validated',!!admin&&!!user);
 const source=JSON.parse(await readFile('docs/content-live-verification.json','utf8'));const fixture=source.fixtures.find(f=>f.media.length);if(!fixture)throw Error('Tracked private file not available yet.');const id=fixture.media[0];
 const rowResponse=await request('/rest/v1/media_workflows?media_id=eq.'+id+'&select=private_path,article_id,product_id',admin);if(!rowResponse.ok)throw Error('Admin fixture read unavailable.');const row=(await rowResponse.json())[0];check('article media owner is real article, not product',row.article_id===fixture.id&&row.product_id===null);
 const path='/storage/v1/object/authenticated/catalog-private/'+row.private_path;
 const original=await request(path,admin);check('known private file readable by verified admin',original.ok&&(await original.arrayBuffer()).byteLength>0);
 for(const [label,token] of [['anonymous',null],['non-admin',user]]){
  const r=await request(path,token);check(label+' cannot read the existing private file',!r.ok);
  const workflows=await request('/rest/v1/media_workflows?media_id=eq.'+id+'&select=media_id',token);check(label+' cannot read private workflow',!workflows.ok||(await workflows.json()).length===0);
  const draft=await request('/rest/v1/articles?id=eq.'+fixture.id+'&select=id',token);check(label+' cannot read draft article directly',draft.ok&&(await draft.json()).length===0);
  const privileged=await request('/rest/v1/rpc/admin_content_choices',token,'POST',{p_kind:'the-edit',p_query:'synthetic'});check(label+' privileged content RPC rejected',privileged.status===401||privileged.status===403);
 }
 report.fixture_media=id;report.status='passed';
}catch{report.status='failed';report.limitations='Stopped; credentials and provider payloads suppressed.';process.exitCode=1;}
finally{await writeFile('docs/content-live-permissions.json',JSON.stringify(report,null,2)+'\n');}
