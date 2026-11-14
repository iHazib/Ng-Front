import { NextRequest, NextResponse } from 'next/server';
import { previewAccess } from '@/lib/server/preview-access';
import { indexingApproved } from '@/lib/seo/site';

export function proxy(request: NextRequest) {
  const path = request.nextUrl.pathname;
  // robots.txt and the brand icon are always public: while unapproved, robots
  // disallows the whole site. sitemap.xml becomes public only after an explicit,
  // production-approved launch.
  if (path === '/robots.txt' || path === '/icon.svg' || (path === '/sitemap.xml' && indexingApproved())) return NextResponse.next();
  // Reject before streaming the catch-all layout; no reference route in a production build.
  if (process.env.NODE_ENV !== 'development' && (path === '/reference' || path.startsWith('/reference/'))) {
    return new NextResponse('Not found.', { status: 404, headers: { 'Cache-Control': 'private, no-store', 'X-Robots-Tag': 'noindex, nofollow' } });
  }
  const access = previewAccess(request.headers.get('authorization'));
  if (access !== 'allowed') {
    return new NextResponse(access === 'unconfigured' ? 'Preview access is not configured.' : 'Preview authentication required.', {
      status: access === 'unconfigured' ? 503 : 401,
      headers: { 'Cache-Control': 'private, no-store', 'X-Robots-Tag': 'noindex, nofollow, noarchive',
        ...(access === 'unauthorized' ? { 'WWW-Authenticate': 'Basic realm="Nook and Glow preview", charset="UTF-8"' } : {}) },
    });
  }
  const response = NextResponse.next();
  response.headers.set('Cache-Control', 'private, no-store');
  if (!indexingApproved()) response.headers.set('X-Robots-Tag', 'noindex, nofollow, noarchive');
  return response;
}

// Protect static assets too, not just HTML; robots remains openly crawlable.
export const config = { matcher: '/:path*' };
