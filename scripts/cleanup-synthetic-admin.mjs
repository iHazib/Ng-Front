/**
 * Remove all synthetic/test fixtures from the hosted admin side.
 * Uses the Supabase service role key to bypass RLS and delete records directly.
 * Only removes records identified as synthetic from verification reports.
 * No real business data is touched.
 */
import {readFile,writeFile} from 'node:fs/promises';
import {parseEnv} from 'node:util';

for(const f of ['.env','.env.local'])try{Object.assign(process.env,parseEnv(await readFile(f,'utf8')));}catch{}

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;
if(!url || !serviceKey){throw new Error('Missing SUPABASE_URL or SUPABASE_SECRET_KEY');}

const headers = {
  apikey: serviceKey,
  Authorization: `Bearer ${serviceKey}`,
  'Content-Type': 'application/json',
  'Prefer': 'return=representation'
};

const SYNTHETIC_PRODUCTS = [
  'e0956643-4628-42ba-85c8-67a225b1f080',
  'eb384ec9-8e0b-479c-996a-58f56c2ca876',
  '05c38735-6748-4a77-8738-ed68c30da69e',
  'a360ca3a-858e-4379-9aa8-5de971eeb1d6',
  '096999dc-8ace-49cf-b0a4-87b322dfedde',
  '1d7bc133-41fd-4246-8258-34eebcfee338'
];

const SYNTHETIC_VARIANTS = [
  'fe1d14c9-6785-4135-b496-915e49e562eb','5b2663ea-2c34-4bbd-a974-506d7b217bfb','5b296b0f-f940-496c-8029-81cf87676129',
  'ae4275d9-bc66-448c-93a0-6b5b95732e76','09413bd4-50df-4f0c-adb6-04881fc6ed01','f4de03a5-aaa1-4045-ae98-bcac47500d84',
  'd35b9ef1-562e-43ac-8c9a-324d35a97c79','3f45b26a-10e9-4fc1-8914-aaea7afd6bc1','2ddba361-f99b-4651-9567-16b8d4b61001',
  'a5ecee78-d977-4d32-a56c-a93d4be20669','9421417f-cf86-4527-9fbf-3092fc32f796','c9f8c05a-5f33-45cb-b914-4b66fdd628f9',
  'a6855e9e-8fbd-43fe-a296-a3f4227167ab','5d43a4d4-99ba-455c-baad-77dd56b69500','95d6ba1a-c8f2-47d4-82dc-a730e8ada81c',
  '6ab3436a-3222-4651-a277-338c2473438a'
];

const SYNTHETIC_MEDIA = [
  '046b200e-8091-4b1d-97f4-db0ceec13eae',
  '73fe6dd4-0d70-4e7c-abde-c7163de34399',
  'ca258bc9-aa86-46c9-ab68-f79d1e24f553',
  'be93a19f-5a0f-45c1-a708-16ed7418da39'
];

const SYNTHETIC_ORDERS = [
  'b0b287b3-62af-4bba-877b-8f9b1f0a05ae','cc10303f-821e-4392-95de-019cd19fc5ab','04258ba2-fba2-4b9d-bd03-a498451e85f7',
  '293ba7f3-f2ff-464f-bfed-575a1f6c27a4','43993528-9703-454b-984f-fa41f77055fd','468b846a-492d-411c-9555-59926b3d7688',
  '8b4695d8-e30c-4ce6-84c9-ed7107786ec6',
  '524c1fd4-d1d6-49f5-90ad-0f828427793c','b4ed667c-ee56-4405-a99c-0385a11e1365','fc033418-a906-4cf8-bb79-e7cb12176f12',
  'acfc642f-d4b0-419b-887c-1531b8a6ea30','17a8f28e-2a58-49cb-b369-6f1dee5f7631',
  '84044568-0878-40de-b605-63002b929496','b439f75b-894e-4e36-9853-2e5fff14aee6'
];

const report = {kind:'synthetic_admin_cleanup',checked_at:new Date().toISOString(),deleted:{},errors:[]};

function inClause(ids){return 'id=in.('+ids.join(',')+')';}

async function del(table,query,label){
  try{
    const r = await fetch(new URL('/rest/v1/'+table+'?'+query,url),{method:'DELETE',headers,cache:'no-store',signal:AbortSignal.timeout(30000)});
    const body = await r.json().catch(()=>null);
    if(!r.ok){report.errors.push({label,table,status:r.status,body});console.log('FAIL delete',label,table,r.status,String(body&&body.message||body).slice(0,200));return false;}
    report.deleted[label]=(report.deleted[label]||0)+1;
    console.log('DELETED',label,table,'count=',Array.isArray(body)?body.length:'ok');
    return true;
  }catch(e){report.errors.push({label,table,error:String(e)});console.log('ERROR delete',label,table,e.message);return false;}
}

async function update(table,query,data,label){
  try{
    const r = await fetch(new URL('/rest/v1/'+table+'?'+query,url),{method:'PATCH',headers:{...headers,Prefer:'return=representation'},body:JSON.stringify(data),cache:'no-store',signal:AbortSignal.timeout(30000)});
    const body = await r.json().catch(()=>null);
    if(!r.ok){report.errors.push({label,table,status:r.status,body});console.log('FAIL update',label,table,r.status,String(body&&body.message||body).slice(0,200));return false;}
    console.log('UPDATED',label,table,'count=',Array.isArray(body)?body.length:'ok');
    return true;
  }catch(e){report.errors.push({label,table,error:String(e)});console.log('ERROR update',label,table,e.message);return false;}
}

