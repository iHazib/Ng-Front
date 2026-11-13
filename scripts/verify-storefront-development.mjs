/** Actual providers only. Never imports source catalog or logs credentials. */
import {chromium} from '@playwright/test';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {parseEnv} from 'node:util';
import {randomUUID,createHash} from 'node:crypto';
import {deflateSync} from 'node:zlib';
for(const f of ['.env','.env.local'])try{Object.assign(process.env,parseEnv(await readFile(f,'utf8')));}catch{}
if(!process.argv.includes('--run-development')||process.env.MEDIA_ENVIRONMENT!=='development')throw Error('Explicit development configuration required.');
const report={kind:'actual_development_supabase_cloudinary_chrome',checked_at:new Date().toISOString(),status:'running',checks:[],pending:[],fixtures:[]};
const save=()=>writeFile('docs/storefront-live-verification.json',JSON.stringify(report,null,2)+'\n');
const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
const hash=v=>createHash('sha256').update(JSON.stringify(v)).digest('hex');
let browser,token,adminPage,phase='RPC installation',baseline;
const mark='sf'+randomUUID().replaceAll('-','').slice(0,12);
const refs={brand:mark,category:mark,concern:mark,evidence:randomUUID(),facet:mark+'-size',finish:mark+'-finish'};
async function provider(table,method='GET',body,query='',auth=false){const r=await fetch(new URL('/rest/v1/'+table+query,url),{method,headers:{apikey:key,'Content-Type':'application/json',...(auth?{Authorization:'Bearer '+token}:{}),Prefer:'return=representation'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(20000)});if(!r.ok)throw Error('Provider request rejected.');return r.status===204?null:r.json();}
const rpc=(args={},auth=false)=>provider('rpc/storefront_catalog','POST',args,'',auth);
const protectedTables=['products','variants','variant_prices','inventory_balances','brands','categories','product_media','media_assets','media_workflows','import_records','homepage_selections','product_concerns','product_facets','evidence','concerns','facet_definitions','facet_values','catalog_search_aliases'];
async function snapshot(){const pairs=await Promise.all(protectedTables.map(async table=>{let rows=[];for(let offset=0;offset<10000;offset+=1000){const data=await provider(table,'GET',undefined,`?select=*&limit=1000&offset=${offset}`,true);rows.push(...data);if(data.length<1000)return[table,rows.map(hash)];}throw Error('Snapshot limit exceeded.');}));return Object.fromEntries(pairs);}
async function unchanged(){const after=await snapshot();return protectedTables.every(table=>baseline[table].every(h=>after[table].includes(h)));}
function check(name,ok){report.checks.push({name,result:ok?'passed':'failed'});console.log((ok?'PASS: ':'FAIL: ')+name);if(!ok)throw Error('Verification failed.');}
function png(color){const chunk=(name,data)=>{const t=Buffer.concat([Buffer.from(name),data]);let crc=0xffffffff;for(const b of t){crc^=b;for(let i=0;i<8;i++)crc=(crc>>>1)^((crc&1)?0xedb88320:0);}const size=Buffer.alloc(4),sum=Buffer.alloc(4);size.writeUInt32BE(data.length);sum.writeUInt32BE((crc^0xffffffff)>>>0);return Buffer.concat([size,t,sum]);};const h=Buffer.alloc(13);h.writeUInt32BE(1,0);h.writeUInt32BE(1,4);h[8]=8;h[9]=6;return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',h),chunk('IDAT',deflateSync(Buffer.from([0,...color,255]))),chunk('IEND',Buffer.alloc(0))]);}
async function api(body,path='/admin/api/catalog'){return adminPage.evaluate(async({body,path})=>{const s=await fetch('/admin/api/session',{cache:'no-store'});const csrf=(await s.json()).csrf;const r=await fetch(path,{method:'POST',headers:{'Content-Type':'application/json','x-admin-csrf':csrf},body:JSON.stringify(body),cache:'no-store'});if(!r.ok)throw Error('Authorized fixture operation failed.');return r.json();},{body,path});}
async function detail(id){return adminPage.evaluate(async id=>{const r=await fetch('/admin/api/catalog?view=product&id='+id,{cache:'no-store'});if(!r.ok)throw Error();return r.json();},id);}
try{
 const probe=await fetch(new URL('/rest/v1/rpc/storefront_navigation',url),{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:'{}',signal:AbortSignal.timeout(15000)});
 report.rpc_http=probe.status;
 if(!probe.ok){report.status='pending';report.pending.push('Apply supabase/sql-editor/07_install_public_storefront.sql once in development. No synthetic fixtures created; actual catalog checks cannot run until RPCs exist.');await save();console.log('PENDING: public storefront RPC installation; no fixture mutations.');}
 else{
 browser=await chromium.launch({channel:'chrome',headless:true});const adminContext=await browser.newContext();adminPage=await adminContext.newPage();adminPage.setDefaultTimeout(60000);
 phase='actual admin login';await adminPage.goto('http://127.0.0.1:3000/admin/login');await adminPage.getByLabel('Email',{exact:true}).fill(process.env.TEST_ADMIN_EMAIL);await adminPage.getByLabel('Password',{exact:true}).fill(process.env.TEST_ADMIN_PASSWORD);await adminPage.getByRole('button',{name:'Sign in',exact:true}).click();await adminPage.waitForURL('**/admin/products');token=(await adminContext.cookies()).find(c=>c.name==='ng_admin_session').value;
 baseline=await snapshot();report.preservation={tables:protectedTables.length,baseline_rows:Object.values(baseline).reduce((s,a)=>s+a.length,0),status:'pending'};
 phase='synthetic taxonomy';await provider('brands','POST',{id:refs.brand,name:'Synthetic CeraVe '+mark},'',true);await provider('categories','POST',{id:refs.category,name:'Synthetic cleansers '+mark,scope:'skincare'},'',true);await provider('category_product_types','POST',{category_id:refs.category,product_type_id:'cleanser'},'',true);
 await provider('concerns','POST',{id:refs.concern,name:'Dry skin synthetic '+mark,claim_kind:'hydration',active:true},'',true);
 await provider('evidence','POST',{id:refs.evidence,source_type:'package',finding:'Synthetic verification only. No real product suitability claim.',status:'approved',reviewed_by:(await provider('rpc/is_admin','POST',{},'',true))? (await fetch(new URL('/auth/v1/user',url),{headers:{apikey:key,Authorization:'Bearer '+token}}).then(r=>r.json())).id:null,reviewed_at:new Date().toISOString()},'',true);
 for(const [id,name,kind] of [[refs.facet,'Synthetic size','quantity'],[refs.finish,'Synthetic finish','enum']]){await provider('facet_definitions','POST',{id,name,kind,active:true},'',true);await provider('facet_scopes','POST',{facet_id:id,scope:'skincare'},'',true);}
 for(const value of ['red','blue'])await provider('facet_values','POST',{id:mark+'-'+value,facet_id:refs.finish,label:'Synthetic '+value},'',true);
 async function fixture(index,two,published){
  phase='synthetic product '+index;const productId=randomUUID(),variantId=randomUUID();const name=`Synthetic storefront ${mark} cleanser ${index}`;const sku='SF-'+randomUUID();report.fixtures.push({productId,variants:[variantId],media:[],hidden:false});await save();const f=report.fixtures.at(-1);
  await api({action:'create',productId,variantId,name,sku});
  const options=[{id:variantId,sku,label:'Small',priceMinor:100000+index*1000,stock:3,expectedStock:0,countChanged:true}];if(two){const id=randomUUID();f.variants.push(id);options.push({id,sku:'SF-'+randomUUID(),label:'Large',priceMinor:200000,stock:0,expectedStock:0,countChanged:true});}
  const data={name,brand:refs.brand,category:refs.category,productType:'cleanser',description:'Synthetic verification only, not for sale.',featured:published,options};
  await api({action:'daily-save',productId,revision:(await detail(productId)).product.revision,data,operationId:randomUUID(),intent:'save'});
  await provider('product_concerns','POST',{product_id:productId,concern_id:refs.concern,evidence_id:refs.evidence,status:'approved',qualification:'Synthetic verification only'},'',true);
  for(const [i,v] of options.entries()){
   await provider('product_facets','POST',{product_id:productId,variant_id:v.id,facet_id:refs.facet,kind:'quantity',decimal_value:(index===1?i+1:3)*10,unit:'ml',status:'approved',evidence_id:refs.evidence},'',true);
   await provider('product_facets','POST',{product_id:productId,variant_id:v.id,facet_id:refs.finish,kind:'enum',option_id:mark+(i===0&&index===1?'-red':'-blue'),status:'approved',evidence_id:refs.evidence},'',true);
   if(published){const mediaId=randomUUID();f.media.push(mediaId);await save();const bytes=png(i?[180,180,180]:[230,230,230]);const cookies=await adminContext.cookies();const session=await adminPage.evaluate(async()=> (await fetch('/admin/api/session')).json());
    const response=await fetch(`http://127.0.0.1:3000/admin/api/media?action=upload&id=${mediaId}&productId=${productId}&variantId=${v.id}&alt=Synthetic%20neutral%20pixel`,{method:'POST',headers:{Cookie:cookies.map(c=>c.name+'='+c.value).join('; '),Origin:'http://127.0.0.1:3000','x-admin-csrf':session.csrf,'Content-Type':'application/octet-stream'},body:bytes,signal:AbortSignal.timeout(90000)});if(!response.ok)throw Error('Private fixture upload failed.');
    await api({action:'approve-publish',id:mediaId},'/admin/api/media');
   }
  }
  if(published){options.forEach(o=>{o.expectedStock=o.stock;o.countChanged=false;});await api({action:'daily-save',productId,revision:(await detail(productId)).product.revision,data,operationId:randomUUID(),intent:'publish'});}
  return {...f,data,sku};
 }
 const one=await fixture(1,true,true);await fixture(2,false,true);const draft=await fixture(3,false,false);
 phase='actual anonymous public projection';let result=await rpc({p_query:mark});check('anonymous projection includes two eligible published families and no draft',result.total===2&&!result.products.some(p=>p.id===draft.productId));
 check('public payload excludes costs, provenance, private media and inventory internals',!/(source_cost|raw_fields|evidence_id|private_path|private_bucket|reserved|reconciled_at|reviewed_by)/.test(JSON.stringify(result)));
 check('admin-token public RPC retains same public allowlist',JSON.stringify(await rpc({p_query:mark},true))===JSON.stringify(result));
 check('combined manufacturer/type/verified concern search',(await rpc({p_query:`CeraVe cleanser for dry skin ${mark}`})).total===2);
 check('spelling variation and partial search',(await rpc({p_query:`Cerav cleans ${mark}`})).total===2);
 check('exact original SKU search',(await rpc({p_query:one.sku})).total===1);
 check('unsupported suitability has no inferred match',(await rpc({p_query:`sensitive acne treatment ${mark}`})).total===0);
 const filters={brand:[refs.brand,'unsupported'],[refs.facet]:['10.0000 ml','20.0000 ml']};check('OR within a facet plus AND across facets',(await rpc({p_query:mark,p_filters:filters})).total===1);
 check('variant-specific filters cannot cross-match different options',(await rpc({p_query:mark,p_filters:{[refs.facet]:['10.0000 ml'],[refs.finish]:[mark+'-blue']}})).total===0);
 const page1=await rpc({p_query:mark,p_size:1,p_sort:'price-asc'}),page2=await rpc({p_query:mark,p_size:1,p_sort:'price-asc',p_page:2});check('bounded pagination preserves total and unique ordered products',page1.total===2&&page1.products.length===1&&page2.products.length===1&&page1.products[0].id!==page2.products[0].id);
 const p=result.products.find(p=>p.id===one.productId);check('variant prices/availability and primary-specific media distinct',p.variants.length===2&&p.variants.some(v=>v.available===0&&v.priceMinor===200000)&&p.variants.every(v=>v.media[0].variantId===v.id)&&p.variants[0].media[0].id!==p.variants[1].media[0].id);
 const m=p.variants[0].media[0];const delivery=`https://res.cloudinary.com/${m.source.cloudName}/image/upload/c_limit,w_320,f_auto,q_auto/v${m.source.version}/${m.source.publicId}.${m.source.format}`;const image=await fetch(delivery,{signal:AbortSignal.timeout(20000)});check('real responsive Cloudinary delivery',image.ok&&image.headers.get('content-type')?.startsWith('image/'));
 check('homepage uses eligible explicit selections',(await rpc({p_query:mark,p_home:true})).total===2);
 phase='actual public browser';const publicContext=await browser.newContext({viewport:{width:1440,height:1000}}),page=await publicContext.newPage();page.setDefaultTimeout(60000);await page.goto('http://127.0.0.1:3000/search?q='+mark);await page.getByRole('heading',{name:one.data.name,exact:true}).waitFor();check('actual category/search product rendering',await page.locator('.catalog-card').count()===2);
 await mkdir('.local/storefront-verification',{recursive:true});await page.screenshot({path:'.local/storefront-verification/live-desktop.png',fullPage:true});await page.goto('http://127.0.0.1:3000/products/'+p.slug);await page.getByRole('radio',{name:'Large',exact:true}).check();await page.getByText('Currently out of stock',{exact:true}).waitFor();check('browser option selection changes availability and blocks bag',await page.getByRole('button',{name:'Add to bag',exact:true}).isDisabled());await page.getByRole('radio',{name:'Small',exact:true}).check();await page.getByRole('button',{name:'Add to bag',exact:true}).click();await page.goto('http://127.0.0.1:3000/cart');await page.getByRole('heading',{name:one.data.name+' · Small',exact:true}).waitFor();check('real published variant survives bag navigation and revalidation',true);
 await page.setViewportSize({width:390,height:844});await page.goto('http://127.0.0.1:3000/search?q='+mark);await page.getByRole('button',{name:'Filter & sort',exact:true}).click();await page.getByRole('dialog').waitFor();await page.getByRole('button',{name:'Close filters',exact:true}).click();check('mobile filter drawer and no document overflow',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await page.screenshot({path:'.local/storefront-verification/live-mobile.png',fullPage:true});
 phase='admin edit freshness';one.data.description='Synthetic edit freshness verified.';one.data.options[0].priceMinor=123456;one.data.options.forEach(o=>{o.countChanged=false;o.expectedStock=o.stock;});await api({action:'daily-save',productId:one.productId,revision:(await detail(one.productId)).product.revision,data:one.data,operationId:randomUUID(),intent:'save'});check('committed admin price edit immediately visible to anonymous reads',(await rpc({p_slug:p.slug})).products[0].variants.some(v=>v.id===one.variants[0]&&v.priceMinor===123456));await page.goto('http://127.0.0.1:3000/products/'+p.slug+'?variant='+one.variants[0]);await page.getByText('Rs 1,234.56',{exact:false}).waitFor();check('Next server wrapper returns fresh admin price in browser',true);
 await api({action:'visibility',productId:one.productId,hidden:true});one.hidden=true;check('hidden fixture immediately disappears from public RPC',(await rpc({p_query:one.sku})).total===0);await publicContext.close();report.status='passed';
 }
}catch{report.status='failed';report.pending.push('Stopped during '+phase+'; credentials/provider details suppressed.');process.exitCode=1;}
finally{
 if(token&&adminPage){for(const fixture of report.fixtures){try{await api({action:'feature',productId:fixture.productId,remove:true});await api({action:'visibility',productId:fixture.productId,hidden:true});fixture.hidden=true;}catch{report.pending.push('Synthetic fixture still needs hiding.');}for(const id of fixture.media)try{await api({action:'detach',id},'/admin/api/media');await api({action:'cleanup',id},'/admin/api/media');fixture.cleaned??=[];fixture.cleaned.push(id);}catch{report.pending.push('Synthetic media cleanup needs guarded reconciliation.');}}
  for(const [table,id,data] of [['brands',refs.brand,{status:'archived'}],['categories',refs.category,{status:'archived'}],['concerns',refs.concern,{active:false}],['facet_definitions',refs.facet,{active:false}],['facet_definitions',refs.finish,{active:false}]])try{await provider(table,'PATCH',data,'?id=eq.'+id,true);}catch{}
  if(baseline)try{check('all pre-existing catalog/source/media rows unchanged',await unchanged());report.preservation.status='passed';}catch{report.preservation.status='failed';report.status='failed';}
 }
 await save();await browser?.close();console.log('Actual verification status: '+report.status);
}


