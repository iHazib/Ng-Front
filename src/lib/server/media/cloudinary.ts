import 'server-only';
import { createHash } from 'node:crypto';

export function mediaSettings() {
  const cloud = process.env.CLOUDINARY_CLOUD_NAME;
  const key = process.env.CLOUDINARY_API_KEY;
  const secret = process.env.CLOUDINARY_API_SECRET;
  const environment = process.env.MEDIA_ENVIRONMENT;
  if (!cloud || !/^[a-zA-Z0-9_-]+$/.test(cloud) || !key || !secret
    || !['development', 'staging', 'production'].includes(environment ?? '')) throw new Error('Media provider configuration is incomplete.');
  return { cloud, key, secret, environment: environment as 'development' | 'staging' | 'production' };
}

/** Cloudinary signs alphabetically sorted parameters + secret, not HMAC. */
export function signParameters(params: Record<string, string>, secret: string) {
  return createHash('sha256').update(Object.keys(params).sort().map(key => `${key}=${params[key]}`).join('&') + secret).digest('hex');
}
export const sha256 = (bytes: Uint8Array) => createHash('sha256').update(bytes).digest('hex');
export async function boundedImageBody(response: Response): Promise<Uint8Array> {
  if (!response.body) throw new Error('Image response is empty.');
  const reader = response.body.getReader(); const chunks: Uint8Array[] = []; let length = 0;
  try {
    while (true) {
      const part = await reader.read(); if (part.done) break;
      length += part.value.length;
      if (length > 10485760) { await reader.cancel(); throw new Error('Image response exceeds size limit.'); }
      chunks.push(part.value);
    }
  } finally { reader.releaseLock(); }
  return new Uint8Array(Buffer.concat(chunks));
}
export function validateImageBytes(bytes: Uint8Array): 'png' | 'jpg' | 'webp' {
  if (!bytes.length || bytes.length > 10 * 1024 * 1024) throw new Error('Image must be between 1 byte and 10 MiB.');
  const b = Buffer.from(bytes);
  if (b.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) return 'png';
  if (b[0] === 255 && b[1] === 216 && b[2] === 255) return 'jpg';
  if (b.toString('ascii', 0, 4) === 'RIFF' && b.toString('ascii', 8, 12) === 'WEBP') return 'webp';
  throw new Error('Only PNG, JPEG and WebP image files are accepted.');
}

export interface VerifiedCloudImage {
  asset_id: string; public_id: string; version: number; width: number; height: number;
  format: 'jpg' | 'png' | 'webp'; resource_type: 'image'; type: 'upload'; bytes: number; sha256: string;
}
export function validateCloudMetadata(value: unknown, publicId: string, bytes: number): Omit<VerifiedCloudImage, 'sha256'> {
  if (!value || typeof value !== 'object') throw new Error('Invalid provider metadata.');
  const r = value as Record<string, unknown>;
  if (r.public_id !== publicId || r.resource_type !== 'image' || r.type !== 'upload'
    || typeof r.asset_id !== 'string' || !/^[a-zA-Z0-9_-]+$/.test(r.asset_id)
    || !Number.isSafeInteger(r.version) || Number(r.version) < 1
    || !['jpg','png','webp'].includes(String(r.format)) || r.bytes !== bytes
    || !Number.isInteger(r.width) || !Number.isInteger(r.height)
    || Number(r.width) < 1 || Number(r.height) < 1 || Number(r.width) > 12000 || Number(r.height) > 12000
    || Number(r.width) * Number(r.height) > 40000000 || (r.pages !== undefined && r.pages !== 1)) throw new Error('Provider image validation failed.');
  return { asset_id: r.asset_id, public_id: publicId, version: Number(r.version), width: Number(r.width), height: Number(r.height),
    format: r.format as VerifiedCloudImage['format'], resource_type: 'image', type: 'upload', bytes };
}

