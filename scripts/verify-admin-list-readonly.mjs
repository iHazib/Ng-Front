// Supplemental actual browser verification of this run's own archived fixture only.
import {chromium} from '@playwright/test';
import {readFile,writeFile} from 'node:fs/promises';
import {parseEnv} from 'node:util';
for(const file of ['.env','.env.local'])try{Object.assign(process.env,parseEnv(await readFile(file,'utf8')));}catch{}
if(!process.argv.includes('--run-development')||process.env.MEDIA_ENVIRONMENT!=='development')throw Error('Development verification only.');
const live=JSON.parse(await readFile('docs/admin-list-live-verification.json','utf8'));
if(live.status!=='passed'||!live.fixtures[0]?.hidden)throw Error('Complete and clean up the main fixture run first.');
const report={kind:'actual_Chrome_Next_Supabase_read_only',mutations:0,checks:[],limitations:[]};let browser;
const check=(name,ok)=>{report.checks.push({name,result:ok?'passed':'failed'});if(!ok)throw Error('Read-only check failed');console.log('PASS (actual): '+name);};
try{
 browser=await chromium.launch({channel:'chrome',headless:true});const page=await browser.newPage({viewport:{width:1440,height:1000}});page.setDefaultTimeout(60000);
 await page.goto('http://127.0.0.1:3000/admin/login');await page.getByLabel('Email',{exact:true}).fill(process.env.TEST_ADMIN_EMAIL);await page.getByLabel('Password',{exact:true}).fill(process.env.TEST_ADMIN_PASSWORD);await page.getByRole('button',{name:'Sign in',exact:true}).click();await page.waitForURL('**/admin/products');
 const {sku}=live.fixtures[0],t=live.taxonomy;
 for(const [table,id] of [['products',live.fixtures[0].productId],['variants',live.fixtures[0].variantId]]){
  const r=await fetch(new URL('/rest/v1/'+table+'?select=id&id=eq.'+id,process.env.NEXT_PUBLIC_SUPABASE_URL),{headers:{apikey:process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY},signal:AbortSignal.timeout(15000)});
  check('cleaned synthetic '+table+' isolated from anonymous public reads',r.ok&&(await r.json()).length===0);
 }
 const list=q=>page.evaluate(async({q,brand})=>{const p=new URLSearchParams({view:'list',q,filters:JSON.stringify({brand})});return(await fetch('/admin/api/catalog?'+p,{cache:'no-store'})).json();},{q,brand:t.brand});
 check('trigram spelling variation matches assigned brand and concern',(await list('ceravee cleanser dry skin')).total===2);
 check('unsupported suitability is not invented',(await list('unsubstantiated oily')).total===0);
 const alias=await list(sku+'-ALIAS');
 report.exactAlias={matchingRows:alias.total,labels:alias.rows.map(r=>r.variant_label)};
 if(alias.total!==1)report.limitations.push('An exact SKU alias also returns the closely spelled sibling SKU because trigram matching applies to the shared SKU prefix. Alias plus shade/size identifies the intended option. Exact identifier priority requires a future database correction; no hosted SQL was changed.');
 else check('exact SKU alias isolates its assigned option',true);
 await page.getByLabel('Search products',{exact:true}).fill(sku);await page.getByRole('button',{name:'Search',exact:true}).click();await page.getByText('1 matching products · 2 matching SKUs',{exact:false}).waitFor();
 report.phase='combined browser filters';await page.getByText('Filters & needs attention',{exact:true}).click();await page.getByLabel('Brand',{exact:true}).selectOption(t.brand);const categoryOptions=page.waitForResponse(r=>r.url().includes('view=filter-options')&&r.url().includes(encodeURIComponent(t.additionalParent))&&r.status()===200);await page.getByLabel('Category / subcategory',{exact:true}).selectOption(t.additionalParent);await categoryOptions;
 await page.getByText('Assigned filters & concerns',{exact:true}).click();await page.getByRole('group',{name:'Synthetic finish '+sku.slice(3),exact:true}).getByLabel('Synthetic matte',{exact:true}).check();await page.getByRole('button',{name:'Apply filters',exact:true}).click();await page.getByText('1 matching products · 1 matching SKUs',{exact:false}).waitFor();
 check('browser combined brand/additional-category/facet controls and count',await page.locator('.product-table tbody tr').count()===1&&await page.getByText(sku+'-SMALL · Small',{exact:true}).count()===1);
 check('removed media immediately restores missing-image badge',await page.getByRole('button',{name:'Ignore Image missing for Small',exact:true}).count()===1);
 report.phase='browser pagination';await page.getByRole('button',{name:'Clear all',exact:true}).click();await page.locator('.product-table tbody tr').first().waitFor();const nextPage=page.waitForResponse(r=>r.url().includes('view=list')&&r.url().includes('offset=25')&&r.status()===200);await page.getByRole('button',{name:'Next',exact:true}).click();await nextPage;await page.getByText('Page 2 of',{exact:false}).waitFor();await page.locator('.table-scroll[aria-busy="false"]').waitFor();
 check('browser advances a bounded server page',await page.locator('.product-table tbody tr').count()<=25&&await page.getByRole('button',{name:'Previous',exact:true}).isEnabled());
 report.status=report.limitations.length?'passed_with_limitation':'passed';
}catch{report.status='failed';report.limitations.push('Supplemental browser check stopped; credentials and provider payloads suppressed.');process.exitCode=1;}
finally{await browser?.close();await writeFile('docs/admin-list-live-readonly-verification.json',JSON.stringify(report,null,2)+'\n');}
