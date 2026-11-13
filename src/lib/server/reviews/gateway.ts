import 'server-only';
import {createHmac,randomBytes,timingSafeEqual} from 'node:crypto';
import {cookies} from 'next/headers';
import {validAdminOrigin} from '@/lib/server/admin/security';
export const reviewHeaders={'Cache-Control':'private, no-store, max-age=0','X-Robots-Tag':'noindex, nofollow','Vary':'Cookie','X-Content-Type-Options':'nosniff'};
import {ReviewError} from './validation';
export {ReviewError} from './validation';
const cookieName='ng_review_session';
function secret(){const value=process.env.REVIEW_SESSION_SECRET;if(!value||value.length<32)throw new ReviewError('Review submissions are not configured yet.',503);return value;}
export function reviewHash(value:string){return createHmac('sha256',secret()).update(value).digest('hex');}
function valid(value:string){const [random,time,signature]=value.split('.');const signed=random+'.'+time;
 return /^[a-f0-9]{48}$/.test(random??'')&&/^\d{13}$/.test(time??'')&&/^[a-f0-9]{64}$/.test(signature??'')&&Number(time)<=Date.now()&&Date.now()-Number(time)<3_600_000&&timingSafeEqual(Buffer.from(signature),Buffer.from(reviewHash(signed)));}
export async function reviewSession(){settings();const jar=await cookies();let value=jar.get(cookieName)?.value??'';
 if(!valid(value)){const signed=randomBytes(24).toString('hex')+'.'+Date.now();value=signed+'.'+reviewHash(signed);jar.set(cookieName,value,{httpOnly:true,sameSite:'strict',secure:process.env.NODE_ENV!=='development',path:'/api/reviews',maxAge:3600});}
 return {csrf:reviewHash('csrf:'+value)};
}
export async function authorizeReviewRequest(request:Request){
 if(!validAdminOrigin(request.headers.get('origin'),request.headers.get('host'),request.headers.get('sec-fetch-site'),process.env.NODE_ENV==='development'))throw new ReviewError('Submit the review from this product page.',403);
 const session=(await cookies()).get(cookieName)?.value??'',csrf=request.headers.get('x-review-csrf')??'';
 if(!valid(session)||!/^[a-f0-9]{64}$/.test(csrf)||!timingSafeEqual(Buffer.from(csrf),Buffer.from(reviewHash('csrf:'+session))))throw new ReviewError('Refresh the review form and try again.',403);
 if(Date.now()-Number(session.split('.')[1])<3000)throw new ReviewError('Take a moment to complete your review, then submit it.');
 const header=process.env.REVIEWS_TRUSTED_IP_HEADER;
 // Trust only a hosting-provider header explicitly configured after ingress strips spoofed values.
 if(header&&!['cf-connecting-ip','x-vercel-forwarded-for'].includes(header))throw new ReviewError('Review protection configuration is invalid.',503);
 const ip=header?request.headers.get(header):process.env.NODE_ENV==='development'?'development-loopback':null;
 if(!ip||!/^[:.a-fA-F0-9]{3,64}$/.test(ip)&&ip!=='development-loopback')throw new ReviewError('Review submission protection is not configured.',503);
 return {session,rate:reviewHash('rate:'+ip+':'+new Date().toISOString().slice(0,10))};
}
function settings(){const key=process.env.SUPABASE_SECRET_KEY??process.env.SUPABASE_SERVICE_ROLE_KEY,url=process.env.NEXT_PUBLIC_SUPABASE_URL;
 if(!key||!url)throw new ReviewError('Review submissions are not configured yet.',503);
 const parsed=new URL(url);if(parsed.protocol!=='https:'&&!['127.0.0.1','localhost'].includes(parsed.hostname))throw new ReviewError('Review configuration is invalid.',503);
 return {url:parsed.origin,key};
}
/** Narrow guest gateway: never export a general privileged table client. */
export async function guestReviewRpc<T>(name:'submit_customer_review'|'complete_customer_review',args:Record<string,unknown>):Promise<T>{const {url,key}=settings();
 const response=await fetch(url+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:key,...(key.startsWith('sb_secret_')?{}:{Authorization:'Bearer '+key}),'Content-Type':'application/json'},body:JSON.stringify(args),cache:'no-store',redirect:'error',signal:AbortSignal.timeout(15000)});
 if(!response.ok)throw new ReviewError(response.status===429?'You have submitted several reviews recently. Please try again after the current hour.':'Could not submit. Check the fields or retry any incomplete images.',response.status===429?429:400);
 return response.status===204?undefined as T:await response.json();
}
export async function reviewStorage(path:string,method:'GET'|'POST',bytes?:Uint8Array){const {url,key}=settings();
 if(!/^media\/(development|staging|production)\/[a-f0-9-]{36}\/original$/.test(path))throw new ReviewError('Invalid review image path.');
 return fetch(url+'/storage/v1/object/'+(method==='GET'?'authenticated/':'')+'catalog-private/'+path,{method,headers:{apikey:key,...(key.startsWith('sb_secret_')?{}:{Authorization:'Bearer '+key}),...(bytes?{'Content-Type':'application/octet-stream','x-upsert':'false'}:{})},body:bytes?new Uint8Array(bytes):undefined,cache:'no-store',redirect:'error',signal:AbortSignal.timeout(30000)});
}
