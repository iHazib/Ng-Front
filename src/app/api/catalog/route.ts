import {publicCatalog,samplePreviewEnabled} from '@/lib/server/storefront/catalog';
export const dynamic='force-dynamic';
export async function GET(request:Request){
 const headers={'Cache-Control':'no-store','X-Robots-Tag':'noindex, nofollow'};
 if(samplePreviewEnabled())return Response.json({error:'Live catalog is not active in sample preview.'},{status:409,headers});
 const url=new URL(request.url),ids=url.searchParams.getAll('variant');
 if(ids.length>20||ids.some(id=>!/^[0-9a-f-]{36}$/i.test(id)))return Response.json({error:'Invalid bag identifiers.'},{status:400,headers});
 try{return Response.json(await publicCatalog('search',JSON.stringify(ids.length?{variant:ids}:{})),{headers});}
 catch{return Response.json({error:'The collection is temporarily unavailable.'},{status:503,headers});}
}
