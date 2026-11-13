import type {Metadata} from 'next';
import {notFound,permanentRedirect} from 'next/navigation';import {publicDeals} from '@/lib/server/storefront/deals';import {Breadcrumbs} from '@/components/storefront/CommercePages';import {DealPurchase} from '@/components/storefront/DealPurchase';
import {slugRedirect} from '@/lib/server/storefront/redirects';
import {pageMetadata} from '@/lib/seo/metadata';
import {siteOrigin} from '@/lib/seo/site';
import {breadcrumbJsonLd,dealJsonLd,mediaImage} from '@/lib/seo/schema';
import {JsonLd} from '@/components/seo/JsonLd';
import {plainText} from '@/lib/seo/plain-text';
export const dynamic='force-dynamic';
const validSlug=(slug:string)=>/^[a-z0-9]+(-[a-z0-9]+)*$/.test(slug);
export async function generateMetadata({params}:{params:Promise<{slug:string}>}):Promise<Metadata>{
 const {slug}=await params;if(!validSlug(slug))notFound();
 const deal=(await publicDeals({slug})).deals[0];
 if(!deal){const target=await slugRedirect('deal',slug);if(target)permanentRedirect(target);notFound();}
 const origin=siteOrigin(),image=origin&&deal.media[0]?mediaImage(deal.media[0],origin):undefined;
 return pageMetadata({title:deal.title,path:'/deals/'+deal.slug,index:true,type:'product',image,description:plainText(deal.description,160)||`An assembled set from Nook & Glow.`});
}
export default async function Page({params}:{params:Promise<{slug:string}>}){const {slug}=await params;if(!validSlug(slug))notFound();const d=(await publicDeals({slug})).deals[0];if(!d){const target=await slugRedirect('deal',slug);if(target)permanentRedirect(target);notFound();}const items=[{label:'Deals',href:'/deals'},{label:d.title}];return <><JsonLd data={dealJsonLd(d)}/><JsonLd data={breadcrumbJsonLd(items,'/deals/'+d.slug)}/><Breadcrumbs items={items}/><DealPurchase deal={d}/></>;}
