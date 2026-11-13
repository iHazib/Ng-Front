import { boundedJson } from '@/lib/server/admin/security';
import { cookies } from 'next/headers';
import { authorizeAdmin } from '@/lib/server/database/client';
import { AdminError, authRequest, cookieOptions, csrfCookie, csrfValue, privateHeaders, sessionCookie, validateMutation } from '@/lib/server/admin/session';
export const dynamic = 'force-dynamic';
export async function GET() { return Response.json({ csrf: await csrfValue() }, { headers: privateHeaders }); }
export async function POST(request: Request) {
  try {
    await validateMutation(request);
    const body = await boundedJson(request, 4096);
    const jar = await cookies();
    if (body.action === 'logout') {
      const token = jar.get(sessionCookie)?.value;
      // Always clear browser credentials, including an expired/revoked session.
      jar.set(sessionCookie, '', { ...cookieOptions, maxAge: 0 });
      jar.set(csrfCookie, '', { ...cookieOptions, maxAge: 0 });
      if (token) { try { await authRequest('logout?scope=local', undefined, token); } catch { /* Browser session still cleared. */ } }
      return Response.json({ ok: true }, { headers: privateHeaders });
    }
    if (typeof body.email !== 'string' || body.email.length > 254 || typeof body.password !== 'string' || body.password.length > 1024) throw new AdminError('Email and password required.');
    const login = await authRequest('token?grant_type=password', { email: body.email, password: body.password });
    if (!login?.access_token) throw new AdminError('Login failed.', 401);
    try { await authorizeAdmin(login.access_token); } catch {
      await authRequest('logout?scope=local', undefined, login.access_token).catch(() => undefined);
      throw new AdminError('Administrator access required.', 403);
    }
    // Short-lived, HTTP-only host cookie. No refresh token is stored or returned.
    jar.set(sessionCookie, login.access_token, { ...cookieOptions, maxAge: Math.min(login.expires_in, 3600) });
    jar.set(csrfCookie, '', { ...cookieOptions, maxAge: 0 });
    return Response.json({ ok: true }, { headers: privateHeaders });
  } catch (error) {
    return Response.json({ error: error instanceof AdminError ? error.message : 'Authentication unavailable.' }, { status: error instanceof AdminError ? error.status : 503, headers: privateHeaders });
  }
}
