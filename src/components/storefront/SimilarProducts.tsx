import Link from 'next/link';
import {publicCatalog} from '@/lib/server/storefront/catalog';
import {scopeRoutes,type PublicProduct} from '@/lib/catalog/public-types';
import {similarProducts} from '@/lib/catalog/recommendations';
import {PublicProductCard} from './PublicCommercePages';

export async function SimilarProducts({product}:{product:PublicProduct}){
 const route=scopeRoutes[product.scope];
 if(!route||!product.categoryId)return null;
 try{
  // One bounded anonymous RPC; no per-card queries, sample fallback or private credentials.
  const result=await publicCatalog(route,JSON.stringify({category:product.categoryId}));
  const products=similarProducts(product,result.products);
  if(!products.length)return null;
  return <section className="similar-products" aria-labelledby="similar-products-title"><header><div><p className="eyebrow">Explore the collection</p><h2 id="similar-products-title">Similar products</h2></div><Link className="text-link" href={'/'+route+'?category='+encodeURIComponent(product.categoryId)}>View collection ↗</Link></header><div className="similar-products-grid">{products.map(p=><PublicProductCard key={p.id} product={p}/>)}</div></section>;
 }catch{return null;}
}
