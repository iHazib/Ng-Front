import 'server-only';
import {cache} from 'react';
import {CatalogUnavailable} from '@/lib/server/storefront/catalog';
import {sanitizeRichText} from './rich-text';
import type {ArticleResult} from '@/lib/catalog/content-types';
export const publicArticles=cache(async(slug?:string,home=false,page=1):Promise<ArticleResult>=>{
 try{const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;if(!url||!key)throw Error();
 const r=await fetch(new URL('/rest/v1/rpc/storefront_articles',url),{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:JSON.stringify({p_slug:slug??null,p_home:home,p_page:Math.min(10000,Math.max(1,page)),p_size:home?12:12}),cache:'no-store',redirect:'error',signal:AbortSignal.timeout(12000)});if(!r.ok)throw Error();const result=await r.json() as ArticleResult;
 const paths=[...new Set(result.articles.flatMap(a=>[...(a.body??'').matchAll(/href="([^"]+)"/g)].map(m=>m[1])))];
 let links:string[]=[];if(paths.length){const l=await fetch(new URL('/rest/v1/rpc/content_link_targets',url),{method:'POST',headers:{apikey:key,'Content-Type':'application/json'},body:JSON.stringify({p_paths:paths.slice(0,32)}),cache:'no-store',signal:AbortSignal.timeout(12000)});if(l.ok)links=await l.json();}
 return {...result,articles:result.articles.map(a=>({...a,body:a.body?sanitizeRichText(a.body,a.images,false,new Set(links)):null}))};}catch{throw new CatalogUnavailable();}
});
