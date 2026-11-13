import { boundedJson } from '@/lib/server/admin/security';
import { adminSession, AdminError, privateHeaders, validateMutation } from '@/lib/server/admin/session';
import { importHistory, initialImagePreview, mutateProduct, productDetail, referenceData } from '@/lib/server/admin/catalog';
import { searchAdminCatalog } from '@/lib/server/database/catalog';
import {invalidatePublicCatalog} from '@/lib/server/storefront/invalidate';
import {adminCatalogList,adminCatalogOptions,setReminder} from '@/lib/server/admin/product-list';
export const dynamic = 'force-dynamic';
function failure(error: unknown) {
  return Response.json({error:error instanceof AdminError?error.message:'Operation failed. Check field compatibility, duplicate identifiers or provider availability. Reload before retrying.'},{status:error instanceof AdminError?error.status:400,headers:privateHeaders});
}
export async function GET(request:Request) {
  try {
    const {token}=await adminSession(); const url=new URL(request.url); const view=url.searchParams.get('view');
    const result=view==='list'?await adminCatalogList(token,url.searchParams):view==='filter-options'?await adminCatalogOptions(token,url.searchParams.get('category')??''):view==='history'?await importHistory(token):view==='references'?await referenceData(token):view==='images'?await initialImagePreview(token):view==='product'?await productDetail(token,url.searchParams.get('id')??''):await searchAdminCatalog(token,url.searchParams.get('q')??'',Number(url.searchParams.get('offset'))||0,url.searchParams.get('status')??'');
    return Response.json(result,{headers:privateHeaders});
  } catch(error) {return failure(error);}
}
export async function POST(request:Request) {
  try {
    await validateMutation(request); const {token}=await adminSession();
    const body=await boundedJson(request,180000);
    if(body.action==='reminder'){await setReminder(token,body);return Response.json({saved:true},{headers:privateHeaders});}
    const result=await mutateProduct(token,body);invalidatePublicCatalog();
    return Response.json(result,{headers:privateHeaders});
  } catch(error) {return failure(error);}
}
