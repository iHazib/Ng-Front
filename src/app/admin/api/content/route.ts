import {boundedJson} from '@/lib/server/admin/security';
import {adminSession,AdminError,privateHeaders,validateMutation} from '@/lib/server/admin/session';
import {contentRead,contentWrite} from '@/lib/server/content/admin';
import {invalidatePublicCatalog} from '@/lib/server/storefront/invalidate';
export const dynamic='force-dynamic';
const failure=(e:unknown)=>Response.json({error:e instanceof AdminError?e.message:'Content is unavailable. Refresh or retry shortly.'},{status:e instanceof AdminError?e.status:400,headers:privateHeaders});
export async function GET(request:Request){try{const {token}=await adminSession();return Response.json(await contentRead(token,new URL(request.url)),{headers:privateHeaders});}catch(e){return failure(e);}}
export async function POST(request:Request){try{await validateMutation(request);const {token}=await adminSession();const result=await contentWrite(token,await boundedJson(request,150000));invalidatePublicCatalog();return Response.json(result??{ok:true},{headers:privateHeaders});}catch(e){return failure(e);}}
