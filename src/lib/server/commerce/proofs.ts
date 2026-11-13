import 'server-only';
import sharp from 'sharp';
import {boundedImageBody,sha256,validateImageBytes} from '@/lib/server/media/cloudinary';
import {CommerceError} from './validation';
export interface ProofDescriptor {id:string;path:string;hash:string;bytes:number}
export async function privateProofStorage(path:string,method:'GET'|'POST',bytes?:Uint8Array){
 if(!/^media\/(development|staging|production)\/[a-f0-9-]{36}\/original$/.test(path))throw new CommerceError('Private proof unavailable.',404);
 const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.SUPABASE_SECRET_KEY??process.env.SUPABASE_SERVICE_ROLE_KEY;
 if(!url||!key)throw new CommerceError('Private proof storage is not configured.',503);
 return fetch(new URL('/storage/v1/object/'+(method==='GET'?'authenticated/':'')+'catalog-private/'+path,url),{method,headers:{apikey:key,...(key.startsWith('sb_secret_')?{}:{Authorization:'Bearer '+key}),...(method==='POST'?{'Content-Type':'image/png','x-upsert':'false'}:{})},body:bytes?new Uint8Array(bytes):undefined,cache:'no-store',redirect:'error',signal:AbortSignal.timeout(20000)});
}
export async function proofBytes(request:Request){
 const bytes=await boundedImageBody(new Response(request.body));
 if(bytes.length>5242880)throw new CommerceError('Choose a PNG, JPEG or WebP proof image up to 5 MiB.');
 try{validateImageBytes(bytes);const image=sharp(bytes,{failOn:'warning',limitInputPixels:12000000});const metadata=await image.metadata();if((metadata.pages??1)!==1)throw Error();const normalized=await image.rotate().png().toBuffer();if(normalized.length>5242880)throw Error();return normalized;}catch{throw new CommerceError('This image cannot be read safely. Choose a smaller PNG, JPEG or WebP image.');}
}
export async function readProof(d:ProofDescriptor){const response=await privateProofStorage(d.path,'GET');if(!response.ok)throw new CommerceError('Private proof is temporarily unavailable.',503);const bytes=await boundedImageBody(response);if(bytes.length!==d.bytes||sha256(bytes)!==d.hash)throw new CommerceError('Private proof validation failed.',503);return bytes;}
