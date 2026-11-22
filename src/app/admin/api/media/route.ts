import { boundedJson } from '@/lib/server/admin/security';
import { adminSession, AdminError, privateHeaders, validateMutation } from '@/lib/server/admin/session';
import { identifier } from '@/lib/server/admin/catalog';
import * as media from '@/lib/server/media/service';
import { boundedImageBody } from '@/lib/server/media/cloudinary';
import {invalidatePublicCatalog} from '@/lib/server/storefront/invalidate';
export const dynamic='force-dynamic';
export const maxDuration=120;
// Deployment/configuration faults that an administrator can act on, and that reveal
// no credentials, provider internals or storage paths. Anything else stays generic.
const explainable=new Set([
  'Media provider configuration is incomplete.',
  'Stored media belongs to another environment.',
  'Media intent not found.',
  'Private image unavailable.',
  'Private image is no longer available.',
  'Private image differs from upload intent.',
  'Only PNG, JPEG and WebP image files are accepted.',
  'Image must be between 1 byte and 10 MiB.',
]);
function failure(error:unknown) {
  const known=error instanceof Error&&explainable.has(error.message)?error.message:null;
  const message=error instanceof AdminError?error.message:known??'Media operation incomplete. Refresh and retry the same image identity; referenced assets cannot be cleaned up.';
  return Response.json({error:message},{status:error instanceof AdminError?error.status:400,headers:privateHeaders});
}
export async function GET(request:Request) {
  try {
    const {token}=await adminSession();const id=identifier(new URL(request.url).searchParams.get('id'));
    const image=await media.getPrivateReviewImage(token,id);
    return new Response(new Uint8Array(image.bytes),{headers:{...privateHeaders,'Content-Type':`image/${image.format==='jpg'?'jpeg':image.format}`,'Content-Disposition':'inline','X-Content-Type-Options':'nosniff'}});
  }catch(error){return failure(error);}
}
export async function POST(request:Request) {
  try {
    await validateMutation(request);const {token}=await adminSession();const url=new URL(request.url);
    if(url.searchParams.get('action')==='upload') {
      const bytes=await boundedImageBody(new Response(request.body,{headers:request.headers}));
      const result=await media.uploadPendingMedia(token,{
        mediaId:identifier(url.searchParams.get('id')),dealId:url.searchParams.get('dealId')?identifier(url.searchParams.get('dealId')):undefined,productId:url.searchParams.get('productId')?identifier(url.searchParams.get('productId')):undefined,
        articleId:url.searchParams.get('articleId')?identifier(url.searchParams.get('articleId')):undefined,
        homepageId:url.searchParams.get('homepageId')?identifier(url.searchParams.get('homepageId')):undefined,
        kind:url.searchParams.get('kind')??undefined,
        variantId:url.searchParams.get('variantId')?identifier(url.searchParams.get('variantId')):undefined,
        replaceAssociationId:url.searchParams.get('replace')?identifier(url.searchParams.get('replace')):undefined,
        alt:(url.searchParams.get('alt')??'').slice(0,500),
      },bytes);
      return Response.json(result,{headers:privateHeaders});
    }
    const body=await boundedJson(request,20000);const id=body.id?identifier(body.id):'';
    switch(body.action){
      case 'approve-publish': {
        const { admin }=await adminSession();
        const rows=await admin.read<Array<{lifecycle:string}>>('media_assets',new URLSearchParams({id:`eq.${id}`,select:'lifecycle'}));
        if(rows[0]?.lifecycle==='private_pending')await media.approveMediaForPublication(token,id);
        await media.publishApprovedMedia(token,id);break;
      }
      case 'approve':await media.approveMediaForPublication(token,id);break;
      case 'publish':await media.publishApprovedMedia(token,id);break;
      case 'detach':await media.detachMedia(token,id);break;
      case 'cleanup':await media.cleanupOrphanMedia(token,id);break;
      case 'primary':await media.selectPrimaryMedia(token,identifier(body.productId),body.variantId?identifier(body.variantId):null,id);break;
      case 'reorder':
        if(!Array.isArray(body.ids)||body.ids.length>1000)throw new AdminError('Invalid image order.');
        await media.reorderMedia(token,identifier(body.productId),body.variantId?identifier(body.variantId):null,body.ids.map(identifier));break;
      default:throw new AdminError('Unknown media action.');
    }
    invalidatePublicCatalog();return Response.json({ok:true},{headers:privateHeaders});
  }catch(error){return failure(error);}
}
