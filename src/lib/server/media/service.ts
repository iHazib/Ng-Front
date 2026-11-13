import 'server-only';
import { authorizeAdmin } from '../database/client';
import { boundedImageBody, destroyCloudImage, lookupCloudImage, mediaSettings, sha256, signedUpload, validateImageBytes, verifyCloudImage } from './cloudinary';
export { selectPrimaryMedia } from '../database/catalog';

interface Workflow { payment_order_id?: string | null; media_id: string; product_id: string | null; variant_id: string | null; review_id?: string | null; deal_id?: string | null; article_id?: string | null; homepage_id?: string | null; private_path: string; expected_public_id: string; association_id: string | null }
interface Asset { id: string; lifecycle: string; cloudinary_asset_id: string | null; cloudinary_cloud_name: string; media_environment: string; content_sha256: string; byte_size: number; workflow: Workflow }
const uuid = (value: string) => { if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) throw new Error('Invalid media identifier.'); return value; };
async function storage(token: string, path: string, method = 'GET', bytes?: Uint8Array) {
  const url = new URL(process.env.NEXT_PUBLIC_SUPABASE_URL ?? '');
  if (url.protocol !== 'https:' && !['localhost','127.0.0.1'].includes(url.hostname)) throw new Error('Invalid Storage URL.');
  return fetch(`${url.origin}/storage/v1/${path}`, { method,
    headers: { apikey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? '', Authorization: `Bearer ${token}`,
      ...(bytes ? { 'Content-Type': 'application/octet-stream', 'x-upsert': 'false', 'Cache-Control': 'max-age=0' } : {}) },
    body: bytes ? new Uint8Array(bytes) : undefined, cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(30000) });
}
function environment(asset: Asset) {
  if (asset.workflow.payment_order_id) throw new Error('Payment proofs use private order access and cannot be published.');
  const c = mediaSettings();
  if (asset.media_environment !== c.environment || asset.cloudinary_cloud_name !== c.cloud) throw new Error('Stored media belongs to another environment.');
}
async function getAsset(token: string, mediaId: string) {
  const admin = await authorizeAdmin(token);
  const query = new URLSearchParams({ id: `eq.${uuid(mediaId)}`, select: '*' });
  const [asset] = await admin.read<Array<Omit<Asset, 'workflow'>>>('media_assets', query);
  const [workflow] = await admin.read<Workflow[]>('media_workflows', new URLSearchParams({ media_id: `eq.${mediaId}`, select: '*' }));
  if (!asset || !workflow) throw new Error('Media intent not found.');
  const result = { ...asset, workflow }; environment(result); return { admin, asset: result };
}
async function readPrivate(token: string, asset: Asset) {
  if (['deleting','deleted'].includes(asset.lifecycle)) throw new Error('Private image is no longer available.');
  const response = await storage(token, `object/authenticated/catalog-private/${asset.workflow.private_path}`);
  if (!response.ok) throw new Error('Private image unavailable.');
  const bytes = await boundedImageBody(response);
  validateImageBytes(bytes);
  if (bytes.length !== asset.byte_size || sha256(bytes) !== asset.content_sha256) throw new Error('Private image differs from upload intent.');
  return bytes;
}

/** Caller supplies a stable UUID per upload attempt; retries must reuse it. */
export async function uploadPendingMedia(token: string, input: { mediaId: string; dealId?: string; productId?: string; variantId?: string; articleId?: string; homepageId?: string; kind?: string; alt: string; replaceAssociationId?: string }, bytes: Uint8Array) {
  const admin = await authorizeAdmin(token);
  validateImageBytes(bytes); const c = mediaSettings();
  if([input.productId,input.articleId,input.homepageId,input.dealId].filter(Boolean).length!==1||(!input.productId&&input.variantId))throw new Error('Choose one image owner.');
  const intent = await admin.rpc<{ media_id: string; lifecycle: string; private_path: string }>(input.dealId?'create_deal_upload':input.productId?'create_media_upload':'create_content_media_upload', {
    p_id: uuid(input.mediaId), ...(input.dealId?{p_deal:uuid(input.dealId)}:input.productId?{p_product:uuid(input.productId),p_variant:input.variantId?uuid(input.variantId):null}:{p_article:input.articleId?uuid(input.articleId):null,p_homepage:input.homepageId?uuid(input.homepageId):null,p_kind:input.kind}),
    p_environment: c.environment, p_cloud: c.cloud, p_hash: sha256(bytes), p_bytes: bytes.length, p_alt: input.alt,
    p_replace: input.replaceAssociationId ? uuid(input.replaceAssociationId) : null,
  });
  if (intent.lifecycle !== 'private_uploading' && intent.lifecycle !== 'failed') return { mediaId: input.mediaId, lifecycle: intent.lifecycle };
  try {
    const uploaded = await storage(token, `object/catalog-private/${intent.private_path}`, 'POST', bytes);
    // On timeout/duplicate retries, read back the immutable UUID path rather than overwrite.
    if (!uploaded.ok && ![400,409].includes(uploaded.status)) throw new Error('Private upload failed.');
    const { asset } = await getAsset(token, input.mediaId);
    await readPrivate(token, asset);
    await admin.rpc('media_workflow_action', { p_id: input.mediaId, p_action: 'private_uploaded' });
    return { mediaId: input.mediaId, lifecycle: 'private_pending' };
  } catch {
    await admin.rpc('media_workflow_action', { p_id: input.mediaId, p_action: 'failed' });
    throw new Error('Private upload incomplete; retry with the same media UUID and bytes.');
  }
}

