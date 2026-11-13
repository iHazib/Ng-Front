/** Read-only hosted probes. Never writes fixtures or prints credentials/contact details. */
import {readFile,writeFile} from 'node:fs/promises';
import {parseEnv} from 'node:util';
for(const file of ['.env','.env.local'])try{Object.assign(process.env,parseEnv(await readFile(file,'utf8')));}catch{}
const report={kind:'actual_hosted_read_only',checked_at:new Date().toISOString(),checks:[],pending:[],mutations:0};
for(const name of ['SUPABASE_SECRET_KEY','REVIEW_SESSION_SECRET']){const present=Boolean(process.env[name]);report.checks.push({name:name+' configured',result:present?'passed':'pending'});if(!present)report.pending.push('Configure '+name+' locally; never send its value in chat.');}
const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
if(url&&key){try{const r=await fetch(new URL('/rest/v1/rpc/storefront_reviews',url),{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:JSON.stringify({p_product:'00000000-0000-4000-8000-000000000000',p_page:1}),signal:AbortSignal.timeout(15000)});report.checks.push({name:'Hosted public review RPC available',result:r.ok?'passed':'pending',http:r.status});if(!r.ok)report.pending.push('Apply reviewed migration 011 once, then verify installation receipt in SQL Editor. Do not rerun 001–010.');}catch{report.pending.push('Hosted review probe unavailable; no mutations attempted.');}}
else report.pending.push('Supabase public configuration missing.');
report.status=report.pending.length?'pending':'ready_for_live_fixtures';
await writeFile('docs/reviews-hosted-preflight.json',JSON.stringify(report,null,2)+'\n');
console.log('Read-only review setup: '+report.status+'; no hosted mutations.');
