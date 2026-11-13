import {authorizeCheckout,commerceHeaders,commerceRpc,commerceSession} from '@/lib/server/commerce/gateway';
import {CommerceError,uuid} from '@/lib/server/commerce/validation';
import {privateProofStorage,proofBytes,readProof,type ProofDescriptor} from '@/lib/server/commerce/proofs';
import {sha256} from '@/lib/server/media/cloudinary';
export const dynamic='force-dynamic';
const fail=(e:unknown)=>Response.json({error:e instanceof CommerceError?e.message:'Private upload failed. Retry the same image.'},{status:e instanceof CommerceError?e.status:503,headers:commerceHeaders});
export async function POST(request:Request){try{
 const s=await authorizeCheckout(request);await commerceRpc('commerce_rate',{p_rate:s.rate});const q=new URL(request.url).searchParams,order=uuid(q.get('order')),id=uuid(q.get('id'));
 // Check ownership before decoding or writing any bytes.
 await commerceRpc('guest_order_confirmation',{p_id:order,p_session:s.session,p_token:s.token(order)});
 const bytes=await proofBytes(request),environment=process.env.MEDIA_ENVIRONMENT;if(!['development','staging','production'].includes(environment??''))throw new CommerceError('Private media environment is not configured.',503);
 const args={p_order:order,p_session:s.session,p_token:s.token(order),p_id:id};
 const d=await commerceRpc<ProofDescriptor>('payment_proof',{...args,p_action:'create',p_data:{hash:sha256(bytes),bytes:bytes.length,environment}});
 const uploaded=await privateProofStorage(d.path,'POST',bytes);if(!uploaded.ok&&uploaded.status!==409&&uploaded.status!==400)throw new CommerceError('Private upload failed. Retry the same image.',503);
 await readProof(d);await commerceRpc('payment_proof',{...args,p_action:'complete',p_data:{}});
 return Response.json({id},{headers:commerceHeaders});
 }catch(e){return fail(e);}}
export async function GET(request:Request){try{const s=await commerceSession(),q=new URL(request.url).searchParams,order=uuid(q.get('order'));const d=await commerceRpc<ProofDescriptor>('payment_proof',{p_order:order,p_session:s.session,p_token:s.token(order),p_id:uuid(q.get('id')),p_action:'read',p_data:{}});return new Response(new Uint8Array(await readProof(d)),{headers:{...commerceHeaders,'Content-Type':'image/png','Content-Disposition':'inline; filename="private-payment-proof.png"','Content-Security-Policy':"default-src 'none'; sandbox"}});}catch(e){return fail(e);}}
