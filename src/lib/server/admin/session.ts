import 'server-only';
import { cookies } from 'next/headers';
import { randomBytes } from 'node:crypto';
import { validAdminOrigin, validCsrf } from './security';
import { authorizeAdmin } from '../database/client';
import {AdminError} from './errors';
export {AdminError} from './errors';

export const sessionCookie = 'ng_admin_session';
export const csrfCookie = 'ng_admin_csrf';
export const privateHeaders = { 'Cache-Control': 'private, no-store, max-age=0', 'X-Robots-Tag': 'noindex, nofollow', Vary: 'Cookie', 'X-Frame-Options': 'DENY' };
export const cookieOptions = { httpOnly: true, sameSite: 'strict' as const, secure: process.env.NODE_ENV !== 'development', path: '/admin' };
export async function adminSession() {
  const token = (await cookies()).get(sessionCookie)?.value;
  if (!token) throw new AdminError('Admin login required.', 401);
  try { return { token, admin: await authorizeAdmin(token) }; }
  catch { throw new AdminError('Admin session expired or access denied. Sign in again.', 401); }
}
export async function csrfValue() {
  const jar = await cookies();
  let value = jar.get(csrfCookie)?.value;
  if (!value || !/^[a-f0-9]{64}$/.test(value)) {
    value = randomBytes(32).toString('hex');
    jar.set(csrfCookie, value, { ...cookieOptions, maxAge: 3600 });
  }
  return value;
}
export async function validateMutation(request: Request) {
  if (!validAdminOrigin(request.headers.get('origin'), request.headers.get('host'), request.headers.get('sec-fetch-site'), process.env.NODE_ENV === 'development')) throw new AdminError('Cross-origin mutation rejected.', 403);
  const expected = (await cookies()).get(csrfCookie)?.value ?? '';
  const supplied = request.headers.get('x-admin-csrf') ?? '';
  if (!validCsrf(expected, supplied)) throw new AdminError('CSRF validation failed. Reload the page.', 403);
}
export async function authRequest(path: string, body?: unknown, token?: string) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) throw new AdminError('Supabase configuration unavailable.', 503);
  const response = await fetch(`${new URL(url).origin}/auth/v1/${path}`, { method: 'POST', headers: {
    apikey: key, 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}),
  }, body: body === undefined ? undefined : JSON.stringify(body), cache: 'no-store', redirect: 'error', signal: AbortSignal.timeout(15000) });
  if (!response.ok) throw new AdminError('Authentication failed. Check your account or retry later.', 401);
  const text = await response.text();
  return text ? JSON.parse(text) as { access_token: string; expires_in: number } : undefined;
}
