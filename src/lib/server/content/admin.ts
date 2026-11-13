import 'server-only';
import {authorizeAdmin} from '@/lib/server/database/client';
import {identifier} from '@/lib/server/admin/catalog';
import {AdminError} from '@/lib/server/admin/session';
import {plainText,sanitizeRichText} from './rich-text';
const query=(v:Record<string,string>)=>new URLSearchParams(v);
export async function contentRead(token:string,url:URL){
 const admin=await authorizeAdmin(token),id=url.searchParams.get('id'),view=url.searchParams.get('view');
 if(view==='choices')return admin.rpc('admin_content_choices',{p_kind:url.searchParams.get('kind')??'products',p_query:(url.searchParams.get('q')??'').slice(0,100)});
 if(view==='homepage'){
 const [selections,workflows,associations]=await Promise.all([admin.read('homepage_selections',query({section:'in.(products,the-edit)',retired_at:'is.null',select:'id,section,position,product_id,article_id,deal_id,slide_theme,status,products(name),deals(name),articles(title)',order:'section,position',limit:'100'})),admin.read('media_workflows',query({homepage_id:'not.is.null',select:'media_id,homepage_id,content_kind,media_assets(alt,lifecycle)',limit:'500'})),admin.read('homepage_media',query({select:'id,homepage_id,media_id',limit:'500'}))]);return {selections,workflows,associations};
 }
 if(id){
 const owner=identifier(id);const [rows,workflows,associations]=await Promise.all([admin.read<Record<string,unknown>[]>('articles',query({id:'eq.'+owner,deleted_at:'is.null',select:'*,editorial_categories(name),article_tags(editorial_tags(name))'})),admin.read<Array<{media_id:string;content_kind:string;media_assets:{alt:string;lifecycle:string}}>>('media_workflows',query({article_id:'eq.'+owner,select:'media_id,content_kind,media_assets(alt,lifecycle)',limit:'200'})),admin.read('article_media',query({article_id:'eq.'+owner,select:'id,media_id,kind,position',order:'position',limit:'200'}))]);if(!rows[0])throw new AdminError('Article not found.',404);
 rows[0].body=sanitizeRichText(String(rows[0].body??''),workflows.filter(w=>w.media_assets.lifecycle!=='deleted').map(w=>({id:w.media_id,alt:w.media_assets.alt})),true);
 return {article:rows[0],workflows,associations};
 }
 return admin.read('articles',query({deleted_at:'is.null',select:'id,title,slug,status,revision,updated_at',title:'ilike.*'+(url.searchParams.get('q')??'').replaceAll('*','').slice(0,100)+'*',order:'updated_at.desc,id',limit:'30',offset:String(Math.min(10000,Math.max(0,Number(url.searchParams.get('offset'))||0)))}));
}
export async function contentWrite(token:string,body:Record<string,unknown>){
 const admin=await authorizeAdmin(token);
 if(body.action==='preview'){
 const owner=identifier(body.id);const workflows=await admin.read<Array<{media_id:string;media_assets:{alt:string;lifecycle:string}}>>('media_workflows',query({article_id:'eq.'+owner,select:'media_id,media_assets(alt,lifecycle)',limit:'200'}));
 return {html:sanitizeRichText(String(body.html??''),workflows.filter(w=>!['deleted','retired','deleting'].includes(w.media_assets.lifecycle)).map(w=>({id:w.media_id,alt:w.media_assets.alt})),true)};
 }
 if(body.action==='homepage'){
 if(!Array.isArray(body.items)||body.items.length>12||!['products','the-edit'].includes(String(body.section)))throw new AdminError('Choose up to 12 manual selections.');
 return admin.rpc('save_homepage_content',{p_section:body.section,p_items:body.items.map(item=>({id:identifier(item.id),entity:identifier(item.entity),theme:item.theme??'sage',kind:item.kind==='deal'?'deal':'product'}))});
 }
 if(body.action==='alt'){
 const id=identifier(body.id),alt=String(body.alt??'').trim();if(!alt||alt.length>500)throw new AdminError('Add a short image description.');
 const owns=await admin.read<unknown[]>('media_workflows',query({media_id:'eq.'+id,or:'(article_id.not.is.null,homepage_id.not.is.null)',select:'media_id'}));if(!owns.length)throw new AdminError('Content image not found.');
 return admin.write('media_assets',query({id:'eq.'+id}),'PATCH',{alt});
 }
 if(body.action!=='save')throw new AdminError('Unknown content action.');
 const data=body.data as Record<string,unknown>;if(!data||typeof data!=='object')throw new AdminError('Article fields missing.');
 let html=sanitizeRichText(String(data.body??''));const title=String(data.title??'').trim();
 const paths=[...new Set([...html.matchAll(/href="([^"]+)"/g)].map(m=>m[1]))];
 if(paths.length>32)throw new AdminError('Use at most 32 product/category links.');
 if(paths.length){const allowed=await admin.rpc<string[]>('content_link_targets',{p_paths:paths});html=sanitizeRichText(html,undefined,false,new Set(allowed));}
 const prepared={title,slug:String(data.slug??'').trim(),summary:String(data.summary??'').trim(),body:html,author:String(data.author??'').trim(),category:String(data.category??'').trim(),tags:Array.isArray(data.tags)?data.tags:[],seoTitle:String(data.seoTitle??'').trim(),seoDescription:String(data.seoDescription??'').trim()};
 if(body.intent==='publish'&&(!title||!prepared.slug||!plainText(html)))throw new AdminError('To publish, add a title, valid slug and article text.');
 try{return await admin.rpc('save_article',{p_id:identifier(body.id),p_revision:Number(body.revision),p_data:prepared,p_intent:body.intent??'save'});}catch{throw new AdminError('Could not save. Check the slug is unique and title, slug, text and approved inline images are complete. If another edit changed this article, reload before saving. Your entered text is kept.');}
}
