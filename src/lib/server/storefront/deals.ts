import 'server-only';
import type {DealResult} from '@/lib/catalog/deals';
import {CatalogUnavailable} from './catalog';
export async function publicDeals({slug,ids=[],page=1,home=false}:{slug?:string;ids?:string[];page?:number;home?:boolean}={}):Promise<DealResult>{
 try{const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;if(!url||!key)throw Error();const r=await fetch(new URL('/rest/v1/rpc/storefront_deals',url),{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:JSON.stringify({p_slug:slug??null,p_ids:ids,p_page:page,p_home:home}),cache:'no-store',redirect:'error',signal:AbortSignal.timeout(12000)});if(!r.ok)throw Error();return r.json();}catch{throw new CatalogUnavailable();}
}
