/** Read-only audit of the authorized development draft import. No customer data is requested. */
import{readFile,writeFile}from'node:fs/promises';import{parseEnv}from'node:util';
for(const file of ['.env','.env.local'])try{Object.assign(process.env,parseEnv(await readFile(file,'utf8')));}catch{}
const report={kind:'actual_supabase_read_only',status:'pending',checks:[]};
function check(name,ok){report.checks.push({name,result:ok?'passed':'failed'});console.log(`${ok?'PASS':'FAIL'}: ${name}`);if(!ok)throw new Error('Audit assertion failed.');}
try{
 if(process.env.MEDIA_ENVIRONMENT!=='development')throw new Error('Development required.');
 const root=process.env.NEXT_PUBLIC_SUPABASE_URL;const headers={apikey:process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,'Content-Type':'application/json'};
 const login=await fetch(root+'/auth/v1/token?grant_type=password',{method:'POST',headers,body:JSON.stringify({email:process.env.TEST_ADMIN_EMAIL,password:process.env.TEST_ADMIN_PASSWORD})});if(!login.ok)throw new Error('Login failed.');const token=(await login.json()).access_token;headers.Authorization=`Bearer ${token}`;
 async function get(table,query){const r=await fetch(root+'/rest/v1/'+table+'?'+new URLSearchParams(query),{headers,cache:'no-store'});if(!r.ok)throw new Error('Audit read failed.');return r.json();}
 const payload=JSON.parse(await readFile('data/catalog-dry-run/database-payload.json','utf8'));const ids=payload.p_records.map(r=>r.variant_id),pids=payload.p_records.map(r=>r.product_id);
 const [variants,products,prices,balances,sources,workflows]=await Promise.all([
 get('variants',{id:`in.(${ids.join(',')})`,select:'id,product_id,original_sku,status'}),get('products',{id:`in.(${pids.join(',')})`,select:'id,status'}),
 get('variant_prices',{variant_id:`in.(${ids.join(',')})`,select:'variant_id,amount_minor,approved'}),get('inventory_balances',{variant_id:`in.(${ids.join(',')})`,select:'variant_id,on_hand,reserved,reconciled_at'}),
 get('import_records',{variant_id:`in.(${ids.join(',')})`,select:'original_sku,variant_id,raw_fields,source_quantity,source_target_minor,state'}),get('media_workflows',{product_id:`in.(${pids.join(',')})`,select:'media_id,variant_id,media_assets(lifecycle,provider,status)'}),
 ]);
 const same=(a,b)=>JSON.stringify(Object.entries(a).sort())===JSON.stringify(Object.entries(b).sort());
 check('all 121 stable product/variant UUIDs and exact original SKUs retained',variants.length===121&&payload.p_records.every(r=>variants.some(v=>v.id===r.variant_id&&v.product_id===r.product_id&&v.original_sku===r.original_sku)));
 check('all 121 products and variants are drafts',products.length===121&&products.every(p=>p.status==='draft')&&variants.every(v=>v.status==='draft'));
 check('all 121 raw source records and quantities preserved',payload.p_records.every(r=>sources.some(s=>s.variant_id===r.variant_id&&s.source_quantity===r.source_stock_units&&same(s.raw_fields,r.raw_source_fields))));
 check('source quantities total 270; no live stock initialized',sources.reduce((n,r)=>n+r.source_quantity,0)===270&&balances.length===121&&balances.every(b=>b.on_hand===0&&b.reserved===0&&b.reconciled_at===null));
 check('all source target prices preserved as unapproved integer minor units',payload.p_records.every(r=>{const p=prices.find(p=>p.variant_id===r.variant_id);return r.source_target_minor>0?p?.amount_minor===r.source_target_minor&&!p.approved:!p;}));
 check('all staged source media remain private and unapproved',workflows.every(w=>w.media_assets.provider==='supabase_private'&&w.media_assets.status==='pending'&&w.media_assets.lifecycle==='private_pending'));
 for(const table of ['products','variants']){const query=new URLSearchParams({id:`in.(${(table==='products'?pids:ids).join(',')})`,select:'id'});const response=await fetch(root+'/rest/v1/'+table+'?'+query,{headers:{apikey:process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY},cache:'no-store'});const rows=await response.json();check(`anonymous PostgREST cannot see imported draft ${table}`,response.ok&&Array.isArray(rows)&&rows.length===0);}
 const privateResponse=await fetch(root+'/rest/v1/import_records?select=original_sku&limit=1',{headers:{apikey:process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY},cache:'no-store'});const privateRows=await privateResponse.json();check('anonymous PostgREST cannot read source provenance',[401,403].includes(privateResponse.status)||(privateResponse.ok&&Array.isArray(privateRows)&&privateRows.length===0));
 let next=0,found=0;await Promise.all(Array.from({length:4},async()=>{while(next<payload.p_records.length){const row=payload.p_records[next++];const response=await fetch(root+'/rest/v1/rpc/admin_search_catalog',{method:'POST',headers,body:JSON.stringify({p_query:row.original_sku,p_limit:50,p_offset:0})});if(!response.ok)throw new Error('Search failed.');const hits=await response.json();if(hits.some(h=>h.variant_id===row.variant_id&&h.original_sku===row.original_sku))found++;}}));
 check('each of the 121 original SKUs individually searchable through admin RPC',found===121);
 report.counts={products:products.length,variants:variants.length,privateImages:workflows.length,sourceUnits:270,liveUnits:0};
 report.status='passed';
 await fetch(root+'/auth/v1/logout?scope=local',{method:'POST',headers});
}catch{report.status='failed';console.log('Read-only audit incomplete; provider payloads suppressed.');process.exitCode=1;}
await writeFile('docs/admin-import-audit.json',JSON.stringify(report,null,2)+'\n');

