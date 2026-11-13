// Actual Chrome/Next/Supabase development verification. Uses synthetic fixtures only; reports installed exact-priority status without applying hosted SQL.
import {chromium} from '@playwright/test';import {readFile,writeFile} from 'node:fs/promises';import {parseEnv} from 'node:util';import {randomUUID,createHash} from 'node:crypto';
for(const file of ['.env','.env.local'])try{Object.assign(process.env,parseEnv(await readFile(file,'utf8')));}catch{}
if(!process.argv.includes('--run-development')||process.env.MEDIA_ENVIRONMENT!=='development')throw Error('Explicit development verification required.');
const report={kind:'actual_Chrome_Next_Supabase',status:'running',checks:[],pending:[],fixtures:[]},save=()=>writeFile('docs/admin-exact-search-live-verification.json',JSON.stringify(report,null,2)+'\n');
const check=(name,ok)=>{report.checks.push({name,result:ok?'passed':'failed'});if(!ok)throw Error('Verification failed');console.log('PASS (actual): '+name);};
const tables=['products','variants','variant_prices','inventory_balances','product_media','media_assets','media_workflows','brands','brand_aliases','categories','product_categories','product_facets','product_concerns','import_records','homepage_selections','articles','reviews','variant_options','category_product_types','sku_aliases','facet_definitions','facet_values','facet_scopes','concerns','factory_set_contents','import_batches','product_checks','article_media','homepage_media'];
const canonical=x=>Array.isArray(x)?x.map(canonical):x&&typeof x==='object'?Object.fromEntries(Object.keys(x).sort().map(k=>[k,canonical(x[k])])):x;
const hash=x=>createHash('sha256').update(JSON.stringify(canonical(x))).digest('hex');let browser,api,provider,baseline,verifyPreservation;
try{
 browser=await chromium.launch({channel:'chrome',headless:true});const context=await browser.newContext({viewport:{width:1440,height:1000}}),page=await context.newPage();page.setDefaultTimeout(60000);const base='http://127.0.0.1:3000';
 api=async(method,body,path='/admin/api/catalog')=>page.evaluate(async({method,body,path})=>{const headers={};if(method==='POST'){headers['x-admin-csrf']=(await(await fetch('/admin/api/session',{cache:'no-store'})).json()).csrf;headers['Content-Type']='application/json';}const r=await fetch(path,{method,headers,body:body===undefined?undefined:JSON.stringify(body),cache:'no-store'});return{status:r.status,body:await r.json(),cache:r.headers.get('cache-control')};},{method,body,path});
 provider=async(table,method='GET',body,query='')=>{const token=(await context.cookies()).find(c=>c.name==='ng_admin_session')?.value;if(!token)throw Error('Admin session required');const r=await fetch(new URL('/rest/v1/'+table+query,process.env.NEXT_PUBLIC_SUPABASE_URL),{method,headers:{apikey:process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,Authorization:'Bearer '+token,'Content-Type':'application/json',Prefer:'return=representation'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(20000)});if(!r.ok){report.providerFailure={table,method,http:r.status};throw Error('Synthetic provider operation failed');}return r.status===204?null:r.json();};
 const snapshot=async()=>Object.fromEntries(await Promise.all(tables.map(async table=>{const all=[];for(let offset=0;offset<10000;offset+=1000){const rows=await provider(table,'GET',undefined,'?select=*&limit=1000&offset='+offset);all.push(...rows.map(hash));if(rows.length<1000)return[table,all];}throw Error('Snapshot bound exceeded');})));
 const preserved=async()=>{const after=await snapshot();return tables.every(t=>baseline[t].every(x=>after[t].includes(x)));};verifyPreservation=preserved;
 const login=async(email,password)=>{await page.goto(base+'/admin/login');await page.getByLabel('Email',{exact:true}).fill(email);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Sign in',exact:true}).click();};
 await page.goto(base+'/admin/products');await page.waitForURL('**/admin/login');check('anonymous list API denied',(await api('GET',undefined,'/admin/api/catalog?view=list')).status===401);
 await login(process.env.TEST_USER_EMAIL,process.env.TEST_USER_PASSWORD);await page.getByRole('alert').filter({hasText:'Administrator access required.'}).waitFor();check('actual non-admin login denied',true);
 await login(process.env.TEST_ADMIN_EMAIL,process.env.TEST_ADMIN_PASSWORD);await page.waitForURL('**/admin/products');check('actual admin browser login works',true);
 check('CSRF-less dismissal denied',await page.evaluate(async()=>{const r=await fetch('/admin/api/catalog',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:'reminder'})});return r.status===403;}));
 const initial=await api('GET',undefined,'/admin/api/catalog?view=list');
 if(initial.status!==200){report.status='hosted_migration_pending';report.pending.push('Migration 013 installed-state/receipt confirmation required before synthetic hosted search/filter/reminder fixtures. No catalog mutations performed.');}
 else{
 check('private list responses uncached',initial.cache.includes('no-store'));
 const userLogin=await fetch(new URL('/auth/v1/token?grant_type=password',process.env.NEXT_PUBLIC_SUPABASE_URL),{method:'POST',headers:{apikey:process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,'Content-Type':'application/json'},body:JSON.stringify({email:process.env.TEST_USER_EMAIL,password:process.env.TEST_USER_PASSWORD}),signal:AbortSignal.timeout(15000)});if(!userLogin.ok)throw Error('User Auth test failed');const userAuth=await userLogin.json();
 for(const [name,token] of [['anonymous',null],['non-admin',userAuth.access_token]]){const headers={apikey:process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})};for(const [fn,args] of [['admin_catalog_list',{}],['admin_catalog_filter_options',{}],['admin_catalog_reminder',{p_key:'synthetic-only',p_episode:randomUUID(),p_ignore:true}]]){const r=await fetch(new URL('/rest/v1/rpc/'+fn,process.env.NEXT_PUBLIC_SUPABASE_URL),{method:'POST',headers,body:JSON.stringify(args),signal:AbortSignal.timeout(15000)});check(name+' hosted RPC '+fn+' denied',r.status===401||r.status===403);}const privateRead=await fetch(new URL('/rest/v1/admin_reminder_dismissals?select=issue_key&limit=1',process.env.NEXT_PUBLIC_SUPABASE_URL),{headers:{...headers,'Accept-Profile':'app_private'},signal:AbortSignal.timeout(15000)});check(name+' direct private API read denied',!privateRead.ok);}

 baseline=await snapshot();report.preservation={tables:tables.length,rows:Object.values(baseline).reduce((n,x)=>n+x.length,0),status:'pending'};
 const marker=randomUUID(),sku='EX-'+marker,brand='ex-'+marker,category='ex-cat-'+marker,productId=randomUUID(),small=randomUUID(),large=randomUUID(),spaced=randomUUID(),alias=sku+'-ALIAS',facet='ex-finish-'+marker,matte='ex-matte-'+marker,gloss='ex-gloss-'+marker;
 report.taxonomy={brand,category,facet};report.fixtures.push({productId,variantIds:[small,large,spaced],marker,sku,hidden:false});await save();
 await provider('brands','POST',{id:brand,name:'CeraVe synthetic '+marker});await provider('categories','POST',{id:category,name:'Synthetic cleansers '+marker,scope:'skincare'});await provider('category_product_types','POST',{category_id:category,product_type_id:'cleanser'});
 check('synthetic draft created through authorized Next wrapper',(await api('POST',{action:'create',productId,variantId:small,name:'Synthetic precision cleanser '+marker,sku:sku+'-SMALL'})).status===200);
 const d=(await api('GET',undefined,'/admin/api/catalog?view=product&id='+productId)).body;
 check('synthetic options saved through Next wrapper',(await api('POST',{action:'daily-save',productId,revision:d.product.revision,operationId:randomUUID(),intent:'save',data:{name:'Synthetic precision cleanser '+marker,brand,category,productType:'cleanser',featured:false,options:[{id:small,sku:sku+'-SMALL',label:'Small',countChanged:false},{id:large,sku:sku+'-LARGE',label:'Large',countChanged:false},{id:spaced,sku:'EXDANM-'+marker+' - 001',label:'Spaced',countChanged:false}]}})).status===200);
 await provider('sku_aliases','POST',{alias,variant_id:small});
 await provider('facet_definitions','POST',{id:facet,name:'Synthetic finish '+marker,kind:'enum',active:true});await provider('facet_scopes','POST',{facet_id:facet,scope:'skincare'});await provider('facet_values','POST',[{id:matte,facet_id:facet,label:'Matte'},{id:gloss,facet_id:facet,label:'Gloss'}]);await provider('product_facets','POST',[{product_id:productId,variant_id:small,facet_id:facet,kind:'enum',option_id:matte},{product_id:productId,variant_id:large,facet_id:facet,kind:'enum',option_id:gloss}]);
 const list=async(q,filters={})=>{const r=await api('GET',undefined,'/admin/api/catalog?'+new URLSearchParams({view:'list',q,filters:JSON.stringify(filters)}));if(r.status!==200)throw Error('List request failed');return r.body;};
 const exact=await list(alias);report.exactAliasRows=exact.total;
 const fixed=exact.total===1&&exact.rows[0]?.variant_id===small;
 if(!fixed){report.pending.push('Incremental 014 must be applied through SQL Editor; actual hosted synthetic full alias still matches siblings. Exact-isolation checks await installation.');report.status='incremental_014_pending';}
 else{
  check('actual hosted full alias isolates only its variant',true);
  for(const [name,q,id] of [
   ['original Small SKU',sku+'-SMALL',small],['original Large sibling SKU',sku+'-LARGE',large],
   ['case-normalized trimmed SKU','  '+(sku+'-SMALL').toLowerCase()+'  ',small],
   ['case-normalized trimmed alias',' '+alias.toLowerCase()+' ',small],
   ['whitespace-trimmed SKU','\t'+sku+'-SMALL\n',small],
   ['original spaced SKU','EXDANM-'+marker+' - 001',spaced],
   ['normalized spaced SKU',' exdanm-'+marker+'-001 ',spaced],
   ['expanded separator spaces','EXDANM-'+marker+'  -  001',spaced]
  ]){const r=await list(q);check(name+' isolates its exact option',r.total===1&&r.rows[0]?.variant_id===id);}
  check('exact identifier combined brand/category/type/facet filters',(await list(alias,{brand,category,type:'cleanser',facets:{[facet]:[matte]}})).total===1);
  check('excluded exact facet does not fall back to close sibling',(await list(alias,{brand,facets:{[facet]:[gloss]}})).total===0);
  check('excluded exact visibility does not fall back',(await list(alias,{status:'published'})).total===0);
  check('excluded exact category does not fall back',(await list(alias,{category:'no-such-category-'+marker})).total===0);
  check('excluded exact brand does not fall back',(await list(sku+'-SMALL',{brand:'no-such-brand-'+marker})).total===0);
  check('excluded original spaced SKU facet does not fall back',(await list('EXDANM-'+marker+' - 001',{facets:{[facet]:[matte]}})).total===0);
  await page.goto(base+'/admin/products');
  for(const [name,q,id] of [['alias',alias,small],['original SKU',sku+'-LARGE',large],['normalized spaced SKU','EXDANM-'+marker+'-001',spaced]]){
   await page.getByLabel('Search products',{exact:true}).fill(q);
   const updated=page.waitForResponse(r=>r.url().includes('/admin/api/catalog?')&&r.url().includes('view=list')&&r.request().method()==='GET');
   await page.getByRole('button',{name:'Search',exact:true}).click();await updated;
   await page.getByText(/1 matching products.*1 matching SKUs/).waitFor();
   const expected=id===small?sku+'-SMALL':id===large?sku+'-LARGE':'EXDANM-'+marker+' - 001';
   await page.getByRole('button',{name:'Edit '+expected,exact:true}).waitFor();
   check('actual browser '+name+' isolates one option',await page.locator('.product-table tbody tr').count()===1);
  }
  await page.setViewportSize({width:390,height:844});
  await page.getByLabel('Search products',{exact:true}).fill(alias);
  const mobileUpdate=page.waitForResponse(r=>r.url().includes('/admin/api/catalog?')&&r.url().includes('view=list')&&r.request().method()==='GET');await page.getByRole('button',{name:'Search',exact:true}).click();await mobileUpdate;await page.getByRole('button',{name:'Edit '+sku+'-SMALL',exact:true}).waitFor();
  check('mobile browser alias isolation',await page.locator('.product-table tbody tr').count()===1);

 }
 const spacedResult=await list(' exdanm-'+marker+'-001 ');report.spacedExactRows=spacedResult.total;
 if(fixed)check('spaced SKU matches normalized query and retains immutable original',spacedResult.total===1&&spacedResult.rows[0]?.original_sku==='EXDANM-'+marker+' - 001');
 check('ordinary brand/name typo search still works',(await list('cerav cleanser',{brand,category})).total===3);
 check('general partial identifier search preserves matching variants',(await list(sku,{brand,facets:{[facet]:[matte,gloss]}})).total===2);
 check('general combined OR facet filters',(await list('cleanser',{brand,category,type:'cleanser',facets:{[facet]:[matte,gloss]}})).total===2);
 check('synthetic fixtures remain drafts',(await provider('products','GET',undefined,'?select=status&id=eq.'+productId))[0].status==='draft');
 report.status=fixed?'passed':'incremental_014_pending';
 }
}catch{report.status='failed';report.error='Verification stopped. No credentials/provider payloads recorded.';process.exitCode=1;}
finally{
 try{
  if(api&&provider)for(const f of report.fixtures){const rows=await provider('products','GET',undefined,'?select=name&id=eq.'+f.productId);if(rows.length){if(rows[0].name!=='Synthetic precision cleanser '+f.marker)throw Error('Fixture identity mismatch');check('synthetic fixture safely hidden',(await api('POST',{action:'visibility',productId:f.productId,hidden:true})).status===200);for(const id of f.variantIds)await provider('variants','PATCH',{status:'archived'},'?id=eq.'+id+'&product_id=eq.'+f.productId);f.hidden=true;}}
  if(provider&&report.taxonomy){await provider('brands','PATCH',{status:'archived'},'?id=eq.'+report.taxonomy.brand);await provider('categories','PATCH',{status:'archived'},'?id=eq.'+report.taxonomy.category);await provider('facet_definitions','PATCH',{active:false},'?id=eq.'+report.taxonomy.facet);}
  if(baseline){const intact=await verifyPreservation();check('every pre-existing business record unchanged',intact);report.preservation.status=intact?'passed':'failed';}
 }catch{report.cleanup='pending; inspect synthetic IDs in report';process.exitCode=1;}
 if(!report.cleanup)report.cleanup='synthetic drafts archived; private audit history retained; no media uploaded';await save();if(browser)await browser.close();console.log('Actual verification status: '+report.status);
}
