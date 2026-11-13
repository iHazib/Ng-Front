import { notFound, permanentRedirect } from 'next/navigation';
import { routeTitle } from '@/components/storefront/CommercePages';
import {publicCatalog,publicNavigation,samplePreviewEnabled,CatalogUnavailable} from '@/lib/server/storefront/catalog';
import {rootRoutes} from '@/lib/catalog/public-types';
import {publicArticles} from '@/lib/server/content/public';
import {slugRedirect} from '@/lib/server/storefront/redirects';

// Validate before the child loading boundary can stream a successful response.
export default async function ValidatedRoute({ params, children }: { params: Promise<{ path: string[] }>; children: React.ReactNode }) {
  const path=(await params).path.join('/');
  if(samplePreviewEnabled()){if(!routeTitle(path))notFound();return children;}
  // Validate actual identities before streaming so absent/private slugs return 404.
  // An outage is handled by the child error boundary, never disguised as not-found.
  try{
    if(path.startsWith('products/')){
      if(!(await publicCatalog('search','{}',path.slice(9))).products.length){
        const target=await slugRedirect('product',path.slice(9));if(target)permanentRedirect(target);notFound();
      }
    }
    else if(path.startsWith('brands/')){
      if(!(await publicNavigation()).brands.some(b=>path==='brands/'+b.id)){
        const target=await slugRedirect('brand',path.slice(7));if(target)permanentRedirect(target);notFound();
      }
    }
    else if(path.startsWith('the-edit/')){
      if(!(await publicArticles(path.slice(9))).articles.length){
        const target=await slugRedirect('article',path.slice(9));if(target)permanentRedirect(target);notFound();
      }
    }
    else if(!Object.hasOwn(rootRoutes,path)&&!['search','brands','cart','checkout','the-edit'].includes(path)&&!/^order-confirmation\/[a-f0-9-]{36}$/.test(path)&&!routeTitle(path))notFound();
  }catch(error){if(!(error instanceof CatalogUnavailable))throw error;}
  return children;
}
