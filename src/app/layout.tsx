import type { Metadata } from 'next';
import { site } from '@/config/site';
import { getEnvironment } from '@/lib/server/environment';
import { indexingApproved } from '@/lib/seo/site';
import { pageMetadata, organizationJsonLd, siteDescription, webSiteJsonLd } from '@/lib/seo/metadata';
import { JsonLd } from '@/components/seo/JsonLd';
import './base.css';

export function generateMetadata(): Metadata {
  const domain = getEnvironment().domain;
  const base = pageMetadata({ path: '/', description: siteDescription, index: true });
  return {
    ...base,
    ...(domain ? { metadataBase: domain } : {}),
    title: {
      default: `${site.name} — Considered beauty and home`,
      template: `%s | ${site.name}`,
    },
    applicationName: site.name,
    category: 'shopping',
    ...(indexingApproved() ? { authors: [{ name: site.name }] } : {}),
  };
}

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang={site.locale} data-scroll-behavior="smooth">
      <body>
        <JsonLd data={organizationJsonLd()} />
        <JsonLd data={webSiteJsonLd()} />
        {children}
      </body>
    </html>
  );
}
