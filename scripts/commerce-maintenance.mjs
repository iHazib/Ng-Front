// Schedule externally every minute. No browser, admin password or public HTTP endpoint.
import {readFile} from 'node:fs/promises';import {parseEnv} from 'node:util';
for(const f of ['.env','.env.local'])try{Object.assign(process.env,parseEnv(await readFile(f,'utf8')));}catch{}
const key=process.env.SUPABASE_SECRET_KEY??process.env.SUPABASE_SERVICE_ROLE_KEY,url=process.env.NEXT_PUBLIC_SUPABASE_URL;if(!key||!url)throw Error('Server-only Supabase configuration required.');
const rpc=async(name,args)=>{const r=await fetch(new URL('/rest/v1/rpc/'+name,url),{method:'POST',headers:{apikey:key,...(key.startsWith('sb_secret_')?{}:{Authorization:'Bearer '+key}),'Content-Type':'application/json'},body:JSON.stringify(args),redirect:'error',signal:AbortSignal.timeout(30000)});if(!r.ok)throw Error('Maintenance provider request failed.');return r.json();};
let dealAllocationsReleased=0;for(let n=0;n<10;n++){const count=await rpc('expire_deal_allocations',{p_limit:100});dealAllocationsReleased+=count;if(count<100)break;}
let expired=0;for(let n=0;n<10;n++){const count=await rpc('expire_commerce_holds',{p_limit:100});expired+=count;if(count<100)break;}
const report=await rpc('commerce_reconciliation',{});console.log(JSON.stringify({expired,dealAllocationsReleased,...report}));if(report.balanceMismatches||report.overdueHolds||report.endedDealAllocations)process.exitCode=1;
