import 'server-only';
import { timingSafeEqual } from 'node:crypto';
/** Host is the actual HTTP Host, never x-forwarded-host. No wildcard origins. */
export function validAdminOrigin(origin: string | null, host: string | null, fetchSite: string | null, development: boolean) {
  if (fetchSite === 'cross-site') return false;
  try {
    const parsed = new URL(origin ?? '');
    return parsed.origin === origin && parsed.host === host && ['http:', 'https:'].includes(parsed.protocol) && (development || parsed.protocol === 'https:');
  } catch { return false; }
}
export function validCsrf(expected: string, supplied: string) {
  return /^[a-f0-9]{64}$/.test(expected) && /^[a-f0-9]{64}$/.test(supplied) && timingSafeEqual(Buffer.from(expected), Buffer.from(supplied));
}
export async function boundedJson(request: Request, limit = 50000): Promise<Record<string, unknown>> {
  const reader = request.body?.getReader(); if (!reader) throw new Error('Body required.');
  let size = 0; const chunks: Uint8Array[] = [];
  try {
    while (true) { const next = await reader.read(); if (next.done) break; size += next.value.byteLength;
      if (size > limit) { await reader.cancel(); throw new Error('Request body too large.'); } chunks.push(next.value);
    }
  } finally { reader.releaseLock(); }
  const data: unknown = JSON.parse(Buffer.concat(chunks).toString('utf8'));
  if (!data || Array.isArray(data) || typeof data !== 'object') throw new Error('Object required.');
  return data as Record<string, unknown>;
}
