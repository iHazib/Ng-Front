// Shared SEO environment policy. No secrets and no assumed production domain.
// This module is intentionally free of `server-only` so the request proxy can use
// the same indexing decision as metadata, robots and sitemap routes.

export function siteUrl(value: string | undefined = process.env.SITE_URL): URL | undefined {
  if (!value) return undefined;
  const url = new URL(value);
  if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash) {
    throw new Error('SITE_URL must be an approved HTTPS URL without credentials, query or fragment.');
  }
  return url;
}

export function siteOrigin(): string | undefined {
  return siteUrl()?.origin;
}

/**
 * Indexing requires all three facts:
 * 1. a production runtime,
 * 2. an explicit owner launch decision (`SEARCH_INDEXING=approved`),
 * 3. a real HTTPS `SITE_URL` used for canonical and sitemap URLs.
 *
 * Preview, staging, local development and production-without-launch stay
 * noindex even when pages have indexable content.
 */
export function indexingApproved(): boolean {
  if (process.env.NODE_ENV !== 'production') return false;
  if (process.env.APP_ENV !== 'production') return false;
  if (process.env.SEARCH_INDEXING !== 'approved') return false;
  try {
    return Boolean(siteUrl());
  } catch {
    return false;
  }
}

export function canonicalUrl(path: string): string | undefined {
  const origin = siteOrigin();
  if (!origin || !path.startsWith('/') || path.startsWith('//') || /[?#]/.test(path)) return undefined;
  const url = new URL(path, origin);
  return url.origin === origin ? url.href : undefined;
}