async function count(table,query,label){
  try{
    const r = await fetch(new URL('/rest/v1/'+table+'?'+query+'&select=count',url),{headers,cache:'no-store',signal:AbortSignal.timeout(15000),headers:{...headers,Prefer:'count=exact'}});
    const contentRange = r.headers.get('content-range');
    console.log('REMAINING',label,table,contentRange||'unknown');
    return contentRange;
  }catch(e){console.log('REMAINING',label,table,'check failed:',e.message);return null;}
}

try{
  // 0. Delete import_records referencing synthetic variants (blocks variant deletion)
  await del('import_records', 'variant_id=in.('+SYNTHETIC_VARIANTS.join(',')+')', 'synthetic import records');

  // 0b. Delete inventory_balances referencing synthetic variants (blocks variant deletion)
  await del('inventory_balances', 'variant_id=in.('+SYNTHETIC_VARIANTS.join(',')+')', 'synthetic inventory balances');

  // 0c. Delete inventory_movements referencing synthetic variants (blocks variant deletion)
  await del('inventory_movements', 'variant_id=in.('+SYNTHETIC_VARIANTS.join(',')+')', 'synthetic inventory movements');

  // 0d. Delete inventory_counts referencing synthetic variants (blocks variant deletion)
  await del('inventory_counts', 'variant_id=in.('+SYNTHETIC_VARIANTS.join(',')+')', 'synthetic inventory counts');

  // 0e. Delete sku_aliases referencing synthetic variants (blocks variant deletion)
  await del('sku_aliases', 'variant_id=in.('+SYNTHETIC_VARIANTS.join(',')+')', 'synthetic SKU aliases');

  // 0f. Delete product_facets referencing synthetic products/variants (blocks variant deletion)
  await del('product_facets', 'product_id=in.('+SYNTHETIC_PRODUCTS.join(',')+')', 'synthetic product facets');

  // 0g. Delete product_save_requests referencing synthetic products (blocks product deletion)
  await del('product_save_requests', 'product_id=in.('+SYNTHETIC_PRODUCTS.join(',')+')', 'synthetic product save requests');

  // 1. Set synthetic orders to draft so order_items can be deleted
  await update('orders', inClause(SYNTHETIC_ORDERS), {status:'draft'}, 'synthetic orders to draft');

  // 2. Find and delete order_item_components (reference order_items)
  const oir = await fetch(new URL('/rest/v1/order_items?'+'order_id=in.('+SYNTHETIC_ORDERS.join(',')+')&select=id',url),{headers,cache:'no-store',signal:AbortSignal.timeout(15000)});
  const ois = await oir.json();
  const orderItemIds = Array.isArray(ois)?ois.map(o=>o.id):[];
  if(orderItemIds.length>0){
    await del('order_item_components', 'order_item_id=in.('+orderItemIds.join(',')+')', 'synthetic order item components');
  }

  // 3. Delete order_items (now that orders are draft)
  await del('order_items', 'order_id=in.('+SYNTHETIC_ORDERS.join(',')+')', 'synthetic order items');

  // 4. Delete orders
  await del('orders', inClause(SYNTHETIC_ORDERS), 'synthetic orders');

  // 5. Delete variant_prices (reference variants)
  await del('variant_prices', 'variant_id=in.('+SYNTHETIC_VARIANTS.join(',')+')', 'synthetic variant prices');

  // 6. Delete variants (reference products)
  await del('variants', inClause(SYNTHETIC_VARIANTS), 'synthetic variants');

  // 7. Delete products
  await del('products', inClause(SYNTHETIC_PRODUCTS), 'synthetic products');

  // 8. Delete media workflows (reference media_assets via media_id)
  await del('media_workflows', 'media_id=in.('+SYNTHETIC_MEDIA.join(',')+')', 'synthetic media workflows');

  // 9. Delete media assets
  await del('media_assets', inClause(SYNTHETIC_MEDIA), 'synthetic media assets');

  // 10. Delete product media associations
  await del('product_media', 'product_id=in.('+SYNTHETIC_PRODUCTS.join(',')+')', 'synthetic product media');

  // 11. Delete homepage selections
  await del('homepage_selections', 'product_id=in.('+SYNTHETIC_PRODUCTS.join(',')+')', 'synthetic homepage selections');

  // 12. Delete deals / deal components
  await del('deal_components', 'deal_id=in.('+SYNTHETIC_PRODUCTS.join(',')+')', 'synthetic deal components');
  await del('deals', inClause(SYNTHETIC_PRODUCTS), 'synthetic deals');

  // Verify remaining counts
  console.log('\n--- Verification: remaining synthetic records ---');
  for(const id of SYNTHETIC_PRODUCTS){await count('products','id=eq.'+id,'product');}
  for(const id of SYNTHETIC_VARIANTS){await count('variants','id=eq.'+id,'variant');}
  for(const id of SYNTHETIC_MEDIA){await count('media_assets','id=eq.'+id,'media');}
  for(const id of SYNTHETIC_ORDERS){await count('orders','id=eq.'+id,'order');}

  report.status = report.errors.length ? 'partial' : 'complete';
  console.log('\nCleanup result:', JSON.stringify(report,null,2));
  await writeFile('docs/synthetic-admin-cleanup.json',JSON.stringify(report,null,2)+'\n');
  process.exit(report.errors.length ? 1 : 0);
}catch(e){report.status='failed';report.fatal=String(e);console.error('FATAL:',e.message);await writeFile('docs/synthetic-admin-cleanup.json',JSON.stringify(report,null,2)+'\n');process.exitCode=1;}
