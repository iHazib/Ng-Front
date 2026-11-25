import type {PublicProduct} from './public-types';

/** Rank only actual public catalog assignments; never infer concerns or suitability. */
export function similarProducts(current:PublicProduct,candidates:PublicProduct[]):PublicProduct[]{
 const seen=new Set<string>([current.id]);
 return candidates.flatMap(product=>{
  if(seen.has(product.id)||product.slug===current.slug||product.scope!==current.scope||product.categoryId!==current.categoryId)return [];
  seen.add(product.id);
  const variants=product.variants.filter(v=>v.available>0&&v.media.length>0).toSorted((a,b)=>a.priceMinor-b.priceMinor);
  return variants.length?[{...product,variants,priceMinor:Math.min(...variants.map(v=>v.priceMinor))}]:[];
 }).sort((a,b)=>Number(b.type===current.type)-Number(a.type===current.type)||Number(b.brandId===current.brandId)-Number(a.brandId===current.brandId)||Math.abs(a.priceMinor-current.priceMinor)-Math.abs(b.priceMinor-current.priceMinor)||a.id.localeCompare(b.id)).slice(0,4);
}
