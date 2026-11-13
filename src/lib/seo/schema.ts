import { site } from '@/config/site';
import { resolveMedia } from '@/lib/catalog/media';
import type { Article } from '@/lib/catalog/content-types';
import type { PublicDeal } from '@/lib/catalog/deals';
import type { PublicProduct } from '@/lib/catalog/public-types';
import type { ReviewResult } from '@/lib/catalog/review-types';
import { canonicalUrl } from './site';
import { plainText } from './plain-text';
import type { MetadataImage } from './metadata';

type BreadcrumbItem = { label: string; href?: string };

function absolute(src: string, origin: string): string | undefined {
  try {
    const url = new URL(src, origin);
    return url.protocol === 'https:' ? url.href : undefined;
  } catch {
    return undefined;
  }
}

export function mediaImage(media: Parameters<typeof resolveMedia>[0] | undefined, origin: string): MetadataImage | undefined {
  if (!media) return undefined;
  try {
    const resolved = resolveMedia(media);
    const url = absolute(resolved.src, origin);
    if (!url) return undefined;
    return {
      url,
      ...(resolved.width ? { width: resolved.width } : {}),
      ...(resolved.height ? { height: resolved.height } : {}),
      alt: resolved.alt,
    };
  } catch {
    return undefined;
  }
}

export function productImage(product: PublicProduct, origin: string): MetadataImage | undefined {
  for (const variant of product.variants) {
    for (const image of variant.media) {
      const result = mediaImage(image, origin);
      if (result) return result;
    }
  }
  return undefined;
}

export function breadcrumbJsonLd(items: BreadcrumbItem[], currentPath: string) {
  const origin = siteImageOrigin();
  if (!origin) return null;
  const url = canonicalUrl(currentPath);
  if (!url) return null;
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((item, index) => ({
      '@type': 'ListItem',
      position: index + 1,
      name: item.label,
      item: item.href ? absolute(item.href, origin) ?? url : url,
    })),
  };
}

function siteImageOrigin(): string | undefined {
  try {
    const parsed = new URL(process.env.SITE_URL ?? '');
    if (parsed.protocol !== 'https:' || parsed.username || parsed.password) return undefined;
    return parsed.origin;
  } catch {
    return undefined;
  }
}

export function productJsonLd(product: PublicProduct, reviews?: ReviewResult | null) {
  const origin = siteImageOrigin();
  const url = canonicalUrl(`/products/${product.slug}`);
  if (!origin || !url) return null;
  const variants = product.variants.filter((variant) => Number.isSafeInteger(variant.priceMinor) && variant.priceMinor >= 0);
  if (!variants.length) return null;
  const prices = variants.map((variant) => variant.priceMinor / 100);
  const inStock = variants.some((variant) => variant.available > 0);
  const description = plainText(product.description, 500) || `${product.name} by ${product.brand}.`;
  const image = productImage(product, origin);
  const approvedReviews = reviews && reviews.total > 0
    ? reviews.reviews.filter((review) => review.rating >= 1 && review.rating <= 5 && review.body.trim())
    : [];
  return {
    '@context': 'https://schema.org',
    '@type': 'Product',
    name: product.name,
    description,
    ...(image ? { image: [image.url] } : {}),
    ...(product.brand ? { brand: { '@type': 'Brand', name: product.brand } } : {}),
    ...(product.category ? { category: product.category } : {}),
    ...(variants.length === 1 ? { sku: variants[0].sku } : {}),
    offers: {
      '@type': 'AggregateOffer',
      url,
      priceCurrency: site.currency,
      lowPrice: Math.min(...prices),
      highPrice: Math.max(...prices),
      offerCount: variants.length,
      availability: inStock ? 'https://schema.org/InStock' : 'https://schema.org/OutOfStock',
    },
    ...(reviews?.average != null && reviews.total > 0
      ? {
          aggregateRating: {
            '@type': 'AggregateRating',
            ratingValue: reviews.average,
            reviewCount: reviews.total,
            bestRating: 5,
            worstRating: 1,
          },
        }
      : {}),
    ...(approvedReviews.length
      ? {
          review: approvedReviews.slice(0, 5).map((review) => ({
            '@type': 'Review',
            author: { '@type': 'Person', name: review.name },
            datePublished: review.createdAt,
            ...(review.title ? { name: review.title } : {}),
            reviewBody: review.body,
            reviewRating: { '@type': 'Rating', ratingValue: review.rating, bestRating: 5, worstRating: 1 },
          })),
        }
      : {}),
  };
}

export function articleJsonLd(article: Article, path: string) {
  const origin = siteImageOrigin();
  const url = canonicalUrl(path);
  if (!origin || !url || !article.slug) return null;
  const image = article.cover ? mediaImage(article.cover, origin) : undefined;
  const publisher = {
    '@type': 'Organization',
    name: site.name,
    url: origin,
    logo: { '@type': 'ImageObject', url: absolute('/assets/brand/logo.png', origin) },
  };
  return {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: article.title,
    description: article.seoDescription || article.summary || plainText(article.body, 300),
    ...(image ? { image: [image.url] } : {}),
    ...(article.publishedAt ? { datePublished: article.publishedAt } : {}),
    ...(article.author ? { author: { '@type': 'Person', name: article.author } } : {}),
    publisher,
    mainEntityOfPage: { '@type': 'WebPage', '@id': url },
    ...(article.category ? { articleSection: article.category } : {}),
    ...(article.tags.length ? { keywords: article.tags.join(', ') } : {}),
    inLanguage: site.locale,
  };
}

export function dealJsonLd(deal: PublicDeal) {
  const origin = siteImageOrigin();
  const url = canonicalUrl(`/deals/${deal.slug}`);
  if (!origin || !url) return null;
  const image = deal.media[0] ? mediaImage(deal.media[0], origin) : undefined;
  const available = deal.available > 0;
  return {
    '@context': 'https://schema.org',
    '@type': 'Product',
    name: deal.title,
    description: plainText(deal.description, 500) || `An assembled set from ${site.name}.`,
    ...(image ? { image: [image.url] } : {}),
    brand: { '@type': 'Brand', name: site.name },
    offers: {
      '@type': 'Offer',
      url,
      priceCurrency: site.currency,
      price: deal.priceMinor / 100,
      availability: available ? 'https://schema.org/InStock' : 'https://schema.org/OutOfStock',
    },
  };
}