export async function approveMediaForPublication(token: string, mediaId: string) {
  const { admin, asset } = await getAsset(token, mediaId);
  await readPrivate(token, asset);
  // Explicit administrator review action, never performed automatically on upload.
  await admin.rpc('media_workflow_action', { p_id: mediaId, p_action: 'approve' });
}

/** Idempotent completion/reconciliation; callback metadata is deliberately not accepted. */
export async function publishApprovedMedia(token: string, mediaId: string) {
  const { admin, asset } = await getAsset(token, mediaId);
  if (asset.lifecycle === 'linked') return { mediaId, associationId: asset.workflow.association_id };
  await admin.rpc('media_workflow_action', { p_id: mediaId, p_action: 'begin_publish' });
  try {
    const bytes = await readPrivate(token, asset);
    if (!await lookupCloudImage(asset.workflow.expected_public_id)) await signedUpload(asset.workflow.expected_public_id, bytes);
    const verified = await verifyCloudImage(asset.workflow.expected_public_id, asset.content_sha256, asset.byte_size);
    const linked = await admin.rpc<Asset>('media_workflow_action', { p_id: mediaId, p_action: 'complete', p_result: verified });
    return { mediaId, associationId: linked.workflow.association_id };
  } catch {
    await admin.rpc('media_workflow_action', { p_id: mediaId, p_action: 'failed' });
    throw new Error('Publication incomplete; retry reconciliation with the same media UUID.');
  }
}

export async function reorderMedia(token: string, productId: string, variantId: string | null, associationIds: string[]) {
  const admin = await authorizeAdmin(token);
  await admin.rpc('reorder_product_media', { p_product: uuid(productId), p_variant: variantId ? uuid(variantId) : null, p_ids: associationIds.map(uuid) });
}
export async function detachMedia(token: string, mediaId: string) {
  const { admin } = await getAsset(token, mediaId);
  await admin.rpc('media_workflow_action', { p_id: mediaId, p_action: 'detach' });
}

export async function getPrivateReviewImage(token: string, mediaId: string) {
  const { asset } = await getAsset(token, mediaId);
  const bytes = await readPrivate(token, asset);
  return { bytes, format: validateImageBytes(bytes) };
}

export async function getMediaRecoveryCandidates(token: string) {
  const admin = await authorizeAdmin(token); const c = mediaSettings();
  return admin.read<Array<{ id: string; lifecycle: string }>>('media_assets', new URLSearchParams({
    select: 'id,lifecycle', media_environment: `eq.${c.environment}`, cloudinary_cloud_name: `eq.${c.cloud}`,
    lifecycle: 'in.(private_uploading,uploading,failed,retired,deleting)', limit: '100', order: 'created_at.asc',
  }));
}

/** Explicit bounded cleanup, not an unscoped folder sweep. Referenced assets refuse deletion. */
export async function cleanupOrphanMedia(token: string, mediaId: string) {
  const { admin, asset } = await getAsset(token, mediaId);
  const claimed = await admin.rpc<Asset>('media_workflow_action', { p_id: mediaId, p_action: 'claim_cleanup' });
  if (claimed.lifecycle === 'deleted') return;
  await destroyCloudImage(asset.workflow.expected_public_id, asset.cloudinary_asset_id);
  const url = new URL(process.env.NEXT_PUBLIC_SUPABASE_URL ?? '');
  const response = await fetch(`${url.origin}/storage/v1/object/catalog-private`, {
    method: 'DELETE', headers: { apikey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? '', Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ prefixes: [asset.workflow.private_path] }), redirect: 'error', signal: AbortSignal.timeout(30000),
  });
  if (!response.ok) throw new Error('Private cleanup incomplete; retry same media UUID.');
  // Downloads can briefly remain cached after deletion. Check the authoritative
  // object listing, not a CDN-served download, before recording the tombstone.
  const slash = asset.workflow.private_path.lastIndexOf('/');
  const name = asset.workflow.private_path.slice(slash + 1);
  const remaining = await fetch(`${url.origin}/storage/v1/object/list/catalog-private`, {
    method: 'POST', headers: { apikey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? '', Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ prefix: asset.workflow.private_path.slice(0, slash), search: name, limit: 100 }),
    cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(30000),
  });
  if (!remaining.ok) throw new Error('Private deletion not confirmed; retry same media UUID.');
  const objects: unknown = await remaining.json();
  if (!Array.isArray(objects) || objects.some(object => !object || typeof object.name !== 'string' || object.name === name)) throw new Error('Private deletion not confirmed; retry same media UUID.');
  await admin.rpc('media_workflow_action', { p_id: mediaId, p_action: 'deleted' });
}
