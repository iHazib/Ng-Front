import {adminSession,AdminError,privateHeaders} from '@/lib/server/admin/session';
import {uuid} from '@/lib/server/commerce/validation';
import {readProof,type ProofDescriptor} from '@/lib/server/commerce/proofs';
export const dynamic='force-dynamic';
export async function GET(request:Request){try{const {admin}=await adminSession();const d=await admin.rpc('admin_payment_proof',{p_id:uuid(new URL(request.url).searchParams.get('id'))}) as ProofDescriptor|null;if(!d)throw new AdminError('Private proof unavailable.',404);return new Response(new Uint8Array(await readProof(d)),{headers:{...privateHeaders,'Content-Type':'image/png','X-Content-Type-Options':'nosniff','Content-Disposition':'inline; filename="private-payment-proof.png"','Content-Security-Policy':"default-src 'none'; sandbox"}});}catch(e){return Response.json({error:e instanceof AdminError?e.message:'Private proof unavailable.'},{status:e instanceof AdminError?e.status:503,headers:privateHeaders});}}
