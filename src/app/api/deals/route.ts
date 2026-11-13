import {publicDeals} from '@/lib/server/storefront/deals';
export const dynamic='force-dynamic';
export async function GET(request:Request){const q=new URL(request.url).searchParams,ids=q.getAll('id'),headers={'Cache-Control':'no-store','X-Robots-Tag':'noindex, nofollow'};if(ids.length>20||ids.some(id=>!/^[a-f0-9-]{36}$/.test(id)))return Response.json({error:'Invalid deal identifiers.'},{status:400,headers});try{return Response.json(await publicDeals({ids}),{headers});}catch{return Response.json({error:'Deals are temporarily unavailable.'},{status:503,headers});}}
