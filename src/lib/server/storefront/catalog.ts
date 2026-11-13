import 'server-only';
import {cache} from 'react';
import {getEnvironment} from '@/lib/server/environment';
import {catalogParams,rootRoutes,type CatalogQuery,type CatalogResult,type PublicNavigation} from '@/lib/catalog/public-types';
export function samplePreviewEnabled(){
 if(process.env.STOREFRONT_DATA_MODE==='sample-preview'){
  if(process.env.NODE_ENV!=='development'||getEnvironment().environment!=='development')throw Error('Sample catalog is restricted to explicit local development preview.');
  return true;
 }
 if(process.env.STOREFRONT_DATA_MODE&&process.env.STOREFRONT_DATA_MODE!=='supabase')throw Error('Invalid storefront data mode.');
 return false;
}
export class CatalogUnavailable extends Error{constructor(){super('The collection is temporarily unavailable. Please try again shortly.');}}
// No Auth cookies/tokens enter this boundary, including when an admin visits public pages.
// No cross-request cache: every navigation sees committed admin/media/taxonomy edits.
async function publicRpc<T>(name:string,args:Record<string,unknown>):Promise<T>{
 try{
  const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if(!url||!key)throw Error();const origin=new URL(url);
  if(origin.protocol!=='https:'&&!(['localhost','127.0.0.1'].includes(origin.hostname)&&origin.protocol==='http:'))throw Error();
  const response=await fetch(new URL('/rest/v1/rpc/'+name,origin),{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:JSON.stringify(args),cache:'no-store',redirect:'error',signal:AbortSignal.timeout(12000)});
  if(!response.ok)throw Error();return await response.json() as T;
 }catch{throw new CatalogUnavailable();}
}
export const publicNavigation=cache(()=>publicRpc<PublicNavigation>('storefront_navigation',{}));
export const publicCatalog=cache(async(path:string,encodedQuery:string,slug?:string,home=false)=>{
 const parsed=catalogParams(JSON.parse(encodedQuery) as CatalogQuery);
 return publicRpc<CatalogResult>('storefront_catalog',{p_query:parsed.q,p_scopes:rootRoutes[path]??[],p_brand:path.startsWith('brands/')?path.slice(7):null,p_filters:parsed.filters,p_sort:parsed.sort,p_page:parsed.page,p_size:24,p_slug:slug??null,p_home:home});
});
