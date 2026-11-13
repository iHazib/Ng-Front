import 'server-only';

/** Server-only Supabase HTTP client. Uses the caller's verified Auth token, never a service-role bypass. */
function settings() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) throw new Error('Supabase test/project URL and publishable key are not configured.');
  const parsed = new URL(url);
  const local = ['localhost', '127.0.0.1', '[::1]'].includes(parsed.hostname);
  if ((parsed.protocol !== 'https:' && !(local && parsed.protocol === 'http:')) || parsed.username || parsed.password || parsed.search || parsed.hash) {
    throw new Error('Invalid Supabase server URL.');
  }
  return { url: parsed.origin, key };
}

async function request<T>(path: string, token: string | undefined, init: RequestInit = {}): Promise<T> {
  const { url, key } = settings();
  const headers = new Headers(init.headers);
  headers.set('apikey', key);
  headers.set('Content-Type', 'application/json');
  if (token) headers.set('Authorization', `Bearer ${token}`);
  const response = await fetch(`${url}${path}`, { ...init, headers, cache: 'no-store', signal: AbortSignal.timeout(15000) });
  // Never log provider payloads, tokens, customer data or request bodies.
  if (!response.ok) throw new Error(`Database request failed (${response.status}).`);
  if (response.status === 204) return undefined as T;
  const text = await response.text();
  return (text ? JSON.parse(text) : undefined) as T;
}

export async function authorizeAdmin(accessToken: string) {
  if (!accessToken || accessToken.length > 16384 || /[\r\n]/.test(accessToken)) throw new Error('A valid Supabase Auth session is required.');
  const user = await request<{ id?: string }>('/auth/v1/user', accessToken);
  if (!user.id) throw new Error('Supabase Auth session is invalid.');
  const admin = await request<boolean>('/rest/v1/rpc/is_admin', accessToken, { method: 'POST', body: '{}' });
  if (admin !== true) throw new Error('Administrator access required.');
  // Context is local to this call; tokens are not returned to callers or stored globally.
  return {
    userId: user.id,
    rpc: <T>(name: string, args: Record<string, unknown>) => request<T>(`/rest/v1/rpc/${name}`, accessToken, { method: 'POST', body: JSON.stringify(args) }),
    read: <T>(table: string, query: URLSearchParams) => request<T>(`/rest/v1/${table}?${query}`, accessToken),
    // Callers are server-only, with explicit table/field allowlists in the admin DAL.
    write: <T>(table: string, query: URLSearchParams, method: 'POST' | 'PATCH' | 'DELETE', body?: unknown, upsert = false) => request<T>(`/rest/v1/${table}?${query}`, accessToken, {
      method, headers: { Prefer: `return=representation${upsert ? ',resolution=merge-duplicates' : ''}` },
      body: body === undefined ? undefined : JSON.stringify(body),
    }),
  };
}

export async function searchPublishedCatalog(query: string) {
  return request<Array<{ product_id: string; name: string; slug: string }>>('/rest/v1/rpc/search_published_catalog', undefined, {
    method: 'POST', body: JSON.stringify({ p_query: query.slice(0, 160), p_limit: 30 }),
  });
}
