import 'server-only';
import sanitizeHtml from 'sanitize-html';
import {resolveMedia} from '@/lib/catalog/media';
import type {Media} from '@/lib/catalog/types';
export type ContentImage=Media&{id:string};
const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/;
export const safeContentPath=(path:string)=>/^\/(?:products\/[a-z0-9-]+|skincare|makeup|bath-body|hair-care|cutlery|fragrances(?:\/(?:personal-fragrance|home-fragrance))?)$/.test(path);
/** Always executed on the server, on BOTH write and public/admin read. */
export function sanitizeRichText(input:string,images?:Array<ContentImage|Pick<ContentImage,'id'|'alt'>>,preview=false,links?:Set<string>){
 if(input.length>100000)throw Error('Article text is too long.');
 return sanitizeHtml(input,{allowedTags:['p','br','strong','b','em','i','h2','h3','ul','ol','li','blockquote','a','img'],allowedAttributes:{a:['href'],img:['data-media-id','src','alt','srcset','sizes','width','height']},allowedSchemes:['https'],allowProtocolRelative:false,
 transformTags:{a:(_tag,attrs):sanitizeHtml.Tag=>({tagName:'a',attribs:attrs.href&&safeContentPath(attrs.href)&&(!links||links.has(attrs.href))?{href:attrs.href}:{}}),
 img:(_tag,attrs):sanitizeHtml.Tag=>{const id=attrs['data-media-id'];if(!id||!uuid.test(id))return {tagName:'span',attribs:{}};if(images===undefined)return {tagName:'img',attribs:{'data-media-id':id}};const image=images.find(m=>m.id===id);if(!image)return {tagName:'span',attribs:{}};if(preview)return {tagName:'img',attribs:{'data-media-id':id,src:'/admin/api/media?id='+id,alt:image.alt}};if(!('source' in image))return {tagName:'span',attribs:{}};const m=resolveMedia(image);return {tagName:'img',attribs:{'data-media-id':id,src:m.src,alt:m.alt,...(m.srcSet?{srcset:m.srcSet,sizes:m.sizes??'100vw'}:{})}};}}
 });
}
export const plainText=(html:string)=>sanitizeHtml(html,{allowedTags:[],allowedAttributes:{}}).trim();
