import type { Metadata } from 'next';
import { site } from '@/config/site';
import { canonicalUrl, indexingApproved, siteOrigin } from './site';

export type MetadataImage = { url: string; width?: number; height?: number; alt?: string };

type PageMetadataInput = {
  title?: string;
  description?: string;
  path: string;
  /** Only pass true when the page has genuine, canonical content. */
  index?: boolean;
  /** Private/transactional pages should not be followed either. */
  follow?: boolean;
  /** Private transactions must not advertise a canonical URL. */
  canonical?: boolean;
  image?: MetadataImage;
  type?: 'website' | 'article' | 'product';
  publishedTime?: string | null;
  authors?: string[];
};

export const siteDescription = 'A considered edit of skincare, makeup, fragrance, bath and body, and home pieces from Nook & Glow.';

export const defaultSocialImage: MetadataImage = {
  url: '/assets/hero/brand-introduction.webp',
  width: 1672,
  height: 941,
  alt: 'Nook & Glow storefront',
};

export function pageMetadata({
  title,
  description = siteDescription,
  path,
  index = false,
  follow,
  canonical: includeCanonical = true,
  image,
  type = 'website',
  publishedTime,
  authors,
}: PageMetadataInput): Metadata {
  const canonical = includeCanonical ? canonicalUrl(path) : undefined;
  const approved = indexingApproved();
  const canIndex = index && approved;
  const shouldFollow = follow ?? canIndex;
  const social: MetadataImage | undefined = image ?? defaultSocialImage;
  const absoluteImage = canonical && social
    ? { ...social, url: new URL(social.url, canonical).href }
    : undefined;

  return {
    ...(title ? { title } : {}),
    description,
    ...(canonical ? { alternates: { canonical } } : {}),
    robots: canIndex
      ? { index: true, follow: true, googleBot: { index: true, follow: true } }
      : { index: false, follow: shouldFollow, noarchive: true },
    openGraph: {
      ...(title ? { title: `${title} | ${site.name}` } : { title: site.name }),
      description,
      siteName: site.name,
      locale: site.locale,
      type: type === 'product' ? 'website' : type,
      ...(canonical ? { url: canonical } : {}),
      ...(absoluteImage ? { images: [absoluteImage] } : {}),
      ...(publishedTime ? { publishedTime } : {}),
      ...(authors?.length ? { authors } : {}),
    },
    twitter: {
      card: 'summary_large_image',
      title: title ? `${title} | ${site.name}` : site.name,
      description,
      ...(absoluteImage ? { images: [absoluteImage.url] } : {}),
    },
  };
}

export function organizationJsonLd() {
  const origin = siteOrigin();
  if (!origin) return null;
  return {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    name: site.name,
    url: origin,
    logo: new URL('/assets/brand/logo.png', origin).href,
    email: site.contactEmail,
    areaServed: 'PK',
  };
}

export function webSiteJsonLd() {
  const origin = siteOrigin();
  if (!origin) return null;
  return {
    '@context': 'https://schema.org',
    '@type': 'WebSite',
    name: site.name,
    url: origin,
    inLanguage: site.locale,
    potentialAction: {
      '@type': 'SearchAction',
      target: new URL('/search?q={search_term_string}', origin).href,
      'query-input': 'required name=search_term_string',
    },
  };
}