function canonicalId(publicId: string) {
  const config = mediaSettings();
  if (!new RegExp(`^nook-glow/${config.environment}/[0-9a-f-]{36}$`).test(publicId)) throw new Error('Media environment/identity mismatch.');
  return config;
}
export async function lookupCloudImage(publicId: string): Promise<unknown | null> {
  const c = canonicalId(publicId);
  const response = await fetch(`https://api.cloudinary.com/v1_1/${c.cloud}/resources/image/upload/${encodeURIComponent(publicId)}`, {
    headers: { Authorization: `Basic ${Buffer.from(`${c.key}:${c.secret}`).toString('base64')}` },
    cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(20000),
  });
  if (response.status === 404) return null;
  if (!response.ok) throw new Error(`Provider lookup failed (${response.status}).`);
  return response.json();
}

/** No signature endpoint: approval binds publication to the exact private bytes. */
export async function signedUpload(publicId: string, bytes: Uint8Array) {
  const c = canonicalId(publicId);
  const format = validateImageBytes(bytes);
  const params: Record<string, string> = { public_id: publicId, timestamp: String(Math.floor(Date.now() / 1000)),
    overwrite: 'false', type: 'upload', allowed_formats: 'jpg,png,webp',
    tags: `nook-glow,${c.environment}`, asset_folder: `nook-glow/${c.environment}` };
  const body = new FormData();
  for (const [key, value] of Object.entries(params)) body.set(key, value);
  body.set('api_key', c.key); body.set('signature', signParameters(params, c.secret));
  body.set('file', new Blob([new Uint8Array(bytes)], { type: `image/${format === 'jpg' ? 'jpeg' : format}` }), `image.${format}`);
  const response = await fetch(`https://api.cloudinary.com/v1_1/${c.cloud}/image/upload`, {
    method: 'POST', body, redirect: 'error', signal: AbortSignal.timeout(60000),
  });
  if (!response.ok) throw new Error(`Provider upload failed (${response.status}).`);
  // Never trust browser callbacks or the upload response as completion evidence.
  await response.arrayBuffer();
}

export async function verifyCloudImage(publicId: string, expectedHash: string, bytes: number): Promise<VerifiedCloudImage> {
  const c = canonicalId(publicId);
  const verified = validateCloudMetadata(await lookupCloudImage(publicId), publicId, bytes);
  const response = await fetch(`https://res.cloudinary.com/${c.cloud}/image/upload/v${verified.version}/${publicId}.${verified.format}`, {
    cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(30000),
  });
  if (!response.ok) throw new Error('Original image delivery verification failed.');
  const original = await boundedImageBody(response);
  if (original.byteLength !== bytes || sha256(original) !== expectedHash) throw new Error('Original image bytes differ from reviewed source.');
  return { ...verified, sha256: expectedHash };
}

export async function destroyCloudImage(publicId: string, expectedAssetId?: string | null) {
  const c = canonicalId(publicId);
  const existing = await lookupCloudImage(publicId) as { asset_id?: string } | null;
  if (!existing) return;
  if (expectedAssetId && existing.asset_id !== expectedAssetId) throw new Error('Provider identity changed; deletion blocked.');
  const params = { public_id: publicId, timestamp: String(Math.floor(Date.now() / 1000)), invalidate: 'true', type: 'upload' };
  const body = new URLSearchParams({ ...params, api_key: c.key, signature: signParameters(params, c.secret) });
  const response = await fetch(`https://api.cloudinary.com/v1_1/${c.cloud}/image/destroy`, { method: 'POST', body, redirect: 'error', signal: AbortSignal.timeout(30000) });
  if (!response.ok) throw new Error('Provider cleanup failed.');
  const result = await response.json() as { result?: string };
  if (!['ok','not found'].includes(result.result ?? '')) throw new Error('Provider cleanup not confirmed.');
  if (await lookupCloudImage(publicId)) throw new Error('Provider deletion still pending; retry cleanup.');
}
