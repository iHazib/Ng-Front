import {boundedJson} from '@/lib/server/admin/security';
import {adminSession,AdminError,privateHeaders,validateMutation} from '@/lib/server/admin/session';
import {reviewsRead,reviewsWrite} from '@/lib/server/reviews/admin';
import {invalidatePublicCatalog} from '@/lib/server/storefront/invalidate';
export const dynamic='force-dynamic';
const fail=(error:unknown)=>Response.json({error:error instanceof AdminError?error.message:'Reviews are unavailable. Retry shortly.'},{status:error instanceof AdminError?error.status:400,headers:privateHeaders});
export async function GET(request:Request){try{const {token}=await adminSession();return Response.json(await reviewsRead(token,new URL(request.url)),{headers:privateHeaders});}catch(error){return fail(error);}}
export async function POST(request:Request){try{await validateMutation(request);const {token}=await adminSession();const result=await reviewsWrite(token,await boundedJson(request,20000));invalidatePublicCatalog();return Response.json(result,{headers:privateHeaders});}catch(error){return fail(error);}}
