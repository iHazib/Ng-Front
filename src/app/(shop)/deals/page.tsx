/* eslint-disable @next/next/no-img-element -- Cloudinary resolver provides responsive optimized delivery. */
import type {Metadata} from 'next';
import Link from 'next/link';import {publicDeals} from '@/lib/server/storefront/deals';import {resolveMedia} from '@/lib/catalog/media';import {pkrMinor} from '@/lib/catalog/public-types';import {Breadcrumbs} from '@/components/storefront/CommercePages';
import {JsonLd} from '@/components/seo/JsonLd';
import {breadcrumbJsonLd} from '@/lib/seo/schema';
import {pageMetadata} from '@/lib/seo/metadata';
export const dynamic='force-dynamic';
function dealPage(value:string|undefined){return Math.max(1,Math.min(10000,Number.parseInt(value??'1',10)||1));}
export async function generateMetadata({searchParams}:{searchParams:Promise<{page?:string}>}):Promise<Metadata>{
 const page=dealPage((await searchParams).page);
 const result=await publicDeals({page}).catch(()=>null);
 return pageMetadata({title:'Deals',path:'/deals',index:Boolean(result?.total)&&page===1,description:'Published assembled deals from Nook & Glow.'});
}
export default async function Page({searchParams}:{searchParams:Promise<{page?:string}>}){const page=dealPage((await searchParams).page);let result;try{result=await publicDeals({page});}catch{return <div role="status"><h1>Deals</h1><p>Deals are temporarily unavailable. Please try again.</p><Link href="/deals">Retry</Link></div>;}const items=[{label:'Deals'}];return <><JsonLd data={breadcrumbJsonLd(items,'/deals')}/><Breadcrumbs items={items}/><header className="commerce-heading"><p className="eyebrow">The considered collection</p><h1>Deals</h1><p>{result.total} published deals</p></header>{result.deals.length?<div className="catalog-grid">{result.deals.map(d=><article className="catalog-card" key={d.id}><Link className="catalog-image" href={'/deals/'+d.slug}>{d.media[0]&&<img {...resolveMedia(d.media[0],{sizes:'(max-width: 600px) 50vw, 25vw'})}/>}</Link><p className="eyebrow">Assembled deal</p><h2><Link href={'/deals/'+d.slug}>{d.title}</Link></h2><p>{pkrMinor(d.priceMinor)} <small>PKR</small></p><Link className="text-link" href={'/deals/'+d.slug}>View exact contents ↗</Link>{!d.available&&<p>Currently unavailable</p>}</article>)}</div>:<p role="status">No active deals are published yet.</p>}<nav className="pagination" aria-label="Deal pages">{page>1&&<Link href={'/deals?page='+(page-1)} rel="prev">Previous</Link>}{page*24<result.total&&<Link href={'/deals?page='+(page+1)} rel="next">Next</Link>}</nav></>;}
