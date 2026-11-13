/** Read-only follow-up for the completed, tracked synthetic CMS run. */
import {readFile,writeFile} from 'node:fs/promises';import {parseEnv} from 'node:util';
for(const f of ['.env','.env.local'])try{Object.assign(process.env,parseEnv(await readFile(f,'utf8')));}catch{}
if(process.env.MEDIA_ENVIRONMENT!=='development')throw Error('Development configuration required.');
const source=JSON.parse(await readFile('docs/content-live-verification.json','utf8'));if(source.status!=='passed')throw Error('Successful tracked run required.');
const report={kind:'actual_content_cleanup_read_only',checks:[],status:'running',business_mutations:0};
const check=(name,ok)=>{report.checks.push({name,result:ok?'passed':'failed'});console.log((ok?'PASS: ':'FAIL: ')+name);if(!ok)throw Error('Read-only check failed.');};
let token;const base=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
async function read(path){const r=await fetch(new URL('/rest/v1/'+path,base),{headers:{apikey:key,Authorization:'Bearer '+token},signal:AbortSignal.timeout(20000)});if(!r.ok)throw Error('Authorized read failed.');return r.json();}
try{
 const auth=await fetch(new URL('/auth/v1/token?grant_type=password',base),{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:JSON.stringify({email:process.env.TEST_ADMIN_EMAIL,password:process.env.TEST_ADMIN_PASSWORD}),signal:AbortSignal.timeout(20000)});if(!auth.ok)throw Error('Local admin login unavailable.');token=(await auth.json()).access_token;
 const ids=source.fixtures.flatMap(f=>f.media);if(ids.some(id=>!(/^[a-f0-9-]{36}$/.test(id))))throw Error('Invalid tracked identity.');
 const assets=await read('media_assets?id=in.('+ids.join(',')+')&select=id,provider,lifecycle,cloudinary_asset_id,cloudinary_public_id,cloudinary_version,width,height,cloudinary_format,alt');
 check('real provider metadata retained and all test assets tombstoned',assets.length===3&&assets.every(m=>m.provider==='cloudinary'&&m.lifecycle==='deleted'&&m.cloudinary_asset_id&&m.cloudinary_public_id&&m.cloudinary_version>0&&m.width===64&&m.height===64&&m.cloudinary_format==='png'&&m.alt));
 for(const table of ['article_media','homepage_media'])check(table+' synthetic associations removed',(await read(table+'?media_id=in.('+ids.join(',')+')&select=id')).length===0);
 for(const f of source.fixtures){const [a]=await read('articles?id=eq.'+f.id+'&select=status,deleted_at,body');check('synthetic article remains deleted and hidden: '+f.slug,a.status==='archived'&&a.deleted_at);const response=await fetch('http://127.0.0.1:3000/the-edit/'+f.slug,{signal:AbortSignal.timeout(30000)});check('deleted synthetic URL returns 404: '+f.slug,response.status===404);}
 const recovery=JSON.parse(await readFile('.local/content-verification/live-recovery.json','utf8'));const home=await read('homepage_selections?section=in.(the-edit,products)&select=*');check('all previous homepage selections restored exactly',recovery.homeBaseline.every(before=>home.some(after=>JSON.stringify(before)===JSON.stringify(after))));
 report.status='passed';
}catch{report.status='failed';report.limitations='Read-only follow-up stopped; credentials and provider payloads suppressed.';process.exitCode=1;}
finally{await writeFile('docs/content-live-cleanup-verification.json',JSON.stringify(report,null,2)+'\n');}
