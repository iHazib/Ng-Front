import 'server-only';
import {authorizeAdmin} from '@/lib/server/database/client';
import {identifier} from '@/lib/server/admin/catalog';
import {AdminError} from '@/lib/server/admin/session';
import {approveMediaForPublication,publishApprovedMedia} from '@/lib/server/media/service';
import {validateReview} from './validation';
export async function reviewsRead(token:string,url:URL){const admin=await authorizeAdmin(token);if(url.searchParams.get('view')==='history'){const rows=await admin.read<Array<{action:string;occurred_at:string}>>('review_moderation_events',new URLSearchParams({review_id:'eq.'+identifier(url.searchParams.get('id')),select:'action,occurred_at',order:'occurred_at.desc,id.desc',limit:'20'}));return rows.map(row=>({action:row.action==='edit'?'Edited — returned to Pending':row.action==='approve'?'Approved':row.action==='hide'?'Hidden':'Declined',date:row.occurred_at}));}const status=url.searchParams.get('status')??'pending';if(!['pending','approved','rejected'].includes(status))throw new AdminError('Choose a review tab.');
 const offset=Math.min(10000,Math.max(0,Number(url.searchParams.get('offset'))||0)),rows=await admin.read<Array<Record<string,unknown>&{id:string}>>('reviews',new URLSearchParams({status:'eq.'+status,select:'id,product_id,display_name,rating,title,body,status,hidden_at,revision,created_at,submission_complete,products(name)',order:'created_at.desc,id',limit:'20',offset:String(offset)}));
 if(!rows.length)return [];
 const images=await admin.read<Array<{review_id:string;media_id:string;media_assets:{alt:string;lifecycle:string}}>>('media_workflows',new URLSearchParams({review_id:'in.('+rows.map(r=>r.id).join(',')+')',select:'review_id,media_id,media_assets(alt,lifecycle)',order:'created_at.asc,media_id',limit:'60'}));
 return rows.map(row=>({...row,images:images.filter(image=>image.review_id===row.id&&!['deleted','retired'].includes(image.media_assets.lifecycle)).map(image=>({id:image.media_id,...image.media_assets}))}));
}
export async function reviewsWrite(token:string,body:Record<string,unknown>){const admin=await authorizeAdmin(token),id=identifier(body.id),revision=Number(body.revision);
 if(!Number.isInteger(revision)||revision<1)throw new AdminError('Reload this review before moderating.');
 const [review]=await admin.read<{revision:number;submission_complete:boolean}[]>('reviews',new URLSearchParams({id:'eq.'+id,select:'revision,submission_complete'}));if(!review||review.revision!==revision)throw new AdminError('This review changed. Reload before moderating.',409);
 if(body.action==='edit'){const data=validateReview({...body.data as Record<string,unknown>,email:''});const saved=await admin.write<unknown[]>('reviews',new URLSearchParams({id:'eq.'+id,revision:'eq.'+revision}),'PATCH',{display_name:data.name,title:data.title||null,body:data.body,rating:data.rating});if(!saved.length)throw new AdminError('This review changed. Reload before saving.',409);return {ok:true};}
 if(!['approve','decline','hide'].includes(String(body.action)))throw new AdminError('Choose Approve, Decline or Hide.');
 if(body.action==='approve'){
 if(!review.submission_complete)throw new AdminError('The customer upload is incomplete. Wait for them to retry, or decline it.');
 const images=await admin.read<Array<{media_id:string;media_assets:{lifecycle:string}}>>('media_workflows',new URLSearchParams({review_id:'eq.'+id,select:'media_id,media_assets(lifecycle)',order:'created_at.asc,media_id.asc',limit:'4'}));
 try{for(const image of images){const state=image.media_assets.lifecycle;if(['retired','deleted'].includes(state))continue;if(state==='private_pending')await approveMediaForPublication(token,image.media_id);await publishApprovedMedia(token,image.media_id);}}catch{throw new AdminError('An image could not be published. The review stays private. Retry approval to complete it.');}
 }
 try{await admin.rpc('moderate_review',{p_id:id,p_revision:revision,p_action:body.action});}catch{throw new AdminError('Review could not be updated. Reload if another edit changed it. Approval requires a complete submission, a published product and all images approved.');}
 return {ok:true};
}
