/** Supplemental actual browser verification; touches only a prior synthetic fixture. */
import {chromium} from '@playwright/test';
import {readFile,writeFile} from 'node:fs/promises';
import {parseEnv} from 'node:util';
for(const file of ['.env','.env.local'])try{Object.assign(process.env,parseEnv(await readFile(file,'utf8')));}catch{}
if(!process.argv.includes('--run-development')||process.env.MEDIA_ENVIRONMENT!=='development')throw Error('Development verification required.');
const previous=JSON.parse(await readFile('docs/admin-usability-live-verification.json','utf8'));
if(previous.status!=='passed')throw Error('Complete the primary browser verification first.');
const fixture=previous.fixtures[0];
const report={kind:'actual_browser_and_development_supabase',checked_at:new Date().toISOString(),status:'pending',checks:[]};
let browser;
try{
 browser=await chromium.launch({channel:'chrome',headless:true});const context=await browser.newContext();const page=await context.newPage();page.setDefaultTimeout(60000);
 await page.goto('http://127.0.0.1:3000/admin/login');await page.getByLabel('Email',{exact:true}).fill(process.env.TEST_ADMIN_EMAIL);await page.getByLabel('Password',{exact:true}).fill(process.env.TEST_ADMIN_PASSWORD);await page.getByRole('button',{name:'Sign in',exact:true}).click();await page.waitForURL('**/admin/products');
 const detail=()=>page.evaluate(async id=>{const r=await fetch('/admin/api/catalog?view=product&id='+id);if(!r.ok)throw Error('Private read failed.');return r.json();},fixture.productId);
 const before=await detail();const variant=before.variants.find(v=>v.id===fixture.variantId);
 if(!variant.original_sku.startsWith('USABILITY-')||!before.product.name.startsWith('Synthetic usability ')||before.product.status!=='archived'||variant.inventory_balances.on_hand!==5)throw Error('Synthetic-only guard failed.');
 const token=(await context.cookies()).find(c=>c.name==='ng_admin_session').value;
 const readCounts=async()=>{const r=await fetch(new URL('/rest/v1/inventory_counts?variant_id=eq.'+fixture.variantId+'&select=previous_count,counted,operation_id',process.env.NEXT_PUBLIC_SUPABASE_URL),{headers:{apikey:process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,Authorization:'Bearer '+token},signal:AbortSignal.timeout(20000)});if(!r.ok)throw Error('Audit read failed.');return r.json();};
 const oldCounts=await readCounts();
 await page.getByLabel('Search by SKU or product name').fill(variant.original_sku);await page.getByRole('button',{name:'Search',exact:true}).click();await page.getByRole('button',{name:'Edit '+variant.original_sku,exact:true}).click();await page.getByLabel('Stock count',{exact:true}).fill('0');await page.getByRole('button',{name:'Save',exact:true}).click();await page.getByRole('status').filter({hasText:'Changes saved. Visibility unchanged.'}).waitFor();
 const after=await detail(),counts=await readCounts();
 function check(name,ok){report.checks.push({name,result:ok?'passed':'failed'});console.log((ok?'PASS: ':'FAIL: ')+name);if(!ok)throw Error('Verification failed.');}
 check('actual browser reconciles five to zero and preserves hidden status',after.product.status==='archived'&&after.variants.find(v=>v.id===fixture.variantId).inventory_balances.on_hand===0&&after.variants.every(v=>v.status===before.variants.find(b=>b.id===v.id).status));
 check('zero count has exactly one new audited reconciliation',counts.length===oldCounts.length+1&&counts.some(c=>!oldCounts.some(old=>old.operation_id===c.operation_id)&&c.previous_count===5&&c.counted===0));
 await page.getByRole('button',{name:'Save',exact:true}).click();await page.getByRole('status').filter({hasText:'Changes saved. Visibility unchanged.'}).waitFor();
 check('unchanged zero save creates no additional inventory count',(await readCounts()).length===counts.length);
 await page.getByRole('button',{name:'Sign out',exact:true}).click();await page.waitForURL('**/admin/login');report.status='passed';
}catch{report.status='failed';report.pending='Synthetic zero-stock browser verification needs retry; credentials/provider details suppressed.';process.exitCode=1;console.log('Supplemental zero-stock test failed; see sanitized report.');}
finally{await writeFile('docs/admin-zero-stock-live-verification.json',JSON.stringify(report,null,2)+'\n');await browser?.close();}
