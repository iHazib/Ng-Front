import { ApprovedHomepage } from '@/components/storefront/ApprovedHomepage';
import { getApprovedPreview } from '@/lib/catalog/approved-preview';
import {publicCatalog,publicNavigation,samplePreviewEnabled} from '@/lib/server/storefront/catalog';
import {publicFrame} from '@/lib/server/storefront/frame';
import {publicDeals} from '@/lib/server/storefront/deals';
import {publicArticles} from '@/lib/server/content/public';
import {pageMetadata, siteDescription} from '@/lib/seo/metadata';

export const dynamic = 'force-dynamic';

export function generateMetadata() {
  return pageMetadata({ path: '/', index: true, description: siteDescription });
}

export default async function Home() {
  if(samplePreviewEnabled())return <ApprovedHomepage sample={getApprovedPreview()} />;
  try{const [navigation,result,editorial,deals]=await Promise.all([publicNavigation(),publicCatalog('search','{}',undefined,true),publicArticles(undefined,true).catch(()=>({total:0,articles:[]})),publicDeals({home:true}).catch(()=>null)]);return <ApprovedHomepage sample={publicFrame(navigation,result.products,editorial.articles,deals?.deals??[],deals?.homeOrder??[])}/>;}
  catch{const frame=publicFrame({version:1,brands:[],categories:[],types:[],concerns:[]});
    const replace=(nodes:typeof frame.nodes)=>{for(const node of nodes)if(typeof node!=='string'){if(node.attrs.role==='status')node.children=['The collection is temporarily unavailable. Please try again shortly.'];replace(node.children);}};replace(frame.nodes);
    return <ApprovedHomepage sample={frame}/>;
  }
}
