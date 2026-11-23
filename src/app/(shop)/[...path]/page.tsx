import {ProductReviews} from '@/components/storefront/ProductReviews';
import type { Metadata } from 'next';
import { notFound, permanentRedirect } from 'next/navigation';
import { CommercePage, routeTitle, type Query } from '@/components/storefront/CommercePages';
import {PublicCommercePage} from '@/components/storefront/PublicCommercePages';
import {PublicBag} from '@/components/storefront/PublicBag';
import {ActualCheckout,OrderConfirmation} from '@/components/storefront/ActualCheckout';
import {publicCatalog,publicNavigation,samplePreviewEnabled} from '@/lib/server/storefront/catalog';
import {catalogParams,rootLabels,rootRoutes} from '@/lib/catalog/public-types';
import {publicArticles} from '@/lib/server/content/public';
import {PublishedEdit} from '@/components/storefront/PublishedEdit';
import {publicReviews} from '@/lib/server/reviews/public';
import {slugRedirect} from '@/lib/server/storefront/redirects';
import {plainText} from '@/lib/seo/plain-text';
import {pageMetadata} from '@/lib/seo/metadata';
import {siteOrigin} from '@/lib/seo/site';
import {mediaImage, productImage} from '@/lib/seo/schema';
export const dynamic='force-dynamic';
type Props = { params: Promise<{ path: string[] }>; searchParams: Promise<Query> };

function collectionFiltered(query: Query) {
  const parsed = catalogParams(query);
  return parsed.q !== '' || parsed.sort !== 'relevance' || parsed.page > 1 || Object.keys(parsed.filters).length > 0;
}

export async function generateMetadata({ params,searchParams }: Props): Promise<Metadata> {
  const path=(await params).path.join('/');
  const query=await searchParams;
  if(samplePreviewEnabled()){
    const previewTitle=routeTitle(path);if(!previewTitle)notFound();
    return pageMetadata({title:previewTitle,path:'/'+path,index:false,description:`${previewTitle} — Nook & Glow sample storefront preview.`});
  }
  if(path.startsWith('order-confirmation/'))return pageMetadata({title:'Private order confirmation',path:'/',index:false,follow:false,canonical:false});
  if(path==='cart'||path==='checkout')return pageMetadata({title:path==='cart'?'Your bag':'Checkout',path:'/'+path,index:false,follow:false,canonical:false});
  if(path==='search')return pageMetadata({title:'Search',path:'/search',index:false,follow:false,description:'Search published products at Nook & Glow.'});
  if(path.startsWith('products/')){
    const slug=path.slice(9),result=await publicCatalog('search','{}',slug),product=result.products[0];
    if(!product){const target=await slugRedirect('product',slug);if(target)permanentRedirect(target);notFound();}
    const origin=siteOrigin(),image=origin?productImage(product,origin):undefined;
    return pageMetadata({title:product.name,path:'/products/'+product.slug,index:true,type:'product',image,
      description:plainText(product.description,160)||`${product.name} by ${product.brand}.`});
  }
  if(path==='brands'){
    const navigation=await publicNavigation().catch(()=>null);
    return pageMetadata({title:'Brands',path:'/brands',index:Boolean(navigation?.brands.some(brand=>brand.count>0)),
      description:'Published brands in the Nook & Glow edit.'});
  }
  if(path.startsWith('brands/')){
    const id=path.slice(7),navigation=await publicNavigation(),brand=navigation.brands.find(item=>item.id===id);
    if(!brand){const target=await slugRedirect('brand',id);if(target)permanentRedirect(target);notFound();}
    const filtered=collectionFiltered(query);
    return pageMetadata({title:brand.name,path:'/brands/'+brand.id,index:brand.count>0&&!filtered,
      description:`${brand.name} products published at Nook & Glow.`});
  }
  if(path.startsWith('the-edit/')){
    const slug=path.slice(9),article=(await publicArticles(slug)).articles[0];
    if(!article){const target=await slugRedirect('article',slug);if(target)permanentRedirect(target);notFound();}
    const origin=siteOrigin(),image=origin&&article.cover?mediaImage(article.cover,origin):undefined;
    return pageMetadata({title:article.seoTitle||article.title,path:'/the-edit/'+slug,index:true,type:'article',image,
      description:article.seoDescription||article.summary||plainText(article.body,160)||'A story from The Edit.',
      publishedTime:article.publishedAt,authors:article.author?[article.author]:undefined});
  }
  if(path==='the-edit'){
    const page=catalogParams(query).page,result=await publicArticles(undefined,false,page).catch(()=>null);
    return pageMetadata({title:'The Edit',path:'/the-edit',index:Boolean(result?.total)&&page===1,
      description:'Beauty, home and everyday stories from Nook & Glow.'});
  }
  if(Object.hasOwn(rootRoutes,path)){
    const filtered=collectionFiltered(query),result=filtered?null:await publicCatalog(path,JSON.stringify(query)).catch(()=>null),label=rootLabels[path];
    return pageMetadata({title:label,path:'/'+path,index:Boolean(result?.total)&&!filtered,
      description:`${label} published at Nook & Glow.`});
  }
  const title=routeTitle(path);
  if(!title)notFound();
  // Customer-care pages are still preview placeholders: keep them out of search
  // results but let crawlers follow their navigation.
  return pageMetadata({title,path:'/'+path,index:false,follow:true,description:`${title} at Nook & Glow.`});
}
export default async function ShopPage({ params, searchParams }: Props) {
  const path = (await params).path.join('/');
  const query=await searchParams;
  if(samplePreviewEnabled()){if(!routeTitle(path))notFound();return <CommercePage path={path} query={query}/>;}
  if(Object.hasOwn(rootRoutes,path)||path==='brands'||path==='search'||path.startsWith('brands/')||path.startsWith('products/')){
    const [navigation,result]=await Promise.all([publicNavigation(),publicCatalog(path.startsWith('products/')?'search':path,JSON.stringify(path.startsWith('products/')?{}:query),path.startsWith('products/')?path.slice(9):undefined)]);
    const product=path.startsWith('products/')?result.products[0]:undefined;
    const reviewPage=Math.min(1000,Math.max(1,Number(Array.isArray(query.reviewPage)?query.reviewPage[0]:query.reviewPage)||1));
    const reviewResult=product?await publicReviews(product.id,reviewPage).catch(()=>null):null;
    return <PublicCommercePage path={path} query={query} result={result} navigation={navigation} reviewResult={reviewResult} reviews={product?<ProductReviews productId={product.id} slug={product.slug} page={reviewPage} result={reviewResult}/>:undefined}/>;
  }
  if(path==='cart')return <PublicBag/>;
  if(path==='checkout')return <ActualCheckout/>;
  if(/^order-confirmation\/[a-f0-9-]{36}$/.test(path))return <OrderConfirmation id={path.slice(19)}/>;
  if(path==='the-edit'||path.startsWith('the-edit/')){const slug=path.startsWith('the-edit/')?path.slice(9):undefined,page=Math.max(1,Math.min(10000,Number(Array.isArray(query.page)?query.page[0]:query.page)||1));return <PublishedEdit slug={slug} page={page} result={await publicArticles(slug,false,page)}/>;}
  if(path.startsWith('the-edit/')||!routeTitle(path))notFound();
  return <CommercePage path={path} query={query}/>;
}
