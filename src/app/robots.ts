import type { MetadataRoute } from 'next';
import { indexingApproved, siteOrigin } from '@/lib/seo/site';

export const dynamic = 'force-dynamic';

export default function robots(): MetadataRoute.Robots {
  const origin = siteOrigin();
  if (!indexingApproved() || !origin) {
    return { rules: { userAgent: '*', disallow: '/' } };
  }
  return {
    rules: {
      userAgent: '*',
      allow: '/',
      disallow: ['/admin', '/admin/', '/api/', '/search', '/cart', '/checkout', '/order-confirmation/', '/reference'],
    },
    sitemap: new URL('/sitemap.xml', origin).href,
  };
}
