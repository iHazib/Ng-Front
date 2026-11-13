import 'server-only';

export type RedirectKind = 'product' | 'article' | 'deal' | 'brand';

const slugPattern = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const prefixes: Record<RedirectKind, string> = {
  product: '/products/',
  article: '/the-edit/',
  deal: '/deals/',
  brand: '/brands/',
};

/**
 * Resolve an explicit legacy slug before rendering a 404. The database function
 * only returns a target that is still public. A missing migration or unavailable
 * API returns null; unknown routes then keep their real 404 instead of a guess.
 */
export async function slugRedirect(kind: RedirectKind, slug: string): Promise<string | null> {
  if (!slugPattern.test(slug)) return null;
  try {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
    if (!url || !key) return null;
    const response = await fetch(new URL('/rest/v1/rpc/storefront_slug_redirect', url), {
      method: 'POST',
      headers: { apikey: key, 'Content-Type': 'application/json' },
      body: JSON.stringify({ p_kind: kind, p_slug: slug }),
      cache: 'no-store',
      redirect: 'error',
      signal: AbortSignal.timeout(4000),
    });
    if (!response.ok) return null;
    const data: unknown = await response.json();
    if (typeof data !== 'string') return null;
    if (!data.startsWith(prefixes[kind]) || data.includes('//') || data.includes('\\')) return null;
    return data;
  } catch {
    return null;
  }
}
