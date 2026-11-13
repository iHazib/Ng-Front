import { ApprovedHomepage } from '@/components/storefront/ApprovedHomepage';
import { getApprovedPreview } from '@/lib/catalog/approved-preview';
import {publicNavigation,samplePreviewEnabled} from '@/lib/server/storefront/catalog';
import {publicFrame} from '@/lib/server/storefront/frame';
import '@/components/storefront/commerce.css';
export default async function ShopLayout({ children }: { children: React.ReactNode }) {
  const sample=samplePreviewEnabled()?getApprovedPreview():publicFrame(await publicNavigation().catch(()=>({version:1 as const,brands:[],categories:[],types:[],concerns:[]})));
  return <ApprovedHomepage sample={sample}><div className="commerce">{children}</div></ApprovedHomepage>;
}
