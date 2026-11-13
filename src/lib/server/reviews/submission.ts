import 'server-only';
import {identifier} from '@/lib/server/admin/catalog';
import {boundedImageBody,mediaSettings,sha256,validateImageBytes} from '@/lib/server/media/cloudinary';
import {guestReviewRpc,reviewHash,reviewStorage} from './gateway';
import {ReviewError,validateReview} from './validation';
export async function submitReview(form:FormData,session:string,rate:string){
 const data=validateReview(Object.fromEntries(['name','title','body','email','rating','website'].map(k=>[k,form.get(k)]))),id=identifier(String(form.get('id'))),product=identifier(String(form.get('product')));
 const files=form.getAll('images').filter((file):file is File=>file instanceof File&&file.size>0);if(files.length>3)throw new ReviewError('Choose at most three review images.');
 const images=[];for(let index=0;index<files.length;index++){const file=files[index];if(file.size>5*1024*1024)throw new ReviewError('Each image must be under 5 MB.');const bytes=new Uint8Array(await file.arrayBuffer());validateImageBytes(bytes);const alt=String(form.get('alt'+index)??'').trim();if(!alt||alt.length>500)throw new ReviewError('Add a short description for each image.');
 const hash=reviewHash('image:'+session+':'+id+':'+index+':'+sha256(bytes)).slice(0,32),mediaId=[hash.slice(0,8),hash.slice(8,12),hash.slice(12,16),hash.slice(16,20),hash.slice(20)].join('-'),config=mediaSettings();images.push({id:mediaId,alt,hash:sha256(bytes),bytes:bytes.length,environment:config.environment,cloud:config.cloud,data:bytes});}
 const token=reviewHash('submission:'+session+':'+id),result=await guestReviewRpc<{id:string;images:Array<{id:string;path:string}>}>('submit_customer_review',{p_id:id,p_product:product,p_data:data,p_token:token,p_rate:rate,p_media:images.map(({data:ignored,...image})=>{void ignored;return image;})});
 for(const intent of result.images){const image=images.find(i=>i.id===intent.id);if(!image)throw new ReviewError('Review image retry mismatch.');const uploaded=await reviewStorage(intent.path,'POST',image.data);if(!uploaded.ok&&![400,409].includes(uploaded.status))throw new ReviewError('Image upload incomplete. Keep this form open and retry.');const stored=await reviewStorage(intent.path,'GET');if(!stored.ok)throw new ReviewError('Image upload could not be confirmed. Retry this submission.');const original=await boundedImageBody(stored);if(sha256(original)!==image.hash||original.length!==image.bytes)throw new ReviewError('Image validation failed.');}
 await guestReviewRpc('complete_customer_review',{p_id:id,p_token:token});return {ok:true};
}
