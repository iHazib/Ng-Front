import { notFound, permanentRedirect } from 'next/navigation';
import { publicDeals } from '@/lib/server/storefront/deals';
import { slugRedirect } from '@/lib/server/storefront/redirects';

const validSlug = (slug: string) => /^[a-z0-9]+(-[a-z0-9]+)*$/.test(slug);

// Validate before the child loading boundary can stream a successful response.
export default async function ValidatedDeal({ params, children }: { params: Promise<{ slug: string }>; children: React.ReactNode }) {
  const { slug } = await params;
  if (!validSlug(slug)) notFound();
  const deal = (await publicDeals({ slug })).deals[0];
  if (!deal) {
    const target = await slugRedirect('deal', slug);
    if (target) permanentRedirect(target);
    notFound();
  }
  return children;
}
