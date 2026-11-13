import {readFile,writeFile} from 'node:fs/promises';import {parseEnv} from 'node:util';
for(const file of ['.env','.env.local'])try{Object.assign(process.env,parseEnv(await readFile(file,'utf8')));}catch{}
if(process.env.MEDIA_ENVIRONMENT!=='development')throw Error('Development only');
const reports=await Promise.all(['docs/admin-exact-search-live-first-attempt.json','docs/admin-exact-search-live-preinstallation-20261012.json','docs/admin-exact-search-live-verification.json'].map(async f=>JSON.parse(await readFile(f,'utf8'))));
const fixtures=reports.flatMap(r=>r.fixtures),ids=fixtures.map(f=>f.productId),variants=fixtures.flatMap(f=>f.variantIds);
const key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,url=process.env.NEXT_PUBLIC_SUPABASE_URL;
const auth=await fetch(new URL('/auth/v1/token?grant_type=password',url),{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:JSON.stringify({email:process.env.TEST_ADMIN_EMAIL,password:process.env.TEST_ADMIN_PASSWORD}),signal:AbortSignal.timeout(15000)});
if(!auth.ok)throw Error('Admin authentication unavailable');const token=(await auth.json()).access_token;
const read=async(table,query,admin)=>{const r=await fetch(new URL('/rest/v1/'+table+query,url),{headers:{apikey:key,...(admin?{Authorization:'Bearer '+token}:{})},signal:AbortSignal.timeout(15000)});if(!r.ok)throw Error('Cleanup read unavailable');return r.json();};
const products=await read('products','?select=id,status&id=in.('+ids.join(',')+')',true),options=await read('variants','?select=id,status&id=in.('+variants.join(',')+')',true);
const report={kind:'actual_Supabase_readonly_cleanup',synthetic_products:ids.length,synthetic_variants:variants.length,all_archived:products.length===ids.length&&products.every(p=>p.status==='archived')&&options.length===variants.length&&options.every(v=>v.status==='archived'),anonymous_products:(await read('products','?select=id&id=in.('+ids.join(',')+')',false)).length,anonymous_variants:(await read('variants','?select=id&id=in.('+variants.join(',')+')',false)).length,media_uploaded:0};
await writeFile('docs/admin-exact-search-cleanup-verification.json',JSON.stringify(report,null,2)+'\n');
if(!report.all_archived||report.anonymous_products||report.anonymous_variants)throw Error('Cleanup verification failed');console.log('PASS: all recorded synthetic fixtures and variants archived; anonymous reads expose none.');
