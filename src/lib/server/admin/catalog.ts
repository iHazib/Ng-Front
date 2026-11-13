import 'server-only';
import { createHash } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import path from 'node:path';
import { authorizeAdmin } from '../database/client';
import { importAdminDrafts, getPublicationReport, adjustStock, type DraftImport } from '../database/catalog';
import * as media from '../media/service';
import type { Row } from '../database/database.types';
import { AdminError } from './session';
import { publicationMessage } from '../../catalog/publication-messages';

export function identifier(value: unknown): string {
  if (typeof value !== 'string' || !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(value)) throw new AdminError('Invalid identifier.');
  return value;
}
function text(value: unknown, max = 500, required = false): string {
  if (typeof value !== 'string' || value.length > max || (required && !value.trim())) throw new AdminError('Invalid or missing text field.');
  return value;
}
function integer(value: unknown, min = 0) {
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < min) throw new AdminError('A valid integer is required.');
  return value;
}
const query = (values: Record<string,string>) => new URLSearchParams(values);
const hash = (bytes: Uint8Array | string) => createHash('sha256').update(bytes).digest('hex');
export async function importHistory(token:string){
  const admin=await authorizeAdmin(token);
  return admin.read('import_batches',query({select:'created_at,contract_version',order:'created_at.desc',limit:'50'}));
}
function developmentOnly() { if (process.env.MEDIA_ENVIRONMENT !== 'development' || process.env.APP_ENV === 'production') throw new AdminError('Source imports are restricted to development.', 403); }
export async function referenceData(token: string) {
  const admin = await authorizeAdmin(token);
  const names = ['brands','categories','product_types','category_product_types','facet_definitions','facet_scopes','facet_values','concerns','option_axes','option_values','publication_requirements'] as const;
  const values = await Promise.all(names.map(table => admin.read(table,query({ select:'*', limit:'1000' }))));
  return Object.fromEntries(names.map((table,index) => [table,values[index]]));
}
export async function productDetail(token: string, id: string) {
  const admin = await authorizeAdmin(token); identifier(id);
  const [product] = await admin.read<Row<'products'>[]>('products',query({id:`eq.${id}`, select:'*'}));
  if (!product) throw new AdminError('Product not found.',404);
  const variants = await admin.read<Row<'variants'>[]>('variants',query({product_id:`eq.${id}`, select:'*,variant_prices(*),inventory_balances(*),variant_options(*)',order:'original_sku.asc'}));
  const [sources, workflows, associations, facets, concerns, checks, features, report] = await Promise.all([
    variants.length ? admin.read('import_records',query({variant_id:`in.(${variants.map(v=>v.id).join(',')})`,select:'original_sku,raw_fields,mapping,source_quantity,flags,state',limit:'1000'})) : [],
    admin.read('media_workflows',query({product_id:`eq.${id}`,select:'media_id,variant_id,association_id,replace_association_id,media_assets(id,alt,lifecycle,cloudinary_public_id,cloudinary_cloud_name,cloudinary_version,cloudinary_format,width,height)',order:'created_at.asc'})),
    admin.read('product_media',query({product_id:`eq.${id}`,select:'*',order:'position.asc'})),
    admin.read('product_facets',query({product_id:`eq.${id}`,select:'*,evidence(*)'})),
    admin.read('product_concerns',query({product_id:`eq.${id}`,select:'*,evidence(*)'})),
    admin.read('product_checks',query({product_id:`eq.${id}`,select:'*'})),
    admin.read('homepage_selections',query({product_id:`eq.${id}`,section:'eq.products',select:'id,position,status'})),
    getPublicationReport(token,id),
  ]);
  return { product, variants, sources, workflows, associations, facets, concerns, checks, features, report };
}
export async function importCatalog(token: string) {
  await authorizeAdmin(token); developmentOnly();
  const payload = JSON.parse(await readFile(path.join(process.cwd(),'data/catalog-dry-run/database-payload.json'),'utf8')) as DraftImport;
  const [source,contract] = await Promise.all([readFile('data/imports/Nook_Glow_Product_Listing_Updated.xlsx'),readFile('data/catalog-contract/review.json')]);
  if (payload.p_records.length !== 121 || hash(source) !== payload.p_source_hash || hash(contract) !== payload.p_contract_hash) throw new AdminError('Import contract or source hash mismatch. Regenerate and review the dry run.');
  return importAdminDrafts(token,payload);
}
async function imageFiles(root = path.join(process.cwd(),'product-images-import')): Promise<string[]> {
  const entries = await readdir(root,{withFileTypes:true});
  const groups = await Promise.all(entries.map(entry => entry.isDirectory() ? imageFiles(path.join(root,entry.name)) : entry.isFile() && /\.(png|jpe?g|webp)$/i.test(entry.name) ? [path.join(root,entry.name)] : []));
  return groups.flat().sort();
}
export async function initialImagePreview(token: string) {
  const admin = await authorizeAdmin(token); developmentOnly();
  const variants = await admin.read<Row<'variants'>[]>('variants',query({select:'id,product_id,original_sku',limit:'1000'}));
  const files = await imageFiles();
  return Promise.all(files.map(async file => {
    const bytes = await readFile(file); const name = path.basename(file); const sku = path.parse(name).name;
    const match = variants.find(v=>v.original_sku===sku);
    return { key:hash(path.relative(process.cwd(),file)), filename:name, sha256:hash(bytes), exactSku:match?.original_sku??null, variantId:match?.id??null, productId:match?.product_id??null };
  }));
}
export async function importInitialImage(token: string, key: unknown, assignedVariant?: unknown) {
  await authorizeAdmin(token); developmentOnly();
  const entries = await initialImagePreview(token); const entry = entries.find(e=>e.key===key);
  if (!entry) throw new AdminError('Source image not found.');
  const admin = await authorizeAdmin(token);
  let variantId=entry.variantId, productId=entry.productId;
  if (!variantId && assignedVariant) {
    const [variant] = await admin.read<Row<'variants'>[]>('variants',query({id:`eq.${identifier(assignedVariant)}`,select:'id,product_id'}));
    if (!variant) throw new AdminError('Assigned SKU not found.');
    variantId=variant.id;productId=variant.product_id;
  }
  if (!variantId || !productId) throw new AdminError('Unmatched image requires explicit SKU assignment.');
  const file = (await imageFiles()).find(f=>hash(path.relative(process.cwd(),f))===key)!;
  const bytes=await readFile(file); if(hash(bytes)!==entry.sha256) throw new AdminError('Source image changed.');
  const stable=hash(`initial-image:development:${variantId}:${entry.sha256}`);
  const mediaId=`${stable.slice(0,8)}-${stable.slice(8,12)}-5${stable.slice(13,16)}-a${stable.slice(17,20)}-${stable.slice(20,32)}`;
  return media.uploadPendingMedia(token,{mediaId,productId,variantId,alt:`Imported product image: ${entry.filename}`},bytes);
}
export async function mutateProduct(token: string, body: Record<string,unknown>) {
  const admin = await authorizeAdmin(token);
  const action=body.action;
  if(action==='daily-save') {
    const id=identifier(body.productId);const revision=integer(body.revision,1);const key=identifier(body.operationId);
    if(!body.data||typeof body.data!=='object'||Array.isArray(body.data))throw new AdminError('Check the product details and try again.');
    try{await admin.read('products',query({id:`eq.${id}`,select:'key_benefits',limit:'1'}));}catch{throw new AdminError('Product content update is not ready. Apply and verify migration 012 before saving.',503);}
    const intent=body.intent??'save';if(typeof intent!=='string'||!['save','draft','publish','hide'].includes(intent))throw new AdminError('Choose Save, Draft, Publish or Hide.');
    const response=await fetch(new URL('/rest/v1/rpc/save_daily_product',process.env.NEXT_PUBLIC_SUPABASE_URL).toString(),{method:'POST',headers:{apikey:process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY??'',Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({p_product:id,p_revision:revision,p_data:body.data,p_key:key,p_intent:intent}),cache:'no-store',redirect:'error',signal:AbortSignal.timeout(20000)});
    const result=await response.json();
    if(!response.ok){
      if(result.code==='PGRST202')throw new AdminError('Saving is temporarily unavailable until the product editor update is installed.',503);
      if(result.code==='23505')throw new AdminError('That SKU is already in use. Choose a different SKU.');
      const message=String(result.message??'');
      if(message.startsWith('Missing publication information: '))throw new AdminError('Before publishing:\n'+Array.from(new Set(message.slice(33).split(',').map(publicationMessage))).join('\n'));
      if(message.startsWith('Published edit would be invalid: '))throw new AdminError('This edit cannot be saved while published. Your published product is unchanged. Fix the following, or explicitly choose Save draft:\n'+Array.from(new Set(message.slice('Published edit would be invalid: '.length).split(',').map(publicationMessage))).join('\n'));
      if(result.code==='P0001'&&/^(Product changed|Stock changed|Stock cannot|Every option|Add a shade|Product name|Existing SKU|Removed option|An option reserved|Stock count|Duplicate option|Save request)/.test(message))throw new AdminError(message);
      throw new AdminError('Could not save. Check the category, product type, prices and stock counts.');
    }
    return result;
  }
  if(action==='catalog-import') return importCatalog(token);
  if(action==='initial-image') return importInitialImage(token,body.key,body.variantId);
  if(action==='create') {
    const productId=identifier(body.productId), variantId=identifier(body.variantId);
    const name=text(body.name,300,true), sku=text(body.sku,120,true);
    const existing=await admin.read<Row<'variants'>[]>('variants',query({original_sku:`eq.${sku}`,select:'id,product_id'}));
    if(existing.length && (existing[0].id!==variantId || existing[0].product_id!==productId)) throw new AdminError('This exact SKU already exists. Open its existing record.',409);
    // Existing transactional import RPC creates the draft identity + zero stock in one transaction.
    // The provenance explicitly identifies this as admin entry, not the workbook.
    const source=hash(`admin-entry:${productId}:${variantId}`);
    const result=await importAdminDrafts(token,{p_source_hash:source,p_contract_hash:source,p_version:'admin-entry-v1',p_records:[{
      product_id:productId,variant_id:variantId,original_sku:sku,raw_source_fields:{'Product Name':name,SKU:sku},source:{row:1,origin:'admin-entry'},
      source_stock_units:null,source_target_minor:null,blocking_import_errors:[],unresolved_flags:['admin_entered_draft'],
    }]});
    if(result.quarantined) throw new AdminError('Creation blocked: SKU collision or identity conflict. Existing records preserved.');
    return {productId};
  }
  const productId=identifier(body.productId);
  const [product]=await admin.read<Row<'products'>[]>('products',query({id:`eq.${productId}`,select:'*'}));
  if(!product) throw new AdminError('Product not found.',404);
  if(action==='save-product') {
    const category=text(body.category,100), type=text(body.productType,100);
    const slug=text(body.slug,200);if(slug&&!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(slug))throw new AdminError('Use a lowercase hyphenated slug.');
    const rows=await admin.write<Row<'products'>[]>('products',query({id:`eq.${productId}`,revision:`eq.${integer(body.revision,1)}`}), 'PATCH', {
      name:text(body.name,300,true),slug:text(body.slug,200)||null,brand_id:text(body.brand,100)||null,category_id:category||null,product_type_id:type||null,
      description:text(body.description,20000)||null,usage:text(body.usage,10000)||null,identity_confirmed:body.identityConfirmed===true,
    });
    if(!rows.length) throw new AdminError('Another edit changed this product. Reload before saving.',409);
    return {ok:true};
  }
  if(action==='visibility') {
    await admin.write('products',query({id:`eq.${productId}`}), 'PATCH',{status:body.hidden===true?'archived':'draft'});return {ok:true};
  }
  if(action==='feature') {
    if(body.remove===true) await admin.write('homepage_selections',query({product_id:`eq.${productId}`,section:'eq.products'}),'DELETE');
    else await admin.write('homepage_selections',query({}),'POST',{section:'products',position:integer(body.position),product_id:productId,status:'draft'});
    return {ok:true};
  }
  if(action==='check') {
    const code=text(body.code,100,true);
    const evidenceId=body.evidenceId?identifier(body.evidenceId):null;
    await admin.write('product_checks',query({on_conflict:'product_id,code'}),'POST',{product_id:productId,code,approved:body.approved===true,evidence_id:evidenceId,approved_by:admin.userId,approved_at:new Date().toISOString()},true);return {ok:true};
  }
  if(action==='evidence') {
    const evidenceId=identifier(body.evidenceId), finding=text(body.finding,5000,true), url=text(body.url,2000);
    if(!body.concernId&&!body.facetId)throw new AdminError('Choose a concern or category-specific filter.');
    if(url && !/^https:\/\//.test(url)) throw new AdminError('Evidence URL must use HTTPS.');
    if(!['official_page','package'].includes(String(body.sourceType))) throw new AdminError('Use official manufacturer or inspected package evidence.');
    await admin.write('evidence',query({}),'POST',{id:evidenceId,source_type:body.sourceType,url:url||null,finding,status:'approved',reviewed_by:admin.userId,reviewed_at:new Date().toISOString(),accessed_on:new Date().toISOString().slice(0,10)});
    if(body.concernId) await admin.write('product_concerns',query({on_conflict:'product_id,concern_id'}),'POST',{product_id:productId,concern_id:text(body.concernId,100,true),evidence_id:evidenceId,status:'approved',qualification:finding},true);
    else {
      const facetId=text(body.facetId,100,true);
      const [definition]=await admin.read<Row<'facet_definitions'>[]>('facet_definitions',query({id:`eq.${facetId}`,select:'*'}));
      if(!definition) throw new AdminError('Unknown facet.');
      const value=text(body.value,100,true); const kind=definition.kind;
      const fields=kind==='enum'||kind==='reference'?{option_id:value}:kind==='boolean'?{boolean_value:value==='true'}:kind==='integer'?{integer_value:integer(Number(value),-2147483648)}:{decimal_value:Number(value),unit:kind==='quantity'?text(body.unit,5,true):null};
      if((kind==='decimal'||kind==='quantity')&&!Number.isFinite(Number(value))) throw new AdminError('Invalid numeric facet.');
      await admin.write('product_facets',query({}),'POST',{product_id:productId,facet_id:facetId,kind,...fields,evidence_id:evidenceId,status:'approved'});
    }
    return {ok:true};
  }
  if(action==='remove-facet') { await admin.write('product_facets',query({id:`eq.${identifier(body.id)}`,product_id:`eq.${productId}`}), 'DELETE');return {ok:true}; }
  if(action==='remove-concern') { await admin.write('product_concerns',query({concern_id:`eq.${text(body.id,100,true)}`,product_id:`eq.${productId}`}), 'DELETE');return {ok:true}; }
  if(action==='add-variant') {
    if(!product.identity_confirmed || body.confirmIdentity!==true) throw new AdminError('Confirm the product family and package identity before grouping variants.');
    await admin.write('variants',query({}),'POST',{id:identifier(body.variantId),product_id:productId,original_sku:text(body.sku,120,true),label:text(body.label,200),status:'draft'});return {ok:true};
  }
  const variantId=identifier(body.variantId);
  const [variant]=await admin.read<Row<'variants'>[]>('variants',query({id:`eq.${variantId}`,product_id:`eq.${productId}`,select:'*'}));
  if(!variant) throw new AdminError('Variant does not belong to this product.');
  if(action==='save-variant') {
    if(!['single','factory_set','unconfirmed_set'].includes(String(body.kind))) throw new AdminError('Invalid sellable type.');
    await admin.write('variants',query({id:`eq.${variantId}`}), 'PATCH',{label:text(body.label,200),identity_confirmed:body.identityConfirmed===true,sellable_kind:body.kind});return {ok:true};
  }
  if(action==='price') {
    await admin.write('variant_prices',query({on_conflict:'variant_id'}),'POST',{variant_id:variantId,amount_minor:integer(body.amountMinor,1),approved:body.approved===true,updated_at:new Date().toISOString()},true);return {ok:true};
  }
  if(action==='option') {
    await admin.write('variant_options',query({on_conflict:'variant_id,axis_id'}),'POST',{variant_id:variantId,axis_id:text(body.axis,100,true),value_id:text(body.value,100,true)},true);return {ok:true};
  }
  if(action==='stock') return {movementId:await adjustStock(token,variantId,integer(body.delta,-2147483647),text(body.reason,1000,true),identifier(body.operationId))};
  throw new AdminError('Unknown product action.');
}
