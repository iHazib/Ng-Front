import 'server-only';
import {AdminError} from '../admin/errors';
import { authorizeAdmin } from './client';
import type { Json, Row } from './database.types';

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function id(value: string) { if (!uuid.test(value)) throw new Error('Invalid identifier.'); return value; }
function minorUnits(value: number) { if (!Number.isSafeInteger(value)) throw new Error('Integer minor units required.'); return value; }

export async function searchAdminCatalog(token:string,query:string,offset=0,status=''){
 const admin=await authorizeAdmin(token);
 if(!['','draft','published','archived'].includes(status))throw new Error('Invalid visibility filter.');
 try{return await admin.rpc<Array<{product_id:string;variant_id:string;original_sku:string;name:string;status:Row<'products'>['status'];price_minor:number|null;stock:number|null;media_id:string|null}>>('admin_product_list',{p_query:query.slice(0,160),p_offset:Math.min(100000,Math.max(0,Math.trunc(offset))),p_status:status});}catch(error){if(error instanceof Error&&error.message==='Database request failed (404).')throw new AdminError('Product list update is not installed. Apply and verify migration 012, then refresh.',503);throw error;}
}

export async function getAdminProduct(token: string, productId: string) {
  const admin = await authorizeAdmin(token);
  const query = new URLSearchParams({ id: `eq.${id(productId)}`, select: 'id,name,slug,brand_id,category_id,product_type_id,status,description,usage,revision' });
  return admin.read<Array<Pick<Row<'products'>, 'id' | 'name' | 'slug' | 'brand_id' | 'category_id' | 'product_type_id' | 'status' | 'description' | 'usage' | 'revision'>>>('products', query);
}

export async function getPublicationReport(token: string, productId: string) {
  const admin = await authorizeAdmin(token);
  return admin.rpc<{ essential_blockers: string[]; optional_enrichment: string[]; concern_research: 'partially_complete' }>('publication_report', { p_product: id(productId) });
}

export type DraftImport = { p_source_hash: string; p_contract_hash: string; p_version: string; p_records: Json[] };
export async function importAdminDrafts(token: string, payload: DraftImport) {
  const admin = await authorizeAdmin(token);
  if (![payload.p_source_hash, payload.p_contract_hash].every(v => /^[a-f0-9]{64}$/.test(v)) || !payload.p_version || payload.p_records.length > 5000) throw new Error('Invalid import envelope.');
  return admin.rpc<{ batch_id: string; state?: string; accepted?: number; quarantined?: number }>('import_catalog_drafts', payload);
}

export async function selectPrimaryMedia(token: string, productId: string, variantId: string | null, mediaId: string) {
  const admin = await authorizeAdmin(token);
  return admin.rpc<null>('set_primary_media', { p_product: id(productId), p_variant: variantId ? id(variantId) : null, p_media: id(mediaId) });
}

export async function adjustStock(token: string, variantId: string, delta: number, reason: string, operationId: string) {
  const admin = await authorizeAdmin(token);
  if (!reason.trim() || !operationId.trim() || !Number.isSafeInteger(delta) || !delta || Math.abs(delta) > 2147483647) throw new Error('Invalid stock adjustment.');
  return admin.rpc<string>('adjust_inventory', { p_variant: id(variantId), p_delta: delta, p_reason: reason, p_key: operationId });
}

/** Display/reporting helper only. No floating-point major-unit price is accepted by writes. */
export function formatPkrMinor(amount: number) {
  return new Intl.NumberFormat('en-PK', { style: 'currency', currency: 'PKR',minimumFractionDigits:2,maximumFractionDigits:2 }).format(minorUnits(amount) / 100);
}
