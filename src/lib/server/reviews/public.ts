import 'server-only';
import type {ReviewResult} from '@/lib/catalog/review-types';
export async function publicReviews(product:string,page=1):Promise<ReviewResult>{const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;if(!url||!key)throw new Error('Reviews unavailable.');
 const result=await fetch(new URL('/rest/v1/rpc/storefront_reviews',url),{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:JSON.stringify({p_product:product,p_page:page}),cache:'no-store',redirect:'error',signal:AbortSignal.timeout(12000)});if(!result.ok)throw new Error('Reviews unavailable.');
 // A provider/proxy error page can still be HTTP 200 JSON. Never let a
 // malformed payload crash the product page; render the unavailable state.
 const data:unknown=await result.json();
 if(!data||typeof data!=='object'||!Array.isArray((data as ReviewResult).reviews)||typeof (data as ReviewResult).total!=='number')throw new Error('Reviews unavailable.');
 return data as ReviewResult;
}
