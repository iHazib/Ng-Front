import {authorizeReviewRequest,ReviewError,reviewHeaders,reviewSession} from '@/lib/server/reviews/gateway';
import {submitReview} from '@/lib/server/reviews/submission';
export const dynamic='force-dynamic';
const failure=(error:unknown)=>Response.json({error:error instanceof ReviewError?error.message:'Review could not be submitted. Please retry shortly.'},{status:error instanceof ReviewError?error.status:400,headers:reviewHeaders});
export async function GET(){try{return Response.json(await reviewSession(),{headers:reviewHeaders});}catch(error){return failure(error);}}
export async function POST(request:Request){try{const {session,rate}=await authorizeReviewRequest(request);
 const type=request.headers.get('content-type')??'';if(!type.startsWith('multipart/form-data;'))throw new ReviewError('Use the review form.');
 const reader=request.body?.getReader();if(!reader)throw new ReviewError('Review fields are missing.');const chunks:Uint8Array[]=[];let length=0;
 try{while(true){const part=await reader.read();if(part.done)break;length+=part.value.byteLength;if(length>16*1024*1024){await reader.cancel();throw new ReviewError('Review images are too large.',413);}chunks.push(part.value);}}finally{reader.releaseLock();}
 const form=await new Request(request.url,{method:'POST',headers:{'Content-Type':type},body:Buffer.concat(chunks)}).formData();
 return Response.json(await submitReview(form,session,rate),{headers:reviewHeaders});
 }catch(error){return failure(error);}}
