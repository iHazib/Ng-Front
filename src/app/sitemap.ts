import type { MetadataRoute } from 'next';
import { indexingApproved, siteOrigin } from '@/lib/seo/site';
import { publicCatalog, publicNavigation } from '@/lib/server/storefront/catalog';
import { publicArticles } from '@/lib/server/content/public';
import { publicDeals } from '@/lib/server/storefront/deals';
import { rootRoutes } from '@/lib/catalog/public-types';

export const dynamic = 'force-dynamic';

const maxPages = 20;

type Entry = MetadataRoute.Sitemap[number];

function slugPattern(kind: 'product' | 'article' | 'deal'): RegExp {
  return kind === 'deal' ? /^[a-z0-9]+(-[a-z0-9]+)*$/ : /^[a-z0-9]+(-[a-z0-9]+)*$/;
}

/**
 * Only canonical, genuinely indexable URLs belong here. Drafts, private routes,
 * search/filter/sort views, care placeholders and preview content are omitted.
 * `lastModified` is emitted only where the public RPC exposes a real timestamp
 * (articles); product and deal RPCs do not, so no synthetic dates are invented.
 */
export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const origin = siteOrigin();
  if (!indexingApproved() || !origin) return [];
  const entries = new Map<string, Entry>();
  const add = (path: string, lastModified?: string) => {
    const url = new URL(path, origin).href;
    if (entries.has(url)) return;
    entries.set(url, { url, ...(lastModified ? { lastModified } : {}) });
  };

  add('/');

  try {
    const navigation = await publicNavigation();
    if (navigation.brands.some((brand) => brand.count > 0)) add('/brands');
    for (const brand of navigation.brands) {
      if (brand.count > 0 && /^[a-z0-9-]+$/.test(brand.id)) add(`/brands/${brand.id}`);
    }
  } catch {
    // A taxonomy outage must not block static sitemap entries.
  }

  for (const path of Object.keys(rootRoutes)) {
    try {
      const result = await publicCatalog(path, '{}');
      if (result.total > 0) add(`/${path}`);
    } catch {
      // Skip the unavailable collection, never emit a guessed count.
    }
  }

  try {
    const first = await publicCatalog('search', JSON.stringify({ page: 1 }));
    const pages = Math.min(maxPages, Math.max(1, Math.ceil(first.total / Math.max(1, first.size))));
    for (let page = 1; page <= pages; page++) {
      const result = page === 1 ? first : await publicCatalog('search', JSON.stringify({ page }));
      for (const product of result.products) {
        if (slugPattern('product').test(product.slug)) add(`/products/${product.slug}`);
      }
    }
  } catch {
    // Products unavailable: leave them out rather than serve stale rows.
  }

  try {
    const first = await publicArticles(undefined, false, 1);
    if (first.total > 0) add('/the-edit');
    const pages = Math.min(maxPages, Math.ceil(first.total / 12));
    for (let page = 1; page <= pages; page++) {
      const result = page === 1 ? first : await publicArticles(undefined, false, page);
      for (const article of result.articles) {
        if (!article.slug || !slugPattern('article').test(article.slug)) continue;
        const date = article.publishedAt && !Number.isNaN(Date.parse(article.publishedAt)) ? article.publishedAt : undefined;
        add(`/the-edit/${article.slug}`, date);
      }
    }
  } catch {
    // Editorial unavailable: keep the sitemap valid and honest.
  }

  try {
    const first = await publicDeals({ page: 1 });
    if (first.total > 0) add('/deals');
    const pages = Math.min(maxPages, Math.ceil(first.total / 24));
    for (let page = 1; page <= pages; page++) {
      const result = page === 1 ? first : await publicDeals({ page });
      for (const deal of result.deals) {
        if (slugPattern('deal').test(deal.slug)) add(`/deals/${deal.slug}`);
      }
    }
  } catch {
    // Deals unavailable: do not list unpublished or unknown deals.
  }

  return [...entries.values()];
}
